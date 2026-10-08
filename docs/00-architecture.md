# 00 · 架构与分层

## 1. 目标

为 MoonBit 提供 OpenList API 客户端：**一个门面 + 六个功能域子模块**，
同时支持 OpenList 的两种认证方式（永久 token / 账号密码换限时 token）。

- 模块名：`q2316367743/open-list`，`source = "src"`（根目录只放元数据与文档）。
- HTTP 客户端：`q2316367743/moonhttp@0.5.0`（不自己写传输层）。
- 目标平台：`preferred_target = "native"`（moonhttp 依赖 `moonbitlang/async@0.22.4`）。
- 契约来源：OpenList v4 服务端源码（`server/router.go`、`server/handles/*.go`），
  官方 Apifox 文档只作参考。

## 2. 分层与依赖方向

```
         ┌────────────────────────── src/open_list.mbt + src/reexport.mbt ──────────┐
         │  OpenListClient（持有 core.Client 与六个域结构体）                        │
         │  create_open_list_client / create_open_list_client_with_token            │
         │  pub using 再导出：core 模型 + 各域请求体类型                             │
         └───────┬───────────────────────────────────────────────────────────────┘
                 │ 派生（每个域结构体持有同一份 core.Client 拷贝）
   ┌─────────────┼──────────────┬────────────┬────────────┬────────────┬───────────┐
   ▼             ▼              ▼            ▼            ▼            ▼
 src/auth   src/user      src/admin      src/fs      src/public   src/share
   └─────────────┴──────────────┴────────────┴────────────┴────────────┴───────────┘
                                     │ 全部依赖
                                     ▼
                                  src/core
                    认证状态 / 错误 / JSON 工具 / 请求管线 / 共享模型
```

依赖是单向的：`core` 不 import 任何域包，域包只 import `core`，根包 import 全部。
不存在循环依赖。

## 3. 使用者看到的 API

```moonbit
// 永久 token
let client = @open-list.create_open_list_client_with_token(
  "https://openlist.example.com",
  "…",
)
// 或账号密码：第一次需要认证的请求前自动登录，换取限时 token
let client = @open-list.create_open_list_client(
  @open-list.Settings::new("https://openlist.example.com"),
  @open-list.Credentials::password("admin", "secret"),
)

let list = client.fs().list("/")          // 文件域
let me = client.user().me()               // 当前用户
let shares = client.share().list(page=1)  // 分享
let initialized = client.public().init_status()
```

`OpenListClient` 上的成员：

| 成员 | 说明 |
|------|------|
| `auth() / user() / admin() / fs() / public() / share()` | 六个域子模块（创建时已派生好） |
| `settings()` | 连接设置（创建时固化，`base_url` 已去掉结尾 `/`） |
| `token()` / `set_token(String?)` / `is_logged_in()` | 共享认证状态 |
| `request(method, path, query?, body?, headers?)` | 逃生通道：直接打任意 `/api/...`，返回信封里的 `data`（原样 `Json`） |

## 4. 认证：两种方式与状态共享

`Credentials` 是封闭枚举：

```moonbit
pub(all) enum Credentials {
  Token(String)                  // 永久 token
  Password(PasswordCredentials)  // 账号密码（可带 otp_code）
}
```

- **两种方式都收敛到同一个 token 槽位**：`core.Client` 内部是
  `token : @ref.Ref[String?]`。
- 用 `Token(t)` 创建：槽位初值 `Some(t)`（`Token("")` 是**匿名模式**：不带
  `Authorization` 头，用于 `/api/public/*` 与可选认证的 `/api/fs/*`）。
- 用 `Password(...)` 创建：槽位初值 `None`，第一次请求前 `ensure_token()` 会
  `POST /api/auth/login` 拿 `data.token` 存进槽位。**并发首次调用可能多发一次
  登录请求**（代价很小，未加锁）。
- 六个域结构体各自持有一份 `core.Client` **拷贝**；因为 token 放在 `@ref.Ref`
  里，拷贝共享同一份状态（MoonBit 的 `Ref` 语义，已实测）。所以
  `client.auth().login(...)` 之后，`client.fs()` 立刻带着新 token。
- **401 自动重登一次**：只在凭证是 `Password` 时进行（`can_relogin()`）；永久
  token 失效时直接抛错，重试没有意义。
- 服务端不会返回 token 有效期（`/api/auth/login` 的 `data` 只有 `token`），
  所以客户端**不主动刷新**，只在收到 401 时重登一次。

## 5. 请求管线（`src/core/client.mbt`）

```
Client::request / send_stream / send_form
  → ensure_token()                    // 账号密码凭证：必要时先登录
  → execute(config, headers)          // 拼 URL、注入默认头、发请求
      · Authorization: <token>        // 注意：OpenList 不带 "Bearer " 前缀
      · Content-Type / 请求级头合并
  → resp.text() → @json.parse          // 必须是 JSON 信封
  → envelope.check(status)             // code != 200 → 抛 Api(ApiError{code,message,status,data})
  → data_or_null()                     // 取 data，缺省为 Json::Null
```

两个关键配置：

- `with_validate_status(_ => true)`：**关掉 moonhttp 的「非 2xx 即抛错」校验**。
  OpenList 把业务结果放在信封的 `code` 里，必须让 4xx/5xx 的响应体也走到我们
  手上，否则读不到 `{code,message,data}`。
- `Config::new(path)` + 默认 `base_url`：每个请求只写相对路径。

二进制体（`PUT /api/fs/put`、`/api/fs/multipart/chunk`）没有 JSON 体，走
`send_stream`（`@io.MemoryReader` 包 `Bytes`，见 `src/core/body.mbt`）；
`PUT /api/fs/form` 走 `send_form`（moonhttp 的 `FormData`）。

## 6. 错误模型（`src/core/error.mbt`）

```moonbit
pub(all) suberror OpenListError {
  Http(@moonhttp.HttpError)   // 传输层：连接失败 / 超时 / 取消 / 非法 URL
  Api(ApiError)               // 业务错误：信封 code != 200
  Decode(String)              // 协议错误：不是 JSON 信封，或 data 解不成目标类型
}

pub struct ApiError { code : Int; message : String; status : Int; data : Json? }
```

访问器：`OpenListError::message()`（一行日志）、`::status()`（HTTP 状态码，传输层
没拿到响应时 `None`）、`::code()`（业务码，非 `Api` 时 `None`）。

⚠️ **错误构造子的可见性限制**：MoonBit 的 `pub using` 能再导出**类型**，但再导出
不了**错误构造子**（moonhttp 的 `HttpError` 就是为此留在根包的）。`OpenListError`
定义在 `core` 包，本项目用黑盒测试 `src/open_list_test.mbt` 实测确认：使用者
import 根包后可以写 `catch { @open-list.OpenListError::Api(error) => … }`。
若未来工具链行为变化导致该写法失效，退路是在文档里指引使用者
`import { "q2316367743/open-list/core" }` 来捕获。

典型处理：

```moonbit
try {
  let list = client.fs().list("/")
  println(list.total)
} catch {
  @open-list.OpenListError::Api(error) => println("业务错误 \{error.code}: \{error.message}")
  error => println(error.message())
}
```

## 7. 子模块的「只能由客户端创建」是怎么落地的

用户要求「每个子模块的参数私有，只能通过客户端创建」。实现方式：

- 域结构体形如 `pub struct FileSystem { priv client : @core.Client }`——
  字段私有，外部**无法伪造**一个域对象（也就伪造不出认证状态）。
- 域构造器是 `pub fn FileSystem::new(@core.Client) -> FileSystem`，由根包在
  `create_open_list_client` 里调用。

⚠️ **MoonBit 的可见性边界**：跨包没有「函数级私有」——`new` 必须是 `pub`，否则
根包也调不到它；而 `@core.Client::new` 本身也是公开的。也就是说，硬要绕过门面
自己 `FileSystem::new(@core.Client::new(...))` 在类型上是可行的，但得到的仍是
同一套 `core` 状态（认证、错误、JSON 处理完全一致），既不破坏封装语义，也没有
额外能力。这是语言能力的边界，不是设计妥协。

## 8. 目录与文件清单

| 包 | 文件 | 职责 |
|----|------|------|
| 根包 | `src/open_list.mbt` | `OpenListClient`、创建函数、访问器、逃生通道 |
| | `src/reexport.mbt` | `pub using` 再导出全部公开类型（含 `Method`、`Transport`） |
| core | `src/core/settings.mbt` `credentials.mbt` | 服务器信息、两种凭证（`Settings::new` 会去掉结尾 `/`） |
| | `src/core/client.mbt` | 共享客户端：默认配置、token 管理、三种发送入口 |
| | `src/core/envelope.mbt` | `{code,message,data}` 信封的解析与校验 |
| | `src/core/error.mbt` | `OpenListError` / `ApiError` |
| | `src/core/json_util.mbt` | 字段读取助手、`null` 剔除、`decode_data` / `decode_page` |
| | `src/core/query.mbt` | `query_json` / `query_string` / `query_int` / `page_pairs` |
| | `src/core/body.mbt` | `bytes_reader`（流式请求体）、`url_path_encode`（RFC 3986） |
| | `src/core/models_*.mbt` | 共享模型：user / fs / archive / meta / setting / share |
| auth | `src/auth/auth.mbt` `types.mbt` | 认证域 |
| user | `src/user/user.mbt` `types.mbt` | 当前用户域 |
| admin | `src/admin/{admin,user,storage,driver,setting,index}.mbt` | 管理域六个子域 |
| fs | `src/fs/{fs,manage,upload,multipart,archive}.mbt` `bodies.mbt` `types.mbt` | 文件域 |
| public | `src/public/public.mbt` | 公共域 |
| share | `src/share/{share,types}.mbt` | 分享域 |
| main | `src/main/main.mbt` | 可运行示例（`moon run src/main`） |

所有生产文件都 ≤ 300 行（RL-04）；测试文件同样受该约束，因此按主题拆分
（如 `fs_wbtest.mbt` / `manage_wbtest.mbt` / `upload_wbtest.mbt`）。

## 9. 测试策略（全程不联网）

- 公开 API 里没有传输层参数；注入点是内部的
  `@core.Client::new(settings, credentials, transport?)`（根包的私有 `new_client`
  透传它），测试注入 moonhttp 的 `@transport.MockTransport`。
- 请求体是 JSON / urlencoded 的域（auth、user、admin、public、share）直接用
  `MockTransport`：`received()` 拿请求列表，断言 URL、`Authorization` 头、
  `RequestBody::Buffered` 里的 JSON 字段。
- **流式请求体**（`/api/fs/put`、`/api/fs/multipart/chunk`）不能用
  `MockTransport`：它只记录流的引用、不消费，测试结束会触发 async 运行时的
  `Dead lock detected … still alive`（SIGABRT）。`src/fs/fs_wbtest.mbt` 里自制了
  `DrainingTransport`：实现 `@transport.Transport`，对
  `RequestBody::Stream(stream)` 用 `stream.reader.read_some()` 把流泵干再返回预制
  响应。
- 快照型断言用 `assert_eq` / `assert_true`；不需要 `moon test --update`。
- 运行：`moon test`（`moon check` 应 0 error / 0 warning）。

## 10. 已知限制

1. 账号密码凭证下，**并发**的首次调用可能发出两次登录请求（无锁；结果一致）。
2. token 过期**不会**主动刷新，只在你这次请求收到 401 时重登一次。
3. 时间字段统一为 RFC3339 字符串（`String` / `String?`），不引时间库，不解析成
   时间类型。
4. 开放取值集合（驱动名、任务状态、`order_by` 等）用 `String` / `Int` 表达，
   不建枚举，避免服务端加值即破。
5. 请求 URL 的查询参数按拼装顺序发出，不做字典序重排。

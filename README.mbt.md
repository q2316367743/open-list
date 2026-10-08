# q2316367743/open-list

MoonBit 版 [OpenList](https://github.com/OpenListTeam/OpenList) API 客户端：
一个门面（`OpenListClient`）+ 六个功能域子模块，HTTP 层用
[`q2316367743/moonhttp`](https://mooncakes.io/docs/q2316367743/moonhttp)。

- 支持 OpenList 的两种认证方式：**永久 token**，或**账号密码**（首次请求前
  自动登录换取限时 token）。
- 六个域各自独立成包，但共享同一份认证状态：`client.auth().login(...)` 之后，
  `client.fs()` 立刻可用。
- 每个端点都有类型化方法；没封装的端点用 `client.request(...)` 逃生通道。
- 契约以 **OpenList v4 服务端源码**为准（官方 API 文档有出入的地方在
  `docs/` 里逐条标出）。

## 安装

```bash
moon add q2316367743/open-list
```

## 快速开始

```moonbit
///|
async fn main {
  // 方式一：永久 token
  let client = @open-list.create_open_list_client_with_token(
    "https://openlist.example.com",
    "YOUR_PERMANENT_TOKEN",
  )

  // 方式二：账号密码（第一次需要认证的请求前自动登录）
  let client = @open-list.create_open_list_client(
    @open-list.Settings::new("https://openlist.example.com"),
    @open-list.Credentials::password("admin", "your-password"),
  )

  try {
    let entries = client.fs().list("/")
    println("共 \{entries.total} 项")
    println(client.public().init_status().initialized)
  } catch {
    @open-list.OpenListError::Api(error) => println("业务错误 \{error.code}: \{error.message}")
    error => println("请求失败：\{error.message()}")
  }
}
```

## 六个子模块

| 访问器 | 包 | 覆盖 |
|--------|----|------|
| `client.auth()` | `src/auth` | 登录（明文 / 预哈希 / LDAP）、退出、两步验证 |
| `client.user()` | `src/user` | `/api/me`、改资料、自己的 SSH 公钥 |
| `client.admin()` | `src/admin` | 元信息、用户、存储、驱动、设置、索引 |
| `client.fs()` | `src/fs` | 列目录 / 读取、文件管理、上传（流式 / 分片）、归档、离线下载 |
| `client.public()` | `src/public` | 站点设置、离线下载工具、归档扩展名、初始化 |
| `client.share()` | `src/share` | 分享记录的增删改查与启停 |

`OpenListClient` 还提供：

| 成员 | 说明 |
|------|------|
| `settings()` | 连接设置（`base_url` 已去掉结尾 `/`） |
| `token()` / `set_token(String?)` / `is_logged_in()` | 共享认证状态 |
| `request(method, path, query?, body?, headers?)` | 直接调用任意 `/api/...`，返回信封里的 `data` |

匿名访问（如 `/api/public/*`）用 `create_open_list_client_with_token(base_url, "")`：
空 token 表示不发 `Authorization` 头。

## 文档

技术文档在 [`docs/`](./docs/README.md)：

| 编号 | 主题 |
|------|------|
| 00 | [架构与分层](./docs/00-architecture.md) |
| 01 | [认证 Authentication](./docs/01-auth.md) |
| 02 | [当前用户 User](./docs/02-user.md) |
| 03 | [管理 Admin](./docs/03-admin.md) |
| 04 | [文件系统 File System](./docs/04-file-system.md) |
| 05 | [公共 Public](./docs/05-public.md) |
| 06 | [分享 Sharing](./docs/06-sharing.md) |
| 07 | [JSON 建模约定](./docs/07-json-modeling.md) |
| 08 | [未封装的端点与逃生通道](./docs/08-unsupported-endpoints.md) |
| 09 | [真机联调程序](./docs/09-manual-integration-test.md) |

## 开发

```bash
moon check        # 静态检查
moon test         # 全部测试（不联网，注入 Mock 传输层）
moon fmt          # 格式化
moon info         # 更新 .mbti
moon run src/main # 真机联调程序（永久 token 模式，见 docs/09）
```

## 已知限制

- 账号密码凭证下，并发首次调用可能发出两次登录请求（结果一致）。
- token 过期不主动刷新，只在这次请求收到 401 时重登一次。
- 时间统一是 RFC3339 字符串；开放取值集合用 `String` / `Int`，不建枚举。
- SSO、WebAuthn、任务域、扫描、种子等未封装，见
  [docs/08](./docs/08-unsupported-endpoints.md)。

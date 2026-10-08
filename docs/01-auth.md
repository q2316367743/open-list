# 01 · 认证 Authentication

包：`src/auth/`（`auth.mbt`、`types.mbt`）。服务端：`server/handles/auth.go`，
路由前缀 `/api/auth*`（另有 `/api/authn/*` 属于 WebAuthn，见 [08](./08-unsupported-endpoints.md)）。

## 1. token 存在哪里

认证 token **不属于本域**：它存在 `core.Client` 的 `@ref.Ref[String?]` 里，六个域
共享同一份状态（详见 [00](./00-architecture.md) 第 4 节）。所以 `client.auth().login(...)`
成功之后，`client.fs()`、`client.admin()` 立刻就能用新 token 发请求。

请求头形如 `Authorization: <token>`——**没有 `Bearer ` 前缀**（OpenList 的
security scheme 明确要求直接放 token）。

## 2. 方法一览

| 方法 | 端点 | 说明 |
|------|------|------|
| `Auth::login(String username, String password, otp_code? : String) -> String` | `POST /api/auth/login` | 明文密码登录；成功写入并返回 token |
| `Auth::login_hash(String username, String hashed_password, otp_code? : String) -> String` | `POST /api/auth/login/hash` | 密码**已经是**静态哈希时用这条 |
| `Auth::login_ldap(String username, String password, otp_code? : String) -> String` | `POST /api/auth/login/ldap` | LDAP 登录 |
| `Auth::logout() -> Unit` | `GET /api/auth/logout` | 服务端作废 token，并清空本地 token |
| `Auth::generate_2fa() -> TwoFactorAuth` | `POST /api/auth/2fa/generate` | 初始化两步验证，返回 `{qr, secret}` |
| `Auth::verify_2fa(String code, String secret) -> Unit` | `POST /api/auth/2fa/verify` | 用 6 位码绑定 |
| `Auth::token() -> String?` / `set_token(String?)` / `is_logged_in() -> Bool` | — | 共享状态的读 / 写 / 判断 |

`login` / `login_hash` / `login_ldap` 三个方法的语义差别只在于 `password` 字段
怎么用（明文 / 预哈希 / 明文送 LDAP），请求体都是
`{username, password, otp_code?}`。

## 3. 契约细节

- **`otp_code` 为空时整个字段不发**（`derive(ToJson)` 对 `None` 字段省略，见
  [07](./07-json-modeling.md)）。服务端只在字段非空时校验 2FA。
- ⚠️ **登录响应只有 token**：`data = {"token": "…"}`，**没有** `expires_in` /
  `expires_at`。官方文档里写的有效期字段在源码里不存在，因此客户端不维护过期
  时间，也不做定时刷新（见 [00](./00-architecture.md) 第 4 节「401 重登一次」）。
- **静态哈希**：OpenList 前端在提交前对密码做 SHA-256（十六进制）再调
  `/api/auth/login/hash`；`/api/auth/login` 则由服务端对收到的明文做同样的处理。
  本库**不内置 SHA-256**——`login_hash` 只接受已经算好的哈希字符串。要自己算
  可以引 `moonbitlang/x` 的 crypto 包，或者直接用 `login` 让服务端算。
- **失败码**（`ErrorResponse` 信封，客户端统一抛 `OpenListError::Api`）：
  - `401 Invalid username or password`
  - `402 Invalid 2FA code`
  - `429 Too many unsuccessful sign-in attempts…`（同一来源 IP 连续失败 5 次后
    被锁 5 分钟，与用户名无关）
- `decode_token` 是**严格**的：`data` 不是对象、缺 `token`、`token` 不是字符串、
  或 `token` 为空串，都会抛
  `OpenListError::Decode("登录响应缺少 token")`，而不是让调用方拿着空 token
  到处 401。

## 4. `logout` 的语义

- 端点是 **`GET /api/auth/logout`**（不是 POST）。
- 未登录（`is_logged_in()` 为 false）时**直接返回、不发请求**，因此可以放心地
  当幂等清理调用。
- 已经登录时先发请求让服务端作废 token，然后用 `errdefer` 保证**无论成功还是
  失败都会清空本地 token**（否则网络异常会留下一个「本地以为已登录、服务端已
  作废」的僵尸状态）。

## 5. 两步验证流程

```moonbit
let tfa = client.auth().generate_2fa()   // tfa.qr 是 data:image/png;base64,…，给用户扫
println(tfa.qr)
client.auth().verify_2fa(code, tfa.secret)  // 用户输入验证器里的 6 位码
```

⚠️ 服务端返回的字段名是 **`qr`**（官方文档里写成 `qr_code`）。本项目以源码为准；
`TwoFactorAuth` 因此是手写 `FromJson`（`src/auth/types.mbt`），字段就是
`qr` / `secret`。

## 6. 示例

```moonbit
// 方式一：永久 token，创建即用
let client = @open-list.create_open_list_client_with_token("https://openlist.example.com", token)

// 方式二：账号密码（第一次需要认证的请求前自动登录，换取限时 token）
let client = @open-list.create_open_list_client(
  @open-list.Settings::new("https://openlist.example.com"),
  @open-list.Credentials::password("admin", "secret"),
)
// 也可以显式登录并拿回 token
let token = client.auth().login("admin", "secret")
println(client.auth().is_logged_in())  // true
client.auth().set_token(None)          // 只清本地，不通知服务端
client.auth().logout()                 // 让服务端也作废，并清本地
```

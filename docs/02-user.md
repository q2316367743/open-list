# 02 · 当前用户 User

包：`src/user/`（`user.mbt`、`types.mbt`）。服务端：`server/handles/user.go`、
`server/handles/sshkey.go`，路由前缀 `/api/me*`。

本域是「操作自己」；操作别人（增删用户、取消他人 2FA 等）在
[03 · 管理 Admin](./03-admin.md) 的 user 子域。

## 1. 方法一览

| 方法 | 端点 | 说明 |
|------|------|------|
| `UserApi::me() -> UserResponse` | `GET /api/me` | 当前用户信息 + 是否开启 2FA |
| `UserApi::update(UpdateMeRequest) -> Unit` | `POST /api/me/update` | 改用户名 / 密码 / SSO 绑定 |
| `UserApi::list_ssh_keys(page?, per_page?) -> PageResult[SSHPublicKey]` | `GET /api/me/sshkey/list` | 自己的 SSH 公钥（分页信封） |
| `UserApi::add_ssh_key(String title, String key) -> Unit` | `POST /api/me/sshkey/add` | 添加公钥 |
| `UserApi::delete_ssh_key(id : UInt) -> Unit` | `POST /api/me/sshkey/delete?id=` | 删除公钥（id 来自上一条） |

以上都要求已登录；未登录时服务端返回 401，客户端抛 `OpenListError::Api`。

## 2. `me()` 的返回

```moonbit
pub struct UserResponse {
  user : User   // 服务端把 password 置空
  otp : Bool    // 当前用户是否开启了两步验证
}
```

`User` 的字段：`id : UInt`、`username`、`password`、`base_path`、`role : Int`、
`disabled : Bool`、`permission : Int`、`sso_id`、`allow_ldap`。

⚠️ 官方文档把 `/api/me` 的响应描述成裸 `User`；源码里是
`UserResp{ model.User; OTP bool }`，所以这里是 `UserResponse{user, otp}`（`user`
而不是平铺字段）。

## 3. `update(UpdateMeRequest)` 的语义

```moonbit
pub struct UpdateMeRequest {
  username : String     // 必填：服务端无条件用请求里的 username 覆盖原值
  password : String?    // None = 不改密码；改密码不要求旧密码
  sso_id : String?      // None = 不改；非空表示绑定 SSO
}
UpdateMeRequest::new("newname", password="newpass")
```

- `username` **不是可选的**：服务端实现是「拿到什么就覆盖什么」，不传
  `username` 会把用户名清空/置乱，所以这里做成必填参数。
- ⚠️ 官方文档里出现过 `old_password` 字段，**源码的 `/api/me/update` 不读它**。
- `password` / `sso_id` 为 `None` 时字段不会出现在请求体里（见
  [07](./07-json-modeling.md)）。

## 4. SSH 公钥

`SSHPublicKey` 字段：`id : UInt`、`title`、`fingerprint`、`added_time`、
`last_used_time`（都是 RFC3339 字符串）。**公钥正文（`key`）不会回传**——
服务端里该字段是 `json:"-"`，所以列表里看不到原文，需要自己保存。

- `add_ssh_key(title, key)`：请求体 `{title, key}`；`title` 非空，`key` 是
  `ssh-ed25519 AAAA…` 这类文本（首尾空白由服务端裁剪）。格式非法或重复添加时
  服务端返回 400。
- `delete_ssh_key(id)`：id 是 `UInt`，来自 `list_ssh_keys`。

## 5. 示例

```moonbit
let me = client.user().me()
println(me.user.username)
println(me.otp)

client.user().update(@open-list.UpdateMeRequest::new(me.user.username, password="newpass"))

let keys = client.user().list_ssh_keys(page=1, per_page=20)
for key in keys.content {
  println("\{key.id} \{key.title} \{key.fingerprint}")
}
client.user().add_ssh_key("笔记本", "ssh-ed25519 AAAAC3Nza… me@laptop")
client.user().delete_ssh_key(keys.content[0].id)
```

///|
/// 「当前登录用户」域的请求类型。

///|
/// 修改当前用户资料的请求体（`POST /api/me/update`）。
///
/// 服务端的实现是「拿到什么就覆盖什么」，只读三个字段：
/// `username`（无条件覆盖，所以这里是必填的 `String`）、`password`
/// （空串/不传表示不改密码）、`sso_id`（SSO 绑定标识）。
pub struct UpdateMeRequest {
  /// 新用户名（必填；服务端不会保留旧值）。
  username : String
  /// 新密码；`None` 表示不改。
  password : String?
  /// 要绑定的 SSO 标识；`None` 表示不改。
  sso_id : String?
} derive(ToJson)

///|
/// 显式声明 `derive` 出来的 `ToJson` 实现以普通方法暴露。
pub extend AddSSHKeyRequest with ToJson::{to_json}

///|
/// 显式声明 `derive` 出来的 `ToJson` 实现以普通方法暴露。
pub extend UpdateMeRequest with ToJson::{to_json}

///|
/// 新增 SSH 公钥的请求体（`POST /api/me/sshkey/add`）。
pub struct AddSSHKeyRequest {
  /// 备注名（必填，服务端要求非空）。
  title : String
  /// 公钥内容（`ssh-ed25519 AAAA...` 这类文本，首尾空白由服务端裁剪）。
  key : String
} derive(ToJson)

///|
/// 构造一份修改资料请求；只改密码时也建议带上当前用户名。
pub fn UpdateMeRequest::new(
  username : String,
  password? : String,
  sso_id? : String,
) -> UpdateMeRequest {
  { username, password, sso_id, }
}

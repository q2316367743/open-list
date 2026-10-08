///|
/// 账号密码凭证。
///
/// OpenList 服务端会在这条通道上做静态哈希，所以这里传**明文**密码；
/// 想做「前端已预哈希」的登录请改用 `login_hash`。
pub struct PasswordCredentials {
  /// 用户名。
  username : String
  /// 明文密码。
  password : String
  /// 两步验证码；服务端为该账号开启 2FA 时必填，否则留 `None`。
  otp_code : String?
}

///|
/// 创建账号密码凭证。
pub fn PasswordCredentials::new(
  username : String,
  password : String,
  otp_code? : String,
) -> PasswordCredentials {
  { username, password, otp_code, }
}

///|
/// 认证凭证：OpenList 支持的两种认证方式二选一。
///
/// - `Token`：后台生成的永久 token，直接拿来用；
/// - `Password`：账号密码，客户端在第一次需要认证的请求前自动登录，
///   换取一个限时 token（服务端过期后由客户端在收到 401 时重登一次）。
pub(all) enum Credentials {
  /// 永久 token。
  Token(String)
  /// 账号密码。
  Password(PasswordCredentials)
}

///|
/// 用永久 token 创建凭证（后台「设置 → 其他 → 令牌」生成的那个）。
pub fn Credentials::token(token : String) -> Credentials {
  Token(token)
}

///|
/// 创建账号密码凭证的便捷构造器。
pub fn Credentials::password(
  username : String,
  password : String,
  otp_code? : String,
) -> Credentials {
  Password(PasswordCredentials::new(username, password, otp_code?))
}

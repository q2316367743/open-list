///|
/// 认证域。
///
/// 两种认证方式都由 core 的 `Client` 统一处理：
///
/// - 直接给永久 token（`create_open_list_client_with_token`）——此时
///   `login` 不必要，`is_logged_in()` 一开始就是 `true`；
/// - 给账号密码（`Credentials::password`）——客户端在第一个需要认证的请求
///   前自动登录换限时 token，token 过期（401）时自动重登一次。
///
/// 因此业务代码**不需要**自己调 `login`；只在「想立刻验证密码是否正确」或
/// 「想自己控制登录时机」时才手动调用，`login` 会顺手把 token 存进共享状态。
pub struct Auth {
  priv client : @core.Client
}

///|
/// 由根包创建（每个域模块的构造器都是这样，使用者拿不到伪造状态的机会）。
pub fn Auth::new(client : @core.Client) -> Auth {
  { client, }
}

///|
/// 用账号密码登录（`POST /api/auth/login`）。
///
/// 服务端会对请求里的密码做静态哈希后再校验，所以这里传**明文**密码。
/// 返回并记住换来的限时 token。常见失败：401 用户名或密码错误、
/// 402 两步验证码错误、429 失败次数过多（同一 IP 5 次后锁 5 分钟）。
pub async fn Auth::login(
  self : Auth,
  username : String,
  password : String,
  otp_code? : String,
) -> String raise @core.OpenListError {
  let token = self.request_token(
    "/api/auth/login", username, password, otp_code,
  )
  self.client.set_token(Some(token))
  token
}

///|
/// 用「前端已做静态哈希」的密码登录（`POST /api/auth/login/hash`）。
///
/// 服务端不会再哈希，因此 `hashed_password` 必须是 `SHA256(密码 + "-" + salt)`
/// 形式的结果；本模块**不**实现哈希算法，需要的话在调用方算好再传进来。
pub async fn Auth::login_hash(
  self : Auth,
  username : String,
  hashed_password : String,
  otp_code? : String,
) -> String raise @core.OpenListError {
  let token = self.request_token(
    "/api/auth/login/hash", username, hashed_password, otp_code,
  )
  self.client.set_token(Some(token))
  token
}

///|
/// 用 LDAP 账号登录（`POST /api/auth/login/ldap`）。
pub async fn Auth::login_ldap(
  self : Auth,
  username : String,
  password : String,
  otp_code? : String,
) -> String raise @core.OpenListError {
  let token = self.request_token(
    "/api/auth/login/ldap", username, password, otp_code,
  )
  self.client.set_token(Some(token))
  token
}

///|
/// 三个登录端点共用的请求逻辑。
async fn Auth::request_token(
  self : Auth,
  path : String,
  username : String,
  password : String,
  otp_code : String?,
) -> String raise @core.OpenListError {
  let body = LoginBody::{ username, password, otp_code, }
  let data = self.client.request(
    @moonhttp.Method::Post,
    path,
    body=@json.to_json(body),
  )
  decode_token(data)
}

///|
/// 退出登录（`GET /api/auth/logout`）：让服务端作废当前 token，并清空本地状态。
///
/// 本来就没登录时直接返回，不发请求。服务端即使报错（例如 token 已失效）
/// 本地状态同样会被清空——退出登录不该因为网络问题而失败在半途。
pub async fn Auth::logout(self : Auth) -> Unit raise @core.OpenListError {
  if !self.client.is_logged_in() {
    return
  }
  errdefer self.client.set_token(None)
  let _ = self.client.request(@moonhttp.Method::Get, "/api/auth/logout")
  self.client.set_token(None)
}

///|
/// 当前 token；永久 token 一开始就有，账号密码凭证则是登录后才有。
pub fn Auth::token(self : Auth) -> String? {
  self.client.token()
}

///|
/// 是否已持有 token。
pub fn Auth::is_logged_in(self : Auth) -> Bool {
  self.client.is_logged_in()
}

///|
/// 直接设置 token（从外部持久化状态恢复会话，或主动作废）。
pub fn Auth::set_token(self : Auth, token : String?) -> Unit {
  self.client.set_token(token)
}

///|
/// 生成两步验证密钥与二维码（`POST /api/auth/2fa/generate`）。
///
/// 需要已登录。真正的开启动作是随后调用 `verify_2fa`。
pub async fn Auth::generate_2fa(
  self : Auth,
) -> TwoFactorAuth raise @core.OpenListError {
  let data = self.client.request(
    @moonhttp.Method::Post,
    "/api/auth/2fa/generate",
  )
  @core.decode_data(data)
}

///|
/// 用验证器上的 6 位码开启两步验证（`POST /api/auth/2fa/verify`）。
pub async fn Auth::verify_2fa(
  self : Auth,
  code : String,
  secret : String,
) -> Unit raise @core.OpenListError {
  let body = VerifyTwoFactorRequest::{ code, secret, }
  let _ = self.client.request(
    @moonhttp.Method::Post,
    "/api/auth/2fa/verify",
    body=@json.to_json(body),
  )
}

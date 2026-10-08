///|
/// 六个域子模块共享的 HTTP 客户端与认证状态。
///
/// 由根包的 `create_open_list_client` 创建，域子模块各持有它的一份拷贝。
/// token 存在共享的 `@ref.Ref` 里，因此各拷贝看到的是同一份登录状态：
/// 认证模块登录成功后，文件系统模块立刻就能用上新 token。
///
/// OpenList 的认证头形如 `Authorization: <token>`，**没有** `Bearer` 前缀。
pub struct Client {
  priv settings : Settings
  priv credentials : Credentials
  priv token : @ref.Ref[String?]
  priv http : @moonhttp.Client
}

///|
/// `POST /api/auth/login` 的请求体。`otp_code` 为 `None` 时整个字段不会出现在
/// JSON 里（OpenList 只在字段非空时校验两步验证码）。
priv struct LoginRequest {
  username : String
  password : String
  otp_code : String?
} derive(ToJson)

///|
/// 登录接口 `data` 的形状：`{"token": "..."}`。
priv struct TokenResponse {
  token : String
} derive(@json.FromJson)

///|
/// 创建共享客户端。`transport` 只在测试里注入 Mock 传输层，生产不传。
pub fn Client::new(
  settings : Settings,
  credentials : Credentials,
  transport? : &@moonhttp.Transport,
) -> Client {
  let base_url = settings.base_url
    .trim_end()
    .to_owned()
    .trim_end(chars="/")
    .to_owned()
  // 关掉 moonhttp 的「非 2xx 即抛错」校验：OpenList 把业务结果放在信封的
  // `code` 里，HTTP 状态码只是粗粒度映射，必须让响应体走到我们手上再判断。
  let defaults = @moonhttp.Config::default()
    .with_base_url(base_url)
    .with_validate_status(_ => true)
  let defaults = match settings.timeout {
    Some(milliseconds) => defaults.with_timeout(milliseconds)
    None => defaults
  }
  let http = match transport {
    Some(transport) => @moonhttp.Client::new(config=defaults, transport~)
    None => @moonhttp.Client::new(config=defaults)
  }
  let token = match credentials {
    // 空 token 表示匿名：公开端点用它去掉 `Authorization` 头。
    Token(value) => if value == "" { None } else { Some(value) }
    Password(_) => None
  }
  { settings, credentials, token: @ref.new(token), http, }
}

///|
/// 连接设置。
pub fn Client::settings(self : Client) -> Settings {
  self.settings
}

///|
/// 当前使用的认证凭证。
pub fn Client::credentials(self : Client) -> Credentials {
  self.credentials
}

///|
/// 当前 token；尚未登录（账号密码凭证且还没登录过）时是 `None`。
pub fn Client::token(self : Client) -> String? {
  self.token.val
}

///|
/// 直接覆盖 token，用于从外部持久化状态恢复会话，或主动让 token 失效。
pub fn Client::set_token(self : Client, token : String?) -> Unit {
  self.token.val = token
}

///|
/// 是否已有可用 token（永久 token，或账号密码换来的限时 token）。
pub fn Client::is_logged_in(self : Client) -> Bool {
  self.token.val is Some(_)
}

///|
/// 账号密码凭证才可能在 401 后重登；永久 token 过期只能换 token。
fn Client::can_relogin(self : Client) -> Bool {
  match self.credentials {
    Password(_) => true
    Token(_) => false
  }
}

///|
/// 拿到一个可用 token：永久 token 直接返回；账号密码则在首次使用时登录换取。
///
/// 已知限制：多个请求同时首次触发登录时，可能各发一次登录请求（服务端会
/// 各自签发 token，最后一次写入生效），不会造成状态错乱。
pub async fn Client::ensure_token(self : Client) -> String raise OpenListError {
  match self.token.val {
    Some(value) => value
    None =>
      match self.credentials {
        Token(value) =>
          if value == "" {
            // 匿名凭证：不带凭证直接请求。
            value
          } else {
            self.token.val = Some(value)
            value
          }
        Password(credentials) => {
          let value = self.password_login(credentials)
          self.token.val = Some(value)
          value
        }
      }
  }
}

///|
/// 用账号密码换限时 token（`POST /api/auth/login`）。
///
/// 这是**唯一**会主动登录的地方，它不经过 `ensure_token`，所以不会递归。
/// 常见的失败是 401（用户名或密码错误）与 402（两步验证码错误）。
pub async fn Client::password_login(
  self : Client,
  credentials : PasswordCredentials,
) -> String raise OpenListError {
  let request = LoginRequest::{
    username: credentials.username,
    password: credentials.password,
    otp_code: credentials.otp_code,
  }
  let (status, envelope) = self.send_envelope(
    @moonhttp.Method::Post,
    "/api/auth/login",
    body=@json.to_json(request),
  )
  envelope.check(status)
  let response : TokenResponse = decode_data(envelope.data_or_null())
  response.token
}

///|
/// 给配置挂上认证头与调用方自定义头，发出去，再把响应文本解析成信封。
///
/// 调用方自定义头后写，因此可以覆盖 `Authorization`。
async fn Client::execute(
  self : Client,
  config : @moonhttp.Config,
  headers? : Array[(String, String)],
) -> (Int, Envelope) raise OpenListError {
  let mut config = config
  // 空 token 等于「匿名」：不带认证头。这样 `Credentials::Token("")` 就能
  // 拿来访问 `/api/public/*` 与可选认证的 `/api/fs/*`（服务端按游客处理）。
  match self.token.val {
    Some(token) =>
      if token != "" {
        config = config.with_header("Authorization", token)
      }
    None => ()
  }
  match headers {
    Some(pairs) =>
      for pair in pairs {
        let (key, value) = pair
        config = config.with_header(key, value)
      }
    None => ()
  }
  let response = self.http.request(config) catch {
    error => raise OpenListError::Http(error)
  }
  (response.status, Envelope::parse(response.status, response.text()))
}

///|
/// 普通 JSON 请求：拼配置后交给 `execute`。它不触发登录、也不检查 `code`，
/// 由调用方决定怎么处理信封（`request` 与各域子模块都走它）。
async fn Client::send_envelope(
  self : Client,
  http_method : @moonhttp.Method,
  path : String,
  query? : Json,
  body? : Json,
  headers? : Array[(String, String)],
) -> (Int, Envelope) raise OpenListError {
  let mut config = @moonhttp.Config::new(path)
    .with_method(http_method)
    .with_validate_status(_ => true)
  match query {
    Some(params) => config = config.with_params(params)
    None => ()
  }
  match body {
    Some(payload) => config = config.with_data_from_json(payload)
    None => ()
  }
  self.execute(config, headers?)
}

///|
/// 发送一个 JSON 请求，返回信封里的 `data`（原样，不做 `null` 剔除）。
///
/// 这是六个域子模块的统一出口，也是留给使用者的逃生通道：官方客户端没有
/// 封装的端点可以直接用它打到 `/api/...`（见 `docs/08-unsupported-endpoints.md`）。
///
/// 认证自动完成：收到 401 且凭证是账号密码时，会清掉旧 token 重登一次再
/// 重试一次；用永久 token 时直接报错（重试也没有意义）。
pub async fn Client::request(
  self : Client,
  http_method : @moonhttp.Method,
  path : String,
  query? : Json,
  body? : Json,
  headers? : Array[(String, String)],
) -> Json raise OpenListError {
  let _ = self.ensure_token()
  let (status, envelope) = self.send_envelope(
    http_method,
    path,
    query?,
    body?,
    headers?,
  )
  if envelope.code == 200 {
    return envelope.data_or_null()
  }
  if envelope.code == 401 && self.can_relogin() {
    self.token.val = None
    let _ = self.ensure_token()
    let (retry_status, retry_envelope) = self.send_envelope(
      http_method,
      path,
      query?,
      body?,
      headers?,
    )
    retry_envelope.check(retry_status)
    return retry_envelope.data_or_null()
  }
  envelope.check(status)
  envelope.data_or_null()
}

///|
/// 发送请求体来自流的请求（二进制上传）。
///
/// 用于 `/api/fs/put`、`/api/fs/multipart/chunk` 这类「body 就是原始字节」的
/// 端点——moonhttp 的请求体构造器没有裸字节那一档，二进制只能走流。
/// 与 `request` 一样检查信封，但不做 401 重试。
pub async fn Client::send_stream(
  self : Client,
  http_method : @moonhttp.Method,
  path : String,
  reader : &@io.Reader,
  content_length? : Int,
  headers? : Array[(String, String)],
) -> Json raise OpenListError {
  let _ = self.ensure_token()
  let mut config = @moonhttp.Config::new(path)
    .with_method(http_method)
    .with_validate_status(_ => true)
  config = match content_length {
    Some(length) => config.with_data_from_stream(reader, content_length=length)
    None => config.with_data_from_stream(reader)
  }
  let (status, envelope) = self.execute(config, headers?)
  envelope.check(status)
  envelope.data_or_null()
}

///|
/// 发送 multipart/form-data 请求（`PUT /api/fs/form`）。
pub async fn Client::send_form(
  self : Client,
  http_method : @moonhttp.Method,
  path : String,
  form : @moonhttp.FormData,
  headers? : Array[(String, String)],
) -> Json raise OpenListError {
  let _ = self.ensure_token()
  let config = @moonhttp.Config::new(path)
    .with_method(http_method)
    .with_validate_status(_ => true)
    .with_data_from_form(form)
  let (status, envelope) = self.execute(config, headers?)
  envelope.check(status)
  envelope.data_or_null()
}

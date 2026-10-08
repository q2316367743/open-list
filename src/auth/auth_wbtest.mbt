///|
/// 认证域的白盒测试：用 `@transport.MockTransport` 预置响应，全程不联网、不需要
/// 真实服务端。覆盖三条登录路径、token 状态流转与退出登录。

///|
/// 造一个 JSON 响应。
fn raw_json(status : Int, body : String) -> @transport.RawResponse {
  {
    status,
    status_text: "OK",
    headers: @transport.Headers::new().set("Content-Type", "application/json"),
    set_cookies: [],
    body: @transport.ResponseBody::from_bytes(@utf8.encode(body)),
  }
}

///|
/// 造一个认证子模块 + Mock 传输层；初始没有任何 token（匿名）。
fn auth_with(
  responses : Array[@transport.RawResponse],
) -> (Auth, @transport.MockTransport) {
  let mock = @transport.MockTransport::from_responses(responses)
  let transport : &@moonhttp.Transport = mock
  let client = @core.Client::new(
    @core.Settings::new("https://openlist.example.com/"),
    @core.Credentials::Token(""),
    transport~,
  )
  (Auth::new(client), mock)
}

///|
/// 把请求体当 JSON 读出来（只能是缓冲形态）。
fn body_json(request : @transport.PreparedRequest) -> Json raise {
  match request.body {
    Some(@transport.RequestBody::Buffered(bytes)) =>
      @json.parse(@utf8.decode(bytes))
    _ => panic()
  }
}

///|
/// 取 JSON 对象里的字段；不是对象或字段缺失都直接让测试失败。
fn field(json : Json, key : String) -> Json {
  match json {
    Object(fields) =>
      match fields.get(key) {
        Some(value) => value
        None => panic()
      }
    _ => panic()
  }
}

///|
/// 断言 JSON 里的字符串字段。
fn assert_json_string(
  json : Json,
  key : String,
  expected : String,
) -> Unit raise {
  let actual = match field(json, key) {
    String(value) => value
    _ => panic()
  }
  assert_eq(actual, expected)
}

///|
/// 断言 JSON 对象里没有这个键（`derive(ToJson)` 会省略值为 `None` 的字段）。
fn assert_absent(json : Json, key : String) -> Unit {
  match json {
    Object(fields) =>
      match fields.get(key) {
        Some(_) => panic()
        None => ()
      }
    _ => panic()
  }
}

///|
async test "login：POST /api/auth/login，成功后记住 token" {
  let (auth, mock) = auth_with([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"token\":\"jwt-1\"}}",
    ),
  ])
  assert_true(!auth.is_logged_in())
  let token = auth.login("admin", "secret")
  assert_eq(token, "jwt-1")
  assert_eq(auth.token(), Some("jwt-1"))
  assert_true(auth.is_logged_in())
  let request = mock.last_request().unwrap()
  assert_eq(request.url, "https://openlist.example.com/api/auth/login")
  assert_eq(request.http_method, @moonhttp.Method::Post)
  let body = body_json(request)
  assert_json_string(body, "username", "admin")
  assert_json_string(body, "password", "secret")
  // `derive(ToJson)` 省略值为 `None` 的字段，所以没传 otp_code 时请求体里没有这个键。
  assert_absent(body, "otp_code")
}

///|
async test "login_hash：密码原样进请求体（调用方已做静态哈希）" {
  let (auth, mock) = auth_with([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"token\":\"jwt-2\"}}",
    ),
  ])
  let token = auth.login_hash("admin", "deadbeef")
  assert_eq(token, "jwt-2")
  let request = mock.last_request().unwrap()
  assert_eq(request.url, "https://openlist.example.com/api/auth/login/hash")
  assert_json_string(body_json(request), "password", "deadbeef")
}

///|
async test "login_ldap：走 /api/auth/login/ldap，otp_code 一并带上" {
  let (auth, mock) = auth_with([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"token\":\"jwt-3\"}}",
    ),
  ])
  let _ = auth.login_ldap("u", "p", otp_code="123456")
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/auth/login/ldap",
  )
  assert_json_string(
    body_json(mock.last_request().unwrap()),
    "otp_code",
    "123456",
  )
}

///|
async test "login 失败：401 抛 Api 错误且不留下 token" {
  let (auth, mock) = auth_with([
    raw_json(
      401, "{\"code\":401,\"message\":\"Invalid username or password\",\"data\":null}",
    ),
  ])
  let code = try {
    let _ = auth.login("admin", "bad")
    0
  } catch {
    @core.OpenListError::Api(error) => error.code
    _ => -1
  }
  assert_eq(code, 401)
  assert_eq(auth.token(), None)
  assert_eq(mock.request_count(), 1)
}

///|
async test "logout：GET /api/auth/logout 并清空本地 token" {
  let (auth, mock) = auth_with([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"token\":\"jwt-1\"}}",
    ),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
  ])
  let _ = auth.login("admin", "secret")
  auth.logout()
  assert_eq(auth.token(), None)
  let request = mock.last_request().unwrap()
  assert_eq(request.url, "https://openlist.example.com/api/auth/logout")
  assert_eq(request.http_method, @moonhttp.Method::Get)
  assert_eq(mock.request_count(), 2)
}

///|
async test "logout：本来就没登录时不发请求" {
  let (auth, mock) = auth_with([
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
  ])
  auth.logout()
  assert_eq(mock.request_count(), 0)
}

///|
async test "generate_2fa 与 verify_2fa" {
  let (auth, mock) = auth_with([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"qr\":\"data:image/png;base64,AAA\",\"secret\":\"SECRET\"}}",
    ),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
  ])
  let two_factor = auth.generate_2fa()
  assert_eq(two_factor.secret, "SECRET")
  assert_true(two_factor.qr.has_prefix("data:image/png"))
  auth.verify_2fa("123456", two_factor.secret)
  let request = mock.last_request().unwrap()
  assert_eq(request.url, "https://openlist.example.com/api/auth/2fa/verify")
  let body = body_json(request)
  assert_json_string(body, "code", "123456")
  assert_json_string(body, "secret", "SECRET")
}

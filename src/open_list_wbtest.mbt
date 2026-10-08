///|
/// 根包（门面）的白盒测试：验证六个域子模块确实由客户端派生、共享同一份认证
/// 状态，且逃生通道能打到未封装的端点。全程用 `@transport.MockTransport`，不联网。

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
async test "账号密码凭证：第一次请求前自动登录，之后带着限时 token" {
  let mock = @transport.MockTransport::from_responses([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"token\":\"jwt-1\"}}",
    ),
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"id\":1,\"username\":\"admin\",\"password\":\"\",\"base_path\":\"/\",\"role\":0,\"disabled\":false,\"permission\":0,\"sso_id\":\"\",\"allow_ldap\":false,\"otp\":false}}",
    ),
  ])
  let transport : &@moonhttp.Transport = mock
  let client = new_client(
    @core.Settings::new("https://openlist.example.com"),
    @core.Credentials::password("admin", "secret"),
    transport~,
  )
  assert_eq(client.token(), None)
  let me = client.user().me()
  assert_eq(me.user.username, "admin")
  assert_true(client.is_logged_in())
  assert_eq(client.token(), Some("jwt-1"))
  let requests = mock.received()
  assert_eq(requests.length(), 2)
  assert_eq(requests[0].url, "https://openlist.example.com/api/auth/login")
  assert_eq(requests[1].url, "https://openlist.example.com/api/me")
  assert_eq(requests[1].headers.get("Authorization"), Some("jwt-1"))
  let login_body = body_json(requests[0])
  assert_json_string(login_body, "username", "admin")
  assert_json_string(login_body, "password", "secret")
}

///|
test "永久 token：创建即可用，base_url 结尾的斜杠被去掉" {
  let client = create_open_list_client_with_token(
    "https://openlist.example.com/", "t0ken",
  )
  assert_eq(client.settings().base_url, "https://openlist.example.com")
  assert_eq(client.token(), Some("t0ken"))
  assert_true(client.is_logged_in())
}

///|
test "六个子模块都由客户端派生并共享认证状态" {
  let client = create_open_list_client_with_token(
    "https://openlist.example.com", "t0ken",
  )
  assert_true(client.auth().is_logged_in())
  assert_eq(client.auth().token(), Some("t0ken"))
  let _ = client.user()
  let _ = client.admin()
  let _ = client.fs()
  let _ = client.public()
  let _ = client.share()
}

///|
test "set_token 让 token 立即对所有子模块生效" {
  let client = create_open_list_client_with_token(
    "https://openlist.example.com", "old",
  )
  client.set_token(Some("new"))
  assert_eq(client.auth().token(), Some("new"))
  client.set_token(None)
  assert_false(client.is_logged_in())
  assert_false(client.auth().is_logged_in())
}

///|
async test "逃生通道 request：返回 data；空 token 时匿名请求" {
  let mock = @transport.MockTransport::from_responses([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"initialized\":true}}",
    ),
  ])
  let transport : &@moonhttp.Transport = mock
  let client = new_client(
    @core.Settings::new("https://openlist.example.com"),
    @core.Credentials::token(""),
    transport~,
  )
  let data = client.request(@moonhttp.Method::Get, "/api/public/init_status")
  assert_true(
    match field(data, "initialized") {
      True => true
      _ => false
    },
  )
  let request = mock.last_request().unwrap()
  assert_eq(request.url, "https://openlist.example.com/api/public/init_status")
  assert_eq(request.headers.get("Authorization"), None)
  assert_false(client.is_logged_in())
}

///|
async test "非 200 信封解码成 Api 错误：可用错误构造子捕获" {
  let mock = @transport.MockTransport::from_responses([
    raw_json(401, "{\"code\":401,\"message\":\"unauthorized\",\"data\":null}"),
  ])
  let transport : &@moonhttp.Transport = mock
  let client = new_client(
    @core.Settings::new("https://openlist.example.com"),
    @core.Credentials::token("bad"),
    transport~,
  )
  let code = try {
    let _ = client.request(@moonhttp.Method::Get, "/api/public/init_status")
    -1
  } catch {
    OpenListError::Api(error) => error.code
    OpenListError::Http(_) => -2
    OpenListError::Decode(_) => -3
  }
  assert_eq(code, 401)
}

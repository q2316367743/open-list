///|
/// 「当前登录用户」域的白盒测试：用 `@transport.MockTransport` 预置响应，
/// 全程不联网。

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
/// 造一个用户域子模块 + Mock 传输层（带一个永久 token）。
fn user_with(
  responses : Array[@transport.RawResponse],
) -> (UserApi, @transport.MockTransport) {
  let mock = @transport.MockTransport::from_responses(responses)
  let transport : &@moonhttp.Transport = mock
  let client = @core.Client::new(
    @core.Settings::new("https://openlist.example.com/"),
    @core.Credentials::Token("t0ken"),
    transport~,
  )
  (UserApi::new(client), mock)
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
async test "me：GET /api/me，用户字段与 otp 同层" {
  let (user, mock) = user_with([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"id\":1,\"username\":\"admin\",\"password\":\"\",\"base_path\":\"/\",\"role\":0,\"disabled\":false,\"permission\":0,\"sso_id\":\"\",\"allow_ldap\":false,\"otp\":true}}",
    ),
  ])
  let response = user.me()
  assert_eq(response.user.id, 1)
  assert_eq(response.user.username, "admin")
  assert_eq(response.user.base_path, "/")
  assert_eq(response.user.password, "")
  assert_true(response.otp)
  let request = mock.last_request().unwrap()
  assert_eq(request.url, "https://openlist.example.com/api/me")
  assert_eq(request.http_method, @moonhttp.Method::Get)
  assert_eq(request.headers.get("Authorization"), Some("t0ken"))
}

///|
async test "update：POST /api/me/update；没给 password 时请求体里没有这个键" {
  let (user, mock) = user_with([
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
  ])
  user.update(UpdateMeRequest::new("admin", password="new-secret"))
  let with_password = body_json(mock.last_request().unwrap())
  assert_json_string(with_password, "username", "admin")
  assert_json_string(with_password, "password", "new-secret")
  user.update(UpdateMeRequest::new("admin"))
  let without_password = body_json(mock.last_request().unwrap())
  assert_json_string(without_password, "username", "admin")
  assert_absent(without_password, "password")
  assert_absent(without_password, "sso_id")
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/me/update",
  )
}

///|
async test "list_ssh_keys：分页信封解码成 PageResult" {
  let (user, mock) = user_with([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"content\":[{\"id\":3,\"title\":\"laptop\",\"fingerprint\":\"SHA256:xx\",\"added_time\":\"2024-01-01T00:00:00Z\",\"last_used_time\":\"0001-01-01T00:00:00Z\"}],\"total\":1}}",
    ),
  ])
  let result = user.list_ssh_keys(page=1, per_page=10)
  assert_eq(result.total, 1L)
  assert_eq(result.content.length(), 1)
  assert_eq(result.content[0].id, 3)
  assert_eq(result.content[0].title, "laptop")
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/me/sshkey/list?page=1&per_page=10",
  )
}

///|
async test "add_ssh_key 与 delete_ssh_key" {
  let (user, mock) = user_with([
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
  ])
  user.add_ssh_key("laptop", "ssh-ed25519 AAAA")
  let request = mock.received()[0]
  assert_eq(request.url, "https://openlist.example.com/api/me/sshkey/add")
  let body = body_json(request)
  assert_json_string(body, "title", "laptop")
  assert_json_string(body, "key", "ssh-ed25519 AAAA")
  user.delete_ssh_key(3)
  let deleted = mock.last_request().unwrap()
  assert_eq(deleted.http_method, @moonhttp.Method::Post)
  assert_eq(
    deleted.url,
    "https://openlist.example.com/api/me/sshkey/delete?id=3",
  )
  assert_true(deleted.body is None)
}

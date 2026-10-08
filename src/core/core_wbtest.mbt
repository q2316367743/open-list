///|
/// core 的白盒测试：全程用 Mock 传输层，不联网、不需要真实 OpenList 服务端。
///
/// 覆盖四件容易写错的事：
/// 1. `base_url` 与请求路径的拼接、`Authorization` 头（无 `Bearer` 前缀）；
/// 2. 信封里 `code != 200` 时抛业务错误、`data` 为 `null` 时也能解码；
/// 3. 账号密码凭证遇到 401 会自动重登并重试一次；
/// 4. 带类型化解码前的 `null` 剔除。

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
/// 用 Mock 传输层造客户端；返回客户端与 mock，方便断言实际发出的请求。
fn client_with(
  credentials : Credentials,
  responses : Array[@transport.RawResponse],
) -> (Client, @transport.MockTransport) {
  let mock = @transport.MockTransport::from_responses(responses)
  let transport : &@moonhttp.Transport = mock
  (
    Client::new(
      Settings::new("https://openlist.example.com/"),
      credentials,
      transport~,
    ),
    mock,
  )
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
/// 取 JSON 对象里可能不存在的字段。
fn maybe_field(json : Json, key : String) -> Json? {
  match json {
    Object(fields) => fields.get(key)
    _ => panic()
  }
}

///|
/// 断言 JSON 对象里的布尔字段。
fn assert_json_bool(json : Json, key : String, expected : Bool) -> Unit raise {
  let actual = match field(json, key) {
    True => true
    False => false
    _ => panic()
  }
  assert_eq(actual, expected)
}

///|
/// 断言 JSON 对象里的字符串字段。
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
/// 测试用的小模型：字段既可能缺失也可能显式为 `null`。
priv struct ProbeModel {
  name : String
  size : Int?
} derive(@json.FromJson)

///|
async test "永久 token：拼接 URL 并带上无 Bearer 前缀的 Authorization 头" {
  let (client, mock) = client_with(Credentials::Token("t0ken"), [
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"ok\":true}}",
    ),
  ])
  let data = client.request(@moonhttp.Method::Get, "/api/me")
  assert_json_bool(data, "ok", true)
  let requests = mock.received()
  assert_eq(requests.length(), 1)
  assert_eq(requests[0].url, "https://openlist.example.com/api/me")
  assert_eq(requests[0].headers.get("Authorization"), Some("t0ken"))
  assert_eq(requests[0].http_method, @moonhttp.Method::Get)
}

///|
async test "账号密码：首个请求先用密码换 token，再带上新 token" {
  let (client, mock) = client_with(Credentials::password("admin", "secret"), [
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"token\":\"fresh\"}}",
    ),
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"username\":\"admin\"}}",
    ),
  ])
  let data = client.request(@moonhttp.Method::Get, "/api/me")
  assert_json_string(data, "username", "admin")
  assert_eq(client.token(), Some("fresh"))
  let requests = mock.received()
  assert_eq(requests.length(), 2)
  assert_eq(requests[0].url, "https://openlist.example.com/api/auth/login")
  assert_eq(requests[0].http_method, @moonhttp.Method::Post)
  assert_eq(requests[0].headers.get("Authorization"), None)
  assert_eq(requests[1].headers.get("Authorization"), Some("fresh"))
}

///|
async test "业务错误：code 非 200 抛 Api 错误并保留状态码与消息" {
  let (client, _) = client_with(Credentials::Token("t0ken"), [
    raw_json(404, "{\"code\":404,\"message\":\"not found\",\"data\":null}"),
  ])
  let error = try {
    ignore(client.request(@moonhttp.Method::Get, "/api/me"))
    None
  } catch {
    error => Some(error)
  }
  let api = match error {
    Some(Api(api)) => api
    _ => panic()
  }
  assert_eq(api.code, 404)
  assert_eq(api.status, 404)
  assert_eq(api.message, "not found")
  assert_true(api.data is None)
}

///|
async test "账号密码收到 401 时清掉旧 token，重登并重试一次" {
  let (client, mock) = client_with(Credentials::password("admin", "secret"), [
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"token\":\"old\"}}",
    ),
    raw_json(401, "{\"code\":401,\"message\":\"token expired\",\"data\":null}"),
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"token\":\"new\"}}",
    ),
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"ok\":true}}",
    ),
  ])
  let data = client.request(@moonhttp.Method::Get, "/api/me")
  assert_json_bool(data, "ok", true)
  assert_eq(client.token(), Some("new"))
  let requests = mock.received()
  assert_eq(requests.length(), 4)
  assert_eq(requests[2].url, "https://openlist.example.com/api/auth/login")
  assert_eq(requests[3].headers.get("Authorization"), Some("new"))
}

///|
async test "永久 token 收到 401 直接报错，不做无意义的重试" {
  let (client, mock) = client_with(Credentials::Token("expired"), [
    raw_json(401, "{\"code\":401,\"message\":\"token expired\",\"data\":null}"),
  ])
  let error = try {
    ignore(client.request(@moonhttp.Method::Get, "/api/me"))
    None
  } catch {
    error => Some(error)
  }
  match error {
    Some(Api(api)) => assert_eq(api.code, 401)
    _ => panic()
  }
  assert_eq(mock.request_count(), 1)
  assert_eq(client.token(), Some("expired"))
}

///|
test "strip_nulls 递归剔除对象里的 null 字段，数组元素保留" {
  let json = @json.parse(
    "{\"a\":null,\"b\":{\"c\":null,\"d\":1},\"e\":[null,{\"f\":null}]}",
  )
  let stripped = strip_nulls(json)
  assert_true(maybe_field(stripped, "a") is None)
  let nested = field(stripped, "b")
  assert_true(maybe_field(nested, "c") is None)
  match field(nested, "d") {
    Number(value, ..) => assert_eq(value, 1.0)
    _ => panic()
  }
  match field(stripped, "e") {
    Array(items) => {
      assert_eq(items.length(), 2)
      assert_true(items[0] is Null)
      assert_true(maybe_field(items[1], "f") is None)
    }
    _ => panic()
  }
}

///|
test "decode_data：显式 null 的字段解码成 None，缺失的字段也是 None" {
  let json = @json.parse(
    "{\"name\":\"a.txt\",\"size\":null,\"extra\":{\"name\":\"b.txt\"}}",
  )
  let model : ProbeModel = decode_data(json)
  assert_eq(model.name, "a.txt")
  assert_true(model.size is None)
  let nested : ProbeModel = decode_data(field(json, "extra"))
  assert_eq(nested.name, "b.txt")
  assert_true(nested.size is None)
}

///|
test "PageResult：缺失 content/total 时退化为空列表与 0" {
  let empty : PageResult[ProbeModel] = decode_data(@json.parse("{}"))
  assert_eq(empty.content.length(), 0)
  assert_eq(empty.total, 0L)
  let page : PageResult[ProbeModel] = decode_data(
    @json.parse("{\"content\":[{\"name\":\"a\"}],\"total\":7}"),
  )
  assert_eq(page.content.length(), 1)
  assert_eq(page.content[0].name, "a")
  assert_eq(page.total, 7L)
}

///|
test "int64_from_json：Go 的 int64 是 JSON 数字，也接受字符串形态" {
  assert_eq(int64_from_json(@json.parse("17179869184")), Some(17179869184L))
  assert_eq(int64_from_json(@json.parse("\"42\"")), Some(42L))
  assert_true(int64_from_json(@json.parse("null")) is None)
  assert_true(int64_from_json(@json.parse("\"abc\"")) is None)
  let fields = match @json.parse("{\"size\":5368709120}") {
    Object(fields) => fields
    _ => panic()
  }
  assert_eq(int64_field(fields, "size"), 5368709120L)
  assert_eq(int64_field(fields, "missing"), 0L)
}

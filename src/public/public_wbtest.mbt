///|
/// 公开域的白盒测试：用 `@transport.MockTransport` 预置响应，全程不联网。

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
/// 造一个公开域子模块 + Mock 传输层（匿名，不带 token）。
fn public_with(
  responses : Array[@transport.RawResponse],
) -> (PublicApi, @transport.MockTransport) {
  let mock = @transport.MockTransport::from_responses(responses)
  let transport : &@moonhttp.Transport = mock
  let client = @core.Client::new(
    @core.Settings::new("https://openlist.example.com/"),
    @core.Credentials::Token(""),
    transport~,
  )
  (PublicApi::new(client), mock)
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
async test "settings：解码成键值对表，匿名也能调用" {
  let (api, mock) = public_with([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"site_title\":\"OpenList\",\"version\":\"v4\"}}",
    ),
  ])
  let settings = api.settings()
  assert_eq(settings.get("site_title"), Some("OpenList"))
  assert_eq(settings.get("version"), Some("v4"))
  let request = mock.last_request().unwrap()
  assert_eq(request.url, "https://openlist.example.com/api/public/settings")
  assert_eq(request.headers.get("Authorization"), None)
}

///|
async test "offline_download_tools：path 可选，缺省时不带查询串" {
  let (api, mock) = public_with([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":[\"aria2\",\"qBittorrent\"]}",
    ),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":[\"aria2\"]}"),
  ])
  let all = api.offline_download_tools()
  assert_eq(all.length(), 2)
  assert_eq(all[1], "qBittorrent")
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/public/offline_download_tools",
  )
  let scoped = api.offline_download_tools(path="/downloads")
  assert_eq(scoped.length(), 1)
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/public/offline_download_tools?path=%2Fdownloads",
  )
}

///|
async test "archive_extensions：返回扩展名数组" {
  let (api, mock) = public_with([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":[\"zip\",\"7z\"]}",
    ),
  ])
  let extensions = api.archive_extensions()
  assert_eq(extensions, ["zip", "7z"])
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/public/archive_extensions",
  )
}

///|
async test "init_status：读 initialized 标记" {
  let (api, mock) = public_with([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"initialized\":true}}",
    ),
  ])
  let status = api.init_status()
  assert_true(status.initialized)
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/public/init_status",
  )
}

///|
async test "init_setup：POST 请求体；已初始化时抛 Api 错误" {
  let (api, mock) = public_with([
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(
      400, "{\"code\":400,\"message\":\"system has already been initialized\",\"data\":null}",
    ),
  ])
  api.init_setup("admin", "pass1234", site_title="我的站")
  let request = mock.received()[0]
  assert_eq(request.url, "https://openlist.example.com/api/public/init/setup")
  assert_eq(request.http_method, @moonhttp.Method::Post)
  let body = body_json(request)
  assert_json_string(body, "username", "admin")
  assert_json_string(body, "password", "pass1234")
  assert_json_string(body, "site_title", "我的站")
  let message = try {
    api.init_setup("admin", "pass1234")
    ""
  } catch {
    @core.OpenListError::Api(error) => error.message
    _ => "unexpected"
  }
  assert_eq(message, "system has already been initialized")
}

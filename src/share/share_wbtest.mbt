///|
/// 分享域的白盒测试：用 `@transport.MockTransport` 预置响应，全程不联网。

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
/// 造一个分享域子模块 + Mock 传输层（普通用户 token）。
fn share_with(
  responses : Array[@transport.RawResponse],
) -> (ShareApi, @transport.MockTransport) {
  let mock = @transport.MockTransport::from_responses(responses)
  let transport : &@moonhttp.Transport = mock
  let client = @core.Client::new(
    @core.Settings::new("https://openlist.example.com/"),
    @core.Credentials::Token("t0ken"),
    transport~,
  )
  (ShareApi::new(client), mock)
}

///|
/// 一条分享记录的 JSON（服务端 `SharingResp` 的扁平形态）。
fn sharing_json() -> String {
  "{\"id\":\"abc\",\"pwd\":\"\",\"accessed\":1,\"max_accessed\":0,\"disabled\":false,\"remark\":\"\",\"readme\":\"\",\"header\":\"\",\"order_by\":\"\",\"order_direction\":\"\",\"extract_folder\":\"\",\"files\":[\"/docs\"],\"creator\":\"admin\",\"creator_role\":0}"
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
async test "list：GET /api/share/list，分页参数进查询串" {
  let (share, mock) = share_with([
    raw_json(
      200,
      "{\"code\":200,\"message\":\"success\",\"data\":{\"content\":[\{sharing_json()}],\"total\":1}}",
    ),
  ])
  let result = share.list(page=1, per_page=20)
  assert_eq(result.total, 1L)
  assert_eq(result.content.length(), 1)
  assert_eq(result.content[0].id, "abc")
  assert_eq(result.content[0].files, ["/docs"])
  assert_eq(result.content[0].creator, "admin")
  let request = mock.last_request().unwrap()
  assert_eq(request.http_method, @moonhttp.Method::Get)
  assert_eq(
    request.url,
    "https://openlist.example.com/api/share/list?page=1&per_page=20",
  )
}

///|
async test "get：分享 ID 是字符串，放在查询串里" {
  let (share, mock) = share_with([
    raw_json(
      200,
      "{\"code\":200,\"message\":\"success\",\"data\":\{sharing_json()}}",
    ),
  ])
  let record = share.get("abc")
  assert_eq(record.id, "abc")
  assert_eq(record.accessed, 1)
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/share/get?id=abc",
  )
}

///|
async test "create：请求体是 UpdateSharingReq，响应解码成记录" {
  let (share, mock) = share_with([
    raw_json(
      200,
      "{\"code\":200,\"message\":\"success\",\"data\":\{sharing_json()}}",
    ),
  ])
  let request = SharingUpdateRequest::new(
    ["/docs"],
    pwd="pw",
    max_accessed=10,
    remark="给同事",
    order_by="name",
  )
  let record = share.create(request)
  assert_eq(record.id, "abc")
  let sent = body_json(mock.last_request().unwrap())
  let files = match field(sent, "files") {
    Array(values) => values
    _ => panic()
  }
  assert_eq(files.length(), 1)
  assert_json_string(sent, "pwd", "pw")
  assert_json_string(sent, "remark", "给同事")
  assert_json_string(sent, "order_by", "name")
  // `derive(ToJson)` 省略值为 `None` 的字段：没给的可空字段不会出现在请求体里。
  assert_absent(sent, "expires")
}

///|
async test "update：id 与 new_id 都进请求体" {
  let (share, mock) = share_with([
    raw_json(
      200,
      "{\"code\":200,\"message\":\"success\",\"data\":\{sharing_json()}}",
    ),
  ])
  let _ = share.update(
    SharingUpdateRequest::new(["/docs"], id="abc", new_id="abc2"),
  )
  let sent = body_json(mock.last_request().unwrap())
  assert_json_string(sent, "id", "abc")
  assert_json_string(sent, "new_id", "abc2")
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/share/update",
  )
}

///|
async test "delete / enable / disable：POST + ?id=，没有请求体" {
  let (share, mock) = share_with([
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
  ])
  share.delete("abc")
  share.enable("abc")
  share.disable("abc")
  let requests = mock.received()
  assert_eq(requests.length(), 3)
  assert_eq(
    requests[0].url,
    "https://openlist.example.com/api/share/delete?id=abc",
  )
  assert_eq(
    requests[1].url,
    "https://openlist.example.com/api/share/enable?id=abc",
  )
  assert_eq(
    requests[2].url,
    "https://openlist.example.com/api/share/disable?id=abc",
  )
  for request in requests {
    assert_eq(request.http_method, @moonhttp.Method::Post)
    assert_true(request.body is None)
  }
}

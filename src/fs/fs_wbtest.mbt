///|
/// fs 读类/管理类接口的白盒测试：用自制传输层，全程不联网、不需要真实服务端。
/// fs 读类接口（list / get / dirs / search / other）的白盒测试：用自制传输层，
/// 全程不联网、不需要真实服务端。管理类的用例在 `manage_wbtest.mbt`，上传相关
/// （流式请求体、分片续传）的用例在 `upload_wbtest.mbt`。

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
/// 测试用传输层：像 `MockTransport` 一样按队列返回预置响应，但会真的把
/// **流式请求体**读完。真实传输必须泵完整个流，生成流的 `MemoryReader` 回调
/// 协程才会收尾；Mock 不消费流，那些协程会一直活着，测试结束时被 async
/// 运行时判定成死锁。
///
/// 顺带把泵出来的字节按请求记下来，于是分片内容也能断言。
struct DrainingTransport {
  responses : Array[@transport.RawResponse]
  received : Array[@transport.PreparedRequest]
  /// 每次请求泵出来的流式请求体分块（非流式请求是空数组）。
  streamed : Array[Array[Bytes]]
  mut cursor : Int
}

///|
fn DrainingTransport::new(
  responses : Array[@transport.RawResponse],
) -> DrainingTransport {
  { responses, received: [], streamed: [], cursor: 0, }
}

///|
/// 收到过的请求，按顺序。
fn DrainingTransport::received(
  self : DrainingTransport,
) -> Array[@transport.PreparedRequest] {
  self.received
}

///|
/// 第 `index` 次请求的流式请求体文本；不是流式请求就是空串。
///
/// 测试载荷都是纯 ASCII 文本，所以分块解码再拼起来就够了。
fn DrainingTransport::streamed(self : DrainingTransport, index : Int) -> String {
  match self.streamed.get(index) {
    Some(chunks) => chunks.map(fn(chunk) { @utf8.decode_lossy(chunk) }).join("")
    None => ""
  }
}

///|
impl @transport.Transport for DrainingTransport with fn send(self, request) {
  self.received.push(request)
  let chunks : Array[Bytes] = []
  match request.body {
    Some(@transport.RequestBody::Stream(stream)) =>
      while true {
        // 读取流可能以任意错误收尾（取消、连接断开……），这里只在测试里
        // 泵请求体，出错就当作读完。
        match (stream.reader.read_some() catch { _ => None }) {
          Some(chunk) => chunks.push(chunk)
          None => break
        }
      }
    _ => ()
  }
  self.streamed.push(chunks)
  if self.responses.is_empty() {
    panic()
  }
  let index = if self.cursor < self.responses.length() {
    self.cursor
  } else {
    self.responses.length() - 1
  }
  self.cursor = self.cursor + 1
  self.responses[index]
}

///|
/// 造一个文件系统子模块；返回它与传输层，方便断言实际发出的请求。
fn fs_with(
  responses : Array[@transport.RawResponse],
) -> (FileSystem, DrainingTransport) {
  let recorder = DrainingTransport::new(responses)
  let transport : &@moonhttp.Transport = recorder
  let client = @core.Client::new(
    @core.Settings::new("https://openlist.example.com/"),
    @core.Credentials::Token("t0ken"),
    transport~,
  )
  (FileSystem::new(client), recorder)
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
/// 断言 JSON 里的整数字段。
fn assert_json_int(json : Json, key : String, expected : Int) -> Unit raise {
  let actual = match field(json, key) {
    Number(value, ..) => value.to_int()
    _ => panic()
  }
  assert_eq(actual, expected)
}

///|
/// 断言某个字段压根没出现在 JSON 里（Go 侧就是零值语义）。
fn assert_absent(json : Json, key : String) -> Unit raise {
  match json {
    Object(fields) => assert_true(fields.get(key) is None)
    _ => panic()
  }
}

///|
/// 断言请求头存在且等于期望值。
fn assert_header(
  request : @transport.PreparedRequest,
  key : String,
  expected : String,
) -> Unit raise {
  assert_eq(request.headers.get(key), Some(expected))
}

///|
async test "list：POST /api/fs/list，请求体带 path 与分页，响应容错解码" {
  let (fs, transport) = fs_with([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"content\":[{\"name\":\"a.txt\",\"size\":12,\"is_dir\":false,\"type\":1}],\"total\":1,\"write\":true,\"provider\":\"Local\"}}",
    ),
  ])
  let listing = fs.list("/docs", page=2, per_page=50)
  assert_eq(listing.total, 1L)
  assert_eq(listing.content.length(), 1)
  assert_eq(listing.content[0].name, "a.txt")
  assert_eq(listing.content[0].size, 12L)
  assert_eq(listing.content[0].obj_type, 1)
  assert_true(listing.write)
  assert_eq(listing.provider, "Local")
  let requests = transport.received()
  assert_eq(requests.length(), 1)
  assert_eq(requests[0].url, "https://openlist.example.com/api/fs/list")
  assert_eq(requests[0].http_method, @moonhttp.Method::Post)
  assert_header(requests[0], "Authorization", "t0ken")
  let body = body_json(requests[0])
  assert_json_string(body, "path", "/docs")
  assert_json_int(body, "page", 2)
  assert_json_int(body, "per_page", 50)
}

///|
async test "get：raw_url 与 related 一起解码" {
  let (fs, transport) = fs_with([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"name\":\"a.txt\",\"size\":3,\"is_dir\":false,\"type\":1,\"raw_url\":\"https://x/a.txt\",\"related\":[{\"name\":\"b.txt\",\"is_dir\":false}]}}",
    ),
  ])
  let obj = fs.get("/a.txt")
  assert_eq(obj.obj.name, "a.txt")
  assert_eq(obj.raw_url, "https://x/a.txt")
  assert_eq(obj.related.length(), 1)
  assert_eq(obj.related[0].name, "b.txt")
  assert_json_string(body_json(transport.received()[0]), "path", "/a.txt")
}

///|
async test "dirs：path 缺省时仍然发出空的 path 字段" {
  let (fs, transport) = fs_with([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":[{\"name\":\"docs\",\"modified\":\"2024-01-01T00:00:00Z\"}]}",
    ),
  ])
  let dirs = fs.dirs(force_root=true)
  assert_eq(dirs.length(), 1)
  assert_eq(dirs[0].name, "docs")
  let body = body_json(transport.received()[0])
  assert_json_string(body, "path", "")
  let force_root = match field(body, "force_root") {
    True => true
    _ => false
  }
  assert_true(force_root)
}

///|
async test "search：关键字与 scope 进请求体，parent 与密码可选" {
  let (fs, transport) = fs_with([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"content\":[{\"parent\":\"/docs\",\"name\":\"a.txt\",\"is_dir\":false,\"size\":7,\"type\":1}],\"total\":1}}",
    ),
  ])
  let found = fs.search("/", "a", scope=2)
  assert_eq(found.total, 1L)
  assert_eq(found.content[0].parent, "/docs")
  assert_eq(found.content[0].size, 7L)
  let body = body_json(transport.received()[0])
  assert_json_string(body, "parent", "/")
  assert_json_string(body, "keywords", "a")
  assert_json_int(body, "scope", 2)
  assert_absent(body, "password")
}

///|
async test "other：驱动自定义返回值原样透出" {
  let (fs, transport) = fs_with([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"custom\":[1,2]}}",
    ),
  ])
  let data = fs.other("/dir", "GET", data=@json.parse("{\"k\":\"v\"}"))
  let custom = match field(data, "custom") {
    Array(items) => items
    _ => panic()
  }
  assert_eq(custom.length(), 2)
  let body = body_json(transport.received()[0])
  assert_json_string(body, "path", "/dir")
  assert_json_string(body, "method", "GET")
  assert_true(
    match field(body, "data") {
      Object(_) => true
      _ => panic()
    },
  )
}

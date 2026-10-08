///|
/// 管理域的白盒测试（元数据）：用 `@transport.MockTransport` 预置响应，全程不联网。
/// 用户与存储的用例分别在 `admin_user_wbtest.mbt` / `admin_storage_wbtest.mbt`，
/// 设置与索引的用例在 `admin_setting_wbtest.mbt`。

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
/// 造一个管理域子模块 + Mock 传输层（管理员 token）。
fn admin_with(
  responses : Array[@transport.RawResponse],
) -> (AdminApi, @transport.MockTransport) {
  let mock = @transport.MockTransport::from_responses(responses)
  let transport : &@moonhttp.Transport = mock
  let client = @core.Client::new(
    @core.Settings::new("https://openlist.example.com/"),
    @core.Credentials::Token("t0ken"),
    transport~,
  )
  (AdminApi::new(client), mock)
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
/// 断言 JSON 里的布尔字段。
fn assert_json_bool(json : Json, key : String, expected : Bool) -> Unit raise {
  let actual = match field(json, key) {
    True => true
    False => false
    _ => panic()
  }
  assert_eq(actual, expected)
}

///|
/// 断言 JSON 里的命名字段（用于 `type` 这种保留字键）。
fn assert_json_number(
  json : Json,
  key : String,
  expected : Double,
) -> Unit raise {
  let actual = match field(json, key) {
    Number(value, ..) => value
    _ => panic()
  }
  assert_eq(actual, expected)
}

///|
/// 一条元数据的 JSON。
fn meta_json() -> String {
  "{\"id\":7,\"path\":\"/a\",\"read_users\":[],\"read_users_sub\":false,\"write_users\":[],\"write_users_sub\":false,\"password\":\"\",\"p_sub\":false,\"write\":true,\"w_sub\":false,\"hide\":\"\",\"h_sub\":false,\"readme\":\"\",\"r_sub\":false,\"header\":\"\",\"header_sub\":false}"
}

///|
/// 一条存储配置的 JSON。
fn storage_json() -> String {
  "{\"id\":2,\"mount_path\":\"/local\",\"order\":0,\"driver\":\"Local\",\"cache_expiration\":30,\"custom_cache_policies\":\"\",\"status\":\"work\",\"addition\":\"{}\",\"remark\":\"\",\"modified\":\"2024-01-01T00:00:00Z\",\"disabled\":false,\"disable_index\":false,\"enable_sign\":false,\"order_by\":\"\",\"order_direction\":\"\",\"extract_folder\":\"\",\"web_proxy\":false,\"webdav_policy\":\"\",\"proxy_range\":false,\"down_proxy_url\":\"\",\"disable_proxy_sign\":false}"
}

///|
/// 一个用户的 JSON。
fn user_json() -> String {
  "{\"id\":1,\"username\":\"alice\",\"password\":\"\",\"base_path\":\"/\",\"role\":1,\"disabled\":false,\"permission\":0,\"sso_id\":\"\",\"allow_ldap\":false}"
}

///|
/// 构造一份元数据（服务端 create/update 直接绑定这个结构）。
fn sample_meta() -> @core.Meta {
  {
    id: 7,
    path: "/a",
    read_users: [],
    read_users_sub: false,
    write_users: [],
    write_users_sub: false,
    password: "",
    p_sub: false,
    write: true,
    w_sub: false,
    hide: "",
    h_sub: false,
    readme: "",
    r_sub: false,
    header: "",
    header_sub: false,
  }
}

///|
/// 构造一条存储配置。
fn sample_storage() -> @core.Storage {
  {
    id: 2,
    mount_path: "/local",
    order: 0,
    driver: "Local",
    cache_expiration: 30,
    custom_cache_policies: "",
    status: "work",
    addition: "{}",
    remark: "",
    modified: "2024-01-01T00:00:00Z",
    disabled: false,
    disable_index: false,
    enable_sign: false,
    order_by: "",
    order_direction: "",
    extract_folder: "",
    web_proxy: false,
    webdav_policy: "",
    proxy_range: false,
    down_proxy_url: "",
    disable_proxy_sign: false,
  }
}

///|
async test "meta：list / get / create / update / delete" {
  let (admin, mock) = admin_with([
    raw_json(
      200,
      "{\"code\":200,\"message\":\"success\",\"data\":{\"content\":[\{meta_json()}],\"total\":1}}",
    ),
    raw_json(
      200,
      "{\"code\":200,\"message\":\"success\",\"data\":\{meta_json()}}",
    ),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
  ])
  let page = admin.list_meta(page=1, per_page=10)
  assert_eq(page.total, 1L)
  assert_eq(page.content[0].id, 7)
  assert_eq(page.content[0].path, "/a")
  assert_true(page.content[0].write)
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/meta/list?page=1&per_page=10",
  )
  let meta = admin.get_meta(7)
  assert_eq(meta.path, "/a")
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/meta/get?id=7",
  )
  admin.create_meta(sample_meta())
  let created = mock.last_request().unwrap()
  assert_eq(created.http_method, @moonhttp.Method::Post)
  assert_eq(created.url, "https://openlist.example.com/api/admin/meta/create")
  let body = body_json(created)
  assert_json_string(body, "path", "/a")
  assert_json_bool(body, "write", true)
  admin.update_meta(sample_meta())
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/meta/update",
  )
  admin.delete_meta(7)
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/meta/delete?id=7",
  )
}

///|
/// 管理域的白盒测试（驱动 / 设置 / 索引）。
///
/// 助手函数（`raw_json`、`admin_with`、`body_json` 等）在
/// `admin_wbtest.mbt` 里，同一个包的测试文件共用。

///|
/// 一个驱动描述的 JSON。
fn driver_info_json() -> String {
  "{\"common\":[{\"name\":\"root_folder_path\",\"type\":\"string\",\"default\":\"/\",\"options\":\"\",\"required\":true,\"help\":\"\"}],\"additional\":[],\"config\":{\"name\":\"Local\",\"local_sort\":true,\"only_proxy\":false,\"no_cache\":false,\"no_upload\":false,\"need_ms\":false,\"default_root\":\"/\",\"alert\":\"\",\"only_indices\":false,\"prefer_proxy\":false}}"
}

///|
/// 一项设置的 JSON。
fn setting_json() -> String {
  "{\"key\":\"site_title\",\"value\":\"OpenList\",\"help\":\"\",\"type\":\"string\",\"options\":\"\",\"group\":1,\"flag\":0,\"index\":0}"
}

///|
async test "driver：list（驱动名到描述的映射）/ names / info" {
  let (admin, mock) = admin_with([
    raw_json(
      200,
      "{\"code\":200,\"message\":\"success\",\"data\":{\"Local\":\{driver_info_json()},\"S3\":\{driver_info_json()}}}",
    ),
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":[\"Local\",\"S3\"]}",
    ),
    raw_json(
      200,
      "{\"code\":200,\"message\":\"success\",\"data\":\{driver_info_json()}}",
    ),
  ])
  let drivers = admin.list_drivers()
  assert_eq(drivers.length(), 2)
  let local_driver = drivers.get("Local").unwrap()
  assert_eq(local_driver.config.name, "Local")
  assert_true(local_driver.config.local_sort)
  assert_eq(local_driver.common.length(), 1)
  assert_true(local_driver.common[0].required)
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/driver/list",
  )
  let names = admin.driver_names()
  assert_eq(names, ["Local", "S3"])
  let info = admin.driver_info("S3")
  assert_eq(info.config.name, "Local")
  assert_eq(info.common.length(), 1)
  assert_eq(info.common[0].name, "root_folder_path")
  assert_true(info.additional.is_empty())
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/driver/info?driver=S3",
  )
}

///|
async test "setting：list / get / get_settings" {
  let (admin, mock) = admin_with([
    raw_json(
      200,
      "{\"code\":200,\"message\":\"success\",\"data\":[\{setting_json()}]}",
    ),
    raw_json(
      200,
      "{\"code\":200,\"message\":\"success\",\"data\":\{setting_json()}}",
    ),
    raw_json(
      200,
      "{\"code\":200,\"message\":\"success\",\"data\":[\{setting_json()}]}",
    ),
  ])
  let settings = admin.list_settings(group=1)
  assert_eq(settings.length(), 1)
  assert_eq(settings[0].key, "site_title")
  assert_eq(settings[0].item_type, "string")
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/setting/list?group=1",
  )
  let single = admin.get_setting("site_title")
  assert_eq(single.value, "OpenList")
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/setting/get?key=site_title",
  )
  let batch = admin.get_settings(["a", "b"])
  assert_eq(batch.length(), 1)
  assert_true(
    mock.last_request().unwrap().url.has_prefix(
      "https://openlist.example.com/api/admin/setting/get?keys=",
    ),
  )
}

///|
async test "setting：save（回传数组）/ delete / reset_token / default" {
  let (admin, mock) = admin_with([
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":\"new-token\"}",
    ),
    raw_json(
      200,
      "{\"code\":200,\"message\":\"success\",\"data\":[\{setting_json()}]}",
    ),
  ])
  let item = @core.SettingItem::{
    key: "site_title",
    value: "新标题",
    help: "",
    item_type: "string",
    options: "",
    group: 1,
    flag: 0,
    index: 0,
  }
  admin.save_settings([item])
  let body = body_json(mock.last_request().unwrap())
  let sent = match body {
    Array(values) => values
    _ => panic()
  }
  assert_eq(sent.length(), 1)
  assert_json_string(sent[0], "key", "site_title")
  assert_json_string(sent[0], "value", "新标题")
  assert_json_string(sent[0], "type", "string")
  admin.delete_setting("site_title")
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/setting/delete?key=site_title",
  )
  let token = admin.reset_token()
  assert_eq(token, "new-token")
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/setting/reset_token",
  )
  let defaults = admin.default_settings(group=1)
  assert_eq(defaults.length(), 1)
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/setting/default?group=1",
  )
}

///|
async test "index：build / update / stop / clear / progress" {
  let (admin, mock) = admin_with([
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"obj_count\":12,\"is_done\":false,\"last_done_time\":null,\"error\":\"\"}}",
    ),
  ])
  admin.index_build()
  let build = mock.last_request().unwrap()
  assert_eq(build.http_method, @moonhttp.Method::Post)
  assert_eq(build.url, "https://openlist.example.com/api/admin/index/build")
  assert_true(build.body is None)
  admin.index_update(["/docs"], max_depth=3)
  let body = body_json(mock.last_request().unwrap())
  let paths = match field(body, "paths") {
    Array(values) => values
    _ => panic()
  }
  assert_eq(paths.length(), 1)
  let first_path = match paths[0] {
    String(value) => value
    _ => panic()
  }
  assert_eq(first_path, "/docs")
  assert_json_number(body, "max_depth", 3.0)
  admin.index_stop()
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/index/stop",
  )
  admin.index_clear()
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/index/clear",
  )
  let progress = admin.index_progress()
  assert_eq(progress.obj_count, 12L)
  assert_true(!progress.is_done)
  assert_eq(progress.last_done_time, None)
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/index/progress",
  )
}

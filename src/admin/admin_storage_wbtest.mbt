///|
/// 管理域存储接口（list / get / create / update / enable / disable / delete /
/// load_all）的白盒测试：复用 `admin_wbtest.mbt` 里的助手与 fixture，全程不联网。

///|
async test "storage：list / get / create / update / 启停 / 删除 / 重载" {
  let (admin, mock) = admin_with([
    raw_json(
      200,
      "{\"code\":200,\"message\":\"success\",\"data\":{\"content\":[\{storage_json()}],\"total\":1}}",
    ),
    raw_json(
      200,
      "{\"code\":200,\"message\":\"success\",\"data\":\{storage_json()}}",
    ),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":{\"id\":5}}"),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
  ])
  let page = admin.list_storages(page=1, per_page=10)
  assert_eq(page.total, 1L)
  assert_eq(page.content[0].mount_path, "/local")
  assert_eq(page.content[0].driver, "Local")
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/storage/list?page=1&per_page=10",
  )
  let storage = admin.get_storage(2)
  assert_eq(storage.id, 2)
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/storage/get?id=2",
  )
  let created = admin.create_storage(sample_storage())
  assert_eq(created, 5)
  let body = body_json(mock.last_request().unwrap())
  assert_json_string(body, "mount_path", "/local")
  assert_json_string(body, "driver", "Local")
  assert_json_number(body, "cache_expiration", 30.0)
  admin.update_storage(sample_storage())
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/storage/update",
  )
  admin.enable_storage(2)
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/storage/enable?id=2",
  )
  admin.disable_storage(2)
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/storage/disable?id=2",
  )
  admin.delete_storage(2)
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/storage/delete?id=2",
  )
  admin.load_all_storages()
  let reloaded = mock.last_request().unwrap()
  assert_eq(
    reloaded.url,
    "https://openlist.example.com/api/admin/storage/load_all",
  )
  assert_true(reloaded.body is None)
}

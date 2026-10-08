///|
/// 管理域用户接口（list / get / create / update / delete / cancel_2fa /
/// del_cache / SSH 公钥）的白盒测试：复用 `admin_wbtest.mbt` 里的助手与
/// fixture，全程不联网。

///|
async test "admin user：list / get / create / update" {
  let (admin, mock) = admin_with([
    raw_json(
      200,
      "{\"code\":200,\"message\":\"success\",\"data\":{\"content\":[\{user_json()}],\"total\":1}}",
    ),
    raw_json(
      200,
      "{\"code\":200,\"message\":\"success\",\"data\":\{user_json()}}",
    ),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
  ])
  let page = admin.list_users()
  assert_eq(page.total, 1L)
  assert_eq(page.content[0].username, "alice")
  assert_eq(page.content[0].role, 1)
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/user/list",
  )
  let user = admin.get_user(1)
  assert_eq(user.id, 1)
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/user/get?id=1",
  )
  let created = @core.User::{
    id: 0,
    username: "alice",
    password: "pw",
    base_path: "/",
    role: 1,
    disabled: false,
    permission: 0,
    sso_id: "",
    allow_ldap: false,
  }
  admin.create_user(created)
  let body = body_json(mock.last_request().unwrap())
  assert_json_string(body, "username", "alice")
  assert_json_string(body, "password", "pw")
  assert_json_number(body, "role", 1.0)
  admin.update_user({ ..created, id: 1, password: "", })
  let updated = body_json(mock.last_request().unwrap())
  assert_json_number(updated, "id", 1.0)
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/user/update",
  )
}

///|
async test "admin user：delete / cancel_2fa / del_cache / SSH 公钥" {
  let (admin, mock) = admin_with([
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"content\":[{\"id\":3,\"title\":\"laptop\",\"fingerprint\":\"SHA256:xx\",\"added_time\":\"2024-01-01T00:00:00Z\",\"last_used_time\":\"0001-01-01T00:00:00Z\"}],\"total\":1}}",
    ),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
  ])
  admin.delete_user(1)
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/user/delete?id=1",
  )
  admin.cancel_2fa(1)
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/user/cancel_2fa?id=1",
  )
  admin.del_cache("alice")
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/user/del_cache?username=alice",
  )
  let keys = admin.list_user_ssh_keys(1, page=1, per_page=10)
  assert_eq(keys.total, 1L)
  assert_eq(keys.content[0].title, "laptop")
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/user/sshkey/list?page=1&per_page=10&uid=1",
  )
  admin.delete_user_ssh_key(3)
  assert_eq(
    mock.last_request().unwrap().url,
    "https://openlist.example.com/api/admin/user/sshkey/delete?id=3",
  )
}

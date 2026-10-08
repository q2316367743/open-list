///|
/// fs 管理类接口（mkdir / rename / batch_rename / regex_rename / move / copy /
/// remove 等）的白盒测试：复用 `fs_wbtest.mbt` 里的助手，全程不联网。

///|
async test "move_to：names 是数组，skip_existing 只在给定时出现" {
  let (fs, transport) = fs_with([
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
  ])
  fs.move_to("/src", "/dst", ["a.txt", "b.txt"], skip_existing=true)
  fs.copy("/src", "/dst", ["c.txt"])
  let requests = transport.received()
  let first = body_json(requests[0])
  assert_eq(requests[0].url, "https://openlist.example.com/api/fs/move")
  assert_json_string(first, "src_dir", "/src")
  assert_json_string(first, "dst_dir", "/dst")
  let names = match field(first, "names") {
    Array(items) => items
    _ => panic()
  }
  assert_eq(names.length(), 2)
  assert_true(
    match field(first, "skip_existing") {
      True => true
      _ => false
    },
  )
  assert_absent(first, "overwrite")
  let second = body_json(requests[1])
  assert_eq(requests[1].url, "https://openlist.example.com/api/fs/copy")
  assert_absent(second, "skip_existing")
}

///|
async test "rename 与 batch_rename：请求体字段名按 Go 结构体" {
  let (fs, transport) = fs_with([
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
  ])
  fs.rename("/a.txt", "b.txt", overwrite=true)
  fs.batch_rename("/dir", [RenameObject::new("a.txt", "x.txt")])
  let first = body_json(transport.received()[0])
  assert_json_string(first, "path", "/a.txt")
  assert_json_string(first, "name", "b.txt")
  let second = body_json(transport.received()[1])
  assert_json_string(second, "src_dir", "/dir")
  let objects = match field(second, "rename_objects") {
    Array(items) => items
    _ => panic()
  }
  assert_eq(objects.length(), 1)
  assert_json_string(objects[0], "src_name", "a.txt")
  assert_json_string(objects[0], "new_name", "x.txt")
}

///|
async test "remove / mkdir / regex_rename 的请求体" {
  let (fs, transport) = fs_with([
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
  ])
  fs.mkdir("/new")
  fs.remove("/dir", ["a.txt"])
  fs.regex_rename("/dir", "a(.*)", "b$1")
  let requests = transport.received()
  assert_json_string(body_json(requests[0]), "path", "/new")
  assert_eq(requests[0].url, "https://openlist.example.com/api/fs/mkdir")
  let removed = body_json(requests[1])
  assert_json_string(removed, "dir", "/dir")
  assert_true(
    match field(removed, "names") {
      Array(_) => true
      _ => panic()
    },
  )
  assert_eq(requests[1].url, "https://openlist.example.com/api/fs/remove")
  let regex = body_json(requests[2])
  assert_json_string(regex, "src_name_regex", "a(.*)")
  assert_json_string(regex, "new_name_regex", "b$1")
}

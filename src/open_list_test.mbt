///|
/// 根包的黑盒测试：模拟一个「只 import `q2316367743/open-list`」的使用者，
/// 验证门面再导出的类型、方法与错误构造子真的可用（这是 `pub using` 的
/// 关键能力，见 `src/reexport.mbt` 顶部的说明）。

///|
test "只用根包就能创建客户端并使用再导出的类型" {
  let settings : @lib.Settings = @lib.Settings::new(
    "https://openlist.example.com",
  )
  assert_eq(settings.base_url, "https://openlist.example.com")
  let credentials : @lib.Credentials = @lib.Credentials::password(
    "admin", "secret",
  )
  let client = @lib.create_open_list_client(settings, credentials)
  assert_eq(client.token(), None)
  let with_token = @lib.create_open_list_client_with_token(
    "https://openlist.example.com", "t0ken",
  )
  assert_eq(with_token.token(), Some("t0ken"))
  let _ = @lib.UpdateMeRequest::new("admin")
  let _ = @lib.SharingUpdateRequest::new(["/docs"])
  let _ = @lib.RenameObject::new("a.txt", "b.txt")
  let _ = @lib.FileHash::new(sha256="deadbeef")
  let _ : @lib.PageResult[@lib.User]? = None
}

///|
/// 逃生通道的错误也能只用根包捕获：这里用一个非法的服务器地址触发传输层错误
/// （不会产生网络请求）。三个构造子都写进分支，验证它们都能从根包引用到。
async test "根包能按构造子捕获错误（逃生通道）" {
  let client = @lib.create_open_list_client_with_token("", "bad")
  let code = try {
    let _ = client.request(@lib.Method::Get, "/api/public/init_status")
    -1
  } catch {
    @lib.OpenListError::Api(error) => error.code
    @lib.OpenListError::Http(_) => -2
    @lib.OpenListError::Decode(_) => -3
  }
  assert_eq(code, -2)
}

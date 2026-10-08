///|
/// 当前用户（`/api/me`、`/api/me/sshkey/*`）。

///|
/// 测当前用户与 SSH 公钥列表，返回当前用户（调用方用它判断是不是管理员）。
pub async fn check_user(client : @lib.OpenListClient) -> @lib.User? {
  section("当前用户 /api/me")
  let me = check(
    "GET /api/me",
    "user().me()",
    Ok(client.user().me()) catch {
      error => Err(error)
    },
    fn(response) {
      "\{user_summary(response.user)}，已开启两步验证=\{response.otp}"
    },
  )
  dump_raw(client, @lib.Method::Get, "/api/me")
  let _ = check(
    "GET /api/me/sshkey/list",
    "user().list_ssh_keys()",
    Ok(client.user().list_ssh_keys(page=1, per_page=20)) catch {
      error => Err(error)
    },
    fn(page) {
      "total=\{page.total}，本页 \{page.content.length()} 个：\{joined(page.content.map(sshkey_summary))}"
    },
  )
  dump_raw(
    client,
    @lib.Method::Get,
    "/api/me/sshkey/list",
    query=Json::object({ "page": Json::number(1), "per_page": Json::number(20) }),
  )
  match me {
    Some(response) => Some(response.user)
    None => None
  }
}

///|
/// 分享列表（`/api/share/list`）。创建/更新/删除放在写入自测里。

///|
/// 测第一页分享记录。
pub async fn check_share(client : @lib.OpenListClient) -> Unit {
  section("分享 /api/share/*")
  let _ = check(
    "GET /api/share/list",
    "share().list()",
    Ok(client.share().list(page=1, per_page=50)) catch {
      error => Err(error)
    },
    fn(page) {
      "total=\{page.total}，本页 \{page.content.length()} 条：\{joined(page.content.map(fn(record) { record.id }))}"
    },
  )
  dump_raw(
    client,
    @lib.Method::Get,
    "/api/share/list",
    query=Json::object({ "page": Json::number(1), "per_page": Json::number(50) }),
  )
}

///|
/// 分享域：`/api/share/*`。
///
/// 这里管的是**分享记录**（创建、查询、启停、删除）；分享出来的内容浏览走另一组
/// `/sd/:sid/*path` 下载路径，不在本模块内。
///
/// 服务端给这组路由挂了 `AuthNotGuest`：需要登录，且访客账号会被拒。普通用户
/// 只能看到/操作自己创建的分享，管理员能看到全部；别人的分享会以 404
/// （`sharing not found`）的形式「不存在」。
pub struct ShareApi {
  priv client : @core.Client
}

///|
/// 由根包创建。
pub fn ShareApi::new(client : @core.Client) -> ShareApi {
  { client, }
}

///|
/// 分享记录的查询参数：ID 是短字符串，不是数字。
fn sharing_query(id : String) -> Json {
  @core.query_json([("id", Some(@core.query_string(id)))])
}

///|
/// 发一个不关心返回值的 POST。
async fn ShareApi::post_quiet(
  self : ShareApi,
  path : String,
  query? : Json,
  body? : Json,
) -> Unit raise @core.OpenListError {
  let _ = self.client.request(@moonhttp.Method::Post, path, query?, body?)
}

///|
/// 分页列出分享记录（`GET /api/share/list?page=&per_page=`）。
pub async fn ShareApi::list(
  self : ShareApi,
  page? : Int,
  per_page? : Int,
) -> @core.PageResult[@core.SharingResponse] raise @core.OpenListError {
  let query = @core.query_json(@core.page_pairs(page?, per_page?))
  let data = self.client.request(
    @moonhttp.Method::Get,
    "/api/share/list",
    query~,
  )
  @core.decode_data(data)
}

///|
/// 按 ID 取一条分享记录（`GET /api/share/get?id=`）。
///
/// 不是自己的分享（且自己不是管理员）时服务端返回 404。
pub async fn ShareApi::get(
  self : ShareApi,
  id : String,
) -> @core.SharingResponse raise @core.OpenListError {
  let data = self.client.request(
    @moonhttp.Method::Get,
    "/api/share/get",
    query=sharing_query(id),
  )
  @core.decode_data(data)
}

///|
/// 新建分享（`POST /api/share/create`），返回创建后的完整记录。
pub async fn ShareApi::create(
  self : ShareApi,
  request : SharingUpdateRequest,
) -> @core.SharingResponse raise @core.OpenListError {
  let data = self.client.request(
    @moonhttp.Method::Post,
    "/api/share/create",
    body=@json.to_json(request),
  )
  @core.decode_data(data)
}

///|
/// 更新分享（`POST /api/share/update`），返回更新后的完整记录。
///
/// `request.id` 必填，且与 `create` 一样必须给出非空的 `files`；`new_id` 非空时
/// 顺带改分享 ID（需要相应权限）。
pub async fn ShareApi::update(
  self : ShareApi,
  request : SharingUpdateRequest,
) -> @core.SharingResponse raise @core.OpenListError {
  let data = self.client.request(
    @moonhttp.Method::Post,
    "/api/share/update",
    body=@json.to_json(request),
  )
  @core.decode_data(data)
}

///|
/// 删除分享（`POST /api/share/delete?id=`）。
pub async fn ShareApi::delete(
  self : ShareApi,
  id : String,
) -> Unit raise @core.OpenListError {
  self.post_quiet("/api/share/delete", query=sharing_query(id))
}

///|
/// 启用分享（`POST /api/share/enable?id=`）。
pub async fn ShareApi::enable(
  self : ShareApi,
  id : String,
) -> Unit raise @core.OpenListError {
  self.post_quiet("/api/share/enable", query=sharing_query(id))
}

///|
/// 禁用分享（`POST /api/share/disable?id=`）。
pub async fn ShareApi::disable(
  self : ShareApi,
  id : String,
) -> Unit raise @core.OpenListError {
  self.post_quiet("/api/share/disable", query=sharing_query(id))
}

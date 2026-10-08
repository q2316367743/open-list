///|
/// 管理域：`/api/admin/*` 下的全部端点。
///
/// 这些端点都要求管理员身份（服务端 `AuthAdmin` 中间件），非管理员调用会拿到
/// 403。所有方法都会把服务端的业务错误抛成 `OpenListError::Api`，调用方可以从
/// `ApiError::code` 读到业务码。
pub struct AdminApi {
  priv client : @core.Client
}

///|
/// 由根包创建。
pub fn AdminApi::new(client : @core.Client) -> AdminApi {
  { client, }
}

///|
/// 只有 `id` 一个查询参数时的写法。
fn id_query(id : UInt) -> Json {
  @core.query_json([("id", Some(Json::number(id.to_double())))])
}

///|
/// 发一个不关心返回值的 POST。
async fn AdminApi::post_quiet(
  self : AdminApi,
  path : String,
  query? : Json,
  body? : Json,
) -> Unit raise @core.OpenListError {
  let _ = self.client.request(@moonhttp.Method::Post, path, query?, body?)
}

///|
/// 发一个 GET 并取回信封里的 `data`。
async fn AdminApi::get_data(
  self : AdminApi,
  path : String,
  query? : Json,
) -> Json raise @core.OpenListError {
  self.client.request(@moonhttp.Method::Get, path, query?)
}

// ---------------------------------------------------------------------------
// 元数据（meta）
// ---------------------------------------------------------------------------

///|
/// 分页列出元数据（`GET /api/admin/meta/list?page=&per_page=`）。
pub async fn AdminApi::list_meta(
  self : AdminApi,
  page? : Int,
  per_page? : Int,
) -> @core.PageResult[@core.Meta] raise @core.OpenListError {
  let query = @core.query_json(@core.page_pairs(page?, per_page?))
  let data = self.get_data("/api/admin/meta/list", query~)
  @core.decode_data(data)
}

///|
/// 按 ID 取一条元数据（`GET /api/admin/meta/get?id=`）。
pub async fn AdminApi::get_meta(
  self : AdminApi,
  id : UInt,
) -> @core.Meta raise @core.OpenListError {
  let data = self.get_data("/api/admin/meta/get", query=id_query(id))
  @core.decode_data(data)
}

///|
/// 新建元数据（`POST /api/admin/meta/create`）。
///
/// 请求体就是 `Meta` 本身；`meta.id` 会被服务端忽略。
pub async fn AdminApi::create_meta(
  self : AdminApi,
  meta : @core.Meta,
) -> Unit raise @core.OpenListError {
  self.post_quiet("/api/admin/meta/create", body=@json.to_json(meta))
}

///|
/// 更新元数据（`POST /api/admin/meta/update`），`meta.id` 必填。
pub async fn AdminApi::update_meta(
  self : AdminApi,
  meta : @core.Meta,
) -> Unit raise @core.OpenListError {
  self.post_quiet("/api/admin/meta/update", body=@json.to_json(meta))
}

///|
/// 删除元数据（`POST /api/admin/meta/delete?id=`）。
pub async fn AdminApi::delete_meta(
  self : AdminApi,
  id : UInt,
) -> Unit raise @core.OpenListError {
  self.post_quiet("/api/admin/meta/delete", query=id_query(id))
}

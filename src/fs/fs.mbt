///|
/// 文件系统域：`/api/fs/*` 下的浏览、搜索、文件管理、上传与归档。
///
/// 服务端对这批端点的认证要求并不一致：
///
/// - `/fs/list`、`/fs/get`、`/fs/archive/meta`、`/fs/archive/list` **必须登录**
///   （这几个挂了强制认证中间件，游客会拿到 401）；
/// - `/fs/dirs`、`/fs/search`、`/fs/other` 与所有写操作是「可选认证」，
///   没登录时按游客权限处理。
///
/// 本客户端的门面会在需要时自动登录，所以两类端点都不用特殊处理；要按游客
/// 使用时传 `Credentials::Token("")`（空 token 不会带认证头）。
pub struct FileSystem {
  priv client : @core.Client
}

///|
/// 由根包创建（使用者应通过 `OpenListClient::fs` 获取）。
pub fn FileSystem::new(client : @core.Client) -> FileSystem {
  { client, }
}

///|
/// 发一个不关心返回值的 POST（成功时服务端的 `data` 是 `null`）。
async fn FileSystem::post_quiet(
  self : FileSystem,
  path : String,
  query? : Json,
  body? : Json,
  headers? : Array[(String, String)],
) -> Unit raise @core.OpenListError {
  let _ = self.client.request(
    @moonhttp.Method::Post,
    path,
    query?,
    body?,
    headers?,
  )
}

///|
/// 列出目录内容（`POST /api/fs/list`）。
///
/// 分页由服务端完成：`page` 小于 1 时按 1 处理，`per_page` 小于 1 时返回全部。
/// `refresh` 会绕过服务端的目录缓存，代价是慢。
pub async fn FileSystem::list(
  self : FileSystem,
  path : String,
  password? : String,
  refresh? : Bool,
  page? : Int,
  per_page? : Int,
) -> @core.FsListResponse raise @core.OpenListError {
  let body = ListBody::{ path, password, refresh, page, per_page, }
  let data = self.client.request(
    @moonhttp.Method::Post,
    "/api/fs/list",
    body=@json.to_json(body),
  )
  @core.decode_data(data)
}

///|
/// 取单个对象的详情（`POST /api/fs/get`）。
///
/// 响应里除了对象本身，还有带签名的直链 `raw_url`，以及该对象的说明与自定义
/// 请求头（挂在元数据上的），见 `@core.FsGetResponse`。
pub async fn FileSystem::get(
  self : FileSystem,
  path : String,
  password? : String,
) -> @core.FsGetResponse raise @core.OpenListError {
  let body = GetBody::{ path, password, }
  let data = self.client.request(
    @moonhttp.Method::Post,
    "/api/fs/get",
    body=@json.to_json(body),
  )
  @core.decode_data(data)
}

///|
/// 列出目录树（`POST /api/fs/dirs`，只给目录名与修改时间）。
///
/// 与 `list` 的区别：它只递归列举目录（适合做目录选择器），不返回文件。
/// `force_root` 为真时从根目录开始，忽略 `path`。
pub async fn FileSystem::dirs(
  self : FileSystem,
  path? : String,
  password? : String,
  force_root? : Bool,
) -> Array[@core.DirResp] raise @core.OpenListError {
  let body = DirsBody::{ path: path.unwrap_or(""), password, force_root, }
  let data = self.client.request(
    @moonhttp.Method::Post,
    "/api/fs/dirs",
    body=@json.to_json(body),
  )
  @core.decode_data(data)
}

///|
/// 在某个目录下按关键字搜索（`POST /api/fs/search`）。
///
/// `scope`：`0` 全部、`1` 只搜目录、`2` 只搜文件；留 `None` 时服务端按 `0`
/// 处理。搜索结果由服务端分页，`total` 是命中总数。
pub async fn FileSystem::search(
  self : FileSystem,
  parent : String,
  keywords : String,
  scope? : Int,
  page? : Int,
  per_page? : Int,
  password? : String,
) -> @core.PageResult[@core.SearchResult] raise @core.OpenListError {
  let body = SearchBody::{ parent, keywords, scope, page, per_page, password, }
  let data = self.client.request(
    @moonhttp.Method::Post,
    "/api/fs/search",
    body=@json.to_json(body),
  )
  @core.decode_data(data)
}

///|
/// 调用存储驱动的自定义方法（`POST /api/fs/other`）。
///
/// `request_method` 是驱动自己认的方法名（例如 `GET`、`POST`），`data` 是驱动
/// 自定义的入参。返回值完全由驱动决定，所以这里**不做解码**，原样返回信封里的
/// `data`。
pub async fn FileSystem::other(
  self : FileSystem,
  path : String,
  request_method : String,
  data? : Json,
  password? : String,
) -> Json raise @core.OpenListError {
  let body = @core.query_json([
    ("path", Some(Json::string(path))),
    ("method", Some(Json::string(request_method))),
    ("data", data),
    ("password", password.map(Json::string)),
  ])
  self.client.request(@moonhttp.Method::Post, "/api/fs/other", body~)
}

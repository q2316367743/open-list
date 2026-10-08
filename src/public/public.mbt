///|
/// 公开域：`/api/public/*`——不需要登录就能访问的服务器信息与安装流程。
///
/// 这些端点在服务端没有挂认证中间件，因此客户端即使在匿名状态
/// （`Credentials::Token("")` 或尚未登录）也能调用。
pub struct PublicApi {
  priv client : @core.Client
}

///|
/// 由根包创建。
pub fn PublicApi::new(client : @core.Client) -> PublicApi {
  { client, }
}

///|
/// 发送初始化请求的请求体（`POST /api/public/init/setup`）。
struct InitSetupBody {
  username : String
  password : String
  site_title : String
} derive(ToJson)

///|
/// 显式声明 `derive` 出来的 `ToJson` 实现。
pub extend InitSetupBody with ToJson::{to_json}

///|
/// 读取服务器的公开设置（`GET /api/public/settings`）。
///
/// 返回站点标题、版本号一类的键值对；键名以服务端为准。
pub async fn PublicApi::settings(
  self : PublicApi,
) -> Map[String, String] raise @core.OpenListError {
  let data = self.client.request(@moonhttp.Method::Get, "/api/public/settings")
  @core.decode_data(data)
}

///|
/// 某个路径下可用的离线下载工具名（`GET /api/public/offline_download_tools`）。
///
/// `path` 不给时返回所有工具（服务端按路径筛选可用驱动）。
pub async fn PublicApi::offline_download_tools(
  self : PublicApi,
  path? : String,
) -> Array[String] raise @core.OpenListError {
  let query = match path {
    Some(value) => @core.query_json([("path", Some(@core.query_string(value)))])
    None => @core.query_json([])
  }
  let data = self.client.request(
    @moonhttp.Method::Get,
    "/api/public/offline_download_tools",
    query~,
  )
  @core.decode_data(data)
}

///|
/// 服务端支持的归档扩展名（`GET /api/public/archive_extensions`）。
///
/// 用来判断哪些文件可以走 `/api/fs/archive/*` 解压。
pub async fn PublicApi::archive_extensions(
  self : PublicApi,
) -> Array[String] raise @core.OpenListError {
  let data = self.client.request(
    @moonhttp.Method::Get,
    "/api/public/archive_extensions",
  )
  @core.decode_data(data)
}

///|
/// 查询系统是否已经初始化（`GET /api/public/init_status`）。
///
/// 未初始化时 `initialized` 为假，此时才能调用 `init_setup`。
pub async fn PublicApi::init_status(
  self : PublicApi,
) -> @core.InitStatus raise @core.OpenListError {
  let data = self.client.request(
    @moonhttp.Method::Get,
    "/api/public/init_status",
  )
  @core.decode_data(data)
}

///|
/// 执行系统初始化，创建首个管理员账号（`POST /api/public/init/setup`）。
///
/// 只在尚未初始化时可用：重复调用会拿到 400（`system has already been
/// initialized`）；密码要求至少 4 个字符（服务端校验，不满足也是 400）。
pub async fn PublicApi::init_setup(
  self : PublicApi,
  username : String,
  password : String,
  site_title? : String,
) -> Unit raise @core.OpenListError {
  let body : InitSetupBody = {
    username,
    password,
    site_title: site_title.unwrap_or(""),
  }
  let _ = self.client.request(
    @moonhttp.Method::Post,
    "/api/public/init/setup",
    body=@json.to_json(body),
  )
}

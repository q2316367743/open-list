///|
/// OpenList 客户端：认证状态的持有者，也是六个 API 域子模块的入口。
///
/// 由一个服务器信息（`Settings`）与一份凭证（`Credentials`）创建，
/// 创建时就把六个子模块派生好——`auth` / `user` / `admin` / `fs` /
/// `public` / `share`。它们共享同一份认证状态：用账号密码登录后拿到的限时
/// token 对所有子模块立即生效，`set_token` 也一样。
///
/// 子模块的字段是私有的，只能由客户端派生（见 `docs/00-architecture.md`）。
pub struct OpenListClient {
  priv core : @core.Client
  priv auth : @auth.Auth
  priv user : @user.UserApi
  priv admin : @admin.AdminApi
  priv fs : @fs.FileSystem
  priv public : @public.PublicApi
  priv share : @share.ShareApi
}

///|
/// 创建客户端：服务器信息 + 凭证。
///
/// 凭证支持 OpenList 的两种认证方式：
///
/// ```moonbit nocheck
/// // 1. 永久 token（后台生成的，直接拿来用）
/// let client = create_open_list_client(
///   Settings::new("https://openlist.example.com"),
///   Credentials::token("..."),
/// )
///
/// // 2. 账号密码：第一次需要认证的请求前自动登录，换取限时 token
///
/// let client = create_open_list_client(
///   Settings::new("https://openlist.example.com"),
///   Credentials::password("admin", "secret"),
/// )
///
/// let files = client.fs().list("/")
/// ```
///
pub fn create_open_list_client(
  settings : Settings,
  credentials : Credentials,
) -> OpenListClient {
  new_client(settings, credentials)
}

///|
/// 真正的构造函数：比公开版本多一个传输层注入点，只给同包的白盒测试用
/// （生产代码不要传 `transport`）。
fn new_client(
  settings : Settings,
  credentials : Credentials,
  transport? : &@moonhttp.Transport,
) -> OpenListClient {
  let core = @core.Client::new(settings, credentials, transport?)
  {
    core,
    auth: @auth.Auth::new(core),
    user: @user.UserApi::new(core),
    admin: @admin.AdminApi::new(core),
    fs: @fs.FileSystem::new(core),
    public: @public.PublicApi::new(core),
    share: @share.ShareApi::new(core),
  }
}

///|
/// 用永久 token 创建客户端（`create_open_list_client` 的常用简写）。
pub fn create_open_list_client_with_token(
  base_url : String,
  token : String,
) -> OpenListClient {
  create_open_list_client(Settings::new(base_url), Credentials::token(token))
}

///|
/// 认证子模块：登录（明文 / 预哈希 / LDAP）、退出、token 与两步验证。
pub fn OpenListClient::auth(self : OpenListClient) -> @auth.Auth {
  self.auth
}

///|
/// 当前用户子模块：`/api/me` 与自己的 SSH 公钥。
pub fn OpenListClient::user(self : OpenListClient) -> @user.UserApi {
  self.user
}

///|
/// 管理子模块：元信息、用户、存储、驱动、设置与索引（需要管理员权限）。
pub fn OpenListClient::admin(self : OpenListClient) -> @admin.AdminApi {
  self.admin
}

///|
/// 文件子模块：列目录、读写、管理、上传（含分片）与归档。
pub fn OpenListClient::fs(self : OpenListClient) -> @fs.FileSystem {
  self.fs
}

///|
/// 公共子模块：站点设置、离线下载工具、归档扩展名与站点初始化。
pub fn OpenListClient::public(self : OpenListClient) -> @public.PublicApi {
  self.public
}

///|
/// 分享子模块：创建 / 查询 / 启停分享链接。
pub fn OpenListClient::share(self : OpenListClient) -> @share.ShareApi {
  self.share
}

///|
/// 连接设置（创建时固化进客户端）。
pub fn OpenListClient::settings(self : OpenListClient) -> Settings {
  self.core.settings()
}

///|
/// 当前 token：永久凭证就是它本身；账号密码凭证在登录成功前是 `None`。
pub fn OpenListClient::token(self : OpenListClient) -> String? {
  self.core.token()
}

///|
/// 直接覆盖 token，用于从本地持久化状态恢复会话，或主动让 token 失效。
pub fn OpenListClient::set_token(
  self : OpenListClient,
  token : String?,
) -> Unit {
  self.core.set_token(token)
}

///|
/// 是否已持有可用 token（永久 token，或账号密码换来的限时 token）。
pub fn OpenListClient::is_logged_in(self : OpenListClient) -> Bool {
  self.core.is_logged_in()
}

///|
/// 逃生通道：直接请求任意 `/api/...` 端点，返回信封里的 `data`（原样 `Json`）。
///
/// 官方客户端没有把它封装成方法的端点（SSO、WebAuthn、`/api/task/*` 等，
/// 清单见 `docs/08-unsupported-endpoints.md`）都可以用它调用。认证、账号密码
/// 凭证的 401 重登、信封检查与 `code != 200` 抛 `Api` 都在这一层自动完成：
///
/// ```moonbit nocheck
/// let status = client.request(Method::Get, "/api/public/init_status")
/// ```
pub async fn OpenListClient::request(
  self : OpenListClient,
  http_method : @moonhttp.Method,
  path : String,
  query? : Json,
  body? : Json,
  headers? : Array[(String, String)],
) -> Json raise OpenListError {
  self.core.request(http_method, path, query?, body?, headers?)
}

///|
/// 「当前登录用户」域：自己的资料与 SSH 公钥。
///
/// 这些端点都需要认证。用账号密码凭证时，第一个请求会自动触发登录；
/// 游客（未登录且服务端允许游客访问）调 `me()` 会拿到游客用户的信息。
pub struct UserApi {
  priv client : @core.Client
}

///|
/// 由根包创建。
pub fn UserApi::new(client : @core.Client) -> UserApi {
  { client, }
}

///|
/// 当前用户信息（`GET /api/me`）。
///
/// 返回的 `user.password` 一定是空串（服务端清掉了），`user_response.otp`
/// 表示该账号是否开启了两步验证。
pub async fn UserApi::me(
  self : UserApi,
) -> @core.UserResponse raise @core.OpenListError {
  let data = self.client.request(@moonhttp.Method::Get, "/api/me")
  @core.decode_data(data)
}

///|
/// 修改当前用户资料（`POST /api/me/update`）。
///
/// 服务端会无条件用请求里的 `username` 覆盖原用户名，所以 `UpdateMeRequest`
/// 的 `username` 是必填的；改密码不要求旧密码。
pub async fn UserApi::update(
  self : UserApi,
  request : UpdateMeRequest,
) -> Unit raise @core.OpenListError {
  let _ = self.client.request(
    @moonhttp.Method::Post,
    "/api/me/update",
    body=@json.to_json(request),
  )
}

///|
/// 分页列出自己的 SSH 公钥（`GET /api/me/sshkey/list?page=&per_page=`）。
///
/// 服务端返回的是标准分页信封，所以这里直接给 `PageResult`。
pub async fn UserApi::list_ssh_keys(
  self : UserApi,
  page? : Int,
  per_page? : Int,
) -> @core.PageResult[@core.SSHPublicKey] raise @core.OpenListError {
  let query = @core.query_json(@core.page_pairs(page?, per_page?))
  let data = self.client.request(
    @moonhttp.Method::Get,
    "/api/me/sshkey/list",
    query~,
  )
  @core.decode_data(data)
}

///|
/// 新增 SSH 公钥（`POST /api/me/sshkey/add`）。
///
/// 公钥格式非法时服务端返回 400；同一个公钥重复添加也会失败。
pub async fn UserApi::add_ssh_key(
  self : UserApi,
  title : String,
  key : String,
) -> Unit raise @core.OpenListError {
  let request = AddSSHKeyRequest::{ title, key, }
  let _ = self.client.request(
    @moonhttp.Method::Post,
    "/api/me/sshkey/add",
    body=@json.to_json(request),
  )
}

///|
/// 删除自己的 SSH 公钥（`POST /api/me/sshkey/delete?id=`）。
///
/// `id` 来自 `list_ssh_keys` 的结果。
pub async fn UserApi::delete_ssh_key(
  self : UserApi,
  id : UInt,
) -> Unit raise @core.OpenListError {
  let query = @core.query_json([("id", Some(Json::number(id.to_double())))])
  let _ = self.client.request(
    @moonhttp.Method::Post,
    "/api/me/sshkey/delete",
    query~,
  )
}

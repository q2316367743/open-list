///|
/// 管理域的「用户」部分：`/api/admin/user/*`。

///|
/// 分页列出用户（`GET /api/admin/user/list?page=&per_page=`）。
pub async fn AdminApi::list_users(
  self : AdminApi,
  page? : Int,
  per_page? : Int,
) -> @core.PageResult[@core.User] raise @core.OpenListError {
  let query = @core.query_json(@core.page_pairs(page?, per_page?))
  let data = self.get_data("/api/admin/user/list", query~)
  @core.decode_data(data)
}

///|
/// 按 ID 取用户（`GET /api/admin/user/get?id=`）。
pub async fn AdminApi::get_user(
  self : AdminApi,
  id : UInt,
) -> @core.User raise @core.OpenListError {
  let data = self.get_data("/api/admin/user/get", query=id_query(id))
  @core.decode_data(data)
}

///|
/// 新建用户（`POST /api/admin/user/create`）。
///
/// 服务端直接绑定 `model.User`，所以这里传的是 `User`：
/// `username` 与 `password`（明文）必填，`role` 只能是 `1`（普通用户），
/// 管理员与游客账号会被服务端拒绝（400 `admin or guest user can not be created`）。
pub async fn AdminApi::create_user(
  self : AdminApi,
  user : @core.User,
) -> Unit raise @core.OpenListError {
  self.post_quiet("/api/admin/user/create", body=@json.to_json(user))
}

///|
/// 更新用户（`POST /api/admin/user/update`），`user.id` 必填。
///
/// 注意事项（都来自服务端实现）：
/// - `role` 不能与原值不同，否则 400 `role can not be changed`；
/// - `password` 留空表示不改密码；
/// - 管理员账号不允许被禁用（400 `admin user can not be disabled`）。
///
/// 因此典型的「改一下基础路径」写法是：先 `get_user`，改字段，再 `update_user`。
pub async fn AdminApi::update_user(
  self : AdminApi,
  user : @core.User,
) -> Unit raise @core.OpenListError {
  self.post_quiet("/api/admin/user/update", body=@json.to_json(user))
}

///|
/// 删除用户（`POST /api/admin/user/delete?id=`）。
pub async fn AdminApi::delete_user(
  self : AdminApi,
  id : UInt,
) -> Unit raise @core.OpenListError {
  self.post_quiet("/api/admin/user/delete", query=id_query(id))
}

///|
/// 取消某个用户的两步验证（`POST /api/admin/user/cancel_2fa?id=`）。
pub async fn AdminApi::cancel_2fa(
  self : AdminApi,
  id : UInt,
) -> Unit raise @core.OpenListError {
  self.post_quiet("/api/admin/user/cancel_2fa", query=id_query(id))
}

///|
/// 清空某个用户的路径缓存（`POST /api/admin/user/del_cache?username=`）。
pub async fn AdminApi::del_cache(
  self : AdminApi,
  username : String,
) -> Unit raise @core.OpenListError {
  let query = @core.query_json([
    ("username", Some(@core.query_string(username))),
  ])
  self.post_quiet("/api/admin/user/del_cache", query~)
}

///|
/// 分页列出某个用户的 SSH 公钥
/// （`GET /api/admin/user/sshkey/list?uid=&page=&per_page=`）。
pub async fn AdminApi::list_user_ssh_keys(
  self : AdminApi,
  uid : UInt,
  page? : Int,
  per_page? : Int,
) -> @core.PageResult[@core.SSHPublicKey] raise @core.OpenListError {
  let pairs = @core.page_pairs(page?, per_page?)
  pairs.push(("uid", Some(Json::number(uid.to_double()))))
  let data = self.get_data(
    "/api/admin/user/sshkey/list",
    query=@core.query_json(pairs),
  )
  @core.decode_data(data)
}

///|
/// 删除任意用户的 SSH 公钥（`POST /api/admin/user/sshkey/delete?id=`）。
pub async fn AdminApi::delete_user_ssh_key(
  self : AdminApi,
  id : UInt,
) -> Unit raise @core.OpenListError {
  self.post_quiet("/api/admin/user/sshkey/delete", query=id_query(id))
}

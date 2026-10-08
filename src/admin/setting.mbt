///|
/// 管理域的「设置」部分：`/api/admin/setting/*`。
///
/// 服务端把设置存成扁平的键值对（`SettingItem`），`value` 永远是字符串。

///|
/// 把 `groups` 拼成服务端要的 `1,2,3` 形式。
fn join_groups(groups : Array[Int]) -> String {
  groups.map(fn(group) { group.to_string() }).join(",")
}

///|
/// `group` / `groups` 两种分组查询参数。
fn group_query(group? : Int, groups? : Array[Int]) -> Json {
  let pairs : Array[(String, Json?)] = []
  match group {
    Some(value) => pairs.push(("group", Some(@core.query_int(value))))
    None => ()
  }
  match groups {
    Some(values) =>
      if values.length() > 0 {
        pairs.push(("groups", Some(@core.query_string(join_groups(values)))))
      }
    None => ()
  }
  @core.query_json(pairs)
}

///|
/// 列出设置（`GET /api/admin/setting/list?group=N` 或 `?groups=1,2`）。
///
/// 不传分组时返回全部设置。
pub async fn AdminApi::list_settings(
  self : AdminApi,
  group? : Int,
  groups? : Array[Int],
) -> Array[@core.SettingItem] raise @core.OpenListError {
  let query = group_query(group?, groups?)
  let data = self.get_data("/api/admin/setting/list", query~)
  @core.decode_data(data)
}

///|
/// 读单项设置（`GET /api/admin/setting/get?key=X`）。
///
/// 服务端在 `keys` 非空时返回数组、否则返回单个对象，所以这里和
/// `get_settings` 是两个方法。
pub async fn AdminApi::get_setting(
  self : AdminApi,
  key : String,
) -> @core.SettingItem raise @core.OpenListError {
  let query = @core.query_json([("key", Some(@core.query_string(key)))])
  let data = self.get_data("/api/admin/setting/get", query~)
  @core.decode_data(data)
}

///|
/// 批量读设置（`GET /api/admin/setting/get?keys=a,b`）。
pub async fn AdminApi::get_settings(
  self : AdminApi,
  keys : Array[String],
) -> Array[@core.SettingItem] raise @core.OpenListError {
  let query = @core.query_json([
    ("keys", Some(@core.query_string(keys.join(",")))),
  ])
  let data = self.get_data("/api/admin/setting/get", query~)
  @core.decode_data(data)
}

///|
/// 保存设置（`POST /api/admin/setting/save`）。
///
/// 请求体是设置项数组；通常做法是 `list_settings` 拿到手、改掉 `value`、
/// 再原样传回来。
pub async fn AdminApi::save_settings(
  self : AdminApi,
  settings : Array[@core.SettingItem],
) -> Unit raise @core.OpenListError {
  self.post_quiet("/api/admin/setting/save", body=@json.to_json(settings))
}

///|
/// 删除设置（`POST /api/admin/setting/delete?key=`）。
pub async fn AdminApi::delete_setting(
  self : AdminApi,
  key : String,
) -> Unit raise @core.OpenListError {
  let query = @core.query_json([("key", Some(@core.query_string(key)))])
  self.post_quiet("/api/admin/setting/delete", query~)
}

///|
/// 重置系统令牌（`POST /api/admin/setting/reset_token`），返回新令牌。
///
/// 这个令牌是 OpenList 给第三方驱动/回调用的系统级令牌，与登录 token 无关。
pub async fn AdminApi::reset_token(
  self : AdminApi,
) -> String raise @core.OpenListError {
  let data = self.client.request(
    @moonhttp.Method::Post,
    "/api/admin/setting/reset_token",
  )
  @core.decode_data(data)
}

///|
/// 取某些分组的默认设置（`POST /api/admin/setting/default?group=N`）。
pub async fn AdminApi::default_settings(
  self : AdminApi,
  group? : Int,
  groups? : Array[Int],
) -> Array[@core.SettingItem] raise @core.OpenListError {
  let query = group_query(group?, groups?)
  let data = self.client.request(
    @moonhttp.Method::Post,
    "/api/admin/setting/default",
    query~,
  )
  @core.decode_data(data)
}

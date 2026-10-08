///|
/// 管理域的「存储」部分：`/api/admin/storage/*`。
///
/// 注意 `list_storages` 返回的每一项在服务端是 `StorageResp`（比 `Storage`
/// 多一个 `mount_details` 字段）。这里保留 `Storage` 的建模，`mount_details`
/// 会被解码器忽略；要读挂载空间可以走文件系统的 `fs.list` / `fs.get`。

///|
/// 分页列出存储（`GET /api/admin/storage/list?page=&per_page=`）。
pub async fn AdminApi::list_storages(
  self : AdminApi,
  page? : Int,
  per_page? : Int,
) -> @core.PageResult[@core.Storage] raise @core.OpenListError {
  let query = @core.query_json(@core.page_pairs(page?, per_page?))
  let data = self.get_data("/api/admin/storage/list", query~)
  @core.decode_data(data)
}

///|
/// 按 ID 取存储（`GET /api/admin/storage/get?id=`）。
pub async fn AdminApi::get_storage(
  self : AdminApi,
  id : UInt,
) -> @core.Storage raise @core.OpenListError {
  let data = self.get_data("/api/admin/storage/get", query=id_query(id))
  @core.decode_data(data)
}

///|
/// 新建存储（`POST /api/admin/storage/create`），返回新存储的 ID。
///
/// `mount_path`、`driver` 必填；`addition` 是驱动配置的 JSON 字符串，
/// 具体字段可以先用 `driver_info(driver)` 查出来再拼。
pub async fn AdminApi::create_storage(
  self : AdminApi,
  storage : @core.Storage,
) -> UInt raise @core.OpenListError {
  let data = self.client.request(
    @moonhttp.Method::Post,
    "/api/admin/storage/create",
    body=@json.to_json(storage),
  )
  match data {
    Json::Object(fields) => @core.uint_field(fields, "id")
    _ => 0U
  }
}

///|
/// 更新存储（`POST /api/admin/storage/update`），`storage.id` 必填。
pub async fn AdminApi::update_storage(
  self : AdminApi,
  storage : @core.Storage,
) -> Unit raise @core.OpenListError {
  self.post_quiet("/api/admin/storage/update", body=@json.to_json(storage))
}

///|
/// 删除存储（`POST /api/admin/storage/delete?id=`）。
pub async fn AdminApi::delete_storage(
  self : AdminApi,
  id : UInt,
) -> Unit raise @core.OpenListError {
  self.post_quiet("/api/admin/storage/delete", query=id_query(id))
}

///|
/// 启用存储（`POST /api/admin/storage/enable?id=`）。
pub async fn AdminApi::enable_storage(
  self : AdminApi,
  id : UInt,
) -> Unit raise @core.OpenListError {
  self.post_quiet("/api/admin/storage/enable", query=id_query(id))
}

///|
/// 禁用存储（`POST /api/admin/storage/disable?id=`）。
pub async fn AdminApi::disable_storage(
  self : AdminApi,
  id : UInt,
) -> Unit raise @core.OpenListError {
  self.post_quiet("/api/admin/storage/disable", query=id_query(id))
}

///|
/// 重新加载全部存储（`POST /api/admin/storage/load_all`）。
///
/// 适用于直接在数据库里改过存储配置的场景。
pub async fn AdminApi::load_all_storages(
  self : AdminApi,
) -> Unit raise @core.OpenListError {
  self.post_quiet("/api/admin/storage/load_all")
}

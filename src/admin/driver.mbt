///|
/// 管理域的「驱动」部分：`/api/admin/driver/*`。
///
/// 三个端点分别是：全部驱动的描述表、驱动名列表、单个驱动的配置项列表。
/// 用账号密码凭证的调用方可以在建存储之前先看 `driver_info`。

///|
/// 全部驱动：驱动名 → 描述（`GET /api/admin/driver/list`）。
///
/// 返回的是「驱动类型」的配置描述，不是某个已挂载的存储。
pub async fn AdminApi::list_drivers(
  self : AdminApi,
) -> Map[String, @core.DriverInfo] raise @core.OpenListError {
  let data = self.get_data("/api/admin/driver/list")
  @core.decode_data(data)
}

///|
/// 全部驱动名（`GET /api/admin/driver/names`）。
pub async fn AdminApi::driver_names(
  self : AdminApi,
) -> Array[String] raise @core.OpenListError {
  let data = self.get_data("/api/admin/driver/names")
  @core.decode_data(data)
}

///|
/// 某个驱动的完整描述（`GET /api/admin/driver/info?driver=X`）。
///
/// 返回 `{common, additional, config}`：服务端给的是**单个**驱动的描述对象
/// （与 `/driver/list` 映射里的每一项同形），不是配置项数组。
/// 驱动名不存在时服务端返回 404（`driver [X] not found`），
/// 在客户端表现为 `OpenListError::Api`。
pub async fn AdminApi::driver_info(
  self : AdminApi,
  driver : String,
) -> @core.DriverInfo raise @core.OpenListError {
  let query = @core.query_json([("driver", Some(@core.query_string(driver)))])
  let data = self.get_data("/api/admin/driver/info", query~)
  @core.decode_data(data)
}

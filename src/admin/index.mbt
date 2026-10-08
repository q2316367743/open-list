///|
/// 管理域的「索引 / 搜索」部分：`/api/admin/index/*`。
///
/// 对应服务端的全文索引（`op.BuildIndex` 等）。构建是异步的，进度用
/// `index_progress` 轮询。

///|
/// 更新索引的请求体（`POST /api/admin/index/update`）。
pub(all) struct UpdateIndexRequest {
  /// 要重建索引的路径列表。
  paths : Array[String]
  /// 最大递归深度；`0` 表示不限制。
  max_depth : Int
} derive(ToJson)

///|
/// 显式声明 `derive` 出来的 `ToJson` 实现以普通方法暴露。
pub extend UpdateIndexRequest with ToJson::{to_json}

///|
/// 全量构建索引（`POST /api/admin/index/build`）。
///
/// 索引已经在跑时服务端返回 400（`index is running`）。
pub async fn AdminApi::index_build(
  self : AdminApi,
) -> Unit raise @core.OpenListError {
  self.post_quiet("/api/admin/index/build")
}

///|
/// 增量更新索引（`POST /api/admin/index/update`）。
pub async fn AdminApi::index_update(
  self : AdminApi,
  paths : Array[String],
  max_depth? : Int,
) -> Unit raise @core.OpenListError {
  let request = UpdateIndexRequest::{
    paths,
    max_depth: max_depth.unwrap_or(0),
  }
  self.post_quiet("/api/admin/index/update", body=@json.to_json(request))
}

///|
/// 停止索引构建（`POST /api/admin/index/stop`）。
pub async fn AdminApi::index_stop(
  self : AdminApi,
) -> Unit raise @core.OpenListError {
  self.post_quiet("/api/admin/index/stop")
}

///|
/// 清空索引（`POST /api/admin/index/clear`）。
pub async fn AdminApi::index_clear(
  self : AdminApi,
) -> Unit raise @core.OpenListError {
  self.post_quiet("/api/admin/index/clear")
}

///|
/// 查询索引进度（`GET /api/admin/index/progress`）。
pub async fn AdminApi::index_progress(
  self : AdminApi,
) -> @core.IndexProgress raise @core.OpenListError {
  let data = self.get_data("/api/admin/index/progress")
  @core.decode_data(data)
}

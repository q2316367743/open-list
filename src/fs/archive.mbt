///|
/// 归档与离线下载。
///
/// 归档端点既能看压缩包内部（`archive_meta` / `archive_list`），也能把包内
/// 内容解压到某个目录（`archive_decompress`，异步任务）。
/// `add_offline_download` 让服务端自己去下载一批 URL（离线下载/秒传）。

///|
/// 读取压缩包的结构与元信息（`POST /api/fs/archive/meta`）。
///
/// 加密的包要在 `archive_pass` 里给密码；`refresh` 会绕过服务端的归档缓存。
pub async fn FileSystem::archive_meta(
  self : FileSystem,
  path : String,
  password? : String,
  refresh? : Bool,
  archive_pass? : String,
) -> @core.ArchiveMetaResponse raise @core.OpenListError {
  let body = ArchiveMetaBody::{ path, password, refresh, archive_pass, }
  let data = self.client.request(
    @moonhttp.Method::Post,
    "/api/fs/archive/meta",
    body=@json.to_json(body),
  )
  @core.decode_data(data)
}

///|
/// 分页列出压缩包内某个目录的内容（`POST /api/fs/archive/list`）。
///
/// `inner_path` 是包内路径（`archive_meta` 没给出时留空表示根）。
pub async fn FileSystem::archive_list(
  self : FileSystem,
  path : String,
  inner_path? : String,
  password? : String,
  refresh? : Bool,
  archive_pass? : String,
  page? : Int,
  per_page? : Int,
) -> @core.PageResult[@core.ArchiveContent] raise @core.OpenListError {
  let body = ArchiveListBody::{
    path,
    inner_path,
    password,
    refresh,
    archive_pass,
    page,
    per_page,
  }
  let data = self.client.request(
    @moonhttp.Method::Post,
    "/api/fs/archive/list",
    body=@json.to_json(body),
  )
  @core.decode_data(data)
}

///|
/// 把压缩包里的内容解压到 `dst_dir`（`POST /api/fs/archive/decompress`）。
///
/// `names` 是包内要解压的条目（相对包内路径）；服务端把它当异步任务跑，
/// 返回的是刚创建的任务列表（服务端字段名是 `task`，但值是数组）。
pub async fn FileSystem::archive_decompress(
  self : FileSystem,
  src_dir : String,
  dst_dir : String,
  names : Array[String],
  archive_pass? : String,
  inner_path? : String,
  cache_full? : Bool,
  put_into_new_dir? : Bool,
  overwrite? : Bool,
) -> Array[@core.TaskInfo] raise @core.OpenListError {
  let body = ArchiveDecompressBody::{
    src_dir,
    dst_dir,
    name: names,
    archive_pass,
    inner_path,
    cache_full,
    put_into_new_dir,
    overwrite,
  }
  let data = self.client.request(
    @moonhttp.Method::Post,
    "/api/fs/archive/decompress",
    body=@json.to_json(body),
  )
  decode_tasks(data)
}

///|
/// 让服务端离线下载一批 URL 到一个目录（`POST /api/fs/add_offline_download`）。
///
/// `tool` 指定用哪个离线下载工具（先用 `PublicApi::offline_download_tools`
/// 查可用列表）；留空时服务端挑默认工具。空白 URL 会被服务端忽略。
/// 返回的是刚创建的任务列表（服务端字段名是 `tasks`）。
pub async fn FileSystem::add_offline_download(
  self : FileSystem,
  path : String,
  urls : Array[String],
  tool? : String,
) -> Array[@core.TaskInfo] raise @core.OpenListError {
  let body = AddOfflineDownloadBody::{ urls, path, tool, }
  let data = self.client.request(
    @moonhttp.Method::Post,
    "/api/fs/add_offline_download",
    body=@json.to_json(body),
  )
  decode_tasks(data)
}

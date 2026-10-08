///|
/// 文件与目录的增删改：新建、重命名、移动、复制、删除、取直链。
///
/// 这些端点都是「可选认证」：没登录时服务端按游客权限判断能否写。

///|
/// 新建文件夹（`POST /api/fs/mkdir`）。
pub async fn FileSystem::mkdir(
  self : FileSystem,
  path : String,
) -> Unit raise @core.OpenListError {
  self.post_quiet("/api/fs/mkdir", body=@json.to_json(MkdirBody::{ path, }))
}

///|
/// 重命名（`POST /api/fs/rename`）。
///
/// `path` 是原路径，`name` 是**新名字**（不含目录）。`overwrite` 为真时允许
/// 覆盖同名对象。
pub async fn FileSystem::rename(
  self : FileSystem,
  path : String,
  name : String,
  overwrite? : Bool,
) -> Unit raise @core.OpenListError {
  let body = RenameBody::{ path, name, overwrite, }
  self.post_quiet("/api/fs/rename", body=@json.to_json(body))
}

///|
/// 批量重命名（`POST /api/fs/batch_rename`）。
///
/// 所有改动都发生在同一个目录 `src_dir` 下。
pub async fn FileSystem::batch_rename(
  self : FileSystem,
  src_dir : String,
  rename_objects : Array[RenameObject],
) -> Unit raise @core.OpenListError {
  let pairs = rename_objects.map(fn(item) {
    RenamePairBody::{ src_name: item.src_name, new_name: item.new_name, }
  })
  let body = BatchRenameBody::{ src_dir, rename_objects: pairs, }
  self.post_quiet("/api/fs/batch_rename", body=@json.to_json(body))
}

///|
/// 用正则批量重命名（`POST /api/fs/regex_rename`）。
///
/// 服务端对目录下每个名字做 `src_name_regex` 匹配，再按 `new_name_regex`
/// 生成新名字（仅匹配到第一个的项会被改名）。
pub async fn FileSystem::regex_rename(
  self : FileSystem,
  src_dir : String,
  src_name_regex : String,
  new_name_regex : String,
) -> Unit raise @core.OpenListError {
  let body = RegexRenameBody::{ src_dir, src_name_regex, new_name_regex, }
  self.post_quiet("/api/fs/regex_rename", body=@json.to_json(body))
}

///|
/// 把一批对象移动到另一个目录（`POST /api/fs/move`）。
///
/// `skip_existing` 与 `merge` 只在目标已存在时起作用：`skip_existing` 跳过冲突项，
/// `merge` 合并目录，两者都为假时按 `overwrite` 决定是否覆盖。
pub async fn FileSystem::move_to(
  self : FileSystem,
  src_dir : String,
  dst_dir : String,
  names : Array[String],
  overwrite? : Bool,
  skip_existing? : Bool,
  merge? : Bool,
) -> Unit raise @core.OpenListError {
  let body = MoveCopyBody::{
    src_dir,
    dst_dir,
    names,
    overwrite,
    skip_existing,
    merge,
  }
  self.post_quiet("/api/fs/move", body=@json.to_json(body))
}

///|
/// 复制一批对象（`POST /api/fs/copy`），参数与 `move` 相同。
pub async fn FileSystem::copy(
  self : FileSystem,
  src_dir : String,
  dst_dir : String,
  names : Array[String],
  overwrite? : Bool,
  skip_existing? : Bool,
  merge? : Bool,
) -> Unit raise @core.OpenListError {
  let body = MoveCopyBody::{
    src_dir,
    dst_dir,
    names,
    overwrite,
    skip_existing,
    merge,
  }
  self.post_quiet("/api/fs/copy", body=@json.to_json(body))
}

///|
/// 递归移动目录（`POST /api/fs/recursive_move`，连子目录一起搬）。
///
/// `conflict_policy` 决定遇到同名项怎么办：`skip`、`overwrite`、`merge`
/// （留 `None` 时服务端按 `overwrite` 处理）。
pub async fn FileSystem::recursive_move(
  self : FileSystem,
  src_dir : String,
  dst_dir : String,
  conflict_policy? : String,
) -> Unit raise @core.OpenListError {
  let body = RecursiveMoveBody::{ src_dir, dst_dir, conflict_policy, }
  self.post_quiet("/api/fs/recursive_move", body=@json.to_json(body))
}

///|
/// 删除一批对象（`POST /api/fs/remove`）。
///
/// 注意参数是「目录 + 目录下的名字」，而不是完整路径。
pub async fn FileSystem::remove(
  self : FileSystem,
  dir : String,
  names : Array[String],
) -> Unit raise @core.OpenListError {
  let body = RemoveBody::{ dir, names, }
  self.post_quiet("/api/fs/remove", body=@json.to_json(body))
}

///|
/// 删除目录下所有空目录（`POST /api/fs/remove_empty_directory`）。
pub async fn FileSystem::remove_empty_directory(
  self : FileSystem,
  src_dir : String,
) -> Unit raise @core.OpenListError {
  let body = RemoveEmptyDirectoryBody::{ src_dir, }
  self.post_quiet("/api/fs/remove_empty_directory", body=@json.to_json(body))
}

///|
/// 给对象取直链（`POST /api/fs/link`，仅管理员）。
///
/// 驱动不支持直链时 `Link::url` 是空字符串；支持多线程加速的驱动还会给出
/// `concurrency` 与 `part_size`，以及需要一起发送的请求头。
pub async fn FileSystem::create_link(
  self : FileSystem,
  path : String,
) -> @core.Link raise @core.OpenListError {
  let data = self.client.request(
    @moonhttp.Method::Post,
    "/api/fs/link",
    body=@core.query_json([("path", Some(Json::string(path)))]),
  )
  @core.decode_data(data)
}

///|
/// 文件系统端点的请求体。
///
/// 这些都是**包私有**的：对外只暴露带明确参数的方法，请求体的字段名与
/// OpenList 的 Go 结构体一一对应（`derive(ToJson)` 的键就是字段名）。
/// 可空字段为 `None` 时整个键不会出现在 JSON 里，正好对上 Go 的零值语义。

///|
/// `POST /api/fs/list`。
priv struct ListBody {
  path : String
  password : String?
  refresh : Bool?
  page : Int?
  per_page : Int?
} derive(ToJson)

///|
/// `POST /api/fs/get`。
priv struct GetBody {
  path : String
  password : String?
} derive(ToJson)

///|
/// `POST /api/fs/dirs`。
priv struct DirsBody {
  path : String
  password : String?
  force_root : Bool?
} derive(ToJson)

///|
/// `POST /api/fs/search`。
priv struct SearchBody {
  parent : String
  keywords : String
  scope : Int?
  page : Int?
  per_page : Int?
  password : String?
} derive(ToJson)

///|
/// `POST /api/fs/mkdir`。
priv struct MkdirBody {
  path : String
} derive(ToJson)

///|
/// `POST /api/fs/rename`。
priv struct RenameBody {
  path : String
  name : String
  overwrite : Bool?
} derive(ToJson)

///|
/// `POST /api/fs/batch_rename` 里的改动项。
priv struct RenamePairBody {
  src_name : String
  new_name : String
} derive(ToJson)

///|
/// `POST /api/fs/batch_rename`。
priv struct BatchRenameBody {
  src_dir : String
  rename_objects : Array[RenamePairBody]
} derive(ToJson)

///|
/// `POST /api/fs/regex_rename`。
priv struct RegexRenameBody {
  src_dir : String
  src_name_regex : String
  new_name_regex : String
} derive(ToJson)

///|
/// `POST /api/fs/move` 与 `POST /api/fs/copy` 共用。
priv struct MoveCopyBody {
  src_dir : String
  dst_dir : String
  names : Array[String]
  overwrite : Bool?
  skip_existing : Bool?
  merge : Bool?
} derive(ToJson)

///|
/// `POST /api/fs/recursive_move`。
priv struct RecursiveMoveBody {
  src_dir : String
  dst_dir : String
  conflict_policy : String?
} derive(ToJson)

///|
/// `POST /api/fs/remove`。
priv struct RemoveBody {
  dir : String
  names : Array[String]
} derive(ToJson)

///|
/// `POST /api/fs/remove_empty_directory`。
priv struct RemoveEmptyDirectoryBody {
  src_dir : String
} derive(ToJson)

///|
/// `POST /api/fs/archive/meta`。
priv struct ArchiveMetaBody {
  path : String
  password : String?
  refresh : Bool?
  archive_pass : String?
} derive(ToJson)

///|
/// `POST /api/fs/archive/list`。
priv struct ArchiveListBody {
  path : String
  inner_path : String?
  password : String?
  refresh : Bool?
  archive_pass : String?
  page : Int?
  per_page : Int?
} derive(ToJson)

///|
/// `POST /api/fs/archive/decompress`（注意字段名是 `name`，单数）。
priv struct ArchiveDecompressBody {
  src_dir : String
  dst_dir : String
  name : Array[String]
  archive_pass : String?
  inner_path : String?
  cache_full : Bool?
  put_into_new_dir : Bool?
  overwrite : Bool?
} derive(ToJson)

///|
/// `POST /api/fs/add_offline_download`。
priv struct AddOfflineDownloadBody {
  urls : Array[String]
  path : String
  tool : String?
} derive(ToJson)

///|
/// 文件系统相关的响应模型。
///
/// 与用户模型一样，解码一律容错：字段缺失、`null`、类型不符都退化成零值。
/// 这里额外处理两类 Go 带来的麻烦：
///
/// - `int64` 字段（文件大小、分片大小）在 JSON 里是**数字**，而 core json 的
///   `Int64` 只认字符串，所以统一用 `int64_field` 读；
/// - JSON 键叫 `type` 的字段在 MoonBit 里没法直接当字段名（保留字），
///   统一命名 `obj_type`。

///|
/// 列表排序设置（Go 的 `model.Sort`，被存储、分享、归档元数据共用）。
pub struct ListSort {
  /// 排序字段，例如 `name`、`size`、`modified`。
  order_by : String
  /// `asc` 或 `desc`。
  order_direction : String
  /// 解压策略：`front`、`decompress` 等。
  extract_folder : String
}

///|
/// 解码排序设置。
pub impl @json.FromJson for ListSort with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "ListSort: expected object"))
  }
  {
    order_by: string_field(fields, "order_by"),
    order_direction: string_field(fields, "order_direction"),
    extract_folder: string_field(fields, "extract_folder"),
  }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend ListSort with @json.FromJson::{from_json}

///|
/// 挂载点容量信息。
///
/// 只有登录用户（非游客）且管理员没有隐藏存储详情时才会随文件对象返回。
pub struct StorageDetails {
  /// 存储驱动名，例如 `Local`、`Aliyundrive`。
  driver_name : String
  /// 总容量（字节）。
  total_space : Int64
  /// 剩余容量（字节）。
  free_space : Int64
}

///|
/// 解码挂载点容量信息。
pub impl @json.FromJson for StorageDetails with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "StorageDetails: expected object"))
  }
  {
    driver_name: string_field(fields, "driver_name"),
    total_space: int64_field(fields, "total_space"),
    free_space: int64_field(fields, "free_space"),
  }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend StorageDetails with @json.FromJson::{from_json}

///|
/// 文件系统对象（文件或目录）。
pub struct ObjResp {
  /// 名称（不含路径）。
  name : String
  /// 字节大小；目录通常是 0。
  size : Int64
  /// 是否为目录。
  is_dir : Bool
  /// 修改时间（RFC3339 字符串）。
  modified : String
  /// 创建时间（RFC3339 字符串）。
  created : String
  /// 签名，用于拼接带签名的直链。
  sign : String
  /// 缩略图 URL。
  thumb : String
  /// 对象类型编号（服务端 `utils.GetObjType` 的结果，对应 JSON 键 `type`）。
  obj_type : Int
  /// 哈希信息的字符串形式。
  hashinfo : String
  /// 哈希信息（算法名 → 值）。
  hash_info : Map[String, String]
  /// 所在挂载点的容量信息；服务端未提供时是 `None`。
  mount_details : StorageDetails?
}

///|
/// 解码文件系统对象。
pub impl @json.FromJson for ObjResp with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "ObjResp: expected object"))
  }
  {
    name: string_field(fields, "name"),
    size: int64_field(fields, "size"),
    is_dir: bool_field(fields, "is_dir"),
    modified: string_field(fields, "modified"),
    created: string_field(fields, "created"),
    sign: string_field(fields, "sign"),
    thumb: string_field(fields, "thumb"),
    obj_type: int_field(fields, "type"),
    hashinfo: string_field(fields, "hashinfo"),
    hash_info: map_field(fields, "hash_info"),
    mount_details: json_field(fields, "mount_details"),
  }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend ObjResp with @json.FromJson::{from_json}

///|
/// `POST /api/fs/list` 的响应。
pub struct FsListResponse {
  /// 目录下的对象。
  content : Array[ObjResp]
  /// 目录内对象总数。
  total : Int64
  /// 该目录的说明（来自元数据配置）。
  readme : String
  /// 该目录的自定义头信息。
  header : String
  /// 当前用户对该目录是否有写权限。
  write : Bool
  /// 是否允许绕过写内容检查。
  write_content_bypass : Bool
  /// 实际提供该目录的存储驱动名。
  provider : String
  /// 该目录可用的直传工具。
  direct_upload_tools : Array[String]
}

///|
/// 解码目录列表响应。
pub impl @json.FromJson for FsListResponse with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "FsListResponse: expected object"))
  }
  {
    content: array_field(fields, "content"),
    total: int64_field(fields, "total"),
    readme: string_field(fields, "readme"),
    header: string_field(fields, "header"),
    write: bool_field(fields, "write"),
    write_content_bypass: bool_field(fields, "write_content_bypass"),
    provider: string_field(fields, "provider"),
    direct_upload_tools: array_field(fields, "direct_upload_tools"),
  }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend FsListResponse with @json.FromJson::{from_json}

///|
/// `POST /api/fs/get` 的响应。
///
/// Go 服务端把 `ObjResp` 内嵌进来，对象字段与 `raw_url` 等在同一层；
/// MoonBit 没有结构体内嵌，所以对象部分放在 `obj` 里（解码时仍从同一个
/// 扁平对象读）。
pub struct FsGetResponse {
  /// 对象本身（名称、大小、签名等）。
  obj : ObjResp
  /// 带签名的直链。
  raw_url : String
  /// 该对象的说明。
  readme : String
  /// 该对象的自定义头信息。
  header : String
  /// 提供该对象的存储驱动名。
  provider : String
  /// 同目录下的相关对象（开启 `related` 时才有）。
  related : Array[ObjResp]
}

///|
/// 解码对象详情响应。
pub impl @json.FromJson for FsGetResponse with fn from_json(json, path) {
  let obj : ObjResp = @json.from_json(json, path~)
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "FsGetResponse: expected object"))
  }
  {
    obj,
    raw_url: string_field(fields, "raw_url"),
    readme: string_field(fields, "readme"),
    header: string_field(fields, "header"),
    provider: string_field(fields, "provider"),
    related: array_field(fields, "related"),
  }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend FsGetResponse with @json.FromJson::{from_json}

///|
/// 目录项（`POST /api/fs/dirs` 用，只有名字与修改时间）。
pub struct DirResp {
  /// 目录名。
  name : String
  /// 修改时间（RFC3339 字符串）。
  modified : String
}

///|
/// 解码目录项。
pub impl @json.FromJson for DirResp with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "DirResp: expected object"))
  }
  {
    name: string_field(fields, "name"),
    modified: string_field(fields, "modified"),
  }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend DirResp with @json.FromJson::{from_json}

///|
/// 搜索结果项（`POST /api/fs/search` 用）。
pub struct SearchResult {
  /// 所在目录的完整路径。
  parent : String
  /// 对象名。
  name : String
  /// 是否为目录。
  is_dir : Bool
  /// 字节大小。
  size : Int64
  /// 对象类型编号（对应 JSON 键 `type`）。
  obj_type : Int
}

///|
/// 解码搜索结果项。
pub impl @json.FromJson for SearchResult with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "SearchResult: expected object"))
  }
  {
    parent: string_field(fields, "parent"),
    name: string_field(fields, "name"),
    is_dir: bool_field(fields, "is_dir"),
    size: int64_field(fields, "size"),
    obj_type: int_field(fields, "type"),
  }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend SearchResult with @json.FromJson::{from_json}

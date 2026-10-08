///|
/// 归档、分片上传、直链与任务相关的模型。
///
/// 和别的模型一样手写容错解码：Go 会内嵌结构体（归档内容项里内嵌 `ObjResp`）、
/// 把 `nil` 切片序列化成 `null`，还有 `int64` 与 JSON 数字的差异。

///|
/// 归档条目的内容项（`POST /api/fs/archive/meta` 的文件树节点）。
///
/// 与 `FsGetResponse` 一样，Go 内嵌了 `ObjResp`；这里放在 `obj` 字段里。
pub struct ArchiveContent {
  /// 该条目对应的文件对象。
  obj : ObjResp
  /// 子条目（只有目录才有）。
  children : Array[ArchiveContent]
}

///|
/// 解码归档内容项。
pub impl @json.FromJson for ArchiveContent with fn from_json(json, path) {
  let obj : ObjResp = @json.from_json(json, path~)
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "ArchiveContent: expected object"))
  }
  { obj, children: array_field(fields, "children"), }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend ArchiveContent with @json.FromJson::{from_json}

///|
/// `POST /api/fs/archive/meta` 的响应。
pub struct ArchiveMetaResponse {
  /// 归档文件自身的注释。
  comment : String
  /// 是否加密（需要 `archive_pass`）。
  encrypted : Bool
  /// 顶层条目。
  content : Array[ArchiveContent]
  /// 服务端记录的排序设置；未提供时是 `None`。
  sort : ListSort?
  /// 归档文件的带签名直链。
  raw_url : String
  /// 签名。
  sign : String
}

///|
/// 解码归档元数据响应。
pub impl @json.FromJson for ArchiveMetaResponse with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "ArchiveMetaResponse: expected object"))
  }
  {
    comment: string_field(fields, "comment"),
    encrypted: bool_field(fields, "encrypted"),
    content: array_field(fields, "content"),
    sort: json_field(fields, "sort"),
    raw_url: string_field(fields, "raw_url"),
    sign: string_field(fields, "sign"),
  }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend ArchiveMetaResponse with @json.FromJson::{from_json}

///|
/// 分片上传会话的快照（`/api/fs/multipart/*` 的响应载荷）。
pub struct SessionSnapshot {
  /// 会话 ID，后续分片请求放在 `X-Upload-Id` 头里。
  upload_id : String
  /// 会话状态。
  state : String
  /// 第几次尝试（服务端重试过会增加）。
  attempt : Int
  /// 目标路径。
  path : String
  /// 文件总大小（字节）。
  size : Int64
  /// 每片大小（字节）。
  chunk_size : Int64
  /// 分片总数。
  total_chunks : Int
  /// 已收到的分片区间，每项是 `[起始, 结束]`（闭区间，单位是分片序号）。
  received : Array[Array[Int]]
  /// 已收到的字节数。
  received_bytes : Int64
  /// 已连续收到的分片前沿。
  frontier : Int
  /// 写入存储的进度百分比。
  storage_progress : Double
  /// 失败原因；没有错误时是 `None`。
  error : String?
}

///|
/// 解码分片上传会话快照。
pub impl @json.FromJson for SessionSnapshot with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "SessionSnapshot: expected object"))
  }
  {
    upload_id: string_field(fields, "upload_id"),
    state: string_field(fields, "state"),
    attempt: int_field(fields, "attempt"),
    path: string_field(fields, "path"),
    size: int64_field(fields, "size"),
    chunk_size: int64_field(fields, "chunk_size"),
    total_chunks: int_field(fields, "total_chunks"),
    received: array_field(fields, "received"),
    received_bytes: int64_field(fields, "received_bytes"),
    frontier: int_field(fields, "frontier"),
    storage_progress: double_field(fields, "storage_progress"),
    error: json_field(fields, "error"),
  }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend SessionSnapshot with @json.FromJson::{from_json}

///|
/// `POST /api/fs/multipart/init` 的响应：会话快照 + 是否是「续传」。
pub struct MultipartInitResponse {
  /// 新建立或续用的会话快照。
  snapshot : SessionSnapshot
  /// 是否是复用了之前的会话（续传）。
  resumed : Bool
}

///|
/// 解码分片上传初始化响应。
pub impl @json.FromJson for MultipartInitResponse with fn from_json(json, path) {
  let snapshot : SessionSnapshot = @json.from_json(json, path~)
  guard json is Object(fields) else {
    raise @json.JsonDecodeError(
      (path, "MultipartInitResponse: expected object"),
    )
  }
  { snapshot, resumed: bool_field(fields, "resumed"), }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend MultipartInitResponse with @json.FromJson::{from_json}

///|
/// 直链（`POST /api/fs/link` 的响应）。
///
/// 服务端在驱动不支持直链时只会填 `url`；支持多线程加速的驱动还会给出
/// `concurrency` 与 `part_size`。
pub struct Link {
  /// 直链地址；驱动返回空时表示不能直链，只能走 `/d/` 下载接口。
  url : String
  /// 直链需要的额外请求头。
  header : Map[String, Array[String]]
  /// 建议的并发数。
  concurrency : Int
  /// 建议的分片大小（字节）。
  part_size : Int
  /// 内容长度（字节）；未知时是 0。
  content_length : Int64
}

///|
/// 解码直链。
pub impl @json.FromJson for Link with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "Link: expected object"))
  }
  {
    url: string_field(fields, "url"),
    header: map_field(fields, "header"),
    concurrency: int_field(fields, "concurrency"),
    part_size: int_field(fields, "part_size"),
    content_length: int64_field(fields, "content_length"),
  }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend Link with @json.FromJson::{from_json}

///|
/// 异步任务的描述（`/api/fs/put` 带 `As-Task: true` 时随响应返回）。
///
/// 本客户端没有封装 `/api/task/*` 的任务管理端点，这个模型只用来读取
/// 「任务已创建」的结果（任务 ID、状态、进度）。
pub struct TaskInfo {
  /// 任务 ID。
  id : String
  /// 任务名（通常是文件名）。
  name : String
  /// 创建者用户名。
  creator : String
  /// 创建者角色：`0` 管理员、`1` 普通用户、`2` 游客。
  creator_role : Int
  /// 状态枚举（`pending`、`running`、`succeeded`、`failed` 等）。
  state : String
  /// 人类可读的状态描述。
  status : String
  /// 进度百分比。
  progress : Double
  /// 开始时间（RFC3339 字符串）；未开始时是 `None`。
  start_time : String?
  /// 结束时间（RFC3339 字符串）；未结束时是 `None`。
  end_time : String?
  /// 总字节数。
  total_bytes : Int64
  /// 失败原因；没有错误时是空字符串。
  error : String
}

///|
/// 解码任务描述。
pub impl @json.FromJson for TaskInfo with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "TaskInfo: expected object"))
  }
  {
    id: string_field(fields, "id"),
    name: string_field(fields, "name"),
    creator: string_field(fields, "creator"),
    creator_role: int_field(fields, "creator_role"),
    state: string_field(fields, "state"),
    status: string_field(fields, "status"),
    progress: double_field(fields, "progress"),
    start_time: json_field(fields, "start_time"),
    end_time: json_field(fields, "end_time"),
    total_bytes: int64_field(fields, "total_bytes"),
    error: string_field(fields, "error"),
  }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend TaskInfo with @json.FromJson::{from_json}

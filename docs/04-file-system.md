# 04 · 文件系统 File System

包：`src/fs/`（`fs.mbt` 读取、`manage.mbt` 管理、`upload.mbt` 上传、
`multipart.mbt` 分片、`archive.mbt` 归档、`bodies.mbt` 私有请求体、
`types.mbt` 公开小类型）。服务端：`server/handles/fs{read,manage,batch,up,multipart,archive}.go`。

## 1. 认证要求（服务端分组，容易踩坑）

| 端点 | 认证 |
|------|------|
| `/fs/list`、`/fs/get`、`/fs/archive/meta`、`/fs/archive/list` | **必须登录** |
| `/fs/dirs`、`/fs/search`、`/fs/other`、所有写操作与上传 | 可选登录（匿名可用，权限受限） |
| `/fs/link` | 必须登录 **且是管理员** |

部分读取操作还能带 `password`（对象/目录在元数据里设了密码时）。

## 2. 路径编码

- **请求头里的路径**（上传、分片的 `File-Path`）用 RFC 3986 百分号编码：
  `/dir/a b.txt` → `%2Fdir%2Fa%20b.txt`（`@core.url_path_encode`，斜杠也编码）。
  不能用 moonhttp 的 `encode_component`——它按表单语义把空格写成 `+`，而服务端
  用 `url.PathUnescape` 解，`+` 不会被还原成空格。
- **JSON 请求体里的 `path` 字段**直接用 UTF-8 原文，不编码。

## 3. 读取（`src/fs/fs.mbt`）

| 方法 | 端点 | 返回 |
|------|------|------|
| `list(path, password?, refresh?, page?, per_page?)` | `POST /api/fs/list` | `FsListResponse` |
| `get(path, password?)` | `POST /api/fs/get` | `FsGetResponse` |
| `dirs(path?, password?, force_root?)` | `POST /api/fs/dirs` | `Array[DirResp]` |
| `search(parent, keywords, scope?, page?, per_page?, password?)` | `POST /api/fs/search` | `PageResult[SearchResult]` |
| `other(path, method, data?, password?)` | `POST /api/fs/other` | 原始 `Json` |

```moonbit
pub struct FsListResponse {
  content : Array[ObjResp]
  total : Int64
  readme : String                  // 目录说明（元数据里的 readme）
  header : String
  write : Bool                     // 当前用户对该目录是否有写权限
  write_content_bypass : Bool
  provider : String                // 实际提供该目录的驱动名
  direct_upload_tools : Array[String]
}
pub struct FsGetResponse {
  obj : ObjResp        // 对象本身
  raw_url : String     // 带签名的直链
  readme : String
  header : String
  provider : String
  related : Array[ObjResp]
}
pub struct ObjResp {
  name; size : Int64; is_dir : Bool; modified : String; created : String
  sign : String; thumb : String; obj_type : Int; hashinfo : String
  hash_info : Map[String, String]; mount_details : StorageDetails?
}
```

- **分页在服务端做**（`page` 不传按 1、`per_page` 不传按「全部」），
  `total` 是目录内对象总数。
- `refresh=true` 让服务端忽略缓存重新拉取。
- `get` 的响应在服务端是「内嵌 `ObjResp` + 展开」，本项目把对象收进 `obj` 字段，
  所以是 `resp.obj.name` 而不是 `resp.name`。
- `dirs` 的 `path` 不给时发**空串**（等价于「猜/根」）；`force_root=true` 强制
  从根开始列（管理员常用）。
- `search` 的 `scope`：`0` 全部、`1` 只目录、`2` 只文件（不传按 `0`）。
- `other` 是驱动自定义方法：`method` 是驱动里注册的处理名，`data` 原样透传
  （传对象或 `{"data": …}` 包裹都可以），返回值**不做解码**，直接给 `Json`。

## 4. 管理（`src/fs/manage.mbt`）

| 方法 | 端点 | 请求体 |
|------|------|--------|
| `mkdir(path)` | `POST /api/fs/mkdir` | `{path}` |
| `rename(path, name, overwrite?)` | `POST /api/fs/rename` | `{path, name, overwrite?}` |
| `batch_rename(src_dir, Array[RenameObject])` | `POST /api/fs/batch_rename` | `{src_dir, rename_objects:[{src_name,new_name}]}` |
| `regex_rename(src_dir, src_name_regex, new_name_regex)` | `POST /api/fs/regex_rename` | 三个字符串 |
| `move_to(src_dir, dst_dir, names, overwrite?, skip_existing?, merge?)` | `POST /api/fs/move` | `{src_dir, dst_dir, names, …}` |
| `copy(同 move_to)` | `POST /api/fs/copy` | 同上 |
| `recursive_move(src_dir, dst_dir, conflict_policy?)` | `POST /api/fs/recursive_move` | `{src_dir, dst_dir, conflict_policy?}` |
| `remove(dir, Array[String] names)` | `POST /api/fs/remove` | `{dir, names}` |
| `remove_empty_directory(src_dir)` | `POST /api/fs/remove_empty_directory` | `{src_dir}` |
| `create_link(path) -> Link` | `POST /api/fs/link` | `{path}`（**仅管理员**） |

- `move_to` / `copy` 一次搬多个：`names` 是**文件/目录名**（不含路径），空数组等于
  对 `src_dir` 本身操作。
- `conflict_policy` 是可选的字符串直传（驱动/实现决定取值，如 `skip`、`overwrite`）。
- `RenameObject::new("a.txt", "b.txt")` 是 `batch_rename` 的元素类型。
- `create_link` 返回 `Link{url, header, concurrency, part_size, content_length}`；
  驱动不支持直链时服务端只填 `url`（甚至为空），其余是默认值：

## 5. 上传（`src/fs/upload.mbt`）

上传元信息**全在请求头**，请求体是原始字节（⚠️ 官方文档写成 JSON 请求体，不对）。

| 头 | 含义 |
|----|------|
| `File-Path` | 目标路径，**URL 编码**（`%2Fdir%2Fa%20b.txt`） |
| `X-File-Size` | 文件字节数（知道就发；服务端只在 `Content-Length` 缺失时读它） |
| `Overwrite` | 只在**明确不允许覆盖**时发 `false`；缺失/其它值都表示允许覆盖 |
| `Last-Modified` | 毫秒时间戳 |
| `X-File-Md5` / `X-File-Sha1` / `X-File-Sha256` | 由 `FileHash?` 决定发哪几个 |
| `Content-Type` | 不传则服务端按文件名猜 |
| `As-Task` | `true` 时走异步任务，响应里带 `task` |

| 方法 | 端点 | 说明 |
|------|------|------|
| `put(path, reader : &@io.Reader, content_length?, overwrite?, as_task?, content_type?, last_modified? : Int64, hash?) -> TaskInfo?` | `PUT /api/fs/put` | 流式（`@io.Reader`），大文件不占内存 |
| `put_bytes(path, Bytes, …)` | `PUT /api/fs/put` | `put` 的便捷封装 |
| `put_form(path, filename, Bytes, …)` | `PUT /api/fs/form` | `multipart/form-data`，字段名固定 `file` |

`put_form` **不会**把 `content_type` 写进请求头：请求头要留给 multipart 的
`boundary`，业务 MIME 只挂在分片头上（服务端读 `file.Header.Get("Content-Type")`）。
早期实现把 `content_type` 同时塞进请求头，服务端会报 500
`request Content-Type isn't multipart/form-data`。

返回值：`as_task=true` 时是 `data.task` 解出的 `TaskInfo`；同步完成时 `data` 为
`null`，返回 `None`。

## 6. 分片上传（`src/fs/multipart.mbt`）

适合「超大可续传上传」：先 init 拿会话，再逐片 PUT，最后 complete。所有元信息
同样在**请求头**里。

| 方法 | 端点 | 头 / 查询 |
|------|------|-----------|
| `multipart_init(path, size : Int64, chunk_size?, overwrite?, content_type?, last_modified?, hash?)` | `POST /api/fs/multipart/init` | `File-Path`、`X-File-Size`（**必填且 > 0**）、`X-Chunk-Size`（可选）、其余同上传 |
| `multipart_chunk(upload_id, index : Int, data : Bytes)` | `PUT /api/fs/multipart/chunk` | `X-Upload-Id`、`X-Chunk-Index`，体是原始字节 |
| `multipart_complete(upload_id)` | `POST /api/fs/multipart/complete` | `X-Upload-Id` |
| `multipart_abort(upload_id)` | `POST /api/fs/multipart/abort` | `X-Upload-Id` |
| `multipart_status(upload_id)` | `GET /api/fs/multipart/status?upload_id=` | |
| `multipart_status_by_path(path, size)` | `GET /api/fs/multipart/status?path=&size=` | |
| `multipart_upload(path, data : Bytes, chunk_size?, overwrite?, content_type?, hash?)` | 上面几个的组合 | init → 逐片 → complete |

```moonbit
pub struct MultipartInitResponse {
  snapshot : SessionSnapshot   // 注意：响应体是**平铺**的，snapshot 只是客户端的归类
  resumed : Bool               // true = 复用了旧会话
}
pub struct SessionSnapshot {
  upload_id : String
  state : String
  attempt : Int
  path : String
  size : Int64
  chunk_size : Int64           // 服务端最终采用的片大小
  total_chunks : Int
  received : Array[Array[Int]] // 已收到的分片闭区间，如 [[0, 3]]
  received_bytes : Int64
  frontier : Int
  storage_progress : Double
  error : String?
}
```

要点：

- **空文件不能走分片**（`X-File-Size` 必须为正），请用 `put`。
- 片大小由服务端决定：设置 `MultipartChunkSize`（默认 10 MB，且下限 1 MB）；
  你请求的 `chunk_size` 只在「>0 且小于上限」时生效。所以 `multipart_upload`
  一律用 **init 返回的 `snapshot.chunk_size`** 切片，不用调用方给的值。
- **续传**：`multipart_upload` 会跳过 `snapshot.received` 里已覆盖的分片序号，
  只需要重传缺口。
- **失败时的 `data`**：chunk / complete 出错（`OpenListError::Api`）时，
  `error.data` 里仍是当前 `snapshot`，可以解出来继续续传。错误码映射：
  `ErrOutOfWindow → 429`、`ErrChunkInFlight → 409`、`ErrSessionNotFound → 404`、
  `ErrNotOwner → 403`、其它 → `400`。
- MoonBit 的 `Bytes` 没有 `slice`，切片用
  `data.exact_view(start=from, end=to).to_owned()`。

## 7. 归档与离线下载（`src/fs/archive.mbt`）

| 方法 | 端点 | 返回 |
|------|------|------|
| `archive_meta(path, password?, refresh?, archive_pass?)` | `POST /api/fs/archive/meta` | `ArchiveMetaResponse` |
| `archive_list(path, inner_path?, password?, refresh?, archive_pass?, page?, per_page?)` | `POST /api/fs/archive/list` | `PageResult[ArchiveContent]` |
| `archive_decompress(src_dir, dst_dir, names, archive_pass?, inner_path?, cache_full?, put_into_new_dir?, overwrite?)` | `POST /api/fs/archive/decompress` | `Array[TaskInfo]` |
| `add_offline_download(path, Array[String] urls, tool?)` | `POST /api/fs/add_offline_download` | `Array[TaskInfo]` |

```moonbit
pub struct ArchiveMetaResponse { comment; encrypted : Bool; content : Array[ArchiveContent]
                                 sort : ListSort?; raw_url; sign }
pub struct ArchiveContent { obj : ObjResp; children : Array[ArchiveContent] }
```

- 加密归档要带 `archive_pass`（`meta` 的 `encrypted` 为 true 时）。
- 解压 / 离线下载都是**异步任务**：返回的 `TaskInfo` 可以拿去任务域查询（本项目未
  封装任务域，见 [08](./08-unsupported-endpoints.md)）。
- ⚠️ 响应键名不统一：归档解压是 `data.task`（值是**数组**），离线下载是
  `data.tasks`；本项目两个键都试，对调用方统一成 `Array[TaskInfo]`。
- 判断一个文件能不能解压，先看 `public().archive_extensions()`（见
  [05](./05-public.md)）。

## 8. 示例

```moonbit
let fs = client.fs()

let entries = fs.list("/")
println(entries.total)
for item in entries.content {
  println("\{item.name} dir=\{item.is_dir} size=\{item.size}")
}

fs.mkdir("/docs")
fs.move_to("/tmp", "/docs", ["a.txt"], overwrite=true)
fs.batch_rename("/docs", [@open-list.RenameObject::new("a.txt", "b.txt")])
println(fs.create_link("/docs/b.txt").url)

let bytes : Bytes = load_something()
fs.put_bytes("/docs/b.txt", bytes, content_type="text/plain")          // 同步
let task = fs.put_bytes("/docs/c.bin", bytes, as_task=true)            // 异步
let snapshot = fs.multipart_upload("/docs/big.zip", big_bytes)          // 分片（自动续传）
println(snapshot.received_bytes)

let tasks = fs.archive_decompress("/docs", "/out", ["pkg.zip"], archive_pass="123")
println(tasks.length())
```

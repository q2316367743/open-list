///|
/// 上传：流式上传（`PUT /api/fs/put`）与表单上传（`PUT /api/fs/form`）。
///
/// 服务端把上传元信息全放在**请求头**里（`File-Path`、`X-File-Size`、
/// `Overwrite`、哈希……），请求体就是原始字节。`File-Path` 要求 URL 编码，
/// 这里统一用 RFC 3986 的百分号编码（`@core.url_path_encode`）。

///|
/// 组装上传用的请求头。
///
/// `Overwrite` 只在明确要求「不覆盖」时才出现：服务端把缺失与任意非
/// `"false"` 的值都当作「允许覆盖」。`size` 是文件字节数：服务端在
/// `Content-Length` 缺失（chunked）时才读 `X-File-Size`，但既然知道大小就
/// 一并带上——请求因此自描述，也不受代理改写长度的影响。
///
/// `send_content_type=false` 给表单上传用：那时请求的 `Content-Type` 必须是
/// `multipart/form-data; boundary=…`，业务 MIME 只能挂在 multipart 分片上
/// （服务端读 `file.Header.Get("Content-Type")`），不能被这里覆盖掉。
fn put_headers(
  path : String,
  size : Int?,
  overwrite? : Bool,
  content_type? : String,
  last_modified? : Int64,
  hash? : FileHash,
  send_content_type? : Bool,
) -> Array[(String, String)] {
  let headers : Array[(String, String)] = [
    ("File-Path", @core.url_path_encode(path)),
  ]
  match size {
    Some(value) => headers.push(("X-File-Size", value.to_string()))
    None => ()
  }
  if overwrite == Some(false) {
    headers.push(("Overwrite", "false"))
  }
  if send_content_type != Some(false) {
    match content_type {
      Some(value) => headers.push(("Content-Type", value))
      None => ()
    }
  }
  match last_modified {
    Some(value) => headers.push(("Last-Modified", value.to_string()))
    None => ()
  }
  match hash {
    Some(value) => {
      match value.md5 {
        Some(text) => headers.push(("X-File-Md5", text))
        None => ()
      }
      match value.sha1 {
        Some(text) => headers.push(("X-File-Sha1", text))
        None => ()
      }
      match value.sha256 {
        Some(text) => headers.push(("X-File-Sha256", text))
        None => ()
      }
    }
    None => ()
  }
  headers
}

///|
/// 从上传响应里读任务：`{"task": {...}}`。
///
/// `data` 是 `null` 时表示服务端已经同步传完（没有任务），返回 `None`。
fn decode_task(data : Json) -> @core.TaskInfo? raise @core.OpenListError {
  match data {
    Null => None
    Object(fields) =>
      match fields.get("task") {
        Some(task) => Some(@core.decode_data(task))
        None => None
      }
    _ => None
  }
}

///|
/// 从归档/离线下载响应里读任务数组（键名是 `task` 或 `tasks`）。
///
/// 归档解压用的键是 `task`（值是数组），离线下载用的是 `tasks`，所以两个键
/// 都试一遍；都没有时给空数组。
fn decode_tasks(data : Json) -> Array[@core.TaskInfo] raise @core.OpenListError {
  match data {
    Object(fields) =>
      match fields.get("tasks") {
        Some(tasks) =>
          match tasks {
            Null => []
            _ => @core.decode_data(tasks)
          }
        None =>
          match fields.get("task") {
            Some(task) =>
              match task {
                Null => []
                _ => @core.decode_data(task)
              }
            None => []
          }
      }
    _ => []
  }
}

///|
/// 流式上传一个文件（`PUT /api/fs/put`）。
///
/// `reader` 是文件内容的读取流：大文件不要先读进内存，直接用
/// `@fs.File::open(...)` 之类的读到 `Reader` 传进来。`content_length` 给了就按
/// 定长发送（同时带上 `X-File-Size`），不给就按 `Transfer-Encoding: chunked`
/// 发送——那种情况下服务端只认 `X-File-Size`，所以流式上传务必给出大小。
///
/// 返回值：`as_task` 为真（且服务端接受了异步任务）时是刚创建的任务，否则是
/// `None`——**同步上传完毕**。要进度回调可以用
/// `OpenListClient::request` 自己拼配置，或后续版本再加。
pub async fn FileSystem::put(
  self : FileSystem,
  path : String,
  reader : &@io.Reader,
  content_length? : Int,
  overwrite? : Bool,
  as_task? : Bool,
  content_type? : String,
  last_modified? : Int64,
  hash? : FileHash,
) -> @core.TaskInfo? raise @core.OpenListError {
  let headers = put_headers(
    path,
    content_length,
    overwrite?,
    content_type?,
    last_modified?,
    hash?,
  )
  if as_task == Some(true) {
    headers.push(("As-Task", "true"))
  }
  let data = self.client.send_stream(
    @moonhttp.Method::Put,
    "/api/fs/put",
    reader,
    content_length?,
    headers~,
  )
  decode_task(data)
}

///|
/// 上传一块已经在内存里的字节（`PUT /api/fs/put` 的便捷版）。
///
/// 适合小文件；大文件请用 `put` 传流，避免把整个文件读进内存。
pub async fn FileSystem::put_bytes(
  self : FileSystem,
  path : String,
  data : Bytes,
  overwrite? : Bool,
  as_task? : Bool,
  content_type? : String,
  last_modified? : Int64,
  hash? : FileHash,
) -> @core.TaskInfo? raise @core.OpenListError {
  self.put(
    path,
    @core.bytes_reader(data),
    content_length=data.length(),
    overwrite?,
    as_task?,
    content_type?,
    last_modified?,
    hash?,
  )
}

///|
/// 用 `multipart/form-data` 上传（`PUT /api/fs/form`）。
///
/// 表单字段名固定是 `file`；`filename` 只用于让服务端猜 MIME 类型。
/// 除了请求体形态不同，头与语义都和 `put` 一样。
pub async fn FileSystem::put_form(
  self : FileSystem,
  path : String,
  filename : String,
  data : Bytes,
  overwrite? : Bool,
  as_task? : Bool,
  content_type? : String,
  last_modified? : Int64,
  hash? : FileHash,
) -> @core.TaskInfo? raise @core.OpenListError {
  let headers = put_headers(
    path,
    Some(data.length()),
    overwrite?,
    content_type?,
    last_modified?,
    hash?,
    send_content_type=false,
  )
  if as_task == Some(true) {
    headers.push(("As-Task", "true"))
  }
  let form = @moonhttp.FormData::new().append_file(
    "file",
    filename,
    data,
    content_type?,
  )
  let payload = self.client.send_form(
    @moonhttp.Method::Put,
    "/api/fs/form",
    form,
    headers~,
  )
  decode_task(payload)
}

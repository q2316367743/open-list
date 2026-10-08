///|
/// 分片上传：`/api/fs/multipart/*`。
///
/// 全部请求参数都在**请求头**里，请求体是原始分片字节。服务端会尽量复用未
/// 完成的会话：`multipart_init` 返回的 `resumed` 为真时，`snapshot.received`
/// 里已经有服务端收过的分片区间，重传会被拒绝（429/409），所以按区间跳过。
///
/// 注意两点服务端约束：
///
/// - 分片大小由服务端决定（默认 10MB，且有 1MB 下限），`chunk_size` 只是建议值；
///   实际的每片大小以 `snapshot.chunk_size` 为准；
/// - `X-File-Size` 必须大于 0，空文件请走 `/fs/put`。

///|
/// 分片上传的请求头。
fn multipart_headers(
  path : String,
  size : Int64,
  chunk_size? : Int,
  overwrite? : Bool,
  content_type? : String,
  last_modified? : Int64,
  hash? : FileHash,
) -> Array[(String, String)] {
  let headers = put_headers(
    path,
    // `size` 是 Int64，这里自己按原值补头，避免先窄化成 Int。
    None,
    overwrite?,
    content_type?,
    last_modified?,
    hash?,
  )
  headers.push(("X-File-Size", size.to_string()))
  match chunk_size {
    Some(value) => headers.push(("X-Chunk-Size", value.to_string()))
    None => ()
  }
  headers
}

///|
/// 判断某个分片是否已经被服务端收下（`received` 里是闭区间）。
fn chunk_received(received : Array[Array[Int]], index : Int) -> Bool {
  let mut hit = false
  for range in received {
    if range.length() >= 2 && index >= range[0] && index <= range[1] {
      hit = true
    }
  }
  hit
}

///|
/// 初始化（或续用）一个分片上传会话（`POST /api/fs/multipart/init`）。
///
/// `size` 是文件总字节数，必须大于 0。`chunk_size` 只是建议值，服务端会把它
/// 夹到 `[1MB, 配置上限]` 之间；实际值看返回的 `snapshot.chunk_size`。
pub async fn FileSystem::multipart_init(
  self : FileSystem,
  path : String,
  size : Int64,
  chunk_size? : Int,
  overwrite? : Bool,
  content_type? : String,
  last_modified? : Int64,
  hash? : FileHash,
) -> @core.MultipartInitResponse raise @core.OpenListError {
  let headers = multipart_headers(
    path,
    size,
    chunk_size?,
    overwrite?,
    content_type?,
    last_modified?,
    hash?,
  )
  let data = self.client.request(
    @moonhttp.Method::Post,
    "/api/fs/multipart/init",
    headers~,
  )
  @core.decode_data(data)
}

///|
/// 上传一个分片（`PUT /api/fs/multipart/chunk`）。
///
/// `index` 从 0 开始。分片被拒时（分片乱序、重复、会话不见了）服务端会把当前
/// 会话快照放在错误响应的 `data` 里，所以抛出的 `OpenListError::Api` 的
/// `ApiError::data` 里仍然能拿到进度，可以据此重试或继续。
pub async fn FileSystem::multipart_chunk(
  self : FileSystem,
  upload_id : String,
  index : Int,
  data : Bytes,
) -> @core.SessionSnapshot raise @core.OpenListError {
  let headers : Array[(String, String)] = [
    ("X-Upload-Id", upload_id),
    ("X-Chunk-Index", index.to_string()),
  ]
  let payload = self.client.send_stream(
    @moonhttp.Method::Put,
    "/api/fs/multipart/chunk",
    @core.bytes_reader(data),
    content_length=data.length(),
    headers~,
  )
  @core.decode_data(payload)
}

///|
/// 声明分片传完，等服务端合并（`POST /api/fs/multipart/complete`）。
///
/// 返回最终快照；驱动真正写盘失败时会抛 `OpenListError::Api`，`state` 与
/// `error` 在错误的 `data` 里。
pub async fn FileSystem::multipart_complete(
  self : FileSystem,
  upload_id : String,
) -> @core.SessionSnapshot raise @core.OpenListError {
  let data = self.client.request(
    @moonhttp.Method::Post,
    "/api/fs/multipart/complete",
    headers=[("X-Upload-Id", upload_id)],
  )
  @core.decode_data(data)
}

///|
/// 按会话 ID 查分片上传进度（`GET /api/fs/multipart/status?upload_id=`）。
pub async fn FileSystem::multipart_status(
  self : FileSystem,
  upload_id : String,
) -> @core.SessionSnapshot raise @core.OpenListError {
  let query = @core.query_json([("upload_id", Some(Json::string(upload_id)))])
  let data = self.client.request(
    @moonhttp.Method::Get,
    "/api/fs/multipart/status",
    query~,
  )
  @core.decode_data(data)
}

///|
/// 按「目标路径 + 总大小」查分片上传进度
/// （`GET /api/fs/multipart/status?path=&size=`）。
///
/// 用于客户端重启后找回未完成的会话，不需要记住 `upload_id`。
pub async fn FileSystem::multipart_status_by_path(
  self : FileSystem,
  path : String,
  size : Int64,
) -> @core.SessionSnapshot raise @core.OpenListError {
  let query = @core.query_json([
    ("path", Some(Json::string(path))),
    ("size", Some(Json::number(size.to_double()))),
  ])
  let data = self.client.request(
    @moonhttp.Method::Get,
    "/api/fs/multipart/status",
    query~,
  )
  @core.decode_data(data)
}

///|
/// 放弃一个分片上传会话（`POST /api/fs/multipart/abort`）。
pub async fn FileSystem::multipart_abort(
  self : FileSystem,
  upload_id : String,
) -> Unit raise @core.OpenListError {
  self.post_quiet("/api/fs/multipart/abort", headers=[
    ("X-Upload-Id", upload_id),
  ])
}

///|
/// 一步做完「初始化 → 逐片上传 → 合并」。
///
/// 分片大小以服务端返回的 `snapshot.chunk_size` 为准；已经在服务端手里的分片
/// （续传场景）会被跳过，所以这个函数可以安全地用同一个文件重跑。
///
/// 只适合「整块字节已在内存里」的场景（手机端小文件、测试）；大文件请按需自己
/// 调 `multipart_init` / `multipart_chunk` / `multipart_complete` 传流。
pub async fn FileSystem::multipart_upload(
  self : FileSystem,
  path : String,
  data : Bytes,
  chunk_size? : Int,
  overwrite? : Bool,
  content_type? : String,
  hash? : FileHash,
) -> @core.SessionSnapshot raise @core.OpenListError {
  let total = data.length()
  let init = self.multipart_init(
    path,
    total.to_int64(),
    chunk_size?,
    overwrite?,
    content_type?,
    hash?,
  )
  let mut snapshot = init.snapshot
  let raw_chunk = snapshot.chunk_size.to_int()
  // 服务端一定会给出正的分片大小；万一没有就退化成「一次传完」。
  let chunk = if raw_chunk > 0 { raw_chunk } else { total }
  let mut index = 0
  while index * chunk < total {
    let start = index * chunk
    let end = if start + chunk < total { start + chunk } else { total }
    if !chunk_received(snapshot.received, index) {
      let piece = data.exact_view(start~, end~).to_owned()
      snapshot = self.multipart_chunk(snapshot.upload_id, index, piece)
    }
    index = index + 1
  }
  self.multipart_complete(snapshot.upload_id)
}

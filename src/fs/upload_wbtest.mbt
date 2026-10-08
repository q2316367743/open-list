///|
/// fs 上传相关的白盒测试：流式上传（/fs/put）、表单上传、分片上传、归档与离线下载。
///
/// 这里最关键的是「请求头 + 流式请求体的字节」：OpenList 把上传元信息全放在
/// 请求头里（`File-Path` 要 RFC 3986 编码、`X-File-Size` 必填、`Overwrite` 只把
/// `"false"` 当禁止），分片内容则完全靠服务端返回的 `chunk_size` 切片。

///|
async test "put：File-Path 编码、As-Task / Overwrite 头、流式字节" {
  let (fs, transport) = fs_with([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"task\":{\"id\":\"t1\",\"name\":\"a b.txt\",\"state\":\"pending\",\"progress\":0.0}}}",
    ),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
  ])
  let task = fs.put_bytes(
    "/dir/a b.txt",
    @utf8.encode("hello"),
    as_task=true,
    overwrite=false,
  )
  let info = match task {
    Some(info) => info
    None => panic()
  }
  assert_eq(info.id, "t1")
  assert_eq(info.name, "a b.txt")
  assert_eq(info.state, "pending")
  let requests = transport.received()
  assert_eq(requests[0].url, "https://openlist.example.com/api/fs/put")
  assert_eq(requests[0].http_method, @moonhttp.Method::Put)
  // 编码口径与 OpenList 前端一致（RFC 3986 / encodeURIComponent）：斜杠也编成 %2F，
  // 服务端是 url.PathUnescape，两种都能还原。
  assert_header(requests[0], "File-Path", "%2Fdir%2Fa%20b.txt")
  assert_header(requests[0], "As-Task", "true")
  assert_header(requests[0], "Overwrite", "false")
  assert_header(requests[0], "X-File-Size", "5")
  // 流式请求体被传输层泵完了，字节要和服务端收到的一致。
  assert_eq(transport.streamed(0), "hello")
  // 同步上传（data 是 null）时没有任务可返回，也不发 As-Task / Overwrite。
  let none = fs.put_bytes("/dir/c.txt", @utf8.encode("hi"))
  assert_true(none is None)
  let second = requests[1]
  assert_eq(second.headers.get("As-Task"), None)
  assert_eq(second.headers.get("Overwrite"), None)
  assert_eq(transport.streamed(1), "hi")
}

///|
async test "put：内容类型、修改时间与校验和都落到请求头" {
  let (fs, transport) = fs_with([
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
  ])
  ignore(
    fs.put_bytes(
      "/a.txt",
      b"xy",
      content_type="text/plain",
      last_modified=1700000000000L,
      hash=FileHash::new(md5="d41d8", sha1="a9993", sha256="5fece"),
    ),
  )
  let request = transport.received()[0]
  assert_header(request, "Content-Type", "text/plain")
  assert_header(request, "Last-Modified", "1700000000000")
  assert_header(request, "X-File-Md5", "d41d8")
  assert_header(request, "X-File-Sha1", "a9993")
  assert_header(request, "X-File-Sha256", "5fece")
  // content_length 声明了，传输层按定长发送。
  match request.body {
    Some(@transport.RequestBody::Stream(stream)) =>
      assert_eq(stream.content_length, Some(2))
    _ => panic()
  }
}

///|
async test "put_form：multipart 表单字段名是 file" {
  let (fs, transport) = fs_with([
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
  ])
  ignore(
    fs.put_form(
      "/dir/a.txt",
      "a.txt",
      @utf8.encode("hello"),
      content_type="text/plain",
    ),
  )
  let request = transport.received()[0]
  assert_header(request, "File-Path", "%2Fdir%2Fa.txt")
  // 请求头必须留给 multipart 的 boundary，业务 MIME 只在分片头上。
  match request.headers.get("Content-Type") {
    Some(value) => assert_true(value.contains("multipart/form-data"))
    None => panic()
  }
  let payload = match request.body {
    Some(@transport.RequestBody::Buffered(bytes)) => @utf8.decode(bytes)
    _ => panic()
  }
  assert_true(payload.contains("name=\"file\""))
  assert_true(payload.contains("filename=\"a.txt\""))
  assert_true(payload.contains("text/plain"))
  assert_true(payload.contains("hello"))
}

///|
async test "create_link：直链字段按 Link 模型解码" {
  let (fs, _) = fs_with([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"url\":\"https://cdn/x\",\"header\":{\"Referer\":[\"https://a\"]},\"concurrency\":4,\"part_size\":1048576,\"content_length\":1024}}",
    ),
  ])
  let link = fs.create_link("/dir/a.txt")
  assert_eq(link.url, "https://cdn/x")
  assert_eq(link.concurrency, 4)
  assert_eq(link.part_size, 1048576)
  assert_eq(link.content_length, 1024L)
  assert_eq(link.header.get("Referer"), Some(["https://a"]))
}

///|
async test "add_offline_download 与 archive_decompress：读 tasks / task 两种键" {
  let (fs, transport) = fs_with([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"tasks\":[{\"id\":\"t1\",\"name\":\"u1\",\"state\":\"pending\"}]}}",
    ),
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"task\":[{\"id\":\"t2\",\"name\":\"a.zip\",\"state\":\"pending\"},{\"id\":\"t3\",\"name\":\"b.zip\",\"state\":\"running\"}]}}",
    ),
  ])
  let tasks = fs.add_offline_download(
    "/dir",
    ["https://example.com/a"],
    tool="aria2",
  )
  assert_eq(tasks.length(), 1)
  assert_eq(tasks[0].id, "t1")
  let decompressed = fs.archive_decompress("/dir", "/dir/out", ["a"])
  assert_eq(decompressed.length(), 2)
  assert_eq(decompressed[1].id, "t3")
  assert_eq(decompressed[1].state, "running")
  let body = body_json(transport.received()[0])
  assert_json_string(body, "tool", "aria2")
  let urls = match field(body, "urls") {
    Array(items) => items
    _ => panic()
  }
  assert_eq(urls.length(), 1)
  // 归档解压的字段名是单数 name。
  let archive_body = body_json(transport.received()[1])
  assert_json_string(archive_body, "src_dir", "/dir")
  assert_json_string(archive_body, "dst_dir", "/dir/out")
  assert_true(
    match field(archive_body, "name") {
      Array(_) => true
      _ => panic()
    },
  )
}

///|
async test "multipart_init：文件大小与分片建议走请求头，不覆盖时不发 Overwrite" {
  let (fs, transport) = fs_with([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"upload_id\":\"u1\",\"state\":\"uploading\",\"path\":\"/big.zip\",\"size\":10,\"chunk_size\":4,\"total_chunks\":3,\"received\":[],\"received_bytes\":0,\"frontier\":0,\"storage_progress\":0.0,\"resumed\":false}}",
    ),
  ])
  let init = fs.multipart_init(
    "/big.zip",
    10L,
    chunk_size=4,
    hash=FileHash::new(md5="d41d8"),
  )
  assert_eq(init.snapshot.upload_id, "u1")
  assert_eq(init.snapshot.chunk_size, 4L)
  assert_eq(init.snapshot.total_chunks, 3)
  assert_true(!init.resumed)
  let request = transport.received()[0]
  assert_eq(request.url, "https://openlist.example.com/api/fs/multipart/init")
  assert_header(request, "File-Path", "%2Fbig.zip")
  assert_header(request, "X-File-Size", "10")
  assert_header(request, "X-Chunk-Size", "4")
  assert_header(request, "X-File-Md5", "d41d8")
  // 默认允许覆盖，所以不发 Overwrite（服务端只把 "false" 当禁止覆盖）。
  assert_eq(request.headers.get("Overwrite"), None)
  assert_eq(request.headers.get("As-Task"), None)
}

///|
async test "multipart_upload：按服务端给的分片大小切分、跳过已收到的分片" {
  let (fs, transport) = fs_with([
    // init：服务端说分片大小是 2，且第 0 片已经收过了（续传）。
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"upload_id\":\"u1\",\"state\":\"uploading\",\"path\":\"/big\",\"size\":4,\"chunk_size\":2,\"total_chunks\":2,\"received\":[[0,0]],\"received_bytes\":2,\"frontier\":1,\"storage_progress\":0.5,\"resumed\":true}}",
    ),
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"upload_id\":\"u1\",\"state\":\"uploading\",\"path\":\"/big\",\"size\":4,\"chunk_size\":2,\"total_chunks\":2,\"received\":[[0,1]],\"received_bytes\":4,\"frontier\":2,\"storage_progress\":1.0}}",
    ),
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"upload_id\":\"u1\",\"state\":\"succeeded\",\"path\":\"/big\",\"size\":4,\"chunk_size\":2,\"total_chunks\":2,\"received\":[[0,1]],\"received_bytes\":4,\"frontier\":2,\"storage_progress\":1.0}}",
    ),
  ])
  let snapshot = fs.multipart_upload("/big", b"abcd", chunk_size=2)
  assert_eq(snapshot.state, "succeeded")
  let requests = transport.received()
  assert_eq(requests.length(), 3)
  assert_eq(
    requests[1].url,
    "https://openlist.example.com/api/fs/multipart/chunk",
  )
  assert_header(requests[1], "X-Upload-Id", "u1")
  assert_header(requests[1], "X-Chunk-Index", "1")
  // 只重传缺的那一片：第 0 片已经在服务端了。
  assert_eq(transport.streamed(1), "cd")
  assert_header(requests[2], "X-Upload-Id", "u1")
  assert_eq(
    requests[2].url,
    "https://openlist.example.com/api/fs/multipart/complete",
  )
}

///|
async test "multipart_status / abort：查询参数与请求头" {
  let (fs, transport) = fs_with([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"upload_id\":\"u1\",\"state\":\"uploading\",\"size\":4,\"chunk_size\":2,\"total_chunks\":2}}",
    ),
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"upload_id\":\"u1\",\"state\":\"uploading\",\"size\":4,\"chunk_size\":8,\"total_chunks\":1}}",
    ),
    raw_json(200, "{\"code\":200,\"message\":\"success\",\"data\":null}"),
  ])
  let by_id = fs.multipart_status("u1")
  assert_eq(by_id.upload_id, "u1")
  let by_path = fs.multipart_status_by_path("/big", 4L)
  assert_eq(by_path.chunk_size, 8L)
  fs.multipart_abort("u1")
  let requests = transport.received()
  assert_eq(
    requests[0].url,
    "https://openlist.example.com/api/fs/multipart/status?upload_id=u1",
  )
  assert_eq(
    requests[1].url,
    "https://openlist.example.com/api/fs/multipart/status?path=%2Fbig&size=4",
  )
  assert_header(requests[2], "X-Upload-Id", "u1")
  assert_eq(
    requests[2].url,
    "https://openlist.example.com/api/fs/multipart/abort",
  )
}

///|
async test "archive_meta / archive_list：加密包与包内分页" {
  let (fs, transport) = fs_with([
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"comment\":\"\",\"encrypted\":true,\"content\":[{\"name\":\"a.txt\",\"size\":3,\"is_dir\":false,\"children\":[]}],\"raw_url\":\"https://x/a.zip\",\"sign\":\"s\"}}",
    ),
    raw_json(
      200, "{\"code\":200,\"message\":\"success\",\"data\":{\"content\":[{\"name\":\"a.txt\",\"size\":3,\"is_dir\":false,\"children\":[]}],\"total\":1}}",
    ),
  ])
  let meta = fs.archive_meta("/a.zip", archive_pass="pw")
  assert_true(meta.encrypted)
  assert_eq(meta.content.length(), 1)
  assert_eq(meta.content[0].obj.name, "a.txt")
  assert_eq(meta.raw_url, "https://x/a.zip")
  let inner = fs.archive_list(
    "/a.zip",
    inner_path="sub",
    archive_pass="pw",
    page=1,
  )
  assert_eq(inner.total, 1L)
  assert_eq(inner.content[0].obj.size, 3L)
  let first = body_json(transport.received()[0])
  assert_json_string(first, "archive_pass", "pw")
  let second = body_json(transport.received()[1])
  assert_json_string(second, "inner_path", "sub")
  assert_json_int(second, "page", 1)
}

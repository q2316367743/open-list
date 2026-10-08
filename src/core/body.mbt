///|
/// 请求体的辅助工具：二进制流与路径编码。
///
/// moonhttp 的请求体构造器没有「裸字节」那一档，二进制只能走
/// `Config::with_data_from_stream`，所以 `/api/fs/put`、
/// `/api/fs/multipart/chunk` 需要一个 `Reader`。

///|
/// 把一段内存里的字节包装成可读流。
///
/// 上传大文件时不要用它把整个文件读进内存，而是自己打开文件拿到 `Reader`
/// 交给 `FileSystem::put`；这个助手更适合「手里已经有一块字节」的场景
/// （分片上传的每一片、表单里的小文件）。
pub fn bytes_reader(data : Bytes) -> &@io.Reader {
  @io.MemoryReader::MemoryReader(async fn(writer) { writer.write(data) })
}

///|
/// 对路径做百分号编码（RFC 3986，空格是 `%20`）。
///
/// OpenList 的 `File-Path` 请求头要求路径是 URL 编码过的（服务端做
/// `url.PathUnescape`）。注意不能用 form 风格编码：`PathUnescape` 不会把
/// `+` 还原成空格，那样文件名里的空格会变成字面量加号。
pub fn url_path_encode(path : String) -> String {
  @percent.encode(path)
}

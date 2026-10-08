///|
/// 文件系统域里不适合塞进方法可选参数的辅助类型。

///|
/// 上传时可选提供的文件哈希，服务端拿它做一致性校验（也用于判断能否跳过
/// 重复上传）。
///
/// 三个字段都是十六进制小写字符串；只有服务端信任这个值，算不准就别填。
pub struct FileHash {
  /// MD5（十六进制）。
  md5 : String?
  /// SHA1（十六进制）。
  sha1 : String?
  /// SHA256（十六进制）。
  sha256 : String?
}

///|
/// 按需构造文件哈希，只填知道的算法。
pub fn FileHash::new(
  md5? : String,
  sha1? : String,
  sha256? : String,
) -> FileHash {
  { md5, sha1, sha256, }
}

///|
/// 批量重命名里的一项：把 `src_name` 改成 `new_name`。
pub struct RenameObject {
  /// 原文件名。
  src_name : String
  /// 新文件名。
  new_name : String
}

///|
/// 构造一条重命名项。
pub fn RenameObject::new(src_name : String, new_name : String) -> RenameObject {
  { src_name, new_name, }
}

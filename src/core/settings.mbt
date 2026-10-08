///|
/// 连接一台 OpenList 服务器所需的设置。
///
/// 这些值在创建客户端时被固化进 moonhttp 的默认配置：`base_url` 成为
/// 请求 URL 的前缀，`timeout` 成为默认超时；之后每个请求只给相对路径。
pub struct Settings {
  /// 服务器根地址，例如 `https://openlist.example.com`。
  /// 结尾多余的 `/` 会在创建客户端时被去掉。
  base_url : String
  /// 默认请求超时（毫秒）。`None` 表示沿用 moonhttp 的默认超时。
  timeout : Int?
}

///|
/// 创建连接设置。
///
/// ```moonbit nocheck
/// let settings = @core.Settings::new("https://openlist.example.com")
/// ```
pub fn Settings::new(base_url : String, timeout? : Int) -> Settings {
  // 结尾的 `/`（以及多余空白）在入口就归一化，客户端拿到的设置即最终值。
  {
    base_url: base_url.trim_end().to_owned().trim_end(chars="/").to_owned(),
    timeout,
  }
}

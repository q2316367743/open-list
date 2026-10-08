///|
/// 服务端返回的业务错误：HTTP 响应已经到达，但信封里的 `code` 不是 200。
///
/// OpenList 用 `code` 表达业务结果，HTTP 状态码只是它的粗粒度映射，
/// 所以两边都保留：`code`/`message` 来自信封，`status` 来自 HTTP 状态行。
pub struct ApiError {
  /// 业务错误码（信封里的 `code`）。
  code : Int
  /// 业务错误消息（信封里的 `message`）。
  message : String
  /// HTTP 状态码。
  status : Int
  /// 错误响应携带的 `data`；字段缺失或为 `null` 时是 `None`。
  data : Json?
} derive(@debug.Debug)

///|
/// 显式声明 `derive` 出来的 `Debug` 实现以普通方法暴露，避免工具链的
/// 「隐式提升为方法」弃用告警（行为与 `derive` 完全一致）。
pub extend ApiError with @debug.Debug::{to_repr}

///|
/// 客户端可能抛出的全部错误。
pub(all) suberror OpenListError {
  /// 传输层错误：连接失败、超时、取消、非法 URL 等（原样保留 moonhttp 的错误）。
  Http(@moonhttp.HttpError)
  /// 业务错误：服务端信封里的 `code` 不是 200。
  Api(ApiError)
  /// 协议错误：响应不是 JSON 信封，或 `data` 无法解码成目标类型。
  Decode(String)
}

///|
/// 人类可读的一行错误消息，适合直接写日志。
pub fn OpenListError::message(self : OpenListError) -> String {
  match self {
    Http(error) => "HTTP: \{error.message()}"
    Api(error) => "API \{error.code}: \{error.message}"
    Decode(message) => "Decode: \{message}"
  }
}

///|
/// 对应的 HTTP 状态码；传输层没拿到响应时是 `None`。
pub fn OpenListError::status(self : OpenListError) -> Int? {
  match self {
    Http(error) =>
      match error.response() {
        Some(response) => Some(response.status)
        None => None
      }
    Api(error) => Some(error.status)
    Decode(_) => None
  }
}

///|
/// 业务错误码；不是 `Api` 错误时是 `None`。
pub fn OpenListError::code(self : OpenListError) -> Int? {
  match self {
    Api(error) => Some(error.code)
    _ => None
  }
}

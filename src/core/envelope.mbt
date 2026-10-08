///|
/// OpenList 的统一响应信封 `{code, message, data}`。
///
/// 只在 core 内部使用：域子模块拿到的是解码后的业务类型或 `OpenListError`。
priv struct Envelope {
  /// 业务结果码；`200` 表示成功。
  code : Int
  /// 业务消息；成功时服务端固定给 `"success"`。
  message : String
  /// 业务载荷；字段缺失或为 `null` 时是 `None`。
  data : Json?
}

///|
/// 截断过长的响应文本，避免把整个 HTML 错误页塞进异常消息。
fn preview(text : String) -> String {
  let chars = text.to_array()
  if chars.length() <= 200 {
    text
  } else {
    "\{String::from_array(chars[:200])}…"
  }
}

///|
/// 把响应文本解析成信封。
///
/// 不是 JSON 对象、或缺少数值型 `code` 都算协议错误（`Decode`）：前者通常
/// 意味着请求打到了反代 / 路由不存在的 404 页面（OpenList 对未知路径会返回
/// 前端 HTML），后者说明服务端不是 OpenList。消息里带上 HTTP 状态，方便区分
/// 「服务端版本没有这个路由」和「真的解析失败」。
fn Envelope::parse(status : Int, text : String) -> Envelope raise OpenListError {
  let json = @json.parse(text) catch {
    _ =>
      raise OpenListError::Decode(
        "HTTP \{status}：响应不是合法 JSON：\{preview(text)}",
      )
  }
  guard json is Object(fields) else {
    raise OpenListError::Decode(
      "HTTP \{status}：响应不是 JSON 对象：\{preview(text)}",
    )
  }
  let code : Int = match fields.get("code") {
    Some(value) =>
      @json.from_json(value) catch {
        _ =>
          raise OpenListError::Decode(
            "HTTP \{status}：响应缺少整数 code：\{preview(text)}",
          )
      }
    None =>
      raise OpenListError::Decode(
        "HTTP \{status}：响应缺少 code 字段：\{preview(text)}",
      )
  }
  let message : String = match fields.get("message") {
    Some(String(value)) => value
    _ => ""
  }
  let data : Json? = match fields.get("data") {
    Some(Json::Null) => None
    Some(value) => Some(value)
    None => None
  }
  { code, message, data, }
}

///|
/// 信封里的 `data`；缺失或 `null` 时退化成 `Json::Null`。
fn Envelope::data_or_null(self : Envelope) -> Json {
  match self.data {
    Some(value) => value
    None => Json::null()
  }
}

///|
/// `code` 不是 200 就抛业务错误。
fn Envelope::check(self : Envelope, status : Int) -> Unit raise OpenListError {
  if self.code != 200 {
    raise OpenListError::Api(ApiError::{
      code: self.code,
      message: self.message,
      status,
      data: self.data,
    })
  }
}

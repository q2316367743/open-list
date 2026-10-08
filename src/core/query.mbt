///|
/// 查询参数构造助手。
///
/// 六个域子模块都要拼 `?page=1&per_page=20` 这类查询串：可选参数不传时
/// 必须整个键都不出现（传 `null` 会被服务端的 `strconv` 解析成空串或报错），
/// 所以这里收「键 + 可选值」的列表，只把 `Some` 的写进 JSON 对象。
///
/// 交给 moonhttp 的默认序列化器拼 URL：数字会写成 `1` 而不是 `1.0`，
/// 字符串会做百分号编码（路径里带中文、空格都由它负责）。

///|
/// 把 `键 -> 可选值` 列表变成查询参数对象。
///
/// ```moonbit nocheck
/// let query = @core.query_json([
///   ("page", Some(Json::number(1))),
///   ("path", Some(Json::string("/docs"))),
///   ("refresh", None),
/// ])
/// // => {"page": 1, "path": "/docs"}
/// ```
pub fn query_json(pairs : Array[(String, Json?)]) -> Json {
  let fields : Map[String, Json] = Map([])
  for pair in pairs {
    let (key, value) = pair
    match value {
      Some(value) => fields.set(key, value)
      None => ()
    }
  }
  Json::object(fields)
}

///|
/// 整数查询参数的便捷写法（`Json::number` 收的是 `Double`）。
pub fn query_int(value : Int) -> Json {
  Json::number(value.to_double())
}

///|
/// 字符串查询参数的便捷写法。
pub fn query_string(value : String) -> Json {
  Json::string(value)
}

///|
/// 分页参数的键值对：`page` 与 `per_page`，未提供的不会出现。
///
/// 服务端对分页参数很宽容（`page < 1` 视作 1、`per_page < 1` 视作不限），
/// 所以调用方不传就是「用服务端默认行为」。
///
/// ```moonbit nocheck
/// let query = @core.query_json(@core.page_pairs(page=1))
/// // => {"page": 1}
/// ```
pub fn page_pairs(page? : Int, per_page? : Int) -> Array[(String, Json?)] {
  let pairs : Array[(String, Json?)] = []
  match page {
    Some(value) => pairs.push(("page", Some(query_int(value))))
    None => ()
  }
  match per_page {
    Some(value) => pairs.push(("per_page", Some(query_int(value))))
    None => ()
  }
  pairs
}

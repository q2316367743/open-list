///|
/// JSON 解码助手，以及分页响应的统一形状。
///
/// OpenList 有两个与 MoonBit core json 不一致的地方，这里统一处理：
///
/// 1. 可选字段既可能「缺失」也可能显式写成 `null`，而 MoonBit 的 `T?` 字段只在
///    字段缺失时给出 `None`、显式 `null` 会让内层类型解码失败。因此带类型化
///    解码的通道统一先过一遍 `strip_nulls`：把对象里所有 `null` 字段删掉，
///    于是 `T?` 字段的语义就变得干净（有值 → `Some`，没有值 → `None`）。
/// 2. Go 的 `int64`/`uint64` 会被序列化成 JSON **数字**，而 core json 的
///    `Int64::from_json` 只接受字符串形态（JSON 数字统一按 `Double` 解析）。
///    所以带 64 位整数字段的模型手写 `FromJson`，用 `int64_field` 读它们。
///
/// `request` 返回原始 `Json` 的那条逃生通道**不**做剔除，保证用户看到的
/// 是服务端原样返回的数据。

///|
/// 递归剔除 JSON 对象里值为 `null` 的字段；数组元素原样保留但会递归处理。
pub fn strip_nulls(json : Json) -> Json {
  match json {
    Object(fields) => {
      let result : Map[String, Json] = Map([])
      for key, value in fields {
        match value {
          Null => ()
          _ => result[key] = strip_nulls(value)
        }
      }
      Json::object(result)
    }
    Array(items) => Json::array(items.map(strip_nulls))
    other => other
  }
}

///|
/// 读一个字段并按目标类型解码；字段缺失、显式 `null` 或类型不符时给 `None`。
///
/// 手写 `FromJson` 的模型用它读普通字段，避免为每个字段重复一遍 try/catch。
pub fn[T : @json.FromJson] json_field(
  fields : Map[String, Json],
  key : String,
) -> T? {
  match fields.get(key) {
    Some(value) => Some(@json.from_json(value)) catch { _ => None }
    None => None
  }
}

///|
/// 字符串字段，缺失时给空串。
pub fn string_field(fields : Map[String, Json], key : String) -> String {
  json_field(fields, key).unwrap_or("")
}

///|
/// 布尔字段，缺失时给 `false`。
pub fn bool_field(fields : Map[String, Json], key : String) -> Bool {
  json_field(fields, key).unwrap_or(false)
}

///|
/// 32 位整数字段（`role`、`order`、`type` 这类小整数），缺失时给 0。
pub fn int_field(fields : Map[String, Json], key : String) -> Int {
  json_field(fields, key).unwrap_or(0)
}

///|
/// 32 位无符号整数字段（各类 ID），缺失时给 0。
pub fn uint_field(fields : Map[String, Json], key : String) -> UInt {
  json_field(fields, key).unwrap_or(0U)
}

///|
/// 浮点字段（进度百分比这类），缺失时给 0。
pub fn double_field(fields : Map[String, Json], key : String) -> Double {
  json_field(fields, key).unwrap_or(0.0)
}

///|
/// 数组字段；缺失或 `null` 时给空数组。
///
/// Go 会把值为 `nil` 的切片序列化成 `null`（而不是 `[]`），所以模型里的
/// 列表字段一律走这里，用户拿到的永远是数组、不用处理 `null`。
pub fn[T : @json.FromJson] array_field(
  fields : Map[String, Json],
  key : String,
) -> Array[T] {
  json_field(fields, key).unwrap_or([])
}

///|
/// 字符串映射字段（哈希值表这类）；缺失或 `null` 时给空映射。
pub fn[V : @json.FromJson] map_field(
  fields : Map[String, Json],
  key : String,
) -> Map[String, V] {
  json_field(fields, key).unwrap_or(Map([]))
}

///|
/// 64 位整数字段（文件大小、分页总数这类），缺失时给 0。
pub fn int64_field(fields : Map[String, Json], key : String) -> Int64 {
  match fields.get(key) {
    Some(value) => int64_from_json(value).unwrap_or(0L)
    None => 0L
  }
}

///|
/// 把一个 JSON 值读成 `Int64`：接受数字（OpenList 的 `int64` 就是数字），
/// 也接受字符串形态（core json 的 `Int64` 表示法）。
pub fn int64_from_json(value : Json) -> Int64? {
  match value {
    Json::Number(number, ..) => Some(number.to_int64())
    Json::String(text) =>
      Some(@json.from_json(Json::string(text))) catch {
        _ => None
      }
    _ => None
  }
}

///|
/// 把统一信封里的 `data` 解码成目标类型（解码前先剔除 `null` 字段）。
///
/// 解码失败会抛 `OpenListError::Decode`，其中带上 core json 给出的
/// 字段路径与原因，便于定位是哪个接口的哪个字段与模型不符。
pub fn[T : @json.FromJson] decode_data(json : Json) -> T raise OpenListError {
  @json.from_json(strip_nulls(json)) catch {
    @json.JsonDecodeError((_, message)) => raise OpenListError::Decode(message)
  }
}

///|
/// OpenList 分页接口的统一结果。
pub struct PageResult[T] {
  /// 当前页的元素。
  content : Array[T]
  /// 符合条件的记录总数（不是当前页长度）。
  total : Int64
}

///|
/// 创建分页结果。
pub fn[T] PageResult::new(content : Array[T], total : Int64) -> PageResult[T] {
  { content, total, }
}

///|
/// 从 `{content, total}` 形态的 JSON 解码分页结果。
///
/// 两个字段都容错：缺失时退化为空列表 / 0，这样服务端某个版本少给一个
/// 字段也不会让整次请求失败。
pub impl[T : @json.FromJson] @json.FromJson for PageResult[T] with fn from_json(
  json,
  path,
) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError(
      (path, "PageResult::from_json: expected object"),
    )
  }
  let content : Array[T] = json_field(fields, "content").unwrap_or([])
  let total = int64_field(fields, "total")
  { content, total, }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露，避免工具链的
/// 「隐式提升为方法」弃用告警（行为与 `derive` 完全一致）。
pub extend PageResult with @json.FromJson::{from_json}

///|
/// 分享相关的响应模型。
///
/// Go 侧 `handles.SharingResp` 内嵌 `*model.Sharing`（而 `Sharing` 又内嵌
/// `SharingDB` 与 `model.Sort`），JSON 上全是扁平字段，这里同样摊平。

///|
/// 一条分享记录。
pub struct SharingResponse {
  /// 分享 ID（短字符串）。
  id : String
  /// 过期时间（RFC3339 字符串）；永不过期时是 `None`。
  expires : String?
  /// 访问密码。
  pwd : String
  /// 已访问次数。
  accessed : Int
  /// 最大访问次数（0 表示不限）。
  max_accessed : Int
  /// 是否已禁用。
  disabled : Bool
  /// 备注。
  remark : String
  /// 列表页首说明。
  readme : String
  /// 列表页头信息。
  header : String
  /// 排序字段。
  order_by : String
  /// 排序方向（`asc`/`desc`）。
  order_direction : String
  /// 解压策略。
  extract_folder : String
  /// 分享的文件路径列表。
  files : Array[String]
  /// 创建者用户名。
  creator : String
  /// 创建者角色编号。
  creator_role : Int
}

///|
/// 解码分享记录。
pub impl @json.FromJson for SharingResponse with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "SharingResponse: expected object"))
  }
  {
    id: string_field(fields, "id"),
    expires: json_field(fields, "expires"),
    pwd: string_field(fields, "pwd"),
    accessed: int_field(fields, "accessed"),
    max_accessed: int_field(fields, "max_accessed"),
    disabled: bool_field(fields, "disabled"),
    remark: string_field(fields, "remark"),
    readme: string_field(fields, "readme"),
    header: string_field(fields, "header"),
    order_by: string_field(fields, "order_by"),
    order_direction: string_field(fields, "order_direction"),
    extract_folder: string_field(fields, "extract_folder"),
    files: array_field(fields, "files"),
    creator: string_field(fields, "creator"),
    creator_role: int_field(fields, "creator_role"),
  }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend SharingResponse with @json.FromJson::{from_json}

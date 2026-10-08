///|
/// 管理端的设置（setting）、驱动（driver）与索引（index）模型。
///
/// 这里额外处理两件 Go 的事：JSON 键叫 `type` 的字段（MoonBit 保留字，
/// 统一命名 `item_type`），以及只有 64 位才能容纳的 `obj_count`
/// （core json 的 `UInt64` 只认字符串，所以对外用 `Int64`）。

///|
/// 一项系统设置（`/api/admin/setting/*` 的读写对象）。
pub(all) struct SettingItem {
  /// 设置键。
  key : String
  /// 设置值（统一是字符串）。
  value : String
  /// 帮助文本。
  help : String
  /// 值类型，如 `string`、`bool`、`number`、`select`（对应 JSON 键 `type`）。
  item_type : String
  /// 可选值（`type = select` 时）。
  options : String
  /// 分组编号。
  group : Int
  /// 可见范围标记：0 公开、1 私有、2 只读、3 已废弃。
  flag : Int
  /// 组内排序。
  index : UInt
}

///|
/// 解码设置项。
pub impl @json.FromJson for SettingItem with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "SettingItem: expected object"))
  }
  {
    key: string_field(fields, "key"),
    value: string_field(fields, "value"),
    help: string_field(fields, "help"),
    item_type: string_field(fields, "type"),
    options: string_field(fields, "options"),
    group: int_field(fields, "group"),
    flag: int_field(fields, "flag"),
    index: uint_field(fields, "index"),
  }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend SettingItem with @json.FromJson::{from_json}

///|
/// 编码设置项（`save_settings` 要把设置原样回传，JSON 键是 `type`）。
pub impl ToJson for SettingItem with fn to_json(self) {
  Json::object({
    "key": Json::string(self.key),
    "value": Json::string(self.value),
    "help": Json::string(self.help),
    "type": Json::string(self.item_type),
    "options": Json::string(self.options),
    "group": Json::number(self.group.to_double()),
    "flag": Json::number(self.flag.to_double()),
    "index": Json::number(self.index.to_double()),
  })
}

///|
/// 显式声明手写的 `ToJson` 实现以普通方法暴露。
pub extend SettingItem with ToJson::{to_json}

///|
/// 驱动的一个配置项描述。
pub struct DriverItem {
  /// 配置项名。
  name : String
  /// 输入类型，如 `string`、`bool`、`select`。
  item_type : String
  /// 默认值。
  default : String
  /// 可选值（`type = select` 时）。
  options : String
  /// 是否必填。
  required : Bool
  /// 帮助文本。
  help : String
}

///|
/// 解码驱动配置项描述。
pub impl @json.FromJson for DriverItem with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "DriverItem: expected object"))
  }
  {
    name: string_field(fields, "name"),
    item_type: string_field(fields, "type"),
    default: string_field(fields, "default"),
    options: string_field(fields, "options"),
    required: bool_field(fields, "required"),
    help: string_field(fields, "help"),
  }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend DriverItem with @json.FromJson::{from_json}

///|
/// 驱动能力声明。
pub struct DriverConfig {
  /// 驱动名。
  name : String
  /// 是否支持本地排序。
  local_sort : Bool
  /// 是否只允许走代理下载。
  only_proxy : Bool
  /// 是否禁用缓存。
  no_cache : Bool
  /// 是否禁止上传。
  no_upload : Bool
  /// 是否需要用户提供额外信息（如验证码）。
  need_ms : Bool
  /// 默认根路径。
  default_root : String
  /// 提示信息。
  alert : String
  /// 是否只存索引（如 UrlTree 驱动）。
  only_indices : Bool
  /// 是否即使有直链也优先走代理。
  prefer_proxy : Bool
}

///|
/// 解码驱动能力声明。
pub impl @json.FromJson for DriverConfig with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "DriverConfig: expected object"))
  }
  {
    name: string_field(fields, "name"),
    local_sort: bool_field(fields, "local_sort"),
    only_proxy: bool_field(fields, "only_proxy"),
    no_cache: bool_field(fields, "no_cache"),
    no_upload: bool_field(fields, "no_upload"),
    need_ms: bool_field(fields, "need_ms"),
    default_root: string_field(fields, "default_root"),
    alert: string_field(fields, "alert"),
    only_indices: bool_field(fields, "only_indices"),
    prefer_proxy: bool_field(fields, "prefer_proxy"),
  }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend DriverConfig with @json.FromJson::{from_json}

///|
/// 一个驱动（或一个存储驱动实例）的完整描述。
pub struct DriverInfo {
  /// 所有驱动共有的配置项。
  common : Array[DriverItem]
  /// 该驱动特有的配置项。
  additional : Array[DriverItem]
  /// 能力声明。
  config : DriverConfig
}

///|
/// 解码驱动描述。
pub impl @json.FromJson for DriverInfo with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "DriverInfo: expected object"))
  }
  {
    common: array_field(fields, "common"),
    additional: array_field(fields, "additional"),
    config: json_field(fields, "config").unwrap_or({
      name: "",
      local_sort: false,
      only_proxy: false,
      no_cache: false,
      no_upload: false,
      need_ms: false,
      default_root: "",
      alert: "",
      only_indices: false,
      prefer_proxy: false,
    }),
  }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend DriverInfo with @json.FromJson::{from_json}

///|
/// 索引构建进度（`GET /api/admin/index/progress`）。
pub struct IndexProgress {
  /// 已索引的对象数。
  obj_count : Int64
  /// 是否已完成。
  is_done : Bool
  /// 上次完成时间（RFC3339 字符串）；从未完成时是 `None`。
  last_done_time : String?
  /// 失败原因；没有错误时是空字符串。
  error : String
}

///|
/// 解码索引进度。
pub impl @json.FromJson for IndexProgress with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "IndexProgress: expected object"))
  }
  {
    obj_count: int64_field(fields, "obj_count"),
    is_done: bool_field(fields, "is_done"),
    last_done_time: json_field(fields, "last_done_time"),
    error: string_field(fields, "error"),
  }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend IndexProgress with @json.FromJson::{from_json}

///|
/// 系统初始化状态（`GET /api/public/init_status`）。
pub struct InitStatus {
  /// 是否已经完成初始化（已完成则不能再调用 `init_setup`）。
  initialized : Bool
}

///|
/// 解码初始化状态。
pub impl @json.FromJson for InitStatus with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "InitStatus: expected object"))
  }
  { initialized: bool_field(fields, "initialized"), }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend InitStatus with @json.FromJson::{from_json}

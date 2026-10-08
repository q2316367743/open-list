///|
/// 管理端的元数据（meta）与存储（storage）模型。
///
/// 与其它模型一样手写容错解码。`Meta` 与 `Storage` 既能当响应读，也能当请求
/// 体写（`derive(ToJson)`），因为服务端的 create/update 直接绑定这两个结构。

///|
/// 路径元数据（`/api/admin/meta/*` 的读写对象）。
///
/// Go 里 `read_users_sub` 这类布尔字段表示「是否连同子目录生效」，
/// 名字里的 `_sub` 后缀不能省。
pub(all) struct Meta {
  /// 元数据 ID。
  id : UInt
  /// 生效路径。
  path : String
  /// 额外可读用户 ID 列表。
  read_users : Array[UInt]
  /// 可读权限是否对子目录生效。
  read_users_sub : Bool
  /// 额外可写用户 ID 列表。
  write_users : Array[UInt]
  /// 可写权限是否对子目录生效。
  write_users_sub : Bool
  /// 访问密码。
  password : String
  /// 密码是否对子目录生效。
  p_sub : Bool
  /// 是否允许写入。
  write : Bool
  /// 写权限是否对子目录生效。
  w_sub : Bool
  /// 隐藏规则。
  hide : String
  /// 隐藏规则是否对子目录生效。
  h_sub : Bool
  /// 目录说明。
  readme : String
  /// 说明是否对子目录生效。
  r_sub : Bool
  /// 自定义头信息。
  header : String
  /// 头信息是否对子目录生效。
  header_sub : Bool
} derive(ToJson)

///|
/// 解码元数据。
pub impl @json.FromJson for Meta with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "Meta: expected object"))
  }
  {
    id: uint_field(fields, "id"),
    path: string_field(fields, "path"),
    read_users: array_field(fields, "read_users"),
    read_users_sub: bool_field(fields, "read_users_sub"),
    write_users: array_field(fields, "write_users"),
    write_users_sub: bool_field(fields, "write_users_sub"),
    password: string_field(fields, "password"),
    p_sub: bool_field(fields, "p_sub"),
    write: bool_field(fields, "write"),
    w_sub: bool_field(fields, "w_sub"),
    hide: string_field(fields, "hide"),
    h_sub: bool_field(fields, "h_sub"),
    readme: string_field(fields, "readme"),
    r_sub: bool_field(fields, "r_sub"),
    header: string_field(fields, "header"),
    header_sub: bool_field(fields, "header_sub"),
  }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend Meta with @json.FromJson::{from_json}

///|
/// 显式声明 `derive` 出来的 `ToJson` 实现以普通方法暴露。
pub extend Meta with ToJson::{to_json}

///|
/// 存储挂载配置。
///
/// Go 把 `model.Sort` 与 `model.Proxy` 内嵌在这里，JSON 上仍是扁平字段，
/// 这里也摊平。
pub(all) struct Storage {
  /// 存储 ID。
  id : UInt
  /// 挂载路径，例如 `/onedrive`。
  mount_path : String
  /// 显示顺序。
  order : Int
  /// 驱动名，例如 `Local`。
  driver : String
  /// 缓存过期秒数。
  cache_expiration : Int
  /// 自定义缓存策略。
  custom_cache_policies : String
  /// 状态（通常是 `work`）。
  status : String
  /// 驱动配置（JSON 字符串）。
  addition : String
  /// 备注。
  remark : String
  /// 修改时间（RFC3339 字符串）。
  modified : String
  /// 是否禁用。
  disabled : Bool
  /// 是否禁用索引。
  disable_index : Bool
  /// 是否对直链签名。
  enable_sign : Bool
  /// 排序字段。
  order_by : String
  /// 排序方向（`asc`/`desc`）。
  order_direction : String
  /// 解压策略。
  extract_folder : String
  /// 是否强制走代理。
  web_proxy : Bool
  /// WebDAV 策略。
  webdav_policy : String
  /// 是否开启代理 Range。
  proxy_range : Bool
  /// 下载代理地址。
  down_proxy_url : String
  /// 是否禁用代理签名。
  disable_proxy_sign : Bool
} derive(ToJson)

///|
/// 解码存储配置。
pub impl @json.FromJson for Storage with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "Storage: expected object"))
  }
  {
    id: uint_field(fields, "id"),
    mount_path: string_field(fields, "mount_path"),
    order: int_field(fields, "order"),
    driver: string_field(fields, "driver"),
    cache_expiration: int_field(fields, "cache_expiration"),
    custom_cache_policies: string_field(fields, "custom_cache_policies"),
    status: string_field(fields, "status"),
    addition: string_field(fields, "addition"),
    remark: string_field(fields, "remark"),
    modified: string_field(fields, "modified"),
    disabled: bool_field(fields, "disabled"),
    disable_index: bool_field(fields, "disable_index"),
    enable_sign: bool_field(fields, "enable_sign"),
    order_by: string_field(fields, "order_by"),
    order_direction: string_field(fields, "order_direction"),
    extract_folder: string_field(fields, "extract_folder"),
    web_proxy: bool_field(fields, "web_proxy"),
    webdav_policy: string_field(fields, "webdav_policy"),
    proxy_range: bool_field(fields, "proxy_range"),
    down_proxy_url: string_field(fields, "down_proxy_url"),
    disable_proxy_sign: bool_field(fields, "disable_proxy_sign"),
  }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend Storage with @json.FromJson::{from_json}

///|
/// 显式声明 `derive` 出来的 `ToJson` 实现以普通方法暴露。
pub extend Storage with ToJson::{to_json}

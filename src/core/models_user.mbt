///|
/// 用户相关的响应模型。
///
/// 这一层的解码一律容错：字段缺失、`null`、类型不符都退化成零值，只有整个
/// 响应不是 JSON 对象时才会报 `OpenListError::Decode`。原因是 OpenList 各版本
/// 会增删字段、Go 又会把 `nil` 切片/指针序列化成 `null`，严格解码会让客户端在
/// 服务端小版本升级后整体不可用。

///|
/// 平台用户。
pub(all) struct User {
  /// 用户 ID。
  id : UInt
  /// 用户名。
  username : String
  /// 密码哈希。`GET /api/me` 会把它清空，正常响应里不会拿到真实哈希。
  password : String
  /// 该用户的根路径；所有相对路径都以它为基准。
  base_path : String
  /// 角色：`0` 管理员、`1` 普通用户、`2` 游客。
  role : Int
  /// 是否被禁用。
  disabled : Bool
  /// 权限位掩码。
  permission : Int
  /// 绑定的单点登录 ID。
  sso_id : String
  /// 是否允许 LDAP 登录。
  allow_ldap : Bool
} derive(ToJson)

///|
/// 解码用户。
pub impl @json.FromJson for User with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "User: expected object"))
  }
  {
    id: uint_field(fields, "id"),
    username: string_field(fields, "username"),
    password: string_field(fields, "password"),
    base_path: string_field(fields, "base_path"),
    role: int_field(fields, "role"),
    disabled: bool_field(fields, "disabled"),
    permission: int_field(fields, "permission"),
    sso_id: string_field(fields, "sso_id"),
    allow_ldap: bool_field(fields, "allow_ldap"),
  }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露，避免工具链的
/// 「隐式提升为方法」弃用告警。
pub extend User with @json.FromJson::{from_json}

///|
/// 显式声明 `derive` 出来的 `ToJson` 实现以普通方法暴露（管理端建/改用户时要回传）。
pub extend User with ToJson::{to_json}

///|
/// `GET /api/me` 的响应：用户信息，外加该账号是否开启两步验证。
///
/// Go 服务端把 `model.User` 内嵌进这个结构体，两组字段在 JSON 里是同一层。
/// MoonBit 没有结构体内嵌，所以这里用 `user` 字段承载用户信息——解码时仍是
/// 从同一个扁平对象里读。
pub struct UserResponse {
  /// 用户信息。
  user : User
  /// 该账号是否开启了两步验证。
  otp : Bool
}

///|
/// 解码 `/api/me` 的响应。
pub impl @json.FromJson for UserResponse with fn from_json(json, path) {
  let user : User = @json.from_json(json, path~)
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "UserResponse: expected object"))
  }
  { user, otp: bool_field(fields, "otp"), }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend UserResponse with @json.FromJson::{from_json}

///|
/// SSH 公钥。
pub struct SSHPublicKey {
  /// 公钥 ID。
  id : UInt
  /// 用户给这把钥匙起的名字。
  title : String
  /// 公钥指纹。
  fingerprint : String
  /// 添加时间（RFC3339 字符串；Go 的零值时间是 `0001-01-01T00:00:00Z`）。
  added_time : String
  /// 最后一次使用时间（同上）。
  last_used_time : String
}

///|
/// 解码 SSH 公钥。
pub impl @json.FromJson for SSHPublicKey with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "SSHPublicKey: expected object"))
  }
  {
    id: uint_field(fields, "id"),
    title: string_field(fields, "title"),
    fingerprint: string_field(fields, "fingerprint"),
    added_time: string_field(fields, "added_time"),
    last_used_time: string_field(fields, "last_used_time"),
  }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend SSHPublicKey with @json.FromJson::{from_json}

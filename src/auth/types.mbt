///|
/// 认证域的类型定义。
///
/// 登录请求体与 core 的私有 `LoginRequest` 形状一致（`otp_code` 为 `None`
/// 时字段被整个省略，服务端只在字段非空时校验两步验证码），但这里要支持
/// `/api/auth/login/hash` 与 `/api/auth/login/ldap` 两条路径，所以单独定义。

///|
/// 登录请求体。
pub struct LoginBody {
  /// 用户名。
  username : String
  /// 密码：`login` 传明文，`login_hash` 传静态哈希后的值，`login_ldap` 传明文。
  password : String
  /// 两步验证码；未开启 2FA 时留 `None`。
  otp_code : String?
} derive(ToJson)

///|
/// 显式声明 `derive` 出来的 `ToJson` 实现以普通方法暴露。
pub extend VerifyTwoFactorRequest with ToJson::{to_json}

///|
/// 显式声明 `derive` 出来的 `ToJson` 实现以普通方法暴露（消除隐式提升告警）。
pub extend LoginBody with ToJson::{to_json}

///|
/// 两步验证码校验请求体（`POST /api/auth/2fa/verify`）。
pub struct VerifyTwoFactorRequest {
  /// 验证器当前显示的 6 位码。
  code : String
  /// 生成 2FA 时返回的密钥。
  secret : String
} derive(ToJson)

///|
/// 从登录响应的 `data` 里取出 token。
///
/// 缺少 `token`、token 不是字符串、或是空串都算协议错误：与其让调用方拿到
/// 一个空 token 之后再各处 401，不如在登录这一步就说清楚。
fn decode_token(data : Json) -> String raise @core.OpenListError {
  guard data is Object(fields) else {
    raise @core.OpenListError::Decode("登录响应不是 JSON 对象")
  }
  match fields.get("token") {
    Some(String(value)) if value != "" => value
    _ => raise @core.OpenListError::Decode("登录响应缺少 token")
  }
}

///|
/// 两步验证的初始化结果（`POST /api/auth/2fa/generate`）。
pub struct TwoFactorAuth {
  /// 二维码图片的 data URL（`data:image/png;base64,...`）。
  qr : String
  /// 密钥，用来在 `verify_2fa` 时回传。
  secret : String
}

///|
/// 解码两步验证初始化结果。
pub impl @json.FromJson for TwoFactorAuth with fn from_json(json, path) {
  guard json is Object(fields) else {
    raise @json.JsonDecodeError((path, "TwoFactorAuth: expected object"))
  }
  {
    qr: @core.string_field(fields, "qr"),
    secret: @core.string_field(fields, "secret"),
  }
}

///|
/// 显式声明手写的 `FromJson` 实现以普通方法暴露。
pub extend TwoFactorAuth with @json.FromJson::{from_json}

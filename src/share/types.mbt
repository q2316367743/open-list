///|
/// 分享域的请求模型。
///
/// 服务端 `handles.UpdateSharingReq` 同时服务 `create` 与 `update`，这里保持一致：
///
/// - 可空字段留空时会以 `null` 发出去，服务端对 `null` 取零值（字符串空串、
///   数值 0、布尔假、时间指针 nil），与我们想要的「不设置」完全等价；
/// - 服务端会忽略它不认识的字段，所以这里比服务端多/少一个字段都不会出错，但
///   反之我们自己也不能依赖多发的字段生效。
pub struct SharingUpdateRequest {
  /// 要分享的路径列表，至少一项；空列表服务端会报 400。
  files : Array[String]
  /// 过期时间，RFC3339 字符串；不设置表示永不过期。
  expires : String?
  /// 访问密码；空表示不需要密码。
  pwd : String?
  /// 最大访问次数，0 表示不限。
  max_accessed : Int?
  /// 是否禁用。
  disabled : Bool?
  /// 备注。
  remark : String?
  /// 分享列表页的说明。
  readme : String?
  /// 分享列表页的头部信息。
  header : String?
  /// 排序字段。
  order_by : String?
  /// 排序方向（`asc`/`desc`）。
  order_direction : String?
  /// 解压策略（枚举字符串，取值以服务端为准）。
  extract_folder : String?
  /// 创建者用户名：只有管理员能指定，普通用户会被忽略。
  creator : String?
  /// 已访问次数（一般不用设置）。
  accessed : Int?
  /// 分享 ID。`create` 时给值表示自定义 ID（需要相应权限）；`update` 时必填。
  id : String?
  /// 变更后的分享 ID：`update` 时非空表示改 ID（需要相应权限）。
  new_id : String?
} derive(ToJson)

///|
/// 显式声明 `derive` 出来的 `ToJson` 实现以普通方法暴露。
pub extend SharingUpdateRequest with ToJson::{to_json}

///|
/// 构造分享请求：`files` 必填，其余按需给。
///
/// 结构体字段本身也是公开的，需要在此函数之外微调时可以直接改（或配合
/// `{ ..request, pwd: Some("x") }` 做函数式更新）。
pub fn SharingUpdateRequest::new(
  files : Array[String],
  expires? : String,
  pwd? : String,
  max_accessed? : Int,
  disabled? : Bool,
  remark? : String,
  readme? : String,
  header? : String,
  order_by? : String,
  order_direction? : String,
  extract_folder? : String,
  creator? : String,
  accessed? : Int,
  id? : String,
  new_id? : String,
) -> SharingUpdateRequest {
  {
    files,
    expires,
    pwd,
    max_accessed,
    disabled,
    remark,
    readme,
    header,
    order_by,
    order_direction,
    extract_folder,
    creator,
    accessed,
    id,
    new_id,
  }
}

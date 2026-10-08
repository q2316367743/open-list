# 06 · 分享 Sharing

包：`src/share/`（`share.mbt`、`types.mbt`）。服务端：`server/handles/sharing.go`，
路由组 `/api/share`（`Auth` + `AuthNotGuest`，访客账号不可用）。

## 1. 方法一览

| 方法 | 端点 | 说明 |
|------|------|------|
| `ShareApi::list(page?, per_page?) -> PageResult[SharingResponse]` | `GET /api/share/list` | 分页列出分享；管理员看全部，普通用户只看自己的 |
| `ShareApi::get(id : String) -> SharingResponse` | `GET /api/share/get?id=` | 单条分享；非本人且非管理员 → 404 `sharing not found` |
| `ShareApi::create(SharingUpdateRequest) -> SharingResponse` | `POST /api/share/create` | 新建，返回完整记录 |
| `ShareApi::update(SharingUpdateRequest) -> SharingResponse` | `POST /api/share/update` | 更新，返回完整记录 |
| `ShareApi::delete(id : String) -> Unit` | `POST /api/share/delete?id=` | 删除 |
| `ShareApi::enable(id : String) -> Unit` | `POST /api/share/enable?id=` | 启用（服务端内部是 `disabled = false`） |
| `ShareApi::disable(id : String) -> Unit` | `POST /api/share/disable?id=` | 禁用（`disabled = true`） |

`id` 是**字符串**（不是数字），来自 `list()` / `get()` / `create()` 的结果。

## 2. 记录形状

```moonbit
pub struct SharingResponse {
  id : String?            // 分享 ID（就是访问路径里的 sid）
  files : Array[String]   // 分享的文件/目录列表
  expires : String?       // RFC3339；None 表示永不过期
  pwd : String?           // 提取码
  max_accessed : Int?     // 最大访问次数
  accessed : Int?         // 已访问次数
  disabled : Bool?
  remark : String?
  readme : String?        // 分享页说明（Markdown）
  header : String?        // 分享页顶部内容
  order_by : String?      // 排序字段
  order_direction : String?
  extract_folder : String?
  creator : String?       // 创建者用户名
  creator_role : Int?     // 创建者角色（0 管理员 / 1 普通 / 2 访客）
}
```

服务端是 `SharingResp{ *model.Sharing; creator; creator_role }`——记录的字段直接
平铺在响应里，`creator` 与 `creator_role` 是额外附加的。

## 3. 请求体：`SharingUpdateRequest`

`create` 与 `update` 共用同一个结构（服务端也是同一个 `UpdateSharingReq`）：

```moonbit
pub struct SharingUpdateRequest {
  files : Array[String]   // 必填，且不能是空数组或空串元素
  expires : String?       // RFC3339 文本
  pwd : String?
  max_accessed : Int?
  disabled : Bool?
  remark : String?
  readme : String?
  header : String?
  order_by : String?
  order_direction : String?
  extract_folder : String?
  creator : String?
  accessed : Int?
  id : String?            // update 必填
  new_id : String?        // 非空时同时改分享 ID（需要权限）
}

SharingUpdateRequest::new(["/docs"], pwd="1234", expires="2027-01-01T00:00:00Z")
```

- `files` 为空（或第一个元素为空串）时服务端返回 400
  `must add at least 1 object`，所以 `new` 的第一个参数是必填的数组。
- 其余字段都是 `T?`：不传就不出现在请求体里（见
  [07](./07-json-modeling.md)），服务端保持原值 / 默认值。
- **`update` 必须带 `id`**；`create` 时带 `id` 没有意义。

## 4. ⚠️ 与官方文档的差异

官方文档把分享描述成另一套字段，实测源码不一致，以源码为准：

| 文档 | 源码（本库） |
|------|--------------|
| `create` 请求 `{paths, password, expiration}` | `{files, pwd, expires, …}`（15 个字段） |
| `get` 返回 `{id, path, password, expiration, created_at}` | 平铺的分享记录 + `creator` / `creator_role`，**没有** `path` / `created_at` |
| `enable` / `disable` 各有独立请求体 | 都只是 `?id=`，服务端共用一个 `SetEnableSharing(disable bool)` |

## 5. 示例

```moonbit
let created = client.share().create(
  @open-list.SharingUpdateRequest::new(["/docs/手册.pdf"], pwd="1234", remark="给同事"),
)
println(created.id)

let all = client.share().list(page=1, per_page=50)
for item in all.content {
  println("\{item.id} \{item.files} accessed=\{item.accessed}")
}

client.share().disable(created.id.unwrap())
client.share().enable(created.id.unwrap())
client.share().delete(created.id.unwrap())
```

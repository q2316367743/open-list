# 07 · JSON 建模约定

OpenList 的 JSON 与 MoonBit core 的 `FromJson` / `ToJson` 有四处不一致，本库在
`src/core/json_util.mbt` 里统一处理。写新模型 / 新方法前先读这一页。

## 1. 统一信封

所有 `/api` 响应都是：

```json
{ "code": 200, "message": "success", "data": { } }
```

- 成功固定 `code = 200`；失败是非 200（配合 HTTP 4xx/5xx）。
- `data` 可以是对象、数组、字符串、`null`。

处理链（`src/core/envelope.mbt` + `src/core/client.mbt`）：

```
resp.text() → @json.parse → 检查 code
   code != 200 → raise OpenListError::Api(ApiError{code, message, status, data})
   code == 200 → 取 data（缺失即 Json::Null）
```

`ApiError` 里也带着 `data`：分片上传失败时它就是 `snapshot`（见
[04](./04-file-system.md) 第 6 节）。

## 2. 两条解码通道

| 通道 | 用法 | 是否剔除 `null` |
|------|------|-----------------|
| 类型化 | `decode_data::<T>(data)` / `decode_page::<T>(data)` | **是** |
| 逃生通道 | `OpenListClient::request(...)` | 否，原样 `Json` |

- `decode_data`：把 `data` 解成 `T`，失败抛
  `OpenListError::Decode("…")`（带 core json 的路径信息）。
- `decode_page`：解成 `PageResult[T]{content : Array[T], total : Int64}`。OpenList
  的分页信封字段是 `content` + `total`（不是 `items` / `list`）。
- 逃生通道不做任何加工，保证用户拿到的就是服务端返回值。

## 3. ⚠️ `null` 必须先剔除

MoonBit core 的 `T?` 字段语义与 OpenList 不一致：

| JSON | `T?` 字段 |
|------|-----------|
| 字段缺失 | `None` ✅ |
| 字段显式为 `null` | **解码报错**（`String::from_json: expected string`）❌ |

而 Go 会把 `nil` 指针 / 切片序列化成显式 `null`。所以类型化通道会先跑一遍
`strip_nulls`：**递归删掉对象里值为 `null` 的字段**（数组元素保留但递归处理）。
之后 `T?` 的含义就干净了：有值 → `Some`，没有值 → `None`。

推论：模型里可以放心把「服务端可能给 null」的字段写成 `T?`；**不需要**为它们写
自定义 `FromJson`。

## 4. ⚠️ 64 位整数与 Go 的 `nil` 切片

- Go 的 `int64` / `uint64` 序列化成 JSON **数字**，而 core json 的
  `Int64::from_json` 只接受**字符串**形态（JSON 数字统一按 `Double` 解析）。
  → 带 `Int64` 字段的模型手写 `FromJson`，用 `int64_field` / `int64_from_json`
  读（两者都同时接受数字与字符串）。
- Go 的 `nil` 切片 / map 会变成 `null`，直接解成 `Array[T]` / `Map[K,V]` 会失败。
  → 列表字段一律走 `array_field` / `map_field`，缺失或 `null` 都给空数组 / 空
  map。用户拿到的永远是数组，不用处理 `null`。

`json_util.mbt` 提供的字段助手：

| 助手 | 行为 |
|------|------|
| `json_field::<T>(fields, key) -> T?` | 缺失 / `null` / 类型不符 → `None` |
| `string_field` | 缺失 → `""` |
| `bool_field` | 缺失 → `false` |
| `int_field` / `uint_field` / `double_field` | 缺失 → `0` |
| `int64_field` | 缺失 → `0`；数字与字符串都接受 |
| `array_field` / `map_field` | 缺失 / `null` → 空数组 / 空 map |

## 5. ⚠️ 关键字 `type`

`FsObject` / `SearchNode` / `DriverItem` / `SettingItem` 都有名为 `type` 的字段，
而 `type` 是 MoonBit 关键字。处理方式：模型里的字段改名（`obj_type` /
`item_type`），并**手写** `FromJson` / `ToJson` 映射回 `type`。

同理 `method` 在请求体里是普通字符串字段（不是关键字，但 `POST /api/fs/other`
的 `method` 由调用方命名参数 `request_method` 以避免歧义）。

## 6. ⚠️ Go 的内嵌结构

Go 的匿名内嵌字段会被 JSON **平铺**在同一个对象里，而 MoonBit 模型里我们会
按语义聚成一个字段：

| 服务端（平铺） | 本项目模型 |
|----------------|-----------|
| `FsGetResp{ObjResp; raw_url; …}` | `FsGetResponse{obj : ObjResp, raw_url, …}` |
| `ArchiveContentResp{ObjResp; children}` | `ArchiveContent{obj : ObjResp, children}` |
| `MultipartInitResp{SessionSnapshot; resumed}` | `MultipartInitResponse{snapshot, resumed}` |
| `SharingResp{*model.Sharing; creator}` | `SharingResponse{…平铺字段, creator, creator_role}` |

前三个都**手写 `FromJson`**：先按同一份 JSON 解出内层结构，再补外层字段。
所以调用时要写 `resp.obj.name`（不是 `resp.name`）、`snap.snapshot.upload_id`
（不是 `snap.upload_id`）。

## 7. `derive(ToJson)` 的实测语义

```moonbit
pub struct LoginBody { username : String; password : String; otp_code : String? } derive(ToJson)
```

- `None` 字段**整个省略**（不发 `null`）
- `Some(v)` 直接编码成 `v`（不包数组）
- `Some("")` 会发出 `""`——要「不发这个字段」就得给 `None`

所以可空字段不用补零值，`otp_code?`、`password?`、`expires?` 这类直接留 `None`
即可。这一点由测试锁定（`assert_absent(body, "otp_code")` 等）。

## 8. 请求体怎么建

- **域内部**的请求体是**包私有** `derive(ToJson)` struct，集中在
  `src/fs/bodies.mbt` 之类的文件里（私有类型也**需要**写
  `pub extend X with ToJson::{to_json}`，否则触发 `implicit_impl_as_method`
  告警）。
- **公开**的请求体（`UpdateMeRequest`、`SharingUpdateRequest`、
  `UpdateIndexRequest`、`FileHash`、`RenameObject`）用 `pub struct` +
  `derive(ToJson)` + `pub extend …::{to_json}`，并在根包 `src/reexport.mbt` 里
  再导出。
- 需要**跨包构造**的响应模型（`User`、`Meta`、`Storage`、`SettingItem`）必须是
  `pub(all) struct`：`pub struct` 的字段对其它包**只读**，字段字面量会报
  `Error [4036] Cannot create values of the read-only type`。

## 9. 其它口径

- 时间统一是 **RFC3339 字符串**（`String` / `String?`），不引时间库、不解析成
  时间类型；需要毫秒时间戳的地方（上传的 `Last-Modified`）用 `Int64`。
- 开放取值集合（驱动名、任务状态、`order_by`、`scope`…）用 `String` / `Int`
  表达，不建枚举，避免服务端加值就破。
- `Map[String, T]` 直接用 core 的 `FromJson`（`/api/public/settings`、
  `/api/admin/driver/list`）。
- 数值 ID（`id`、`uid`）统一 `UInt`，大小相关的 `size` / `total` 统一 `Int64`。

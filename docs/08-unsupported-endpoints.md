# 08 · 未封装的端点与逃生通道

本项目只封装六个功能域里**稳定且契约明确**的端点（详见
[01](./01-auth.md)–[06](./06-sharing.md)）。其余端点没有类型化方法，用
`OpenListClient::request` 调用——认证、401 重登、信封检查、`code != 200` 抛
`OpenListError::Api` 都在这一层自动完成。

## 1. 逃生通道

```moonbit
pub async fn OpenListClient::request(
  self : OpenListClient,
  http_method : Method,                    // Method::Get / Post / Put / Delete / Patch…
  path : String,                           // "/api/..."（相对路径，自动拼 base_url）
  query? : Json,                           // 查询参数（Json 对象）
  body? : Json,                            // 请求体（Json；自动 Content-Type: application/json）
  headers? : Array[(String, String)],      // 额外请求头
) -> Json raise OpenListError
```

返回值是信封里的 **`data`**，**原样** `Json`（不做 `null` 剔除，也不解码成类型）。
需要类型化结果时把它交给 core 的 `decode_data`（逃生通道里用不到也没关系——
自己按 JSON 读即可）。

```moonbit
// GET /api/task/upload/undone?page=1&per_page=20
let undone = client.request(
  @open-list.Method::Get,
  "/api/task/upload/undone",
  query=Json::object({ "page": Json::number(1), "per_page": Json::number(20) }),
)

// POST /api/admin/scan/start
let _ = client.request(
  @open-list.Method::Post,
  "/api/admin/scan/start",
  body=Json::object({ "path": Json::string("/docs"), "limit": Json::number(1000) }),
)

// 从原始 Json 里取字段
match undone {
  Object(fields) =>
    match fields.get("content") {
      Some(Array(items)) => println(items.length())
      _ => ()
    }
  _ => ()
}
```

> `Json::object({ "键": Json::string(…) })` 是 core 的 map 字面量；
> `Json::number(Double)`、`Json::string(String)`、`Json::boolean(Bool)`、
> `Json::array(Array[Json])`、`Json::null()` 都可用。这段写法在
> `src/open_list_test.mbt` 的同款调用上编译验证过。

## 2. 未封装的端点清单

### 2.1 SSO（4 个，`/api/auth`，无认证）

| 端点 | 说明 |
|------|------|
| `GET /api/auth/sso` | 发起 SSO 登录（302 跳转，重定向到身份提供方） |
| `GET /api/auth/sso_callback` | 回调；需要浏览器会话/Cookie，不适合程序调用 |
| `GET /api/auth/get_sso_id` | 取当前 SSO 标识 |
| `GET /api/auth/sso_get_token` | 用 SSO 会话换 token |

SSO 依赖浏览器跳转与 Cookie，moonhttp 的客户端里也没有 Cookie 会话管理，硬封
装价值不大。

### 2.2 WebAuthn（`/api/authn`，无认证）

`GET /api/authn/webauthn_begin_login`、`POST /api/authn/webauthn_finish_login`、
`GET /api/authn/webauthn_begin_registration`、
`POST /api/authn/webauthn_finish_registration`、`POST /api/authn/delete_authn`、
`GET /api/authn/getcredentials`。

挑战值（challenge）要用浏览器 WebAuthn API 签名，纯客户端库做不了。

### 2.3 任务域（`/api/task/*`）

7 个 manager：`upload`、`copy`、`move`、`offline_download`、
`offline_download_transfer`、`decompress`、`decompress_upload`；每个都有：

```
GET  /api/task/<manager>/undone          POST /api/task/<manager>/info
GET  /api/task/<manager>/done            POST /api/task/<manager>/cancel
POST /api/task/<manager>/delete          POST /api/task/<manager>/retry
POST /api/task/<manager>/cancel_some     POST /api/task/<manager>/delete_some
POST /api/task/<manager>/retry_some      POST /api/task/<manager>/clear_done
POST /api/task/<manager>/clear_succeeded POST /api/task/<manager>/retry_failed
```

单任务操作用 `?tid=<id>`，批量操作的请求体是**裸字符串数组** `["tid1","tid2"]`。
模型 `TaskInfo` 已经导出（`@open-list.TaskInfo`），且上传 / 归档 / 离线下载
方法会直接返回它：

```moonbit
let tasks = client.fs().archive_decompress("/docs", "/out", ["pkg.zip"])
for task in tasks {
  println("\{task.id} \{task.state} \{task.progress}")
}
// 想查进度就自己发一次
let done = client.request(@open-list.Method::Get, "/api/task/decompress/done")
```

### 2.4 管理端扫描（`/api/admin/scan/*`）

`POST /start`（体 `{path, limit}`）、`POST /stop`、`GET /progress`
（返回 `{obj_count, is_done}`）。与索引（已封装，见
[03](./03-admin.md) 第 6 节）是两个独立功能。

### 2.5 种子（`/api/fs/torrent/*`）

`POST /parse`、`/upload_parse`、`/rapid_upload`、`/generate`。需要先有种子文件
或磁力链，且部分能力依赖外部服务（离线下载工具的种子解析）。

### 2.6 第三方驱动配置（`/api/admin/setting/set_*`，12 个）

服务端为常见第三方集成（各类网盘、搜索等）提供的「一键写入配置」包装。它们本质
上是 `save_settings` 的便捷形式，用已封装的方法即可达到同样效果：

```moonbit
let items = client.admin().get_settings(["…"])
client.admin().save_settings(items)
```

### 2.7 非 `/api` 的访问路由

`GET/HEAD /d/*path`、`/p/*path`、`/ad/*path`、`/ap/*path`、`/ae/*path`、
`/sd/:sid/*path`、`/sad/:sid/*path`：这些返回**文件内容或 HTML 页面**，不是 JSON
信封，不属于本库的 JSON 客户端范畴。要下载文件请用 `fs().get(path).raw_url`
或 `fs().create_link(path).url` 拿直链，再交给通用的 HTTP 客户端（或浏览器）。

### 2.8 客户端侧 SHA-256

`Auth::login_hash` 只接受**已经算好的**静态哈希（OpenList 前端用 SHA-256
十六进制）。本库不内置 SHA-256：要么用 `Auth::login` 让服务端算，要么自行引
`moonbitlang/x` 的 crypto 包。

## 3. 判断要不要新增封装

新增端点前先问三个问题：

1. 它返回统一 JSON 信封吗？（不是 → 不该进这个库）
2. 它的请求/响应能被稳定地类型化吗？（跳转、挑战值、二进制 → 不适合）
3. 它属于六个功能域之一吗？（属于别的域就补文档，别硬塞进现有子模块）

满足条件的话，按 [07](./07-json-modeling.md) 的约定建模型、加方法、补测试，
并更新本文件与 [docs/README.md](./README.md)。

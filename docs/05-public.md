# 05 · 公共 Public

包：`src/public/`。服务端：`server/handles/setting.go`（`PublicSettings`）、
`server/handles/setup.go`，路由组 `/api/public`（**无需认证**）。

## 1. 方法一览

| 方法 | 端点 | 说明 |
|------|------|------|
| `PublicApi::settings() -> Map[String, String]` | `GET /api/public/settings` | 站点公开设置（标题、版本等键值对） |
| `PublicApi::offline_download_tools(path?) -> Array[String]` | `GET /api/public/offline_download_tools?path=` | 该路径可用的离线下载工具名 |
| `PublicApi::archive_extensions() -> Array[String]` | `GET /api/public/archive_extensions` | 支持解压的扩展名（如 `zip`、`7z`） |
| `PublicApi::init_status() -> InitStatus` | `GET /api/public/init_status` | 系统是否已初始化 |
| `PublicApi::init_setup(username, password, site_title?) -> Unit` | `POST /api/public/init/setup` | 首次初始化，创建管理员 |

因为整个 `/api/public` 组不校验 token，本域可以直接用**匿名客户端**访问：

```moonbit
let client = @open-list.create_open_list_client_with_token("https://openlist.example.com", "")
println(client.public().init_status().initialized)
```

（`Token("")` 是匿名模式：请求不带 `Authorization` 头，见
[00](./00-architecture.md) 第 4 节。）

## 2. 契约细节

- `settings()` 的键名与数量由服务端 `GetPublicSettingsMap()` 决定，不建结构体、
  不硬编码键名，用 `Map[String, String]` 原样给出。
- `offline_download_tools(path?)`：不给 `path` 时**不带 query**（服务端
  `NamesForPath("")` 返回全部工具）；给了就 `?path=<urlencoded>`。
- `init_status()` 返回 `InitStatus{initialized : Bool}`；只有
  `initialized == false` 时才可以调 `init_setup`。
- `init_setup` 的请求体是 `{username, password, site_title}`：`username` /
  `password` 服务端要求非空，`site_title` 不给时本项目发**空串**（不是省略，
  因为服务端结构体是值类型 `string`）。常见失败：
  - 密码少于 4 个字符 → 400 `password must be at least 4 characters`
  - 系统已初始化 → 400 `system has already been initialized`
- ⚠️ 官方文档的 Public 分组只列了 `settings` / `offline_download_tools` /
  `archive_extensions` 三个端点，`init_status` 与 `init/setup` 它们在文档里没写
  全；但服务端确实挂在同一个 `/api/public` 组下，本项目一并封装。
- ⚠️ `init_status` / `init/setup` 是 OpenList **较新版本**才注册的路由（初始化
  向导，2026-09-07 合入）。更早的版本（含 `v4.2.6`）没有这两条路由，请求会落到
  前端静态页，客户端拿到的是 HTML，表现为 `OpenListError::Decode`，消息形如
  `HTTP 404：响应不是合法 JSON：<!doctype html>…`。对着旧版本调 `init_status()`
  时请按这个模式处理（联调程序会记一条「跳过」）。

## 3. 示例

```moonbit
if !client.public().init_status().initialized {
  client.public().init_setup("admin", "secret123", site_title="我的 OpenList")
}
let settings = client.public().settings()
println(settings.get("site_title"))
let tools = client.public().offline_download_tools(path="/downloads")
println(tools.length())
println(client.public().archive_extensions())
```

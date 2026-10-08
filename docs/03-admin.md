# 03 · 管理 Admin

包：`src/admin/`（`admin.mbt`、`user.mbt`、`storage.mbt`、`driver.mbt`、
`setting.mbt`、`index.mbt`）。服务端：`server/handles/{meta,user,storage,driver,setting,index}.go`，
路由组 `/api/admin`（`AuthAdmin`）——**所有方法都要求管理员 token**。

模型 `Meta` / `Storage` / `SettingItem` / `User` 都是 `pub(all) struct`，可以直接用
字段字面量构造再回传给 create / update（见 [07](./07-json-modeling.md)）。

## 1. meta 子域（`MetaApi` → `AdminApi::*`）

| 方法 | 端点 | 返回 |
|------|------|------|
| `list_meta(page?, per_page?)` | `GET /api/admin/meta/list` | `PageResult[Meta]` |
| `get_meta(id : UInt)` | `GET /api/admin/meta/get?id=` | `Meta` |
| `create_meta(@core.Meta)` | `POST /api/admin/meta/create` | `Unit` |
| `update_meta(@core.Meta)` | `POST /api/admin/meta/update` | `Unit` |
| `delete_meta(id : UInt)` | `POST /api/admin/meta/delete?id=` | `Unit` |

`Meta` 字段：`id : UInt`、`path`、`read_users`、`read_users_sub`、`write_users`、
`write_users_sub`、`password`、`p_sub`、`write`、`w_sub`、`hide`、`h_sub`、`readme`、
`r_sub`、`header`、`header_sub`（`*_sub` 是「对其子目录生效」，`p_sub` / `w_sub` /
`h_sub` / `r_sub` 是对应密码/开关的子目录版本）。

create / update 的请求体就是**完整的 `Meta`**（服务端 `c.ShouldBind(&meta)`）。
⚠️ 官方文档把 `get` 描述成 `ApiResponse` 包一层，实际直接返回 `Meta` 对象。

## 2. user 子域

| 方法 | 端点 |
|------|------|
| `list_users(page?, per_page?) -> PageResult[User]` | `GET /api/admin/user/list` |
| `get_user(id : UInt) -> User` | `GET /api/admin/user/get?id=` |
| `create_user(@core.User) -> Unit` | `POST /api/admin/user/create` |
| `update_user(@core.User) -> Unit` | `POST /api/admin/user/update` |
| `delete_user(id : UInt) -> Unit` | `POST /api/admin/user/delete?id=` |
| `cancel_2fa(id : UInt) -> Unit` | `POST /api/admin/user/cancel_2fa?id=` |
| `del_cache(username : String) -> Unit` | `POST /api/admin/user/del_cache?username=` |
| `list_user_ssh_keys(uid : UInt, page?, per_page?) -> PageResult[SSHPublicKey]` | `GET /api/admin/user/sshkey/list?uid=&page=&per_page=` |
| `delete_user_ssh_key(id : UInt) -> Unit` | `POST /api/admin/user/sshkey/delete?id=` |

服务端校验（都会返回 400）：`admin or guest user can not be created`（不能创建
admin/guest 角色）、`role can not be changed`（update 时改 role）、
`admin user can not be disabled`（禁用管理员）。

`User` 字段：`id : UInt`、`username`、`password`、`base_path`、`role : Int`、
`disabled : Bool`、`permission : Int`、`sso_id`、`allow_ldap`。update 时
`password` 留空表示**保留旧哈希**，所以「先 `get_user` 再改字段回传」是可行的。

## 3. storage 子域

| 方法 | 端点 | 说明 |
|------|------|------|
| `list_storages(page?, per_page?) -> PageResult[Storage]` | `GET /api/admin/storage/list` | 每项可能带 `mount_details` |
| `get_storage(id : UInt) -> Storage` | `GET /api/admin/storage/get?id=` | 单个对象 |
| `create_storage(@core.Storage) -> UInt` | `POST /api/admin/storage/create` | 返回新存储的 `id` |
| `update_storage(@core.Storage) -> Unit` | `POST /api/admin/storage/update` | |
| `delete_storage / enable_storage / disable_storage(id)` | `POST /api/admin/storage/{delete,enable,disable}?id=` | |
| `load_all_storages() -> Unit` | `POST /api/admin/storage/load_all` | 重新挂载全部存储 |

`Storage` 字段：`id : UInt`、`mount_path`、`order : Int`、`driver`、
`cache_expiration : Int`、`custom_cache_policies`、`status`、`addition`、`remark`、
`modified`、`disabled : Bool`、`disable_index : Bool`、`enable_sign : Bool`、
`order_by`、`order_direction`、`extract_folder`、`web_proxy : Bool`、
`webdav_policy`、`proxy_range : Bool`、`down_proxy_url`、`disable_proxy_sign : Bool`。

⚠️ 官方文档说 `get` 返回 `{storage, driver}`、`create` 返回存储对象；源码里
`get` 直接返回 `Storage`，`create` 只返回 `data:{"id": N}`（本项目读成 `UInt`）。
`addition` 是驱动自己的 JSON 配置，本项目按**字符串**原样传递。

## 4. driver 子域

| 方法 | 端点 | 返回 |
|------|------|------|
| `list_drivers()` | `GET /api/admin/driver/list` | `Map[String, DriverInfo]`（按分组名） |
| `driver_names()` | `GET /api/admin/driver/names` | `Array[String]` |
| `driver_info(driver : String)` | `GET /api/admin/driver/info?driver=` | `DriverInfo`（单个驱动） |

```moonbit
pub struct DriverInfo {
  common : Array[DriverItem]    // 所有驱动共有
  additional : Array[DriverItem] // 该驱动特有
  config : DriverConfig          // 能力声明
}
pub struct DriverItem { name, item_type, default, options, required : Bool, help }
pub struct DriverConfig { name, local_sort, only_proxy, no_cache, no_upload, need_ms,
                          default_root, alert, only_indices, prefer_proxy }
```

`driver_info` 传了不存在的驱动名时服务端返回 404 `driver [X] not found`。
⚠️ 官方文档把 `list` / `names` / `info` 的返回都写成 `DriverInfo[]`，实际是：
`list` 是「驱动名 → DriverInfo 的 Map」，`names` 是字符串数组，而 `info` 是
**单个** `DriverInfo`（`{common, additional, config}`，与 map 里的某一项同形，
没有外层数组）——服务端 `GetDriverInfo` 就是 `SuccessResp(c, infoMap[driverName])`。

## 5. setting 子域

| 方法 | 端点 | 返回 |
|------|------|------|
| `list_settings(group? : Int, groups? : Array[Int])` | `GET /api/admin/setting/list?group=` 或 `?groups=1,2` | `Array[SettingItem]` |
| `get_setting(key : String)` | `GET /api/admin/setting/get?key=` | `SettingItem` |
| `get_settings(keys : Array[String])` | `GET /api/admin/setting/get?keys=a,b` | `Array[SettingItem]` |
| `save_settings(Array[SettingItem])` | `POST /api/admin/setting/save` | `Unit`（data 为 null） |
| `delete_setting(key : String)` | `POST /api/admin/setting/delete?key=` | `Unit` |
| `reset_token() -> String` | `POST /api/admin/setting/reset_token` | 新的 API token 字符串 |
| `default_settings(group?, groups?)` | `POST /api/admin/setting/default` | `Array[SettingItem]` |

```moonbit
pub struct SettingItem {
  key : String
  value : String
  help : String
  item_type : String   // 服务端的 JSON key 是 "type"
  options : String
  group : Int
  flag : Int
  index : UInt
}
```

- ⚠️ **同一个 `get` 端点有两种响应形态**：`?key=X` 返回**单个对象**，
  `?keys=a,b` 返回**数组**。本项目拆成 `get_setting` / `get_settings` 两个方法，
  避免调用方自己去猜。
- `type` 是 MoonBit 关键字，模型里字段名是 `item_type`，`FromJson` / `ToJson` 手写
  映射到服务端的 `type`，所以 `save_settings` 能把拿到的 `SettingItem` 原样回传。
- `list_settings` 按 `group`（单个）或 `groups`（逗号分隔的多个）过滤，都不给则
  返回全部；`groups` 拼成 `1,2,3` 的逗号串。
- `reset_token` 的 `data` 是**裸字符串**（不是对象）。
- 12 个第三方驱动配置（`/api/admin/setting/set_*`）没有单独封装，用
  `save_settings` 或逃生通道即可，见 [08](./08-unsupported-endpoints.md)。

## 6. index 子域

| 方法 | 端点 | 说明 |
|------|------|------|
| `index_build()` | `POST /api/admin/index/build` | 全量构建；已在跑时 400 `index is running` |
| `index_update(paths, max_depth?)` | `POST /api/admin/index/update` | 请求体 `{paths, max_depth}` |
| `index_stop()` | `POST /api/admin/index/stop` | |
| `index_clear()` | `POST /api/admin/index/clear` | |
| `index_progress() -> IndexProgress` | `GET /api/admin/index/progress` | 进度 |

```moonbit
pub struct IndexProgress {
  obj_count : Int64
  is_done : Bool
  last_done_time : String?  // RFC3339；从未完成时 None
  error : String
}
```

⚠️ 官方文档把 `/index/progress` 描述成 `{total, current, status}`；源码返回的是
`model.IndexProgress{obj_count, is_done, last_done_time, error}`。

## 7. 示例

```moonbit
let admin = client.admin()

// 驱动与存储
println(admin.driver_names())
let storages = admin.list_storages(page=1, per_page=20)
let id = admin.create_storage(@open-list.Storage::{
  mount_path: "/s3",
  driver: "S3",
  order: 0,
  addition: "{\"bucket\":\"…\"}",
  ..storages.content[0],
})

// 设置
let item = admin.get_setting("site_title")
admin.save_settings([@open-list.SettingItem::{ value: "新标题", ..item }])
println(admin.reset_token())

// 用户与索引
admin.create_user(@open-list.User::{ username: "alice", password: "p@ss", role: 1, disabled: false, .. })
admin.index_update(["/docs"], max_depth=3)
println(admin.index_progress().obj_count)
```

> 字段字面量的 `..` 展开需要同类型的值；上面的写法只为示意，实际请先
> `get_storage` / `get_setting` / `get_user` 拿到基线再改字段。

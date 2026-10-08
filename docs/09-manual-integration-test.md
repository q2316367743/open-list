# 真机联调程序（`src/main/`）

`src/main/` 不是示例片段，而是一个可以对着**真实 OpenList** 跑一遍全部已封装接口的
控制台程序：每测一个端点都打一行「测了哪个 API、结果如何」的结论，紧跟服务器返回的
原始 `data` 作为证据，最后给一份通过 / 失败 / 跳过的汇总；管理端与写入自测按账号角色
与实际需要可选执行。

## 怎么跑

```
moon run src/main
```

程序用**永久 token** 模式启动（`create_open_list_client_with_token`），不读账号密码；
服务器、token、测试目录都写在 `src/main/main.mbt` 顶部的常量里：

| 常量 | 当前值 | 说明 |
|------|--------|------|
| `base_url` | `http://10.20.30.2:23245` | OpenList 地址 |
| `api_token` | `openlist-9548aae6-…`（内网永久 token） | 后台「设置 → 令牌」生成的永久 token；请求头直接放它，不带 `Bearer` 前缀 |
| `test_dir` | `/服务器/Downloads/测试` | 联调用的测试目录（相对服务端数据根目录） |

换服务器时改这三个常量即可。想改用账号密码模式（换限时 token），把
`create_open_list_client_with_token(base_url, api_token)` 换成
`create_open_list_client(Settings::new(base_url, timeout=60000), Credentials::password(user, pwd))`，
并在 `check_user` 之前先调一次 `auth().login(user, pwd)`。

## 输出结构

每个端点一行结论，只读端点再跟一段原始 `data` 作为证据：

```
[7] ✔ 通过 GET /api/me ｜ user().me()
     原始 data：
     { …完整 JSON，缩进 2 空格… }
```

- 结论行格式是 `[序号] ✔/✗/- 状态 API ｜ 方法调用：摘要`，状态含义：`✔ 通过`、
  `✗ 失败`（摘要位是错误信息）、`- 跳过`（如非管理员不跑管理端、目录里没有压缩包
  不跑归档、没有选择写入自测）。
- 证据行来自 `OpenListClient::request`（逃生通道）+ `Json::stringify(indent=2)`，
  字段一个不少，**这就是「完整测试数据」**；它只出现在只读端点后面。
- 结论行由各子模块的类型化方法产生，验证模型真的能解码。
- 上传 / 分片这类二进制请求走不了逃生通道（它只收 JSON body），所以只打结论行
  （`TaskInfo` 或 `SessionSnapshot` 摘要）；写入自测里的写端点也只调一次，避免重复
  产生副作用。
- 程序最后打「测试汇总」：`共测 N 项：通过 x，失败 y，跳过 z`，再列失败明细与跳过
  明细，一个失败一个跳过都没有时补一句 `全部通过。`。

## 执行流程

1. 用永久 token 建客户端（token 校验放在第 2 步）。
2. `check_user`：`/api/me` 与 `/api/me/sshkey/list`，从角色判断是不是管理员
   （`role == 2`）；`/api/me` 失败（例如 token 已失效）就地打汇总并退出，后面不再测。
3. `check_public`：`init_status`、`archive_extensions`、`offline_download_tools`、`settings`。
4. `check_fs_read`：`list`、`get`、`dirs`、`search`（关键词取列表第一条目的名字）；
   测试目录里恰好有压缩包时再跑 `archive_meta` 与 `archive_list`。
5. `check_share`：`share/list`。
6. 角色是管理员时跑 `check_admin`：`meta` 列表 / 单条、`user` 列表 / 单个 / 该用户的
   SSH 公钥、`storage` 列表 / 单个、`driver` 名字 / 映射 / 单个驱动的配置、`setting`
   列表 / 单条、索引进度；不是管理员就记一条「跳过」。
7. 询问是否继续写入自测，回答 `y` / `Y` / `yes` / `YES` 才执行；不跑就记一条「跳过」。
8. 打测试汇总。

## 写入自测（`check_write`）

所有写操作都发生在 `<test_dir>/open-list-self-test` 这一个子目录里：

| 步骤 | 说明 |
|------|------|
| `mkdir` | 建自测目录 |
| `put_bytes(hello.txt)` | 同步上传（走 `PUT /api/fs/put`） |
| `put_bytes(task.txt, as_task=true)` | 任务式上传，打印 `TaskInfo` |
| `put_form(form.txt)` | `multipart/form-data` 上传 |
| `multipart_upload(big.bin)` | 3 MB、1 MB 分片，走分片上传全流程 |
| `list` / `get` | 确认文件都在、能读到大小与时间 |
| `rename` | `hello.txt` → `renamed.txt` |
| `create_link` | 仅管理员：`POST /api/fs/link` 取直链 |
| 分享 | `create` → `get` → `disable` → `delete`（带密码 `1234`） |
| `remove` + `remove_empty_directory` | 删掉 4 个自测文件与自测目录 |

每一步失败只打印错误并继续，不会中断后面的步骤。

## 常见的环境性失败

| 现象 | 原因 |
|------|------|
| `GET /api/public/init_status` 返回 HTML（`Decode: HTTP 404：响应不是合法 JSON：<!doctype html>…`） | 服务端较旧，没有初始化向导那两条路由；本程序先探一次，探不到就记「跳过」 |
| `POST /api/fs/link` 报 `API 500: failed link: failed get link: redirect failed, status: 200` | 该存储驱动不支持生成直链，是服务端能力问题，与客户端无关 |
| `Decode: HTTP 502：响应不是合法 JSON：…` | 请求打到了反向代理的错误页 |
| `Http: 网络请求失败：ResolveHostnameError(...)` | 地址写错或服务端不可达 |

`Decode` 类错误的消息里带 HTTP 状态，可以据此区分「路由不存在（404 + HTML）」与
「响应真的是坏 JSON」。

## 安全说明

- 只读部分不会改动服务器：管理端全部是 `get` / `list` / `progress`。
- 唯一的写操作在写入自测里，只碰 `<test_dir>/open-list-self-test`，并且结束时把它
  删掉（先删文件再删空目录）。
- 程序用永久 token 认证，终端里不再输入密码；token 以明文写在 `src/main/main.mbt`
  的常量里，只适合内网 / 本机联调——要放进公开仓库请改成从环境变量或控制台读取。
- 未封装的端点（SSO、WebAuthn、`/api/task/*`、扫描、种子等）不在本程序里，见
  [08 未封装的端点](./08-unsupported-endpoints.md)。

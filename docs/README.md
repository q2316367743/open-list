# open-list 文档索引

MoonBit 版 OpenList API 客户端：一个门面（`OpenListClient`）+ 六个功能域子模块。
接口契约以 **OpenList v4 服务端源码**（`OpenListTeam/OpenList`）为准；官方 Apifox
文档与源码有出入的地方，在对应文档里都用「⚠️ 与文档不一致」标了出来。

| 编号 | 标题 | 描述 |
|------|------|------|
| [00](./00-architecture.md) | 架构与分层 | 门面 / core / 六域的分层、认证状态共享、请求管线、错误模型、测试策略与已知限制 |
| [01](./01-auth.md) | 认证 Authentication | 登录（明文 / 预哈希 / LDAP）、退出、token 管理、两步验证 |
| [02](./02-user.md) | 当前用户 User | `/api/me`、修改自己、自己的 SSH 公钥 |
| [03](./03-admin.md) | 管理 Admin | 元信息、用户、存储、驱动、设置、索引六个子域 |
| [04](./04-file-system.md) | 文件系统 File System | 列目录 / 读、文件管理、上传（流式与分片）、归档与离线下载 |
| [05](./05-public.md) | 公共 Public | 站点设置、离线下载工具、归档扩展名、站点初始化 |
| [06](./06-sharing.md) | 分享 Sharing | 分享记录的增删改查与启停 |
| [07](./07-json-modeling.md) | JSON 建模约定 | 信封、`derive` 的实测语义、`null` 剔除、手写 `FromJson` 的场景 |
| [08](./08-unsupported-endpoints.md) | 未封装的端点 | SSO / WebAuthn / 任务域 / 扫描 / 种子等，以及逃生通道用法 |
| [09](./09-manual-integration-test.md) | 真机联调程序 | `moon run src/main` 的用法（永久 token 模式）、输出含义、执行流程与写入自测的边界 |
| [10](./10-ci-and-release.md) | CI 与发布 | 两个 GitHub Actions 工作流：检查 / 构建 / 测试门禁，Release 触发发布到 mooncakes.io 的完整流程 |

代码结构（`src/`）：

```
src/
  open_list.mbt   reexport.mbt        根包门面：OpenListClient、创建函数、pub using 再导出
  core/          认证状态、错误、JSON 工具、请求管线、共享模型
  auth/ user/ admin/ fs/ public/ share/    六个功能域子模块
  main/          真机联调程序（moon run src/main，见 09）
```

约定：使用者通常只 `import { "q2316367743/open-list" }` 并调用
`create_open_list_client`；域子模块与 `core` 都不用直接 import（要做官方客户端没
封装的请求时，用 `OpenListClient::request`）。

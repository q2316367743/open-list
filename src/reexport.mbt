// ============================================================================
// 门面：把各子包里对使用者有意义的公开类型从根包再导出一份。
//
// 这样使用者只 import `q2316367743/open-list` 就能拿到全部类型，不必记住
// 每个类型归属哪个子包（`core` / `auth` / `user` / `admin` / `fs` /
// `public` / `share`）。子包结构本身仍然保留，需要精细控制（自定义请求、
// 自己实现传输层）的使用者可以直接依赖对应子包。
//
// 约定：凡是出现在公开签名里的类型，都在定义它的包里再导出一次。
//
// ⚠️ 一条硬限制：**`pub using` 再导出不了错误构造子**。`OpenListError` 定义在
// `core` 包里，`pub using` 能让这里出现这个类型名，但构造子仍留在 `core`——
// 所以黑盒测试 `src/open_list_test.mbt` 专门验证「根包能不能 catch 到
// `@lib.OpenListError::Api(...)`」；若该能力不成立，就按文档指引
// import `q2316367743/open-list/core` 来捕获（详见 docs/00-architecture.md）。
// ============================================================================

///|
/// 核心类型再导出：连接设置、凭证、统一错误与全部分页结果。
///
/// `OpenListClient` 的构造参数与六个域子模块的返回值都用这些类型。
pub using @core {
  type Settings,
  type Credentials,
  type PasswordCredentials,
  type OpenListError,
  type ApiError,
  type PageResult,
}

///|
/// 用户域模型再导出：`/api/me` 与 `/api/admin/user/*` 共用。
pub using @core {type User, type UserResponse, type SSHPublicKey}

///|
/// 管理域模型再导出：元信息、存储、设置项、驱动与索引进度。
pub using @core {
  type Meta,
  type Storage,
  type StorageDetails,
  type SettingItem,
  type DriverItem,
  type DriverConfig,
  type DriverInfo,
  type IndexProgress,
}

///|
/// 公共域模型再导出：初始化状态。
pub using @core {type InitStatus}

///|
/// 文件域模型再导出：目录项、列表/详情响应、搜索结果与归档。
pub using @core {
  type ObjResp,
  type ListSort,
  type FsListResponse,
  type FsGetResponse,
  type DirResp,
  type SearchResult,
  type ArchiveContent,
  type ArchiveMetaResponse,
}

///|
/// 上传与任务相关模型再导出：分片会话、任务信息与直链。
pub using @core {
  type SessionSnapshot,
  type MultipartInitResponse,
  type Link,
  type TaskInfo,
}

///|
/// 分享域响应模型再导出。
pub using @core {type SharingResponse}

///|
/// 请求体类型再导出：各域方法的入参。
pub using @user {type UpdateMeRequest}

///|
/// 管理域的索引更新入参。
pub using @admin {type UpdateIndexRequest}

///|
/// 文件域入参：上传哈希与批量重命名的一对名字。
pub using @fs {type FileHash, type RenameObject}

///|
/// 分享域的创建 / 更新入参。
pub using @share {type SharingUpdateRequest}

///|
/// 让使用者不必直接依赖 moonhttp：`OpenListClient::request` 的 HTTP 方法、
/// 以及 `create_open_list_client` 的传输层注入点都在这里。
pub using @moonhttp {type Method, trait Transport}

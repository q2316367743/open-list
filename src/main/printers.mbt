///|
/// 把各域的模型摘要成一行可读文本，供联调程序打印。
///
/// 类型化方法返回的结构体只在这里被格式化，真正的「完整数据」由
/// `console.mbt` 的 `dump_endpoint` 打原始 JSON。

///|
/// 把字符串数组拼成一行。
pub fn joined(parts : Array[String]) -> String {
  parts.join("、")
}

///|
/// 条目名列表。
pub fn name_list(items : Array[@lib.ObjResp]) -> String {
  joined(items.map(fn(item) { item.name }))
}

///|
/// 截断过长的文本（存储的 `addition` 常常是一大串 JSON）。
pub fn brief(text : String, limit : Int) -> String {
  if text.length() <= limit {
    text
  } else {
    "\{text[:limit]}…（共 \{text.length()} 字符）"
  }
}

///|
/// 可选字符串的显示（`None` 打成一个短标记）。
pub fn opt_str(value : String?) -> String {
  match value {
    Some(text) => text
    None => "（无）"
  }
}

///|
/// 最多取前 n 项。
pub fn[T] take(items : Array[T], n : Int) -> Array[T] {
  if items.length() <= n {
    items
  } else {
    items[:n].to_owned()
  }
}

///|
/// 角色名（服务端常量：0 普通用户、1 游客、2 管理员）。
pub fn role_name(role : Int) -> String {
  match role {
    0 => "普通用户(0)"
    1 => "游客(1)"
    2 => "管理员(2)"
    _ => "未知(\{role})"
  }
}

///|
/// 用户摘要。
pub fn user_summary(user : @lib.User) -> String {
  "id=\{user.id} 用户名=\{user.username} 角色=\{role_name(user.role)} 禁用=\{user.disabled} base_path=\{user.base_path} 权限=\{user.permission} allow_ldap=\{user.allow_ldap}"
}

///|
/// 文件对象摘要。
pub fn obj_summary(obj : @lib.ObjResp) -> String {
  let kind = if obj.is_dir { "目录" } else { "文件" }
  let mount = match obj.mount_details {
    Some(details) =>
      " 容量=\{details.free_space}/\{details.total_space}(\{details.driver_name})"
    None => ""
  }
  "\{kind} \{obj.name} size=\{obj.size} modified=\{obj.modified}\{mount}"
}

///|
/// 目录列表逐条展开（每行一条）。
pub fn entry_lines(items : Array[@lib.ObjResp]) -> String {
  items.map(fn(item) { "    \{obj_summary(item)}" }).join("\n")
}

///|
/// 任务摘要。
pub fn task_summary(task : @lib.TaskInfo) -> String {
  "id=\{task.id} 名称=\{task.name} 状态=\{task.state}/\{task.status} 进度=\{task.progress} 创建者=\{task.creator}\{role_name(task.creator_role)} 字节=\{task.total_bytes} 错误=\{task.error}"
}

///|
/// 上传类方法的返回值（同步上传没有任务）。
pub fn task_result(task : @lib.TaskInfo?) -> String {
  match task {
    Some(info) => "返回任务：\{task_summary(info)}"
    None => "同步完成（服务端没有返回任务）"
  }
}

///|
/// 任务数组摘要。
pub fn task_list_summary(tasks : Array[@lib.TaskInfo]) -> String {
  "共 \{tasks.length()} 个任务：\{joined(tasks.map(fn(task) { task.id }))}"
}

///|
/// 分片上传会话摘要。
pub fn snapshot_summary(snapshot : @lib.SessionSnapshot) -> String {
  let spans = snapshot.received.map(fn(span) { "\{span[0]}-\{span[1]}" })
  "upload_id=\{snapshot.upload_id} 状态=\{snapshot.state} 路径=\{snapshot.path} 大小=\{snapshot.size} 片大小=\{snapshot.chunk_size} 总片数=\{snapshot.total_chunks} 已收=\{snapshot.received_bytes} 前沿=\{snapshot.frontier} 已收区间=\{joined(spans)} 进度=\{snapshot.storage_progress} 错误=\{opt_str(snapshot.error)}"
}

///|
/// 分片初始化响应摘要。
pub fn init_summary(response : @lib.MultipartInitResponse) -> String {
  "resumed=\{response.resumed} \{snapshot_summary(response.snapshot)}"
}

///|
/// 分享记录摘要。
pub fn sharing_summary(record : @lib.SharingResponse) -> String {
  "id=\{record.id} 文件=\{joined(record.files)} 密码=\{record.pwd} 过期=\{opt_str(record.expires)} 访问=\{record.accessed}/\{record.max_accessed} 禁用=\{record.disabled} 创建者=\{record.creator}\{role_name(record.creator_role)} 备注=\{record.remark}"
}

///|
/// SSH 公钥摘要。
pub fn sshkey_summary(key : @lib.SSHPublicKey) -> String {
  "id=\{key.id} 名称=\{key.title} 指纹=\{key.fingerprint} 添加=\{key.added_time} 最近使用=\{key.last_used_time}"
}

///|
/// 元信息摘要。
pub fn meta_summary(meta : @lib.Meta) -> String {
  let locked = if meta.password == "" { "无" } else { "有" }
  "id=\{meta.id} 路径=\{meta.path} 隐藏=\{meta.hide} 可写=\{meta.write} 密码=\{locked} readme=\{brief(meta.readme, 60)} header=\{brief(meta.header, 60)}"
}

///|
/// 存储摘要。
pub fn storage_summary(storage : @lib.Storage) -> String {
  "id=\{storage.id} 挂载路径=\{storage.mount_path} 驱动=\{storage.driver} 顺序=\{storage.order} 状态=\{storage.status} 禁用=\{storage.disabled} 备注=\{storage.remark} addition=\{brief(storage.addition, 80)}"
}

///|
/// 设置项摘要。
pub fn setting_summary(item : @lib.SettingItem) -> String {
  "key=\{item.key} 值=\{brief(item.value, 60)} 类型=\{item.item_type} 分组=\{item.group} flag=\{item.flag} 说明=\{brief(item.help, 40)}"
}

///|
/// 目录项摘要。
pub fn dir_summary(dir : @lib.DirResp) -> String {
  "\{dir.name}（\{dir.modified}）"
}

///|
/// 搜索结果项摘要。
pub fn search_summary(result : @lib.SearchResult) -> String {
  let kind = if result.is_dir { "目录" } else { "文件" }
  "\{kind} \{result.parent}/\{result.name} size=\{result.size} type=\{result.obj_type}"
}

///|
/// 索引进度摘要。
pub fn index_summary(progress : @lib.IndexProgress) -> String {
  "已索引=\{progress.obj_count} 完成=\{progress.is_done} 上次完成=\{opt_str(progress.last_done_time)} 错误=\{progress.error}"
}

///|
/// 驱动信息摘要（字段数很多，只报数量与驱动名）。
pub fn driver_summary(name : String, info : @lib.DriverInfo) -> String {
  "\{name}：公共项 \{info.common.length()} 个、附加项 \{info.additional.length()} 个、本地排序=\{info.config.local_sort} 默认根=\{info.config.default_root}"
}

///|
/// 驱动配置项摘要。
pub fn driver_item_summary(item : @lib.DriverItem) -> String {
  "\{item.name}(\{item.item_type}) 必填=\{item.required} 默认=\{item.default} 说明=\{brief(item.help, 40)}"
}

///|
/// 归档元信息摘要。
pub fn archive_summary(meta : @lib.ArchiveMetaResponse) -> String {
  "注释=\{meta.comment} 加密=\{meta.encrypted} 顶层条目=\{meta.content.length()} 个 raw_url=\{brief(meta.raw_url, 50)}"
}

///|
/// 文件系统读接口（`/api/fs/*`）。

///|
/// 测测试目录的列表、对象详情、子目录与搜索；目录里有压缩包时再测归档信息。
///
/// 返回第一页条目，供调用方挑搜索关键词与压缩包。
pub async fn check_fs_read(
  client : @lib.OpenListClient,
  dir : String,
) -> Array[@lib.ObjResp] {
  section("文件系统（读） /api/fs/*")
  let listing = check(
    "POST /api/fs/list",
    "fs().list(dir)",
    Ok(client.fs().list(dir, page=1, per_page=50)) catch {
      error => Err(error)
    },
    fn(page) {
      "total=\{page.total}，本页 \{page.content.length()} 项，provider=\{page.provider}，可写=\{page.write}，readme=\{page.readme.length()} 字符"
    },
  )
  dump_raw(
    client,
    @lib.Method::Post,
    "/api/fs/list",
    body=Json::object({
      "path": Json::string(dir),
      "page": Json::number(1),
      "per_page": Json::number(50),
      "refresh": Json::boolean(false),
    }),
  )
  let content = match listing {
    Some(page) => {
      say("     条目明细：")
      say(entry_lines(page.content))
      page.content
    }
    None => []
  }
  let _ = check(
    "POST /api/fs/get",
    "fs().get(dir)",
    Ok(client.fs().get(dir)) catch {
      error => Err(error)
    },
    fn(response) {
      "\{obj_summary(response.obj)} provider=\{response.provider} raw_url=\{brief(response.raw_url, 50)} 相关对象=\{response.related.length()} 个"
    },
  )
  dump_raw(
    client,
    @lib.Method::Post,
    "/api/fs/get",
    body=Json::object({ "path": Json::string(dir) }),
  )
  let _ = check(
    "POST /api/fs/dirs",
    "fs().dirs(path=dir)",
    Ok(client.fs().dirs(path=dir)) catch {
      error => Err(error)
    },
    fn(list) {
      "共 \{list.length()} 个子目录：\{joined(list.map(dir_summary))}"
    },
  )
  dump_raw(
    client,
    @lib.Method::Post,
    "/api/fs/dirs",
    body=Json::object({ "path": Json::string(dir) }),
  )
  let keyword = match content {
    [first, ..] => first.name
    [] => ""
  }
  say("     搜索关键词取列表第一条目的名字：\{keyword}")
  let _ = check(
    "POST /api/fs/search",
    "fs().search(dir, keyword, scope=0)",
    Ok(client.fs().search(dir, keyword, scope=0, page=1, per_page=20)) catch {
      error => Err(error)
    },
    fn(page) {
      "total=\{page.total}，本页 \{page.content.length()} 项：\{joined(page.content.map(search_summary))}"
    },
  )
  dump_raw(
    client,
    @lib.Method::Post,
    "/api/fs/search",
    body=Json::object({
      "parent": Json::string(dir),
      "keywords": Json::string(keyword),
      "scope": Json::number(0),
      "page": Json::number(1),
      "per_page": Json::number(20),
    }),
  )
  check_archive(client, dir, content)
  content
}

///|
/// 目录里有压缩包时测归档元信息与归档内列表，否则记一条「跳过」。
async fn check_archive(
  client : @lib.OpenListClient,
  dir : String,
  items : Array[@lib.ObjResp],
) -> Unit {
  match find_archive(dir, items) {
    Some(archive) => {
      let _ = check(
        "POST /api/fs/archive/meta",
        "fs().archive_meta(archive)",
        Ok(client.fs().archive_meta(archive)) catch {
          error => Err(error)
        },
        archive_summary,
      )
      dump_raw(
        client,
        @lib.Method::Post,
        "/api/fs/archive/meta",
        body=Json::object({ "path": Json::string(archive) }),
      )
      let _ = check(
        "POST /api/fs/archive/list",
        "fs().archive_list(archive)",
        Ok(client.fs().archive_list(archive, page=1, per_page=20)) catch {
          error => Err(error)
        },
        fn(page) { "total=\{page.total}，本页 \{page.content.length()} 项" },
      )
      dump_raw(
        client,
        @lib.Method::Post,
        "/api/fs/archive/list",
        body=Json::object({
          "path": Json::string(archive),
          "inner_path": Json::string(""),
          "page": Json::number(1),
          "per_page": Json::number(20),
        }),
      )
    }
    None =>
      skip(
        "POST /api/fs/archive/meta、/api/fs/archive/list", "归档接口", "测试目录里没有压缩包（.zip/.7z/.tar/.gz/.rar/.xz/.bz2）",
      )
  }
}

///|
/// 在目录列表里找一个压缩包，返回它的完整路径。
fn find_archive(dir : String, items : Array[@lib.ObjResp]) -> String? {
  for item in items {
    if !item.is_dir && is_archive_name(item.name) {
      return Some(dir + "/" + item.name)
    }
  }
  None
}

///|
/// 按扩展名判断是不是压缩包。
fn is_archive_name(name : String) -> Bool {
  for ext in [".zip", ".7z", ".tar", ".gz", ".rar", ".xz", ".bz2", ".zst"] {
    if name.has_suffix(ext) {
      return true
    }
  }
  false
}

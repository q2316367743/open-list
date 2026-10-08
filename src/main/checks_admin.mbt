///|
/// 管理端接口（`/api/admin/*`），需要管理员账号。

///|
/// 分页查询参数（第一页，每页 10 条）。
fn page_query() -> Json {
  Json::object({ "page": Json::number(1), "per_page": Json::number(10) })
}

///|
/// `?id=` 查询参数。
fn id_query(id : UInt) -> Json {
  Json::object({ "id": Json::number(id.to_double()) })
}

///|
/// 分页地测管理端只读接口：meta / user / storage，再由 checks_admin_more 测
/// driver / setting / index。
pub async fn check_admin(client : @lib.OpenListClient) -> Unit {
  section("管理端 /api/admin/*")
  check_admin_meta(client)
  check_admin_user(client)
  check_admin_storage(client)
  check_admin_more(client)
}

///|
/// 元信息接口。
async fn check_admin_meta(client : @lib.OpenListClient) -> Unit {
  step("元信息 /api/admin/meta/*")
  let listing = check(
    "GET /api/admin/meta/list",
    "admin().list_meta(page=1, per_page=10)",
    Ok(client.admin().list_meta(page=1, per_page=10)) catch {
      error => Err(error)
    },
    fn(page) {
      "total=\{page.total}，本页 \{page.content.length()} 条：\{joined(page.content.map(fn(meta) { meta.path }))}"
    },
  )
  dump_raw(client, @lib.Method::Get, "/api/admin/meta/list", query=page_query())
  let metas = match listing {
    Some(page) => page.content
    None => []
  }
  match metas {
    [first, ..] => {
      let _ = check(
        "GET /api/admin/meta/get",
        "admin().get_meta(id)",
        Ok(client.admin().get_meta(first.id)) catch {
          error => Err(error)
        },
        meta_summary,
      )
      dump_raw(
        client,
        @lib.Method::Get,
        "/api/admin/meta/get",
        query=id_query(first.id),
      )
    }
    [] => ()
  }
}

///|
/// 用户接口。
async fn check_admin_user(client : @lib.OpenListClient) -> Unit {
  step("用户 /api/admin/user/*")
  let listing = check(
    "GET /api/admin/user/list",
    "admin().list_users(page=1, per_page=10)",
    Ok(client.admin().list_users(page=1, per_page=10)) catch {
      error => Err(error)
    },
    fn(page) {
      "total=\{page.total}，本页 \{page.content.length()} 个：\{joined(page.content.map(user_summary))}"
    },
  )
  dump_raw(client, @lib.Method::Get, "/api/admin/user/list", query=page_query())
  let users = match listing {
    Some(page) => page.content
    None => []
  }
  match users {
    [first, ..] => {
      let _ = check(
        "GET /api/admin/user/get",
        "admin().get_user(id)",
        Ok(client.admin().get_user(first.id)) catch {
          error => Err(error)
        },
        user_summary,
      )
      dump_raw(
        client,
        @lib.Method::Get,
        "/api/admin/user/get",
        query=id_query(first.id),
      )
      let _ = check(
        "GET /api/admin/user/sshkey/list",
        "admin().list_user_ssh_keys(uid, page=1, per_page=20)",
        Ok(client.admin().list_user_ssh_keys(first.id, page=1, per_page=20)) catch {
          error => Err(error)
        },
        fn(page) {
          "total=\{page.total}，本页 \{page.content.length()} 个：\{joined(page.content.map(sshkey_summary))}"
        },
      )
      dump_raw(
        client,
        @lib.Method::Get,
        "/api/admin/user/sshkey/list",
        query=Json::object({
          "uid": Json::number(first.id.to_double()),
          "page": Json::number(1),
          "per_page": Json::number(20),
        }),
      )
    }
    [] => ()
  }
}

///|
/// 存储接口。
async fn check_admin_storage(client : @lib.OpenListClient) -> Unit {
  step("存储 /api/admin/storage/*")
  let listing = check(
    "GET /api/admin/storage/list",
    "admin().list_storages(page=1, per_page=10)",
    Ok(client.admin().list_storages(page=1, per_page=10)) catch {
      error => Err(error)
    },
    fn(page) {
      "total=\{page.total}，本页 \{page.content.length()} 个：\{joined(page.content.map(storage_summary))}"
    },
  )
  dump_raw(
    client,
    @lib.Method::Get,
    "/api/admin/storage/list",
    query=page_query(),
  )
  let storages = match listing {
    Some(page) => page.content
    None => []
  }
  match storages {
    [first, ..] => {
      let _ = check(
        "GET /api/admin/storage/get",
        "admin().get_storage(id)",
        Ok(client.admin().get_storage(first.id)) catch {
          error => Err(error)
        },
        storage_summary,
      )
      dump_raw(
        client,
        @lib.Method::Get,
        "/api/admin/storage/get",
        query=id_query(first.id),
      )
    }
    [] => ()
  }
}

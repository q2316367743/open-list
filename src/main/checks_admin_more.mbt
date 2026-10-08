///|
/// 管理端的驱动、设置与索引接口。

///|
/// 测 `/api/admin/driver/*`、`/api/admin/setting/*`、`/api/admin/index/progress`。
pub async fn check_admin_more(client : @lib.OpenListClient) -> Unit {
  check_admin_driver(client)
  check_admin_setting(client)
  check_admin_index(client)
}

///|
/// 驱动接口。
async fn check_admin_driver(client : @lib.OpenListClient) -> Unit {
  step("驱动 /api/admin/driver/*")
  let names_result = check(
    "GET /api/admin/driver/names",
    "admin().driver_names()",
    Ok(client.admin().driver_names()) catch {
      error => Err(error)
    },
    fn(list) { "共 \{list.length()} 个：\{joined(take(list, 10))}" },
  )
  dump_raw(client, @lib.Method::Get, "/api/admin/driver/names")
  let _ = check(
    "GET /api/admin/driver/list",
    "admin().list_drivers()",
    Ok(client.admin().list_drivers()) catch {
      error => Err(error)
    },
    fn(map) { "共 \{map.length()} 个驱动的配置项" },
  )
  dump_raw(client, @lib.Method::Get, "/api/admin/driver/list")
  let names = match names_result {
    Some(list) => list
    None => []
  }
  match names {
    [first, ..] => {
      let _ = check(
        "GET /api/admin/driver/info",
        "admin().driver_info(driver)",
        Ok(client.admin().driver_info(first)) catch {
          error => Err(error)
        },
        fn(info) {
          "\{driver_summary(first, info)}；公共项前 5 个：\{joined(take(info.common, 5).map(driver_item_summary))}"
        },
      )
      dump_raw(
        client,
        @lib.Method::Get,
        "/api/admin/driver/info",
        query=Json::object({ "driver": Json::string(first) }),
      )
    }
    [] => ()
  }
}

///|
/// 设置接口。
async fn check_admin_setting(client : @lib.OpenListClient) -> Unit {
  step("设置 /api/admin/setting/*")
  let listing = check(
    "GET /api/admin/setting/list",
    "admin().list_settings(group=0)",
    Ok(client.admin().list_settings(group=0)) catch {
      error => Err(error)
    },
    fn(list) {
      "共 \{list.length()} 项，前 10 个 key：\{joined(take(list, 10).map(fn(item) { item.key }))}"
    },
  )
  dump_raw(
    client,
    @lib.Method::Get,
    "/api/admin/setting/list",
    query=Json::object({ "group": Json::number(0) }),
  )
  let settings = match listing {
    Some(list) => list
    None => []
  }
  match settings {
    [first, ..] => {
      let _ = check(
        "GET /api/admin/setting/get",
        "admin().get_setting(key)",
        Ok(client.admin().get_setting(first.key)) catch {
          error => Err(error)
        },
        setting_summary,
      )
      dump_raw(
        client,
        @lib.Method::Get,
        "/api/admin/setting/get",
        query=Json::object({ "key": Json::string(first.key) }),
      )
    }
    [] => ()
  }
}

///|
/// 索引状态。
async fn check_admin_index(client : @lib.OpenListClient) -> Unit {
  step("索引 /api/admin/index/*")
  let _ = check(
    "GET /api/admin/index/progress",
    "admin().index_progress()",
    Ok(client.admin().index_progress()) catch {
      error => Err(error)
    },
    index_summary,
  )
  dump_raw(client, @lib.Method::Get, "/api/admin/index/progress")
}

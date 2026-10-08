///|
/// 公共接口（`/api/public/*`）：这些端点不需要认证，这里仍用已登录的客户端调用。

///|
/// 依次测 `init_status` / `archive_extensions` / `offline_download_tools` / `settings`。
pub async fn check_public(client : @lib.OpenListClient, dir : String) -> Unit {
  section("公共接口 /api/public/*")
  // 初始化向导是 OpenList 较新版本才有的路由：旧版本没有 `/init_status`，
  // 未匹配的路径会落到前端静态页（HTML），表现为 `Decode`。先探一下，探不到
  // 就记「跳过」——那是服务端版本问题，不是客户端解码错。
  let init_status_supported = try {
    let _ = client.request(@lib.Method::Get, "/api/public/init_status")
    true
  } catch {
    @lib.OpenListError::Decode(_) => false
    @lib.OpenListError::Http(_) => true
    @lib.OpenListError::Api(_) => true
  }

  if init_status_supported {
    let _ = check(
      "GET /api/public/init_status",
      "public().init_status()",
      Ok(client.public().init_status()) catch {
        error => Err(error)
      },
      fn(status) { "initialized=\{status.initialized}" },
    )
    dump_raw(client, @lib.Method::Get, "/api/public/init_status")
  } else {
    skip(
      "GET /api/public/init_status", "public().init_status()", "服务端没有这个路由（初始化向导需要较新版本，旧版本返回前端页面）",
    )
  }
  let _ = check(
    "GET /api/public/archive_extensions",
    "public().archive_extensions()",
    Ok(client.public().archive_extensions()) catch {
      error => Err(error)
    },
    fn(list) { "共 \{list.length()} 个：\{joined(take(list, 10))}" },
  )
  dump_raw(client, @lib.Method::Get, "/api/public/archive_extensions")
  let _ = check(
    "GET /api/public/offline_download_tools?path=<测试目录>",
    "public().offline_download_tools(dir)",
    Ok(client.public().offline_download_tools(path=dir)) catch {
      error => Err(error)
    },
    fn(list) { "共 \{list.length()} 个：\{joined(take(list, 10))}" },
  )
  dump_raw(
    client,
    @lib.Method::Get,
    "/api/public/offline_download_tools",
    query=Json::object({ "path": Json::string(dir) }),
  )
  let _ = check(
    "GET /api/public/settings",
    "public().settings()",
    Ok(client.public().settings()) catch {
      error => Err(error)
    },
    fn(map) { "共 \{map.length()} 项" },
  )
  dump_raw(client, @lib.Method::Get, "/api/public/settings")
}

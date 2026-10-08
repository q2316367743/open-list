///|
/// open-list 真机联调程序：用永久 token 创建客户端，把六个域的接口按测试报告的
/// 形式跑一遍（结论行 + 原始数据证据 + 最后的汇总）。

///|
/// 服务器地址。
let base_url = "http://10.20.30.2:23245"

///|
/// 永久 token（OpenList 后台「设置 → 令牌」生成的 `openlist-…` 字符串）。
/// 请求头里直接放它，不带 `Bearer` 前缀。
let api_token = "openlist-9548aae6-761d-4457-8797-d54d3747c25cOvmrvnsoLFo9N1pVI47cdzfau003dYHlYb1Otes3f6e57WQn3ErhsTRqCx9xZ4O8"

///|
/// 测试目录（服务端数据根目录下的路径）。
let test_dir = "/服务器/Downloads/测试"

///|
/// 联调入口。
async fn main {
  section("open-list 真机联调（token 模式）")
  say("服务器：\{base_url}")
  say("测试目录：\{test_dir}")
  say("token：已配置（共 \{api_token.length()} 字符的永久 token）")
  let client = @lib.create_open_list_client_with_token(base_url, api_token)
  let me = check_user(client)
  let is_admin = match me {
    None => {
      say("token 无效或已失效，后面的接口没法测，退出。")
      report_summary()
      return
    }
    Some(user) => user.role == 2
  }
  say(
    "当前账号是管理员：\{is_admin}（服务端角色 2 才是管理员）",
  )
  check_public(client, test_dir)
  let entries = check_fs_read(client, test_dir)
  say("测试目录第一页共 \{entries.length()} 个条目。")
  check_share(client)
  if is_admin {
    check_admin(client)
  } else {
    skip(
      "GET/POST /api/admin/*", "管理端接口", "当前账号不是管理员（角色 != 2）",
    )
  }
  let answer = read_line(
    "\n是否继续跑写入自测（会在 \{test_dir} 下建文件并删除）？[y/N] ",
  )
  match answer {
    "y" | "Y" | "yes" | "YES" => check_write(client, test_dir, is_admin)
    _ =>
      skip(
        "PUT /api/fs/put、POST /api/share/create…", "写入自测", "你选择了不跑",
      )
  }
  report_summary()
}

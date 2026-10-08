///|
/// 控制台输入输出的小工具。所有输出都直接写 `@stdio.stdout`（不经过 libc
/// 缓冲），保证提示语一定出现在「等待输入」之前。

///|
/// 输出一行。
pub async fn say(text : String) -> Unit {
  @stdio.stdout.write("\{text}\n")
}

///|
/// 输出一个分节标题。
pub async fn section(title : String) -> Unit {
  @stdio.stdout.write("\n===== \{title} =====\n")
}

///|
/// 输出一个缩进的小标题。
pub async fn step(title : String) -> Unit {
  @stdio.stdout.write("\n-- \{title}\n")
}

///|
/// 从控制台读一行并去掉首尾空白；读到 EOF 时返回空串。
pub async fn read_line(prompt : String) -> String {
  @stdio.stdout.write(prompt)
  match @stdio.stdin.read_until("\n") {
    Some(line) => line.trim().to_owned()
    None => ""
  }
}

///|
/// 打印服务器返回的原始 `data`（完整测试数据），作为紧邻那条结果行的证据。
///
/// 用逃生通道发请求，看得到信封里真正的字段。取不到就只打一行原因，不算独立
/// 测试项（对应的类型化调用会记一条失败）。
pub async fn dump_raw(
  client : @lib.OpenListClient,
  http_method : @lib.Method,
  path : String,
  query? : Json,
  body? : Json,
) -> Unit {
  match
    (Some(client.request(http_method, path, query?, body?)) catch {
      error => {
        say("     原始数据获取失败：\{error.message()}")
        None
      }
    }) {
    Some(data) => say("     原始 data：\{data.stringify(indent=2)}")
    None => ()
  }
}

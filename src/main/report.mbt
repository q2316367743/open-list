///|
/// 联调结果收集与最终报告。
///
/// 每测一个端点就调用 `check` 记一条结果（同时打一行「测了什么、结果如何」），
/// 程序结束时 `report_summary` 汇总通过 / 失败 / 跳过的数量与明细。原始 JSON 由
/// `console.mbt` 的 `dump_raw` 作为证据打在结论之后。

///|
/// 单条结果的状态。
pub enum CaseStatus {
  Passed
  Failed
  Skipped
}

///|
/// 状态名。
pub fn CaseStatus::name(self : CaseStatus) -> String {
  match self {
    Passed => "通过"
    Failed => "失败"
    Skipped => "跳过"
  }
}

///|
/// 一条端点的测试结果。
pub struct CaseResult {
  seq : Int
  api : String
  label : String
  status : CaseStatus
  detail : String
}

///|
/// 本次联调的全部结果（模块级单例，进程内有效）。
let cases : Array[CaseResult] = []

///|
/// 记一条结果并打一行结果行。
async fn record(
  api : String,
  label : String,
  status : CaseStatus,
  detail : String,
) -> Unit {
  let seq = cases.length() + 1
  cases.push({ seq, api, label, status, detail, })
  let mark = match status {
    Passed => "✔"
    Failed => "✗"
    Skipped => "-"
  }
  @stdio.stdout.write(
    "[\{seq}] \{mark} \{CaseStatus::name(status)} \{api} ｜ \{label}：\{detail}\n",
  )
}

///|
/// 测一个类型化调用：打结果行并记录；成功时把值返回给调用方继续用。
pub async fn[T] check(
  api : String,
  label : String,
  outcome : Result[T, @lib.OpenListError],
  show : (T) -> String,
) -> T? {
  match outcome {
    Ok(value) => {
      record(api, label, Passed, show(value))
      Some(value)
    }
    Err(error) => {
      record(api, label, Failed, error.message())
      None
    }
  }
}

///|
/// 记一条「跳过」（权限不够、环境不满足等）。
pub async fn skip(api : String, label : String, reason : String) -> Unit {
  record(api, label, Skipped, reason)
}

///|
/// 打最终测试报告：总数、通过 / 失败 / 跳过，以及失败与跳过的明细。
pub async fn report_summary() -> Unit {
  section("测试汇总")
  let mut passed = 0
  let mut failed = 0
  let mut skipped_count = 0
  let failed_lines : Array[String] = []
  let skipped_lines : Array[String] = []
  for item in cases {
    match item.status {
      Passed => passed = passed + 1
      Failed => {
        failed = failed + 1
        failed_lines.push(
          "  ✗ [\{item.seq}] \{item.api} ｜ \{item.label}：\{item.detail}",
        )
      }
      Skipped => {
        skipped_count = skipped_count + 1
        skipped_lines.push(
          "  - [\{item.seq}] \{item.api} ｜ \{item.label}：\{item.detail}",
        )
      }
    }
  }
  say(
    "共测 \{cases.length()} 项：通过 \{passed}，失败 \{failed}，跳过 \{skipped_count}",
  )
  if !failed_lines.is_empty() {
    say("失败明细：")
    say(failed_lines.join("\n"))
  }
  if !skipped_lines.is_empty() {
    say("跳过明细：")
    say(skipped_lines.join("\n"))
  }
  if failed == 0 && skipped_count == 0 {
    say("全部通过。")
  }
}

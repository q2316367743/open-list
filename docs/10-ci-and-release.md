# 10 CI 与发布

> 对应文件：`.github/workflows/ci.yml`、`.github/workflows/publish.yml`
> 参考实现：`moonhttp` 仓库的同名 workflow（结构与门禁一致）

## 1. 两个工作流的职责

| 工作流 | 触发 | 做什么 |
|--------|------|--------|
| `ci.yml` | push 到 `master`、任何 PR、手动 | 检查 → 构建 → 测试，外加 `.mbti`/格式两道门禁 |
| `publish.yml` | 发布 Release（`types: [released]`）、手动 | 校验 tag 与版本一致 → 重跑全部门禁 → `moon publish` 到 mooncakes.io |

CI 用 `concurrency: ci-${{ github.ref }}` + `cancel-in-progress`：同一分支连续推送时只
保留最后一次运行。两个工作流都只申请 `contents: read`（发布用的是 `MOONCAKES_TOKEN`
这个 secret，不是 `GITHUB_TOKEN`）。

## 2. 命令序列与理由

安装工具链统一用官方脚本，之后 `moon version --all`（留版本证据）、`moon update`
（同步 `moon.mod` 里的 `moonbitlang/async@0.22.4`、`q2316367743/moonhttp@0.5.0`）。

| 步骤 | 命令 | 为什么这么写 |
|------|------|--------------|
| 检查 | `moon check --deny-warn` | 告警也计入失败，避免告警长期堆积 |
| 构建 | `moon build` | 走模块默认的 native 目标（`preferred_target = "native"`） |
| 测试 | `moon test` | 快照用例用 `--update` 刷新这一行为**不在** CI 里做，必须提交时已是最新 |
| `.mbti` 门禁 | `moon info` + `git diff --exit-code` | 新增公开 API 却忘了提交重新生成的 `.mbti` 时报错 |
| 格式门禁 | `moon fmt` + `git diff --exit-code` | 代码没跑 `moon fmt` 时报错 |

两道门禁来自 moonbitlang 官方仓库做法：跑完命令看工作区是否产生 diff，产生即失败。
`publish.yml` 在发布前重跑同一套门禁（多了 `moon build`），任何一步失败都不发布。

## 3. 发布一个新版本的流程

1. 改 `moon.mod` 的 `version`（例如 `0.1.0` → `0.1.1`），提交并推送到 `master`
2. 等这次 push 的 CI 跑绿
3. 仓库页 → Releases → Draft a new release：Tag 填 `v0.1.1`（target 选 `master`），
   **不要**勾 `Set as a pre-release`，**不要**存成 Draft
4. Publish release → `publish.yml` 自动执行

Release 建在 tag 上，与分支无关，所以不需要额外的发布分支；mooncakes.io 上的版本号取
自 `moon.mod` 的 `version`，tag 只是标记。仅推送 tag、或把 Release 存成 Draft /
标为 pre-release 都**不会**触发。也可以在 Actions 页手动 `workflow_dispatch`，直接发布
当前 `master` 的版本。

`publish.yml` 的第一步会把 tag 与 `moon.mod` 的 `version` 比对（tag 允许带 `v` 前缀），
不一致就立刻失败，而不是把注册表那句难懂的报错丢回来。

## 4. 一次性配置

仓库 Settings → Secrets and variables → Actions → New repository secret：

- 名称 `MOONCAKES_TOKEN`
- 值：本机 `~/.moon/credentials.json` 的**完整内容**（一行 JSON），形如
  `{"token": "<你的 token>", "username": "q2316367743"}`

工作流运行时把该值写进 `~/.moon/credentials.json`，`moon publish` 完成后立即删除。

## 5. 注意事项

- 本地先跑一遍与 CI 相同的命令再推送，可省一次红叉：
  `moon check --deny-warn && moon build && moon test && moon info && moon fmt && git diff --exit-code`
- `.githooks/pre-commit` 只跑 `moon check`，覆盖面远小于 CI，别把它当 CI 的替代。
- `moon publish` 对版本号是「已存在即拒绝」，重复发布同一个版本会失败；发布前务必先
  递增 `moon.mod` 的 `version`。
- 本地可用 `moon publish --dry-run` 验证打包是否通过（不真正上传，服务端返回 202
  时命令以非零码退出属正常）。

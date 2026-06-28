结论：该任务宜按“Codex 基线稳定化 → 状态模型升级 → Claude 级多会话体验 → 发布工程化”四层推进。核心分界点是：先保留 [codex-status-bar](/Users/bytedance/app_development/codex-status-bar/reference/codex-status-bar/README.md:116) 已有的 Codex hook 适配，再逐步引入 [claude-status-bar](/Users/bytedance/app_development/codex-status-bar/reference/claude-status-bar/Sources/main.swift:197) 的 `state.d` 多会话架构。

## 关键差异
	
| 维度 | Codex 当前基线 | Claude 目标能力 | 规划含义 |
|---|---|---|---|
| 状态存储 | 单文件 `~/.codex/statusbar/state.json`，见 [main.swift](/Users/bytedance/app_development/codex-status-bar/reference/codex-status-bar/Sources/main.swift:30) | 每 session 一个文件 `state.d/<session>.json`，见 [main.swift](/Users/bytedance/app_development/codex-status-bar/reference/claude-status-bar/Sources/main.swift:197) | 第一重大改造是状态模型，而非 UI |
| 多会话 | 只跟随 active turn | 聚合所有 session，按 permission > working > idle 排序 | 应单独成期，避免和菜单改造混杂 |
| Hook writer | 已适配 Codex events 和 `~/.codex/hooks.json`，见 [install-codex-statusbar.js](/Users/bytedance/app_development/codex-status-bar/reference/codex-status-bar/scripts/install-codex-statusbar.js:18) | 有 lifecycle writer，负责 start/end 与自启动，见 [lifecycle.js](/Users/bytedance/app_development/codex-status-bar/reference/claude-status-bar/hooks/lifecycle.js:2) | Codex 应补 lifecycle，但保留 Codex 事件语义 |
| 菜单 | 主要是设置项、Reveal/Reset | 有 Sessions 区、行内 spinner、CLI/APP badge、hide idle | UI 升级应在多会话数据稳定后做 |
| Liveness | 依赖 stale timeout、quiet thinking timeout | 通过 `pid` 检测进程存活，见 [main.swift](/Users/bytedance/app_development/codex-status-bar/reference/claude-status-bar/Sources/main.swift:952) | 后续应从“时间推断”升级为“进程事实” |
| 安装/升级 | 手动运行 installer | 启动时按版本自修复 hooks，见 [main.swift](/Users/bytedance/app_development/codex-status-bar/reference/claude-status-bar/Sources/main.swift:313) | 发布前再做，避免早期复杂化 |
| 视觉能力 | Codex icon + Codex pets，见 [main.swift](/Users/bytedance/app_development/codex-status-bar/reference/codex-status-bar/Sources/main.swift:517) | 多动画风格、系统色适配更成熟 | Codex pets 是差异化优势，应保留 |
| 打包 | arm64、本地 ad-hoc 签名 | universal binary、DMG、签名/公证、更新检查 | 属于最后工程化阶段 |

## 分期规划

## 第 0 期：基线整理与可运行骨架

目标是把 `reference/codex-status-bar` 变成项目主体，而不是继续在 `reference/` 中实验。

- [ ] 复制 Codex 基线到正式源码目录，例如 `Sources/`、`scripts/`、`assets/`、`build.sh`。
- [ ] 保留 Codex 专属路径：`~/.codex/hooks.json`、`~/.codex/statusbar/`、`~/.codex/pets`。
- [ ] 调整 bundle id、应用名、README、LICENSE attribution，避免 Claude 残留命名。
- [ ] 跑通 `./build.sh`、`open -g build/CodexStatusBar.app`、`node scripts/dev-state.js demo`。
- [ ] 明确 MVP 验收：状态栏能显示 idle、thinking、tool、permission、done。

## 第 1 期：Codex Hook 可靠性

目标是先把单会话状态做准，避免过早进入多会话复杂度。

- [ ] 梳理 Codex hook event matrix：`SessionStart`、`UserPromptSubmit`、`PreToolUse`、`PostToolUse`、`PermissionRequest`、`Stop`、`SubagentStart`、`SubagentStop`。
- [ ] 强化 [codex-status-writer.js](/Users/bytedance/app_development/codex-status-bar/reference/codex-status-bar/scripts/codex-status-writer.js:152) 中 `session_id` / `turn_id` 防串扰逻辑。
- [ ] 补齐调试日志开关，保留 payload keys/type，不记录 prompt、命令输出和敏感字段。
- [ ] 完善 permission 最小可见时间、tool 最小可见时间、quiet thinking 自动恢复。
- [ ] 增加本地 hook replay 脚本，用固定 JSON fixtures 回放典型事件序列。
- [ ] 验证 Codex CLI 与 Codex Desktop 的事件差异，形成 `docs/hook-events.md`。

## 第 2 期：状态模型升级为多会话

目标是从单一 `state.json` 迁移到 Claude 式 `state.d`，但语义仍保持 Codex 化。

- [ ] 将 writer 输出从 `state.json` 改为 `~/.codex/statusbar/state.d/<session_id>.json`。
- [ ] 每个 session 文件包含 `state`、`label`、`tool`、`project`、`sessionId`、`turnId`、`pid`、`entrypoint`、`started`、`startedAt`、`ts`。
- [ ] 添加 Codex 版 lifecycle writer：`SessionStart` 创建 idle session，`SessionEnd` 删除对应 session。
- [ ] 兼容旧 `state.json`：迁移期可读取旧文件，但新写入只使用 `state.d`。
- [ ] Swift 端将 `current` 单状态替换为 `sessions: [String: Session]`，参考 [reloadSessions](/Users/bytedance/app_development/codex-status-bar/reference/claude-status-bar/Sources/main.swift:843)。
- [ ] 实现 lead session 选择规则：permission 优先，其次 tool/thinking，其次最近活跃 idle。
- [ ] 验证同时运行两个 CLI session、一个 Desktop session 时状态栏不被旧事件覆盖。

## 第 3 期：Sessions 下拉菜单

目标是接近 Claude 版核心体验：状态栏显示最高优先级，菜单列出所有活跃 session。

- [ ] 增加菜单区块：`Sessions`、`Options`、`Icon`、`Diagnostics`。
- [ ] 为每个 session 增加自定义行：项目名、状态图标、计时器、CLI/APP badge。
- [ ] 移植或改写 Claude 的 `SessionRowView`，但文案与 badge 改为 Codex 语义。
- [ ] 增加 hide idle sessions 设置：5 分钟、15 分钟、30 分钟、1 小时、Never。
- [ ] 增加点击聚焦：Desktop session 打开 Codex app；CLI session 根据 `TERM_PROGRAM` 聚焦 Terminal/iTerm/Warp/VS Code。
- [ ] 对多会话菜单进行长项目名、浅色/深色菜单、hover 高亮、计时器刷新验证。

## 第 4 期：生命周期与自修复

目标是使应用像 Claude 版一样“无需用户长期管理”。

- [ ] 启动时检测当前版本，版本变化时自动重装 hooks。
- [ ] 移植 Node 定位逻辑，覆盖 Homebrew、Volta、asdf、nvm、系统 Node。
- [ ] 实现自退出：无 Codex Desktop 进程且无 live session 后延迟退出。
- [ ] 实现进程级 liveness：优先用 `pid` 判断 session 是否仍存在，减少 stale timeout 误判。
- [ ] 增加 crash/force quit 恢复：应用启动时清理明显过期或无主 session。
- [ ] 安装/卸载脚本只移除自身 hook marker，不影响用户其他 Codex hooks。

## 第 5 期：Codex 视觉与交互完善

目标是形成 Codex 自有体验，而非 Claude 版换皮。

- [ ] 保留 Codex icon 与 Codex Pets 两种 icon style。
- [ ] 将状态图标体系标准化：thinking/tool 动画、permission 黄点、idle resting icon。
- [ ] 区分 notification sounds：permission 与 completion，completion 可设置 1 分钟阈值。
- [ ] 增加菜单中的当前版本、状态文件目录、打开日志、重置所有状态。
- [ ] 优化系统色与彩色模式，确保浅色/深色菜单栏均可读。
- [ ] 避免引入 Claude 的品牌动画、Anthropic 色彩和非 Codex 命名。

## 第 6 期：发布工程化

目标是把本地工具提升为可分发的 macOS app。

- [ ] 将 `build.sh` 升级为 universal binary：`arm64 + x86_64`。
- [ ] 固定 macOS deployment target 为 12.0。
- [ ] 增加 DMG 布局、Applications symlink、资源清理。
- [ ] 增加 Developer ID 签名与 notarization 可选流程。
- [ ] 增加 GitHub release update check；若暂不发布，可先关闭网络检查。
- [ ] 补齐 `PRIVACY.md`、`TROUBLESHOOTING.md`、`CHANGELOG.md`、`CONTRIBUTING.md`。
- [ ] 验证全新安装、覆盖更新、卸载、无 Node、无 Codex app、仅 CLI、仅 Desktop 等场景。

## 第 7 期：回归测试与长期维护

目标是防止 hook 事件和 Codex 版本变化导致状态栏失真。

- [ ] 建立 fixtures：单会话、双 CLI、CLI + Desktop、permission denied、tool timeout、subagent stop。
- [ ] 增加 writer 级 Node 测试，验证事件到 session JSON 的状态转移。
- [ ] 增加 Swift 手工/脚本验证：读取 `state.d`、菜单刷新、lead session 优先级。
- [ ] 增加诊断命令：打印 hooks 安装状态、state.d 内容摘要、Node 路径、Codex app 检测结果。
- [ ] 每次 Codex hook schema 变化时，先更新 fixtures，再改 writer。

## 建议执行顺序

最优顺序是：第 0 期 → 第 1 期 → 第 2 期 → 第 3 期。  
这四期完成后，项目已经具备“Codex 版 Claude Status Bar”的主要价值。第 4 至第 7 期属于产品化、分发和长期稳定性建设，可在核心体验稳定后推进。
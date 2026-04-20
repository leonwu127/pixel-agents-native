# Pixel Agents Lua — Backlog

本地 backlog，用于跟踪推迟到 MVP 之后的工作项。GH Issue 化：每条日后可直接粘贴成 GitHub Issue。

---

## [UPGRADE] 接入 Claude Code Hooks API，替代/补充 JSONL 轮询

**状态**：Planned（MVP 阶段不实现）
**优先级**：P2（MVP 交付并稳定后再启动）
**创建**：2026-04-20

### 背景

MVP 选用纯文件轮询（heuristic mode）作为 agent 活动输入源——Love2D 每 ~500ms 扫描 `~/.claude/projects/<hash>/<session>.jsonl` 的新行，解析 JSON 记录推导出工具调用、turn 结束等事件。

优点：零依赖、不修改用户 Claude 配置、开箱即用。适合 MVP。

缺点：
- 延迟 200–500ms
- 需要自行处理 `/clear`、session 切换、partial line buffering
- `turn_duration` 只在有工具使用的 turn 触发，纯文本 turn 要靠 text-idle 超时兜底（原项目 `TEXT_IDLE_DELAY_MS = 5s`）

### 提议

实现 hooks 模式作为优选路径，轮询退为 fallback（原项目 dual-mode 架构）：

1. **本地 HTTP server**：Love2D 启动时监听一个本地端口。技术选型待定：
   - `luasocket` + 手写 HTTP 解析（简单，但要自己处理 keep-alive / 多路复用）
   - `copas` 协程 HTTP server（更完整）
   - 或者**起一个独立 Node/Go 子进程**做 HTTP server，通过 stdin/stdout 或 unix socket 和 Love2D 通信（和原项目 `server/` 类似）——Love2D 本身不擅长网络
2. **Hook 注册**：首次运行时把 hook 脚本写到 `~/.claude/settings.json`（参考原项目 `claudeHookInstaller.ts`）
3. **Server discovery**：写 `~/.pixel-agents-lua/server.json`（端口 + PID + auth token），hook 脚本读取后 POST 事件
4. **Dual-mode 切换**：每个 agent 有 `hookDelivered` flag，收到 hook 事件后该 agent 的轮询就只用于工具内容跟踪，不再用于 idle/permission 计时

### 涉及的原项目参考代码

- `server/src/server.ts` — HTTP server 骨架
- `server/src/hookEventHandler.ts` — 事件路由与缓冲
- `server/src/providers/hook/claude/claudeHookInstaller.ts` — settings.json 写入
- `server/src/providers/hook/claude/hooks/claude-hook.ts` — hook 脚本
- `src/fileWatcher.ts` — heuristic mode 和 dual-mode 切换逻辑

### 验收

- [ ] Claude Code 工具调用到画面反应延迟 < 100ms（现在是 200–500ms）
- [ ] `/clear` 检测由 hook 驱动，不再依赖 JSONL 内容扫描
- [ ] Permission 气泡在真实的 7s 超时下稳定出现/消失
- [ ] hook 未安装时自动退回轮询模式，不崩
- [ ] 退出 Love2D 时清理 server.json、不残留 hook 进程

### 风险

- Love2D 生态里做 HTTP server 不顺手；可能需要拉一个外部 sidecar 进程，复杂度变高
- 修改用户 `~/.claude/settings.json` 需要明确知情同意的 UI 流程

---

## [LEGAL] 分发前审核角色素材授权

**状态**：Open（公开分发前必须完成）
**优先级**：P1（仅限私下使用时可忽略，分发/上传前必须解决）
**创建**：2026-04-20

### 背景

MVP 阶段直接借用原 `pixel-agents` 的 `webview-ui/public/assets/characters/char_0..5.png`。这 6 个角色 PNG **不受原项目 MIT 覆盖**，来自 [JIK-A-4 — Metro City Free Topdown Character Pack](https://jik-a-4.itch.io/metrocity-free-topdown-character-pack)。

家具 / 地板 / 墙瓦片 PNG 是原作者自制，MIT 覆盖，可复用（保留 copyright）。

### 要做的事

- [ ] 去 JIK-A-4 页面确认授权条款（免费 ≠ CC0；可能要求署名、禁止商用、禁止再分发等）
- [ ] 如果条款允许：在 README/CREDITS 里加署名
- [ ] 如果条款不允许任何形式的再分发：
  - 选项 A：替换成 CC0 的角色包（itch.io 搜 "CC0 topdown character"）
  - 选项 B：自己画
  - 选项 C：让用户自行下载，MVP 包里不内置角色 PNG（"BYO assets"）

### 触发点

任何以下动作前必须先过这一关：
- Push 到公开 fork
- 发 release / tag
- 打包成可分发的 `.love` / exe
- 截图发到社交媒体用于宣传

---

## [FEATURE] 后置功能清单（MVP 不做）

以下原项目有、MVP 明确不实现的功能，按粗粒度优先级排：

### P2 — 等 MVP 跑稳再考虑
- **子 agent 可视化**：Task 工具调用时父 agent 派生一只独立角色（原项目 `activeSubagentToolNames` + 负 ID 机制）
- **工具完成 tooltip**：悬停或选中角色时显示当前/最近工具状态文本
- **角色选中 + 换座位**：点击角色高亮，再点椅子重新分配
- **声音通知**：turn 完成两音上行钟声（原 `notificationSound.ts`）
- **多调色板角色**：6 套预上色 PNG + 超过 6 人时随机 hue shift
- **Matrix 数字雨 spawn/despawn 特效**：原 `matrixEffect.ts`

### P3 — 可能永远不做
- **内置布局编辑器**：用户用 JSON 手编或写个 CLI 工具转换就够了
- **外部 asset 目录 / 自定义家具包**：Love2D 可以走 `package.path`，但不是核心
- **跨窗口 layout 同步**：Love2D 单实例场景下没必要

所有 P2 项应在 MVP 架构中为将来扩展留好位，但不写实现。

---

## [PLATFORM] 跨平台支持（MVP 只覆盖 WSL2/Linux）

**状态**：Planned
**优先级**：P3

### MVP 支持范围

- **主要平台**：Linux（特别是 Windows 11 WSL2 + WSLg）
- **间接兼容**：macOS / 原生 Linux（Love2D 本身跨平台，但未测试）
- **明确不支持**：Windows 原生（JSONL 路径、shell 差异、打包流程都不同）

### 未来工作

- [ ] 测试并适配 macOS（Homebrew 装 love + 原生 Claude Code）
- [ ] 测试并适配 Windows 原生（JSONL 在 `%USERPROFILE%\.claude\projects\...`，路径分隔符处理）
- [ ] 打包成 `.love` 文件 + 平台特定启动器

### 影响

- 路径拼接：MVP 只处理 POSIX 风格，不加 Windows 分支
- 文件监听：只依赖 POSIX 语义（原子 rename、mtime），不处理 Windows 文件锁

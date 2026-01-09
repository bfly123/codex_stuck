# codex-status

<div align="center">

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Platform](https://img.shields.io/badge/platform-linux%20%7C%20macos%20%7C%20windows%20%7C%20wsl-lightgrey)
![Shell](https://img.shields.io/badge/shell-bash%20%7C%20zsh%20%7C%20powershell-green)
![License](https://img.shields.io/badge/license-MIT-orange)

**实时监控 Codex CLI 运行状态，在终端标题栏显示状态图标。**

[English](README.md) | **中文**

</div>

---

<div align="center">
  <img src="images/demo.png" alt="codex-status demo" width="800">
  <br>
  <em>(截图占位符)</em>
</div>

---

## 这个项目做什么
`codex-status` 用来跟踪 Codex CLI 的状态，并显示在：
- 终端标题/标签页（推荐：`codex-status-bg` + Shell Hook）
- 命令行输出（`codex-status --watch`）

为了可靠区分“等待输入 vs 等待输出”，项目还提供并安装了一组 wrapper，会把稳定的完成标记（`CODEX_DONE` / `CCB_DONE`）自动注入到 Codex 的提示词中。

## 核心思想（实现原理）
这是一个“尽力而为、零集成”的监控器：不依赖 Codex 官方 API，也不需要改 Codex 本体。

1) **让完成状态可被机器识别**：wrapper 注入规则，要求每次 assistant 回复最后一行输出 `CODEX_DONE`（或 `CCB_DONE`）。
2) **以 session 文件为准**：读取 `~/.codex/sessions/*.jsonl`，用时间戳判断：
   - 最新用户消息时间 vs 最新 done-tag 时间 → pending（等输出）或 free（等输入）
3) **用轻量进程信号做辅助**：
   - CPU/IO 增量、以及在可用平台上的进程状态，用来细分 Run/Think/Idle/Stuck
4) **把状态渲染到标题栏**：
   - 通用终端：写 OSC 标题控制序列
   - WezTerm：可用 `wezterm cli set-tab-title` / `set-window-title`

## 状态图标说明
| 图标 (Emoji) | 图标 (图形) | 状态 | 说明 |
| :---: | :---: | :--- | :--- |
| 🟢 | ▶ | Run（运行） | 正在输出/持续有进展。 |
| 🟡 | ▷ | Think（思考） | 仍在等待输出，但最近活动较少。 |
| 🟠 | ◇ | Idle（空转） | 仍在等待输出，长时间安静（未到卡死阈值）。 |
| 🔵 | □ | Free（空闲） | 等待你输入。 |
| 🔴 | ■ | Stuck（卡死） | 超长时间无活动（可配置阈值）。 |
| ⚫ | × | Exit（退出） | Codex 进程已退出。 |

## 安装方式

### Linux / WSL（推荐）/ macOS
前置条件：
- `python3`
- `bash` 或 `zsh`
- 已安装 `codex` 且在 `PATH` 中

安装：
```bash
./install.sh
```

启用自动 Hook（二选一）：
- Zsh：加到 `~/.zshrc`
  ```bash
  export PATH="$HOME/.local/bin/priority:$PATH"
  source "$HOME/.local/lib/codex-status/shell_hook.zsh"
  ```
- Bash：加到 `~/.bashrc`
  ```bash
  export PATH="$HOME/.local/bin/priority:$PATH"
  source "$HOME/.local/lib/codex-status/shell_hook.bash"
  ```

然后重开一个 shell（或 `source` 对应 rc 文件）。

### Windows（WezTerm + PowerShell）
原生 Windows + **WezTerm** 已支持：通过 `install.ps1` + `wezterm cli` 实现（不依赖 bash/zsh hook）。

前置条件：
- 已安装 WezTerm，且 `wezterm` 在 `PATH` 中（保证 `wezterm cli ...` 可用）
- 已安装 Python 3（可用 `py -3` 或 `python`）
- 已安装 `codex` 且在 `PATH` 中

安装（PowerShell）：
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install.ps1
```

PATH 配置（推荐）：
- 把下面路径加入用户 `PATH`：
  - `%USERPROFILE%\.local\bin\priority`
  - `%USERPROFILE%\.local\bin`
- 重启 WezTerm。

方案 A（不改 PATH）：
- 不想“自动包装 codex”的话，至少把 `%USERPROFILE%\.local\bin` 加到 `PATH`（或用完整路径调用 `.cmd`）。
- 直接用 `codex-status-wrapper` 启动 Codex 并更新标题：
  ```powershell
  codex-status-wrapper
  ```
  完整路径：
  ```powershell
  & "$env:USERPROFILE\.local\bin\codex-status-wrapper.cmd"
  ```

方案 B（推荐：自动包装 `codex`）：
- 确保 `%USERPROFILE%\.local\bin\priority` 在 `PATH` 中，使 `codex` 解析到 `codex.cmd` shim。
- 验证：
  ```powershell
  Get-Command codex
  Get-Command codex-status
  wezterm cli list
  ```
- 使用：
  ```powershell
  codex
  ```
  如果 `Get-Command codex` 仍然指向原始 `codex`，继续使用 `codex-status-wrapper`，或者在 `$PROFILE` 里把路径前置。

PowerShell Profile 小技巧（可选）：
- 仅当前会话：
  ```powershell
  $env:PATH = "$env:USERPROFILE\.local\bin\priority;$env:USERPROFILE\.local\bin;$env:PATH"
  ```
- 永久写入用户环境变量：
  ```powershell
  $u = [Environment]::GetEnvironmentVariable("Path","User")
  $p = "$env:USERPROFILE\.local\bin\priority;$env:USERPROFILE\.local\bin"
  [Environment]::SetEnvironmentVariable("Path", "$p;$u", "User")
  ```

## 使用方法
- Linux/WSL/macOS：配置了 `~/.local/bin/priority` 到 `PATH` 后直接用 `codex`；或显式使用 `codex-done`。
- Windows（WezTerm + PowerShell）：配置 `%USERPROFILE%\.local\bin\priority` 后直接用 `codex`；或使用 `codex-status-wrapper`。
- 手动查看：
  - `codex-status --watch --title`
  - `codex-status --watch --json`

## 配置项（环境变量）
Linux/macOS 在 `~/.zshrc` / `~/.bashrc`，Windows PowerShell 建议在 `$PROFILE` 或用 `[Environment]::SetEnvironmentVariable(...,"User")` 设置：
- `CODEX_STATUS_ICON_STYLE`: `shape`（默认）或 `emoji`
- `CODEX_STATUS_OSC`: `0`（默认）或 `2`（部分终端只更新 window title）
- `CODEX_STATUS_WEZTERM_MODE`: `auto`（默认）, `off`, `tab`, `window`, `window-active`
- `CODEX_STATUS_INTERVAL_S`: 采样间隔秒数（默认 `2`）
- `CODEX_STATUS_WAIT_S`: `codex-status-bg` 等待本 TTY 出现 Codex 的秒数（默认 `10`）
- `CODEX_STATUS_THINKING_S`: pending→Think 阈值（默认 `5`）
- `CODEX_STATUS_IDLE_S`: pending→Idle 阈值（默认 `30`）
- `CODEX_STATUS_MODEL_STUCK_S`: pending→Stuck 阈值（默认 `900`）
- `CODEX_STATUS_PENDING_REFRESH_S`: Session 解析刷新秒数（默认 `2`）

注：`CODEX_STATUS_WAIT_S` 只影响 `codex-status-bg`（Linux/WSL/macOS 的 shell hook 流程）。

## 文件说明（梳理）
- `install.sh`: 安装到 `~/.local/*`
- `install.ps1`: 安装到 `%USERPROFILE%\.local\*`（Windows WezTerm）
- `bin/codex-status`: 状态查看器（`--watch` / `--json` / `--detail` / `--title`）
- `bin/codex-status-bg`: 单 TTY 后台标题更新（Shell Hook 使用）
- `bin/codex-status-wrapper`: 启动 `codex` 并更新标题（可选）
- `bin/codex-done`: 启动 Codex 并注入 `CODEX_DONE`（推荐）
- `bin/codex-ccbdone`: 使用 `CCB_DONE` 的替代 wrapper
- `bin/codex-wrapper`: 安装为 `~/.local/bin/priority/codex`（透明注入）
- `lib/monitor.py`: 状态检测（进程 + session 文件）
- `lib/renderer.py`: 标题/输出渲染 + OSC 写入
- `lib/shell_hook.zsh`, `lib/shell_hook.bash`: 自动启动 `codex-status-bg`
- `config/*.txt`: 安装到 `~/.local/share/codex-status/` 的提示模板

## 卸载
Linux/macOS/WSL 删除：
- `~/.local/bin/codex-status*`, `~/.local/bin/codex-done`, `~/.local/bin/codex-ccbdone`
- `~/.local/bin/priority/codex`
- `~/.local/lib/codex-status/`
- `~/.local/share/codex-status/`
- `~/.cache/codex-status/`

Windows 删除：
- `%USERPROFILE%\.local\bin\codex-status*` 以及 `*.cmd`
- `%USERPROFILE%\.local\bin\priority\codex.cmd`
- `%USERPROFILE%\.local\lib\codex-status\`
- `%USERPROFILE%\.local\share\codex-status\`
- `%USERPROFILE%\.cache\codex-status\`


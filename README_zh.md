<div align="center">

# codex_stuck

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Platform](https://img.shields.io/badge/platform-Linux%20|%20macOS%20|%20Windows%20|%20WSL-lightgrey)
![License](https://img.shields.io/badge/license-MIT-green)

**检测 Codex 是在运行还是卡住了**

*你是不是经常遇到 Codex 长时间执行毫无响应，想杀掉但又害怕它还在默默执行？*

[English](README.md) | [中文](README_zh.md)

![demo](images/demo.gif)

</div>

---

## 核心思想

> **轻量级** Codex 终端状态显示插件

通过监测以下内容判断 Codex 是否卡死：
- Session 文件状态
- 流量变化
- 沉默时间

打造这款插件除了便于检测 Codex 状态外，也是为了 **[cca](https://github.com/bfly123/claude_code_autoflow)** 和 **[ccb](https://github.com/bfly123/claude_code_bridge)** 全自动运行制作的监测器。

### 方案

1. 注入完成标记 (`CODEX_DONE`) 到 Codex 提示词
2. 监控会话文件 (`~/.codex/sessions/*.jsonl`) 检测状态
3. 通过 OSC 序列在终端标题显示状态

---

## 状态图标

| 图标 | 状态 | 含义 |
|:---:|:---|:---|
| `▶` | **Run** | 正在输出 |
| `▷` | **Think** | 等待中，活动较少 |
| `◇` | **Idle** | 长时间安静 |
| `□` | **Free** | 等待输入 |
| `■` | **Stuck** | 超长等待 |
| `×` | **Exit** | 进程退出 |

---

## 安装

### Linux / macOS / WSL

```bash
./install.sh
```

> 自动配置 shell (zsh/bash)，安装后重启终端。

### Windows (PowerShell)

```powershell
.\install.ps1
```

> 自动配置 PATH，安装后重启终端。

---

## 使用

安装后直接运行：

```bash
codex
```

终端标题将 **实时显示状态**。

---

## 卸载

```bash
./uninstall.sh      # Linux/macOS/WSL
.\uninstall.ps1     # Windows
```

---

## 配置 (可选)

| 变量 | 默认值 | 说明 |
|:---|:---:|:---|
| `CODEX_STATUS_ICON_STYLE` | `shape` | `shape` 或 `emoji` |
| `CODEX_STATUS_INTERVAL_S` | `2` | 采样间隔 (秒) |
| `CODEX_STATUS_MODEL_STUCK_S` | `900` | 卡住阈值 (秒) |

---

<div align="center">

**相关项目**: [cca](https://github.com/bfly123/claude_code_autoflow) | [ccb](https://github.com/bfly123/claude_code_bridge)

</div>

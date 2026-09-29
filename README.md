# MacFix

MacFix 是一个原生 macOS 工具箱，用于处理常见的缓存、Quick Look、Homebrew、npm 代理和文本文件创建问题。项目包含 SwiftUI 桌面应用，以及可选的本地 Python Agent 服务。

## 功能

- **缓存清理**：清理用户缓存和日志，可选择是否清理 JetBrains / IDEA 缓存。
- **快速预览修复**：重置 Quick Look 缓存并重启访达。
- **Homebrew 代理**：通过本地代理测试连接、安装软件包。
- **npm 代理**：通过本地代理测试、安装、更新和检查全局 npm 包。
- **新建 txt**：在指定目录快速创建文本文件。
- **智能助手**：通过本地 FastAPI 服务连接 OpenAI 兼容接口，支持流式对话。

## 环境要求

- macOS 12 或更高版本
- Xcode Command Line Tools（提供 `swiftc`、`sips`、`iconutil`）
- 可选：Python 3.11 或 3.12，以及 [uv](https://docs.astral.sh/uv/)，用于运行智能助手后端

## 构建应用

在项目根目录执行：

```bash
bash rebuild.sh
```

脚本会编译 SwiftUI 应用、复制资源、生成图标，并在本机生成 `MacFix.app` 和 `MacFix.dmg`。这些文件属于本地构建产物，已被 `.gitignore` 忽略。

也可以只构建应用包：

```bash
cd MacFixApp
bash build.sh
```

构建结果位于 `MacFixApp/build/MacFix.app`。

## Agent 后端

首次运行前安装锁定依赖：

```bash
cd agent
uv sync --frozen
```

然后启动本地服务：

```bash
uv run python -m macfix_agent
```

服务监听 `127.0.0.1:8765`，提供 `/health` 和 `/chat` 接口。API Key 等配置只保存在本机的 `~/Library/Application Support/MacFix/agent/config.json`，不会写入仓库。

## 项目结构

```text
MacFix/
├── MacFixApp/       # SwiftUI 应用、脚本和资源
├── agent/           # Python Agent 服务
├── docs/            # 设计文档
├── rebuild.sh       # 完整构建脚本
└── README.md
```

## 安全说明

应用中的脚本会操作用户目录或调用 Homebrew、npm 等本机工具。运行前请确认目标目录和命令内容；Agent 服务仅绑定本机回环地址，不对局域网开放。

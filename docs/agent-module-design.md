# MacFix Agent 模块技术设计文档

> 分支：`feature/agent-module`
> 状态：草案 v1（待开发）
> 目标：在现有 SwiftUI 应用下方新增一个「Agent 对话框」，接入多厂商大模型（以 DeepSeek 为主），
> 通过 LangChain / LangGraph / RAG / MCP 构建一个能调用本机终端、解决 Mac 常见问题的智能助手。

---

## 1. 背景与目标

现有 `MacFix` 是一个原生 macOS SwiftUI 应用，主页以网格卡片展示固定的问题修复模块
（缓存清理、快速预览、Homebrew、npm 代理、新建 txt），每个模块背后是一个 bash 脚本。

本次新增「Agent」能力：**保持现有 UI 不变**，在主页下方增加一个对话框。用户用自然语言提问，
Agent 能：

1. 接入不同厂家模型（DeepSeek、OpenAI、Qwen、Kimi 等，OpenAI 兼容协议优先）；
2. 调用本机终端执行命令，诊断并解决 Mac 常见问题；
3. 具备文本知识库（RAG），后续扩充图片检索；
4. 可选接入 MCP 服务器扩展工具。

---

## 2. 总体架构

### 2.1 关键决策：Python 本地服务 + SwiftUI 前端

Agent 生态（LangChain / LangGraph / RAG / MCP）几乎都在 Python 侧。而宿主应用是 SwiftUI。
因此采用**前后端分离、通过本地 HTTP + SSE 通信**的架构：

```
┌────────────────────────────────────────────────────────────┐
│  MacFix.app (SwiftUI)                                       │
│  ┌────────────────────────────────────────────────────────┐│
│  │ HomeView                                                 ││
│  │  ├─ 模块网格（现有，保持不变）                            ││
│  │  └─ Agent 聊天面板（新增）                                ││
│  │       ├─ 用 URLSession 发 HTTP + 流式解析 SSE            ││
│  │       └─ 负责 Agent 服务的启动/停止生命周期               ││
│  └────────────────────────────────────────────────────────┘│
│            │ HTTP POST /chat  + SSE 流式响应                 │
│            ▼  127.0.0.1:8765                                │
│  ┌────────────────────────────────────────────────────────┐│
│  │ Python Agent 服务（uv 管理，FastAPI）                     ││
│  │  ├─ LLM Provider 抽象（DeepSeek 默认）                   ││
│  │  ├─ LangGraph Agent（工具调用循环 + 流式）               ││
│  │  │    ├─ ShellTool（调用本机终端，危险命令需确认）        ││
│  │  │    ├─ 内置工具（文件/系统/网络/软件）                  ││
│  │  │    ├─ RAG 检索工具（Phase 2/3）                       ││
│  │  │    └─ MCP 工具（Phase 3，langchain-mcp-adapters）     ││
│  │  └─ 会话持久化（SQLite / LangGraph checkpointer）        ││
│  └────────────────────────────────────────────────────────┘│
```

选 Python 本地服务而非纯 Swift 的原因：
- LangChain/LangGraph/MCP 无 Swift 一等支持，重写成本极高；
- 服务跑在 127.0.0.1 本地回环，无外部暴露，安全可控；
- 前后端可独立开发、独立测试。

选 **HTTP + SSE** 而非 stdio 子进程的原因：
- 流式 token 输出（SSE）实现简单、稳健，Swift 端 `URLSession.bytes(for:)` 原生支持；
- 便于后续独立调试（`curl` 直接测），也便于未来加多会话 / 多端。

---

## 3. 技术选型

| 层 | 选型 | 理由 |
|----|------|------|
| Python | 3.11（uv 管理，`uv sync`） | LangGraph/MCP 兼容性最好；uv 快速、可锁版本 |
| Web 服务 | FastAPI + uvicorn + sse-starlette | 异步、SSE 原生、文档自动生成 |
| LLM 接入 | `langchain-openai` 的 `ChatOpenAI`（`openai_api_base` 可定制） | 兼容 DeepSeek/Qwen/Kimi/OpenAI 全部 OpenAI 协议端点 |
| Agent 框架 | LangGraph（`StateGraph` 工具循环） | 状态机可控、易流式（`astream_events`）、易加 checkpointer |
| 向量库 | ChromaDB | 本地持久化、零运维 |
| Embedding | `sentence-transformers` + `BAAI/bge-small-zh-v1.5` | 本地离线、中文效果好、体积小（~100MB） |
| MCP | `langchain-mcp-adapters`（`MultiServerMCPClient`） | 官方适配，MCP server 工具可直接注入 LangGraph |
| 持久化 | SQLite（LangGraph `SqliteSaver`） | 本地、无额外服务 |
| 前端 | SwiftUI + `URLSession`（SSE） | 与现有代码同栈 |

### 3.1 模型供应商抽象

通过配置文件声明供应商，`ChatOpenAI` 用 `openai_api_base` + `openai_api_key` 指向对应端点，
做到「换一家只改配置，不改代码」：

- DeepSeek：`https://api.deepseek.com/v1`，模型 `deepseek-chat` / `deepseek-reasoner`
- 通义 Qwen（DashScope 兼容模式）：`https://dashscope.aliyuncs.com/compatible-mode/v1`
- Moonshot Kimi：`https://api.moonshot.cn/v1`
- OpenAI：`https://api.openai.com/v1`

默认供应商为 **DeepSeek**。

---

## 4. 目录结构（新增部分）

```
repo/
├── MacFixApp/
│   └── Sources/
│       ├── App.swift              # 现有
│       ├── Support.swift          # 现有
│       └── Agent/
│           ├── AgentServer.swift  # Agent 服务生命周期（启动/停止 Python 进程）
│           ├── AgentClient.swift  # HTTP + SSE 客户端
│           ├── AgentChatView.swift# 聊天面板（SSE 流式渲染）
│           └── AgentModels.swift  # 消息/请求响应模型
├── agent/                          # Python 后端（新增）
│   ├── pyproject.toml
│   ├── .python-version             # 3.11
│   ├── uv.lock
│   ├── macfix_agent/
│   │   ├── __init__.py
│   │   ├── __main__.py             # uvicorn 入口
│   │   ├── server.py               # FastAPI + /chat SSE
│   │   ├── config.py               # 配置加载/写入
│   │   ├── llm.py                  # 供应商抽象
│   │   ├── graph.py                # LangGraph agent
│   │   └── tools/
│   │       ├── __init__.py
│   │       ├── shell.py            # 终端工具（核心）
│   │       ├── system.py           # 系统信息/进程/磁盘
│   │       ├── network.py          # 网络诊断
│   │       └── software.py         # brew/npm 等
│   ├── rag/                        # Phase 2（文本 RAG）
│   └── knowledge/                  # 知识库文档（Markdown）
└── docs/
    └── agent-module-design.md      # 本文档
```

配置与数据目录（运行时生成，非仓库）：
`~/Library/Application Support/MacFix/agent/config.json`、`chat.db`、`chroma/`。

---

## 5. 配置与数据设计

### 5.1 config.json

```json
{
  "provider": "deepseek",
  "providers": {
    "deepseek": {
      "base_url": "https://api.deepseek.com/v1",
      "api_key": "",
      "model": "deepseek-chat"
    }
  },
  "agent": {
    "max_iterations": 12,
    "allow_shell": true,
    "dangerous_command_policy": "confirm"
  },
  "mcp_servers": []
}
```

`api_key` 也可在 App 界面里设置（settings），写入同一文件。

### 5.2 会话持久化

- 会话：LangGraph `SqliteSaver` → `chat.db`，保存多轮上下文与 checkpoints；
- 消息模型：LangChain 标准消息（`HumanMessage` / `AIMessage` / `ToolMessage`）。

---

## 6. 模块详细设计

### 6.1 后端服务

`POST /chat` 请求体：

```json
{ "session_id": "uuid", "message": "帮我释放磁盘空间" }
```

响应：`text/event-stream`，事件类型：

- `meta`：会话元信息
- `token`：LLM 增量文本
- `tool_start` / `tool_end`：工具调用开始/结束（含命令、结果摘要）
- `done`：结束，附最终消息
- `error`：错误

流式实现用 `graph.astream_events(..., version="v2")` 逐 token/逐工具事件转发。

### 6.2 LangGraph Agent 图

```
START → agent(LLM 决定工具) → [有工具调用] → tools(执行) → agent → ... → END
```

- 当 LLM 不再返回工具调用时结束；
- `max_iterations` 限制循环，防死循环。

### 6.3 ShellTool（核心：调用本机终端）

- 封装 `subprocess` 执行 bash，捕获 stdout/stderr/退出码；
- 命令**危险分级**：`rm -rf /`、`dd`、`diskutil erase`、`sudo`、`reboot`、`shutdown` 等
  锁定为「危险」类，默认策略 `confirm`（由前端弹确认框，拿到授权后才执行）；
- 只读命令（`df`、`ps`、`top`、`networksetup -getinfo`、`brew info`…）直接执行；
- 超时 + 输出长度截断，防止挂死/刷屏。

### 6.4 RAG（Phase 2：文本知识库）

- 知识库：Mac 常见问题 Markdown 文档（放 `agent/knowledge/`）；
- 入库：切块 → bge-small-zh 向量化 → ChromaDB；
- 检索：查询向量化 → top-k 召回 → 作为上下文注入 Agent；
- 后续（Phase 3）图片：用 CLIP 视觉 embedding 对截图/图标建索引，支持以图搜图。

### 6.5 MCP（Phase 3）

- `MultiServerMCPClient` 加载 `mcp_servers` 中配置的服务器（如 filesystem、terminal 等）；
- 将远端工具并入 LangGraph 的 tools 列表，与本地工具统一调度。

---

## 7. 分阶段实施计划

| 阶段 | 内容 | 验收标准 |
|------|------|----------|
| **Phase 0** | 后端骨架 + 前端聊天面板 + DeepSeek 纯对话（无工具） | 能流式对话、多轮上下文正确 |
| **Phase 1** | LangGraph Agent + ShellTool + 终端确认机制 | 能回答并真实执行终端命令 |
| **Phase 2** | 文本 RAG 知识库 | 回答能引用知识库内容 |
| **Phase 3** | 图片 RAG + MCP + 多供应商切换 UI | 以图搜图、接入 MCP、界面可选模型 |

当前进入 **Phase 0**。

---

## 8. 安全与风险

| 风险 | 对策 |
|------|------|
| Agent 执行危险命令 | ShellTool 危险命令分级 + 前端确认 + `dangerous_command_policy` 配置 |
| API Key 泄露 | Key 只存本地 config.json，不上传 git（`.gitignore`）；日志脱敏 |
| Python 服务崩溃/残留 | Swift 端进程生命周期管理，退出时 kill；固定回环端口 |
| 模型幻觉导致错误操作 | 提示词强制「先诊断再执行」；命令清单化并回显给用户 |
| 依赖体积/离线 | 用 uv 锁版本；embedding 模型本地缓存一次 |

---

## 9. 权限规划（预计的系统授权）

本应用**未开启 App Sandbox**（ad-hoc 签名、无 entitlements），主体不受沙盒限制，文件访问由系统 TCC 控制。
预计只会出现以下**一次性**弹窗：

| 权限 | 触发场景 | 频率 |
|------|----------|------|
| 「桌面」文件夹访问 | 「新建 txt 在桌面」首次向 `~/Desktop` 写入 | 仅首次 1 次 |
| 「文稿」/「下载」文件夹访问 | 用户在「新建文本文件」里选择这些目录保存 | 仅在主动选择时触发 |
| 防火墙「允许接入网络」 | 本机 Agent 服务 / brew / npm 联网 | 视防火墙设置，最多 1 次 |

**不需要**的权限：完全磁盘访问（不读写受其保护的目录）、辅助功能、自动化（Apple Events）、麦克风/摄像头。

结论：每个 TCC 权限授权一次后 macOS 会永久记住，**不会反复弹窗**。唯一可能重复弹的是
「新建文本文件」在权限不足时的管理员密码框（`osascript with administrator privileges` 兜底），默认写桌面不会触发。

Gatekeeper 提示：本地 ad-hoc 签名、未公证，若经网络分发（携带 quarantine 属性）会触发「无法验证开发者」，
需右键打开或移除隔离属性；本地构建运行不受影响。

---

## 10. 依赖清单（Python，Phase 0/1 所需）

```text
fastapi
uvicorn[standard]
sse-starlette
langchain-core
langchain-openai
langgraph
langgraph-checkpoint-sqlite
pydantic
pydantic-settings
```

Phase 2 追加：`chromadb`、`sentence-transformers`
Phase 3 追加：`langchain-mcp-adapters`、`mcp`
# MacFix

macOS 常用问题修复工具，双击即可使用。

## 功能模块

- **缓存清理**：删除 `~/Library/Caches`（应用缓存）和 `~/Library/Logs`（应用日志）下的内容，释放磁盘空间。默认**保留 JetBrains / IDEA 缓存**（避免删除后 IDEA 数据库缓存出现 "Storage corrupted" 报错），可在界面中勾选「同时清理 JetBrains 缓存」一并清理并查看其所占空间。不碰系统目录和系统快照，被运行中应用占用的文件会自动跳过。

- **快速预览**：针对 Quick Look 预览「罢工」（选中文件按空格无法预览、预览内容错乱）时的解决办法，重置 Quick Look 缓存并重启访达。

- **Homebrew**：输入代理端口号（默认 7892），通过本地代理加速 Homebrew 软件包的测试连接与安装。

- **npm 代理**：输入代理端口号（默认 7892），通过本地代理加速全局 npm 包的安装、更新与下载。

- **新建txt在桌面**：macOS 右键菜单没有新建 txt 文档的功能，此模块默认在桌面快速创建 txt 文档。

## 使用

将 `MacFix.app` 复制到 `~/Applications` 或 `/Applications`，即可在启动台（Launchpad）中直接打开。

## 构建

在 `MacFixApp` 目录下运行：

```bash
bash build.sh
```

即可重新编译并生成 `MacFix.app`。

# MacFix

macOS 常用问题修复工具，双击即可使用。

整合四个模块：

- **缓存清理**：清理用户缓存与日志，释放磁盘空间
- **快速预览**：重置 Quick Look 缓存并重启访达
- **Homebrew**：通过代理测试连接并安装软件包（端口可配置）
- **npm 代理**：通过代理管理全局 npm 包（端口可配置）

## 使用

将 `MacFix.app` 复制到 `~/Applications` 或 `/Applications`，即可在启动台（Launchpad）中直接打开。

## 构建

在 `MacFixApp` 目录下运行：

```bash
bash build.sh
```

即可重新编译并生成 `MacFix.app`。

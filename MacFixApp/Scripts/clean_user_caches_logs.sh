#!/bin/bash

set -u

CACHE_DIR="$HOME/Library/Caches"
LOG_DIR="$HOME/Library/Logs"

# 传入 --yes 时跳过确认（供 App 按钮调用）
# 传入 --include-jetbrains 时，一并清理 JetBrains（IDEA）缓存；默认保留
SKIP_CONFIRM=0
INCLUDE_JETBRAINS=0
for arg in "$@"; do
    case "$arg" in
        --yes) SKIP_CONFIRM=1 ;;
        --include-jetbrains) INCLUDE_JETBRAINS=1 ;;
    esac
done

echo "即将清理："
echo "  $CACHE_DIR"
echo "  $LOG_DIR"
if [[ "$INCLUDE_JETBRAINS" -eq 1 ]]; then
    echo "  （含 JetBrains/IDEA 缓存）"
else
    echo "  （保留 JetBrains/IDEA 缓存）"
fi
echo "待清理内容大小："
du -sh "$CACHE_DIR" "$LOG_DIR" 2>/dev/null || true
echo "不会处理系统目录、系统快照；JetBrains 缓存默认保留。"

if [[ "$SKIP_CONFIRM" -eq 0 ]]; then
    while true; do
        printf "是否执行清理？请输入 yes 或 no："
        if ! read -r confirmation; then
            echo
            echo "未读取到选择，已取消。"
            exit 0
        fi

        case "$confirmation" in
            yes|YES|Yes|y|Y)
                break
                ;;
            no|NO|No|n|N)
                echo "已取消。"
                exit 0
                ;;
            *)
                echo "输入无效，请输入 yes 或 no。"
                ;;
        esac
    done
fi

for target in "$CACHE_DIR" "$LOG_DIR"; do
    if [[ -d "$target" ]]; then
        if [[ "$target" == "$CACHE_DIR" && "$INCLUDE_JETBRAINS" -eq 0 ]]; then
            find "$target" -mindepth 1 -maxdepth 1 ! -name "JetBrains" -exec rm -rf {} + 2>&1 || true
            echo "已清理：$target（已保留 JetBrains 缓存）"
        else
            find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>&1 || true
            echo "已清理：$target"
        fi
    else
        echo "目录不存在，跳过：$target"
    fi
done

echo "清理完成。受 macOS 或正在运行的应用保护的项目可能无法删除。"
du -sh "$CACHE_DIR" "$LOG_DIR" 2>/dev/null || true

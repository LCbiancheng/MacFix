#!/bin/bash

# 扩展 PATH：从启动台双击启动时，进程不包含用户 shell 配置里的路径，
# 这里补充常见 Node.js / Homebrew 安装位置，确保能找到 npm
for d in \
    "$HOME/.nvm/versions/node"/*/bin \
    "$HOME/n/bin" \
    "$HOME/.volta/bin" \
    "$HOME/.local/bin" \
    /opt/homebrew/bin \
    /usr/local/bin; do
    if [ -d "$d" ]; then
        PATH="$d:$PATH"
    fi
done
export PATH

# ================= 配置区域 =================
# 请确保你的代理软件已开启，且端口与下方一致
PROXY_HOST="127.0.0.1"
# 端口可通过环境变量覆盖，默认 7892
HTTP_PORT="${HTTP_PORT:-7892}"
SOCKS_PORT="${SOCKS_PORT:-7892}"

DEFAULT_PACKAGE="@openai/codex"
TEST_URL="https://registry.npmjs.org/"
# ===========================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

HTTP_PROXY_URL="http://${PROXY_HOST}:${HTTP_PORT}"
SOCKS_PROXY_URL="socks5://${PROXY_HOST}:${SOCKS_PORT}"

show_help() {
    echo -e "${BLUE}用法:${NC}"
    echo "  bash npm_proxy_manager.sh test"
    echo "  bash npm_proxy_manager.sh install [包名]"
    echo "  bash npm_proxy_manager.sh update [包名]"
    echo "  bash npm_proxy_manager.sh reinstall [包名]"
    echo "  bash npm_proxy_manager.sh check [包名]"
    echo "  bash npm_proxy_manager.sh version [包名]"
    echo ""
    echo "默认包名: ${DEFAULT_PACKAGE}"
    echo ""
    echo "示例："
    echo "  bash npm_proxy_manager.sh install"
    echo "  bash npm_proxy_manager.sh install typescript"
}

run_with_proxy() {
    HTTP_PROXY="${HTTP_PROXY_URL}" \
    HTTPS_PROXY="${HTTP_PROXY_URL}" \
    http_proxy="${HTTP_PROXY_URL}" \
    https_proxy="${HTTP_PROXY_URL}" \
    ALL_PROXY="${SOCKS_PROXY_URL}" \
    all_proxy="${SOCKS_PROXY_URL}" \
    NO_PROXY="localhost,127.0.0.1,::1" \
    no_proxy="localhost,127.0.0.1,::1" \
    "$@"
}

test_proxy() {
    echo -e "${YELLOW}>>> 正在测试代理到 npm 仓库的连接...${NC}"
    if run_with_proxy curl -I -s --connect-timeout 8 "${TEST_URL}" >/dev/null; then
        echo -e "${GREEN}OK: 代理可用，npm 网络访问正常${NC}"
    else
        echo -e "${RED}FAIL: 代理不可用${NC}"
        echo "请检查代理软件是否开启，或端口是否为 ${HTTP_PORT}"
        exit 1
    fi
}

check_npm() {
    if ! command -v npm >/dev/null 2>&1; then
        echo -e "${RED}FAIL: 未检测到 npm，请先安装 Node.js${NC}"
        exit 1
    fi
}

check_package() {
    PACKAGE_NAME="${1:-$DEFAULT_PACKAGE}"
    echo -e "${YELLOW}>>> 检查全局包是否已安装: ${PACKAGE_NAME}${NC}"
    npm list -g --depth=0 "${PACKAGE_NAME}"
}

show_version() {
    PACKAGE_NAME="${1:-$DEFAULT_PACKAGE}"
    echo -e "${YELLOW}>>> 查看包信息: ${PACKAGE_NAME}${NC}"
    echo -e "${BLUE}已安装版本：${NC}"
    npm list -g --depth=0 "${PACKAGE_NAME}" 2>/dev/null || true
    echo -e "${BLUE}仓库最新版本：${NC}"
    run_with_proxy npm view "${PACKAGE_NAME}" version
}

install_package() {
    PACKAGE_NAME="${1:-$DEFAULT_PACKAGE}"
    echo -e "${YELLOW}>>> 开始安装全局 npm 包: ${PACKAGE_NAME}${NC}"
    run_with_proxy npm install -g "${PACKAGE_NAME}"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}OK: 安装成功: ${PACKAGE_NAME}${NC}"
    else
        echo -e "${RED}FAIL: 安装失败${NC}"
        exit 1
    fi
}

update_package() {
    PACKAGE_NAME="${1:-$DEFAULT_PACKAGE}"
    echo -e "${YELLOW}>>> 开始更新全局 npm 包: ${PACKAGE_NAME}${NC}"
    run_with_proxy npm install -g "${PACKAGE_NAME}@latest"
}

reinstall_package() {
    PACKAGE_NAME="${1:-$DEFAULT_PACKAGE}"
    echo -e "${YELLOW}>>> 重新安装全局 npm 包: ${PACKAGE_NAME}${NC}"
    run_with_proxy npm uninstall -g "${PACKAGE_NAME}"
    run_with_proxy npm install -g "${PACKAGE_NAME}@latest"
}

main() {
    ACTION="$1"
    PACKAGE_NAME="$2"
    check_npm

    case "$ACTION" in
        test)      test_proxy ;;
        install)   test_proxy; install_package "$PACKAGE_NAME" ;;
        update)    test_proxy; update_package "$PACKAGE_NAME" ;;
        reinstall) test_proxy; reinstall_package "$PACKAGE_NAME" ;;
        check)     check_package "$PACKAGE_NAME" ;;
        version)   test_proxy; show_version "$PACKAGE_NAME" ;;
        *)         show_help ;;
    esac
}

main "$@"

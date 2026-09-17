#!/bin/bash
set -euo pipefail

# 扩展 PATH：从启动台双击启动时，进程不包含用户 shell 配置里的路径，
# 这里补充常见 Homebrew 安装位置，确保能找到 brew
for d in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin"; do
    if [ -d "$d" ]; then
        PATH="$d:$PATH"
    fi
done
export PATH

# 通用 Homebrew 代理管理脚本
# 用法:
#   bash brew_proxy_manager.sh test
#   bash brew_proxy_manager.sh install <formula...>
#   bash brew_proxy_manager.sh install-prefix <prefix>

PROXY_HOST="127.0.0.1"
# 端口可通过环境变量覆盖，默认 7892
HTTP_PORT="${HTTP_PORT:-7892}"
SOCKS_PORT="${SOCKS_PORT:-7892}"

TEST_URL="https://formulae.brew.sh/"
FORMULA_API="https://formulae.brew.sh/api/formula.json"

HTTP_PROXY_URL="http://${PROXY_HOST}:${HTTP_PORT}"
SOCKS_PROXY_URL="socks5://${PROXY_HOST}:${SOCKS_PORT}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

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
    echo -e "${YELLOW}>>> 正在测试代理到 Homebrew 仓库的连接...${NC}"
    if run_with_proxy curl -I -s --connect-timeout 8 "${TEST_URL}" >/dev/null; then
        echo -e "${GREEN}OK: 代理可用，Homebrew 网络访问正常${NC}"
    else
        echo -e "${RED}FAIL: 代理不可用${NC}"
        echo "请检查代理软件是否开启，或端口是否为 ${HTTP_PORT}"
        exit 1
    fi
}

check_brew() {
    if ! command -v brew >/dev/null 2>&1; then
        echo -e "${RED}FAIL: 未检测到 Homebrew${NC}"
        echo "请先安装 Homebrew: https://brew.sh"
        exit 1
    fi
}

install_formulae() {
    if [[ $# -eq 0 ]]; then
        echo -e "${RED}未指定要安装的包名${NC}"
        exit 1
    fi
    local f
    for f in "$@"; do
        echo -e "${YELLOW}>>> 安装: ${f}${NC}"
        run_with_proxy brew install "${f}"
    done
    echo -e "${GREEN}安装流程结束${NC}"
}

install_prefix() {
    local prefix="${1:-}"
    if [[ -z "${prefix}" ]]; then
        echo -e "${RED}未指定前缀${NC}"
        exit 1
    fi
    echo -e "${YELLOW}>>> 搜索以 '${prefix}' 开头的 formulae...${NC}"
    local matches
    matches="$(run_with_proxy curl -s "${FORMULA_API}" | grep -oE "\"name\":\"${prefix}[^\"]*\"" | sed 's/"name":"//; s/"$//' | sort -u)"
    if [[ -z "${matches}" ]]; then
        echo "未找到以 '${prefix}' 开头的 formulae"
        return 0
    fi
    echo "找到以下 formulae："
    echo "${matches}"
    echo ""
    echo -e "${YELLOW}>>> 开始安装...${NC}"
    local name
    while IFS= read -r name; do
        run_with_proxy brew install "${name}" || echo -e "${RED}安装失败: ${name}${NC}"
    done <<< "${matches}"
    echo -e "${GREEN}安装流程结束${NC}"
}

main() {
    local action="${1:-}"
    case "${action}" in
        test) test_proxy ;;
        install) shift; check_brew; install_formulae "$@" ;;
        install-prefix) shift; check_brew; install_prefix "${1:-}" ;;
        *)
            echo "用法:"
            echo "  bash brew_proxy_manager.sh test"
            echo "  bash brew_proxy_manager.sh install <formula...>"
            echo "  bash brew_proxy_manager.sh install-prefix <prefix>"
            ;;
    esac
}

main "$@"

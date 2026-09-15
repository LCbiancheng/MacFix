#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BREW_MANAGER="${SCRIPT_DIR}/brew_proxy_manager.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_help() {
    echo -e "${BLUE}Brew Proxy Manager — Install Script${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "  bash install.sh              # Install default formulae starting with 'p'"
    echo "  bash install.sh -p <prefix>  # Install default formulae matching prefix"
    echo "  bash install.sh <formula...> # Install specific formulae"
    echo "  bash install.sh -t           # Test proxy only"
    echo "  bash install.sh -h           # Show this help"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  bash install.sh"
    echo "  bash install.sh -p p"
    echo "  bash install.sh poppler python"
}

# --------------------------------------------------
# Main
# --------------------------------------------------

if [ ! -f "${BREW_MANAGER}" ]; then
    echo -e "${RED}Error: brew_proxy_manager.sh not found at ${BREW_MANAGER}${NC}" >&2
    exit 1
fi

if [ ! -x "${BREW_MANAGER}" ]; then
    echo -e "${YELLOW}Making brew_proxy_manager.sh executable...${NC}"
    chmod +x "${BREW_MANAGER}"
fi

# Check if Homebrew is available
if ! command -v brew >/dev/null 2>&1; then
    echo -e "${RED}Homebrew is not installed. Please install Homebrew first.${NC}" >&2
    exit 1
fi

action=""
prefix=""
packages=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--test)
            action="test"
            shift
            ;;
        -p|--prefix)
            if [[ -z "${2:-}" || "${2:0:1}" == "-" ]]; then
                echo -e "${RED}Error: -p requires a prefix value${NC}" >&2
                exit 1
            fi
            prefix="$2"
            shift 2
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}" >&2
            show_help
            exit 1
            ;;
        *)
            packages+=("$1")
            shift
            ;;
    esac
done

# Determine action
if [ -z "${action}" ]; then
    action="install"
fi

case "${action}" in
    test)
        echo -e "${BLUE}Testing proxy connectivity...${NC}"
        "${BREW_MANAGER}" test
        ;;
    install)
        if [ -n "${prefix}" ]; then
            echo -e "${BLUE}Installing default formulae with prefix '${prefix}'...${NC}"
            "${BREW_MANAGER}" install-prefix "${prefix}"
        elif [ ${#packages[@]} -gt 0 ]; then
            echo -e "${BLUE}Installing specified formulae: ${packages[*]}${NC}"
            "${BREW_MANAGER}" install "${packages[@]}"
        else
            echo -e "${BLUE}Installing default formulae starting with 'p'...${NC}"
            "${BREW_MANAGER}" install-prefix p
        fi
        ;;
esac

echo ""
echo -e "${GREEN}Done.${NC}"

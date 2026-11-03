#!/bin/bash
# Used for Linux environment

VENV_PATH="${VENV_PATH:-/opt/zephyrproject/.venv}"
export ZEPHYR_BASE="${ZEPHYR_BASE:-/opt/zephyrproject/zephyr}"
PROJECT_DIR="$(pwd)"
BUILD_DIR="$PROJECT_DIR/build"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

check_venv() {
    if [ -f "$VENV_PATH/bin/activate" ]; then
        source "$VENV_PATH/bin/activate"
        echo -e "${GREEN}✓ Virtual environment activated${NC}"
    else
        echo -e "${RED}✗ Virtual environment not found${NC}"
        exit 1
    fi
}
case "$1" in
    build)
        check_venv
        west build -d "$BUILD_DIR" "$PROJECT_DIR"
        ;;
    rebuild)
        check_venv
        rm -rf "$BUILD_DIR"
        west build -d "$BUILD_DIR" "$PROJECT_DIR"
        ;;
    flash)
        check_venv
        west flash -d "$BUILD_DIR"
        ;;
    menuconfig)
        check_venv
        west build -d "$BUILD_DIR" -t menuconfig
        ;;
    diff_config)
        python3 ${ZEPHYR_BASE}/scripts/kconfig/diffconfig build/zephyr/.config.old build/zephyr/.config
        ;;
    clean)
        rm -rf "$BUILD_DIR"
        ;;
    *)
        echo -e "${BLUE}Usage: $0 <command>${NC}"
        echo -e "  ${GREEN}build${NC}        Build the project"
        echo -e "  ${GREEN}rebuild${NC}      Clean and rebuild the project"
        echo -e "  ${GREEN}flash${NC}        Flash the built firmware"
        echo -e "  ${GREEN}menuconfig${NC}   Open the menuconfig UI"
        echo -e "  ${GREEN}diff_config${NC}  Diff old and new .config"
        echo -e "  ${GREEN}clean${NC}        Remove the build directory"
        exit 1
        ;;
esac
#!/usr/bin/env bash

if [ "${__CRYSTAL_PLATFORM_SH_LOADED:-}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi
__CRYSTAL_PLATFORM_SH_LOADED=1

# 初始化平台入口路径：init_platform_env "${BASH_SOURCE[0]}"。
init_platform_env() {
    PLATFORM_DIR=$(CDPATH= cd -- "$(dirname -- "$1")" && pwd)
    PLATFORM_NAME=$(basename "$PLATFORM_DIR")
    ROOT_DIR=$(CDPATH= cd -- "$PLATFORM_DIR/../.." && pwd)
}

# 列出当前平台下包含 ctrl 的包。
list_platform_packages() {
    local dir

    for dir in "$PLATFORM_DIR"/*; do
        if [ -d "$dir" ] && [ -f "$dir/ctrl" ]; then
            basename "$dir"
        fi
    done
}

platform_package_exists() {
    [ -f "$PLATFORM_DIR/$1/ctrl" ]
}

# 粗略判断包是否实现 action，用于平台批量分发时跳过无关包。
platform_package_supports_action() {
    local pkg=$1
    local action=$2

    grep -Eq "(^|[[:space:]\|])$action(\)|\|)" "$PLATFORM_DIR/$pkg/ctrl"
}

run_platform_package() {
    local pkg=$1
    shift

    if ! platform_package_exists "$pkg"; then
        echo "unknown $PLATFORM_NAME package: $pkg" >&2
        false
    fi

    bash "$PLATFORM_DIR/$pkg/ctrl" "$@"
}

# 执行包 action；未实现 action 时返回 2，方便平台入口选择跳过。
run_supported_platform_package() {
    local pkg=$1
    local action=$2
    shift 2

    if ! platform_package_exists "$pkg"; then
        echo "unknown $PLATFORM_NAME package: $pkg" >&2
        return 1
    fi

    if ! platform_package_supports_action "$pkg" "$action"; then
        return 2
    fi

    run_platform_package "$pkg" "$action" "$@"
}

if [ "${CRYSTAL_TEST:-}" = "1" ]; then
    . "$(dirname "$0")/test.sh"

    init_platform_env packages/server/ctrl

    assert_eq "$PLATFORM_NAME" "server"
    assert_eq "$PLATFORM_DIR" "$ROOT_DIR/packages/server"
fi

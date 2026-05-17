#!/bin/sh

# 初始化包路径：init_pkg_env "$0"。
# 适用于 packages/<platform>/<package>/ctrl 这种新包结构。
init_pkg_env() {
    PKG_DIR=$(CDPATH= cd -- "$(dirname -- "$1")" && pwd)
    PKG_NAME=$(basename "$PKG_DIR")
    PLATFORM_NAME=$(basename "$(dirname "$PKG_DIR")")
    ROOT_DIR=$(CDPATH= cd -- "$PKG_DIR/../../.." && pwd)
    TEMP_DIR="$ROOT_DIR/temp/$PLATFORM_NAME/$PKG_NAME"
}

if [ "${CRYSTAL_TEST:-}" = "1" ]; then
    . "$(dirname "$0")/test.sh"

    init_pkg_env packages/server/xray/ctrl

    assert_eq "init_pkg_env pkg name" "$PKG_NAME" "xray"
    assert_eq "init_pkg_env platform name" "$PLATFORM_NAME" "server"
    assert_eq "init_pkg_env temp dir" "$TEMP_DIR" "$ROOT_DIR/temp/server/xray"
fi

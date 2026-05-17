#!/usr/bin/env bash

if [ "${__CRYSTAL_TEST_SH_LOADED:-}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi
__CRYSTAL_TEST_SH_LOADED=1

# 断言两个字符串相等：assert_eq "$actual" "$expected"。
assert_eq() {
    local actual=$1
    local expected=$2

    if [ "$actual" != "$expected" ]; then
        echo "assert_eq failed" >&2
        echo "expected:" >&2
        echo "$expected" >&2
        echo "actual:" >&2
        echo "$actual" >&2
        exit 1
    fi
}

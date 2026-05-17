#!/bin/sh

# 断言两个字符串相等：assert_eq "case name" "$actual" "$expected"。
assert_eq() {
    local name=$1
    local actual=$2
    local expected=$3

    if [ "$actual" != "$expected" ]; then
        echo "$name failed" >&2
        echo "expected:" >&2
        echo "$expected" >&2
        echo "actual:" >&2
        echo "$actual" >&2
        exit 1
    fi
}

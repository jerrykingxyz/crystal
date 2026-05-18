#!/usr/bin/env bash

if [ "${__CRYSTAL_CONFIG_SH_LOADED:-}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi
__CRYSTAL_CONFIG_SH_LOADED=1

_encode_value() {
    echo "$1" | awk -v RS= '{ gsub(/\n/,"\\n") } 1'
}

_decode_value() {
    echo "$1" | awk -v RS= '{ gsub(/\\n/,"\n") } 1'
}

# 读取配置文件为单行记录：read_config_vars config。
read_config_vars() {
    awk -F"=" '
BEGIN {
    current=""
    value=""
}
$0=="" {
    if (current!="") {
        print current "=" value
    }
    current=""
    value=""
    next
}
index($0,"=")>0 {
    if (current!="") {
        print current "=" value
    }
    current=$1
    value=$0
    sub(/^[^=]*=/,"",value)
    next
}
{
    if (current=="") {
        print "config continuation line before key: " $0 > "/dev/stderr"
        exit 1
    }
    value=value "\\n" $0
}
END {
    if (current!="") {
        print current "=" value
    }
}' "$1"
}

# 读取配置值：get_config_var config domains。
# 多行块会按原文返回，JSON 片段也不会被解析或转换。
get_config_var() {
    local value

    value=$(
        read_config_vars "$1" |
            awk -F"=" -v key="$2" '$1==key { print substr($0, index($0,"=")+1); found=1; exit } END { if (found!=1) exit 1 }'
    ) || return 1

    _decode_value "$value"
}

exist_config_var() {
    read_config_vars "$1" |
        awk -F"=" -v key="$2" '$1==key { found=1; exit } END { exit found!=1 }'
}

# 写入配置值：update_config_var config domains "$domains"。
# 如果 key 已存在，会替换整个 key 块，避免旧续行残留。
update_config_var() {
    local var_file=$1
    local key=$2
    local value
    local tmp_file="$var_file.tmp.$$"

    value=$(_encode_value "$3")

    read_config_vars "$var_file" |
        awk -F"=" -v key="$key" -v value="$value" '
$1==key {
    if (updated!=1) {
        print key "=" value
        updated=1
    }
    next
}
{
    print
}
END {
    if (updated!=1) {
        print key "=" value
    }
}' |
        awk -v RS= '{ gsub(/\\n/,"\n") } 1' > "$tmp_file"

    mv -f "$tmp_file" "$var_file"
}

add_config_var() {
    update_config_var "$1" "$2" "$3"
}

# 删除配置值：del_config_var config domains。
# 如果 key 是多行块，会连同续行一起删除。
del_config_var() {
    local var_file=$1
    local key=$2
    local tmp_file="$var_file.tmp.$$"

    if [ ! -f "$var_file" ]; then
        return 0
    fi

    read_config_vars "$var_file" |
        awk -F"=" -v key="$key" '$1!=key { print }' |
        awk -v RS= '{ gsub(/\\n/,"\n") } 1' > "$tmp_file"

    mv -f "$tmp_file" "$var_file"
}

if [ "${CRYSTAL_TEST:-}" = "1" ]; then
    . "$(dirname "$0")/test.sh"

    actual=$(get_config_var /dev/fd/3 domains 3<<'EOF'
server=127.0.0.1

domains=test.local 127.0.0.1
router.local 192.168.1.1

json=["a","b"]
EOF
)
    expected='test.local 127.0.0.1
router.local 192.168.1.1'

    assert_eq "$actual" "$expected"
fi

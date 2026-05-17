#!/bin/sh

# 读取配置值：get_config_var config domains。
# 多行块会按原文返回，JSON 片段也不会被解析或转换。
get_config_var() {
    awk -F"=" -v target="$2" '
function emit_value() {
    if (current==target) {
        print value
        found=1
    }
}
BEGIN {
    current=""
    value=""
    found=0
}
$0=="" {
    emit_value()
    current=""
    value=""
    next
}
index($0,"=")>0 {
    emit_value()
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
    if (value=="") {
        value=$0
    } else {
        value=value "\n" $0
    }
}
END {
    emit_value()
    if (found==0) {
        exit 1
    }
}' "$1"
}

exist_config_var() {
    get_config_var "$1" "$2" >/dev/null 2>&1
}

# 写入配置值：update_config_var config domains "$domains"。
# 如果 key 已存在，会替换整个 key 块，避免旧续行残留。
update_config_var() {
    local var_file=$1
    local key=$2
    local value=$3
    local tmp_file="$var_file.tmp.$$"

    if [ ! -f "$var_file" ]; then
        touch "$var_file"
    fi

    awk -F"=" -v target="$key" -v new_value="$value" '
function print_block() {
    line_count=split(new_value, lines, "\n")
    print target "=" lines[1]
    for (i=2; i<=line_count; i++) {
        print lines[i]
    }
}
function is_key_line(line) {
    return index(line,"=")>0
}
BEGIN {
    updated=0
    skipping=0
}
$0=="" {
    if (skipping==1) {
        skipping=0
    }
    print
    next
}
is_key_line($0) {
    if ($1==target) {
        if (updated==0) {
            print_block()
            updated=1
        }
        skipping=1
        next
    }
    skipping=0
}
skipping==1 {
    next
}
{
    print
}
END {
    if (updated==0) {
        print_block()
    }
}' "$var_file" > "$tmp_file"
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
        return
    fi

    awk -F"=" -v target="$key" '
function is_key_line(line) {
    return index(line,"=")>0
}
BEGIN {
    skipping=0
}
$0=="" {
    skipping=0
    print
    next
}
is_key_line($0) {
    if ($1==target) {
        skipping=1
        next
    }
    skipping=0
}
skipping==1 {
    next
}
{
    print
}' "$var_file" > "$tmp_file"
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

    assert_eq "get_config_var smoke test" "$actual" "$expected"
fi

#!/bin/sh

# 渲染模板：render_config template config > output。
# 只替换 __key__ 占位符，不解析 JSON，也不转换多行值。
render_config() {
    awk -F"=" '
function escape_value(value) {
    gsub(/\\/,"\\\\",value)
    gsub(/&/,"\\&",value)
    return value
}
function commit_value() {
    if (current!="") {
        vars["__" current "__"]=escape_value(value)
    }
}
NR==FNR {
    if ($0=="") {
        commit_value()
        current=""
        value=""
        next
    }
    if (index($0,"=")>0) {
        commit_value()
        current=$1
        value=$0
        sub(/^[^=]*=/,"",value)
        next
    }
    if (current=="") {
        print "config continuation line before key: " $0 > "/dev/stderr"
        exit 1
    }
    if (value=="") {
        value=$0
    } else {
        value=value "\n" $0
    }
    next
}
FNR==1 {
    commit_value()
}
{
    for (key in vars) {
        gsub(key, vars[key])
    }
    print
}' "$2" "$1"
}

if [ "${CRYSTAL_TEST:-}" = "1" ]; then
    . "$(dirname "$0")/test.sh"

    actual=$(render_config /dev/fd/3 /dev/fd/4 3<<'EOF_TEMPLATE' 4<<'EOF_CONFIG'
server=__server__
domains=
__domains__
json=__json__
EOF_TEMPLATE
server=127.0.0.1

domains=test.local 127.0.0.1
router.local 192.168.1.1

json=["a","b"]
EOF_CONFIG
)
    expected='server=127.0.0.1
domains=
test.local 127.0.0.1
router.local 192.168.1.1
json=["a","b"]'

    assert_eq "render_config smoke test" "$actual" "$expected"
fi

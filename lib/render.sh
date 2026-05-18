#!/usr/bin/env bash

if [ "${__CRYSTAL_RENDER_SH_LOADED:-}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi
__CRYSTAL_RENDER_SH_LOADED=1

__CRYSTAL_RENDER_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
. "$__CRYSTAL_RENDER_DIR/config.sh"

# 渲染模板：render_config template config > output。
# 只替换 __key__ 占位符，不解析 JSON，也不转换多行值。
render_config() {
    local template_file=$1
    local var_file=$2

    read_config_vars "$var_file" |
    awk -F"=" '
NR==FNR {
    value=substr($0,index($0,"=")+1)
    gsub(/\\n/,"\n",value)
    gsub(/\\/,"\\\\",value)
    gsub(/&/,"\\&",value)
    vars["__" $1 "__"]=value
    next
}
{
    for (key in vars) {
        gsub(key, vars[key])
    }
    print
}' - "$template_file"
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

    assert_eq "$actual" "$expected"
fi

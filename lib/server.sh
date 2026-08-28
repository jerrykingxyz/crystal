#!/usr/bin/env bash

if [ "${__CRYSTAL_SERVER_SH_LOADED:-}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi
__CRYSTAL_SERVER_SH_LOADED=1

# 使用服务器系统包管理器安装依赖。
server_install() {
    . /etc/os-release

    case "$ID" in
        ubuntu)
            apt-get update
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
            ;;
        centos)
            if command -v dnf >/dev/null; then
                dnf install -y "$@"
            else
                yum install -y "$@"
            fi
            ;;
        *)
            printf '%s\n' "不支持的服务器系统: $ID" >&2
            false
            ;;
    esac
}

# 使用服务器系统包管理器移除依赖。
server_remove() {
    . /etc/os-release

    case "$ID" in
        ubuntu)
            apt-get remove -y "$@"
            ;;
        centos)
            if command -v dnf >/dev/null; then
                dnf remove -y "$@"
            else
                yum remove -y "$@"
            fi
            ;;
        *)
            printf '%s\n' "不支持的服务器系统: $ID" >&2
            false
            ;;
    esac
}

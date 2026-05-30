#!/usr/bin/env bash

if [ "${__CRYSTAL_ARCHLINUX_SH_LOADED:-}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi
__CRYSTAL_ARCHLINUX_SH_LOADED=1

pacman_install() {
    pacman -S "$@" --needed --noconfirm
}

pacman_remove() {
    pacman -Runs "$@" --noconfirm
}

create_link() {
    local source_file=$1
    local target_file=$2

    if [ -e "$target_file" ] || [ -L "$target_file" ]; then
        rm -r "$target_file"
    fi

    mkdir -p "$(dirname "$target_file")"
    ln -s "$source_file" "$target_file"
}

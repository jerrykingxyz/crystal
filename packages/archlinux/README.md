# ArchLinux

ArchLinux 平台入口是 `packages/archlinux/ctrl <action> [package...]`，也可以通过根入口 `CRYSTAL_PLATFORM=archlinux ./ctrl <action> [package...]` 调用。

`root_setup` 用于安装系统依赖，通常需要 root 权限；`user_setup` 用于写入用户态配置。其中 Bash 初始化由 `bash` 包负责，它会把 `source packages/archlinux/ctrl profile` 注册到 `~/.bashrc` 和 `~/.bash_profile`。

`profile` 会 source 各包的 `profile` action；其中 `bash` 包会把 `packages/archlinux/bash/command` 加入 `PATH`。需要当前 shell 生效时直接 `source packages/archlinux/ctrl profile`。

前台应用使用 `run`，例如 `./ctrl run chrome`、`./ctrl run audio`、`./ctrl run sway`。`start` 只用于真正需要启动服务或运行态的包。短命令集中由 `bash` 包维护，是包 `run` 的快捷入口。

常用 pacman 命令：

```sh
pacman -Syu
pacman -Ss <package>
pacman -S <package>
pacman -Runs <package>
```

安装系统时的交互式用户创建不放入默认 setup；需要时执行：

```sh
packages/archlinux/user/ctrl create <username>
```

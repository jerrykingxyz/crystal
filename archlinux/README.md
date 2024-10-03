TODO
1. vps
2. macos

# Archlinux

Those scripts is used to initial archlinux envirement, and it includes three parts.

### packages

`Packages` is the software packages. The entry of a software is the `ctrl` file, and it will implement part of command to complete the feature.

```
ctrl bootstrap # run when install archlinux system
ctrl root_setup # setup software, should run as root
ctrl user_setup # setup software, should run as user
ctrl start # run this software
ctrl # same as start
ctrl stop # stop this software
ctrl config # set software config
ctrl root_remove # remove software, should run as root
ctrl user_remove # remove software, should run as user
ctrl profile # run on .bash_profile
ctrl help # print help info
```

### command

`command` directary will be registered to `PATH`, software can create a soft link on this folder to make it can run globally.

### ctrl, profile

Those root command is used to run all of `packages` easily.

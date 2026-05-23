# 框架规划

本仓库正在逐步收敛为一个小型、无额外依赖的 shell 配置框架，用于管理机器和服务配置。目标是在保留包脚本自由度的同时，统一仓库目录结构和 action 命名。

## 目录结构

```text
crystal/
  ctrl
  lib/
  temp/
  packages/
    <platform>/
      ctrl
      <package>/
        ctrl
        config
        template.*
```

- `packages/<platform>/<package>` 是主要包结构。
- `platform` 表示运行目标，例如 `openwrt`、`archlinux`、`macos` 或 `server`。
- 根目录 `ctrl` 根据当前环境选择平台入口；需要手动指定时使用 `CRYSTAL_PLATFORM=<platform>`。
- `packages/<platform>/ctrl` 是平台入口，负责批量分发本平台包，并承载必要的平台级动作。
- `temp/<platform>/<package>` 存放运行时生成文件。
- `lib/` 用于存放已经复用的公共 shell helper，例如 `lib/env.sh`、`lib/config.sh` 和 `lib/render.sh`。

## 配置格式

配置文件使用块式 `key=value`：

```text
key1=value11
value12
value13

key2=value2
```

- `key=value` 开始一个配置项。
- 后续不含 `=` 的非空行作为当前 key 的续行值。
- 空行结束当前 key 块，用于分隔配置。
- 多行值默认按原文多行处理，配置层和渲染层不做 JSON、数组或其他类型转换。
- 如果模板需要 JSON 数组，可以直接在单行 value 中写 JSON 片段。

## Actions

每个包保留自己的 `ctrl` 脚本。包可以只实现自己需要的 action，但 action 名称应遵循下面的语义。

- 根入口和平台入口使用 `ctrl <action> [package...]` 分发普通 action；不指定 package 时表示全部包。
- 平台入口的配置更新使用 `ctrl config <package> <key> <value>`。
- 包脚本不内置 usage 文案；支持的 action 以文档为准，未知 action 直接失败。
- `root_setup` 和 `user_setup` 应支持多次运行；二次运行应刷新依赖或覆盖生成物。
- `root_setup`：需要 root 权限的准备工作，例如安装依赖包、写系统服务或修改系统网络配置。
- `user_setup`：用户态配置，例如 dotfiles、shell profile、用户级服务配置或本地密钥材料生成。
- `start`：将当前包配置应用到运行环境。如果包需要生成运行时文件，`start` 可以先 render 再启动或刷新服务。
- `stop`：停止或撤销 `start` 产生的运行态影响。
- `restart`：重启包运行态。默认可以理解为 `stop` 后再 `start`，但包可以按自身需要实现。
- `run`：前台运行包的运行态，阻塞当前终端，退出时结束本次前台运行。
- `config key value`：更新包自己的本地配置源。
- `root_remove`：撤销 `root_setup` 产生的系统级配置。
- `user_remove`：撤销 `user_setup` 产生的用户级配置。

## 约束

- 框架层不依赖 YAML、Python、Node.js、Ansible、Nix 或其他外部工具。
- 框架脚本统一使用 bash。
- 可跨平台复用的逻辑放入 `lib/`，平台相关逻辑保留在平台包脚本内，或后续收敛到 `lib/platform/<platform>.sh`。
- 生成文件、本地配置和 secrets 不进 git。
- 公共库需要能够安全地被重复 source，并由模块自身管理依赖加载。

## 包环境

新包结构中的 `ctrl` 可以通过 `init_pkg_env "${BASH_SOURCE[0]}"` 初始化路径变量：

- `PKG_DIR`：当前包目录。
- `PKG_NAME`：当前包名。
- `PLATFORM_NAME`：当前平台名。
- `ROOT_DIR`：仓库根目录。
- `TEMP_DIR`：当前包的运行时临时目录。

## 内联测试

- 公共 `lib/*.sh` 可以通过 `CRYSTAL_TEST=1 bash lib/xxx.sh` 运行内联冒烟测试。
- 测试样例应贴近工具函数本身，尽量作为 example 阅读。
- 公共断言放在 `lib/test.sh`，测试文件只保留本工具的输入和期望输出。
- 测试保持克制，默认只写一个覆盖主要行为的冒烟测试；后续出现 edge case 时再补充或调整。
- 测试不写入或删除文件，优先使用 here-doc 和文件描述符提供输入。

## 迁移策略

1. 新包放到 `packages/<platform>/<package>`。
2. 运行时生成文件放到 `temp/<platform>/<package>`。
3. 至少两个包需要同一段 shell 逻辑时，再把它抽到 `lib/`。
4. 旧目录按平台逐步迁移，迁移时保持改动范围清晰。

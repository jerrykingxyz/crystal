# OpenWrt

运行 OpenWrt 侧脚本前需要先安装 bash：

```sh
opkg update
opkg install bash
```

OpenWrt 包位于 `packages/openwrt`，平台入口为 `packages/openwrt/ctrl <action> [package...]`。

当前代理链路使用 Xray DNS/FakeDNS 做域名白名单，nftables 按 `proxy_source_ips` 接管 DNS 和 FakeIP 流量。Xray DNS 负责广告域名屏蔽；代理域名由 `geosite:gfw`、`geosite:google`、`geosite:openai` 和 `packages/openwrt/xray/config` 中的 `proxy_domains` 共同组成，SmartDNS 不参与代理链路。

Xray 普通 DNS 上游固定回问本机 dnsmasq，由 dnsmasq 继续负责真实上游 DNS。

## DDNS

`ddns/ctrl` 负责定时获取出口 IP，并在地址变化时执行配置的更新命令。默认使用同目录的 `namesilo` 脚本调用 NameSilo API，服务商请求与定时调度分开维护。

使用默认配置前，在 NameSilo DNS Manager 创建 `home.crystalnode.top` 的 A 记录，TTL 设为 `3600`，并在 API Manager 生成 API Key。域名需要使用 NameSilo 的 DNS 托管。把 API Key 填入本地 `config` 的 `api_key`，然后执行：

```sh
cp packages/openwrt/ddns/config.example packages/openwrt/ddns/config
chmod 600 packages/openwrt/ddns/config
vi packages/openwrt/ddns/config

bash packages/openwrt/ctrl root_setup ddns
bash packages/openwrt/ctrl start ddns
```

`domain` 填完整域名，不再拆分注册域名和主机名。每次更新会分别检查 IPv4 和 IPv6。`ip_url` 应返回纯文本公网出口地址，默认使用支持双栈的 `https://api64.ipify.org`；curl 分别用 `-4`、`-6` 查询。脚本还会读取系统路由选择的本机出口地址，只有它与公网探测结果一致时才更新对应的 A 或 AAAA 记录；如果经过上级 NAT、地址获取失败或两者不一致，就跳过该地址族，避免把不可直连的地址写入 DDNS。

默认配置中的 `update_command=bash "$DDNS_DIR/namesilo"` 会先查询所选类型的记录 ID，再发起更新，并检查 API 业务状态码。ID 不需要手动填写。请求使用 XML 响应，通过 sed 提取状态码、awk 按记录分块匹配域名和类型后取 ID，不依赖 jsonfilter。`ttl` 默认 `3600`，`api_key` 只保存在本地配置，不写入定时任务或 curl 的进程参数。

NameSilo 脚本目前使用一级子域名，将 `home.crystalnode.top` 拆为主机名 `home` 和注册域名 `crystalnode.top`。如需同步某类地址，需提前创建对应的 A 或 AAAA 记录，每种类型只保留一条。API 的 IP 白名单不能固定为旧的家庭出口 IP，否则换 IP 后无法更新。

`update_command` 也可以替换为其他服务商的一行 Bash 命令。执行时可读取以下环境变量：

| 变量 | 含义 |
| --- | --- |
| `DOMAIN` | 配置的完整域名 |
| `IP` | 当前出口地址 |
| `IP_VERSION` | 本次地址类型：`ipv4` 或 `ipv6` |
| `RECORD_TYPE` | DNS 记录类型：`A` 或 `AAAA` |
| `DDNS_DIR` | 当前包的绝对路径 |

简单接口可以直接配置 curl 请求；需要先查询记录再更新的接口，可以使用 `update_command=bash "$DDNS_DIR/update"` 调用本地脚本。本地脚本及密钥可放入已被 git 忽略的 `runtime/`，对应配置为 `update_command=bash "$DDNS_DIR/runtime/update"`。更新命令应检查业务响应，失败返回非零退出码；例如 HTTP 200 中仍可能包含业务错误，只有 curl 的 `--fail` 不足以判断这种情况。

配置与更新命令会以 root 执行，只填写自己信任的命令，并保护好本地配置与密钥。`api_key`、`ttl` 由默认的 NameSilo 脚本读取，通用调度入口不处理这两个参数。

### 定时任务如何工作

`start` 会在 root crontab 中维护下面这样的一行，并立即执行一次更新：

```cron
*/5 * * * * /bin/bash "/仓库路径/packages/openwrt/ddns/ctrl" update 2>&1 | logger -t crystal-ddns # crystal-ddns
```

- `*/5 * * * *`：每 5 分钟执行一次。
- `/bin/bash ... update`：执行本包的单次更新动作。
- `2>&1 | logger -t crystal-ddns`：把输出和错误写入系统日志。
- `# crystal-ddns`：标记本包的任务，方便启停时识别。

脚本通过 `crontab -l` 读取已有任务，删除带本包标记的旧行，启动时追加上面一行，再通过 `crontab -` 写回。因此重复启动只有一条任务，`stop` / `root_remove` 也只删除这一条。其他任务保留，不停止系统 cron、不卸载共享依赖。平台的 `/etc/init.d/crystal` 启动时同样会应用此配置；没有本地 `config` 时跳过 DDNS。

```sh
# 查看当前定时任务。
crontab -l

# 手动检查地址并更新。
bash packages/openwrt/ddns/ctrl update

# 查看日志。
logread -e crystal-ddns
```

成功上报后，地址会缓存在 `temp/openwrt/ddns/ipv4` / `ipv6`，后续地址未变就跳过更新；失败不写缓存，下次继续尝试。IPv4 和 IPv6 分别处理，一类失败仍会尝试另一类，最终只要有一类失败就返回失败。缓存按查询接口返回的文本比较，不再自行解析和展开 IPv6。重新 `start` / `restart` 会清除缓存并重新上报，修改配置或外部 DNS 记录后可用这个方式强制刷新。

`root_setup` 只安装 curl，不单独安装 CA 证书包；HTTPS 验证使用路由器已有的可信证书库。如果系统没有可用证书，curl 会校验失败，此时需补装 ca-bundle 或 ca-certificates。脚本使用 curl 默认的证书验证。

curl 查询 IP 时会禁用显式代理。当前 nftables 只接管指定 LAN 来源的 prerouting 流量，路由器自身请求走直连；如另行配置全局透明代理，应确保查询接口走家庭出口。此包不配置入站端口或内网穿透。

旧 SNAPSHOT 的软件源可能已失效，安装依赖失败时应先检查软件源与固件的兼容性，不要强制安装新版依赖。

接口参考：[NameSilo 查询记录](https://www.namesilo.com/api-reference/pages?uid=dns/dns-list-records)、[更新记录](https://www.namesilo.com/api-reference/pages?uid=dns/dns-update-record)。

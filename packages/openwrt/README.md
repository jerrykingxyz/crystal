# OpenWrt

运行 OpenWrt 侧脚本前需要先安装 bash：

```sh
opkg update
opkg install bash
```

平台入口为 `packages/openwrt/ctrl <action> [package...]`，不指定包时按默认顺序处理全部包；`stop` / `root_remove` 按相反顺序。单个包也可直接运行 `packages/openwrt/<包>/ctrl <action>`。每个包的本地配置在 `<包>/config`，从 `config.example` 复制后修改，也可用 `ctrl config <包> <key> <value>` 写入。

## 包一览

| 包 | 功能 |
| --- | --- |
| `xray` | 透明代理核心：Xray DNS/FakeDNS 做域名白名单，广告域名屏蔽，代理流量走远端节点 |
| `nftables` | 按 `proxy_source_ips` 把指定 LAN 设备的 DNS 和 FakeIP 流量接管到 xray |
| `dhcp` | 按 MAC 绑定固定 IP 和主机名（dnsmasq `dhcp.@host`） |
| `dns` | 维护本地域名解析（dnsmasq `dhcp.@domain`），如 `router.local` |
| `vpn` | 在路由器上跑 Xray 入站（VLESS + Reality），外部客户端可访问内网；自动维护 WAN 入站 IPv6 防火墙规则，并可生成订阅地址 |
| `apiserver` | `script-server`，只对内网开放，通过 POST 执行 `apiserver/scripts/` 下的脚本（如读写代理域名、重启） |
| `ddns` | 把 WAN 口的 IPv6 同步到 DNS 的 AAAA 记录，让外部知道家里的地址 |

## 代理链路（xray / nftables / dns / dhcp）

代理域名由 `geosite:gfw`、`geosite:google`、`geosite:openai` 和 `packages/openwrt/xray/config` 中的 `proxy_domains` 共同组成，命中的域名由 FakeDNS 返回假 IP，nftables 再把这些流量交给 xray 的透明代理端口。Xray DNS 同时负责广告域名屏蔽；普通 DNS 上游固定回问本机 dnsmasq，由 dnsmasq 继续负责真实上游 DNS，不使用 SmartDNS。

- `xray`：`root_setup` 安装 `xray-core` 并下载 `geosite.dat`，关闭系统自带的 xray 服务，改由本包启停。
- `nftables`：创建 `nft_proxy_table` 表，并添加 fwmark 策略路由；`stop` 会清理表和路由。
- `dhcp`：`config` 每行 `名称=IP/MAC`，`start` 时整体重写 dnsmasq 的静态主机记录。
- `dns`：`config` 的 `domains` 每行 `域名 IP`，`start` 时整体重写 dnsmasq 的本地域名记录，会覆盖手工在 LuCI 里添加的同类记录。

## DDNS

`ddns/ctrl` 每 30 分钟读取 `interface`（默认 `wan`）上的全局 IPv6，地址变化时调用 `providers/<provider>` 同步 AAAA 记录。只处理 IPv6，不探测公网、不处理 IPv4。目前只有 `providers/namesilo`，调用 NameSilo API。

取地址时排除 `dynamic`（DHCPv6）、`temporary` 和 `deprecated` 地址，只取 SLAAC 的稳定地址。取不到地址时只输出日志并正常退出，不写缓存。

使用前在 NameSilo DNS Manager 创建 `home.crystalnode.top` 的 AAAA 记录（每种类型只保留一条），并在 API Manager 生成 API Key。域名需使用 NameSilo 的 DNS 托管，API 的 IP 白名单不能固定为旧的家庭出口 IP。

```sh
cp packages/openwrt/ddns/config.example packages/openwrt/ddns/config
chmod 600 packages/openwrt/ddns/config
vi packages/openwrt/ddns/config

bash packages/openwrt/ctrl root_setup ddns
bash packages/openwrt/ctrl start ddns
```

| 配置 | 含义 |
| --- | --- |
| `domain` | 完整域名，NameSilo 脚本只支持一级子域名 |
| `interface` | 读取地址的接口，默认 `wan` |
| `provider` | `providers/` 下的脚本名，目前为 `namesilo` |
| `api_key` | 通过标准输入传给 provider，不进入进程参数 |
| `ttl` | 可选，NameSilo 默认且最小 `3600` |

provider 的调用形式为 `providers/<name> <fqdn> <ip> [--type AAAA] [--ttl N]`，API Key 从标准输入读取，失败返回非零；HTTP 200 中仍可能包含业务错误，需检查业务响应。新增服务商只需在 `providers/` 下放一个遵循该约定的脚本。配置以 root 执行，请保护好本地 `config`。

`start` 会在 root crontab 中维护一行带 `# crystal-ddns` 标记的 `*/30` 任务并立即更新一次；重复启动只保留一条，`stop` / `root_remove` 只删除这一条。成功后地址缓存在 `temp/openwrt/ddns/ipv6`，未变化就跳过；失败不写缓存。`start` / `restart` 会清除缓存，可用于强制刷新。

```sh
bash packages/openwrt/ddns/ctrl update   # 手动更新
logread -e crystal-ddns                  # 查看日志
```

`root_setup` 只安装 curl，HTTPS 使用系统已有证书库；证书校验失败时需补装 ca-bundle。

接口参考：[NameSilo 查询记录](https://www.namesilo.com/api-reference/pages?uid=dns/dns-list-records)、[更新记录](https://www.namesilo.com/api-reference/pages?uid=dns/dns-update-record)。

## VPN

`vpn` 在路由器上监听 `[::]:<port>`（默认 `5000`），使用 VLESS + Reality。路由规则只放行目标为 `192.168.0.0/16` 的流量，其余一律丢弃，所以只能访问内网，不能当出口代理。客户端通过 DDNS 域名连回来，用本地 SOCKS 配合 `ssh -o ProxyCommand` 访问内网机器时，只能使用 IP，不能使用主机名。

| 配置 | 含义 |
| --- | --- |
| `port` | 监听端口，同时用于防火墙规则 |
| `server_domain` | 订阅链接里的服务器地址，通常填 DDNS 域名 |
| `user_id` | 客户端 UUID，需为真实 UUID |
| `domain` | Reality 伪装域名，对应链接里的 `sni` |
| `private_key` / `public_key` | `user_setup` 生成 |
| `share_token` | 订阅地址的访问令牌，`user_setup` 生成，缺失时 `share` 自动补上 |

防火墙：`start` 写入 UCI 规则 `crystal_vpn`，仅放行 WAN 入站 IPv6 的 TCP `port`；`stop` / `root_remove` 删除。如手动加过放行该端口的规则，请自行清理。apiserver 的 8000 端口只对内网开放，不会放行。

订阅：`root_setup` 会安装 `uhttpd`。执行下面的命令会输出订阅地址并在前台提供下载，Ctrl-C 结束并清理文件：

```sh
bash packages/openwrt/vpn/ctrl share
```

订阅地址使用 `br-lan` 的 IPv4 和 `8001` 端口，仅限内网访问，内容是 base64 编码的 `vless://` 链接。`share` 不开放 WAN 端口，因此只在内网有效。

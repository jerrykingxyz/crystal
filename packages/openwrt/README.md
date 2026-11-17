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

## VPN 防火墙

`vpn/ctrl start` 会按 `vpn/config` 的 `port`（默认 `5000`）写入 UCI 规则 `crystal_vpn`，仅放行 WAN 入站 IPv6 的 TCP 端口；`stop` / `root_remove` 会删除。如手动加过放行该端口的规则，请自行清理。apiserver 的 8000 端口只对内网开放，不会放行。

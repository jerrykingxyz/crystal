# OpenWrt

运行 OpenWrt 侧脚本前需要先安装 bash：

```sh
opkg update
opkg install bash
```

OpenWrt 包位于 `packages/openwrt`，平台入口为 `packages/openwrt/ctrl <action> [package...]`。

当前代理链路使用 Xray DNS/FakeDNS 做域名白名单，dns 包负责将 dnsmasq 转发到 Xray DNS，nftables 只转发 FakeIP 流量。Xray DNS 负责广告域名屏蔽；代理域名由 `geosite:gfw` 和 `packages/openwrt/xray/config` 中的 `proxy_domains` 共同组成，SmartDNS 不参与代理链路。

Xray 普通 DNS 上游优先使用 OpenWrt 运行时获取到的上游 DNS；读取不到时使用 `packages/openwrt/xray/config` 中的 `upstream_dns_servers`。

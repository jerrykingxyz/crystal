```bash
ip route add local default dev lo table 100
ip rule add fwmark 1 table 100

ip route list
ip rule list
ip route del local default dev lo table 100
ip rule del fwmark 1 table 100

nft -f ./nft.conf
# list ruleset
# list tables
# delete table ip xray
```

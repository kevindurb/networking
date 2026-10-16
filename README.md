# networking

Ansible provisioning for the home network. Currently this manages a single
host: the home router.

## Router

| | |
|---|---|
| Hardware | generic x86/64 (no Wi-Fi) |
| OS | OpenWrt 25.12.0, kernel 6.12 (apk package manager) |
| Hostname | `router` |
| LAN | `br-lan` (bridge, `eth0`) static `192.168.1.1/16` |
| WAN | `eth1`, DHCP (IPv4 + IPv6) |
| Tailnet | `100.124.132.94`, subnet router + exit node |

### Topology

- **LAN** is `192.168.0.0/16` (addressed as `192.168.1.1/16`). The Kubernetes
  API VIP lives at `192.168.42.1`, inside that range.
- **Tailscale** runs on the router (`tailscale0`). It advertises the whole
  `192.168.0.0/16` subnet and offers itself as an exit node, so tailnet clients
  can reach LAN hosts (including the k8s API VIP). Magic DNS is disabled and
  `ts.net` queries are forwarded by dnsmasq to `100.100.100.100`.
- **DNS** is dnsmasq on the router (domain `lan`), upstreaming to
  Cloudflare/Google over WAN. See `roles/router_dhcp`.

## Layout

```
ansible/
├── router.yml                  # play: runs the roles below in order
├── requirements.yml            # collections (community.openwrt pinned to 1.9.0)
├── inventory/prod.yml          # router (LAN IP; travel-router left unmanaged)
└── roles/
    ├── router_common/          # hostname, timezone, logging, NTP
    ├── router_packages/        # apk installs; removes retired WireGuard pkgs
    ├── router_network/         # globals, br-lan, lan, wan, wan6, tailscale iface
    ├── router_dhcp/            # dnsmasq, DHCP pool, RA/odhcpd
    ├── router_firewall/        # zones (incl. tailscale), forwardings, rules
    ├── router_tailscale/       # /etc/config/tailscale + service
    └── router_services/        # dropbear, uhttpd, upnpd, attended sysupgrade
```

Roles use the `community.openwrt` ucode modules (`uci`, `apk`, `service`)
because the router has no Python.

## Usage

```sh
just galaxy-install        # or: ansible-galaxy collection install -r ansible/requirements.yml
cd ansible && ansible-playbook router.yml
```

The playbook is idempotent and does not run automatically.

## Manual steps (not automated)

- **Tailscale node auth** — `tailscale up` is a one-time action:
  ```sh
  ssh root@192.168.1.1 tailscale up \
    --advertise-exit-node \
    --advertise-routes=192.168.0.0/16 \
    --ssh
  ```
- **SSH authorized keys** — the router's `/etc/dropbear/authorized_keys` is
  managed by hand; keys are not stored in this repo.
- **`beaver-cloud.xyz`** was removed from the dnsmasq forwarders (domain is
  retired). Until the play runs, the entry may still exist on the router;
  remove it with `uci del_list dhcp.@dnsmasq[0].server='/beaver-cloud.xyz/192.168.42.53'`.

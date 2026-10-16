# networking

Ansible provisioning for the home network: the home router and its two
wireless access points.

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

## Access points

Two TP-Link EAP245 v3 units, reflashed to OpenWrt, running as **dumb APs**:
they bridge the LAN onto a shared SSID and leave DHCP/RA/DNS to the router.

| | south-ap | north-ap |
|---|---|---|
| Hardware | TP-Link EAP245 v3 (`ath79/generic`) | same |
| OS | OpenWrt 25.12 (apk) | same |
| LAN | `192.168.1.2/16` static | `192.168.1.3/16` static |
| Radios | `radio0` 2.4 GHz (ath9k), `radio1` 5 GHz (ath10k) | same |
| Channels | 2.4 GHz 1, 5 GHz 36 | 2.4 GHz 11, 5 GHz 149 |
| Roaming | 802.11k/v/r, one shared SSID | same |

The SSID and PSK are kept encrypted in `group_vars/aps/vault.yml` (the SSID is
location-revealing), and referenced from `group_vars/aps.yml`. See the manual
steps below. The addresses sit outside the router's DHCP pool, so no
reservations are needed.

## Layout

```
ansible/
├── router.yml                  # play: runs the router roles below in order
├── aps.yml                     # play: provisions the access points
├── requirements.yml            # collections (community.openwrt pinned to 1.9.0)
├── inventory/prod.yml          # router + the two APs (travel-router unmanaged)
├── group_vars/aps.yml          # shared AP vars (references the vault)
├── group_vars/aps/vault.yml    # encrypted SSID + PSK
└── roles/
    ├── router_common/          # hostname, timezone, logging, NTP
    ├── router_packages/        # apk installs; removes retired WireGuard pkgs
    ├── router_network/         # globals, br-lan, lan, wan, wan6, tailscale iface
    ├── router_dhcp/            # dnsmasq, DHCP pool, RA/odhcpd
    ├── router_firewall/        # zones (incl. tailscale), forwardings, rules
    ├── router_tailscale/       # /etc/config/tailscale + service
    ├── router_services/        # dropbear, uhttpd, upnpd, attended sysupgrade
    ├── ap_common/              # hostname, timezone, logging, NTP
    ├── ap_packages/            # luci-ssl, iperf3 (16 MB flash: keep small)
    ├── ap_network/             # br-lan static IP, no WAN, DHCP/RA off
    ├── ap_wireless/            # radio0/radio1, SSID/PSK, 802.11k/v/r
    └── ap_services/            # dropbear, uhttpd/LuCI, disable dnsmasq/odhcpd
```

Roles use the `community.openwrt` ucode modules (`uci`, `apk`, `service`)
because the devices have no Python.

## Usage

```sh
just galaxy-install        # or: ansible-galaxy collection install -r ansible/requirements.yml

just run                   # router
just aps-run               # access points
```

`just check` and `just aps-check` are `--check --diff` dry runs. The AP playbook
needs the vault password for the SSID/PSK; the recipes read it from
`~/.vault_pass` (override with `ANSIBLE_VAULT_PASSWORD_FILE`). The playbooks are
idempotent and do not run automatically.

## Manual steps (not automated)

- **Tailscale node auth** — `tailscale up` is a one-time action:
  ```sh
  ssh root@192.168.1.1 tailscale up \
    --advertise-exit-node \
    --advertise-routes=192.168.0.0/16 \
    --ssh
  ```
- **SSH authorized keys** — the router's and the APs' `/etc/dropbear/
  authorized_keys` are managed by hand; keys are not stored in this repo. Each
  AP needs this workstation's key installed during bootstrap (below).
- **`beaver-cloud.xyz`** was removed from the dnsmasq forwarders (domain is
  retired). Until the play runs, the entry may still exist on the router;
  remove it with `uci del_list dhcp.@dnsmasq[0].server='/beaver-cloud.xyz/192.168.42.53'`.

### Access points (one-time, per AP)

- **Flash OpenWrt** — install the `tplink_eap245-v3-squashfs-factory.bin`
  image (OpenWrt 25.12, `ath79/generic`) through the stock TP-Link web UI.
  TFTP recovery is the fallback if the stock firmware rejects the image.
- **Bootstrap the key and address** — a freshly flashed AP boots OpenWrt at
  `192.168.1.1` (which collides with the router) and has no authorized SSH key.
  Connect it off the LAN, set its final address (`192.168.1.2` / `192.168.1.3`)
  and install this workstation's public key into its
  `/etc/dropbear/authorized_keys`. Only then connect it to the LAN: `aps.yml`
  assumes the AP is already reachable at that address, and a wireless reload
  can briefly drop connectivity (`serial: 1` applies one AP at a time).
- **Set the SSID and PSK** — both live encrypted in the vault:
  ```sh
  ansible-vault edit ansible/group_vars/aps/vault.yml
  ```
  The playbook refuses to run while they are still `REPLACE_ME_*`. The vault
  password is in `~/.vault_pass`; back it up — without it the vault cannot be
  decrypted. `aps-check` redacts the SSID/PSK in its `--diff` output.
- **Firmware upgrades** stay manual; `sysupgrade` is not automated.

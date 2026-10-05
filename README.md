<p align="center">
  <img src="assets/logo.png" alt="Ojo al Clic" width="180">
</p>

<h1 align="center">ojoalclic-ejpt</h1>

<p align="center">
  eJPTv2 pivot lab by OjoAlClic · Instagram <a href="https://instagram.com/ojoalclic">@ojoalclic</a>
</p>

A pentesting lab to practice pivoting and the services you run into on the eJPTv2, all in one place. You clone the repo, run `vagrant up`, and it builds an isolated internal network that you can only reach by compromising a dual-homed host and tunneling through it, the same way the exam works. It runs on Windows, macOS and Linux.

I built it because I couldn't find a free lab that had the pivoting part together with all the services the cert covers (SMB, FTP, SSH, SNMP, rsync, WebDAV, WordPress, Shellshock, RDP, WinRM). They were scattered across separate VMs or behind a paywall, so I put everything into a single lab and left it free.

```
  YOUR KALI ──Red A (host-only 192.168.56.0/24)──►  gateway (dual-homed)
                                                       │  also on Red B
                                     Red B (internal, isolated) 172.16.50.0/24
                                   ┌──────────────┴───────────────┐
                              services-box 172.16.50.22      windows 172.16.50.23
                              (Linux services)               (SMB / RDP / WinRM)
```

The internal hosts (`.22`, `.23`) are not reachable from your Kali directly. You have to exploit the gateway and tunnel through it.

## Requirements
- [VirtualBox](https://www.virtualbox.org/) 6.1+ (7.x recommended)
- [Vagrant](https://www.vagrantup.com/) 2.3+
- Around 40 GB free disk and 16 GB RAM (the lab uses about 9 GB with all VMs running)
- Your own attacker VM (Kali or Parrot). See "Attach your attacker" below.

## Quick start
```bash
git clone https://github.com/mequerejeta/ojoalclic-ejpt
cd ojoalclic-ejpt
vagrant up            # downloads the boxes and builds everything (first run is long)
```
Manage it:
```bash
vagrant halt          # power off the lab
vagrant up            # power it back on
vagrant destroy -f    # delete the lab VMs
```

## Attach your attacker (Kali)
Your Kali needs an interface on Red A (192.168.56.0/24) to reach the gateway:
1. In VirtualBox, add a Host-Only Adapter to your Kali on the same network Vagrant created (192.168.56.0/24), or
2. set a NIC to that host-only network and give Kali something like 192.168.56.50.

Then from Kali run `nmap -sn 192.168.56.0/24` and you'll see the gateway at `.101`. You can keep a NAT interface too if you want Internet on Kali, it won't break the isolation.

## What's inside (attack surface)
gateway `192.168.56.101` (rapid7/metasploitable3-ub1404), a service-rich Linux box: SSH, Samba, web apps, databases and more. This is your foothold and your pivot.

services-box `172.16.50.22` (internal), intentionally vulnerable:
| Port | Service | Technique |
|------|---------|-----------|
| 873 | rsync (module `public`, no auth) | anonymous list/read |
| 161/udp | SNMP (community `public`) | `snmpwalk` enum |
| 80 `/webdav` | WebDAV (no auth) | `PUT` webshell |
| 8000 | WordPress 5.0 (`admin:password`, `bob:bob123`) | `wpscan`, user enum |
| 8080 `/cgi-bin/vuln.cgi` | Shellshock (CVE-2014-6271) | `User-Agent` RCE |

windows `172.16.50.23` (internal, rapid7/metasploitable3-win2k8): SMB, RDP, WinRM (`vagrant:vagrant`), IIS, Jenkins, Tomcat, GlassFish, ElasticSearch and more.

## The pivot (the whole point)
1. Enumerate Red A and find the gateway (`192.168.56.101`).
2. Exploit the gateway to get a shell.
3. From Kali/Metasploit, route Network B through that session and start a SOCKS proxy:
   ```
   use post/multi/manage/autoroute   (set SESSION, SUBNET 172.16.50.0) ; run
   use auxiliary/server/socks_proxy  (VERSION 5, SRVPORT 1080) ; run -j
   ```
   Then point `proxychains` at `socks5 127.0.0.1 1080`.
4. Scan and attack the internal hosts through the tunnel (TCP connect only):
   ```
   proxychains -q nmap -sT -Pn -p- 172.16.50.0/24 --open
   ```

> Heads up: a direct `nmap -sn 172.16.50.0/24` from Kali shows false positives (the NAT answers the probes). You only map the internal network correctly through the pivot.

## Legal and safety
These VMs are intentionally vulnerable. Run them only inside this isolated lab. Never bridge them to your LAN or expose them to the Internet. This is for education and authorized practice only.

The repo ships automation only. It downloads the VM images from their official sources on first run, and nothing vulnerable or licensed is redistributed here.

## Sources and credits
Every component is pulled from its official source on the first `vagrant up`. Nothing vulnerable or licensed is hosted in this repo.

| Component | Source | License / terms |
|-----------|--------|-----------------|
| gateway | [`rapid7/metasploitable3-ub1404`](https://app.vagrantup.com/rapid7/boxes/metasploitable3-ub1404) (Rapid7) | BSD-3-Clause |
| windows | [`rapid7/metasploitable3-win2k8`](https://app.vagrantup.com/rapid7/boxes/metasploitable3-win2k8) (Rapid7), includes a Microsoft Windows evaluation OS | Rapid7 BSD-3-Clause + Microsoft eval terms |
| services base | [`bento/ubuntu-20.04`](https://app.vagrantup.com/bento/boxes/ubuntu-20.04) (Chef Bento) | MIT |
| WordPress + DB | official [`wordpress`](https://hub.docker.com/_/wordpress) + [`mariadb`](https://hub.docker.com/_/mariadb) Docker images | GPLv2 |
| Shellshock container | built locally from `ubuntu:20.04` + GNU [`bash 4.3`](https://ftp.gnu.org/gnu/bash/) source | GPLv3 (bash) |

[Metasploitable3](https://github.com/rapid7/metasploitable3) is a Rapid7 project. Please respect each upstream's license and terms of use.

## Notes and troubleshooting
- First boot takes a while. The metasploitable3 boxes start a lot of services after booting, so give the gateway and Windows around 5 to 10 minutes before everything responds.
- The gateway box has no Guest Additions (that comes from the upstream box). The Vagrantfile handles it: it disables the `/vagrant` synced folder on the gateway and uses password auth (`vagrant:vagrant`) with key insertion, so `vagrant ssh gateway` still works.
- Through a SOCKS pivot, scan with `-sT -Pn` only (no `-sS`, no UDP, no `-O`).
- Don't run two labs on 192.168.56.0/24 at the same time or the IPs clash. Halt one first.

## License
MIT. See [LICENSE](LICENSE).

---

<p align="center">
  Made by OjoAlClic · Instagram <a href="https://instagram.com/ojoalclic">@ojoalclic</a> · AppSec, hacking ético, ciberseguridad
</p>

If the lab helped you, a star on the repo is appreciated.

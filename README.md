<p align="center">
  <img src="assets/logo.png" alt="Ojo al Clic — AppSec / Hacking Ético / Ciberseguridad" width="180">
</p>

<h1 align="center">ojoalclic-ejpt 🧪</h1>

<p align="center">
  <b>eJPTv2 Pivot Lab</b> by <b>OjoAlClic</b> — 📸 Instagram:
  <a href="https://instagram.com/ojoalclic">@ojoalclic</a>
</p>

A self-contained, **one-command** penetration-testing lab to practice **pivoting**
and multi-service exploitation — built for people studying the **eJPTv2** (or anyone
learning network pentesting). Cross-platform: **Windows, macOS, Linux**.

Clone it, run `vagrant up`, and you get an isolated internal network you can only
reach by **compromising a dual-homed host and pivoting** — just like the exam.

```
  YOUR KALI ──Red A (host-only 192.168.56.0/24)──►  gateway (dual-homed)
                                                       │  also on Red B
                                     Red B (internal, isolated) 172.16.50.0/24
                                   ┌──────────────┴───────────────┐
                              services-box 172.16.50.22      windows 172.16.50.23
                              (Linux services)               (SMB/RDP/WinRM/…)
```

The internal hosts (`.22`, `.23`) are **not reachable from your Kali directly** —
you must exploit the gateway and tunnel through it.

---

## Requirements
- [VirtualBox](https://www.virtualbox.org/) 6.1+ (7.x recommended)
- [Vagrant](https://www.vagrantup.com/) 2.3+
- ~**40 GB** free disk, **16 GB RAM** recommended (lab uses ~9 GB when all VMs run)
- Your own attacker VM (Kali/Parrot) — see "Attach your attacker" below

## Quick start
```bash
git clone <this-repo> ejpt-pivot-lab
cd ejpt-pivot-lab
vagrant up            # downloads boxes + builds everything (first run is long)
```
Manage it:
```bash
vagrant halt          # power off the lab
vagrant up            # power it back on
vagrant destroy -f    # delete the lab VMs
```

## Attach your attacker (Kali)
Your Kali needs an interface on **Red A (192.168.56.0/24)** to reach the gateway:
1. In VirtualBox, add a **Host-Only Adapter** to your Kali on the same network
   Vagrant created (`192.168.56.0/24`), or
2. set a NIC to that host-only network and give Kali e.g. `192.168.56.50`.

Then from Kali: `nmap -sn 192.168.56.0/24` → you'll see the **gateway** (`.101`).
Keep a NAT interface too if you want Internet on Kali (it won't break isolation).

## What's inside (attack surface)
**gateway `192.168.56.101`** (rapid7/metasploitable3-ub1404) — service-rich Linux:
SSH, Samba, web apps, databases, and more. Your foothold + pivot box.

**services-box `172.16.50.22`** (internal) — intentionally vulnerable:
| Port | Service | Technique |
|------|---------|-----------|
| 873 | rsync (module `public`, no auth) | anonymous list/read |
| 161/udp | SNMP (community `public`) | `snmpwalk` enum |
| 80 `/webdav` | WebDAV (no auth) | `PUT` webshell |
| 8000 | WordPress 5.0 (`admin:password`, `bob:bob123`) | `wpscan`, user enum |
| 8080 `/cgi-bin/vuln.cgi` | Shellshock (CVE-2014-6271) | `User-Agent` RCE |

**windows `172.16.50.23`** (internal, rapid7/metasploitable3-win2k8):
SMB, RDP, WinRM (`vagrant:vagrant`), IIS, Jenkins, Tomcat, GlassFish, ElasticSearch, …

## The pivot (the whole point)
1. Enumerate Red A → find the gateway (`192.168.56.101`).
2. Exploit the gateway → get a shell.
3. From Kali/Metasploit, route Network B through that session + start a SOCKS proxy:
   ```
   use post/multi/manage/autoroute   (set SESSION, SUBNET 172.16.50.0) ; run
   use auxiliary/server/socks_proxy  (VERSION 5, SRVPORT 1080) ; run -j
   ```
   `proxychains` → `socks5 127.0.0.1 1080`
4. Scan/attack the internal hosts **through the tunnel** (TCP connect only):
   ```
   proxychains -q nmap -sT -Pn -p- 172.16.50.0/24 --open
   ```

> Tip: a direct `nmap -sn 172.16.50.0/24` from Kali shows **false positives** (NAT
> answers the probes). The internal network is only mapped correctly **through the pivot**.

## ⚠️ Legal / safety
These VMs are **intentionally vulnerable**. Run them **only** in this isolated lab.
**Never** bridge them to your LAN or expose them to the Internet. For education and
authorized practice only.

This repo ships **automation only** — it downloads the VM images from their official
sources on first run; no vulnerable or licensed images are redistributed here.

## Sources & credits
Every component is pulled from its **official source** on first `vagrant up`.
Nothing vulnerable or licensed is hosted in this repo.

| Component | Source | License / terms |
|-----------|--------|-----------------|
| gateway | [`rapid7/metasploitable3-ub1404`](https://app.vagrantup.com/rapid7/boxes/metasploitable3-ub1404) (Rapid7) | BSD-3-Clause |
| windows | [`rapid7/metasploitable3-win2k8`](https://app.vagrantup.com/rapid7/boxes/metasploitable3-win2k8) (Rapid7) — includes a Microsoft Windows **evaluation** OS | Rapid7 BSD-3-Clause + Microsoft eval terms |
| services base | [`bento/ubuntu-20.04`](https://app.vagrantup.com/bento/boxes/ubuntu-20.04) (Chef Bento) | MIT |
| WordPress + DB | official [`wordpress`](https://hub.docker.com/_/wordpress) + [`mariadb`](https://hub.docker.com/_/mariadb) Docker images | GPLv2 |
| Shellshock container | built locally from `ubuntu:20.04` + GNU [`bash 4.3`](https://ftp.gnu.org/gnu/bash/) source | GPLv3 (bash) |

[Metasploitable3](https://github.com/rapid7/metasploitable3) is a Rapid7 project.
Please respect each upstream's license and terms of use.

## Notes / troubleshooting
- **First boot takes time.** The metasploitable3 boxes start many services *after*
  boot — give the gateway/Windows ~5–10 min before everything responds.
- **Gateway box has no Guest Additions** (upstream box). That's expected: the
  Vagrantfile disables its `/vagrant` synced folder and uses password auth
  (`vagrant:vagrant`) with key insertion. `vagrant ssh gateway` works fine.
- **Through a SOCKS pivot, scan with `-sT -Pn` only** (no `-sS`, no UDP, no `-O`).
- **Don't run two labs on `192.168.56.0/24` at once** (IP clashes). Halt one first.

## License
MIT — see [LICENSE](LICENSE).

---

<p align="center">
  Made by <b>OjoAlClic</b> · 📸 <a href="https://instagram.com/ojoalclic">@ojoalclic</a>
  · AppSec / Hacking Ético / Ciberseguridad · ⭐ the repo if it helped!
</p>

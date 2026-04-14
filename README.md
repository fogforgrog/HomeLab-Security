# &#x20;HomeLab Security Stack

A production-grade home network security lab built on a **Raspberry Pi 4** and **ThinkPad L570**, implementing IPS, SIEM, automated threat response, and SOAR — using entirely open-source tools.



## Table of Contents

* [Overview](#overview)
* [Hardware](#hardware)
* [Architecture](#architecture)
* [Step 1 — DNS Security](#step-1--dns-security)
* [Step 2 — IPS + SIEM](#step-2--ips--siem)
* [Step 3 — Automated Response](#step-3--automated-response)
* [Roadmap](#roadmap)
* [Key Lessons Learned](#key-lessons-learned)

\---

## Overview

|Component|Tool|Purpose|
|-|-|-|
|DNS Filtering|Pi-hole v6|Block malicious domains (311k+ entries)|
|Recursive DNS|Unbound|Privacy-preserving DNS resolution|
|IPS|Suricata 7.0.10|Deep packet inspection, 49k+ rules|
|Firewall|nftables|Packet filtering + NFQueue for IPS|
|SIEM|Grafana + Loki|Log aggregation and dashboards|
|Log Shipping|Grafana Alloy|Pi → Laptop log pipeline|
|Auto-blocking|Fail2ban|Automated IP banning|
|Alerts|Telegram Bot|Real-time security notifications|
|SOAR|Shuffle|Security workflow orchestration|

\---

## Hardware

### Raspberry Pi 4 (Security Gateway)

* **IP**: `10.0.0.49` (eth0) / `10.0.0.50` (wlan0)
* **OS**: Raspberry Pi OS Lite arm64
* **Role**: Pi-hole, Unbound, Suricata IPS, Fail2ban, nftables

### ThinkPad L570 (SIEM Server)

* **IP**: `10.0.0.30`
* **OS**: Debian 13
* **Role**: Grafana, Loki, Shuffle SOAR (Docker)

\---

## Architecture

```
Internet
    │
    ▼
A1 ISP Router (10.0.0.138)
    │
    ▼
Raspberry Pi 4
├── Pi-hole (DNS filtering, port 53/80/443)
├── Unbound (recursive DNS, 127.0.0.1:5335)
├── Suricata IPS (NFQueue mode, 49k+ rules)
├── nftables (firewall + IPS queue)
└── Fail2ban (auto-ban + Telegram alerts)
    │
    │ Grafana Alloy (log shipping)
    ▼
ThinkPad L570 (Docker)
├── Loki (log storage, port 3100)
├── Grafana (dashboards, port 3000)
└── Shuffle SOAR (workflows, port 3001)
    │
    ▼
 Telegram Bot
(real-time alerts)
```

\---

## Step 1 — DNS Security

### Components

* **Pi-hole v6** — DNS-level ad and malware blocking
* **Unbound** — recursive, validating DNS resolver (no upstream provider)

### Features

* 311,000+ blocked domains
* DNSSEC validation
* DNS-over-TLS capable
* Custom local DNS records (`.lan` TLD)
* 4 clients configured

### Config Files

* [`configs/pi/pihole/`](configs/pi/pihole/) — Pi-hole configuration
* [`configs/pi/unbound/`](configs/pi/unbound/) — Unbound configuration

\---

## Step 2 — IPS + SIEM

### Components

* **Suricata 7.0.10** — Network IPS in NFQueue mode
* **nftables** — Firewall with NFQueue integration
* **Grafana + Loki** — SIEM stack
* **Grafana Alloy** — Log shipping agent

### Suricata Features

* 49,268 rules loaded (ET Open ruleset)
* NFQueue mode (`mode: accept`, `fail-open: yes`)
* Detects: Tor relays, malicious TLDs, DNS anomalies, known attack signatures
* Logs: `fast.log` (alerts), `eve.json` (full events)

### nftables Design

```
Input chain:
  lo → accept
  ct state invalid → drop
  ct state established,related → accept
  tcp/udp → queue to Suricata (NFQueue 0)
  icmp → accept
```

### SIEM Log Sources

|Job Label|Source|Content|
|-|-|-|
|`suricata` / `fast`|`/var/log/suricata/fast.log`|IPS alerts|
|`suricata` / `eve`|`/var/log/suricata/eve.json`|Full events|
|`pihole` / `dns`|`/var/log/pihole/pihole.log`|DNS queries|
|`pihole` / `ftl`|`/var/log/pihole/FTL.log`|FTL engine|
|`security`|`/var/log/fail2ban.log`|Ban events|

### Config Files

* [`configs/pi/nftables/nftables.conf`](configs/pi/nftables/nftables.conf)
* [`configs/pi/suricata/`](configs/pi/suricata/)
* [`configs/laptop/docker/docker-compose.yml`](configs/laptop/docker/docker-compose.yml)

\---

## Step 3 — Automated Response

### Components

* **Fail2ban** — Suricata alert-driven auto-blocking
* **Telegram Bot** — Real-time alerts
* **Shuffle SOAR** — Workflow orchestration

### Fail2ban Suricata Jail

* Watches `/var/log/suricata/fast.log`
* Custom regex extracts source IPs from Suricata format
* LAN (`10.0.0.0/24`) always whitelisted
* Bans external IPs via nftables
* 3 hits in 60 seconds → 1 hour ban

### Telegram Alert Pipeline

```
Threat detected → Suricata → fast.log
                                  ↓
                            Fail2ban reads
                                  ↓
                         Shell script called
                                  ↓
                    Shuffle webhook (structured JSON)
                                  ↓
                         Telegram message:
                    " Fail2Ban Alert
                     Action: banned
                     IP: x.x.x.x
                     Jail: suricata-high
                     Time: 2026-04-12 15:36:48"
```

### Alert Types

|Event|Channel|Format|
|-|-|-|
|Fail2ban start/stop|Direct Telegram|Simple text|
|IP banned|Shuffle → Telegram|Structured JSON|
|IP unbanned|Shuffle → Telegram|Structured JSON|

### Config Files

* [`configs/pi/fail2ban/`](configs/pi/fail2ban/)
* [`scripts/fail2ban-telegram.sh`](scripts/fail2ban-telegram.sh)

\---

## Roadmap

### Step 4 — Threat Intelligence (Planned)

* \[ ] RAM upgrade (ThinkPad L570 → 32GB)
* \[ ] TheHive — incident management
* \[ ] Cortex — automated IP enrichment (VirusTotal, AbuseIPDB)
* \[ ] MISP — threat intelligence feeds
* \[ ] Wazuh HIDS — host intrusion detection
* \[ ] Shuffle enrichment workflows

### Step 5 — Hardware Upgrade (Planned)

* \[ ] Protectli VP2410 — dedicated firewall/IPS router
* \[ ] TP-Link TL-SG108E — managed switch with VLANs
* \[ ] Full inline traffic inspection
* \[ ] Network segmentation (Trusted / IoT / Lab VLANs)

\---

## Key Lessons Learned

### 1\. NFQueue Mode Selection

`mode: accept` is simpler and more reliable than `mode: repeat` for home setups. `repeat` mode requires nftables mark rules and can cause connectivity issues if misconfigured.

### 2\. Fail2ban Regex Testing

Always test with `fail2ban-regex` before deploying:

```bash
fail2ban-regex /var/log/suricata/fast.log /etc/fail2ban/filter.d/suricata.conf
```

A bad regex extracted `0.0.0.3` from log metadata — always verify matches.

### 3\. Shell Scripts Over Inline Commands

Complex curl commands with dynamic content (timestamps, variables) belong in dedicated shell scripts, not inline Fail2ban action definitions.

### 4\. SOAR Complexity

Shuffle requires Orborus + OpenSearch + proper authentication before it adds value. Start with direct API calls, add orchestration once the pipeline is stable.

### 5\. Always Set Recovery Net Before Firewall Changes

```bash
echo "sudo nft flush ruleset \&\& sudo nft -f /etc/nftables.conf.bak" | at now + 3 minutes
```

Learned this the hard way — a bad nftables rule locked out SSH, requiring physical access.

### 6\. LAN Whitelist is Critical

```ini
ignoreip = 127.0.0.1/8 10.0.0.0/24
```

Without this, Suricata DNS alerts would cause Fail2ban to ban your own devices.

\---

## Grafana Queries

```logql
# All Suricata alerts
{job="suricata", type="fast"}

# High priority only
{job="suricata", type="fast"} |= "Priority: 1"

# DNS anomalies
{job="suricata", type="fast"} |= "DNS"

# Fail2ban bans
{job="security"} |= "Ban"

# Pi-hole blocked queries
{job="pihole", type="dns"} |= "blocked"
```

\---

## License

MIT — feel free to use, adapt, and share.

\---

*Built as a practical Purple Team learning project. All tools are open-source.*


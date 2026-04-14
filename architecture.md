# Architecture Documentation

## Network Topology

```
                    ┌─────────────────┐
                    │  Internet/ISP   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  A1 ISP Router  │
                    │  10.0.0.138     │
                    └────────┬────────┘
                             │ 10.0.0.0/24 LAN
              ┌──────────────┼──────────────┐
              │              │              │
     ┌────────▼────────┐     │     ┌────────▼────────┐
     │  Raspberry Pi 4 │     │     │  ThinkPad L570  │
     │  10.0.0.49 eth0 │     │     │  10.0.0.30      │
     │  10.0.0.50 wlan0│     │     │  Debian 13      │
     └────────┬────────┘     │     └────────┬────────┘
              │              │              │
     ┌────────▼────────┐     │     ┌────────▼────────┐
     │    Pi-hole v6   │     │     │     Docker      │
     │    Unbound      │     │     │  ┌───────────┐  │
     │    Suricata IPS │     │     │  │   Loki    │  │
     │    nftables     │     │     │  │  Grafana  │  │
     │    Fail2ban     │     │     │  │  Shuffle  │  │
     │    Alloy        │─────┼────▶│  └───────────┘  │
     └─────────────────┘     │     └─────────────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
     ┌────────▼──┐  ┌────────▼──┐  ┌───────▼────┐
     │    PC     │  │  Phones   │  │   Tablets  │
     │10.0.0.194 │  │10.0.0.10  │  │            │
     └───────────┘  └───────────┘  └────────────┘
```

## Traffic Flow

### DNS Query Flow
```
Device → Pi-hole (port 53)
              │
              ├── Domain blocked? → SINKHOLE (0.0.0.0)
              │
              └── Domain allowed? → Unbound (127.0.0.1:5335)
                                          │
                                          └── Root DNS servers
                                              (recursive resolution)
```

### IPS Inspection Flow
```
Packet arrives at Pi eth0/wlan0
              │
              ▼
         nftables INPUT chain
              │
              ├── loopback → accept
              ├── ct invalid → drop
              ├── ct established → accept (skip re-inspection)
              │
              └── TCP/UDP → NFQueue 0
                                │
                           Suricata IPS
                                │
                    ┌───────────┴───────────┐
                    │                       │
              Rule matches?           No match
                    │                       │
              Alert + accept           accept
                    │
              fast.log entry
                    │
              Fail2ban reads
                    │
              External IP?
                    │
              ┌─────┴─────┐
              │           │
           Yes (ban)    No (LAN)
              │           │
         nftables       ignore
          ban rule
              │
         Telegram
          alert
```

### Log Shipping Flow
```
Raspberry Pi logs:
  /var/log/suricata/fast.log    ─┐
  /var/log/suricata/eve.json    ─┤
  /var/log/pihole/pihole.log    ─┤─→ Grafana Alloy ──→ Loki (10.0.0.30:3100)
  /var/log/pihole/FTL.log       ─┤                         │
  /var/log/fail2ban.log         ─┤                    Grafana (port 3000)
  /var/log/auth.log             ─┘                    Dashboards + Alerts
```

## Port Reference

### Raspberry Pi (10.0.0.49)
| Port | Protocol | Service | Exposed To |
|------|----------|---------|------------|
| 22 | TCP | SSH | LAN |
| 53 | TCP/UDP | Pi-hole DNS | LAN |
| 80 | TCP | Pi-hole Web UI | LAN |
| 443 | TCP | Pi-hole Web UI (TLS) | LAN |
| 5335 | UDP | Unbound | localhost only |
| 12345 | TCP | Grafana Alloy | localhost only |

### ThinkPad L570 (10.0.0.30)
| Port | Protocol | Service | Exposed To |
|------|----------|---------|------------|
| 22 | TCP | SSH | LAN |
| 3000 | TCP | Grafana | LAN |
| 3001 | TCP | Shuffle SOAR | LAN |
| 3100 | TCP | Loki | LAN |
| 5001 | TCP | Shuffle Backend | Docker internal |
| 9200 | TCP | OpenSearch | Docker internal |

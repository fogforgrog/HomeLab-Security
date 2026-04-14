# Installation Guide

## Prerequisites

### Raspberry Pi 4
- Raspberry Pi OS Lite arm64
- Static IP configured (`10.0.0.49`)
- SSH access with key authentication

### ThinkPad L570 (or any Debian machine)
- Debian 13
- Docker + docker-compose installed
- Static IP (`10.0.0.30`)

---

## Step 1 — Pi-hole + Unbound

### Install Pi-hole v6
```bash
curl -sSL https://install.pi-hole.net | bash
```

### Install Unbound
```bash
sudo apt install unbound -y
```

### Configure Pi-hole to use Unbound
In Pi-hole admin → Settings → DNS:
- Uncheck all upstream DNS providers
- Set custom DNS: `127.0.0.1#5335`

### Add blocklists
Recommended lists:
- `https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts`
- `https://urlhaus.abuse.ch/downloads/rpz/`

---

## Step 2 — Suricata IPS

### Install Suricata
```bash
sudo apt install suricata suricata-update -y
```

### Update rules
```bash
sudo suricata-update
```

### Configure NFQueue mode
Edit `/etc/suricata/suricata.yaml`:
```yaml
nfq:
  mode: accept
  fail-open: yes
```

### Load kernel module
```bash
sudo modprobe nfnetlink_queue
echo "nfnetlink_queue" | sudo tee /etc/modules-load.d/nfqueue.conf
```

### Apply nftables
```bash
sudo cp configs/pi/nftables/nftables.conf /etc/nftables.conf
sudo systemctl restart nftables
```

### Start Suricata
```bash
sudo systemctl restart suricata
# Verify queue bound:
cat /proc/net/netfilter/nfnetlink_queue
```

---

## Step 2 — SIEM Stack (Laptop)

### Deploy Docker stack
```bash
mkdir -p ~/siem && cd ~/siem
cp configs/laptop/docker/docker-compose.yml .
mkdir -p shuffle-apps shuffle-files
docker-compose up -d
```

### Install Grafana Alloy (on Pi)
```bash
# Follow official Grafana Alloy install for ARM64
# https://grafana.com/docs/alloy/latest/install/linux/
sudo cp configs/pi/alloy/config.alloy /etc/alloy/config.alloy
sudo systemctl restart alloy
```

### Configure Grafana
1. Open `http://10.0.0.30:3000` (admin/changeme)
2. Add Loki datasource: `http://loki:3100`
3. Create dashboards using queries from README

---

## Step 3 — Automated Response

### Install Fail2ban
```bash
sudo apt install fail2ban -y
```

### Configure jails
```bash
sudo cp configs/pi/fail2ban/fail2ban.conf /etc/fail2ban/jail.local
# Create filter:
sudo nano /etc/fail2ban/filter.d/suricata.conf
# Create action:
sudo nano /etc/fail2ban/action.d/telegram.conf
```

### Install Telegram script
```bash
sudo cp scripts/fail2ban-telegram.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/fail2ban-telegram.sh
# Edit script with your Shuffle webhook URL
sudo nano /usr/local/bin/fail2ban-telegram.sh
```

### Create Telegram Bot
1. Message `@BotFather` on Telegram
2. `/newbot` → get token
3. Get chat ID: `https://api.telegram.org/bot<TOKEN>/getUpdates`

### Configure Shuffle
1. Open `http://10.0.0.30:3001`
2. Register admin account
3. Create workflow: Webhook → Telegram
4. Copy webhook URL to `fail2ban-telegram.sh`

### Start everything
```bash
sudo systemctl restart fail2ban
# Test:
sudo fail2ban-client set sshd banip 9.8.7.6
# Check Telegram for alert
sudo fail2ban-client set sshd unbanip 9.8.7.6
```

---

## Verification

### Check Suricata is inspecting traffic
```bash
sudo suricatasc -c dump-counters | grep '"pkts"'
# pkts should be > 0
```

### Check Fail2ban jails
```bash
sudo fail2ban-client status
sudo fail2ban-client status sshd
sudo fail2ban-client status suricata-high
```

### Check logs flowing to Loki
```bash
curl -s 'http://10.0.0.30:3100/loki/api/v1/query?query={job="suricata"}' | python3 -m json.tool
```

### Test alert pipeline end-to-end
```bash
# From another machine:
curl -4 -A "BlackSun" http://10.0.0.49/
# Check fast.log on Pi:
sudo tail -f /var/log/suricata/fast.log
```

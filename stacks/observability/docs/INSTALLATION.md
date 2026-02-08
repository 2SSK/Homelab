# Installation Guide

**Comprehensive setup instructions for the Homelab Observability Stack**

---

## Table of Contents

- [Pre-Installation Checklist](#pre-installation-checklist)
- [Installation Methods](#installation-methods)
- [Step-by-Step Installation](#step-by-step-installation)
- [Initial Configuration](#initial-configuration)
- [Verification Steps](#verification-steps)
- [Post-Installation Tasks](#post-installation-tasks)
- [Uninstallation](#uninstallation)
- [Troubleshooting Installation](#troubleshooting-installation)

---

## Pre-Installation Checklist

Before beginning installation, verify you have:

### ✅ System Requirements

- [ ] Linux system (Ubuntu 20.04+, Debian 11+, or RHEL 8+)
- [ ] 4GB RAM minimum (6GB recommended)
- [ ] 20GB free disk space
- [ ] 2+ CPU cores
- [ ] Root or sudo access

### ✅ Software Prerequisites

```bash
# Check Docker installation
docker --version
# Expected: Docker version 20.10.0 or higher

# Check Docker Compose (v2 syntax required)
docker compose version
# Expected: Docker Compose version v2.0.0 or higher

# Check systemd
systemctl --version
# Expected: systemd 237 or higher

# Optional: Validation tools
promtool --version  # For alert rule validation (optional)
```

### ✅ Network Requirements

- [ ] Outbound internet access for pulling Docker images
- [ ] Ports 3000, 9090, 9093, 3100 available on localhost
- [ ] SSH access configured for port forwarding

### ✅ Planning Decisions

- [ ] Choose installation method (systemd or standalone)
- [ ] Decide on Grafana admin password (required)
- [ ] Determine alert notification method (email/Slack/PagerDuty)
- [ ] Configure SMTP for email alerts (if using)

---

## Installation Methods

### Method 1: Systemd Integration (Recommended)

**Pros:**
- Automatic startup on boot
- Managed with standard `systemctl` commands
- Integrated with system logs
- Hot reload capability for config updates

**Best for:** Production homelab deployment

### Method 2: Standalone Docker Compose

**Pros:**
- Simpler initial setup
- More manual control
- Easier for testing/development

**Best for:** Testing, development, or non-systemd systems

---

## Step-by-Step Installation

### Step 1: Clone Repository

```bash
# Navigate to preferred location (e.g., /opt)
cd /opt

# Clone repository
sudo git clone https://github.com/yourusername/Homelab.git
cd Homelab/stacks/observability

# Verify files
ls -la
# Expected: compose.yaml, prometheus/, grafana/, loki/, etc.
```

**Verification:**
```bash
# Check directory structure
tree -L 2 .
```

---

### Step 2: Create Data Directories

These directories persist your monitoring data across container restarts.

```bash
# Create directory structure
sudo mkdir -p /srv/data/observability/{prometheus,grafana,loki,alertmanager,promtail}

# Set ownership for Prometheus (runs as nobody:nogroup = 65534:65534)
sudo chown -R 65534:65534 /srv/data/observability/prometheus

# Set ownership for Grafana (runs as user 472)
sudo chown -R 472:472 /srv/data/observability/grafana

# Set ownership for Loki (runs as user 10001)
sudo chown -R 10001:10001 /srv/data/observability/loki

# Set ownership for Alertmanager (uses same user as Prometheus)
sudo chown -R 65534:65534 /srv/data/observability/alertmanager

# Promtail can use root ownership
sudo chown -R root:root /srv/data/observability/promtail
```

**Verification:**
```bash
ls -ln /srv/data/observability/
# Expected output showing correct UIDs:
# drwxr-xr-x 2 65534 65534 ... prometheus
# drwxr-xr-x 2   472   472 ... grafana
# drwxr-xr-x 2 10001 10001 ... loki
```

**Why these specific UIDs?**
- These match the non-root users inside the Docker containers
- Prevents permission denied errors when containers try to write data
- Security best practice: containers don't run as root

---

### Step 3: Configure Environment Variables

```bash
# Copy template
cp .env.example .env

# Secure the file (contains passwords)
chmod 600 .env

# Edit configuration
nano .env
```

**Required Configuration:**

```bash
# REQUIRED: Set a strong admin password
GRAFANA_ADMIN_PASSWORD=<generate-strong-password-here>

# RECOMMENDED: Configure SMTP for alert emails
SMTP_HOST=smtp.gmail.com:587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=<app-specific-password>  # NOT your regular password
SMTP_FROM=homelab-alerts@yourdomain.com
ALERT_EMAIL=admin@yourdomain.com
```

**Gmail App Password Setup:**
1. Enable 2FA on Google account
2. Go to https://myaccount.google.com/apppasswords
3. Generate app password for "Mail"
4. Use that password in `SMTP_PASSWORD`

**Verification:**
```bash
# Check .env exists and has correct permissions
ls -la .env
# Expected: -rw------- (600 permissions)

# Verify required variables are set
grep -E "GRAFANA_ADMIN_PASSWORD|SMTP_HOST" .env
# Should show your configured values
```

---

### Step 4: Generate Alertmanager Configuration

Alertmanager config contains SMTP credentials and must be generated from template:

```bash
# Method A: Using envsubst (if available)
envsubst < alertmanager/alertmanager.yml.template > alertmanager/alertmanager.yml

# Method B: Manual replacement
# Edit alertmanager/alertmanager.yml.template and replace:
# __SMTP_HOST__ → your SMTP host
# __SMTP_USER__ → your SMTP username
# __SMTP_PASSWORD__ → your SMTP password
# __SMTP_FROM__ → your from address
# __ALERT_EMAIL__ → your alert recipient
```

**Verification:**
```bash
# Check that placeholders are replaced
grep -E "__(SMTP|ALERT)" alertmanager/alertmanager.yml
# Should return NO results if done correctly

# Verify SMTP settings
grep "smtp_smarthost:" alertmanager/alertmanager.yml
# Should show your actual SMTP host, not __SMTP_HOST__
```

---

### Step 5A: Install with Systemd (Recommended)

```bash
# Create systemd directory for configs
sudo mkdir -p /srv/docker/observability

# Symlink compose file (keeps config in git)
sudo ln -sf $(pwd)/compose.yaml /srv/docker/observability/compose.yaml

# Copy .env file (NOT symlinked - contains secrets)
sudo cp .env /srv/docker/observability/.env
sudo chmod 600 /srv/docker/observability/.env

# Install systemd service unit
sudo cp systemd/observability.service /etc/systemd/system/

# Reload systemd to recognize new service
sudo systemctl daemon-reload

# Enable service (start on boot)
sudo systemctl enable observability

# Start service
sudo systemctl start observability
```

**Verification:**
```bash
# Check service status
sudo systemctl status observability
# Expected: "active (running)"

# Check if containers started
docker compose -f /srv/docker/observability/compose.yaml ps
# Expected: All services showing "Up" status

# View startup logs
journalctl -u observability -f
# Press Ctrl+C to exit
```

---

### Step 5B: Install with Docker Compose (Alternative)

```bash
# Start stack
docker compose up -d

# Verify all services started
docker compose ps
```

**Verification:**
```bash
# Check container status
docker compose ps
# Expected: STATE showing "Up" for all services

# Check logs for errors
docker compose logs | grep -i error
# Should see minimal/no errors (some startup warnings are normal)
```

---

### Step 6: Wait for Health Checks

Services have health checks that must pass before they're ready:

```bash
# Watch health status (refresh every 2 seconds)
watch -n 2 'docker compose ps --format "table {{.Name}}\t{{.Status}}"'

# Alternative: One-time check
docker ps --format "table {{.Names}}\t{{.Status}}"
```

**Expected Timeline:**
- Prometheus: 30 seconds (starts immediately)
- Node Exporter: 10 seconds (minimal startup)
- cAdvisor: 15 seconds (scans containers)
- Loki: 30 seconds (initializes storage)
- Promtail: 10 seconds (minimal startup)
- Grafana: 30-60 seconds (depends on Prometheus/Loki health)
- Alertmanager: 10 seconds (minimal startup)

**Status Indicators:**
- `Up X seconds (healthy)` ✅ - Service is ready
- `Up X seconds (health: starting)` ⏳ - Still initializing
- `Restarting` ❌ - Health check failing (see logs)

---

### Step 7: Verify Network Connectivity

All services bind to localhost only. Test internal connectivity:

```bash
# Test Prometheus
curl http://localhost:9090/-/healthy
# Expected: Prometheus is Healthy.

# Test Grafana
curl http://localhost:3000/api/health
# Expected: {"database":"ok",...}

# Test Loki
curl http://localhost:3100/ready
# Expected: ready

# Test Alertmanager
curl http://localhost:9093/-/healthy
# Expected: OK
```

**Setup SSH Tunnel for Access:**

```bash
# From your local machine (not the server)
ssh -L 3000:localhost:3000 -L 9090:localhost:9090 user@homelab-server

# Now you can access from your local browser:
# http://localhost:3000 → Grafana
# http://localhost:9090 → Prometheus
```

---

## Initial Configuration

### First Grafana Login

1. **Open Grafana**: http://localhost:3000 (via SSH tunnel)

2. **Login Credentials:**
   - Username: `admin`
   - Password: `<from your .env file>`

3. **Verify Datasources:**
   - Navigate to: Configuration → Data Sources
   - Expected: Prometheus and Loki already configured (auto-provisioned)
   - Test both datasources (should show green checkmark)

4. **Verify Dashboards:**
   - Navigate to: Dashboards → Browse
   - Expected: 6 dashboards pre-loaded:
     - Homelab System Overview
     - Systemd Services
     - Security Monitoring
     - CRON Monitoring
     - Docker Security & Stability
     - Network Exposure & Socket Monitoring

5. **Change Default Password (Optional but Recommended):**
   - Click profile icon → Change password
   - Use strong, unique password
   - Update `.env` file if you want to document it

---

### Verify Metrics Collection

**Check Prometheus Targets:**

1. Open Prometheus: http://localhost:9090
2. Navigate to: Status → Targets
3. Verify all targets are "UP":
   - prometheus (self-monitoring)
   - node-exporter (host metrics)
   - cadvisor (container metrics)
   - alertmanager
   - loki

**Common "DOWN" Reasons:**
- Service not healthy yet (wait 1-2 minutes)
- Service crashed (check `docker compose logs <service>`)
- Network connectivity issue (check Docker network: `docker network inspect observability`)

---

### Verify Alert Rules

**Check Alert Rules Loaded:**

```bash
# Prometheus web UI
open http://localhost:9090/rules

# CLI check
curl http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[].name'
```

**Expected: 97 alert rules across 12 files**

**Validate Alert Syntax:**

```bash
# Using promtool in container
docker exec prometheus promtool check rules /etc/prometheus/alerts.yml
# Expected: SUCCESS

# Check all alert files
for file in prometheus/*-alerts.yml; do
  echo "Checking $file..."
  docker exec prometheus promtool check rules /etc/prometheus/$(basename $file)
done
```

---

### Test Alert Notifications (Optional)

**Send Test Alert:**

```bash
# Trigger a test alert manually
curl -X POST http://localhost:9093/api/v1/alerts \
  -H "Content-Type: application/json" \
  -d '[{
    "labels": {"alertname":"TestAlert","severity":"warning"},
    "annotations": {"summary":"Test alert from installation"},
    "startsAt": "'$(date -Iseconds)'"
  }]'
```

**Verify Alert Received:**
- Check email inbox for alert notification
- Check Alertmanager UI: http://localhost:9093/#/alerts

**If Email Not Received:**
- Check Alertmanager logs: `docker compose logs alertmanager`
- Verify SMTP settings in `alertmanager/alertmanager.yml`
- Test SMTP from Alertmanager container:
  ```bash
  docker exec alertmanager wget --spider smtp://smtp.gmail.com:587
  ```

---

## Verification Steps

### Comprehensive Health Check

Run this checklist to verify complete installation:

```bash
#!/bin/bash
# Save as verify-installation.sh

echo "=== Homelab Observability Stack Verification ==="

# 1. Check all containers running
echo -e "\n1. Container Status:"
docker compose ps | grep -E "(Up|healthy)" && echo "✅ All containers up" || echo "❌ Some containers down"

# 2. Check Prometheus health
echo -e "\n2. Prometheus Health:"
curl -sf http://localhost:9090/-/healthy > /dev/null && echo "✅ Prometheus healthy" || echo "❌ Prometheus unhealthy"

# 3. Check Grafana health
echo -e "\n3. Grafana Health:"
curl -sf http://localhost:3000/api/health > /dev/null && echo "✅ Grafana healthy" || echo "❌ Grafana unhealthy"

# 4. Check Loki health
echo -e "\n4. Loki Health:"
curl -sf http://localhost:3100/ready > /dev/null && echo "✅ Loki ready" || echo "❌ Loki not ready"

# 5. Check alert rules count
echo -e "\n5. Alert Rules:"
RULES=$(curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].rules | length' | awk '{s+=$1} END {print s}')
if [ "$RULES" -eq 97 ]; then
  echo "✅ All 97 alert rules loaded"
else
  echo "⚠️  Expected 97 rules, found $RULES"
fi

# 6. Check Prometheus targets
echo -e "\n6. Prometheus Targets:"
UP_TARGETS=$(curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health=="up") | .job' | wc -l)
echo "✅ $UP_TARGETS targets UP"

# 7. Check data directories
echo -e "\n7. Data Directories:"
[ -d /srv/data/observability/prometheus ] && echo "✅ Prometheus data dir exists" || echo "❌ Missing prometheus data"
[ -d /srv/data/observability/grafana ] && echo "✅ Grafana data dir exists" || echo "❌ Missing grafana data"

# 8. Check systemd service (if installed)
echo -e "\n8. Systemd Service:"
if systemctl is-enabled observability &>/dev/null; then
  systemctl is-active observability &>/dev/null && echo "✅ Systemd service active" || echo "❌ Systemd service inactive"
else
  echo "ℹ️  Systemd service not installed (standalone mode)"
fi

echo -e "\n=== Verification Complete ==="
```

**Run verification:**
```bash
chmod +x verify-installation.sh
./verify-installation.sh
```

---

## Post-Installation Tasks

### 1. Configure Backups

Set up automated backups of monitoring data:

```bash
# Create backup script
sudo tee /usr/local/bin/backup-observability.sh > /dev/null <<'EOF'
#!/bin/bash
BACKUP_DIR="/backup/observability"
DATE=$(date +%Y%m%d-%H%M%S)

# Stop stack for consistent backup
systemctl stop observability

# Create backup
mkdir -p "$BACKUP_DIR"
tar -czf "$BACKUP_DIR/observability-$DATE.tar.gz" \
  /srv/data/observability/ \
  /srv/docker/observability/.env

# Restart stack
systemctl start observability

# Keep only last 7 backups
find "$BACKUP_DIR" -name "observability-*.tar.gz" -mtime +7 -delete
EOF

sudo chmod +x /usr/local/bin/backup-observability.sh

# Schedule weekly backups
echo "0 2 * * 0 root /usr/local/bin/backup-observability.sh" | sudo tee /etc/cron.d/observability-backup
```

---

### 2. Configure Firewall

Ensure ports are only accessible locally:

```bash
# UFW (Ubuntu/Debian)
sudo ufw deny 3000/tcp  # Grafana
sudo ufw deny 9090/tcp  # Prometheus
sudo ufw deny 9093/tcp  # Alertmanager
sudo ufw deny 3100/tcp  # Loki

# Verify rules
sudo ufw status numbered
```

**Note:** Services already bind to 127.0.0.1, this is defense-in-depth.

---

### 3. Set Up Tailscale (Optional but Recommended)

For secure remote access without SSH tunnels:

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Authenticate
sudo tailscale up

# Access Grafana directly via Tailscale
# http://homelab:3000 (where 'homelab' is your Tailscale hostname)
```

---

### 4. Configure Alerting Integrations

**Slack Integration (Optional):**

Edit `alertmanager/alertmanager.yml`:

```yaml
receivers:
  - name: 'slack-notifications'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#homelab-alerts'
        title: '{{ .CommonLabels.alertname }}'
        text: '{{ .CommonAnnotations.summary }}'
```

**PagerDuty Integration (Optional):**

```yaml
receivers:
  - name: 'pagerduty-critical'
    pagerduty_configs:
      - service_key: 'YOUR_PAGERDUTY_SERVICE_KEY'
        severity: '{{ .CommonLabels.severity }}'
```

After changes, restart Alertmanager:
```bash
docker compose restart alertmanager
```

---

### 5. Customize Dashboards

See [DASHBOARDS.md](./DASHBOARDS.md) for dashboard customization guide.

---

### 6. Review and Adjust Alert Rules

See [ALERTS.md](./ALERTS.md) for alert customization guide.

**Common Adjustments:**
- Thresholds (CPU, memory, disk usage percentages)
- Evaluation intervals (`for: 5m` durations)
- Alert severity levels

---

### 7. Document Your Setup

Create local documentation:

```bash
# Create operations log
cat > /srv/docker/observability/OPERATIONS_LOG.md <<EOF
# Observability Stack Operations Log

## Installation
- **Date:** $(date +%Y-%m-%d)
- **Installed by:** $(whoami)
- **Version:** 2.0.0

## Configuration
- Grafana admin: admin
- Alert email: <your-email>
- SMTP: <your-smtp-host>

## Customizations
- (Document any changes you make here)

## Incidents
- (Log any issues and resolutions here)
EOF
```

---

## Uninstallation

### Complete Removal

```bash
# Stop and remove services
cd /opt/Homelab/stacks/observability
docker compose down -v

# Remove systemd service
sudo systemctl stop observability
sudo systemctl disable observability
sudo rm /etc/systemd/system/observability.service
sudo systemctl daemon-reload

# Remove data (WARNING: This deletes all monitoring history)
sudo rm -rf /srv/data/observability

# Remove configs
sudo rm -rf /srv/docker/observability

# Remove repository (if desired)
sudo rm -rf /opt/Homelab
```

**Verification:**
```bash
docker ps -a | grep -E "prometheus|grafana|loki"
# Should return nothing

ls /srv/data/observability
# Should show "No such file or directory"
```

---

### Partial Removal (Keep Data)

To remove services but keep monitoring data for later restoration:

```bash
# Stop services
docker compose down

# Disable systemd service
sudo systemctl stop observability
sudo systemctl disable observability

# Data remains in /srv/data/observability/
# Can be restored later by redeploying stack
```

---

## Troubleshooting Installation

### Issue: Docker Compose Not Found

```bash
# Error: docker: 'compose' is not a docker command

# Solution: Install Docker Compose v2
sudo apt update
sudo apt install docker-compose-plugin

# Verify
docker compose version
```

---

### Issue: Permission Denied on Data Directories

```bash
# Error: mkdir /srv/data/observability/prometheus: permission denied

# Solution: Check ownership
ls -ln /srv/data/observability/

# Fix ownership (example for Prometheus)
sudo chown -R 65534:65534 /srv/data/observability/prometheus
```

---

### Issue: Prometheus Container Exits Immediately

```bash
# Check logs
docker compose logs prometheus

# Common cause: Invalid alert rule syntax
# Solution: Validate rules
docker run --rm -v $(pwd)/prometheus:/etc/prometheus \
  prom/prometheus:v2.48.1 promtool check rules /etc/prometheus/alerts.yml

# Fix syntax errors and restart
docker compose up -d prometheus
```

---

### Issue: Grafana Shows "Datasource Not Found"

```bash
# Common cause: Grafana started before Prometheus was healthy
# Solution: Restart Grafana
docker compose restart grafana

# Verify datasources
curl http://localhost:3000/api/datasources \
  -u admin:<password>
```

---

### Issue: SMTP Email Not Working

```bash
# Test SMTP connectivity
docker exec alertmanager wget --spider smtp://smtp.gmail.com:587

# Check Alertmanager logs for auth errors
docker compose logs alertmanager | grep -i "smtp\|auth"

# Common fix: Use app-specific password for Gmail
# Not your regular password!
```

---

### Issue: High Memory Usage After Installation

```bash
# Check memory consumption
docker stats --no-stream

# If Prometheus using excessive memory:
# Reduce retention period in compose.yaml:
# --storage.tsdb.retention.time=7d (instead of 15d)

# Restart with new limits
docker compose up -d --force-recreate prometheus
```

---

## Next Steps

After successful installation:

1. ✅ **Explore Dashboards**: Open Grafana and familiarize yourself with the 6 pre-built dashboards
2. ✅ **Review Alerts**: Check [ALERTS.md](./ALERTS.md) to understand what triggers notifications
3. ✅ **Set Up Backups**: Implement the backup strategy from post-installation tasks
4. ✅ **Join Community**: Share your setup and get help in GitHub Discussions

**Recommended Reading:**
- [OPERATIONS.md](./OPERATIONS.md) - Day-to-day management
- [MONITORING.md](./MONITORING.md) - What to watch for
- [CONFIGURATION.md](./CONFIGURATION.md) - Advanced configuration

---

**Installation complete! 🎉**

You now have a production-grade observability stack running on your homelab.

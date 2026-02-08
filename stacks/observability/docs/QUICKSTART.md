# Observability Stack - Quick Start Guide

**For impatient admins who want to get monitoring running NOW.**

## Prerequisites Check (2 minutes)

```bash
# Verify Docker is running
docker ps >/dev/null 2>&1 && echo "✓ Docker OK" || echo "✗ Docker not running"

# Check available disk space (need at least 10GB free)
df -h /srv/data 2>/dev/null || df -h /

# Verify Git repo is in correct location
pwd  # Should be /home/ssk/Code/Projects/building/Homelab
```

## First Time Setup (5 minutes)

### Step 1: Configure Secrets

```bash
cd stacks/observability

# Create .env file if it doesn't exist
cp .env.example .env 2>/dev/null || true

# IMPORTANT: Change default passwords
nano .env
```

**Required changes in `.env`:**
```bash
GF_SECURITY_ADMIN_PASSWORD=your_secure_password_here  # Change from 'admin'!
```

### Step 2: Create Data Directories

```bash
# Create directories with correct permissions
sudo mkdir -p /srv/data/observability/{prometheus,grafana,loki,alertmanager}
sudo chown -R 65534:65534 /srv/data/observability/prometheus
sudo chown -R 472:472 /srv/data/observability/grafana
sudo chown -R 10001:10001 /srv/data/observability/loki
sudo chown -R 65534:65534 /srv/data/observability/alertmanager

# Verify
ls -la /srv/data/observability/
```

### Step 3: Deploy the Stack

```bash
# Using systemd (recommended - survives reboots)
sudo systemctl enable /home/ssk/Code/Projects/building/Homelab/stacks/observability/systemd/observability.service
sudo systemctl start observability
sudo systemctl status observability

# OR using CLI wrapper
./cli/homelab.sh observability start

# OR directly with docker compose
cd stacks/observability
docker compose up -d
```

### Step 4: Verify Services (2 minutes)

```bash
# Check all containers are running
docker ps --filter "name=observability" --format "table {{.Names}}\t{{.Status}}"

# Should see 4 containers:
# observability-prometheus-1    Up X minutes (healthy)
# observability-grafana-1       Up X minutes  
# observability-loki-1          Up X minutes
# observability-alertmanager-1  Up X minutes
```

**Check service endpoints:**
```bash
# Prometheus (metrics database)
curl -s http://localhost:9090/-/healthy && echo "✓ Prometheus healthy"

# Grafana (dashboards)
curl -s http://localhost:3000/api/health | jq -r .database && echo "✓ Grafana healthy"

# Loki (log aggregation)
curl -s http://localhost:3100/ready && echo "✓ Loki ready"

# Alertmanager (alert routing)
curl -s http://localhost:9093/-/healthy && echo "✓ Alertmanager healthy"
```

## Access Your Monitoring (Now!)

### Grafana Dashboards
- **URL:** http://localhost:3000
- **Username:** `admin`
- **Password:** (from your `.env` file)

**Available Dashboards:**
1. **Homelab System Overview** - Start here! System health at a glance
2. **Systemd Services** - Service status and restart tracking
3. **Security Monitoring** - SSH attacks, Docker security, privilege escalation
4. **CRON Monitoring** - Scheduled job tracking
5. **Docker Security & Stability** - Container health and security
6. **Network Exposure** - Open ports and listening services

### Prometheus Alerts
- **URL:** http://localhost:9090/alerts
- **Expected:** DeadMansSwitch firing (proves alerting works!)
- **Rules:** 97 alert rules across 12 categories

### Alertmanager
- **URL:** http://localhost:9093
- **Status:** Check which alerts are currently firing

## Common First-Time Issues

### Issue: Containers restart repeatedly

```bash
# Check logs
docker logs observability-prometheus-1 --tail 50
docker logs observability-grafana-1 --tail 50

# Common causes:
# 1. Permission issues on /srv/data/observability/
sudo chown -R 65534:65534 /srv/data/observability/prometheus
sudo chown -R 472:472 /srv/data/observability/grafana

# 2. Port conflicts (something else using 3000, 9090, 9093, 3100)
sudo ss -tulpn | grep -E ':(3000|9090|9093|3100)'
```

### Issue: Prometheus won't start

```bash
# Validate alert rules
cd stacks/observability/prometheus
for file in *-alerts.yml alerts.yml; do
    docker run --rm \
        -v "$(pwd)/$file:/tmp/rules.yml:ro" \
        --entrypoint /bin/promtool \
        prom/prometheus:v2.48.1 \
        check rules /tmp/rules.yml
done
```

### Issue: No data in dashboards

```bash
# Check if node-exporter is running
systemctl status node-exporter

# Check if Prometheus can scrape it
curl http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | "\(.labels.job) - \(.health)"'

# Should show:
# node-exporter - up
# prometheus - up
# alertmanager - up
```

### Issue: Grafana shows "Data source not found"

```bash
# Restart Grafana (it may have started before Prometheus)
docker restart observability-grafana-1

# Wait 30 seconds, then check again
```

## Quick Validation Checklist

After deployment, verify everything works:

```bash
# 1. All containers running
docker ps --filter "name=observability" | grep -c "Up"
# Should output: 4

# 2. Prometheus loaded all alert rules
curl -s http://localhost:9090/api/v1/rules | jq '[.data.groups[].rules[]] | length'
# Should output: 97

# 3. Grafana dashboards loaded
curl -s -u admin:your_password http://localhost:3000/api/search?type=dash-db | jq 'length'
# Should output: 6

# 4. Dead Man's Switch is firing (proves alerting works)
curl -s http://localhost:9090/api/v1/alerts | jq -r '.data.alerts[] | select(.labels.alertname=="DeadMansSwitch") | .state'
# Should output: firing

# 5. Metrics are being collected
curl -s http://localhost:9090/api/v1/query?query=up | jq -r '.data.result | length'
# Should output: 3 or more (node-exporter, prometheus, alertmanager)
```

## Next Steps After Setup

### Immediate (First Hour)
1. **Change default passwords** - Don't skip this!
2. **Browse dashboards** - Familiarize yourself with what's monitored
3. **Check alert rules** - Understand what will trigger notifications
4. **Configure Alertmanager** - Set up Slack/email for alert delivery

### This Week
1. **Set up alert routing** - Edit `alertmanager/alertmanager.yml`
2. **Document baselines** - What's "normal" for your system?
3. **Test alerts** - Manually trigger a test alert
4. **Security hardening** - Firewall rules, reverse proxy, etc.

### This Month
1. **Customize dashboards** - Adapt to your specific needs
2. **Add application metrics** - Monitor your services
3. **Set up external monitoring** - Dead Man's Switch delivery verification
4. **Create runbooks** - Document response procedures

## Performance Tuning

### Low-Resource Environments (< 4GB RAM)

Edit `stacks/observability/compose.yaml`:

```yaml
prometheus:
  command:
    - '--storage.tsdb.retention.time=7d'  # Reduce from 15d
    - '--storage.tsdb.retention.size=2GB' # Reduce from 5GB
```

### High-Traffic Environments (> 100 containers)

```yaml
prometheus:
  command:
    - '--storage.tsdb.retention.time=30d'
    - '--storage.tsdb.retention.size=20GB'
    - '--query.max-concurrency=50'
```

## Useful Commands

```bash
# Restart entire stack
./cli/homelab.sh observability restart

# View logs (all services)
./cli/homelab.sh observability logs -f

# View logs (specific service)
docker logs -f observability-prometheus-1

# Check Prometheus config
docker exec observability-prometheus-1 promtool check config /etc/prometheus/prometheus.yml

# Reload Prometheus (without restart)
curl -X POST http://localhost:9090/-/reload

# Check disk usage
du -sh /srv/data/observability/*

# Backup Grafana dashboards
docker exec observability-grafana-1 grafana cli admin export-dashboard > backup.json
```

## Help & Documentation

- **Full Documentation:** `stacks/observability/docs/README.md`
- **Installation Guide:** `stacks/observability/docs/INSTALLATION.md`
- **Alert Reference:** `stacks/observability/docs/ALERTS.md`
- **Dashboard Guide:** `stacks/observability/docs/DASHBOARDS.md`
- **Operations Manual:** `stacks/observability/docs/OPERATIONS.md`

## Emergency Troubleshooting

### Stack won't start at all

```bash
# Check Docker daemon
sudo systemctl status docker

# Check for resource exhaustion
free -h
df -h

# Try starting services individually
cd stacks/observability
docker compose up prometheus  # Start just Prometheus
```

### Complete reset (nuclear option)

```bash
# WARNING: Deletes all monitoring data!
docker compose down -v
sudo rm -rf /srv/data/observability/*
# Then follow "First Time Setup" again
```

### Get help

```bash
# Check Prometheus status
curl http://localhost:9090/api/v1/status/runtimeinfo | jq

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | "\(.labels.job): \(.health)"'

# Check for configuration errors
docker logs observability-prometheus-1 2>&1 | grep -i error
```

---

**Expected Setup Time:** 10-15 minutes for first-time deployment

**Expected Resource Usage:**
- CPU: 5-10% average (spikes during scrapes)
- Memory: 1-2GB total across all containers
- Disk: ~100MB/day (depends on metric cardinality)

**Success Criteria:**
- ✓ All 4 containers running
- ✓ Grafana accessible with 6 dashboards
- ✓ Prometheus showing 97 alert rules
- ✓ DeadMansSwitch alert firing
- ✓ Metrics visible in dashboards

Now go to http://localhost:3000 and start monitoring! 🚀

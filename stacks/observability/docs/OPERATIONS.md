# Operations Guide

**Day-to-day operational procedures for the Homelab Observability Stack**

---

## Table of Contents

- [Service Management](#service-management)
- [Checking Service Status](#checking-service-status)
- [Viewing Logs](#viewing-logs)
- [Configuration Hot Reload](#configuration-hot-reload)
- [Backup and Restore](#backup-and-restore)
- [Upgrading Components](#upgrading-components)
- [Scaling Considerations](#scaling-considerations)
- [Capacity Planning](#capacity-planning)
- [Disaster Recovery](#disaster-recovery)
- [Common Operational Tasks](#common-operational-tasks)

---

## Service Management

### Starting Services

**Via Systemd (Recommended):**

```bash
# Start entire observability stack
sudo systemctl start observability

# Check status
sudo systemctl status observability

# View startup logs
journalctl -u observability -f
```

**Via Docker Compose:**

```bash
cd /opt/Homelab/stacks/observability

# Start all services
docker compose up -d

# Start specific service
docker compose up -d prometheus

# Start with rebuild (if image changed)
docker compose up -d --build

# Start with force recreate (if compose.yaml changed)
docker compose up -d --force-recreate
```

**Expected Startup Time:**
- **Fast services** (<10s): Node Exporter, Promtail, Alertmanager
- **Medium services** (10-30s): Prometheus, cAdvisor
- **Slow services** (30-60s): Loki, Grafana (depends on dependencies)

---

### Stopping Services

**Graceful Shutdown:**

```bash
# Via systemd
sudo systemctl stop observability

# Via Docker Compose
docker compose down

# Stop specific service
docker compose stop prometheus
```

**Force Stop (if graceful fails):**

```bash
# Kill specific container
docker kill prometheus

# Force remove all
docker compose down --remove-orphans --volumes
```

**⚠️ Warning:** `--volumes` flag deletes all data! Only use for complete removal.

---

### Restarting Services

**Restart All:**

```bash
# Via systemd
sudo systemctl restart observability

# Via Docker Compose
docker compose restart

# Restart with downtime (recreate containers)
docker compose down && docker compose up -d
```

**Restart Specific Service:**

```bash
# Restart just Prometheus
docker compose restart prometheus

# Restart with logs
docker compose restart prometheus && docker compose logs -f prometheus
```

**Zero-Downtime Reload (Prometheus only):**

```bash
# See "Configuration Hot Reload" section below
curl -X POST http://localhost:9090/-/reload
```

---

## Checking Service Status

### Quick Health Check

**All Services:**

```bash
# Via Docker Compose
docker compose ps

# Expected output:
# NAME           STATUS
# prometheus     Up 2 hours (healthy)
# grafana        Up 2 hours (healthy)
# loki           Up 2 hours (healthy)
# alertmanager   Up 2 hours (healthy)
# node-exporter  Up 2 hours (healthy)
# cadvisor       Up 2 hours (healthy)
# promtail       Up 2 hours (healthy)
```

**Health Status Indicators:**

- ✅ `Up X (healthy)` - Service running and health check passing
- ⏳ `Up X (health: starting)` - Service starting, health check pending
- ⚠️ `Up X (unhealthy)` - Service running but health check failing
- ❌ `Restarting` - Service crash-looping
- 🛑 `Exited` - Service stopped (check logs)

---

### Individual Service Health

**Prometheus:**

```bash
# Health endpoint
curl http://localhost:9090/-/healthy
# Expected: Prometheus is Healthy.

# Readiness endpoint
curl http://localhost:9090/-/ready
# Expected: Prometheus is Ready.

# Check targets
curl -s http://localhost:9090/api/v1/targets | \
  jq '.data.activeTargets[] | {job: .job, health: .health}'

# Check rules loaded
curl -s http://localhost:9090/api/v1/rules | \
  jq '.data.groups[] | {file: .file, rules: (.rules | length)}'
```

**Grafana:**

```bash
# Health endpoint
curl http://localhost:3000/api/health
# Expected: {"database":"ok","version":"10.2.0"}

# Check datasources
curl -s http://localhost:3000/api/datasources \
  -u admin:password | \
  jq '.[] | {name: .name, type: .type}'
```

**Loki:**

```bash
# Readiness endpoint
curl http://localhost:3100/ready
# Expected: ready

# Check ingester status
curl -s http://localhost:3100/ingester/ring | jq .
```

**Alertmanager:**

```bash
# Health endpoint
curl http://localhost:9093/-/healthy
# Expected: OK

# Check active alerts
curl -s http://localhost:9093/api/v1/alerts | \
  jq '.data[] | {alertname: .labels.alertname, state: .status.state}'
```

---

### Resource Usage Monitoring

**Real-time Resource Usage:**

```bash
# All services
docker stats --no-stream

# Specific service
docker stats prometheus --no-stream

# Continuous monitoring (refresh every 2s)
watch -n 2 docker stats --no-stream
```

**Expected Resource Usage:**

| Service | Memory | CPU (avg) | Notes |
|---------|--------|-----------|-------|
| Prometheus | 200-400MB | 5-10% | Spikes during scrapes |
| Grafana | 100-200MB | 2-5% | Increases with users |
| Loki | 100-200MB | 5-10% | Depends on log volume |
| Alertmanager | 20-40MB | 1-2% | Very lightweight |
| Node Exporter | 20-40MB | 1-2% | Minimal overhead |
| cAdvisor | 50-100MB | 3-5% | Per-container overhead |
| Promtail | 20-40MB | 2-4% | Depends on log volume |

**Alert if:**
- Any service exceeds memory limit (causes OOM)
- CPU consistently >50% (undersized or issue)
- Memory growing unbounded (memory leak)

---

### Disk Space Monitoring

**Check Data Directories:**

```bash
# Overall usage
du -sh /srv/data/observability/

# Per-service breakdown
du -sh /srv/data/observability/*

# Expected output:
# 2.1G  /srv/data/observability/prometheus  (largest)
# 800M  /srv/data/observability/loki
# 200M  /srv/data/observability/grafana
# 10M   /srv/data/observability/alertmanager
# 5M    /srv/data/observability/promtail
```

**Prometheus Disk Usage Details:**

```bash
# TSDB stats via API
curl -s http://localhost:9090/api/v1/status/tsdb-status | jq .

# WAL size
du -sh /srv/data/observability/prometheus/wal/

# Block storage
du -sh /srv/data/observability/prometheus/chunks_head/
```

**Clean Up Disk Space:**

```bash
# Clean old Prometheus data (reduces retention)
# Edit compose.yaml: --storage.tsdb.retention.time=7d
# Then restart: docker compose up -d --force-recreate prometheus

# Clean Docker system (careful!)
docker system prune -a --volumes  # ⚠️ Removes all unused data

# Clean logs
sudo journalctl --vacuum-time=7d
```

---

## Viewing Logs

### Docker Compose Logs

**All Services:**

```bash
# Follow all logs (Ctrl+C to exit)
docker compose logs -f

# Last 100 lines from all services
docker compose logs --tail=100

# Last hour of logs
docker compose logs --since 1h

# Show timestamps
docker compose logs -f -t
```

**Specific Service:**

```bash
# Prometheus logs
docker compose logs -f prometheus

# Last 50 lines
docker compose logs --tail=50 prometheus

# Multiple services
docker compose logs -f prometheus grafana
```

---

### Systemd Journal Logs

**Observability Service:**

```bash
# Follow observability service logs
journalctl -u observability -f

# Last 100 lines
journalctl -u observability -n 100

# Today's logs
journalctl -u observability --since today

# Logs between time range
journalctl -u observability --since "2026-02-08 10:00" --until "2026-02-08 11:00"

# Export logs to file
journalctl -u observability > observability.log
```

---

### Searching Logs

**Grep for Errors:**

```bash
# All services - errors
docker compose logs | grep -i error

# Prometheus - errors only
docker compose logs prometheus | grep -i "level=error"

# Multiple patterns
docker compose logs | grep -E "error|warning|critical"
```

**Using jq for JSON Logs:**

```bash
# If logs are JSON formatted
docker compose logs --tail=100 | jq -r 'select(.level=="error")'
```

---

### Log Rotation

Docker handles log rotation via logging driver config in `compose.yaml`:

```yaml
logging:
  driver: json-file
  options:
    max-size: "10m"    # Max 10MB per log file
    max-file: "3"       # Keep 3 files
    compress: "true"    # Compress old logs
```

**Manual Log Cleanup:**

```bash
# Find large log files
find /var/lib/docker/containers/ -name "*.log" -size +50M

# Truncate specific container logs
sudo truncate -s 0 /var/lib/docker/containers/<container-id>/<container-id>-json.log

# Safer: Restart container (rotates logs)
docker compose restart <service>
```

---

## Configuration Hot Reload

### Prometheus Hot Reload

**Why:** Update alert rules or scrape configs without downtime

**Method 1: API Endpoint (Recommended)**

```bash
# Trigger reload
curl -X POST http://localhost:9090/-/reload

# Check reload succeeded
curl -s http://localhost:9090/api/v1/status/config | jq '.status'
# Expected: "success"

# Verify new config loaded
curl -s http://localhost:9090/api/v1/status/config | jq '.data.yaml' | head -20
```

**Method 2: Systemd Reload**

```bash
# Reload via systemd (uses curl internally)
sudo systemctl reload observability

# This runs:
# /bin/bash -c 'curl -X POST http://localhost:9090/-/reload && docker compose restart grafana promtail'
```

**Method 3: Send SIGHUP Signal**

```bash
# Find Prometheus PID
docker exec prometheus ps aux | grep prometheus

# Send SIGHUP
docker exec prometheus kill -HUP 1
```

---

### What Can Be Hot Reloaded?

**✅ Hot Reload Supported:**
- Alert rules (`prometheus/*-alerts.yml`)
- Scrape configs (`prometheus/prometheus.yml`)
- Recording rules
- Global config changes (intervals, labels)

**❌ Requires Restart:**
- Storage retention settings (`--storage.tsdb.retention.*`)
- Command-line flags
- Volume mounts
- Network settings

---

### Validating Before Reload

**Always validate configuration before reloading:**

```bash
# Validate Prometheus config
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml

# Validate alert rules
docker exec prometheus promtool check rules /etc/prometheus/alerts.yml

# Check all alert files
for file in prometheus/*-alerts.yml; do
  echo "Checking $(basename $file)..."
  docker exec prometheus promtool check rules /etc/prometheus/$(basename $file) || exit 1
done
```

**Rollback if Reload Fails:**

```bash
# Reload will fail if config invalid (safe)
curl -X POST http://localhost:9090/-/reload
# Returns error if config invalid

# If Prometheus crashes (rare):
# Restore from git
cd /opt/Homelab/stacks/observability
git restore prometheus/prometheus.yml

# Restart
docker compose restart prometheus
```

---

## Backup and Restore

### What to Backup

**Critical Data:**
1. **Prometheus metrics** - `/srv/data/observability/prometheus/`
2. **Grafana dashboards** - `/srv/data/observability/grafana/`
3. **Loki logs** - `/srv/data/observability/loki/`
4. **Environment config** - `/srv/docker/observability/.env`

**Version Controlled (no backup needed):**
- Alert rules (in git)
- Dashboard definitions (in git)
- Configuration files (in git)

---

### Full Backup

**Automated Backup Script:**

```bash
#!/bin/bash
# /usr/local/bin/backup-observability.sh

BACKUP_DIR="/backup/observability"
DATE=$(date +%Y%m%d-%H%M%S)
RETENTION_DAYS=30

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Stop stack for consistent backup (optional but recommended)
systemctl stop observability

# Backup data directories
tar -czf "$BACKUP_DIR/observability-data-$DATE.tar.gz" \
  -C /srv/data observability/

# Backup environment config (contains secrets)
tar -czf "$BACKUP_DIR/observability-config-$DATE.tar.gz" \
  -C /srv/docker observability/.env

# Restart stack
systemctl start observability

# Clean old backups
find "$BACKUP_DIR" -name "observability-*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "Backup completed: $BACKUP_DIR/observability-data-$DATE.tar.gz"
```

**Schedule Backup:**

```bash
# Make executable
sudo chmod +x /usr/local/bin/backup-observability.sh

# Schedule weekly (Sunday 2 AM)
echo "0 2 * * 0 root /usr/local/bin/backup-observability.sh" | \
  sudo tee /etc/cron.d/observability-backup
```

---

### Selective Backup (No Downtime)

**Backup Without Stopping Services:**

```bash
# Prometheus (TSDB - may include incomplete data)
rsync -av /srv/data/observability/prometheus/ /backup/prometheus-$(date +%Y%m%d)/

# Grafana dashboards only
tar -czf /backup/grafana-dashboards-$(date +%Y%m%d).tar.gz \
  /opt/Homelab/stacks/observability/grafana/provisioning/dashboards/

# Loki logs (may be inconsistent)
rsync -av /srv/data/observability/loki/ /backup/loki-$(date +%Y%m%d)/
```

**⚠️ Note:** Backups while services running may capture inconsistent state. For critical backups, stop services first.

---

### Restore from Backup

**Full Restore:**

```bash
# Stop stack
sudo systemctl stop observability

# Restore data
sudo tar -xzf /backup/observability-data-20260208.tar.gz -C /srv/data/

# Restore config
sudo tar -xzf /backup/observability-config-20260208.tar.gz -C /srv/docker/

# Fix permissions
sudo chown -R 65534:65534 /srv/data/observability/prometheus
sudo chown -R 472:472 /srv/data/observability/grafana
sudo chown -R 10001:10001 /srv/data/observability/loki

# Restart stack
sudo systemctl start observability

# Verify services healthy
docker compose ps
```

---

### Disaster Recovery Testing

**Regularly test your backups!**

```bash
#!/bin/bash
# Test restore procedure (non-destructive)

BACKUP_FILE="/backup/observability-data-20260208.tar.gz"
TEST_DIR="/tmp/observability-restore-test"

# Extract to test location
mkdir -p $TEST_DIR
tar -xzf $BACKUP_FILE -C $TEST_DIR

# Verify extraction
ls -lh $TEST_DIR/observability/

# Check Prometheus TSDB
docker run --rm -v $TEST_DIR/observability/prometheus:/prometheus \
  prom/prometheus:v2.48.1 \
  promtool tsdb dump /prometheus | head -20

# Clean up
rm -rf $TEST_DIR

echo "✅ Backup restore test completed successfully"
```

**Schedule monthly:** `0 3 1 * * /usr/local/bin/test-restore.sh`

---

## Upgrading Components

### Pre-Upgrade Checklist

- [ ] Review changelog for breaking changes
- [ ] Backup current data
- [ ] Test in non-production environment (if possible)
- [ ] Schedule maintenance window
- [ ] Notify users (if applicable)
- [ ] Have rollback plan ready

---

### Upgrading Prometheus

**Check Current Version:**

```bash
docker exec prometheus prometheus --version
# prometheus, version 2.48.1
```

**Upgrade Process:**

```bash
# 1. Backup data
sudo systemctl stop observability
sudo tar -czf /backup/prometheus-pre-upgrade.tar.gz /srv/data/observability/prometheus/

# 2. Update image version in compose.yaml
cd /opt/Homelab/stacks/observability
nano compose.yaml

# Change:
# image: prom/prometheus:v2.48.1
# To:
# image: prom/prometheus:v2.50.0

# 3. Pull new image
docker compose pull prometheus

# 4. Restart with new version
sudo systemctl start observability

# 5. Verify upgrade
docker exec prometheus prometheus --version
curl http://localhost:9090/-/healthy

# 6. Check logs for errors
docker compose logs prometheus | grep -i error
```

**Rollback if Issues:**

```bash
# Revert image version in compose.yaml
nano compose.yaml  # Change back to v2.48.1

# Restart
sudo systemctl restart observability
```

---

### Upgrading Grafana

**Special Considerations:**
- Database migrations may occur
- Plugins might need updates
- Dashboards usually compatible (test first)

**Upgrade Process:**

```bash
# 1. Backup Grafana database
sudo tar -czf /backup/grafana-pre-upgrade.tar.gz /srv/data/observability/grafana/

# 2. Update compose.yaml
nano compose.yaml
# image: grafana/grafana-oss:10.2.3 → 10.4.0

# 3. Pull and restart
docker compose pull grafana
docker compose up -d grafana

# 4. Check migration logs
docker compose logs grafana | grep -i "database migration"

# 5. Verify UI accessible
curl http://localhost:3000/api/health
```

---

### Upgrading All Components

**Batch Upgrade:**

```bash
# Update all image versions in compose.yaml
# Then:

# Pull all new images
docker compose pull

# Restart entire stack
sudo systemctl restart observability

# Monitor startup
docker compose ps
docker compose logs -f

# Verify all healthy
for service in prometheus grafana loki alertmanager; do
  echo "Checking $service..."
  docker compose ps $service | grep -q "healthy" && echo "✅ $service healthy" || echo "❌ $service unhealthy"
done
```

---

## Scaling Considerations

### Vertical Scaling (Single Host)

**Increase Resources:**

```yaml
# compose.yaml
prometheus:
  deploy:
    resources:
      limits:
        memory: 1G      # From 512M
        cpus: '2'       # Add CPU limit
      reservations:
        memory: 512M    # From 256M
```

**When to Scale Up:**
- Prometheus memory consistently >80% of limit
- Query latency increasing
- Scrape targets increasing significantly
- Retention period needs extension

---

### Horizontal Scaling (Multiple Instances)

**Not Recommended for Homelab:**
- Complexity outweighs benefits at homelab scale
- Single instance handles 100+ targets easily
- If needed, consider Thanos or Cortex (out of scope)

---

## Capacity Planning

### Metrics Cardinality Analysis

**Check Current Cardinality:**

```bash
# Total time series
curl -s http://localhost:9090/api/v1/status/tsdb-status | jq '.data.seriesCountByMetricName | length'

# Top 10 highest cardinality metrics
curl -s http://localhost:9090/api/v1/status/tsdb-status | \
  jq '.data.seriesCountByMetricName | to_entries | sort_by(.value) | reverse | .[0:10]'
```

**High Cardinality Problems:**
- Increases memory usage
- Slows queries
- Increases disk usage

**Solutions:**
- Drop unnecessary labels via `metric_relabel_configs`
- Reduce scrape frequency for high-cardinality exporters
- Use recording rules to pre-aggregate

---

### Projecting Growth

**Calculate Prometheus Growth:**

```bash
# Get current TSDB size
CURRENT_SIZE=$(du -sb /srv/data/observability/prometheus | awk '{print $1}')

# Calculate daily growth rate (requires 2+ days of data)
# Query: rate of data size increase
# (Simplified - manual calculation needed)

# Project future size
# Future size = Current + (Daily growth × Retention days)
```

**Example:**
- Current: 2GB
- Daily growth: 150MB
- Retention: 15 days
- Projected steady state: 2GB + (150MB × 15) = 4.25GB

**Action:** Set `--storage.tsdb.retention.size=5GB` with safety margin

---

## Disaster Recovery

### Scenarios and Procedures

#### Scenario 1: Prometheus Data Corruption

**Symptoms:**
- Prometheus won't start
- Errors about "corrupted WAL" or "bad block"

**Recovery:**

```bash
# Stop Prometheus
docker compose stop prometheus

# Try TSDB repair
docker run --rm -v /srv/data/observability/prometheus:/prometheus \
  prom/prometheus:v2.48.1 \
  promtool tsdb analyze /prometheus

# If repair fails, restore from backup
sudo rm -rf /srv/data/observability/prometheus/*
sudo tar -xzf /backup/prometheus-data.tar.gz -C /srv/data/observability/
sudo chown -R 65534:65534 /srv/data/observability/prometheus

# Restart
docker compose start prometheus
```

---

#### Scenario 2: Grafana Database Corruption

**Symptoms:**
- Grafana won't start
- "database is locked" errors

**Recovery:**

```bash
# Stop Grafana
docker compose stop grafana

# Restore from backup
sudo rm /srv/data/observability/grafana/grafana.db
sudo tar -xzf /backup/grafana-data.tar.gz -C /srv/data/observability/
sudo chown -R 472:472 /srv/data/observability/grafana

# If no backup, rebuild (loses custom changes):
sudo rm -rf /srv/data/observability/grafana/*
docker compose start grafana
# Dashboards will reprovision from JSON files
```

---

#### Scenario 3: Complete Host Failure

**Recovery:**

1. **Provision New Host:**
   ```bash
   # Install Docker
   curl -fsSL https://get.docker.com | sh
   ```

2. **Restore Repository:**
   ```bash
   cd /opt
   git clone https://github.com/yourusername/Homelab.git
   cd Homelab/stacks/observability
   ```

3. **Restore Data:**
   ```bash
   # Copy backup to new host (scp, rsync, etc.)
   sudo mkdir -p /srv/data/observability
   sudo tar -xzf observability-data-backup.tar.gz -C /srv/data/
   ```

4. **Restore Config:**
   ```bash
   sudo mkdir -p /srv/docker/observability
   sudo tar -xzf observability-config-backup.tar.gz -C /srv/docker/
   ```

5. **Fix Permissions:**
   ```bash
   sudo chown -R 65534:65534 /srv/data/observability/prometheus
   sudo chown -R 472:472 /srv/data/observability/grafana
   sudo chown -R 10001:10001 /srv/data/observability/loki
   ```

6. **Deploy:**
   ```bash
   sudo ln -sf $(pwd)/compose.yaml /srv/docker/observability/compose.yaml
   sudo cp systemd/observability.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable --now observability
   ```

7. **Verify:**
   ```bash
   docker compose ps
   curl http://localhost:9090/-/healthy
   curl http://localhost:3000/api/health
   ```

**RTO (Recovery Time Objective):** 15-30 minutes  
**RPO (Recovery Point Objective):** Last backup (daily = 24h)

---

## Common Operational Tasks

### Clearing Alert History

```bash
# Expire resolved alerts in Alertmanager
docker exec alertmanager amtool alert add \
  --end=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  alertname="DummyAlert"

# Clear Grafana alert history
# (Via UI: Alerting → Alert Rules → Clear history)
```

---

### Reindexing Loki

**If Loki logs corrupted or queries failing:**

```bash
# Stop Loki
docker compose stop loki

# Delete index (will rebuild from chunks)
sudo rm -rf /srv/data/observability/loki/boltdb-shipper-*

# Restart (will regenerate index)
docker compose start loki

# Monitor reindex progress
docker compose logs -f loki
```

---

### Testing Alert Notifications

```bash
# Send test alert to Alertmanager
curl -H "Content-Type: application/json" -d '[{
  "labels": {"alertname":"TestAlert","severity":"info"},
  "annotations": {"summary":"Test alert from operations"},
  "startsAt": "'$(date -Iseconds)'"
}]' http://localhost:9093/api/v1/alerts

# Check email/Slack received notification
```

---

### Updating SSL Certificates

**If using HTTPS (reverse proxy):**

```bash
# Update certificate files
sudo cp new-cert.pem /etc/ssl/certs/homelab-cert.pem
sudo cp new-key.pem /etc/ssl/private/homelab-key.pem

# Restart reverse proxy (nginx example)
sudo systemctl restart nginx

# No restart needed for Grafana (uses reverse proxy certs)
```

---

## Operations Runbook Template

Document common procedures for your team:

```markdown
# Observability Stack Operations Runbook

## Contacts
- Primary: Admin Name (admin@example.com)
- Backup: Backup Admin (backup@example.com)
- Escalation: Manager (manager@example.com)

## Daily Tasks
- [ ] Check Grafana "Homelab System Overview" dashboard
- [ ] Review "Security Monitoring" for attacks
- [ ] Check Alertmanager for firing alerts
- [ ] Verify all services healthy: `docker compose ps`

## Weekly Tasks
- [ ] Review alert trends (false positives?)
- [ ] Check disk space: `du -sh /srv/data/observability`
- [ ] Verify backups completed: `ls -lh /backup/observability`
- [ ] Update alert thresholds if needed

## Monthly Tasks
- [ ] Test backup restore procedure
- [ ] Review and update documentation
- [ ] Check for component updates
- [ ] Capacity planning review

## Emergency Procedures
See [Disaster Recovery](#disaster-recovery) section.
```

---

## Next Steps

- **[MONITORING.md](./MONITORING.md)** - What to monitor and when
- **[CONFIGURATION.md](./CONFIGURATION.md)** - Tuning and optimization
- **[ALERTS.md](./ALERTS.md)** - Alert management

---

**Operate smoothly! Consistency and automation are your friends.** ⚙️

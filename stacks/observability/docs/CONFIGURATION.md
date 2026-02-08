# Configuration Guide

**Complete reference for configuring the Homelab Observability Stack**

---

## Table of Contents

- [Environment Variables](#environment-variables)
- [Prometheus Configuration](#prometheus-configuration)
- [Alert Rules Customization](#alert-rules-customization)
- [Alertmanager Routing](#alertmanager-routing)
- [Loki and Promtail](#loki-and-promtail)
- [Grafana Provisioning](#grafana-provisioning)
- [Retention Policies](#retention-policies)
- [Performance Tuning](#performance-tuning)
- [Advanced Configuration](#advanced-configuration)

---

## Environment Variables

### Overview

Environment variables are stored in `.env` file in the stack directory and control runtime behavior of services.

**Location:** `/srv/docker/observability/.env` (or `stacks/observability/.env` in git repo)

**Security:** 
- ⚠️ **Never commit `.env` to git** (already in `.gitignore`)
- Set permissions: `chmod 600 .env`
- Store backup separately (password manager or encrypted volume)

---

### Required Variables

These must be set before deployment:

```bash
# Grafana Admin Password (REQUIRED)
GRAFANA_ADMIN_PASSWORD=your-secure-password-here
```

**Password Requirements:**
- Minimum 12 characters recommended
- Mix of uppercase, lowercase, numbers, special characters
- Use password generator: `openssl rand -base64 32`

**Changing Password:**
```bash
# Update .env file
nano /srv/docker/observability/.env

# Restart Grafana to apply
docker compose restart grafana

# OR change via Grafana UI after login
# Profile → Change Password
```

---

### Email/SMTP Configuration

For alert notifications via email:

```bash
# SMTP Server Configuration
SMTP_HOST=smtp.gmail.com:587           # Gmail example
SMTP_USER=your-email@gmail.com         # SMTP username
SMTP_PASSWORD=your-app-password        # App-specific password
SMTP_FROM=homelab-alerts@yourdomain.com  # From address
ALERT_EMAIL=admin@yourdomain.com       # Alert recipient
```

**Provider-Specific Examples:**

<details>
<summary><b>Gmail</b></summary>

```bash
SMTP_HOST=smtp.gmail.com:587
SMTP_USER=yourname@gmail.com
SMTP_PASSWORD=abcd-efgh-ijkl-mnop  # 16-char app password
SMTP_FROM=yourname@gmail.com
ALERT_EMAIL=yourname@gmail.com
```

**Setup:**
1. Enable 2FA: https://myaccount.google.com/security
2. Generate app password: https://myaccount.google.com/apppasswords
3. Use app password in `SMTP_PASSWORD` (not your Google password)

</details>

<details>
<summary><b>Office 365</b></summary>

```bash
SMTP_HOST=smtp.office365.com:587
SMTP_USER=yourname@yourdomain.com
SMTP_PASSWORD=your-password
SMTP_FROM=yourname@yourdomain.com
ALERT_EMAIL=yourname@yourdomain.com
```

</details>

<details>
<summary><b>SendGrid</b></summary>

```bash
SMTP_HOST=smtp.sendgrid.net:587
SMTP_USER=apikey
SMTP_PASSWORD=SG.your-api-key-here
SMTP_FROM=verified-sender@yourdomain.com
ALERT_EMAIL=alerts@yourdomain.com
```

</details>

<details>
<summary><b>Mailgun</b></summary>

```bash
SMTP_HOST=smtp.mailgun.org:587
SMTP_USER=postmaster@yourdomain.com
SMTP_PASSWORD=your-mailgun-password
SMTP_FROM=alerts@yourdomain.com
ALERT_EMAIL=you@yourdomain.com
```

</details>

---

### Optional Variables

These have sensible defaults but can be customized:

```bash
# Grafana Configuration
GRAFANA_ADMIN_USER=admin              # Default: admin

# Additional SMTP Settings
GF_SMTP_SKIP_VERIFY=false             # Skip SSL certificate verification
GF_SMTP_STARTTLS=true                 # Use STARTTLS

# Logging
GF_LOG_LEVEL=info                     # Options: debug, info, warn, error
```

---

### Applying Configuration Changes

After modifying `.env`:

```bash
# Method 1: Restart affected services
docker compose restart grafana alertmanager

# Method 2: Full stack restart (if major changes)
docker compose down && docker compose up -d

# Method 3: Via systemd (if installed)
sudo systemctl restart observability
```

**Note:** Prometheus does not use `.env` variables - it uses configuration files.

---

## Prometheus Configuration

### Main Configuration File

**Location:** `prometheus/prometheus.yml`

**Structure:**
```yaml
global:
  scrape_interval: 30s      # How often to scrape targets
  evaluation_interval: 30s   # How often to evaluate alert rules
  scrape_timeout: 10s        # Timeout for scrape requests

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

rule_files:
  - /etc/prometheus/alerts.yml
  - /etc/prometheus/systemd-alerts.yml
  # ... (12 alert rule files total)

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
  # ... (more scrape configs)
```

---

### Adjusting Scrape Intervals

**Trade-offs:**

| Interval | Pros | Cons | Use Case |
|----------|------|------|----------|
| 15s | High resolution, fast alerts | High CPU/memory | Production critical systems |
| 30s (default) | Balanced resource usage | Good enough for homelab | **Recommended for homelab** |
| 60s | Lower resource usage | Delayed alert detection | Low-priority systems |

**Changing Scrape Interval:**

```yaml
# In prometheus/prometheus.yml
global:
  scrape_interval: 60s      # Change from 30s to 60s
  evaluation_interval: 60s   # Match scrape interval
```

**Apply Changes:**
```bash
# Validate configuration
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml

# Hot reload (no downtime)
curl -X POST http://localhost:9090/-/reload

# OR via systemd
sudo systemctl reload observability
```

---

### Adding New Scrape Targets

**Example: Add Blackbox Exporter for URL monitoring**

1. Edit `prometheus/prometheus.yml`:

```yaml
scrape_configs:
  # ... existing configs ...

  - job_name: 'blackbox'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - https://example.com
          - https://yourservice.local
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115
```

2. Add Blackbox Exporter to `compose.yaml`:

```yaml
services:
  blackbox-exporter:
    image: prom/blackbox-exporter:v0.24.0
    container_name: blackbox-exporter
    restart: unless-stopped
    networks:
      - observability
```

3. Reload configuration:
```bash
docker compose up -d
curl -X POST http://localhost:9090/-/reload
```

---

### Storage Configuration

Prometheus storage is configured via command-line flags in `compose.yaml`:

```yaml
prometheus:
  command:
    - --storage.tsdb.path=/prometheus
    - --storage.tsdb.retention.time=15d
    - --storage.tsdb.retention.size=5GB
```

**Retention Policies:**

| Setting | Default | Low Resources | High Resources |
|---------|---------|---------------|----------------|
| `retention.time` | 15d | 7d | 30d |
| `retention.size` | 5GB | 3GB | 10GB |
| Scrape interval | 30s | 60s | 15s |

**Calculating Storage Needs:**

```
Estimated disk usage = 
  (samples/sec) × (bytes/sample) × (retention seconds)

Example (default config):
  ~200 samples/sec × 2 bytes × (15 days × 86400 sec) = ~518 MB
  
Add 50% overhead for indexing = ~800 MB
```

**Changing Retention:**

1. Edit `compose.yaml`:
```yaml
prometheus:
  command:
    - --storage.tsdb.retention.time=7d    # Reduce to 7 days
    - --storage.tsdb.retention.size=3GB   # Reduce to 3GB
```

2. Apply changes:
```bash
docker compose up -d --force-recreate prometheus
```

---

## Alert Rules Customization

### Understanding Alert Structure

**Location:** `prometheus/*.yml` files (12 files total)

**Basic Alert Anatomy:**

```yaml
groups:
  - name: example-alerts
    rules:
      - alert: HighCPUUsage              # Alert name (shows in notification)
        expr: cpu_usage > 80              # PromQL expression (when to fire)
        for: 5m                           # Fire only if true for 5 minutes
        labels:
          severity: warning               # Alert severity
        annotations:
          summary: "High CPU usage"       # Short description
          description: "CPU is at {{ $value }}%"  # Detailed info
```

**Key Components:**

- **expr**: PromQL query that must evaluate to true to fire
- **for**: Duration threshold must be exceeded before firing (prevents flapping)
- **severity**: `critical`, `warning`, or `info` (affects routing)
- **annotations**: Human-readable context (shows in email/Slack)

---

### Adjusting Alert Thresholds

**Example: Change CPU Alert Threshold**

**Before (80% threshold):**
```yaml
- alert: HostHighCpuLoad
  expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
  for: 5m
```

**After (90% threshold):**
```yaml
- alert: HostHighCpuLoad
  expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90
  for: 5m
```

**Apply Changes:**
```bash
# Validate syntax
docker exec prometheus promtool check rules /etc/prometheus/alerts.yml

# Hot reload
curl -X POST http://localhost:9090/-/reload
```

---

### Changing Alert Duration

**Example: Make Disk Alert More Patient**

**Before (fires after 5 minutes):**
```yaml
- alert: HostDiskSpaceLow
  expr: disk_usage > 80
  for: 5m
```

**After (fires after 1 hour):**
```yaml
- alert: HostDiskSpaceLow
  expr: disk_usage > 80
  for: 1h
```

**When to Increase Duration:**
- Non-critical alerts
- Metrics with expected fluctuations
- Resource-constrained systems with intermittent spikes

**When to Decrease Duration:**
- Critical security alerts
- Rapid failure conditions
- Early warning indicators

---

### Adding Custom Alert Rules

**Example: Alert on High Swap Usage**

1. Choose appropriate alert file (`prometheus/alerts.yml` for system alerts)

2. Add rule to existing group:

```yaml
groups:
  - name: host
    rules:
      # ... existing rules ...
      
      - alert: HighSwapUsage
        expr: (1 - (node_memory_SwapFree_bytes / node_memory_SwapTotal_bytes)) * 100 > 50
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High swap usage on {{ $labels.instance }}"
          description: "Swap usage is above 50% (current: {{ $value | printf \"%.1f\" }}%)"
```

3. Validate and reload:

```bash
docker exec prometheus promtool check rules /etc/prometheus/alerts.yml
curl -X POST http://localhost:9090/-/reload
```

4. Verify rule loaded:

```bash
# Check in Prometheus UI
open http://localhost:9090/rules

# Or via API
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[] | select(.name=="HighSwapUsage")'
```

---

### Disabling Specific Alerts

**Method 1: Comment Out (Temporary)**

```yaml
# - alert: AlertName
#   expr: some_metric > threshold
#   for: 5m
#   labels:
#     severity: warning
#   annotations:
#     summary: "Something happened"
```

**Method 2: Move to Archived (Permanent)**

```bash
# View archived alerts
ls prometheus/archived/

# Restore archived alert
# See prometheus/archived/README.md for instructions
```

**Method 3: Silence in Alertmanager (Runtime)**

```bash
# Create silence via UI
open http://localhost:9093/#/silences

# Or via API
curl -X POST http://localhost:9093/api/v1/silences \
  -H "Content-Type: application/json" \
  -d '{
    "matchers": [{"name":"alertname","value":"AlertName","isRegex":false}],
    "startsAt": "2026-02-08T00:00:00Z",
    "endsAt": "2026-12-31T23:59:59Z",
    "comment": "Disabled until further notice"
  }'
```

---

### Restoring Archived Alerts

See full restoration guide: `prometheus/archived/README.md`

**Quick Restore Example:**

```bash
# 1. View available archived files
ls prometheus/archived/*.full

# 2. Copy rules back to active file
cp prometheus/archived/fail2ban-alerts.yml.full prometheus/fail2ban-alerts.yml

# 3. Validate
docker exec prometheus promtool check rules /etc/prometheus/fail2ban-alerts.yml

# 4. Reload
curl -X POST http://localhost:9090/-/reload
```

**Understanding the Reduction:**
- Original: 122 alert rules
- Current: 97 alert rules (20.5% reduction)
- Rationale: See `prometheus/archived/REDUCTION_SUMMARY.md`

---

## Alertmanager Routing

### Configuration File

**Location:** `alertmanager/alertmanager.yml`

**Note:** Generated from `alertmanager/alertmanager.yml.template` with envsubst.

---

### Basic Routing Configuration

**Default Setup:**

```yaml
route:
  receiver: 'email-notifications'     # Default receiver
  group_by: ['alertname', 'severity', 'instance']
  group_wait: 30s        # Wait 30s to batch alerts
  group_interval: 5m     # Send update every 5m if more alerts
  repeat_interval: 4h    # Resend if still firing after 4h
  
  routes:
    - match:
        severity: critical
      receiver: 'email-critical'
      group_wait: 10s        # Critical alerts sent faster
      repeat_interval: 1h    # Resend more frequently
```

**Parameters Explained:**

- **group_by**: Group alerts with same labels into single notification
- **group_wait**: Wait time before sending first notification (allows batching)
- **group_interval**: Wait time before sending notification about updated group
- **repeat_interval**: How often to resend notification if alert still firing

---

### Routing by Severity

**Three-Tier Routing Example:**

```yaml
route:
  receiver: 'email-default'
  routes:
    # Critical: Immediate, frequent reminders
    - match:
        severity: critical
      receiver: 'pagerduty-oncall'
      group_wait: 10s
      repeat_interval: 30m
    
    # Warning: Batched, less frequent
    - match:
        severity: warning
      receiver: 'email-team'
      group_wait: 5m
      repeat_interval: 4h
    
    # Info: Daily digest
    - match:
        severity: info
      receiver: 'email-daily-digest'
      group_wait: 30m
      repeat_interval: 24h
```

---

### Multiple Receivers

**Email + Slack Example:**

```yaml
receivers:
  - name: 'email-and-slack'
    email_configs:
      - to: 'admin@example.com'
        send_resolved: true
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#alerts'
        title: '{{ .CommonLabels.alertname }}'
```

---

### Slack Integration

**Setup Steps:**

1. Create Slack Incoming Webhook:
   - Go to https://api.slack.com/apps
   - Create New App → Incoming Webhooks
   - Add to Workspace → Copy Webhook URL

2. Add Slack receiver to `alertmanager/alertmanager.yml`:

```yaml
receivers:
  - name: 'slack-notifications'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX'
        channel: '#homelab-alerts'
        username: 'Homelab Alertmanager'
        title: '{{ .Status | toUpper }}: {{ .CommonLabels.alertname }}'
        text: |-
          {{ range .Alerts }}
          *Summary:* {{ .Annotations.summary }}
          *Description:* {{ .Annotations.description }}
          *Severity:* {{ .Labels.severity }}
          *Instance:* {{ .Labels.instance }}
          {{ end }}
        send_resolved: true
```

3. Restart Alertmanager:
```bash
docker compose restart alertmanager
```

4. Test notification:
```bash
# Trigger test alert
curl -X POST http://localhost:9093/api/v1/alerts -d '[{
  "labels": {"alertname":"TestSlack","severity":"info"},
  "annotations": {"summary":"Testing Slack integration"}
}]'
```

---

### PagerDuty Integration

```yaml
receivers:
  - name: 'pagerduty-critical'
    pagerduty_configs:
      - service_key: 'YOUR_PAGERDUTY_INTEGRATION_KEY'
        severity: '{{ if eq .CommonLabels.severity "critical" }}critical{{ else }}warning{{ end }}'
        description: '{{ .CommonAnnotations.summary }}'
        details:
          firing: '{{ .Alerts.Firing | len }}'
          resolved: '{{ .Alerts.Resolved | len }}'
```

**Setup:**
1. In PagerDuty: Services → Add Service → Integration Type: "Prometheus"
2. Copy Integration Key
3. Paste into `service_key` above

---

### Alert Inhibition

Prevent redundant notifications when related alerts fire:

```yaml
inhibit_rules:
  # If critical firing, silence warning for same alert
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
  
  # If host down, silence all other alerts from that host
  - source_match:
      alertname: 'HostDown'
    target_match_re:
      alertname: '.*'
    equal: ['instance']
```

**Example Scenario:**
1. `HostHighCpuLoad` (warning) fires at 80% CPU
2. `HostCriticalCpuLoad` (critical) fires at 95% CPU
3. Inhibition rule suppresses warning notification (only critical sent)

---

### Time-Based Routing

**Example: Off-Hours Routing**

```yaml
route:
  routes:
    # Business hours: Page on-call
    - match:
        severity: critical
      receiver: 'pagerduty'
      active_time_intervals:
        - business_hours
    
    # Off-hours: Email only
    - match:
        severity: critical
      receiver: 'email'
      active_time_intervals:
        - off_hours

time_intervals:
  - name: business_hours
    time_intervals:
      - weekdays: ['monday:friday']
        times:
          - start_time: '09:00'
            end_time: '17:00'
  
  - name: off_hours
    time_intervals:
      - weekdays: ['monday:friday']
        times:
          - start_time: '17:00'
            end_time: '23:59'
          - start_time: '00:00'
            end_time: '09:00'
      - weekdays: ['saturday', 'sunday']
```

---

## Loki and Promtail

### Loki Configuration

**Location:** `loki/loki-config.yml`

**Key Settings:**

```yaml
server:
  http_listen_port: 3100

limits_config:
  retention_period: 168h        # 7 days retention
  ingestion_rate_mb: 10         # 10MB/s ingestion limit
  ingestion_burst_size_mb: 20   # Burst up to 20MB

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/boltdb-shipper-active
    cache_location: /loki/boltdb-shipper-cache
  filesystem:
    directory: /loki/chunks

compactor:
  retention_enabled: true       # Enable log deletion per retention
```

**Adjusting Retention:**

```yaml
limits_config:
  retention_period: 336h  # 14 days instead of 7
```

**Note:** Restart Loki after changes: `docker compose restart loki`

---

### Promtail Configuration

**Location:** `promtail/promtail-config.yml`

**Default Log Sources:**

```yaml
scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*.log

  - job_name: docker
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          __path__: /var/lib/docker/containers/*/*.log
```

---

### Adding Custom Log Sources

**Example: Add Application Logs**

```yaml
scrape_configs:
  # ... existing configs ...
  
  - job_name: myapp
    static_configs:
      - targets:
          - localhost
        labels:
          job: myapp
          app: myapp
          __path__: /opt/myapp/logs/*.log
    pipeline_stages:
      # Parse JSON logs
      - json:
          expressions:
            level: level
            message: message
      # Extract level as label
      - labels:
          level:
```

**Mount log directory in `compose.yaml`:**

```yaml
promtail:
  volumes:
    - /opt/myapp/logs:/opt/myapp/logs:ro
```

**Restart Promtail:**
```bash
docker compose restart promtail
```

---

### Log Parsing Pipeline

**Example: Parse Nginx Access Logs**

```yaml
- job_name: nginx
  static_configs:
    - targets:
        - localhost
      labels:
        job: nginx
        __path__: /var/log/nginx/access.log
  pipeline_stages:
    # Parse log format
    - regex:
        expression: '^(?P<remote_addr>[\w\.]+) - (?P<remote_user>[\w]+) \[(?P<time_local>.*)\] "(?P<request>.*)" (?P<status>[\d]+) (?P<body_bytes_sent>[\d]+)'
    # Extract status code as label
    - labels:
        status:
    # Drop debug logs
    - match:
        selector: '{job="nginx"} |= "healthcheck"'
        action: drop
```

---

## Grafana Provisioning

### Datasources

**Location:** `grafana/provisioning/datasources/datasources.yml`

**Default Configuration:**

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: false
```

**Adding Additional Datasource:**

```yaml
datasources:
  # ... existing ...
  
  - name: Prometheus-External
    type: prometheus
    access: proxy
    url: http://external-prometheus:9090
    basicAuth: true
    basicAuthUser: admin
    secureJsonData:
      basicAuthPassword: 'password'
```

**Note:** Datasources are provisioned at Grafana startup. To modify, edit file and restart:
```bash
docker compose restart grafana
```

---

### Dashboard Provisioning

**Location:** `grafana/provisioning/dashboards/dashboards.yml`

```yaml
apiVersion: 1

providers:
  - name: 'Homelab'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false  # Allow deletion via UI
    updateIntervalSeconds: 10
    allowUiUpdates: true    # Allow editing via UI
    options:
      path: /etc/grafana/provisioning/dashboards/json
```

**Dashboard JSON Files:** `grafana/provisioning/dashboards/json/*.json`

**Deploying New Dashboard:**

1. Export dashboard from Grafana UI (Share → Export → Save JSON)
2. Save JSON file to `grafana/provisioning/dashboards/json/`
3. Grafana auto-detects within 10 seconds (no restart needed)

---

### Grafana Environment Variables

Set in `compose.yaml` under `grafana` service:

```yaml
grafana:
  environment:
    # Security
    - GF_SECURITY_ADMIN_USER=${GRAFANA_ADMIN_USER:-admin}
    - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
    - GF_USERS_ALLOW_SIGN_UP=false
    
    # Server
    - GF_SERVER_ROOT_URL=http://homelab:3000
    
    # SMTP
    - GF_SMTP_ENABLED=true
    - GF_SMTP_HOST=${SMTP_HOST}
    
    # Logging
    - GF_LOG_MODE=console file
    - GF_LOG_LEVEL=info
```

**Change Log Level for Debugging:**

```yaml
- GF_LOG_LEVEL=debug  # Options: debug, info, warn, error
```

Restart Grafana: `docker compose restart grafana`

---

## Retention Policies

### Summary Table

| Component | Default Retention | Location | Configurable Via |
|-----------|-------------------|----------|------------------|
| Prometheus | 15 days or 5GB | `/srv/data/observability/prometheus` | `compose.yaml` command flags |
| Loki | 7 days | `/srv/data/observability/loki` | `loki-config.yml` |
| Grafana | Unlimited | `/srv/data/observability/grafana` | Manual cleanup |
| Alertmanager | 5 days | `/srv/data/observability/alertmanager` | Automatic |

---

### Prometheus Retention

**Two Limits (whichever hits first):**

1. **Time-based:** `--storage.tsdb.retention.time=15d`
2. **Size-based:** `--storage.tsdb.retention.size=5GB`

**Changing Retention:**

Edit `compose.yaml`:
```yaml
prometheus:
  command:
    - --storage.tsdb.retention.time=30d  # Increase to 30 days
    - --storage.tsdb.retention.size=10GB  # Increase to 10GB
```

Apply: `docker compose up -d --force-recreate prometheus`

**Storage Considerations:**

- Each day of metrics ≈ 50-100MB (depends on cardinality)
- Check current size: `du -sh /srv/data/observability/prometheus`
- Retention deletes oldest data first

---

### Loki Retention

**Configuration:** `loki/loki-config.yml`

```yaml
limits_config:
  retention_period: 336h  # 14 days (in hours)

compactor:
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150
```

**Apply Changes:**
```bash
docker compose restart loki
```

**Note:** Compactor runs periodically to delete old data. May take a few hours after restart.

---

### Grafana Dashboard Cleanup

Grafana stores dashboard history and snapshots - these grow over time.

**Manual Cleanup:**

```bash
# Enter Grafana container
docker exec -it grafana bash

# Database location
cd /var/lib/grafana

# Check database size
du -sh grafana.db

# Vacuum database (requires Grafana stop)
docker compose stop grafana
docker exec -it grafana sqlite3 /var/lib/grafana/grafana.db "VACUUM;"
docker compose start grafana
```

---

## Performance Tuning

### Resource-Constrained Systems (2-4GB RAM)

**Recommendations:**

1. **Reduce scrape frequency:**
   ```yaml
   # prometheus.yml
   global:
     scrape_interval: 60s  # From 30s
   ```

2. **Lower Prometheus retention:**
   ```yaml
   # compose.yaml
   - --storage.tsdb.retention.time=7d
   - --storage.tsdb.retention.size=3GB
   ```

3. **Disable high-cardinality collectors:**
   ```yaml
   # compose.yaml - node-exporter
   command:
     - --no-collector.wifi         # If no WiFi
     - --no-collector.hwmon         # If monitoring not needed
   ```

4. **Reduce memory limits (with caution):**
   ```yaml
   # compose.yaml
   prometheus:
     deploy:
       resources:
         limits:
           memory: 384M  # From 512M
   ```

---

### High-Performance Systems (8GB+ RAM)

**Optimizations:**

1. **Increase scrape frequency:**
   ```yaml
   global:
     scrape_interval: 15s
     evaluation_interval: 15s
   ```

2. **Increase retention:**
   ```yaml
   - --storage.tsdb.retention.time=30d
   - --storage.tsdb.retention.size=15GB
   ```

3. **Increase memory limits:**
   ```yaml
   prometheus:
     deploy:
       resources:
         limits:
           memory: 1G
   ```

4. **Enable query concurrency:**
   ```yaml
   prometheus:
     command:
       - --query.max-concurrency=20
       - --query.timeout=2m
   ```

---

### Cardinality Management

High cardinality = more unique time series = more memory.

**Check Cardinality:**

```bash
# Top 10 metrics by cardinality
curl -s http://localhost:9090/api/v1/status/tsdb | jq '.data.seriesCountByMetricName | to_entries | sort_by(.value) | reverse | .[0:10]'
```

**Common High-Cardinality Sources:**
- Container metrics (many containers)
- Labels with unique values (container IDs, PIDs)
- Network metrics (many interfaces)

**Solutions:**
1. **Drop high-cardinality metrics:**
   ```yaml
   scrape_configs:
     - job_name: 'cadvisor'
       metric_relabel_configs:
         - source_labels: [__name__]
           regex: 'container_network_.*'
           action: drop
   ```

2. **Limit label values:**
   ```yaml
   metric_relabel_configs:
     - source_labels: [container_label_com_docker_compose_project]
       action: keep
       regex: '(observability|core)'  # Only keep certain projects
   ```

---

## Advanced Configuration

### Prometheus Remote Write

Send metrics to external storage (e.g., Thanos, Cortex, VictoriaMetrics):

```yaml
# prometheus.yml
remote_write:
  - url: "http://remote-storage:9201/api/v1/push"
    basic_auth:
      username: admin
      password: password
    queue_config:
      capacity: 10000
      max_samples_per_send: 1000
      batch_send_deadline: 5s
```

---

### Prometheus Federation

Query metrics from multiple Prometheus instances:

```yaml
scrape_configs:
  - job_name: 'federate'
    scrape_interval: 60s
    honor_labels: true
    metrics_path: '/federate'
    params:
      'match[]':
        - '{job="prometheus"}'
        - '{__name__=~"job:.*"}'
    static_configs:
      - targets:
          - 'other-prometheus:9090'
```

---

### Custom Recording Rules

Pre-compute expensive queries:

```yaml
# prometheus/alerts.yml (or separate file)
groups:
  - name: recording-rules
    interval: 30s
    rules:
      # Pre-calculate CPU usage percentage
      - record: instance:cpu_usage:rate5m
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
      
      # Pre-calculate memory usage percentage
      - record: instance:memory_usage:percent
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```

**Usage in alerts:**
```yaml
- alert: HighCPU
  expr: instance:cpu_usage:rate5m > 80  # Faster query
```

---

### External Labels

Tag metrics with environment information:

```yaml
# prometheus.yml
global:
  external_labels:
    monitor: 'homelab'
    environment: 'production'
    cluster: 'main'
    region: 'us-east'
```

Useful for:
- Multi-cluster monitoring
- Identifying metric source in centralized systems
- Alert routing based on environment

---

## Configuration Validation

### Pre-Deployment Validation

```bash
# Validate Prometheus config
docker run --rm -v $(pwd)/prometheus:/etc/prometheus \
  prom/prometheus:v2.48.1 \
  promtool check config /etc/prometheus/prometheus.yml

# Validate all alert rules
for file in prometheus/*-alerts.yml; do
  echo "Checking $file..."
  docker run --rm -v $(pwd)/prometheus:/etc/prometheus \
    prom/prometheus:v2.48.1 \
    promtool check rules /etc/prometheus/$(basename $file)
done

# Validate Alertmanager config
docker run --rm -v $(pwd)/alertmanager:/etc/alertmanager \
  prom/alertmanager:v0.26.0 \
  amtool check-config /etc/alertmanager/alertmanager.yml
```

---

### Live Configuration Reload

```bash
# Check Prometheus config (doesn't apply)
curl -X POST http://localhost:9090/-/check

# Hot reload Prometheus (applies config)
curl -X POST http://localhost:9090/-/reload

# Check if reload succeeded
curl http://localhost:9090/api/v1/status/config | jq '.status'
# Expected: "success"
```

---

### Rollback Configuration

```bash
# Configurations are in git - rollback is easy
cd /opt/Homelab/stacks/observability

# View recent changes
git log --oneline -10 prometheus/

# Rollback to previous version
git checkout HEAD~1 prometheus/alerts.yml

# Reload Prometheus
curl -X POST http://localhost:9090/-/reload

# If that doesn't work, restore from git
git restore prometheus/alerts.yml
```

---

## Next Steps

- **[ALERTS.md](./ALERTS.md)** - Deep dive into alert rules and customization
- **[OPERATIONS.md](./OPERATIONS.md)** - Day-to-day operational procedures
- **[MONITORING.md](./MONITORING.md)** - What to monitor and when

---

**Configuration complete! Your stack is now tuned for your environment.** 🎛️

---
created: 2026-01-18
tags: [homelab, monitoring, prometheus, grafana, loki, observability]
aliases: ["monitoring setup", "prometheus grafana", "observability stack"]
---

# Homelab - Observability Stack

## Overview

Complete monitoring and logging solution for the homelab server.

Stack includes:

- **Prometheus** - Metrics collection and alerting
- **Grafana** - Visualization and dashboards
- **Loki** - Log aggregation
- **Promtail** - Log shipping
- **Alertmanager** - Alert routing (email notifications)
- **Node Exporter** - Host metrics
- **cAdvisor** - Container metrics

## Directory Layout

Production-safe separation of concerns:

```text
/opt/Homelab/stacks/observability/   # Source configs (git repo)
├── compose.yaml
├── .env.example
├── prometheus/
├── alertmanager/
├── loki/
├── promtail/
├── grafana/
└── systemd/

/srv/docker/observability/           # Runtime (compose + secrets)
├── compose.yaml → (symlink)
├── .env                             # Your secrets (chmod 600)
├── prometheus/ → (symlink)
├── loki/ → (symlink)
├── promtail/ → (symlink)
├── grafana/ → (symlink)
└── alertmanager/
    └── alertmanager.yml             # Generated from template

/srv/data/observability/             # Persistent data (survives updates)
├── prometheus/
├── grafana/
├── loki/
├── alertmanager/
└── promtail/
```

## Resource Usage

Optimized for low-resource systems (4GB RAM):

| Service | Memory Limit | Memory Reserved |
|---------|-------------|-----------------|
| Prometheus | 512 MB | 256 MB |
| Grafana | 256 MB | 128 MB |
| Loki | 256 MB | 128 MB |
| cAdvisor | 128 MB | 64 MB |
| Node Exporter | 64 MB | 32 MB |
| Promtail | 64 MB | 32 MB |
| Alertmanager | 64 MB | 32 MB |
| **Total** | **~1.3 GB** | **~670 MB** |

## Installation

### Prerequisites

- Docker and Docker Compose installed
- Email account for alerts (Gmail recommended)

### Steps

### 1. Run Install Script

```bash
homelab install observability
```

This creates the directory structure and copies `.env.example`.

### 2. Configure Environment

```bash
sudo nano /srv/docker/observability/.env
```

Required settings:

```bash
# REQUIRED - change this!
GRAFANA_ADMIN_PASSWORD=your-secure-password

# Email alerts (optional but recommended)
SMTP_HOST=smtp.gmail.com:587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password  # Use Gmail App Password
SMTP_FROM=homelab@gmail.com
ALERT_EMAIL=your-email@gmail.com
```

> **Gmail App Password:** Go to https://myaccount.google.com/apppasswords

### 3. Complete Installation

```bash
homelab install observability
```

The script will detect your configured `.env` and complete deployment.

### 4. Access Grafana

Grafana is bound to localhost only. Access via SSH tunnel:

```bash
# From your local machine
ssh -L 3000:localhost:3000 homelab

# Then open in browser
http://localhost:3000
```

Credentials:

- Username: `admin`
- Password: (from `.env` file)

## Usage

### CLI Commands

```bash
homelab observability install          # Deploy stack
homelab observability status           # Show status and URLs
homelab observability stop             # Stop all services
homelab observability restart          # Restart services
homelab observability logs             # Follow all logs
homelab observability logs loki        # Follow specific service
homelab observability regenerate-config # Regenerate alertmanager config
homelab observability destroy          # Remove stack and data
```

### Systemd Integration

The stack is managed via systemd for auto-start on boot:

```bash
systemctl status observability     # Check status
systemctl restart observability    # Restart stack
systemctl stop observability       # Stop stack
journalctl -u observability -f     # View logs
```

### Access Points

| Service | URL | Access |
|---------|-----|--------|
| Grafana | localhost:3000 | SSH tunnel |
| Prometheus | localhost:9090 | Local only |
| Alertmanager | localhost:9093 | Local only |
| Loki | localhost:3100 | Local only |

> All services are bound to localhost for security.
> Use SSH tunnel or access via Grafana.

## Dashboards

### Pre-installed Dashboards

| Dashboard | Description |
|-----------|-------------|
| Homelab System Overview | CPU, memory, disk, network gauges and graphs |

### Import Additional Dashboards

1. Go to Grafana → Dashboards → Import
2. Enter dashboard ID from [Grafana Dashboards](https://grafana.com/grafana/dashboards/)

Recommended:

- **1860** - Node Exporter Full
- **893** - Docker and Host Monitoring
- **13639** - Loki Dashboard

> **Important: Dashboard Portability**
> All datasources now have stable UIDs:
> - Prometheus: `prometheus`
> - Loki: `loki`
> - Alertmanager: `alertmanager`
>
> When importing dashboards from Grafana.com or sharing dashboards between instances:
> - Dashboards using these standard UID names will work without modification
> - No need to manually remap datasources after import
> - Exported dashboards remain portable across Homelab instances

## Configuration Details

### Datasource UIDs

All Grafana datasources use stable, predictable UIDs for reliable references:

| Datasource | UID | Purpose |
|------------|-----|---------|
| Prometheus | `prometheus` | Metrics queries and dashboard references |
| Loki | `loki` | Log queries and derived fields |
| Alertmanager | `alertmanager` | Alert management UI integration |

**Why UIDs Matter:**

1. **Dashboard Portability**: Dashboards exported from one instance work on another without datasource remapping
2. **Stable References**: Queries and alerts maintain references across Grafana restarts
3. **API Consistency**: External tools can reliably reference datasources via API
4. **Version Control**: Dashboard JSON files remain consistent for git tracking

**Technical Details:**
- UIDs are defined in `/opt/Homelab/stacks/observability/grafana/provisioning/datasources/datasources.yml`
- Provisioning happens at Grafana startup
- UIDs cannot be changed via Grafana UI (defined as `editable: false`)
- Custom datasources should follow the pattern: `<service-name>` (lowercase, no special chars)

See [ADR 0002: Datasource UID Stability](adr/0002-datasource-uid-stability.md) for architectural decision details.

### Healthcheck Implementations

The stack uses Docker healthchecks to ensure proper startup ordering and failure detection:

| Service | Method | Endpoint | Notes |
|---------|--------|----------|-------|
| Prometheus | wget | `/-/healthy` | Standard Prometheus endpoint |
| Loki | wget | `/ready` | Waits for storage initialization |
| Grafana | wget | `/api/health` | Checks database and provisioning |
| Alertmanager | wget | `/-/healthy` | Standard Alertmanager endpoint |
| Node Exporter | wget | `/metrics` | Simple metric availability check |
| cAdvisor | wget | `/healthz` | Built-in healthz endpoint |
| Promtail | bash TCP | `:9080/ready` | **No wget in image** - uses `/dev/tcp` |

**Promtail Healthcheck Details:**

Promtail uses a bash TCP connection check instead of wget:

```yaml
test:
  [
    "CMD-SHELL",
    "bash -lc 'exec 3<>/dev/tcp/127.0.0.1/9080; printf \"GET /ready HTTP/1.1\\r\\nHost: localhost\\r\\nConnection: close\\r\\n\\r\\n\" >&3; read -r line <&3; [[ \"$$line\" == *\"200\"* ]]'",
  ]
```

**Why not wget?:**
- The `grafana/promtail` official image is built on a minimal base without `wget` or `curl`
- Adding these tools would increase image size unnecessarily
- Bash is available and `/dev/tcp` is a built-in bash feature
- This approach is more lightweight and faster than spawning wget

**How it works:**
1. Opens TCP connection to `127.0.0.1:9080` (file descriptor 3)
2. Sends HTTP GET request to `/ready` endpoint
3. Reads response line
4. Checks for `200` status code in response
5. Returns success (0) or failure (non-zero) exit code

**Troubleshooting TCP healthcheck:**
```bash
# Test manually inside container
docker exec promtail bash -c 'exec 3<>/dev/tcp/127.0.0.1/9080 && echo "Connection OK"'

# Check if promtail HTTP server is running
docker exec promtail netstat -tlnp | grep 9080

# View raw healthcheck logs
docker inspect promtail | jq '.[0].State.Health.Log[-3:]'
```

See [ADR 0001: Healthcheck Strategies](adr/0001-healthcheck-strategies.md) for the full decision context.

## Alerts

### Configured Alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| HostHighCpuLoad | CPU > 80% for 5m | Warning |
| HostCriticalCpuLoad | CPU > 95% for 2m | Critical |
| HostHighMemoryUsage | Memory > 80% for 5m | Warning |
| HostCriticalMemoryUsage | Memory > 95% for 2m | Critical |
| HostDiskSpaceLow | Disk > 80% for 5m | Warning |
| HostDiskSpaceCritical | Disk > 90% for 2m | Critical |
| HostDiskWillFillIn24Hours | Predictive | Warning |
| HostDown | Node exporter down | Critical |
| ContainerDown | Container stopped | Warning |
| ContainerHighCpu | Container CPU > 80% | Warning |
| ContainerRestarting | >3 restarts/hour | Warning |

### Alert Flow

```text
Prometheus → Alertmanager → Email
     ↓
  Grafana (also shows alerts)
```

## Data Retention

| Data Type | Retention | Storage Limit |
|-----------|-----------|---------------|
| Metrics (Prometheus) | 15 days | 5 GB |
| Logs (Loki) | 7 days | Unlimited |

## Logs

### View Logs in Grafana

1. Go to Explore → Select Loki
2. Use LogQL queries:

```logql
{job="syslog"}              # System logs
{job="auth"}                # Auth/SSH logs
{job="docker"}              # Container logs
{job="docker"} |= "error"   # Container errors
```

### Available Log Sources

| Job | Source |
|-----|--------|
| syslog | /var/log/syslog |
| auth | /var/log/auth.log |
| kernel | /var/log/kern.log |
| docker | Docker container logs |

## Troubleshooting

### Stack Not Starting

Check Docker status:

```bash
docker compose -f /opt/Homelab/stacks/observability/compose.yaml ps
docker compose -f /opt/Homelab/stacks/observability/compose.yaml logs
```

#### Healthcheck Failures

If containers show as unhealthy:

```bash
docker compose -f /opt/Homelab/stacks/observability/compose.yaml ps
```

**Promtail healthcheck specifics:**
- The promtail image does not include `wget` or `curl`
- Uses bash TCP connection check instead: `/dev/tcp/127.0.0.1/9080`
- If healthcheck fails, verify promtail is listening: `docker logs promtail`
- Port 9080 is promtail's HTTP server for metrics and health endpoint

**General healthcheck debugging:**
```bash
# Check specific container health
docker inspect --format='{{json .State.Health}}' <container_name> | jq

# View healthcheck logs
docker inspect <container_name> | jq '.[0].State.Health.Log'
```

See [ADR 0001: Healthcheck Strategies](adr/0001-healthcheck-strategies.md) for technical details.

### No Email Alerts

1. Check Alertmanager config:

```bash
docker exec alertmanager cat /etc/alertmanager/alertmanager.yml
```

2. Test SMTP connectivity:

```bash
docker exec alertmanager wget -qO- http://localhost:9093/api/v1/status
```

3. Check for Gmail blocking - use App Password

### High Memory Usage

If stack uses too much memory:

```bash
# Reduce Prometheus retention
# Edit compose.yaml: --storage.tsdb.retention.time=7d

# Or disable Loki temporarily
docker compose stop loki promtail
```

### Prometheus Targets Down

Check targets status:

```bash
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
```

## File Locations

```text
/opt/Homelab/stacks/observability/    # Source (git tracked)
├── compose.yaml                      # Docker Compose file
├── .env.example                      # Template for secrets
├── prometheus/
│   ├── prometheus.yml                # Prometheus config
│   └── alerts.yml                    # Alert rules
├── alertmanager/
│   └── alertmanager.yml.template     # Email template (uses placeholders)
├── loki/
│   └── loki-config.yml               # Loki config
├── promtail/
│   └── promtail-config.yml           # Log sources
├── grafana/
│   └── provisioning/
│       ├── datasources/              # Auto-configured datasources
│       │   └── datasources.yml      # Prometheus, Loki, Alertmanager
│       │                            # All use stable UIDs for portability
│       │                            # prometheus, loki, alertmanager
│       └── dashboards/               # Auto-imported dashboards
└── systemd/
    └── observability.service         # Systemd unit

/srv/docker/observability/            # Runtime
├── .env                              # Your secrets (not in git)
└── alertmanager/
    └── alertmanager.yml              # Generated from template

/srv/data/observability/              # Persistent data
├── prometheus/                       # Metrics TSDB
├── grafana/                          # Dashboards, users
├── loki/                             # Log chunks
├── alertmanager/                     # Silences, notifications
└── promtail/                         # Positions file
```

## Backup

### What to Backup

| Path | Contents | Priority |
|------|----------|----------|
| `/srv/docker/observability/.env` | Secrets | Critical |
| `/srv/data/observability/grafana/` | Dashboards, users | High |
| `/srv/data/observability/alertmanager/` | Silences | Medium |

### Backup Script

```bash
#!/bin/bash
BACKUP_DIR="/backup/observability-$(date +%Y%m%d)"
mkdir -p "${BACKUP_DIR}"

# Backup secrets
cp /srv/docker/observability/.env "${BACKUP_DIR}/"

# Backup Grafana data
sudo tar -czf "${BACKUP_DIR}/grafana.tar.gz" /srv/data/observability/grafana/

# Backup alertmanager state
sudo tar -czf "${BACKUP_DIR}/alertmanager.tar.gz" /srv/data/observability/alertmanager/
```

> **Note:** Prometheus and Loki data can be regenerated. Only back up if you need historical data.

## Updating

Update to latest images:

```bash
cd /srv/docker/observability
docker compose pull
sudo systemctl restart observability
```

Or use the CLI:

```bash
homelab observability restart
```

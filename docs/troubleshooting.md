---
created: 2026-01-24
tags: [homelab, troubleshooting, debugging, docker, healthchecks]
aliases: ["debugging", "common issues", "problem solving"]
---

# Homelab - Troubleshooting Guide

## Overview

Common issues and solutions for Homelab infrastructure.

---

## Docker Issues

### Container Health Checks

#### Understanding Health States

Docker containers can be in these health states:

- `starting` - Initial health checks in progress (during `start_period`)
- `healthy` - All recent health checks passed
- `unhealthy` - Health check failed `retries` times

Check container health:

```bash
# All containers with health status
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Health}}"

# Detailed health info for specific container
docker inspect --format='{{json .State.Health}}' <container> | jq
```

#### Health Check Failures

**Symptom**: Container shows as "unhealthy" or constantly restarting

**Diagnosis:**

1. Check health check logs:
```bash
docker inspect <container> | jq '.[0].State.Health.Log[-5:]'
```

2. Check container logs:
```bash
docker logs <container> --tail 100
```

3. Check if service is actually running:
```bash
docker exec <container> ps aux
```

**Common Causes:**

| Issue | Solution |
|-------|----------|
| Service not ready | Increase `start_period` in compose.yaml |
| Service on wrong port | Verify port matches healthcheck test |
| Missing health tool | Use bash TCP check (see Promtail example) |
| Service crashed | Check logs for errors |

#### Promtail Healthcheck Pattern

The promtail container doesn't include `wget` or `curl`. Use this bash TCP pattern:

```yaml
healthcheck:
  test:
    [
      "CMD-SHELL",
      "bash -lc 'exec 3<>/dev/tcp/127.0.0.1/PORT; printf \"GET /endpoint HTTP/1.1\\r\\nHost: localhost\\r\\nConnection: close\\r\\n\\r\\n\" >&3; read -r line <&3; [[ \"$$line\" == *\"200\"* ]]'",
    ]
```

**Testing bash TCP healthcheck manually:**

```bash
# Inside container
docker exec <container> bash -c 'exec 3<>/dev/tcp/127.0.0.1/9080 && echo "TCP OK"'

# Check if port is listening
docker exec <container> netstat -tlnp | grep 9080
```

See [ADR 0001: Healthcheck Strategies](adr/0001-healthcheck-strategies.md) for full details.

---

## Observability Stack Issues

### Grafana

#### Login Issues

**Symptom**: Cannot log in to Grafana, "Invalid username or password"

**Solution:**
```bash
# Reset admin password
homelab observability reset-password

# Or manually
docker exec -it grafana grafana-cli admin reset-admin-password <newpassword>
```

#### Datasources Not Working

**Symptom**: Queries fail with "Data source not found" or datasource shows as unavailable

**Diagnosis:**

1. Check datasource health:
   - Go to Grafana → Configuration → Data sources
   - Click "Test" button on each datasource

2. Verify provisioning loaded:
```bash
docker exec grafana ls -la /etc/grafana/provisioning/datasources/
docker logs grafana | grep -i datasource
```

**Common Issues:**

| Error | Cause | Solution |
|-------|-------|----------|
| "Connection refused" | Target service not running | Check service health: `docker ps` |
| "Data source not found" | Wrong UID in dashboard | Verify dashboard uses correct UIDs |
| "Unauthorized" | Missing auth config | Check datasources.yml for auth settings |
| "Timeout" | Service overloaded | Check memory limits, increase if needed |

**Stable UIDs:**
- Prometheus: `prometheus`
- Loki: `loki`
- Alertmanager: `alertmanager`

If importing dashboards, ensure they reference these UIDs.

See [ADR 0002: Datasource UID Stability](adr/0002-datasource-uid-stability.md) for details.

#### Dashboard Import Issues

**Symptom**: Imported dashboard shows "N/A" or "No Data" for all panels

**Solution:**

1. Check datasource references in dashboard JSON:
```bash
cat dashboard.json | jq '.panels[].datasource'
```

2. Update datasource UIDs if needed:
```bash
# Replace old UID with new
sed -i 's/"datasource": "old-uid"/"datasource": "prometheus"/g' dashboard.json
```

3. Re-import dashboard

### Prometheus

#### Targets Down

**Symptom**: Prometheus shows targets as "DOWN" in Status → Targets

**Diagnosis:**

```bash
# Check target health via API
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health, error: .lastError}'
```

**Common Causes:**

| Target | Error | Solution |
|--------|-------|----------|
| node-exporter | "Connection refused" | Check container: `docker ps \| grep node-exporter` |
| cadvisor | "Timeout" | Check if cAdvisor is responsive: `curl http://localhost:8080/metrics` |
| prometheus | "Dial tcp: lookup" | DNS resolution issue, check network |

### Loki

#### No Logs Visible

**Symptom**: Grafana Explore shows no logs from Loki

**Diagnosis:**

1. Check Promtail is shipping logs:
```bash
docker logs promtail | grep -i "sent"
```

2. Check Loki received logs:
```bash
curl -s http://localhost:3100/loki/api/v1/label | jq
```

3. Verify log files are readable:
```bash
ls -la /var/log/syslog /var/log/auth.log
docker exec promtail ls -la /var/log/
```

**Solutions:**

| Issue | Fix |
|-------|-----|
| Permission denied | Promtail needs read access: `sudo chmod +r /var/log/*` |
| Wrong log path | Check promtail-config.yml path matches host |
| Loki storage full | Check disk space: `df -h` |

### Alertmanager

#### No Email Alerts

See [Observability Documentation - Troubleshooting - No Email Alerts](observability.md#no-email-alerts)

---

## systemd-networkd Issues

See [systemd-networkd Documentation](systemd-networkd.md)

---

## Dotfiles Issues

### Stow Conflicts

**Symptom**: `stow` command fails with "existing target is not a link"

**Solution:**
```bash
# Backup and remove conflicting files
mkdir -p ~/.dotfiles_backup
mv ~/.bashrc ~/.dotfiles_backup/
mv ~/.config/bash ~/.dotfiles_backup/

# Restow
homelab dotfiles restow
```

### Bash Configuration Not Loading

**Symptom**: After stow, bash prompt or aliases don't work

**Diagnosis:**

1. Check symlinks:
```bash
ls -la ~/.bashrc
ls -la ~/.config/bash/
```

2. Check bash is sourcing config:
```bash
grep -i "config/bash" ~/.bashrc
```

**Solution:**
```bash
# Reload shell
exec bash

# Or source manually
source ~/.bashrc
```

---

## General Debugging

### Container Logs

```bash
# All containers in compose stack
docker compose -f /opt/Homelab/stacks/observability/compose.yaml logs

# Specific service
docker compose logs -f <service_name>

# Follow logs with timestamps
docker logs -f --timestamps <container_name>
```

### System Resources

```bash
# Memory usage by container
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}"

# Disk space
df -h /srv/data/

# Running containers
docker ps -a
```

### Network Issues

```bash
# Check Docker network
docker network inspect observability

# Test connectivity between containers
docker exec <container1> ping <container2>

# Check port bindings
netstat -tlnp | grep -E '(3000|9090|3100)'
```

---

## Getting Help

### Logs to Collect

When reporting issues, collect:

```bash
# System info
uname -a
docker version
docker compose version

# Service status
systemctl status observability
docker ps -a

# Recent logs
docker compose logs --tail=100 > docker-logs.txt
journalctl -u observability --since "1 hour ago" > systemd-logs.txt

# Health status
docker inspect <container> | jq '.[0].State.Health' > health-status.json
```

### Useful Commands

| Command | Purpose |
|---------|---------|
| `homelab help` | List all CLI commands |
| `systemctl status observability` | Check systemd service status |
| `docker compose config` | Validate compose.yaml syntax |
| `docker system df` | Show Docker disk usage |
| `docker system prune` | Clean up unused Docker resources |

---

## Related Documentation

- [Observability Stack Documentation](observability.md)
- [ADR 0001: Healthcheck Strategies](adr/0001-healthcheck-strategies.md)
- [ADR 0002: Datasource UID Stability](adr/0002-datasource-uid-stability.md)

# Migration Guide - February 2026 Updates

**For users upgrading from previous observability stack configurations**

## What Changed?

### Alert Rules Reduction (122 → 97 rules)

We reduced alert rules by 20.5% to eliminate noise while maintaining comprehensive security and availability monitoring.

### Dashboard Cleanup (7 → 6 dashboards)

Removed redundant `security-monitoring-overview.json` dashboard that duplicated the main security dashboard.

### New Documentation & Tools

Added production-grade documentation and operational tools.

---

## Should I Upgrade?

### ✅ Upgrade If:

- You're experiencing alert fatigue
- You want better documentation
- You need operational validation scripts
- You want standardized alert notification configs

### ⚠️ Skip If:

- You've customized alert rules extensively
- Your dashboards have custom modifications
- You prefer the original 122-rule configuration

---

## Pre-Migration Checklist

```bash
# 1. Backup current configuration
cd stacks/observability
mkdir -p backups/$(date +%Y%m%d)
cp -r prometheus/*.yml backups/$(date +%Y%m%d)/
cp -r grafana/provisioning/dashboards/json/*.json backups/$(date +%Y%m%d)/
cp alertmanager/alertmanager.yml backups/$(date +%Y%m%d)/

# 2. Document current alert count (for verification)
curl -s http://localhost:9090/api/v1/rules | jq '[.data.groups[].rules[]] | length'
# Save this number for comparison

# 3. Export current dashboard list
curl -s http://localhost:3000/api/search?type=dash-db | jq -r '.[].title' > backups/$(date +%Y%m%d)/dashboards.txt

# 4. Check for firing alerts
curl -s http://localhost:9090/api/v1/alerts | jq -r '.data.alerts[] | select(.state=="firing") | .labels.alertname'
# Document any currently firing alerts
```

---

## Migration Options

### Option 1: Clean Upgrade (Recommended)

**Best for:** Users who want the full benefit of optimizations

```bash
# 1. Pull latest changes
cd /home/ssk/Code/Projects/building/Homelab
git fetch origin
git pull origin main

# 2. Stop observability stack
./cli/homelab.sh observability stop

# 3. Validate new configuration
cd stacks/observability
./scripts/validate-alerts.sh

# 4. Start with new configuration
./cli/homelab.sh observability start

# 5. Verify health
./scripts/health-check.sh

# 6. Check alert count
curl -s http://localhost:9090/api/v1/rules | jq '[.data.groups[].rules[]] | length'
# Should output: 97

# 7. Verify dashboards
curl -s http://localhost:3000/api/search?type=dash-db | jq length
# Should output: 6
```

**Rollback if needed:**
```bash
# Restore from backup
cd stacks/observability
cp backups/$(date +%Y%m%d)/prometheus/*.yml prometheus/
./cli/homelab.sh observability restart
```

---

### Option 2: Gradual Migration

**Best for:** Users with custom modifications

#### Step 1: Keep All Rules, Add New Tools

```bash
# Pull latest changes
git pull origin main

# Restore archived rules if you want them all
cd stacks/observability/prometheus/archived
cp *.full ../
cd ..
for f in archived/*.full; do
    mv "$f" "$(basename "$f" .full)"
done

# Now you have 122 rules + new documentation + new scripts
./scripts/validate-alerts.sh
./scripts/health-check.sh
```

#### Step 2: Test New Documentation

```bash
# Try quick start guide
cat docs/QUICKSTART.md

# Try health check
./scripts/health-check.sh

# Configure alertmanager using examples
cat docs/ALERTMANAGER_EXAMPLES.md
```

#### Step 3: Selectively Adopt Reductions

Review `prometheus/archived/REDUCTION_SUMMARY.md` and choose which rules to remove:

```bash
# Example: Remove only fail2ban noise (71% reduction)
cp prometheus/fail2ban-alerts.yml prometheus/fail2ban-alerts.yml.old
# Edit prometheus/fail2ban-alerts.yml to keep only critical rules
./scripts/validate-alerts.sh

# If validation passes, restart
./cli/homelab.sh observability reload
```

---

### Option 3: Cherry-Pick Features

**Best for:** Users who only want specific improvements

#### Just Add Scripts

```bash
# Add operational scripts without changing configuration
git checkout main -- stacks/observability/scripts/

chmod +x stacks/observability/scripts/*.sh

# Now you can use:
./stacks/observability/scripts/health-check.sh
./stacks/observability/scripts/validate-alerts.sh
```

#### Just Add Documentation

```bash
# Get new documentation without changing configs
git checkout main -- stacks/observability/docs/

# Now you have:
# - QUICKSTART.md
# - ALERTMANAGER_EXAMPLES.md
# - Updated other docs
```

#### Just Remove Dashboard

```bash
# Remove redundant dashboard
rm stacks/observability/grafana/provisioning/dashboards/json/security-monitoring-overview.json
docker restart observability-grafana-1
```

---

## Post-Migration Verification

### 1. Alert Rules Check

```bash
# Run validation
cd stacks/observability
./scripts/validate-alerts.sh

# Expected output:
# Total files validated: 12
# Valid files:           12
# Invalid files:         0
# Total alert rules:     97 (or 122 if you kept all)
```

### 2. Health Check

```bash
./scripts/health-check.sh

# Should show all green checks
# Any failures indicate issues to fix
```

### 3. Dashboard Verification

```bash
# Check Grafana has 6 dashboards (or 7 if you kept old one)
curl -s http://localhost:3000/api/search?type=dash-db | jq length

# List dashboard names
curl -s http://localhost:3000/api/search?type=dash-db | jq -r '.[].title'
```

### 4. Alert Delivery Test

```bash
# Send test alert
curl -X POST http://localhost:9093/api/v2/alerts -H "Content-Type: application/json" -d '[
  {
    "labels": {
      "alertname": "MigrationTest",
      "severity": "warning"
    },
    "annotations": {
      "summary": "Testing alert delivery after migration",
      "description": "If you receive this, your alerting is working"
    }
  }
]'

# Check alert appears in Alertmanager
curl -s http://localhost:9093/api/v2/alerts | jq '.[] | select(.labels.alertname=="MigrationTest")'
```

### 5. Dead Man's Switch

```bash
# Should be firing (proves alerting works)
curl -s http://localhost:9090/api/v1/alerts | \
  jq '.data.alerts[] | select(.labels.alertname=="DeadMansSwitch")'
```

---

## What Was Removed?

### Alert Rules Removed

**Fail2Ban (10 rules removed):**
- PersistentAttacker (informational, not actionable)
- ChronicAttacker (informational, not actionable)
- ShortBanDuration (configuration noise)
- TorExitNodeBan (broken without GeoIP)
- RecurrentBanSameIP (duplicate of others)
- BanDurationSpike (baseline-dependent)

**CRON (5 rules removed):**
- Excessive failures (baseline-dependent)
- Never succeeded (better covered by main rule)
- Duration anomalies (baseline-dependent)

**Port Monitoring (5 rules removed):**
- Baseline-dependent change detection
- Kept critical: unexpected opens, privileged ports

**Privilege Escalation (3 rules removed):**
- Pattern-based rules without learning phase
- Kept critical: SUID changes, direct escalation

**User Management (2 rules removed):**
- Baseline-dependent anomalies
- Kept critical: root activity, suspicious changes

**See:** `prometheus/archived/REDUCTION_SUMMARY.md` for full details

### Dashboard Removed

- `security-monitoring-overview.json` - Redundant with main security dashboard

---

## What Was Added?

### Documentation

1. **QUICKSTART.md** - 10-minute setup guide
2. **ALERTMANAGER_EXAMPLES.md** - Ready-to-use configs for:
   - Slack integration
   - Email (Gmail & SMTP)
   - Discord integration
   - Telegram integration
   - PagerDuty integration
   - Multi-channel routing

### Scripts

1. **scripts/validate-alerts.sh** - Validate alert rules before deployment
2. **scripts/health-check.sh** - Comprehensive health verification

### Safety Features

1. **Archived rules** - All removed rules backed up in `prometheus/archived/`
2. **Restoration guide** - `prometheus/archived/README.md`
3. **Change rationale** - `prometheus/archived/REDUCTION_SUMMARY.md`

---

## Troubleshooting Migration Issues

### Issue: More/fewer rules loaded than expected

```bash
# Check what's actually loaded
curl -s http://localhost:9090/api/v1/rules | jq '[.data.groups[].rules[]] | length'

# Compare with file count
cd stacks/observability/prometheus
for f in *-alerts.yml alerts.yml; do
    grep -c "alert:" "$f"
done | paste -sd+ | bc

# If mismatch, check Prometheus logs
docker logs observability-prometheus-1 | grep -i error
```

### Issue: Dashboard still shows 7 dashboards

```bash
# Manually delete from Grafana
DASHBOARD_UID=$(curl -s http://localhost:3000/api/search?query="Security%20Monitoring%20Overview" | jq -r '.[0].uid')
curl -X DELETE http://localhost:3000/api/dashboards/uid/${DASHBOARD_UID}

# Or restart Grafana
docker restart observability-grafana-1
```

### Issue: Alerts not firing

```bash
# Check Alertmanager logs
docker logs observability-alertmanager-1 --tail 100

# Check Prometheus can reach Alertmanager
curl -s http://localhost:9090/api/v1/alertmanagers | jq

# Reload Prometheus
curl -X POST http://localhost:9090/-/reload
```

### Issue: Scripts not executable

```bash
chmod +x stacks/observability/scripts/*.sh
```

---

## Reverting to Previous Configuration

### Full Rollback

```bash
# Stop stack
./cli/homelab.sh observability stop

# Restore from backup
cd stacks/observability
cp backups/YYYYMMDD/prometheus/*.yml prometheus/
cp backups/YYYYMMDD/*.json grafana/provisioning/dashboards/json/

# Restart
./cli/homelab.sh observability start

# Verify
curl -s http://localhost:9090/api/v1/rules | jq '[.data.groups[].rules[]] | length'
```

### Partial Rollback (Just Alert Rules)

```bash
# Restore specific rule file from archive
cd stacks/observability/prometheus
cp archived/fail2ban-alerts.yml.full fail2ban-alerts.yml

# Validate
docker run --rm \
  -v $(pwd)/fail2ban-alerts.yml:/tmp/rules.yml:ro \
  --entrypoint /bin/promtool \
  prom/prometheus:v2.48.1 \
  check rules /tmp/rules.yml

# Hot reload (no restart needed)
curl -X POST http://localhost:9090/-/reload
```

---

## Getting Help

### Check Documentation

- **Setup issues:** `docs/QUICKSTART.md` or `docs/INSTALLATION.md`
- **Alert questions:** `docs/ALERTS.md`
- **Configuration:** `docs/CONFIGURATION.md`
- **Operations:** `docs/OPERATIONS.md`

### Run Health Check

```bash
./stacks/observability/scripts/health-check.sh
```

This provides detailed diagnostics of what's working and what's not.

### Check Logs

```bash
# All services
docker compose -f stacks/observability/compose.yaml logs --tail 100

# Specific service
docker logs observability-prometheus-1 --tail 50
docker logs observability-alertmanager-1 --tail 50
```

### Validate Configuration

```bash
# Validate alert rules
./stacks/observability/scripts/validate-alerts.sh

# Validate compose file
cd stacks/observability
docker compose config --quiet && echo "Valid"
```

---

## Migration Checklist

Before migration:
- [ ] Backed up current configuration to `backups/YYYYMMDD/`
- [ ] Documented current alert count
- [ ] Documented currently firing alerts
- [ ] Exported dashboard list

After migration:
- [ ] Validated alert rules with `validate-alerts.sh`
- [ ] Ran health check with `health-check.sh`
- [ ] Verified alert count matches expectation (97 or 122)
- [ ] Verified dashboard count (6 or 7)
- [ ] Tested alert delivery with test alert
- [ ] Confirmed Dead Man's Switch is firing
- [ ] Reviewed new documentation

Optional enhancements:
- [ ] Configured Alertmanager notifications (Slack/email)
- [ ] Set up alert routing for different severity levels
- [ ] Customized dashboard layouts
- [ ] Added monitoring baselines to documentation

---

## Success Criteria

Your migration is successful when:

1. ✅ All containers running: `docker ps | grep observability` shows 4 containers
2. ✅ Health check passes: `./scripts/health-check.sh` exits 0
3. ✅ Alert rules valid: `./scripts/validate-alerts.sh` exits 0
4. ✅ Expected alert count: 97 rules (or 122 if you kept all)
5. ✅ Dashboards load: Grafana shows 6 dashboards (or 7 if you kept old one)
6. ✅ Dead Man's Switch firing: Proves alerting works
7. ✅ Test alert delivers: Alertmanager processes test alerts

---

**Questions?** Review `docs/README.md` for full documentation index.

**Found an issue?** Check `docs/OPERATIONS.md` troubleshooting section.

**Need to rollback?** See "Reverting to Previous Configuration" above.

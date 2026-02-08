# Monitoring Guide

**What to monitor daily, weekly, and monthly for a healthy homelab**

---

## Table of Contents

- [Monitoring Philosophy](#monitoring-philosophy)
- [Daily Monitoring Routine](#daily-monitoring-routine)
- [Weekly Review](#weekly-review)
- [Monthly Assessment](#monthly-assessment)
- [Understanding Normal vs Abnormal](#understanding-normal-vs-abnormal)
- [Self-Monitoring](#self-monitoring)
- [Performance Baselines](#performance-baselines)
- [Alert Fatigue Prevention](#alert-fatigue-prevention)
- [Monitoring Checklists](#monitoring-checklists)

---

## Monitoring Philosophy

### The Golden Signals

Monitor these four key metrics for any system:

1. **Latency** - How fast is it responding?
2. **Traffic** - How much demand is it serving?
3. **Errors** - What's failing?
4. **Saturation** - How full is it?

### Homelab-Specific Considerations

**Different from Enterprise:**

| Enterprise | Homelab |
|------------|---------|
| 24/7 on-call team | You are the team |
| Redundant everything | Single host often |
| SLA commitments | Learning and experimentation |
| Alert fatigue unacceptable | Balance alerts vs. noise |

**Result:** Homelab monitoring focuses on:
- Actionable alerts only
- Trend identification (capacity planning)
- Security event detection
- Learning opportunities

---

## Daily Monitoring Routine

### Quick Morning Check (5 minutes)

**Goal:** Verify systems operational, no overnight issues

**Checklist:**

```
1. Open Grafana: http://localhost:3000
2. Dashboard: "Homelab System Overview"
   └─ All gauges green? ✅ Done (< 1 minute)
   └─ Any yellow/red? Investigate

3. Dashboard: "Security Monitoring"
   └─ SSH Login Attempts - attacks overnight?
   └─ Fail2ban Status - protection active?
   └─ Critical File Modifications - unauthorized changes?

4. Check Active Alerts (if any)
   └─ Alertmanager: http://localhost:9093/#/alerts
   └─ Any critical alerts? Investigate immediately
   └─ Any warnings? Note for later

5. Systemd Services
   └─ Quick glance: Any failed services?
   └─ `docker compose ps` - all healthy?
```

**Expected Time:**
- 🟢 All green: 1-2 minutes
- 🟡 Minor issues: 5-10 minutes
- 🔴 Critical issues: Immediate attention

---

### What "Healthy" Looks Like

**Homelab System Overview Dashboard:**

```
┌─────────────────────────────────────┐
│ CPU Usage          │  35%   🟢      │  < 70% = Good
│ Memory Usage       │  45%   🟢      │  < 80% = Good
│ Disk Usage         │  62%   🟢      │  < 80% = Good
│ System Load (5m)   │  0.8   🟢      │  < 2.0 = Good (2 CPUs)
│ Network Traffic    │  50Mbps 🟢     │  No spikes
│ Uptime             │  12 days 🟢    │  Stable
└─────────────────────────────────────┘
```

**Security Monitoring Dashboard:**

```
┌─────────────────────────────────────┐
│ SSH Failed Logins  │   3    🟢      │  < 10/day = Normal
│ Fail2ban Active    │   Yes  🟢      │  Service running
│ Active Bans        │   1    🟢      │  0-2 = Normal
│ Sudo Commands      │   5    🟢      │  Normal activity
│ File Modifications │   0    🟢      │  No unauthorized
└─────────────────────────────────────┘
```

---

### When to Investigate

**Immediate Investigation Required:**

- ❌ Any service showing "unhealthy" or "restarting"
- ❌ CPU/Memory >95% sustained
- ❌ Disk >90% full
- ❌ Critical alerts firing
- ❌ SSH brute force attack (>20 failures/5min)
- ❌ Unexpected file modifications in /etc/

**Schedule Investigation (non-urgent):**

- ⚠️ CPU/Memory 80-90% sustained
- ⚠️ Disk 80-90% full
- ⚠️ Warning alerts firing
- ⚠️ Service restarted once
- ⚠️ Unusual network traffic patterns

**Note and Monitor:**

- ℹ️ Minor SSH login failures (< 10/day)
- ℹ️ Normal sudo activity
- ℹ️ Expected cron job executions
- ℹ️ Container restarts after updates

---

## Weekly Review

### Sunday Morning Review (30 minutes)

**Goal:** Identify trends, prevent future issues, capacity planning

---

### 1. Resource Trends (10 minutes)

**Dashboard:** Homelab System Overview

**Questions to Answer:**

1. **CPU Usage:**
   - Any increasing trend?
   - Any unusual spikes? (investigate cause)
   - Average usage over week: acceptable?

2. **Memory Usage:**
   - Growing over time? (memory leak?)
   - Swap usage increasing? (need more RAM?)
   - Top memory consumers changed?

3. **Disk Usage:**
   - Growth rate normal?
   - Will disk fill in next 30 days?
   - What's consuming most space?

**Action Items:**

```bash
# Check disk growth trend
du -sh /srv/data/observability/prometheus

# Identify large files
sudo du -ah /srv/data | sort -rh | head -20

# Review memory consumption
docker stats --no-stream | sort -k 4 -rh
```

---

### 2. Security Posture (10 minutes)

**Dashboard:** Security Monitoring

**Questions to Answer:**

1. **Attack Patterns:**
   - Frequency of SSH attacks increasing?
   - Same IPs or different?
   - Fail2ban keeping up?

2. **Authentication Events:**
   - Any successful logins from unexpected IPs?
   - sudo usage patterns normal?
   - Any new users created?

3. **File Integrity:**
   - Any modifications to critical files?
   - Were they authorized?
   - Configuration drift from baseline?

**Action Items:**

```bash
# Review SSH attack sources
docker compose logs promtail | grep "Failed password" | \
  awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | head -10

# Check for new users
cat /etc/passwd | wc -l  # Compare to last week

# Review sudo activity
docker compose logs promtail | grep "sudo:" | tail -20
```

---

### 3. Service Reliability (5 minutes)

**Dashboard:** Systemd Services, Docker Security & Stability

**Questions to Answer:**

1. **Service Failures:**
   - Any services failed during week?
   - Root cause identified?
   - Preventable in future?

2. **Container Health:**
   - Any containers restarted?
   - OOM kills?
   - Crash loops?

3. **Scheduled Jobs:**
   - All cron jobs completed successfully?
   - Any failures need investigation?

**Action Items:**

```bash
# Check service failures
systemctl --failed

# Review Docker events
docker events --since 168h --until 0h | grep -E "restart|die|kill"

# Check cron job status
grep CRON /var/log/syslog | grep -i error
```

---

### 4. Alert Review (5 minutes)

**Dashboard:** Alertmanager

**Questions to Answer:**

1. **Alert Volume:**
   - How many alerts fired this week?
   - Increasing or decreasing?
   - Any alert fatigue?

2. **Alert Quality:**
   - Were alerts actionable?
   - Any false positives?
   - Any alerts missed (should have fired)?

3. **Response Time:**
   - How long to acknowledge/resolve?
   - Could automation help?

**Action Items:**

```bash
# Count alerts this week
curl -s http://localhost:9093/api/v1/alerts | \
  jq '[.data[].startsAt] | length'

# Most frequent alerts
curl -s http://localhost:9090/api/v1/rules | \
  jq '.data.groups[].rules[] | select(.state=="firing") | .name' | \
  sort | uniq -c | sort -rn
```

**Tuning:**
- False positive → Adjust threshold or duration
- Noisy alert → Consider removing or changing to info
- Missing alert → Create new rule

---

## Monthly Assessment

### First Sunday of Month (1 hour)

**Goal:** Long-term planning, optimization, security audit

---

### 1. Capacity Planning (20 minutes)

**Review 30-day trends:**

```bash
# Prometheus disk usage growth
LAST_MONTH=$(du -sb /srv/data/observability/prometheus | awk '{print $1}')
# Compare to saved value from last month

# Calculate daily growth rate
DAILY_GROWTH=$((($LAST_MONTH - $SAVED_SIZE) / 30))

# Project next 3 months
echo "Projected disk usage in 90 days: $(($LAST_MONTH + ($DAILY_GROWTH * 90))) bytes"
```

**Questions:**

1. **Storage:**
   - Prometheus TSDB growth sustainable?
   - Loki log volume manageable?
   - Need to adjust retention?

2. **Compute:**
   - CPU/Memory trends concerning?
   - Need to scale up resources?
   - Can optimize any services?

3. **Network:**
   - Bandwidth usage increasing?
   - Scrape interval appropriate?

**Action Items:**
- Adjust retention if disk growing too fast
- Increase resource limits if consistently near max
- Optimize queries if Prometheus slow

---

### 2. Security Audit (20 minutes)

**Comprehensive security review:**

1. **User Accounts:**
   ```bash
   # Review user accounts
   cat /etc/passwd | awk -F: '$3 >= 1000 {print $1}'
   
   # Check sudo group members
   getent group sudo
   
   # Review SSH authorized keys
   for user in $(ls /home); do
     echo "=== $user ==="
     cat /home/$user/.ssh/authorized_keys 2>/dev/null
   done
   ```

2. **File Permissions:**
   ```bash
   # Check SUID binaries (compare to baseline)
   find / -perm -4000 -type f 2>/dev/null > /tmp/suid-current.txt
   diff /tmp/suid-baseline.txt /tmp/suid-current.txt
   
   # Check /etc permissions
   ls -la /etc/passwd /etc/shadow /etc/sudoers
   ```

3. **Attack Summary:**
   ```bash
   # SSH attack statistics (last 30 days)
   echo "Total failed SSH attempts:"
   journalctl -u sshd --since "30 days ago" | grep "Failed password" | wc -l
   
   echo "Unique attacker IPs:"
   journalctl -u sshd --since "30 days ago" | grep "Failed password" | \
     awk '{print $(NF-3)}' | sort -u | wc -l
   
   # Fail2ban summary
   sudo fail2ban-client status sshd
   ```

4. **Configuration Review:**
   ```bash
   # SSH config hardening check
   sshd -T | grep -E "permitrootlogin|passwordauthentication|pubkeyauthentication"
   
   # Firewall rules
   sudo ufw status numbered
   ```

**Action Items:**
- Remove unused user accounts
- Revoke old SSH keys
- Update attack mitigation strategies
- Patch security vulnerabilities

---

### 3. Alert Rules Review (10 minutes)

**Evaluate alert effectiveness:**

```bash
# Export alert firing history (last 30 days)
# Manual review in Grafana or via Prometheus API

# Count alerts by severity
curl -s http://localhost:9090/api/v1/rules | \
  jq '.data.groups[].rules[] | .labels.severity' | \
  sort | uniq -c
```

**Questions:**

1. **Coverage:**
   - Any blind spots? (services not monitored)
   - Missing alerts that would have helped?

2. **Noise:**
   - Any alerts firing too frequently?
   - False positives to eliminate?

3. **Thresholds:**
   - Any thresholds need adjustment?
   - Severity levels appropriate?

**Action Items:**
- Create new alerts for coverage gaps
- Remove or adjust noisy alerts
- Update thresholds based on observed baselines

---

### 4. Documentation Update (10 minutes)

**Keep operations log current:**

```bash
# Update /srv/docker/observability/OPERATIONS_LOG.md

## 2026-02-01 Monthly Review
- Disk usage: 3.2GB (up from 2.8GB)
- Adjusted Prometheus retention to 12 days
- Added alert for Docker daemon restarts
- Blocked 3 persistent attacker IPs in firewall
- Upgraded Grafana 10.2.0 → 10.2.3

## Incidents This Month
- 2026-02-15: Prometheus OOM (increased memory limit)
- 2026-02-22: SSH brute force (12,000 attempts, fail2ban blocked)

## Action Items for Next Month
- [ ] Implement log rotation for application logs
- [ ] Test backup restore procedure
- [ ] Evaluate Loki retention (currently 7 days)
```

---

## Understanding Normal vs Abnormal

### System Metrics Baselines

**Establish baselines for your environment:**

| Metric | Normal Range | Investigate If | Critical If |
|--------|--------------|----------------|-------------|
| CPU Usage | 10-50% | >70% sustained | >95% sustained |
| Memory Usage | 30-70% | >80% sustained | >95% sustained |
| Disk Usage | 40-75% | >80% | >90% |
| System Load (2 CPU) | 0.5-1.5 | >2.0 sustained | >4.0 sustained |
| Network (100Mbps) | 1-20Mbps | >50Mbps unexplained | >80Mbps sustained |
| Disk I/O | 10-50 IOPS | >200 IOPS sustained | Constant maxed |

**Your baselines will vary!** Document your normal values:

```bash
# Create baseline document
cat > /srv/docker/observability/BASELINES.md <<EOF
# Observability Stack Baselines

## System Resources (Typical)
- CPU: 25% average, 60% peak during scrapes
- Memory: 2.2GB used / 4GB total
- Disk: 40% full, growing 50MB/day
- Network: 5Mbps average, 15Mbps peak

## Services (Normal Behavior)
- Prometheus: Scrapes every 30s, CPU spike for 2-3s
- Grafana: Idle except during dashboard loads
- Loki: Log ingestion ~100 lines/min

## Security Events (Typical)
- SSH failures: 5-15/day (bots scanning)
- Fail2ban bans: 0-2/day
- Sudo commands: 10-20/day (legitimate admin)

Last Updated: 2026-02-08
EOF
```

---

### Security Event Patterns

**Normal:**
- 5-15 SSH failed logins per day (random scanners)
- 0-2 fail2ban bans per day (repeat offenders)
- 10-20 sudo commands per day (your typical usage)
- 1-2 crontab views per day (viewing, not modifying)

**Abnormal (Investigate):**
- 50+ SSH failures in 1 hour
- 10+ fail2ban bans in 1 hour (coordinated attack)
- 50+ sudo commands in 1 hour (unusual activity)
- Crontab modifications (unless you made them)

**Critical (Immediate Action):**
- 100+ SSH failures in 5 minutes (brute force)
- Successful SSH login from unknown IP
- Root login attempt
- SUID binary modification
- /etc/passwd or /etc/shadow modification
- New user created (unless you did it)

---

## Self-Monitoring

### The Observability Stack Monitors Itself

**Key Self-Monitoring Alerts:**

1. **Dead Man's Switch**
   - Ensures alerting is working
   - Should always be firing
   - If stops firing = alerting broken

2. **Prometheus Disk Capacity**
   - Monitors TSDB disk usage
   - Alerts before Prometheus stops writing

3. **Scrape Failures**
   - Monitors targets going down
   - Alerts if node-exporter stops

4. **Alert Evaluation Errors**
   - Monitors alert rule errors
   - Alerts if rules broken

---

### Dead Man's Switch

**What it is:** An alert that always fires. If you stop receiving it, alerting is broken.

**Implementation:**

```yaml
# In prometheus/alerts.yml
- alert: DeadMansSwitch
  expr: vector(1)  # Always returns 1 (true)
  for: 0m
  labels:
    severity: info
  annotations:
    summary: "Alerting is functional"
    description: "This alert always fires. If you stop receiving it, check alerting pipeline."
```

**Configure Alertmanager:**

```yaml
# Send to separate channel (daily digest)
routes:
  - match:
      alertname: DeadMansSwitch
    receiver: 'deadmansswitch-receiver'
    repeat_interval: 24h  # Daily confirmation
```

**External Monitoring:**

For true dead man's switch, use external service:
- [Dead Man's Snitch](https://deadmanssnitch.com/)
- [Healthchecks.io](https://healthchecks.io/)
- [Cronitor](https://cronitor.io/)

**Setup:**

```bash
# Webhook to external service (example: Healthchecks.io)
curl -m 10 --retry 5 https://hc-ping.com/your-uuid-here

# Add to Alertmanager config
receivers:
  - name: 'deadmansswitch-receiver'
    webhook_configs:
      - url: 'https://hc-ping.com/your-uuid-here'
```

---

### Observability Health Dashboard

**Create dashboard to monitor the monitors:**

**Panels:**
1. Prometheus up/down
2. Prometheus TSDB disk usage
3. Grafana up/down
4. Loki up/down
5. Alertmanager up/down
6. Scrape target health (all targets)
7. Alert evaluation errors
8. Query duration (slow queries?)

---

## Performance Baselines

### Establishing Baselines

**Week 1: Observe and Document**

```bash
# Collect baseline data
echo "=== Baseline Collection: $(date) ===" >> /tmp/baseline.txt

# CPU usage (average over 5 minutes)
echo "CPU: $(mpstat 300 1 | tail -1 | awk '{print 100-$NF}')%" >> /tmp/baseline.txt

# Memory usage
free -h | grep Mem >> /tmp/baseline.txt

# Disk usage
df -h / >> /tmp/baseline.txt

# Network (requires iftop or similar)
# Manual observation

# Prometheus stats
curl -s http://localhost:9090/api/v1/status/tsdb-status | \
  jq '.data.seriesCountByMetricName | length' >> /tmp/baseline.txt
```

**Week 2-4: Confirm Patterns**

- Same time each day (e.g., 10 AM)
- Identify daily patterns (cron jobs, backups)
- Identify weekly patterns (weekend vs. weekday)
- Document exceptional events (updates, reboots)

**Result: Baseline Document**

```markdown
# Performance Baselines

## Daily Patterns
- 2-3 AM: Backup jobs (CPU spike to 60%, disk I/O high)
- 6 AM: Maintenance scripts (moderate CPU)
- 12 PM: Typical usage (CPU 20-30%)
- 11 PM: Log rotation (brief CPU spike)

## Weekly Patterns
- Sunday 2 AM: Full backup (disk I/O sustained 30 min)
- Wednesday: Docker image updates (network spike)

## Baseline Values (10 AM weekday)
- CPU: 25% ±5%
- Memory: 2.2GB / 4GB
- Disk: Growing 50MB/day
- Network: 5Mbps ±2Mbps
- Prometheus series: 1,200 ±100
```

---

## Alert Fatigue Prevention

### Symptoms of Alert Fatigue

- ❌ Ignoring alerts without investigating
- ❌ Creating silences without fixing root cause
- ❌ "Alert fatigue" mentioned in team discussions
- ❌ Alerts treated as noise, not signals
- ❌ Important alerts missed among noise

---

### Prevention Strategies

**1. Actionable Alerts Only**

Every alert must have clear action:

```
❌ BAD:  "High network traffic" (So what? What should I do?)
✅ GOOD: "Network approaching bandwidth limit" (Action: Investigate traffic source, consider upgrade)
```

**2. Appropriate Severity**

Don't cry wolf with critical alerts:

```
Critical: System down, security breach, imminent failure
Warning: Sustained high usage, trend concern
Info:    Interesting event, no action needed
```

**3. Threshold Tuning**

Adjust thresholds to your baseline:

```yaml
# Before (too sensitive)
- alert: HighCPU
  expr: cpu_usage > 50

# After (tuned to baseline)
- alert: HighCPU
  expr: cpu_usage > 80
  for: 5m  # Sustained, not spike
```

**4. Alert Grouping**

Group related alerts to avoid notification storm:

```yaml
# Alertmanager config
route:
  group_by: ['alertname', 'instance']
  group_wait: 30s        # Wait to batch
  group_interval: 5m     # Group updates
```

**5. Regular Review**

Monthly review:
- Which alerts fired most?
- Were they actionable?
- Any false positives?
- Any threshold adjustments needed?

---

### Current Alert Reduction Success

**Before (Original Deployment):**
- 122 alert rules
- ~30 alerts/week
- Many false positives
- Alert fatigue setting in

**After (2026-02-08 Reduction):**
- 97 alert rules (20.5% reduction)
- ~10 actionable alerts/week
- Minimal false positives
- Sustainable long-term

**Method:**
- Eliminated info-level noise (moved to dashboards)
- Removed duplicate alerts
- Archived (not deleted) reduced rules
- Documented rationale for each change

---

## Monitoring Checklists

### Daily Checklist (5 min)

```
[ ] Open Grafana
[ ] Check "Homelab System Overview" - all green?
[ ] Check "Security Monitoring" - any attacks?
[ ] Check Alertmanager - any active alerts?
[ ] Run: docker compose ps - all healthy?
```

---

### Weekly Checklist (30 min)

```
[ ] Review resource trends (CPU, memory, disk)
[ ] Review security events (SSH, fail2ban, sudo)
[ ] Check service reliability (failures, restarts)
[ ] Review alerts (volume, quality, response time)
[ ] Check disk space: du -sh /srv/data/observability
[ ] Verify backups completed successfully
```

---

### Monthly Checklist (1 hour)

```
[ ] Capacity planning review (30-day trends)
[ ] Security audit (users, permissions, attacks)
[ ] Alert rules review (coverage, noise, thresholds)
[ ] Documentation update (operations log)
[ ] Test backup restore procedure
[ ] Check for component updates
[ ] Review and update baselines
```

---

### Incident Response Checklist

```
When alert fires:

[ ] Acknowledge alert (note start time)
[ ] Check Grafana for context
    [ ] When did issue start?
    [ ] Any correlated events?
    [ ] Resource exhaustion?
[ ] Check service logs
    [ ] docker compose logs <service>
    [ ] journalctl -u observability
[ ] Identify root cause
[ ] Apply fix
[ ] Verify resolution (alert clears)
[ ] Document incident (operations log)
[ ] Post-mortem: Could we prevent this?
```

---

## Quick Reference

### Normal vs. Abnormal

| Metric | Normal | Investigate | Critical |
|--------|--------|-------------|----------|
| SSH failures/day | 5-15 | 20-50 | >100 |
| Fail2ban bans/day | 0-2 | 3-10 | >10 |
| CPU usage | 10-50% | 70-80% | >95% |
| Memory usage | 30-70% | 80-90% | >95% |
| Disk usage | 40-75% | 80-90% | >90% |
| Alert volume/week | 5-15 | 20-30 | >50 |

### Monitoring Cadence

- **Daily:** 5 min health check
- **Weekly:** 30 min trend review
- **Monthly:** 1 hour comprehensive audit
- **Quarterly:** Baseline recalibration

---

## Next Steps

- **[OPERATIONS.md](./OPERATIONS.md)** - Detailed operational procedures
- **[ALERTS.md](./ALERTS.md)** - Alert management and tuning
- **[DASHBOARDS.md](./DASHBOARDS.md)** - Dashboard usage guide

---

**Monitor intelligently! Focus on signals, not noise.** 📊

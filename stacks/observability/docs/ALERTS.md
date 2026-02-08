# Alert Rules Guide

**Comprehensive guide to the 97 alert rules in the Homelab Observability Stack**

---

## Table of Contents

- [Alert Philosophy](#alert-philosophy)
- [Alert Severity Levels](#alert-severity-levels)
- [Alert Reduction Rationale](#alert-reduction-rationale)
- [Alert Rules by Category](#alert-rules-by-category)
- [Creating Custom Alerts](#creating-custom-alerts)
- [Restoring Archived Alerts](#restoring-archived-alerts)
- [Alert Runbook Template](#alert-runbook-template)
- [Silence Management](#silence-management)
- [Testing and Validation](#testing-and-validation)

---

## Alert Philosophy

### Design Principles

This alert collection embodies the following principles, refined over months of homelab operation:

**1. Actionable Over Informative**

Every alert must have a clear action. Removed alerts that were "nice to know" but provided no actionable response.

```
❌ BAD: "SSH connections increased" (So what? Is this a problem?)
✅ GOOD: "Possible SSH brute force attack" (Action: Check logs, block IP)
```

**2. Context Over Volume**

Reduced from 122 to 97 rules (20.5% reduction) by eliminating:
- Duplicate alerts (same signal, different thresholds)
- Info-level noise (moved to dashboards)
- Broken detection logic (requiring features we don't have)
- Homelab-inappropriate rules (enterprise-only concerns)

**3. Severity Reflects Urgency**

```
CRITICAL: Wake me up at 3 AM (service down, security breach)
WARNING: Tell me tomorrow morning (high usage, trends)
INFO: Show on dashboard (interesting but not concerning)
```

**4. Alert Fatigue Prevention**

Used `for:` duration thoughtfully:
- Security alerts: `for: 0m` (immediate)
- Resource alerts: `for: 5m` (sustained issue)
- Trend alerts: `for: 30m` (confirmed pattern)

**5. Self-Monitoring**

The observability stack monitors itself:
- Dead Man's Switch (ensure alerting is working)
- Prometheus disk capacity
- Alert rule evaluation failures
- Scrape failures

---

## Alert Severity Levels

### Critical (16 rules)

**When to fire:** Immediate attention required, potential service outage or security breach

**Notification:** Instant notification, resend every 1 hour if unresolved

**Examples:**
- Host is down
- Service crashed and won't restart
- Active security attack (SSH brute force, fail2ban storm)
- Out of memory (OOM killer active)
- Disk will fill in 4 hours
- Root crontab modified
- New SUID binary detected

**Response Time:** Within minutes

---

### Warning (74 rules)

**When to fire:** Issue detected that needs attention but isn't immediately critical

**Notification:** Batched with other warnings, resend every 4 hours if unresolved

**Examples:**
- High CPU/memory usage (sustained)
- Disk space above 80%
- Container restarting frequently
- SSH failures increasing
- Failed scheduled jobs
- Unusual sudo activity

**Response Time:** Within a few hours to a day

---

### Info (7 rules)

**When to fire:** Interesting events worth tracking, not concerning

**Notification:** Dashboard only (no alerts sent)

**Examples:**
- New user created
- Service restarted normally
- Configuration change detected
- Backup completed successfully

**Response Time:** Review periodically

---

## Alert Reduction Rationale

### Why 97 Rules, Not 122?

**The Problem:** Original deployment created alert fatigue
- Multiple alerts for the same underlying issue
- Info-level events generating notifications
- Detection logic requiring features not in use
- Thresholds inappropriate for homelab scale

**The Solution:** Systematic reduction through analysis
- Tested each alert: Does it provide unique value?
- Archived (not deleted) reduced rules with restoration path
- Documented rationale in `prometheus/archived/REDUCTION_SUMMARY.md`

---

### What Was Removed

#### Fail2ban: 14 → 4 rules (71% reduction)

**Removed:**
- `PersistentAttacker`, `ChronicAttacker` - Info noise, not actionable
- `CriticalJailDown`, `ActiveJailOverload` - Edge cases never seen
- `RestartingFrequently` - Duplicate of systemd service monitoring
- `ShortBanDuration`, `MultipleJailsActive` - Configuration issues, not alerts
- `TorExitNodeAttack` - Requires GeoIP database (not installed)
- `AndSSHCoordinatedAttack` - Redundant with BanStorm
- `ManyActiveBans` - Rarely matters in homelab

**Kept:**
- `Fail2banServiceDown` - Critical: protection is offline
- `Fail2banHighBanRate` - Warning: Active attack in progress
- `Fail2banBanStorm` - Critical: Massive attack (>10 bans/5min)
- `Fail2banNoBansHighFailures` - Warning: Misconfiguration detected

---

#### CRON: 10 → 5 rules (50% reduction)

**Removed:**
- `CronNewUserActivity` - Too noisy (legitimate automation)
- `CronOffHoursActivity` - Homelab runs automation 24/7
- `CronRootJobModified` - Duplicate of `RootCrontabModified`
- `CronUnusualFrequency`, `CronJobsCountAnomaly` - Need baseline (future feature)

**Kept:**
- `CronServiceDown` - Critical: Automation stopped
- `CronExecutionErrors` - Warning: Jobs failing
- `RootCrontabModified` - Critical: Security concern
- `SuspiciousCronCommand` - High: Potential backdoor
- `CrontabModified` - High: Track configuration changes

---

#### Port Monitoring: 10 → 5 rules (50% reduction)

**Removed:**
- `CommonPortOpen` - Too noisy (expected in homelab)
- `PortExposedToInternet` - Network-dependent, false positives
- `PortFlapping` - Need baseline
- `RangeOfPortsOpen` - Not applicable to homelab scale

**Kept:**
- `HighEstablishedConnections` - Performance indicator
- `SynFloodPossible` - Security: DDoS attempt
- `TCPSocketExhaustion` - Critical: Service degradation
- `HighTimeWaitSockets` - Performance: Connection leak
- `UDPBufferErrors` - Performance: Packet loss

---

#### Privilege Escalation: 8 → 5 rules (38% reduction)

**Removed:**
- `SuspiciousSetuidOwner` - Needs better detection logic
- `SetuidCountAnomaly` - Requires baseline
- `WorldWritableSetuid` - OS-level prevention handles this

**Kept:**
- `NewSUIDBinary` - Critical: Privilege escalation risk
- `SUIDSGIDSet` - Critical: Permission change detected
- `SUIDBinaryTampered` - Critical: Binary modified
- `NewCapabilityAssigned` - High: Linux capabilities added
- `CapabilityModified` - High: Capability change

---

#### User Management: 6 → 4 rules (33% reduction)

**Removed:**
- `UserIDModified` - Rare operation, low value
- `UserShellChanged` - Legitimate admin action

**Kept:**
- `NewUserCreated` - High: Track account creation
- `RapidUserCreation` - Critical: Possible compromise
- `UserDeleted` - High: Track account deletion
- `SudoGroupMembershipChanged` - Critical: Privilege escalation

---

### Files Unchanged

These alert files had minimal rules and all were deemed essential:

- **alerts.yml** (25 rules) - Core system monitoring
- **docker-security-alerts.yml** (17 rules) - Container security
- **file-integrity-alerts.yml** (7 rules) - Critical file monitoring
- **process-alerts.yml** (2 rules) - Process monitoring (4 LogQL rules commented)
- **ssh-alerts.yml** (13 rules) - SSH security
- **sudo-alerts.yml** (6 rules) - Privilege tracking
- **systemd-alerts.yml** (4 rules) - Service management

---

## Alert Rules by Category

### 1. Core System Alerts (25 rules)

**File:** `prometheus/alerts.yml`

**Key Alerts:**

```yaml
# CPU Monitoring
- HostHighCpuLoad (>80% for 5m) → warning
- HostCriticalCpuLoad (>95% for 2m) → critical

# Memory Monitoring
- HostHighMemoryUsage (>80% for 5m) → warning
- HostCriticalMemoryUsage (>95% for 2m) → critical

# Disk Monitoring
- HostDiskSpaceLow (>80% for 5m) → warning
- HostDiskSpaceCritical (>90% for 2m) → critical
- HostDiskWillFillIn24Hours (predictive) → warning

# Availability
- HostDown (node-exporter down for 1m) → critical
- HostClockSkew (>0.05s offset) → warning
```

**When to Review:**
- Daily: Check for any critical alerts
- Weekly: Review warning alerts for trends
- Monthly: Assess if thresholds need adjustment

---

### 2. Docker Security (17 rules)

**File:** `prometheus/docker-security-alerts.yml`

**Container Health:**

```yaml
- ContainerRestartingFrequently (>3 restarts/hour) → warning
- ContainerRestartLoop (>5 restarts/15min) → critical
- ContainerOOMKilled (immediate) → critical
- ContainerNearOOMRisk (>90% memory for 5m) → warning
```

**Security Monitoring:**

```yaml
- UnexpectedContainerCount (>10 containers) → warning
- ContainerRunningAsRoot (security risk) → high
- PrivilegedContainerDetected (immediate) → critical
- ContainerWithoutHealthcheck (best practice) → info
```

**Example Scenario:**

```
1. ContainerNearOOMRisk fires (warning) → Container using 92% memory
2. Action: Review container logs, check for memory leak
3. If ignored: ContainerOOMKilled fires (critical) → Container killed by OOM
4. Recovery: Increase memory limit or fix leak
```

---

### 3. SSH Security (13 rules)

**File:** `prometheus/ssh-alerts.yml`

**Attack Detection:**

```yaml
- SSHBruteForceAttempt (>5 failures/5min) → warning
- SSHBruteForceSustained (>10 failures/15min) → high
- SSHBruteForceAttack (>20 failures/5min) → critical
- SSHRootLoginAttempt (immediate) → high
```

**Authentication Monitoring:**

```yaml
- SSHFailedLoginSpike (>10 failures/min) → critical
- SSHUnknownUserAttempt (immediate) → warning
- SSHMultipleUsers (>3 users/5min) → high
```

**Key Management:**

```yaml
- SSHKeyAdded (immediate) → high
- SSHKeyRemoved (immediate) → high
- SSHAuthorizedKeysModified (immediate) → critical
```

**Best Practices:**

1. Review SSH alerts daily (high attack surface)
2. Investigate all `critical` and `high` severity immediately
3. Consider blocking IPs with >50 failures (via fail2ban)
4. Use key-based auth only (disable password auth)

---

### 4. Fail2ban (4 rules)

**File:** `prometheus/fail2ban-alerts.yml`

```yaml
- Fail2banServiceDown → critical
  Description: Fail2ban protection is offline
  Action: Restart fail2ban service immediately

- Fail2banHighBanRate (>2 bans/5min) → warning
  Description: Active attack in progress
  Action: Monitor attack source, consider firewall rules

- Fail2banBanStorm (>10 bans/5min) → critical
  Description: Massive coordinated attack
  Action: Check attack pattern, notify security team

- Fail2banNoBansHighFailures (>50 failures, 0 bans) → warning
  Description: Fail2ban misconfigured or not working
  Action: Review fail2ban configuration
```

---

### 5. CRON Monitoring (5 rules)

**File:** `prometheus/cron-alerts.yml`

```yaml
- CronServiceDown → critical
  Description: Cron daemon stopped
  Action: Restart cron service, check system logs

- CronExecutionErrors (>5 errors/hour) → warning
  Description: Scheduled jobs failing
  Action: Review /var/log/syslog for CRON errors

- RootCrontabModified → critical
  Description: Root's crontab changed (security risk)
  Action: Review changes, revert if unauthorized

- SuspiciousCronCommand → high
  Description: Potentially malicious command detected
  Detects: curl|wget to external hosts, /tmp scripts
  Action: Investigate immediately, possible backdoor

- CrontabModified → high
  Description: User crontab modified
  Action: Track legitimate changes
```

---

### 6. Port & Network (5 rules)

**File:** `prometheus/port-alerts.yml`

```yaml
- HighEstablishedConnections (>1000) → warning
  Description: Unusual connection count
  Action: Check for connection leaks or DDoS

- SynFloodPossible (>500 SYN_RECV) → critical
  Description: SYN flood attack detected
  Action: Enable SYN cookies, investigate source

- TCPSocketExhaustion (>90% sockets used) → critical
  Description: Running out of available sockets
  Action: Increase limits, find socket leak

- HighTimeWaitSockets (>5000 TIME_WAIT) → warning
  Description: Connection cleanup delay
  Action: Tune TIME_WAIT settings, check for leak

- UDPBufferErrors (>10/min) → warning
  Description: UDP packet loss
  Action: Increase UDP buffer size
```

---

### 7. Systemd Services (4 rules)

**File:** `prometheus/systemd-alerts.yml`

```yaml
- SystemdServiceFailed → critical
  Description: Critical service failed to start
  Action: Check journalctl for service failure reason

- SystemdServiceFlapping (>3 restarts/hour) → warning
  Description: Service restarting frequently
  Action: Review service logs for crash cause

- SystemdUnitMaskChanged → high
  Description: Service masked/unmasked (security)
  Action: Verify authorized change

- SystemdFailedUnits → warning
  Description: One or more units in failed state
  Action: Review systemctl --failed
```

---

### 8. Sudo Monitoring (6 rules)

**File:** `prometheus/sudo-alerts.yml`

```yaml
- SudoCommandExecuted → info
  Description: Privileged command executed
  Action: Track for audit trail

- SudoAuthenticationFailure → high
  Description: Failed sudo authentication
  Action: Investigate unauthorized access attempt

- SudoMultipleFailures (>3/5min) → critical
  Description: Repeated sudo failures
  Action: Possible privilege escalation attempt

- SudoersFileModified → critical
  Description: Sudo configuration changed
  Action: Review changes immediately

- SudoRootShell → high
  Description: User spawned root shell
  Action: Track who and why (audit)

- SudoByUnauthorizedUser → critical
  Description: Non-sudoer attempted sudo
  Action: Security event, investigate immediately
```

---

### 9. File Integrity (7 rules)

**File:** `prometheus/file-integrity-alerts.yml`

```yaml
- CriticalFileModified → critical
  Files: /etc/passwd, /etc/shadow, /etc/sudoers
  Action: Investigate unauthorized modification

- SSHConfigModified → high
  Files: /etc/ssh/sshd_config, ~/.ssh/*
  Action: Review SSH configuration changes

- SystemBinaryModified → critical
  Files: /bin/*, /sbin/*, /usr/bin/*
  Action: Possible rootkit, verify integrity

- CronFileModified → high
  Files: /etc/cron.*, /var/spool/cron/*
  Action: Verify authorized changes

- SystemdUnitFileModified → high
  Files: /etc/systemd/system/*
  Action: Track service configuration changes

- HostsFileModified → warning
  Files: /etc/hosts
  Action: Check for unauthorized entries

- PasswdModifiedOutsideUseradd → high
  Description: Direct /etc/passwd edit (unusual)
  Action: Verify authorized user management
```

---

### 10. Privilege Escalation (5 rules)

**File:** `prometheus/privilege-escalation-alerts.yml`

```yaml
- NewSUIDBinary → critical
  Description: New SUID binary detected
  Action: Verify legitimate installation

- SUIDSGIDSet → critical
  Description: SUID/SGID bit set on file
  Action: Check if authorized

- SUIDBinaryTampered → critical
  Description: Existing SUID binary modified
  Action: Possible privilege escalation, investigate

- NewCapabilityAssigned → high
  Description: Linux capability added to binary
  Action: Review capability assignment

- CapabilityModified → high
  Description: Existing capability changed
  Action: Verify authorized modification
```

---

### 11. User Management (4 rules)

**File:** `prometheus/user-management-alerts.yml`

```yaml
- NewUserCreated → high
  Description: User account created
  Action: Track account creation for audit

- RapidUserCreation (>3 users/5min) → critical
  Description: Multiple accounts created quickly
  Action: Possible system compromise

- UserDeleted → high
  Description: User account removed
  Action: Track account deletion for audit

- SudoGroupMembershipChanged → critical
  Description: User added/removed from sudo group
  Action: Verify authorized privilege change
```

---

### 12. Process Monitoring (2 rules)

**File:** `prometheus/process-alerts.yml`

```yaml
- SuspiciousProcessName → high
  Detects: nc, ncat, socat (reverse shell tools)
  Action: Investigate immediately

- ProcessRunningFromTmp → high
  Description: Binary executing from /tmp
  Action: Possible malware, investigate
```

**Note:** 4 additional LogQL-based rules commented out (require Grafana alerting):
- SuspiciousShellAccess
- ReverseShellDetected  
- ProcessCreatedByWebServer
- HighPrivilegeProcessSpawned

---

## Creating Custom Alerts

### Alert Template

```yaml
groups:
  - name: custom-alerts
    interval: 30s  # How often to evaluate
    rules:
      - alert: MyCustomAlert
        expr: |
          # PromQL expression that returns true when alert should fire
          my_metric > threshold
        for: 5m  # Alert must be true for this duration
        labels:
          severity: warning  # critical, warning, or info
          category: custom   # For organizing alerts
        annotations:
          summary: "Brief description"
          description: "Detailed description with {{ $value }} value"
          runbook_url: "https://wiki.internal/runbooks/my-alert"
```

---

### Example: Alert on High Swap Usage

**Problem:** Want to know when system is swapping excessively

**Solution:**

```yaml
# Add to prometheus/alerts.yml under 'host' group
- alert: HighSwapUsage
  expr: |
    (
      (node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes) 
      / node_memory_SwapTotal_bytes * 100
    ) > 50
  for: 10m
  labels:
    severity: warning
    category: system
  annotations:
    summary: "High swap usage on {{ $labels.instance }}"
    description: |
      Swap usage is {{ $value | printf "%.1f" }}% (over 50%).
      This indicates memory pressure. Consider:
      - Adding more RAM
      - Reducing container memory usage
      - Investigating memory leaks
    runbook_url: "https://wiki.internal/runbooks/high-swap"
```

**Deploy:**

```bash
# Validate
docker exec prometheus promtool check rules /etc/prometheus/alerts.yml

# Reload
curl -X POST http://localhost:9090/-/reload

# Verify loaded
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[] | select(.name=="HighSwapUsage")'
```

---

### Example: Alert on Service-Specific Metric

**Problem:** Monitor custom application metrics

**Solution:**

1. **Expose metrics from your application:**

```python
# Python example using prometheus_client
from prometheus_client import Counter, start_http_server

request_errors = Counter('myapp_request_errors_total', 'Total request errors')

# Increment when error occurs
request_errors.inc()

# Start metrics server
start_http_server(8000)
```

2. **Add scrape config to `prometheus/prometheus.yml`:**

```yaml
scrape_configs:
  - job_name: 'myapp'
    static_configs:
      - targets: ['myapp:8000']
```

3. **Create alert rule:**

```yaml
# prometheus/alerts.yml or custom file
- alert: MyAppHighErrorRate
  expr: |
    rate(myapp_request_errors_total[5m]) > 0.1
  for: 5m
  labels:
    severity: warning
    category: application
  annotations:
    summary: "High error rate in myapp"
    description: "Error rate is {{ $value | printf \"%.2f\" }} errors/sec"
```

---

### PromQL Tips for Alerts

**Common Patterns:**

```yaml
# Rate over time (for counters)
rate(metric_total[5m]) > threshold

# Percentage calculation
(used / total * 100) > percentage_threshold

# Increase over time window
increase(metric_total[1h]) > count_threshold

# Predictive alert (will happen in X hours)
predict_linear(metric[6h], 3600 * hours) < threshold

# Aggregation
sum(rate(metric[5m])) by (label) > threshold

# Boolean logic
(metric1 > threshold1) and (metric2 < threshold2)
```

---

## Restoring Archived Alerts

### View Available Archives

```bash
ls prometheus/archived/

# Output:
# README.md
# REDUCTION_SUMMARY.md
# cron-alerts.yml.full
# fail2ban-alerts.yml.full
# port-alerts.yml.full
# privilege-escalation-alerts.yml.full
# user-management-alerts.yml.full
```

---

### Full Restoration

**Restore all alerts from archived file:**

```bash
# Backup current file
cp prometheus/fail2ban-alerts.yml prometheus/fail2ban-alerts.yml.backup

# Restore full archived version
cp prometheus/archived/fail2ban-alerts.yml.full prometheus/fail2ban-alerts.yml

# Validate
docker exec prometheus promtool check rules /etc/prometheus/fail2ban-alerts.yml

# Reload
curl -X POST http://localhost:9090/-/reload
```

**Result:** fail2ban-alerts goes from 4 rules → 14 rules

---

### Selective Restoration

**Restore only specific rules from archive:**

1. Open archived file: `prometheus/archived/fail2ban-alerts.yml.full`

2. Copy desired rule(s), e.g., `PersistentAttacker`:

```yaml
- alert: PersistentAttacker
  expr: |
    sum(rate(fail2ban_banned_ips_total[1h])) by (jail, ip) > 3
  for: 0m
  labels:
    severity: info
    category: security
  annotations:
    summary: "IP banned multiple times in jail {{ $labels.jail }}"
```

3. Paste into active file: `prometheus/fail2ban-alerts.yml`

4. Validate and reload

---

### Why Would You Restore?

**Scenarios:**

1. **Your environment differs:** Archive removed rules assuming typical homelab, but you have specific needs

2. **Debugging:** Need more verbose alerting temporarily to diagnose issue

3. **Security posture change:** Moving from homelab → production, need stricter monitoring

4. **Learning:** Want to understand what alerts detect

---

## Alert Runbook Template

Every alert should have a runbook. Here's a template:

```markdown
# Alert: AlertName

## Severity: Critical/Warning/Info

## Description
What does this alert detect? What is the underlying problem?

## Impact
What happens if this isn't addressed?
- User-facing impact
- System impact
- Security implications

## Diagnosis
How to investigate:

1. Check Prometheus metrics:
   ```
   # PromQL queries to run
   metric_name{label="value"}
   ```

2. Check logs:
   ```bash
   docker compose logs service_name
   journalctl -u service_name
   ```

3. Check system state:
   ```bash
   # Diagnostic commands
   top, htop, df -h, etc.
   ```

## Resolution

### Quick Fix (Stop the bleeding)
```bash
# Immediate actions to stop alert
```

### Root Cause Fix
```bash
# Permanent solution
```

## Prevention
How to prevent this in the future?

## Escalation
When to escalate? Who to contact?

## References
- Related runbooks
- Documentation links
- Past incidents
```

---

### Example Runbook

```markdown
# Alert: HostDiskSpaceCritical

## Severity: Critical

## Description
Root filesystem (/) is above 90% capacity and will impact system stability.

## Impact
- **95% full**: Log writes may fail
- **98% full**: Service degradation (Docker can't pull images)
- **100% full**: System becomes unresponsive

## Diagnosis

1. Check current usage:
   ```bash
   df -h /
   du -sh /srv/data/* | sort -h
   ```

2. Find large files:
   ```bash
   sudo du -ah / | sort -rh | head -20
   ```

3. Check Docker disk usage:
   ```bash
   docker system df
   ```

## Resolution

### Quick Fix
```bash
# Clean Docker resources
docker system prune -af --volumes

# Clear old logs
sudo journalctl --vacuum-time=7d
sudo truncate -s 0 /var/log/large-log-file.log
```

### Root Cause Fix
```bash
# Reduce Prometheus retention
# Edit compose.yaml:
# --storage.tsdb.retention.time=7d

# Implement log rotation
sudo nano /etc/logrotate.d/myapp

# Add monitoring disk
# Mount /srv/data to separate volume
```

## Prevention
- Set up automated disk cleanup (weekly cron)
- Monitor `HostDiskWillFillIn24Hours` for early warning
- Implement proper log rotation
- Configure retention policies on all services

## Escalation
If disk is 98%+ full and cleanup didn't help: Contact infrastructure team.

## References
- [Disk management runbook](#)
- [Prometheus retention docs](https://prometheus.io/docs/prometheus/latest/storage/)
```

---

## Silence Management

### When to Silence Alerts

**Appropriate Use:**
- ✅ Planned maintenance (server reboot, updates)
- ✅ Known issue being actively worked on
- ✅ Test environment alerts during development
- ✅ Noisy alert while tuning threshold

**Inappropriate Use:**
- ❌ "This alert is annoying" (fix the alert or threshold instead)
- ❌ Permanent silence (remove the alert rule instead)
- ❌ Security alerts during "testing" (use proper test environment)

---

### Creating Silences

**Via Alertmanager UI:**

1. Open http://localhost:9093
2. Click "Silences" → "New Silence"
3. Add matchers (e.g., `alertname="HostHighCpuLoad"`)
4. Set duration and comment
5. Create

**Via API:**

```bash
# Silence specific alert for 2 hours
curl -X POST http://localhost:9093/api/v1/silences \
  -H "Content-Type: application/json" \
  -d '{
    "matchers": [
      {"name": "alertname", "value": "HostHighCpuLoad", "isRegex": false}
    ],
    "startsAt": "'$(date -Iseconds)'",
    "endsAt": "'$(date -Iseconds -d '+2 hours)'",
    "comment": "Server maintenance - CPU usage expected to be high",
    "createdBy": "admin"
  }'
```

**Silence Multiple Alerts by Label:**

```bash
# Silence all alerts from specific instance
{
  "matchers": [
    {"name": "instance", "value": "homelab", "isRegex": false}
  ],
  "startsAt": "2026-02-08T20:00:00Z",
  "endsAt": "2026-02-08T22:00:00Z",
  "comment": "System upgrade window"
}
```

**Silence Using Regex:**

```bash
# Silence all SSH-related alerts
{
  "matchers": [
    {"name": "alertname", "value": "SSH.*", "isRegex": true}
  ],
  "endsAt": "2026-02-09T00:00:00Z",
  "comment": "Known SSH scanner, already blocked"
}
```

---

### Viewing Active Silences

```bash
# List all silences
curl -s http://localhost:9093/api/v1/silences | jq '.data[] | {id, comment, status}'

# Find specific silence
curl -s http://localhost:9093/api/v1/silences | jq '.data[] | select(.matchers[].value == "HostDown")'
```

---

### Deleting Silences

**Via UI:** Click trash icon next to silence

**Via API:**

```bash
# Get silence ID
SILENCE_ID=$(curl -s http://localhost:9093/api/v1/silences | jq -r '.data[0].id')

# Delete silence
curl -X DELETE http://localhost:9093/api/v1/silence/$SILENCE_ID
```

---

## Testing and Validation

### Validate Alert Syntax

```bash
# Check specific file
docker exec prometheus promtool check rules /etc/prometheus/alerts.yml

# Check all alert files
for file in prometheus/*-alerts.yml; do
  echo "Validating $file..."
  docker exec prometheus promtool check rules /etc/prometheus/$(basename $file) || exit 1
done
```

---

### Test Alert Firing

**Method 1: Trigger Real Condition**

```bash
# Test high CPU alert
stress-ng --cpu 4 --timeout 360s

# Watch for alert
watch -n 5 'curl -s http://localhost:9090/api/v1/alerts | jq ".data.alerts[] | select(.labels.alertname==\"HostHighCpuLoad\")"'
```

**Method 2: Temporary Threshold Change**

```yaml
# Change threshold temporarily
- alert: HostHighCpuLoad
  expr: cpu_usage > 1  # Will fire immediately
```

**Method 3: Unit Testing with promtool**

```yaml
# Create test file: alerts_test.yml
rule_files:
  - alerts.yml

evaluation_interval: 1m

tests:
  - interval: 1m
    input_series:
      - series: 'node_cpu_seconds_total{mode="idle",instance="test"}'
        values: '100+0x10'  # Constant 100 for 10 minutes
    alert_rule_test:
      - eval_time: 5m
        alertname: HostHighCpuLoad
        exp_alerts:
          - exp_labels:
              severity: warning
              instance: test
            exp_annotations:
              summary: "High CPU load on test"
```

Run test:
```bash
docker exec prometheus promtool test rules alerts_test.yml
```

---

### Monitor Alert Manager Performance

```bash
# Check alertmanager metrics
curl -s http://localhost:9093/metrics | grep alertmanager

# Key metrics:
# alertmanager_notifications_total - Total notifications sent
# alertmanager_notifications_failed_total - Failed notifications
# alertmanager_alerts_received_total - Alerts received
# alertmanager_silences - Active silences
```

---

## Best Practices

### ✅ DO

1. **Test new alerts thoroughly** before deploying to production
2. **Document every alert** with runbook or at minimum a description
3. **Use appropriate severity levels** (critical = wake me up)
4. **Set reasonable `for:` durations** to avoid flapping
5. **Group related alerts** in same file for maintainability
6. **Version control all changes** (already done via git)
7. **Review alerts weekly** to identify noise or gaps

### ❌ DON'T

1. **Don't create alerts without clear actions** ("FYI alerts")
2. **Don't set critical severity on non-critical issues**
3. **Don't create duplicate alerts** (same condition, different name)
4. **Don't ignore repeated alerts** (fix underlying issue or adjust rule)
5. **Don't silence alerts permanently** (remove rule instead)
6. **Don't skip validation** before deploying changes
7. **Don't alert on metrics you don't collect**

---

## Quick Reference

### Alert Rule Count by File

```
alerts.yml                      : 25 rules
docker-security-alerts.yml      : 17 rules
ssh-alerts.yml                  : 13 rules
file-integrity-alerts.yml       :  7 rules
sudo-alerts.yml                 :  6 rules
port-alerts.yml                 :  5 rules
cron-alerts.yml                 :  5 rules
privilege-escalation-alerts.yml :  5 rules
systemd-alerts.yml              :  4 rules
fail2ban-alerts.yml             :  4 rules
user-management-alerts.yml      :  4 rules
process-alerts.yml              :  2 rules
────────────────────────────────────────
TOTAL                           : 97 rules
```

### Alert Severity Distribution

```
Critical : 16 rules (16.5%)
Warning  : 74 rules (76.3%)
Info     :  7 rules  (7.2%)
```

---

## Next Steps

- **[CONFIGURATION.md](./CONFIGURATION.md)** - Tune alert thresholds and routing
- **[OPERATIONS.md](./OPERATIONS.md)** - Managing alerts in production
- **[MONITORING.md](./MONITORING.md)** - What alerts to watch daily

---

**Alert responsibly! Each notification should drive action.** 🚨

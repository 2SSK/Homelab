# Dashboards Guide

**Complete guide to the 6 pre-built Grafana dashboards**

---

## Table of Contents

- [Dashboard Overview](#dashboard-overview)
- [Dashboard Descriptions](#dashboard-descriptions)
- [When to Use Each Dashboard](#when-to-use-each-dashboard)
- [Customization Guide](#customization-guide)
- [Creating New Dashboards](#creating-new-dashboards)
- [Dashboard Backup and Restore](#dashboard-backup-and-restore)
- [Progressive Disclosure Patterns](#progressive-disclosure-patterns)
- [Best Practices](#best-practices)

---

## Dashboard Overview

### Quick Reference

| Dashboard | Panels | Primary Use | Refresh |
|-----------|--------|-------------|---------|
| **Homelab System Overview** | 9 | Daily health check | 30s |
| **Systemd Services** | 14 | Service monitoring | 1m |
| **Security Monitoring** | 35 | Security events | 1m |
| **CRON Monitoring** | 19 | Scheduled jobs | 5m |
| **Docker Security & Stability** | 18 | Container health | 30s |
| **Network Exposure & Socket Monitoring** | 14 | Network activity | 1m |

**Total:** 109 panels across 6 dashboards

---

### Access Dashboards

1. **Via Grafana UI:** http://localhost:3000 (through SSH tunnel)
2. **Login:** admin / `<from .env file>`
3. **Navigate:** Dashboards → Browse
4. **Search:** Use search bar to filter by name

**Keyboard Shortcuts:**
- `d` + `h` = Home dashboard
- `d` + `s` = Search dashboards
- `f` = Toggle fullscreen panel
- `?` = Show all shortcuts

---

## Dashboard Descriptions

### 1. Homelab System Overview

**Purpose:** At-a-glance system health - your daily check-in dashboard

**Location:** `grafana/provisioning/dashboards/json/homelab-system.json`

**Panels (9 total):**

1. **CPU Usage** - Current CPU utilization (gauge)
   - Green: 0-70%
   - Yellow: 70-85%
   - Red: 85-100%

2. **Memory Usage** - RAM utilization with available memory
   - Shows used vs. total
   - Includes swap usage

3. **Disk Usage** - Root filesystem capacity
   - Predictive: Will fill in X days at current rate

4. **System Load** - 1m, 5m, 15m load averages
   - Normalized by CPU count

5. **Network Traffic** - Inbound/outbound bandwidth
   - Separate transmit (TX) and receive (RX)

6. **Disk I/O** - Read/write operations per second
   - Identifies disk bottlenecks

7. **Top Processes** - Highest resource consumers
   - CPU and memory hogs

8. **Uptime** - System uptime
   - Days since last reboot

9. **Temperature** - CPU/system temperature (if sensors available)
   - Thermal throttling indicator

**When to Use:**
- **Daily:** Quick morning health check (< 1 minute)
- **After changes:** Verify system stable after updates
- **Performance issues:** First place to look for resource constraints

**Example Workflow:**

```
1. Open dashboard
2. Check gauges (CPU, Memory, Disk) - all green?
   ✅ Yes: System healthy, move on
   ⚠️ Yellow: Note for monitoring
   ❌ Red: Investigate immediately

3. Check graphs for trends
   - CPU spiking? Check Top Processes
   - Memory climbing? Check for leaks
   - Disk I/O high? Check what's writing

4. Review uptime
   - Recent reboot? Check why (updates? crash?)
```

---

### 2. Systemd Services

**Purpose:** Monitor service health and failures across your system

**Location:** `grafana/provisioning/dashboards/json/systemd-services.json`

**Panels (14 total):**

**Status Overview:**
1. **Services Summary** - Active, failed, inactive counts
2. **Failed Services** - Current failures (table)
3. **Service State Timeline** - Historical state changes

**Core Services:**
4. **Docker Service** - Docker daemon health
5. **SSH Service** - SSH daemon status
6. **Observability Stack** - Prometheus, Grafana, Loki status

**Service Metrics:**
7. **Service Restarts** - Restart count per service (last 24h)
8. **Service CPU Usage** - CPU consumed by each service
9. **Service Memory Usage** - Memory consumed by each service

**Failure Analysis:**
10. **Recent Failures** - Timeline of service failures
11. **Failure Rate** - Failures per hour
12. **Most Frequent Failures** - Which services fail most

**Actions:**
13. **Service Actions Log** - Start/stop/restart events
14. **Service Dependencies** - Service dependency graph

**When to Use:**
- **After deployment:** Verify all services started correctly
- **Alert investigation:** Why did service restart?
- **Capacity planning:** Which services consume most resources?
- **Troubleshooting:** Track service state changes over time

**Common Patterns:**

```yaml
Service failing at startup:
  1. Check "Failed Services" table
  2. View "Recent Failures" timeline - when did it start?
  3. Check dependencies - is required service down?
  4. Action: journalctl -u service-name

Service restarting frequently:
  1. Check "Service Restarts" - how many times?
  2. View "Service Actions Log" - what's triggering restarts?
  3. Check "Service CPU/Memory" - resource issue?
  4. Action: Review service logs for crash reason
```

---

### 3. Security Monitoring

**Purpose:** Comprehensive security event tracking and threat detection

**Location:** `grafana/provisioning/dashboards/json/security-monitoring.json`

**Panels (35 total - scheduled for redesign to ~22):**

**Note:** This dashboard is intentionally comprehensive, covering multiple security domains. Consider using Grafana's row collapse feature to hide sections you check less frequently.

**SSH Security (8 panels):**
1. SSH Login Attempts - Success vs. failure rate
2. SSH Failed Logins by User - Who's being targeted?
3. SSH Failed Logins by IP - Attack sources
4. SSH Brute Force Events - Timeline of attacks
5. SSH Root Login Attempts - Critical: root access attempts
6. SSH Key Changes - Authorized keys modifications
7. SSH Session Duration - Unusual long sessions
8. SSH Concurrent Sessions - Multiple sessions from one user

**Fail2ban (7 panels):**
9. Fail2ban Status - Service health
10. Ban Rate - Bans per hour
11. Active Bans - Currently banned IPs
12. Bans by Jail - Which services being attacked
13. Persistent Attackers - IPs banned repeatedly
14. Ban Duration Distribution - How long IPs stay banned
15. Fail2ban Actions Timeline - Ban/unban events

**Sudo Activity (5 panels):**
16. Sudo Commands Executed - Privilege escalation tracking
17. Sudo by User - Who's using sudo most?
18. Sudo Failures - Authentication failures
19. Sudoers Modifications - Configuration changes
20. Root Shell Spawns - sudo su activity

**File Integrity (5 panels):**
21. Critical File Modifications - /etc/passwd, shadow, sudoers
22. SSH Config Changes - sshd_config modifications
23. System Binary Changes - Potential rootkit detection
24. Crontab Modifications - Scheduled job changes
25. Systemd Unit File Changes - Service config tracking

**Process Monitoring (4 panels):**
26. Suspicious Processes - nc, ncat, socat detected
27. Processes from /tmp - Potential malware
28. Process Tree - Parent-child relationships
29. Unusual Process Startups - Processes starting at odd times

**User Management (3 panels):**
30. User Account Changes - Created/deleted users
31. Group Membership Changes - Privilege changes
32. Password Changes - Account security events

**Privilege Escalation (3 panels):**
33. SUID Binary Changes - New/modified SUID binaries
34. Linux Capability Changes - Capability assignments
35. Permission Changes on Sensitive Files - chmod on /etc/*

**Usage Recommendations:**

```
Daily (5 minutes):
  - SSH Login Attempts (check for attacks)
  - Fail2ban Status (protection working?)
  - Critical File Modifications (any unauthorized changes?)

Weekly (15 minutes):
  - SSH Failed Logins by IP (trending attack sources?)
  - Sudo Activity (normal usage patterns?)
  - User Account Changes (track account lifecycle)

Monthly (30 minutes):
  - Full dashboard review
  - Identify patterns
  - Adjust alert thresholds based on baseline
```

---

### 4. CRON Monitoring

**Purpose:** Track scheduled job execution, failures, and patterns

**Location:** `grafana/provisioning/dashboards/json/cron-monitoring.json`

**Panels (19 total):**

**Service Health (3 panels):**
1. CRON Service Status - Is cron running?
2. CRON Service Restarts - Restart count
3. CRON Daemon Logs - Recent cron log entries

**Execution Tracking (6 panels):**
4. Job Execution Rate - Jobs per hour
5. Job Success vs. Failure - Pass/fail ratio
6. Execution Duration - How long jobs take
7. Jobs by User - Who owns most jobs?
8. Jobs by Time of Day - When do jobs run?
9. Concurrent Jobs - Overlapping execution

**Failure Analysis (4 panels):**
10. Failed Jobs - Which jobs failing?
11. Failure Timeline - When do failures occur?
12. Error Messages - Common error patterns
13. Retry Attempts - Jobs retrying

**Security (3 panels):**
14. Root Crontab Modifications - Security-sensitive changes
15. Suspicious CRON Commands - Curl/wget to external hosts
16. New CRON Jobs - Tracking job additions

**Configuration (3 panels):**
17. Active CRON Jobs - Complete job list
18. Job Frequency - How often each job runs
19. Crontab Modification History - Configuration changes

**When to Use:**
- **Job failures:** Investigate why backups/maintenance failed
- **Performance issues:** Jobs running too long or overlapping
- **Security audit:** Review what's scheduled to run
- **Capacity planning:** When to schedule new jobs

**Troubleshooting Example:**

```
Scenario: Backup job failing

1. Check "Failed Jobs" panel
   → Identify: backup.sh failing since 2AM

2. Check "Failure Timeline"
   → Pattern: Fails every night at 2AM

3. Check "Execution Duration"
   → Previous job (running before backup) taking 2+ hours
   → Overlap causing failure

4. Solution: Reschedule backup to 3AM or optimize previous job
```

---

### 5. Docker Security & Stability

**Purpose:** Container health, resource usage, and security monitoring

**Location:** `grafana/provisioning/dashboards/json/docker-security-dashboard.json`

**Panels (18 total):**

**Container Health (5 panels):**
1. Container Status - Running, stopped, paused counts
2. Container Restarts - Restart count by container
3. Unhealthy Containers - Failed health checks
4. Container Uptime - How long containers been running
5. Container State Changes - Start/stop timeline

**Resource Usage (6 panels):**
6. CPU Usage by Container - Which containers consuming CPU
7. Memory Usage by Container - RAM consumption
8. Memory Limit Proximity - How close to OOM?
9. Network I/O by Container - Bandwidth usage
10. Disk I/O by Container - Read/write operations
11. Block I/O Wait - Disk bottleneck identification

**Security (4 panels):**
12. Containers Running as Root - Security risk
13. Privileged Containers - Dangerous privilege escalation
14. Containers Without Health Checks - Best practice violation
15. Container Image Versions - Outdated images

**Stability (3 panels):**
16. OOM Kill Events - Out-of-memory terminations
17. Restart Loop Detection - Containers crash-looping
18. Docker Daemon Restarts - Docker service stability

**When to Use:**
- **Container crashes:** Why did container restart?
- **Performance issues:** Which container hogging resources?
- **Security audit:** Containers running with elevated privileges?
- **Capacity planning:** Do containers need more resources?

**Quick Health Check:**

```bash
1. Unhealthy Containers - any red? Investigate immediately
2. Memory Limit Proximity - any >90%? Increase limits
3. Restart Loop Detection - any firing? Check logs
4. OOM Kill Events - any recent? Container needs more memory
```

---

### 6. Network Exposure & Socket Monitoring

**Purpose:** Network activity, connection patterns, and anomaly detection

**Location:** `grafana/provisioning/dashboards/json/network-exposure-dashboard.json`

**Panels (14 total):**

**Connection Overview (4 panels):**
1. Total Established Connections - Current connection count
2. Connection State Distribution - ESTABLISHED, TIME_WAIT, etc.
3. Connections by Port - Which ports most active
4. Connections by Remote IP - Top connection sources

**Socket Monitoring (4 panels):**
5. TCP Socket Usage - Available vs. in-use
6. TIME_WAIT Sockets - Connection cleanup tracking
7. SYN_RECV Sockets - Half-open connections (SYN flood detection)
8. UDP Socket Usage - UDP connection tracking

**Network Performance (3 panels):**
9. Network Errors - TX/RX errors
10. Network Drops - Dropped packets
11. UDP Buffer Errors - UDP packet loss

**Security (3 panels):**
12. Connection Spike Detection - Unusual connection increases
13. Port Scan Detection - Sequential port access
14. Listening Services - What ports are exposed

**When to Use:**
- **Network issues:** Slow connections, timeouts
- **Security events:** Port scans, DDoS attempts
- **Performance tuning:** Socket exhaustion, buffer sizing
- **Capacity planning:** Connection limits

**Attack Detection Example:**

```
Scenario: Possible DDoS attack

1. Check "Total Established Connections"
   → Spike from normal 50 to 500+

2. Check "Connections by Remote IP"
   → Single IP or distributed?

3. Check "SYN_RECV Sockets"
   → High count indicates SYN flood

4. Check "Connection State Distribution"
   → Unusual patterns?

5. Action:
   - Block attacking IP(s) in firewall
   - Enable SYN cookies if distributed attack
   - Review fail2ban logs
```

---

## When to Use Each Dashboard

### Decision Tree

```
What do you need to know?

├─ Is my system healthy overall?
│  └─ Use: Homelab System Overview
│
├─ Did a service fail or restart?
│  └─ Use: Systemd Services
│
├─ Am I under attack?
│  └─ Use: Security Monitoring
│
├─ Why did my backup fail?
│  └─ Use: CRON Monitoring
│
├─ Why did my container crash?
│  └─ Use: Docker Security & Stability
│
└─ Is there unusual network activity?
   └─ Use: Network Exposure & Socket Monitoring
```

---

### Daily Monitoring Routine (5-10 minutes)

**Morning Check:**

1. **Homelab System Overview** (1 min)
   - Quick glance at all gauges
   - All green? Move on

2. **Security Monitoring** (3 min)
   - SSH Login Attempts - any attacks overnight?
   - Fail2ban Status - protection active?
   - Critical File Modifications - unauthorized changes?

3. **Systemd Services** (1 min)
   - Any failed services?
   - Recent restarts?

4. **Docker Security & Stability** (1 min)
   - All containers healthy?
   - Any OOM kills?

**Total:** ~6 minutes to verify all systems operational

---

### Weekly Review (30 minutes)

**Monday Morning:**

1. **Review all dashboard alerts** (5 min)
   - What fired last week?
   - Any patterns?

2. **Capacity planning** (10 min)
   - Homelab System Overview: Resource trends
   - Docker: Container resource growth

3. **Security posture** (10 min)
   - Security Monitoring: Attack patterns
   - Failed login trends
   - New user accounts

4. **Maintenance review** (5 min)
   - CRON Monitoring: Job failures
   - Systemd Services: Restart patterns

---

### Incident Investigation

**Step-by-step troubleshooting:**

```
1. Symptom identified (alert, user report, monitoring)
   ↓
2. Homelab System Overview
   - Resource exhaustion?
   - System overloaded?
   ↓
3. Appropriate specialized dashboard
   - Service down? → Systemd Services
   - Container issue? → Docker Security & Stability
   - Network problem? → Network Exposure
   ↓
4. Correlate events across dashboards
   - Time-align all dashboards to incident window
   - Look for cascade effects
   ↓
5. Root cause identification
   - What changed?
   - What triggered the issue?
   ↓
6. Resolution and documentation
   - Apply fix
   - Document in operations log
```

---

## Customization Guide

### Editing Existing Dashboards

**Via Grafana UI:**

1. Open dashboard
2. Click gear icon (⚙️) → Settings
3. Make changes:
   - Add/remove panels
   - Adjust queries
   - Change visualizations
4. Save (💾 icon)
5. Export JSON: Share → Export → Save to file

**Update Git Repository:**

```bash
# Copy exported JSON to git repo
cp ~/Downloads/dashboard-export.json \
  /opt/Homelab/stacks/observability/grafana/provisioning/dashboards/json/

# Commit change
cd /opt/Homelab
git add stacks/observability/grafana/provisioning/dashboards/json/
git commit -m "Update dashboard: describe changes"
```

---

### Modifying Panel Queries

**Example: Change CPU Alert Threshold in Visual**

1. Edit dashboard → Click panel title → Edit
2. Find query tab
3. Current query:
   ```promql
   100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
   ```
4. Modify threshold visualization:
   - Panel tab → Thresholds
   - Change from `[70, 85]` to `[80, 90]`
5. Apply → Save dashboard

---

### Changing Panel Colors

**Example: Make Critical Levels More Obvious**

1. Edit panel → Panel tab
2. Thresholds:
   - 0-70: Green
   - 70-85: Yellow  
   - 85-100: Red
3. Change to:
   - 0-60: Green (#73BF69)
   - 60-80: Yellow (#FADE2A)
   - 80-90: Orange (#FF9830)
   - 90-100: Red (#F2495C)

---

### Adding Annotations

**Show Alert Firings on Dashboard:**

1. Dashboard Settings → Annotations
2. Add Annotation Query
3. Data source: Prometheus
4. Query:
   ```promql
   ALERTS{alertstate="firing"}
   ```
5. Enable: ✅ Show on all panels
6. Icon: 🚨

**Result:** Alert firing times marked on all graphs

---

## Creating New Dashboards

### From Scratch

**Step-by-step:**

1. **Create Dashboard:**
   - Dashboards → New Dashboard → Add visualization

2. **Configure Data Source:**
   - Select: Prometheus or Loki

3. **Write Query:**
   ```promql
   # Example: Disk usage percentage
   (1 - (node_filesystem_avail_bytes{mountpoint="/"} / 
         node_filesystem_size_bytes{mountpoint="/"})) * 100
   ```

4. **Choose Visualization:**
   - Gauge (single value)
   - Graph (time series)
   - Table (multi-row data)
   - Stat (big number)

5. **Set Panel Options:**
   - Title
   - Description
   - Units (percent, bytes, etc.)
   - Decimals
   - Thresholds

6. **Save Dashboard:**
   - 💾 → Save As → Name + folder

7. **Export and Commit:**
   ```bash
   # Export JSON via UI
   # Copy to git repo
   cp dashboard.json grafana/provisioning/dashboards/json/my-dashboard.json
   
   # Commit
   git add grafana/provisioning/dashboards/json/my-dashboard.json
   git commit -m "Add custom dashboard: My Dashboard"
   ```

---

### Dashboard Templates

**Simple System Metrics Dashboard Template:**

```json
{
  "title": "My Custom Dashboard",
  "panels": [
    {
      "title": "CPU Usage",
      "type": "graph",
      "datasource": "Prometheus",
      "targets": [{
        "expr": "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"
      }]
    },
    {
      "title": "Memory Usage",
      "type": "gauge",
      "datasource": "Prometheus",
      "targets": [{
        "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100"
      }]
    }
  ]
}
```

---

## Dashboard Backup and Restore

### Manual Backup

**Export All Dashboards:**

```bash
# Using Grafana API
GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="your-password"

# Get all dashboard UIDs
curl -s -u $GRAFANA_USER:$GRAFANA_PASS \
  $GRAFANA_URL/api/search?type=dash-db | \
  jq -r '.[].uid' > dashboard-uids.txt

# Export each dashboard
while read uid; do
  curl -s -u $GRAFANA_USER:$GRAFANA_PASS \
    $GRAFANA_URL/api/dashboards/uid/$uid | \
    jq '.dashboard' > "backup-$uid.json"
done < dashboard-uids.txt
```

---

### Automated Backup

**Add to Cron:**

```bash
# Create backup script
cat > /usr/local/bin/backup-grafana-dashboards.sh <<'EOF'
#!/bin/bash
BACKUP_DIR="/backup/grafana/dashboards"
DATE=$(date +%Y%m%d)

mkdir -p $BACKUP_DIR

# Copy provisioned dashboards (already in git)
cp -r /opt/Homelab/stacks/observability/grafana/provisioning/dashboards/json/ \
  $BACKUP_DIR/$DATE/

# Compress
tar -czf $BACKUP_DIR/dashboards-$DATE.tar.gz $BACKUP_DIR/$DATE/
rm -rf $BACKUP_DIR/$DATE/

# Keep last 30 days
find $BACKUP_DIR -name "dashboards-*.tar.gz" -mtime +30 -delete
EOF

chmod +x /usr/local/bin/backup-grafana-dashboards.sh

# Schedule weekly
echo "0 2 * * 0 root /usr/local/bin/backup-grafana-dashboards.sh" | \
  sudo tee /etc/cron.d/grafana-backup
```

---

### Restore Dashboard

**From JSON File:**

1. **Via UI:**
   - Dashboards → Import
   - Upload JSON file
   - Select datasource
   - Import

2. **Via API:**
   ```bash
   curl -X POST http://localhost:3000/api/dashboards/db \
     -u admin:password \
     -H "Content-Type: application/json" \
     -d @dashboard.json
   ```

3. **Via Provisioning:**
   ```bash
   # Copy JSON to provisioning directory
   cp dashboard.json \
     /opt/Homelab/stacks/observability/grafana/provisioning/dashboards/json/
   
   # Grafana auto-detects within 10 seconds (no restart needed)
   ```

---

## Progressive Disclosure Patterns

### Using Row Collapse

**Problem:** Security Monitoring has 35 panels - overwhelming

**Solution:** Use collapsible rows to group related panels

**Implementation:**

1. Edit dashboard
2. Add Row: Add panel → Add a new row
3. Move panels into row (drag and drop)
4. Row settings → Collapse by default: ✅
5. Repeat for each category

**Result:**

```
Security Monitoring Dashboard

▶ SSH Security (8 panels) ← Collapsed by default
▶ Fail2ban (7 panels)
▶ Sudo Activity (5 panels)
▶ File Integrity (5 panels)
▶ Process Monitoring (4 panels)
▶ User Management (3 panels)
▶ Privilege Escalation (3 panels)

User expands only sections they need to investigate
```

---

### Creating Dashboard Hierarchy

**Pattern:** Master dashboard links to specialized dashboards

**Example:**

```
Homelab Overview Dashboard (high-level)
  ├─ Link → "System Details" (detailed system metrics)
  ├─ Link → "Security Deep Dive" (security monitoring)
  ├─ Link → "Container Analysis" (Docker metrics)
  └─ Link → "Network Analysis" (network metrics)
```

**Implementation:**

1. Add text panel to master dashboard
2. Content:
   ```markdown
   ## Quick Links
   - [System Details](/d/system-details)
   - [Security Deep Dive](/d/security-monitoring)
   - [Container Analysis](/d/docker-security)
   ```

---

## Best Practices

### ✅ Dashboard Design

1. **Purpose-driven:** Each dashboard should answer specific questions
2. **Scannable:** Most important info at top
3. **Consistent:** Use same color scheme across dashboards
4. **Annotated:** Add descriptions to complex panels
5. **Time-aligned:** Use dashboard time picker for correlation

### ✅ Performance

1. **Limit queries:** Maximum 20-30 queries per dashboard
2. **Appropriate intervals:** Don't query 1s data for 30-day view
3. **Use recording rules:** Pre-compute expensive queries
4. **Cache results:** Set reasonable refresh intervals
5. **Lazy loading:** Use row collapse for rarely-used panels

### ✅ Maintenance

1. **Version control:** Commit dashboard JSON to git
2. **Document changes:** Use DASHBOARDS_CHANGELOG.md
3. **Test changes:** Verify queries before deploying
4. **Regular review:** Monthly audit for unused panels
5. **Backup strategy:** Automated backup of custom dashboards

---

## Troubleshooting

### Dashboard Shows "No Data"

**Diagnosis:**

```bash
# Check Prometheus has data
curl -s http://localhost:9090/api/v1/query?query=up | jq .

# Check datasource connection
curl http://localhost:3000/api/datasources/proxy/1/api/v1/query?query=up
```

**Common Causes:**
- Prometheus not collecting metrics (check targets)
- Wrong datasource selected in panel
- Query syntax error
- Time range outside data retention

---

### Dashboard Loads Slowly

**Diagnosis:**

1. Check query count (F12 → Network tab)
2. Identify slow queries (Query Inspector → Request stats)
3. Optimize expensive queries

**Solutions:**
- Reduce time range
- Increase scrape interval
- Use recording rules for complex queries
- Add row collapse to defer loading

---

## Next Steps

- **[MONITORING.md](./MONITORING.md)** - What to monitor daily
- **[OPERATIONS.md](./OPERATIONS.md)** - Dashboard management procedures
- **[CONFIGURATION.md](./CONFIGURATION.md)** - Grafana configuration options

---

**Visualize effectively! Dashboards should tell a story.** 📊

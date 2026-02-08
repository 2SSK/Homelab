# Contributing Guide

**How to contribute improvements to the Homelab Observability Stack**

---

## Table of Contents

- [Ways to Contribute](#ways-to-contribute)
- [Getting Started](#getting-started)
- [Adding New Alert Rules](#adding-new-alert-rules)
- [Dashboard Contribution Guidelines](#dashboard-contribution-guidelines)
- [Testing Changes](#testing-changes)
- [Documentation Standards](#documentation-standards)
- [Code Review Process](#code-review-process)
- [Community Guidelines](#community-guidelines)

---

## Ways to Contribute

### 🐛 Bug Reports

**Found a bug?** Open an issue with:
- Clear description of the problem
- Steps to reproduce
- Expected vs. actual behavior
- Environment details (OS, Docker version, etc.)
- Relevant logs or screenshots

**Example:**

```markdown
## Bug: Prometheus fails to start after adding custom alert

**Environment:**
- OS: Ubuntu 22.04
- Docker: 24.0.7
- Prometheus: v2.48.1

**Steps to Reproduce:**
1. Added custom alert to prometheus/alerts.yml
2. Ran: curl -X POST http://localhost:9090/-/reload
3. Prometheus container exited

**Expected:** Prometheus reloads with new alert
**Actual:** Prometheus crashes with "invalid rule" error

**Logs:**
```
level=error ts=2026-02-08T12:00:00.000Z caller=main.go:123 err="invalid rule: ..."
```

**Additional Context:**
Custom alert query: `my_metric{label="value"} > 100`
```

---

### ✨ Feature Requests

**Have an idea?** Open an issue with:
- Clear description of the feature
- Use case (why is this useful?)
- Proposed implementation (if you have one)
- Alternatives considered

**Example:**

```markdown
## Feature Request: Add PostgreSQL monitoring

**Use Case:**
Many homelabs run PostgreSQL databases. Would be valuable to monitor:
- Query performance
- Connection pool usage
- Replication lag (if applicable)
- Slow queries

**Proposed Implementation:**
1. Add postgres_exporter to compose.yaml
2. Create postgres-alerts.yml with common alerts
3. Add PostgreSQL dashboard

**Alternatives Considered:**
- Use Grafana Postgres datasource (doesn't provide metrics)
- External monitoring tool (adds complexity)

**Effort Estimate:** Medium (2-4 hours)
**Willing to Contribute:** Yes
```

---

### 📝 Documentation Improvements

**Improve docs:**
- Fix typos or unclear instructions
- Add examples or use cases
- Expand troubleshooting sections
- Translate documentation (future)

**PRs welcome for:**
- README clarifications
- Tutorial additions
- Runbook examples
- Architecture diagrams

---

### 🎨 Dashboard Enhancements

**Improve dashboards:**
- Better visualizations
- Additional panels
- Performance optimizations
- New dashboard types

**See:** [Dashboard Contribution Guidelines](#dashboard-contribution-guidelines)

---

### 🚨 Alert Rule Contributions

**Add or improve alerts:**
- New detection scenarios
- Better thresholds
- Improved annotations
- Runbook documentation

**See:** [Adding New Alert Rules](#adding-new-alert-rules)

---

### 🔧 Configuration Improvements

**Optimize configs:**
- Performance tuning
- Resource optimization
- Security hardening
- Best practices

---

## Getting Started

### 1. Fork and Clone

```bash
# Fork repository on GitHub (click "Fork" button)

# Clone your fork
git clone https://github.com/YOUR_USERNAME/Homelab.git
cd Homelab/stacks/observability

# Add upstream remote
git remote add upstream https://github.com/ORIGINAL_OWNER/Homelab.git
```

---

### 2. Create Feature Branch

```bash
# Update main branch
git checkout main
git pull upstream main

# Create feature branch
git checkout -b feature/add-postgres-monitoring

# Or for bug fixes
git checkout -b fix/prometheus-reload-issue
```

**Branch Naming Convention:**
- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation only
- `refactor/description` - Code refactoring
- `test/description` - Test additions

---

### 3. Make Changes

**Follow best practices:**
- One logical change per commit
- Test thoroughly before committing
- Update documentation if behavior changes
- Add comments for complex logic

---

### 4. Commit Changes

**Commit Message Format:**

```
<type>: <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting, missing semicolons, etc.
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `test`: Adding missing tests
- `chore`: Updating build tasks, configs, etc.

**Example:**

```bash
git commit -m "feat: add PostgreSQL monitoring support

- Added postgres_exporter to compose.yaml
- Created postgres-alerts.yml with 12 common alerts
- Added PostgreSQL dashboard with 15 panels
- Updated documentation with setup instructions

Closes #123"
```

---

### 5. Push and Create Pull Request

```bash
# Push branch to your fork
git push origin feature/add-postgres-monitoring

# Create PR on GitHub
# Provide clear description and link to related issues
```

**PR Template:**

```markdown
## Description
Brief description of changes

## Motivation
Why is this change needed?

## Changes Made
- Change 1
- Change 2
- Change 3

## Testing
How was this tested?
- [ ] Local testing
- [ ] Integration testing
- [ ] Documentation reviewed

## Screenshots (if applicable)
Add screenshots here

## Related Issues
Closes #123
Related to #456

## Checklist
- [ ] Code tested locally
- [ ] Documentation updated
- [ ] Commit messages follow convention
- [ ] No merge conflicts
```

---

## Adding New Alert Rules

### Process

1. **Identify Need**
   - What condition should trigger alert?
   - Why is this important?
   - What action should user take?

2. **Design Alert**
   - Write PromQL query
   - Determine appropriate severity
   - Set threshold and duration
   - Write clear annotations

3. **Choose File Location**
   - System alerts → `alerts.yml`
   - Security alerts → appropriate security file
   - New category → create new file

4. **Test Alert**
   - Validate syntax
   - Test triggering condition
   - Verify notification

5. **Document**
   - Add to ALERTS.md
   - Create runbook (if complex)

---

### Alert Template

```yaml
- alert: AlertName
  expr: |
    # PromQL expression
    metric_name{label="value"} > threshold
  for: 5m  # Duration threshold must be met
  labels:
    severity: warning  # critical, warning, or info
    category: system   # For organization
  annotations:
    summary: "Brief summary with {{ $labels.instance }}"
    description: |
      Detailed description explaining:
      - What happened: Metric X is {{ $value | printf "%.1f" }}
      - Why it matters: This indicates Y
      - What to do: Check Z
    runbook_url: "https://wiki.internal/runbooks/alert-name"
```

---

### Alert Design Guidelines

**✅ Good Alert:**

```yaml
- alert: HighMemoryUsageWithContext
  expr: (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 < 20
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Memory critically low on {{ $labels.instance }}"
    description: |
      Only {{ $value | printf "%.1f" }}% memory available.
      
      Actions:
      1. Check top memory consumers: docker stats --no-stream
      2. Review recent deployments (memory leak?)
      3. Consider increasing system memory
      4. Check for OOM kills: dmesg | grep -i "out of memory"
```

**❌ Bad Alert:**

```yaml
- alert: MemoryHigh
  expr: memory > 50
  for: 0m
  labels:
    severity: critical
  annotations:
    summary: "Memory high"
```

**Problems:**
- Vague metric name (`memory` - which metric?)
- Low threshold (50% is normal)
- No duration (will flap)
- Critical severity inappropriate (not immediate danger)
- No actionable description

---

### Testing New Alerts

**1. Syntax Validation:**

```bash
# Validate YAML syntax
docker exec prometheus promtool check rules prometheus/alerts.yml

# Should output:
# Checking prometheus/alerts.yml
#   SUCCESS: 25 rules found
```

**2. Test Query:**

```bash
# Test PromQL query in Prometheus UI
# http://localhost:9090/graph
# Enter query and verify it returns expected data

# Or via API
curl -s 'http://localhost:9090/api/v1/query?query=your_query_here' | jq .
```

**3. Trigger Alert:**

```bash
# Method 1: Create condition
# Example: Trigger high CPU alert
stress-ng --cpu 4 --timeout 600s

# Watch for alert
watch -n 5 'curl -s http://localhost:9090/api/v1/alerts | \
  jq ".data.alerts[] | select(.labels.alertname==\"YourAlertName\")"'

# Method 2: Temporarily lower threshold
# Change: expr: cpu > 90
# To:     expr: cpu > 10
# Reload Prometheus
# Change back after testing
```

**4. Verify Notification:**

```bash
# Check Alertmanager received alert
curl -s http://localhost:9093/api/v1/alerts | \
  jq '.data[] | select(.labels.alertname=="YourAlertName")'

# Check email/Slack received notification
```

---

### Alert Documentation

**Update ALERTS.md:**

```markdown
### 13. New Category (X rules)

**File:** `prometheus/new-category-alerts.yml`

```yaml
- AlertName1 (threshold) → severity
  Description: What it detects
  Action: What to do

- AlertName2 (threshold) → severity
  Description: What it detects
  Action: What to do
```

**When to Use:**
- Scenario 1
- Scenario 2

**Common Patterns:**
...
```

---

## Dashboard Contribution Guidelines

### Dashboard Design Principles

1. **Purpose-driven:** Each dashboard answers specific questions
2. **Scannable:** Most important info at top
3. **Consistent:** Follow existing color schemes and layouts
4. **Performant:** Limit queries, use appropriate intervals
5. **Documented:** Add panel descriptions for complex metrics

---

### Creating New Dashboard

**1. Design:**

```markdown
## Dashboard: Service Name Monitoring

**Purpose:** Monitor health and performance of Service X

**Panels:**
1. Service Status (gauge) - Up/Down
2. Request Rate (graph) - Requests per second
3. Error Rate (graph) - Errors per second
4. Response Time (graph) - Latency percentiles
5. Resource Usage (graph) - CPU/Memory
```

**2. Build in Grafana UI:**

- Create dashboard manually
- Test queries thoroughly
- Ensure proper data sources
- Set appropriate refresh intervals
- Add panel descriptions

**3. Export JSON:**

```bash
# Via UI: Share → Export → Save to file

# Or via API
curl -H "Authorization: Bearer $GRAFANA_API_KEY" \
  http://localhost:3000/api/dashboards/uid/$DASHBOARD_UID | \
  jq '.dashboard' > dashboard.json
```

**4. Clean JSON:**

```json
{
  "title": "Service Monitoring",
  "tags": ["service", "monitoring"],
  "timezone": "browser",
  "panels": [
    {
      "title": "Service Status",
      "type": "gauge",
      "datasource": "Prometheus",
      "targets": [{
        "expr": "up{job=\"service\"}"
      }]
    }
  ]
}
```

**Remove from exported JSON:**
- `id` field (auto-generated)
- `uid` field (auto-generated)
- `version` field (incremental)
- Any personal information

**5. Add to Repository:**

```bash
# Copy to provisioning directory
cp dashboard.json grafana/provisioning/dashboards/json/service-monitoring.json

# Test auto-provisioning
# Grafana should detect new dashboard within 10 seconds

# Commit
git add grafana/provisioning/dashboards/json/service-monitoring.json
git commit -m "feat: add Service Monitoring dashboard"
```

---

### Dashboard Review Checklist

Before submitting dashboard PR:

- [ ] Dashboard has clear purpose (documented in PR)
- [ ] All panels have titles and descriptions
- [ ] Queries are optimized (no full table scans)
- [ ] Refresh interval appropriate (30s for real-time, 1m for historical)
- [ ] Colors follow existing scheme
- [ ] Time range selector works correctly
- [ ] Dashboard loads in < 5 seconds
- [ ] Tested with empty data (no errors)
- [ ] JSON exported and cleaned
- [ ] Added to DASHBOARDS.md

---

## Testing Changes

### Local Testing

**1. Setup Test Environment:**

```bash
# Clone repository
git clone https://github.com/YOUR_USERNAME/Homelab.git
cd Homelab/stacks/observability

# Create test .env
cp .env.example .env
nano .env  # Configure

# Deploy stack
docker compose up -d

# Wait for healthy status
watch docker compose ps
```

---

**2. Test Changes:**

```bash
# Test alert rule changes
docker exec prometheus promtool check rules prometheus/alerts.yml
curl -X POST http://localhost:9090/-/reload

# Test dashboard changes
# Open Grafana, verify dashboard loads correctly

# Test configuration changes
docker compose config  # Validate compose.yaml syntax
docker compose restart <service>  # Apply changes
```

---

**3. Integration Testing:**

```bash
# Test complete workflow
./scripts/integration-test.sh

# Example test script:
#!/bin/bash
set -e

echo "Starting integration tests..."

# 1. Services start successfully
docker compose up -d
sleep 60  # Wait for startup

# 2. All services healthy
docker compose ps | grep -q "healthy" || exit 1

# 3. Prometheus loads alert rules
RULES=$(curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].rules | length' | awk '{s+=$1} END {print s}')
[ "$RULES" -eq 97 ] || { echo "Expected 97 rules, got $RULES"; exit 1; }

# 4. Grafana dashboards load
DASHBOARDS=$(curl -s http://localhost:3000/api/search?type=dash-db -u admin:$GRAFANA_ADMIN_PASSWORD | jq length)
[ "$DASHBOARDS" -eq 6 ] || { echo "Expected 6 dashboards, got $DASHBOARDS"; exit 1; }

echo "✅ All integration tests passed"
```

---

### Validation Tools

**Prometheus:**

```bash
# Check config
promtool check config prometheus/prometheus.yml

# Check rules
promtool check rules prometheus/alerts.yml

# Test query
promtool query instant http://localhost:9090 'up'

# Check TSDB
promtool tsdb analyze /path/to/prometheus/data
```

**Alertmanager:**

```bash
# Check config
amtool check-config alertmanager/alertmanager.yml

# Test routing
amtool config routes test --config.file=alertmanager/alertmanager.yml \
  --alertmanager.url=http://localhost:9093 \
  severity=critical alertname=TestAlert
```

**Docker Compose:**

```bash
# Validate syntax
docker compose config

# Validate and view resolved config
docker compose config --resolve-image-digests
```

---

## Documentation Standards

### Writing Style

**Tone:**
- Professional but approachable
- Clear and concise
- Assume intermediate Linux/Docker knowledge
- Explain Prometheus/Grafana specifics

**Format:**
- Use Markdown
- Include code examples
- Add tables for structured data
- Use callouts for warnings/notes

---

### Documentation Structure

**Each doc should have:**

```markdown
# Title

Brief description of document purpose

---

## Table of Contents
- [Section 1](#section-1)
- [Section 2](#section-2)

---

## Section 1
Content...

### Subsection
Content...

---

## Section 2
Content...

---

## Next Steps
- Link to related documents
```

---

### Code Examples

**Format code blocks:**

```bash
# Use syntax highlighting
docker compose ps

# Add comments
docker compose logs -f  # Follow logs in real-time

# Show expected output
docker compose ps
# NAME           STATUS
# prometheus     Up 2 hours (healthy)
```

**Multi-line commands:**

```bash
# Use backslash for readability
docker run --rm \
  -v $(pwd)/prometheus:/etc/prometheus \
  prom/prometheus:v2.48.1 \
  promtool check config /etc/prometheus/prometheus.yml
```

---

### Screenshots and Diagrams

**When to include:**
- Complex UI workflows
- Architecture diagrams
- Dashboard layouts
- Alert notification examples

**Format:**
- PNG for screenshots (compress)
- SVG for diagrams (preferred)
- Alt text for accessibility
- Hosted in repository (`docs/images/`)

**Example:**

```markdown
![Grafana Dashboard](./images/homelab-overview-dashboard.png)
*Figure 1: Homelab System Overview Dashboard showing healthy system*
```

---

### Linking Between Documents

**Use relative links:**

```markdown
# Good
See [ALERTS.md](./ALERTS.md) for alert configuration.

# Bad
See https://github.com/user/repo/blob/main/docs/ALERTS.md
```

**Link to specific sections:**

```markdown
See [Alert Severity Levels](./ALERTS.md#alert-severity-levels)
```

---

## Code Review Process

### Submitting PR

1. **Ensure CI passes** (if configured)
2. **Provide clear description** (use template)
3. **Link related issues** (`Closes #123`)
4. **Request review** from maintainers
5. **Be responsive** to feedback

---

### Review Criteria

**Functionality:**
- ✅ Change works as intended
- ✅ No breaking changes (or documented)
- ✅ Edge cases considered
- ✅ Error handling present

**Code Quality:**
- ✅ Follows existing patterns
- ✅ Well-commented (where needed)
- ✅ No hardcoded values
- ✅ Efficient queries/logic

**Testing:**
- ✅ Manually tested
- ✅ Validation passes
- ✅ No regressions introduced

**Documentation:**
- ✅ README updated (if needed)
- ✅ Comments explain why, not what
- ✅ Configuration examples provided
- ✅ Breaking changes documented

---

### Responding to Feedback

**Be receptive:**
- ✅ Thank reviewers for their time
- ✅ Ask questions if unclear
- ✅ Make requested changes promptly
- ✅ Explain if you disagree (respectfully)

**Example:**

```markdown
> Reviewer: Consider using a gauge instead of graph for this metric

Thanks for the suggestion! I chose a graph because we need to see trends over time 
for this metric. However, I could add a stat panel above the graph showing the 
current value. Would that address your concern?
```

---

## Community Guidelines

### Code of Conduct

**Be respectful:**
- Treat everyone with respect and kindness
- Welcome newcomers and help them learn
- Assume good intentions
- Focus on ideas, not individuals

**Be collaborative:**
- Give credit where due
- Share knowledge freely
- Help others learn and grow
- Celebrate contributions

**Be professional:**
- Keep discussions on-topic
- Avoid inflammatory language
- Respect project decisions
- Resolve conflicts constructively

---

### Getting Help

**Stuck?** Here's how to get help:

1. **Search existing issues/discussions**
   - Your question may already be answered

2. **Read documentation thoroughly**
   - docs/ directory has comprehensive guides

3. **Ask in GitHub Discussions**
   - Q&A category for questions
   - Share ideas category for proposals

4. **Open an issue (if bug)**
   - Provide detailed information
   - Include reproduction steps

**Response Time:**
- Issues: Within 48 hours (usually)
- PRs: Within 1 week (usually)
- Discussions: Community-driven

---

### Recognition

**Contributors will be:**
- Listed in CONTRIBUTORS.md (if added)
- Credited in release notes
- Thanked in commit messages
- Appreciated in discussions

**Want more involvement?**
- Consistently high-quality contributions
- Help with issue triage
- Review others' PRs
- Improve documentation
- May be invited as maintainer

---

## Quick Reference

### Contribution Checklist

```
Before submitting PR:

[ ] Feature branch created from main
[ ] Changes tested locally
[ ] Validation passes (promtool, etc.)
[ ] Documentation updated
[ ] Commit messages follow convention
[ ] No merge conflicts
[ ] PR description complete
[ ] Related issues linked
```

---

### Useful Commands

```bash
# Update fork
git fetch upstream
git rebase upstream/main

# Validate changes
docker compose config
docker exec prometheus promtool check rules prometheus/alerts.yml
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml

# Test changes
docker compose up -d
docker compose logs -f <service>

# Commit changes
git add .
git commit -m "feat: description"
git push origin feature/branch-name
```

---

## Thank You!

Thank you for contributing to the Homelab Observability Stack! Every contribution, no matter how small, helps make this project better for the entire homelab community.

**Questions?** Open a discussion on GitHub.

**Found a bug?** Open an issue with details.

**Have an idea?** We'd love to hear it!

---

**Happy contributing! 🎉**

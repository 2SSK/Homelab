# Dashboards Changelog

## 2026-02-08: Security Dashboard Simplification

### Changes Made

#### Deleted
- **security-monitoring-overview.json** - Redundant dashboard with overlapping metrics from security-monitoring.json

#### Modified  
- **security-monitoring.json** - Scheduled for redesign to focus on actionable metrics
  - Remove excessive Fail2Ban panels
  - Add Docker daemon restart tracking
  - Add container security metrics
  - Add system security events (sudo, processes, ports)
  - Reduce from 35 → ~22 panels

### Rationale
The security-monitoring-overview dashboard was created as a "lighter" version of the full security dashboard, but having both caused confusion. Users didn't know which to check, and both had redundant information.

The consolidated dashboard will use Grafana's row collapse feature to provide both overview and detail in a single interface.

### Migration Guide
If you were using security-monitoring-overview:
- All metrics are available in the main security-monitoring dashboard
- Set rows to collapsed by default for the same "overview" experience


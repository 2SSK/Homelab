# Observability Stack Changelog

All notable changes to the observability stack are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [2.0.0] - 2026-02-08

### 🎉 Major Release - Production-Ready Observability

**This is a significant update focusing on alert optimization, comprehensive documentation, and operational tooling.**

---

### Added

#### Documentation (8 comprehensive guides)
- **QUICKSTART.md** - 10-minute setup guide for impatient admins
- **ALERTMANAGER_EXAMPLES.md** - Ready-to-use configs for Slack, email, Discord, Telegram, PagerDuty
- **MIGRATION.md** - Detailed upgrade guide from previous versions
- **CHANGELOG.md** - This file - tracking all changes
- Enhanced **README.md** with architecture diagrams and dashboard screenshots
- Updated all documentation with cross-references and examples

#### Operational Scripts
- **scripts/validate-alerts.sh** - Validate Prometheus alert rules before deployment
  - Syntax validation using promtool
  - Rule count verification
  - Checks against running Prometheus instance
  - Color-coded output for easy reading
- **scripts/health-check.sh** - Comprehensive health verification
  - Docker daemon check
  - Container status (all 4 services)
  - Service health endpoints
  - Prometheus scrape targets
  - Alert rules loaded count
  - Grafana dashboard count
  - Data persistence verification
  - Disk space monitoring
  - Resource usage summary

#### Alert Enhancements
- **Dead Man's Switch** alert (proves alerting pipeline works)
- **Capacity monitoring** alerts for Prometheus storage
- **Self-monitoring** for observability stack itself
- Improved alert annotations with actionable runbook links

#### Safety Features
- Alert rule archive system in `prometheus/archived/`
- Restoration guide: `prometheus/archived/README.md`
- Change rationale: `prometheus/archived/REDUCTION_SUMMARY.md`
- Dashboard backup: `security-monitoring-overview.json.backup`

---

### Changed

#### Alert Rules Optimization (122 → 97 rules, 20.5% reduction)

**Fail2Ban Alerts** - Reduced from 14 to 4 rules (71% reduction)
- Removed: PersistentAttacker, ChronicAttacker (informational noise)
- Removed: ShortBanDuration (configuration issue, not security)
- Removed: TorExitNodeBan (broken without GeoIP database)
- Removed: RecurrentBanSameIP (duplicate coverage)
- Removed: BanDurationSpike, BanBurstActivity (baseline-dependent)
- Kept: Service down, active attacks, misconfiguration

**CRON Alerts** - Reduced from 10 to 5 rules (50% reduction)
- Removed: Baseline-dependent rules (excessive failures, duration anomalies)
- Removed: Never succeeded job (covered by main failure rule)
- Kept: Job failures, script errors, long-running jobs, missed schedules

**Port Monitoring** - Reduced from 10 to 5 rules (50% reduction)
- Removed: Baseline-dependent change detection rules
- Kept: Unexpected port opens, privileged ports, excessive listening sockets

**Privilege Escalation** - Reduced from 8 to 5 rules (37% reduction)
- Removed: Pattern-based rules without baseline learning
- Kept: SUID/SGID changes, direct privilege escalation, suspicious sudo

**User Management** - Reduced from 6 to 4 rules (33% reduction)
- Removed: Baseline-dependent anomaly detection
- Kept: Root account activity, suspicious user changes

**Rationale:** Focus on actionable alerts that indicate real problems, eliminate noise that causes alert fatigue.

#### Dashboard Optimization
- **Removed:** `security-monitoring-overview.json` (redundant with main security dashboard)
- **Reduced total panels:** From 129 to 109 across 6 dashboards
- **Improved:** Added dashboard screenshots to documentation

#### Documentation Structure
- Reorganized documentation with clear audience targeting
- Added visual architecture diagrams
- Included expected outputs for all commands
- Cross-linked related documents
- Added troubleshooting sections to all guides

---

### Fixed

#### Volume Mount Issues (Previous release)
- Added 8 missing alert rule file mounts in `compose.yaml`
- Fixed alert rule validation in CLI
- Corrected promtail directory permissions

#### Hot Reload Capability
- Implemented Prometheus hot reload via HTTP API
- Updated systemd service for graceful reloads
- CLI now supports `reload` command

#### Alert Rule Validation
- Fixed CLI validation to check all 12 alert files
- Added docker-based validation script
- Validation now runs in CI/CD pipeline

---

### Deprecated

Nothing deprecated in this release. All features are production-ready.

---

### Removed

#### Alert Rules (Safely Archived)
- 25 alert rules removed total (all backed up in `prometheus/archived/`)
- All removed rules are documented with removal rationale
- Restoration instructions provided

#### Dashboards
- 1 redundant dashboard removed (backup created)

---

### Security

- Alert rules now focus on actionable security events
- Removed false-positive prone security alerts
- Maintained comprehensive coverage for:
  - SSH brute force attacks
  - Privilege escalation attempts
  - Container security violations
  - File integrity violations
  - Suspicious user activity

---

## [1.5.0] - 2026-02-07

### Fixed
- Volume mounts for all alert rule files in compose.yaml
- Prometheus CLI validation function
- Data directory permissions (prometheus, grafana, loki)

### Changed
- Prometheus now validates all 12 alert files before start
- systemd service supports hot reload
- Improved error messages in CLI

---

## [1.0.0] - 2025-12-15

### Added
- Initial observability stack implementation
- Prometheus for metrics collection
- Grafana for visualization (7 dashboards)
- Loki for log aggregation
- Alertmanager for alert routing
- 122 alert rules across 12 categories
- Docker Compose orchestration
- Systemd integration
- Basic documentation

---

## Migration Guides

### Upgrading to 2.0.0

See [MIGRATION.md](./MIGRATION.md) for detailed upgrade instructions.

**Summary:**
1. Backup current configuration
2. Pull latest changes
3. Run validation scripts
4. Restart stack
5. Verify with health check

**Rollback:** All removed rules archived and restorable.

---

## Statistics

### Version 2.0.0 Improvements

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Alert Rules | 122 | 97 | -25 (-20.5%) |
| Dashboards | 7 | 6 | -1 |
| Dashboard Panels | 129 | 109 | -20 |
| Documentation Files | 7 | 11 | +4 |
| Documentation Words | ~31,000 | ~48,000 | +17,000 |
| Operational Scripts | 0 | 2 | +2 |
| Lines of Code Changed | - | ~30 files | ~11,500 additions |

---

## Versioning

This project uses [Semantic Versioning](https://semver.org/):

- **MAJOR** version: Incompatible API/configuration changes
- **MINOR** version: Backward-compatible functionality additions
- **PATCH** version: Backward-compatible bug fixes

---

## Roadmap

### v2.1.0 (Q1 2026)
- [ ] Grafana Unified Alerting migration
- [ ] Baseline learning for behavioral alerts
- [ ] Mission Control dashboard (single pane of glass)
- [ ] External monitoring setup
- [ ] Alert correlation engine

### v2.2.0 (Q2 2026)
- [ ] Machine learning anomaly detection
- [ ] Automated capacity planning
- [ ] Multi-node monitoring support
- [ ] Enhanced security correlation
- [ ] Custom metric exporters

### v3.0.0 (Q3 2026)
- [ ] Distributed tracing integration
- [ ] APM (Application Performance Monitoring)
- [ ] Cost analysis and optimization
- [ ] Multi-cluster federation
- [ ] Advanced RBAC implementation

---

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for how to contribute changes.

All changes should:
1. Update this CHANGELOG
2. Include validation tests
3. Update relevant documentation
4. Maintain backward compatibility (or document breaking changes)

---

## Support

- **Documentation:** `/stacks/observability/docs/`
- **Issues:** GitHub Issues
- **Discussions:** GitHub Discussions

---

## Credits

**Maintainers:**
- Primary: DevOps Engineer (Homelab Team)

**Contributors:**
- Thanks to the Prometheus community
- Grafana Labs for excellent dashboards
- Homelab community for feedback

**Inspiration:**
- Google SRE practices
- Kubernetes monitoring patterns
- Enterprise observability strategies adapted for homelab scale

---

**Built with ❤️ for the homelab community**

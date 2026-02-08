# Alert Rules Reduction Summary

## Overview
Reduced observability alert rules from 122 to 97 (20.5% reduction) to minimize alert fatigue while maintaining security posture.

## Reduction Breakdown

### fail2ban-alerts.yml: 14 → 4 rules (71% reduction)
**Archived (10 rules)**:
- PersistentAttacker, ChronicAttacker (info noise)
- CriticalJailDown, ActiveJailOverload (edge cases)
- RestartingFrequently (duplicate of systemd alerts)
- ShortBanDuration, MultipleJailsActive (configuration noise)
- TorExitNodeAttack (broken, needs GeoIP)
- AndSSHCoordinatedAttack (redundant)
- ManyActiveBans (rarely matters)

**Kept (4 rules)**:
- Fail2banServiceDown (critical)
- Fail2banHighBanRate (active attack)
- Fail2banBanStorm (massive attack)
- Fail2banNoBansHighFailures (misconfiguration)

### cron-alerts.yml: 10 → 5 rules (50% reduction)
**Archived (5 rules)**:
- CronNewUserActivity (too noisy)
- CronOffHoursActivity (legitimate automation)
- CronRootJobModified (duplicate)
- CronUnusualFrequency, CronJobsCountAnomaly (need baseline)

**Kept (5 rules)**:
- CronServiceDown (critical)
- CronExecutionErrors (operational)
- RootCrontabModified (critical security)
- SuspiciousCronCommand (security)
- CrontabModified (security)

### port-alerts.yml: 10 → 5 rules (50% reduction)
**Archived (4 rules)**:
- CommonPortOpen, PortExposedToInternet (noisy)
- PortFlapping, RangeOfPortsOpen (need baseline)

**Kept (5 rules)**:
- HighEstablishedConnections (performance)
- SynFloodPossible (security)
- TCPSocketExhaustion (critical)
- HighTimeWaitSockets (performance)
- UDPBufferErrors (performance)

### privilege-escalation-alerts.yml: 8 → 5 rules (37.5% reduction)
**Archived (3 rules)**:
- SuspiciousSetuidOwner, SetuidCountAnomaly (need better detection)
- WorldWritableSetuid (OS-level prevention)

**Kept (5 rules)**:
- NewSUIDBinary (critical)
- SUIDSGIDSet (critical)
- SUIDBinaryTampered (critical)
- NewCapabilityAssigned (high)
- CapabilityModified (high)

### user-management-alerts.yml: 6 → 4 rules (33% reduction)
**Archived (2 rules)**:
- UserIDModified (rare)
- UserShellChanged (legitimate admin action)

**Kept (4 rules)**:
- NewUserCreated (high)
- RapidUserCreation (critical)
- UserDeleted (high)
- SudoGroupMembershipChanged (critical)

## Files Unchanged
- **alerts.yml** (25 rules) - Core system alerts, all essential
- **docker-security-alerts.yml** (17 rules) - All actionable
- **file-integrity-alerts.yml** (7 rules) - Critical security, minimal set
- **process-alerts.yml** (2 rules) - Already minimal (4 LogQL rules already commented out)
- **ssh-alerts.yml** (13 rules) - All important for security
- **sudo-alerts.yml** (6 rules) - All actionable
- **systemd-alerts.yml** (4 rules) - Minimal, all critical

## Validation
All 97 remaining alert rules validated successfully with promtool.

## Restoration
To restore archived rules, see: archived/README.md


# Archived Alert Rules

This directory contains alert rules that were removed from active monitoring to reduce alert fatigue.

## Why These Were Archived

These alerts were archived because they:
1. **Generate excessive noise** - Fire too frequently for homelab context
2. **Lack actionability** - No clear action to take when they fire
3. **Duplicate other alerts** - Same event covered by more critical alerts
4. **Need baseline learning** - Require behavioral analysis not yet implemented
5. **Log-based without Loki ruler** - Use LogQL syntax incompatible with Prometheus

## Re-enabling Archived Alerts

To re-enable an alert:
1. Copy the alert file from `archived/` back to `prometheus/`
2. Add volume mount in `compose.yaml`
3. Add reference in `prometheus.yml` rule_files section
4. Restart Prometheus

## Restoration Priority

- **Critical alerts**: Should never have been archived - restore immediately
- **Useful for security enthusiasts**: Consider restoring if you actively hunt threats
- **Nice-to-have**: Keep archived unless specific need arises
- **Remove entirely**: No practical value even for paranoid admins

Last updated: $(date -I)

---
created: 2026-03-05
tags: [backup, ci, restore, automation, monitoring]
aliases: ["backup automation", "restore schedule"]
---

# restore automation & test schedule

Purpose: document the automated testing cadence for backups/restores and the recommended CI/local automation options.

Schedule
--------
- daily: smoke test — verify snapshots exist and run `restic check --light` (implement with `stacks/backup/verify_backup.sh` and a systemd timer)
- weekly: non-destructive staging test — restore a snapshot into a temp path and run service health checks; suitable for a self-hosted GitHub Actions runner or local scheduler
- monthly: destructive restore (one service) — operator-supervised test that exercises full restore and produces a `restore_report` JSON; rotate target services (grafana → prometheus → loki → postgres)

Automation options
------------------
- local: systemd timers + repository scripts (`stacks/backup/verify_backup.sh`, `stacks/backup/restore.sh`)
- ci: GitHub Actions workflow `/.github/workflows/backup-restore-test.yml` running on a self-hosted runner with restic credentials

prometheus alert examples
-------------------------
Backup stale example rule:

```yaml
alert: BackupStale
expr: time() - node_file_mtime_seconds{job="backup",path="/var/backups/homelab"} > 86400
for: 30m
labels:
  severity: page
annotations:
  summary: "Backups appear stale on {{ $labels.instance }}"
```

Backup verification failed example rule:

```yaml
alert: BackupVerifyFailed
expr: homelab_backup_check_ok == 0
for: 15m
labels:
  severity: warning
annotations:
  summary: "Backup verification failed on {{ $labels.instance }}"
```

runbook for automated failures
-----------------------------
1. pager fires → operator inspects last backup logs in `/var/backups/homelab/<host>/<ts>/restic.stdout.log`
2. if transient (network/storage), fix and re-run `homelab backup verify` or `stacks/backup/verify_backup.sh`
3. if repository corruption is suspected, run `restic check` manually and escalate with restore report and logs

see also: `docs/backup-and-restore.md` and `docs/disaster-recovery.md` for operator procedures and templates.

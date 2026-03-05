---
created: 2026-03-05
tags: [disaster-recovery, dr, backup, restore]
aliases: ["dr runbook", "disaster recovery"]
---

# disaster recovery (dr) runbook — homelab

Purpose: practical runbook to recover system and application state from restic backups stored on an external disk. Intended for operator use during scheduled tests or real incidents.

overview
--------
- goals: recover critical system state (`/etc`, systemd units, SSH, tailscale) and application state (docker volumes, bind mounts); prove recoverability with destructive tests
- storage model: primary backup disk mounted at `/mnt/backup`; restic repo at `/mnt/backup/restic`; local artifacts at `/var/backups/homelab/<host>/<timestamp>/`

initial setup
-------------
1. attach external USB and identify device (use `lsblk`)
2. create filesystem and mount point (example using ext4):

```bash
sudo mkfs.ext4 -L HOMELAB_BACKUP /dev/sdX
sudo mkdir -p /mnt/backup
sudo mount /dev/disk/by-label/HOMELAB_BACKUP /mnt/backup
# optional: add to /etc/fstab using UUID for persistent mount
```

3. secure mount point:

```bash
sudo chown root:root /mnt/backup
sudo chmod 700 /mnt/backup
```

4. create restic password file (root-only):

```bash
printf 'your-strong-password' | sudo tee /etc/homelab/restic.pass >/dev/null
sudo chmod 600 /etc/homelab/restic.pass
```

5. copy `stacks/backup/restic.env.example` → `stacks/backup/restic.env` and set `RESTIC_REPOSITORY` and `RESTIC_PASSWORD_FILE`

6. initialize restic (one-time):

```bash
export RESTIC_PASSWORD_FILE=/etc/homelab/restic.pass
restic init --repo /mnt/backup/restic
```

quick manual backup
-------------------
Run the orchestrator:

```bash
sudo bash stacks/backup/backup.sh
```

confirm snapshot exists:

```bash
restic -r /mnt/backup/restic snapshots
```

inspect local artifacts:

```bash
ls -la /var/backups/homelab/$(hostname -s)/*
```

destructive restore examples
---------------------------
grafana

1. ensure a recent backup and successful verify
2. identify grafana volume name (eg. `grafana_data`): `docker volume ls`
3. remove the grafana volume:

```bash
docker volume rm grafana_data
```

4. restore via helper:

```bash
sudo bash stacks/backup/restore.sh restore latest grafana_data
```

5. start grafana and validate via API health and search endpoints

postgres

prefer logical dumps for production; for volume-based DR test:

```bash
docker-compose -f stacks/observability/compose.yaml stop postgres
docker volume rm postgres_data
sudo bash stacks/backup/restore.sh restore latest postgres_data
docker-compose -f stacks/observability/compose.yaml up -d postgres
docker exec -it $(docker ps -qf name=postgres) psql -U postgres -c 'SELECT 1;'
```

validation checks
-----------------
- grafana: `/api/health` and search endpoint return expected results
- prometheus: `/-/ready` returns 200 and queries like `up` return data
- loki: readiness or basic query returns results

restore report template
-----------------------
See `stacks/backup/restore_report_template.json` (example fields: test_id, service, snapshot_id, started_at, finished_at, checks.sha256, checks.service_up, logs_path, operator)

offsite copy options
--------------------
- rotate a second encrypted USB monthly via `rclone sync`
- run MinIO on a remote host and use restic S3 backend

retention policy
----------------
- `restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune`
- schedule prune weekly to avoid long-running prune during daily backups

where to store artifacts
------------------------
- primary: `/var/backups/homelab/<host>/<timestamp>/`
- offsite: secondary USB or remote host (MinIO/rclone)

troubleshooting
---------------
- restic auth: ensure `RESTIC_PASSWORD_FILE` is set and readable by root
- slow backups: check sizes/compressibility and consider alternative snapshot strategies
- restore failures: collect restic logs and produce restore report JSON for diagnosis

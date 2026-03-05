---
created: 2026-03-05
tags: [backup, restic, restore, runbook]
aliases: ["backup guide", "restore runbook"]
---

# backup and restore — homelab

Operator-facing runbook for restic-based backups shipped with this repository. The scripts and systemd templates live under `stacks/backup/` and are wrapped by the CLI at `cli/homelab.sh`.

overview
--------
- location: `stacks/backup/` (versioned)
- cli: `./cli/homelab.sh backup <command>`
- scope: encrypted, incremental backups of system state (`/etc`, systemd units, SSH), application state (docker volumes, bind mounts), and repository artifacts

design goals
------------
- incremental backups with deduplication (restic)
- encrypted at rest
- primary off-host copy on an external USB (mounted at `/mnt/backup`)
- automatable via systemd timers and CI
- regular restore testing (staging + destructive exercises)

quickstart — initialize storage and restic
----------------------------------------
1. mount external USB at `/mnt/backup` (use UUID in `/etc/fstab`):

```bash
sudo mkdir -p /mnt/backup
sudo mount /dev/disk/by-id/<your-device> /mnt/backup
sudo chown root:root /mnt/backup && sudo chmod 700 /mnt/backup
```

2. create restic password file (root-only):

```bash
printf 'REPLACE-WITH-STRONG-PASSWORD' | sudo tee /etc/homelab/restic.pass >/dev/null
sudo chmod 600 /etc/homelab/restic.pass
```

3. copy the example env and point to the password file:

```bash
cp stacks/backup/restic.env.example stacks/backup/restic.env
# edit stacks/backup/restic.env and set RESTIC_PASSWORD_FILE=/etc/homelab/restic.pass
```

4. initialize the restic repository:

```bash
export RESTIC_PASSWORD_FILE=/etc/homelab/restic.pass
restic init --repo /mnt/backup/restic
```

run a backup via CLI
--------------------
From the repository root run:

```bash
./cli/homelab.sh backup run
```

verify backups
--------------
Run verification and basic integrity checks:

```bash
./cli/homelab.sh backup verify
```

stage and non-destructive restore
--------------------------------
Stage (non-destructive) restores snapshot contents into `/tmp` for inspection:

```bash
./cli/homelab.sh backup stage
```

destructive restore (example)
-----------------------------
Restore a named docker volume from the latest snapshot:

```bash
./cli/homelab.sh backup restore latest grafana_data
```

install systemd timers
----------------------
Install templates and enable timers for scheduled backups and pruning:

```bash
sudo ./cli/homelab.sh backup install-systemd
sudo ./cli/homelab.sh backup enable-timers
```

destructive restore examples
---------------------------
grafana (POC):

```bash
docker volume rm grafana_data
sudo ./cli/homelab.sh backup restore latest grafana_data
docker-compose -f stacks/observability/compose.yaml up -d grafana
sleep 10
curl -s -u admin:admin http://localhost:3000/api/health | jq .
```

postgres (POC): prefer `pg_dump` for Phase 2; volume restore example:

```bash
docker-compose -f stacks/observability/compose.yaml stop postgres
docker volume rm postgres_data
sudo ./cli/homelab.sh backup restore latest postgres_data
docker-compose -f stacks/observability/compose.yaml up -d postgres
docker exec -it $(docker ps -qf name=postgres) psql -U postgres -c 'SELECT 1;'
```

retention & pruning
-------------------
Recommended restic retention policy:

- `--keep-daily 7`
- `--keep-weekly 4`
- `--keep-monthly 6`

Schedule `restic forget` + `--prune` weekly via `homelab-prune.timer`.

offsite copy options
--------------------
- secondary encrypted USB (rotate monthly via `rclone sync`)
- self-hosted MinIO as S3-compatible backend
- copy over Tailscale/SSH with `rclone` or `rsync`

observability
-------------
The verify script writes a Prometheus textfile under `/var/lib/node_exporter/textfile_collector/homelab_backup.prom`. Scrape it and alert on stale backups or verification failures.

troubleshooting
---------------
- restic auth errors: ensure `RESTIC_PASSWORD_FILE` points to a readable file owned by root and `restic.env` references it
- slow backups: inspect volume sizes, disk throughput, and consider logical dumps or block-level snapshots for large datasets

operator checklist
------------------
1. mount USB and initialize restic
2. run `./cli/homelab.sh backup run`
3. run `./cli/homelab.sh backup verify`
4. install and enable systemd timers if desired
5. schedule monthly destructive restore exercises and keep reports in `/var/backups/homelab/<host>/<ts>/`

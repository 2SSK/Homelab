# Homelab v2 roadmap

Goal: safely operate Ubuntu servers. A fresh server is provisioned with one
command. Problems are detected and alerted outside the monitored machines.
Service is recovered with a documented runbook, and the recovery is proven.

Having the tools running is not the goal. The readiness gates at the end are.

## What v2 is

| Concern | Tool |
|---|---|
| Fast test fleet | [vpslab](https://github.com/2SSK/vpslab) containers, git submodule at `vpslab/` |
| Production-parity tests | Small Ubuntu server VMs from cloud images (`vm create`) |
| Host configuration | Ansible (inventory, roles, playbooks) |
| How services run | Native: pinned upstream binaries or vendor apt repos, managed by systemd. No Docker |
| Metrics | node_exporter and app exporters → Prometheus |
| Logs | journald and files → Grafana Alloy → Loki |
| Traces | OTel SDKs → Alloy (OTLP) → Tempo, added with the app |
| Dashboards | Grafana, provisioned from git |
| Alerts | Prometheus and Loki rules → Alertmanager → a receiver outside the lab, plus an external Watchdog |
| Backups | restic to an off-host repository, database-aware for Postgres |
| Bootstrap secrets | ansible-vault (only what is needed to reach the secret store) |
| Other secrets | OpenBao (single node, ADR before M7) |
| Demo app | Go API and Temporal worker, Temporal server, Postgres, Next.js |
| Operator CLI | Go, built last, wrapping Ansible and the stack's APIs |

Not planned: Kubernetes, Docker on the servers, custom collectors or config
management, a management web UI, multi-region, service discovery.

### Why native binaries and systemd instead of containers

- vpslab nodes are already containers. Docker inside them means nested overlayfs,
  iptables, and cgroups, which is complexity a real VPS doesn't have.
- systemd gives restart policy, resource limits (`MemoryMax`, `CPUQuota`),
  sandboxing (`ProtectSystem`, `DynamicUser`), and journald logs for free. It is
  the same mechanism the demo app uses.
- Each component is one pinned version, one config file, one unit, one data
  directory. That is easy to back up, upgrade, and roll back with Ansible.

| Component | Install from | Verify |
|---|---|---|
| Prometheus, Alertmanager, node_exporter | GitHub release tarball | `sha256sums.txt` |
| Grafana, Loki, Alloy, Tempo | Grafana apt repo, version pinned | apt signature |
| Postgres | PGDG apt repo, major version pinned | apt signature |
| Temporal server | GitHub release tarball | checksum |
| OpenBao | GitHub release or its apt repo | checksum or signature |

## Two test layers

| Layer | What it proves | When |
|---|---|---|
| **vpslab** (containers, seconds to reset) | Ansible connectivity, idempotency, deploys, config validation, scraping, log shipping, basic failures | Every commit |
| **Ubuntu VM** (`vm create`, minutes) | Kernel OOM, real block devices and disk exhaustion, reboots, kernel updates, firewall, SSH recovery | VM gates in M3, M5, M9, before cutover |

vpslab is the fast loop, not the final authority on host behaviour. A milestone
with a VM gate is only done when the gate passes on a VM.

## Monitoring requirements

| # | Need | Source | Done when |
|---|---|---|---|
| 1 | CPU, memory, load, disk, inodes, read-only filesystem | node_exporter | `stress-ng`, a disk fill, and an inode fill each fire their alert |
| 2 | systemd services: logs, failed state, restart count | journald → Alloy, node_exporter systemd collector | An error line shows in Grafana within 30s. A crash loop fires an alert |
| 3 | OOM kills, kernel and cgroup (`MemoryMax`) kills kept separate | `node_vmstat_oom_kill`, kernel and systemd journal, `memory.events` | A `MemoryMax=50M` hog shows as a cgroup kill. A host-wide hog shows as a kernel kill (VM) |
| 4 | Nginx: routes, status, latency, bytes, upstream failures, timeouts | JSON access and error log → Alloy | Load test numbers match the panel. A dead upstream fires an alert |
| 5 | Packages and versions, security updates, reboot required | dpkg and apt → textfile collector | `apt install htop` shows within one timer run. A pending kernel update shows reboot required |
| 6 | CVEs: fixable vs unfixable, scan freshness | SBOM → scanner → textfile collector (counts only) | An old vulnerable package raises the fixable count. A stopped scan fires a stale alert |
| 7 | Outbound traffic. E0 per host (required), E1 per service (does not block) | Interface counters, then nftables per-cgroup counters | E0: a 1 GB download shows on the host. E1: it is counted against the right service |
| 8 | Apps: RED, traces, workflows, DB availability and connections, backup age | OTel, Temporal and postgres_exporter metrics, backup job metrics | Each trace segment is proven separately, then the full chain |

Built in order: 1 → 2 → 3 → 4 → 5 → 6 → 7 E0. Then 8 with the app. 7 E1 can be done whenever there's time.

## Production standards (apply to every milestone)

- **Pinned and verified:** every binary, package, and collection has a pinned
  version and a checksum or signature. Never `latest`.
- **Private:** Prometheus, Loki, Tempo, Alertmanager, and OpenBao are never
  public. Bind them to the private IP or localhost. Reach them over Tailscale or an SSH tunnel.
- **Sandboxed:** every service has its own user, a hardened systemd unit, and a `MemoryMax`.
- **Sized:** every store has retention and a disk budget. Each node has a measured
  resource budget (M9). Alert on the monitoring disk itself.
- **Validated before activated:** `sshd -t`, `nginx -t`, `promtool check config`,
  `amtool check-config`, `alloy validate`. A bad config never reaches a restart.
- **Tested alerts:** every alert has a `promtool` test, a `runbook_url`, and
  someone who acts on it. An alert nobody acts on gets deleted.
- **Low cardinality:** Loki labels are `job`, `host`, `unit`, plus `env` and
  `service` where useful. Never path, IP, status, user, trace id, or request id.
- **Idempotent and safe:** the second run reports `changed=0`. Destructive actions
  need an explicit variable. `--diff` and `-v` are never used on secret-bearing tasks.
- **No secrets in git or logs:** ansible-vault for bootstrap, OpenBao for the rest, `no_log: true`.

## Branching strategy

```
main ──●──●──●──●──●──●──●──●──●  v2: small commits, straight to main
   \
    v1.0.0 tag ── legacy/v1        frozen v1, real server tracks it until M11
```

- **v1 is frozen** as tag `v1.0.0` and branch `legacy/v1`. Hotfixes go there only
  if the real server needs them. They are never merged forward.
- **v2 is committed straight to `main`.** No feature branches and no PRs. Each
  commit is one small, working step (one task or part of one), so `main` always works.
- **Before each push,** run the commit checklist below. If a change can't be
  finished in one working commit, split it into smaller ones.
- **v1 code is deleted in the commit that proves its replacement.** There are no
  compatibility layers.
- **Commits** use `type(scope): summary` (72 chars max). Types: `feat fix docs
  refactor chore test ci`. Scopes: `ansible role/<name> obs alerts backup secrets app cli lab docs ci`.
- **Tags:** `v2.0.0-alpha.N` per milestone, `v2.0.0` at cutover. Delete `legacy/v1` after cutover's rollback window.

### vpslab submodule

vpslab is its own repo with its own commits and tags, also straight to its
`main`. Homelab pins one commit of it.

```bash
git clone --recurse-submodules git@github.com:2SSK/Homelab.git   # fresh clone
git submodule update --init                                       # existing clone

cd vpslab && git switch main    # commit and push in vpslab
cd .. && git add vpslab && git commit -m "chore(lab): bump vpslab to <tag>"
```

Homelab only points at vpslab commits that are pushed to vpslab's `main`.

### Commit checklist

- [ ] `make lint` passes (yamllint, ansible-lint, shellcheck, promtool, golangci-lint)
- [ ] Fresh lab: `make lab-reset && make apply` succeeds
- [ ] The second `make apply` reports `changed=0` on every host
- [ ] `make check` (`--check --diff`) shows no unexpected changes
- [ ] The task's "done when" was demonstrated
- [ ] v1 code it replaces is deleted, and docs are updated

## Milestones

| | Milestone | Repo | Weeks | Tag |
|---|---|---|---|---|
| M0 | Freeze v1, add the submodule | Homelab | 0.5 | `v1.0.0` |
| M1 | vpslab nodes behave like production servers | vpslab | 2 | vpslab `v0.2.0` |
| M2 | Cleanup and skeleton | Homelab | 1 | |
| M3 | Ansible baseline and safe operations | Homelab | 4 | `alpha.1` |
| M4 | Observability core | Homelab | 3 | `alpha.2` |
| M5 | Advanced host monitoring | Homelab | 5 | `alpha.3` |
| M6 | Backup and restore | Homelab | 2 | `alpha.4` |
| M7 | Secret store | Homelab | 2 | `alpha.5` |
| M8 | Demo app with a real deployment lifecycle | Homelab + app repo | 5 | `beta.1` |
| M9 | Reliability proof | Homelab | 3 | `beta.2` |
| M10 | Go CLI | Homelab | 3 | `rc.1` |
| M11 | Production cutover | Homelab | 1 + 2 rollback window | `v2.0.0` |

Total is about 32 weeks at 1–2 hours a day.

---

### M0: Freeze v1

- [x] M0.1 Tag `v1.0.0`, create and push `legacy/v1`
- [x] M0.2 Disable the deploy and shellcheck workflows
- [ ] M0.3 Switch the real server to `legacy/v1`
- [x] M0.4 Add vpslab as a submodule at `vpslab/`, and add this roadmap
- [ ] M0.5 Answer the open decisions at the bottom of this file

### M1: vpslab nodes behave like production servers

Today `free`, `top`, `/proc/loadavg`, and node_exporter on a node show **your
workstation's** numbers, a disk fill fills your own disk, and `make down` throws
the node away. Every monitoring milestone depends on these being true.

Since the stack runs as native services, nodes don't need Docker inside them.

**The server is saved**

- [ ] M1.1 **Node state on volumes:** `/etc`, `/var`, `/home`, `/root`, `/opt`,
  and `/srv` live on named volumes per node. `/proc`, `/sys`, `/run`, and `/tmp`
  do not. Done when a file and an installed package on vps-02 survive
  `docker compose down && make up`.
- [ ] M1.2 **Boot persistence:** nodes come back on their own after a host reboot
  or a Docker restart, with the same machine-id, SSH host keys, and IP. Done when
  you reboot the host and `make check` passes with no `known_hosts` warning.
- [ ] M1.3 **Clear lifecycle:** `stop`/`start` is power off and on, `down`/`up`
  replaces the hardware but keeps the disk, and `destroy` wipes a node for good.
  `make reset` = `destroy` + `up`. Done when each target does what its name says.

**The numbers are true**

- [ ] M1.4 **LXCFS:** run `lxcfs` on the host with loadavg enabled. Bind its
  `/proc/{meminfo,cpuinfo,stat,loadavg,uptime,diskstats,swaps}` into every node.
  Done when `free -m` matches `mem_limit`, `nproc` matches `cpus`, and
  `stress-ng --cpu 1` raises one node's load but not its neighbours'.
- [ ] M1.5 **Per-node sizing:** each node gets its own CPU and memory, kept in one
  place. Start with vps-01 2 CPU / 2 GiB (monitoring), vps-02 1 / 1 GiB (web),
  vps-03 2 / 3 GiB (Temporal and Postgres). These get re-measured in M9.
- [ ] M1.6 **Own disk:** each node's state volumes sit on a fixed-size filesystem
  (spike: loop-backed ext4 image vs XFS project quota), so filling it cannot fill
  the host. Done when `df -h /var` shows the node's size and `fallocate` past it
  fails on that node only.
- [ ] M1.7 **node_exporter tells the truth:** run node_exporter by hand on a node
  and compare CPU, memory, load, and filesystem metrics with the limits. Done
  when every number matches, or the mismatch is understood and written down.

**Parity and gaps**

- [ ] M1.8 **Cloud-image parity:** match a fresh Ubuntu server cloud image, with
  `python3` present, journald persistent, and the same default packages. Done when
  `ansible -m ping` works on a fresh node with no bootstrap play.
- [ ] M1.9 **Known gaps:** document in the vpslab README what still differs from a
  VM: shared kernel (kernel log, kernel OOM, eBPF, kernel updates), no real block
  device, no reboot of the kernel. Each item points to the VM gate that covers it.
- [ ] M1.10 Extend `make test` to assert M1.1–M1.8. Tag vpslab `v0.2.0` and bump the submodule.

### M2: Cleanup and skeleton

- [ ] M2.1 Delete dead v1 paths: `osquery/`, `prometheus/archived/`, the
  `.ssh-enhanced` promtail config, `cli/remove/`, the old workflows. Remove
  tethering and networkd unless they are still needed.
- [ ] M2.2 Create the v2 layout: `ansible.cfg inventory/{lab,vm} playbooks roles tests docs/{adr,runbooks}`
- [ ] M2.3 Pin the toolchain: `ansible-core`, `ansible-lint`, `yamllint`, and a `requirements.yml` for collections
- [ ] M2.4 Makefile: `lint lab-up lab-reset apply check`. The lab targets call `make -C vpslab`
- [ ] M2.5 CI `lint.yml` on every push to `main`
- [ ] M2.6 README: what v2 is, current status, quickstart

Done when `make lint` is green locally and in CI.

### M3: Ansible baseline and safe operations

**Baseline**

- [ ] M3.1 `inventory/lab/hosts.yml`. Groups: `monitoring` (vps-01), `web` (vps-02),
  `apps` (vps-03), `nodes` (all). Each host has an SSH address (`127.0.0.1:220N`),
  a `private_ip` (`10.80.0.1N`), and `env: lab`. Keys come from `vpslab/keys/`.
- [ ] M3.2 `roles/baseline`: packages, timezone, admin user, journald persistent with size cap, NTP
- [ ] M3.3 `playbooks/site.yml`, with `make apply` and `make check`
- [ ] M3.4 `tests/idempotency.sh`: run twice, fail if the second run changed anything
- [ ] M3.5 `roles/ssh_hardening`: drop-in config, `validate: sshd -t`, restart handler
- [ ] M3.6 Lockout drill: break sshd, recover with `make -C vpslab console 02`, write `docs/runbooks/ssh-lockout.md`
- [ ] M3.7 `roles/firewall`: nftables, default deny inbound, allow SSH and only
  the ports each group needs from `private_ip` ranges
- [ ] M3.8 ansible-vault for bootstrap secrets only: `group_vars/all/vault.yml`, password file outside the repo
- [ ] M3.9 Optional `roles/dotfiles`. Delete `cli/bootstrap/` and the v1 Docker install

**Safe operations**

- [ ] M3.10 `roles/preflight`, run first in every play: OS version, free disk and
  memory, time sync, reachability. Fails before anything changes
- [ ] M3.11 `serial` in `site.yml` so changes roll out one host at a time, with
  `max_fail_percentage: 0`
- [ ] M3.12 A pattern for installing a pinned binary role: download to a
  versioned dir, verify checksum, switch a `current` symlink, validate config,
  restart, health check. The previous version stays for rollback
- [ ] M3.13 OS maintenance: unattended security updates, reboot-required
  detection, `playbooks/patch.yml` that patches and reboots one host at a time
  with post-reboot health checks. Runbook for emergency patching

**VM gate 1**

- [ ] M3.14 `vm create` an Ubuntu server VM, add it as `inventory/vm/`, and run
  `site.yml` and `patch.yml` (including a real kernel update and reboot) against it

Done when `make lab-reset && make apply && make test-idempotency && make check`
is all green, and VM gate 1 passes.

### M4: Observability core (requirements 1 and 2)

- [ ] M4.1 ADR covering the data flow, native install, retention and disk budget,
  why Alloy, why Alertmanager, why node_exporter stays separate from Alloy
- [ ] M4.2 `roles/node_exporter` on all nodes, listening on `private_ip`, with the
  textfile directory and the systemd collector enabled
- [ ] M4.3 `roles/prometheus` on `monitoring`. Scrape targets generated from the
  inventory (`groups['nodes']`). Retention by time and size
- [ ] M4.4 `roles/alertmanager`. Routes, inhibition of node alerts when the node
  is down, a receiver outside the lab (see open decisions)
- [ ] M4.5 **External monitoring (hard requirement):** Watchdog alert to an
  external heartbeat that pages when it stops. An external uptime check of the
  monitoring host
- [ ] M4.6 Alert rules with `promtool test rules` (see the alert set below)
- [ ] M4.7 `roles/loki` (local filesystem storage, compactor retention) and
  `roles/alloy` on all nodes: journal → Loki with `host`, `unit`, `level`, `env`
  labels. Alloy's own metrics scraped
- [ ] M4.8 `roles/grafana`: datasources with fixed UIDs, the Node Exporter Full
  dashboard, admin password from vault, no sign-up
- [ ] M4.9 `roles/demo_service` on `apps`: a tiny HTTP service under systemd that
  logs JSON to stdout. The real app replaces it in M8
- [ ] M4.10 Services dashboard showing log volume, error rate, failed units, restarts
- [ ] M4.11 Delete v1 observability, `cli/homelab.sh`, promtail. Rewrite `docs/observability.md`

Done when stopping a node fires exactly one `InstanceDown` to the external
receiver, stopping Prometheus makes the external heartbeat page, and service logs
appear in Grafana.

### M5: Advanced host monitoring (requirements 3 to 7)

- [ ] M5.1 **OOM:** alert on `node_vmstat_oom_kill`. Alloy parses kernel `Killed
  process` lines and systemd `oom-kill` results separately, with the process as
  structured metadata. Dashboard with kills per day, kernel vs cgroup, top processes
- [ ] M5.2 **Nginx:** `roles/nginx` on `web`. JSON access log (`uri status
  request_time upstream_status upstream_response_time request_length bytes_sent`)
  and the error log. Validated with `nginx -t`
- [ ] M5.3 Nginx → Alloy → Loki. Routes normalised (`/users/123` → `/users/:id`) at query time
- [ ] M5.4 Nginx dashboard: requests per route, status mix, p50/p95/p99, bytes,
  upstream failures and timeouts. Loki recording rules for expensive queries.
  Alerts for 5xx ratio and upstream down
- [ ] M5.5 **Packages:** a timer plus an apt hook write `package_info{name,version}`,
  security updates pending, and reboot required, atomically (temp file then
  rename). Check the community `apt_info` script first
- [ ] M5.6 Package dashboard: versions per host, drift, security updates, reboot required
- [ ] M5.7 **CVE spike:** measure Trivy vs Syft+Grype for RAM, DB size, and false
  positives on Ubuntu. Record the result in an ADR
- [ ] M5.8 `roles/vuln_scan`: a daily timer. Counts by severity × fixable as
  metrics, plus the last-success timestamp. Per-CVE detail as JSON logs in Loki
- [ ] M5.9 **Egress E0:** bytes out per host per day and month, plus a cost panel
  (price per GB as a variable). Budget alert
- [ ] M5.10 **VM gate 2:** run M5.1 with a host-wide memory hog on the VM. The
  kernel OOM path must show up
- [ ] M5.11 Optional, does not block: **Egress E1**, per-service bytes via
  nftables `socket cgroupv2` counters. Validate on the VM's kernel first

Done when requirements 3 to 6 and 7 E0 pass, and VM gate 2 passes.

### M6: Backup and restore

A successful backup job is not proof. A restore is.

- [ ] M6.1 ADR: what is backed up per node, RPO and RTO for each, the off-host
  restic repository, where the restic password lives outside the servers, retention
- [ ] M6.2 `roles/backup`: restic plus a systemd timer, prune and `restic check`.
  Metrics for last success, duration, and size via the textfile collector
- [ ] M6.3 Config and state: Grafana database, Prometheus snapshot API (not a raw
  copy of a live TSDB), Loki data if within RPO, Alertmanager silences
- [ ] M6.4 Alerts: `BackupStale`, `BackupFailed`, repository check failed
- [ ] M6.5 Restore drill: destroy vps-01, `make apply`, restore, verify
  dashboards and history are back. Record the actual RTO
- [ ] M6.6 Delete v1 `stacks/backup`, `docker/backup-image`, the backup CLI and its workflow

Done when the restore drill passes and its time is within the RTO in the ADR.

### M7: Secret store

ansible-vault holds only what's needed to reach OpenBao. Everything else moves
into OpenBao. The recovery material lives offline, never on the servers.

- [ ] M7.1 ADR: OpenBao single node, Raft storage, TLS, unseal method, where the
  unseal and recovery keys live offline, what happens when it is down
- [ ] M7.2 `roles/openbao` on `monitoring`: TLS, audit log to Loki, not public
- [ ] M7.3 Init and unseal runbook, plus a drill: restart the node, then unseal
- [ ] M7.4 Policies per consumer (Ansible, Grafana, app). AppRole for machines, no root token in use
- [ ] M7.5 Move secrets out of ansible-vault. Ansible reads them with the `community.hashi_vault` lookup
- [ ] M7.6 Apps read secrets at startup, not per request. A store outage doesn't take the app down
- [ ] M7.7 Monitoring: metrics, `SecretStoreSealed`, token and lease expiry, audit failures
- [ ] M7.8 Raft snapshots added to backups. Restore drill: rebuild vps-01, restore
  the snapshot, unseal with the offline keys, Ansible works again

Done when only bootstrap secrets remain in ansible-vault, and the rebuild-restore-unseal drill passes.

### M8: Demo app with a real deployment lifecycle (requirement 8)

A simple app built to be operated. It lives in its own repo. Homelab deploys and monitors it.

| Component | Node | Runs as |
|---|---|---|
| Next.js frontend | vps-02 (`web`) behind nginx | systemd |
| Go API and Go Temporal worker | vps-03 (`apps`) | systemd |
| Temporal server | vps-03 (`apps`) | systemd, release binary |
| Postgres | vps-03 (`apps`) | systemd, PGDG package |
| Tempo | vps-01 (`monitoring`) | systemd, Grafana apt repo |

```
build → verify checksum → preflight → backup and migration check → deploy → health check
                                                                      pass: keep / fail: roll back
```

- [ ] M8.1 App repo: Go API with `/healthz` and `/readyz`, a Temporal workflow
  with two activities (one calls an external API), a Next.js page, graceful
  shutdown, OTel from the start
- [ ] M8.2 App CI builds versioned artifacts with checksums
- [ ] M8.3 `roles/postgres` and `roles/temporal`, credentials from OpenBao.
  Postgres backups with `pg_dump` or `pg_basebackup`, never a raw data dir copy
- [ ] M8.4 `roles/app_*`: the release lifecycle above, the current version and
  deploy history recorded on the host, rollback to the previous release
- [ ] M8.5 Migrations: backward-compatible (expand, then contract). Rolling back a
  binary must work with the new schema
- [ ] M8.6 Rollback test: deploy a deliberately broken release, health check
  fails, previous version restored automatically
- [ ] M8.7 `roles/tempo`. Alloy receives OTLP on each node: traces to Tempo,
  metrics to Prometheus, logs to Loki
- [ ] M8.8 Traces proven one segment at a time: Next.js server → API, API →
  Temporal → worker, worker → Postgres and the external API. Then browser to DB
- [ ] M8.9 Correlation: trace id in every log line, exemplars on latency metrics,
  links between logs, traces, and metrics in Grafana
- [ ] M8.10 Exporters and dashboards: RED per endpoint, workflow success,
  failure, latency, backlog, Postgres availability and connection saturation, backup age
- [ ] M8.11 SLOs for the API (availability and p95) with burn-rate alerts. Alerts
  tell app failure apart from dependency failure
- [ ] M8.12 Delete `roles/demo_service`

Done when a click shows as one trace, a broken release rolls itself back, and a
failing activity and an SLO burn each fire an alert.

### M9: Reliability proof

- [ ] M9.1 `tests/chaos/`: node down, CPU stress, memory hog, disk and inode fill,
  read-only filesystem, sshd broken, crash loop, nginx 5xx and dead upstream,
  egress burst, Prometheus killed, Alloy broken, OpenBao sealed, Postgres down,
  worker killed, slow external API, monitoring host lost
- [ ] M9.2 Runner: inject → assert the alert reached the external receiver →
  recover with the runbook → assert resolved. Records MTTD, MTTR, and alert delivery latency
- [ ] M9.3 One runbook per alert in `docs/runbooks/`, linked from `runbook_url`
- [ ] M9.4 Upgrade drills: upgrade Prometheus, Grafana, Postgres minor, and the
  app, then roll each back
- [ ] M9.5 Full rebuild drill: destroy a node, provision, restore, verify. Record RPO and RTO
- [ ] M9.6 Resource budget per node measured under load (ingestion rate, disk
  growth, workflow throughput, DB connections). Update sizes and retention
- [ ] M9.7 **VM gate 3:** run the host-level scenarios on VMs

Done when every scenario passes in one run, with MTTD, MTTR, RPO, and RTO recorded.

### M10: Go CLI

These are the commands that M9 showed you repeating. The CLI wraps Ansible and
calls the Prometheus, Loki, Alertmanager, and OpenBao APIs. It reimplements none of them.

- [ ] M10.1 Module skeleton in `cli/`: cobra, slog, an exec runner behind an interface so it can be tested
- [ ] M10.2 `homelab inventory`
- [ ] M10.3 `homelab check` / `homelab apply --inventory <env> [--limit] [--tags]`.
  Prod needs confirmation. Ctrl-C cancels cleanly and exit codes are passed through
- [ ] M10.4 `homelab status`: `up`, firing alerts, backup age, OpenBao sealed
- [ ] M10.5 `homelab logs <host> [--unit] [--since]` via the Loki API
- [ ] M10.6 `homelab doctor`: tools, vault file, SSH reachability, stack health

Done when `go test -race` passes with ≥ 80% coverage and golangci-lint is clean.

### M11: Production cutover

- [ ] M11.1 `inventory/prod/` with its own bootstrap vault and OpenBao
- [ ] M11.2 Full backup of the real server. v1 restore tested
- [ ] M11.3 Maintenance window. Apply v2 one host at a time, then run the
  post-deploy checklist (readiness gates below)
- [ ] M11.4 Two-week rollback window during which v1 stays recoverable
- [ ] M11.5 Delete `legacy/v1`, tag `v2.0.0`

## Production readiness gates

v2 is done when all of these pass on VMs and on the real server.

| Gate | Passes when |
|---|---|
| Fresh provisioning | A clean Ubuntu VM is provisioned with no manual steps |
| Idempotency | A repeated run makes no changes |
| Security | No public monitoring endpoints, no secrets in git, key-only SSH, default-deny firewall |
| Observability | Alerts arrive outside the monitored machines. Losing the monitoring host pages |
| Backups | A restore was performed and its time recorded |
| Recovery | A failed host was rebuilt from the docs |
| Upgrades | OS, stack, and app upgrades each have a tested rollback |
| Reliability | Every injected failure alerted and was fixed by its runbook |
| Documentation | Someone else could operate it from the docs alone |

## Alert set (start here, grow only from real incidents)

| Alert | Condition |
|---|---|
| `InstanceDown` | `up == 0` for 2m |
| `HostCPUHigh` | busy > 90% for 10m |
| `HostMemoryLow` | available < 10% for 5m |
| `HostLoadHigh` | `load5 / cores > 2` for 15m |
| `HostDiskWillFill` | `predict_linear` says full within 24h |
| `HostDiskAlmostFull` | free < 10% |
| `HostInodesLow` | free inodes < 10% |
| `HostFilesystemReadOnly` | `node_filesystem_readonly == 1` on a writable mount |
| `HostOOMKill` | `increase(node_vmstat_oom_kill[5m]) > 0` |
| `SystemdUnitFailed` | a unit is in the `failed` state |
| `SystemdUnitFlapping` | restarts > 3 in 15m |
| `RebootRequired` | for more than 7 days |
| `AlloyDown` | Alloy `up == 0` |
| `Nginx5xxHigh` | 5xx > 5% of requests for 5m |
| `NginxUpstreamDown` | upstream errors for 2m |
| `EgressOverBudget` | bytes out per day > budget |
| `CVECriticalFixable` | a critical CVE has a fix available |
| `TextfileStale` | scan or package metrics older than 26h |
| `BackupStale` | last successful backup older than RPO |
| `SecretStoreSealed` | OpenBao reports sealed |
| `APIErrorBudgetBurn` | fast or slow burn of the API SLO |
| `WorkflowFailures` | failed Temporal workflows > 0 for 5m |
| `PostgresDown` / `PostgresConnectionsHigh` | down for 1m / > 80% of `max_connections` |
| `Watchdog` | always firing, to an external heartbeat |

## Open decisions (answer in M0)

1. **Ubuntu version:** 24.04 LTS (vpslab today) or 26.04 LTS. vpslab, VMs, and
   the real server should all match.
2. **Alert receiver and heartbeat:** email, Telegram, or ntfy, plus an external
   heartbeat service (e.g. healthchecks.io).
3. **Off-host backup target:** a cloud bucket (S3-compatible) or another machine.
4. **Own roles or collections:** write roles yourself (learning), or use
   `prometheus.prometheus` and `grafana.grafana` (maintained). A middle path is
   writing node_exporter and Prometheus yourself, then judging the collections.
5. **Tethering and networkd:** still needed on the real server?
6. **Dotfiles role:** keep or drop?

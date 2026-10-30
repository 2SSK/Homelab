# Homelab v2 roadmap

Goal: provision a fresh Ubuntu server with one command and get production-grade
observability for it. A failure should be detected, alerted, and fixed with a
documented runbook.

## What v2 is

| Concern | Tool |
|---|---|
| Host configuration | Ansible (inventory, roles, playbooks, ansible-vault) |
| Metrics | node_exporter → Prometheus |
| Logs | journald and files → Grafana Alloy → Loki |
| OpenTelemetry | Alloy receives OTLP from apps; OTel semantic conventions for names |
| Dashboards | Grafana (provisioned from git, no clicking) |
| Alerts | Prometheus and Loki rules → Alertmanager, plus a Watchdog heartbeat |
| Test fleet | [vpslab](https://github.com/2SSK/vpslab) as a git submodule at `vpslab/` |
| Operator CLI | Go, built last, only for commands you actually repeat |
| Dotfiles | GNU Stow (unchanged) |

Out of scope: Kubernetes, tracing backends (Tempo), HashiCorp Vault, Molecule.

## Monitoring requirements

| # | Need | Source | Answer in Grafana | Done when |
|---|---|---|---|---|
| 1 | CPU, memory, load, disk | node_exporter | Host dashboard and alerts | `stress-ng` or a disk fill fires the alert |
| 2 | systemd service logs | journald → Alloy | Logs per `unit`, error rate | An app error line shows in Grafana within 30s |
| 3 | OOM kills | `node_vmstat_oom_kill` and the kernel and systemd journal | Kills over time, which process, how big | A `MemoryMax=50M` hog appears with its name and time |
| 4 | Nginx traffic | JSON access log → Alloy | Requests per route, status, p95 latency, bytes in and out | Load test numbers match the panel |
| 5 | Packages and versions | dpkg → textfile collector | Package × host table, version drift | `apt install htop` shows up within one run of the timer |
| 6 | CVEs | Package list (SBOM) → scanner → textfile collector | CVE counts by severity, fixes available | An old vulnerable package raises the count |
| 7 | Outbound traffic | Interface counters → nftables per-service counters | Bytes out per host and per service, cost per month | A 1 GB download is counted against the right service |

They are built in order of difficulty: 1 → 2 → 3 → 4 → 5 → 6 → 7.

## Production standards (apply to every milestone)

- **Pinned:** image tags, binary versions, Ansible collections. Never `latest`.
- **Private:** Prometheus, Loki, and Alertmanager have no auth. Bind them to the
  private IP or localhost and reach them over Tailscale or an SSH tunnel.
- **Sized:** set retention (`retention.time` and `retention.size`, Loki compactor
  retention) and per-container memory limits. Alert on the monitoring disk itself.
- **Tested alerts:** every alert has a `promtool test rules` case, a `runbook_url`,
  and someone who acts on it. An alert nobody acts on gets deleted.
- **Low cardinality:** Loki labels are only `job`, `host`, `unit`. Never path,
  IP, status, or request id.
- **Idempotent:** the second `ansible-playbook` run reports `changed=0`.
- **No secrets in git:** ansible-vault with `vault_` prefixed variables and `no_log: true`.

## Branching strategy

```
main ──●──●──●──●──●──────────●  (v2, always working)
        \  \                  ↑
         \  m2/role-baseline ─┘  short-lived, squash-merged
          \
           v1.0.0 tag ── legacy/v1   (frozen v1, real server tracks it until M8)
```

- **v1 is frozen** as tag `v1.0.0` and branch `legacy/v1`. Hotfixes go there only
  if the real server needs them. They are never merged forward.
- **v2 lives on `main`.** Do one small branch per task or two, named
  `m<N>/<topic>` (e.g. `m4/alloy-journal`), then open a PR and squash-merge.
- **There is no long-lived `v2` branch.** It would end in one giant merge, and
  nothing on it would be used until then.
- **v1 code is deleted in the PR that proves its replacement** on vpslab. There
  are no compatibility layers. v1 lives on in `legacy/v1`.
- **Commits** use `type(scope): summary` (72 chars max). Types: `feat fix docs
  refactor chore test ci`. Scopes: `ansible role/<name> obs alerts cli lab docs ci`.
- **Tags:** `v2.0.0-alpha.N` at the end of each milestone, `v2.0.0` at cutover.
  Delete `legacy/v1` after cutover and keep the tag.

### vpslab submodule

vpslab is its own repo with its own PRs and tags. Homelab pins one commit of it.

```bash
git clone --recurse-submodules git@github.com:2SSK/Homelab.git   # fresh clone
git submodule update --init                                       # existing clone

# change vpslab: work inside the submodule like any repo
cd vpslab && git switch -c m1/lxcfs   # ...commit, push, PR, merge in vpslab...
git switch main && git pull && cd ..
git add vpslab && git commit -m "chore(lab): bump vpslab to <tag>"
```

Rule: Homelab only points at vpslab commits that are merged to vpslab's `main`.

### Definition of done for every PR

- [ ] `make lint` passes (yamllint, ansible-lint, shellcheck, promtool, golangci-lint)
- [ ] Fresh lab: `make lab-reset && make apply` succeeds
- [ ] The second `make apply` reports `changed=0` on every host
- [ ] `make check` (`--check --diff`) shows no unexpected changes
- [ ] The task's "done when" was demonstrated and the output pasted in the PR
- [ ] v1 code it replaces is deleted, and docs are updated

## Milestones

| | Milestone | Repo | Weeks | Tag |
|---|---|---|---|---|
| M0 | Freeze v1, add the submodule | Homelab | 0.5 | |
| M1 | vpslab behaves like a real server | vpslab | 2 | vpslab `v0.2.0` |
| M2 | Cleanup and skeleton | Homelab | 1 | |
| M3 | Ansible baseline | Homelab | 3 | `alpha.1` |
| M4 | Observability core | Homelab | 3 | `alpha.2` |
| M5 | Advanced monitoring | Homelab | 5 | `alpha.3` |
| M6 | Reliability proof | Homelab | 2 | `beta.1` |
| M7 | Go CLI | Homelab | 3 | `beta.2` |
| M8 | Production cutover | Homelab | 1 | `v2.0.0` |

Total is about 20 weeks at 1–2 hours a day.

---

### M0: Freeze v1

`.github/workflows/deploy.yml` runs `git pull origin main` on the real server on
every push. It must be off before any v2 merge.

- [ ] M0.1 Tag `v1.0.0`, create and push `legacy/v1`
- [ ] M0.2 `gh workflow disable` both deploy and shellcheck. Switch the server to `legacy/v1`
- [ ] M0.3 Add vpslab as a submodule at `vpslab/`, and add this roadmap
- [ ] M0.4 Answer the open decisions at the bottom of this file

Done when `gh workflow list` shows the deploy workflow disabled and the server is on `legacy/v1`.

### M1: vpslab behaves like a real server

Today the nodes are containers that share the host kernel. `free`, `top`,
`/proc/loadavg`, and node_exporter all show **your workstation's** CPU, memory,
and load. A disk fill fills your own disk. Fix what can be fixed, and write down what can't.

- [ ] M1.1 **LXCFS:** run `lxcfs` on the host with loadavg enabled. Bind its
  `/proc/{meminfo,cpuinfo,stat,loadavg,uptime,diskstats,swaps}` into every node.
  Done when `free -m` shows 1 GiB, `nproc` shows 1, and `stress-ng --cpu 1`
  raises the node's load but not its neighbours'.
- [ ] M1.2 **Per-node sizing:** each node gets its own `cpus` and `mem_limit`.
  vps-01 (monitoring) gets 2 CPUs and 2 GiB. Done when `free` agrees on each node.
- [ ] M1.3 **Own disk:** each node gets a fixed-size data disk (spike: loop-backed
  ext4 image vs XFS project quota) so filling it cannot fill the host. Done when
  `df -h /` shows the node's own size and `fallocate` past it fails on the node only.
- [ ] M1.4 **Persistence:** node state (`/etc`, `/var`, `/home`) survives
  `make stop/start`, a host reboot, and `docker compose up --force-recreate`.
  Only `make reset` wipes it. Done when a file written on vps-02 survives a host reboot.
- [ ] M1.5 **Cloud-image parity:** match a fresh Ubuntu 24.04 cloud server, with
  `python3` present, journald persistent, and the same default packages. Done when
  `ansible -m ping` works on a fresh node with no bootstrap play.
- [ ] M1.6 **Docker inside a node:** `/var/lib/docker` on its own volume so
  overlay2 works. Done when `docker run hello-world` works on vps-01.
- [ ] M1.7 **Known gaps:** document in the vpslab README what still differs from
  a VM. The kernel log is host-wide, so kernel OOM lines and eBPF need a real VM.
  Done when every requirement in the table above is marked lab-testable or VM-only.
- [ ] M1.8 Extend `make test` to assert M1.1–M1.6. Tag vpslab `v0.2.0` and bump the submodule.

### M2: Cleanup and skeleton

- [ ] M2.1 Delete dead v1 paths: `osquery/`, `prometheus/archived/`, the
  `.ssh-enhanced` promtail config, `cli/remove/`, the old workflows. Remove
  tethering and networkd unless they are still needed.
- [ ] M2.2 Create the v2 layout: `ansible.cfg inventory/lab playbooks roles stacks/observability tests docs/runbooks`
- [ ] M2.3 Pin the toolchain: `ansible-core`, `ansible-lint`, `yamllint`, and a `requirements.yml` for collections
- [ ] M2.4 Makefile: `lint lab-up lab-reset apply check`. The lab targets call `make -C vpslab`
- [ ] M2.5 CI `lint.yml`, and protect `main`
- [ ] M2.6 README: what v2 is, current status, quickstart

Done when `make lint` is green locally and in CI.

### M3: Ansible baseline

- [ ] M3.1 `inventory/lab/hosts.yml`. Groups: `monitoring` (vps-01), `web` (vps-02),
  `apps` (vps-03), `nodes` (all). Each host has an SSH address (`127.0.0.1:220N`)
  and a `private_ip` (`10.80.0.1N`). Keys come from `vpslab/keys/`.
- [ ] M3.2 `roles/baseline`: packages, timezone, admin user, unattended-upgrades, journald persistent with size cap
- [ ] M3.3 `playbooks/site.yml`, with `make apply` and `make check`
- [ ] M3.4 `tests/idempotency.sh`: run twice, fail if the second run changed anything
- [ ] M3.5 `roles/ssh_hardening`: drop-in config, `validate: sshd -t`, restart handler
- [ ] M3.6 Lockout drill: break sshd, recover with `make -C vpslab console 02`, write `docs/runbooks/ssh-lockout.md`
- [ ] M3.7 `roles/docker` for the `monitoring` and `web` groups only, with log rotation in `daemon.json`
- [ ] M3.8 ansible-vault: `group_vars/all/vault.yml`, password file outside the repo
- [ ] M3.9 Optional `roles/dotfiles`. Delete `cli/bootstrap/` and `cli/install/docker.sh`

Done when `make lab-reset && make apply && make test-idempotency && make check` is all green.

### M4: Observability core (requirements 1 and 2)

- [ ] M4.1 ADR covering the data flow, retention sizing, why Alloy, why
  Alertmanager, and why node_exporter is separate from Alloy
- [ ] M4.2 `stacks/observability/compose.yaml` on vps-01: Prometheus, Loki,
  Grafana, Alertmanager. Pinned, memory-limited, healthchecked, deployed by Ansible
- [ ] M4.3 `roles/node_exporter` on all nodes, listening on `private_ip`, with the textfile directory enabled
- [ ] M4.4 Prometheus scrape targets generated from the inventory (`groups['nodes']`)
- [ ] M4.5 Grafana provisioning: datasources with fixed UIDs, the Node Exporter
  Full dashboard, admin password from vault
- [ ] M4.6 Alert rules and tests (see the alert list below). Alertmanager routing,
  with node alerts inhibited when the node is down. Watchdog sent to an external heartbeat
- [ ] M4.7 `roles/alloy`: journal → Loki with `unit`, `host`, `level` labels. Alloy's own metrics scraped
- [ ] M4.8 `roles/demo_app` on `apps`: a small HTTP service under systemd that logs JSON to stdout
- [ ] M4.9 Services dashboard showing log volume, error rate, and failed units
- [ ] M4.10 Delete v1 observability, `cli/homelab.sh`, and promtail. Rewrite `docs/observability.md`

Done when stopping a node fires exactly one `InstanceDown`, `stress-ng` fires the
CPU alert, and the demo app's logs appear in Grafana.

### M5: Advanced monitoring (requirements 3 to 7)

- [ ] M5.1 **OOM:** the `node_vmstat_oom_kill` alert. Alloy parses the kernel
  `Killed process` lines and systemd `oom-kill` messages, with the process as
  structured metadata, not a label. Dashboard with kills per day, top processes,
  and recent events. Kernel lines need the real VM.
- [ ] M5.2 **Nginx:** `roles/nginx` on `web`, using `log_format escape=json`
  with `uri status request_time upstream_response_time request_length bytes_sent`
- [ ] M5.3 Nginx → Alloy → Loki. Routes normalised (`/users/123` → `/users/:id`)
  when extracted at query time
- [ ] M5.4 Nginx dashboard showing requests per route, status mix, p50/p95/p99,
  and bytes. Loki recording rules for the expensive queries. 5xx-ratio alert
- [ ] M5.5 **Packages:** a timer plus an apt hook write `package_info{name,version}`
  atomically (temp file then rename). Check the community `apt_info` script first
- [ ] M5.6 Package dashboard with versions per host, drift, pending upgrades, and reboot required
- [ ] M5.7 **CVE spike:** measure Trivy vs Syft+Grype for RAM, DB size, and false
  positives on Ubuntu. Record the result in an ADR
- [ ] M5.8 `roles/vuln_scan`: a daily timer, counts by severity and fixable as
  metrics, per-CVE detail as JSON logs in Loki. Alerts for a fixable critical and for a stale scan
- [ ] M5.9 **Egress E0:** bytes out per host and month, plus a cost panel (price per GB as a variable)
- [ ] M5.10 **Egress E1:** nftables counters per systemd unit (`socket cgroupv2`)
  → textfile collector. Budget alert
- [ ] M5.11 Optional, real VM only: per-destination egress via DNS logs plus
  Alloy `beyla.ebpf`. Write an ADR first

Done when each requirement's "done when" passes. Requirement 3's kernel check passes on a real VM.

### M6: Reliability proof

- [ ] M6.1 `tests/chaos/`: node down, CPU stress, memory hog / OOM, disk fill,
  sshd broken, app crash loop, nginx 5xx burst, egress burst, Prometheus killed, Alloy broken
- [ ] M6.2 Runner: inject → assert the alert fired (Alertmanager API) → recover → assert it resolved
- [ ] M6.3 One runbook per alert in `docs/runbooks/`, linked from `runbook_url`
- [ ] M6.4 `roles/backup` (restic plus a timer) replaces `stacks/backup`. Restore drill for the Grafana and Prometheus data

Done when all scenarios pass in one run, with time-to-detect recorded.

### M7: Go CLI

These are the commands that M6 showed you repeating. The CLI wraps Ansible and
calls the Prometheus, Loki, and Alertmanager APIs. It reimplements none of them.

- [ ] M7.1 Module skeleton in `cli/`: cobra, slog, an exec runner behind an interface so it can be tested
- [ ] M7.2 `homelab inventory` (from `ansible-inventory --list`)
- [ ] M7.3 `homelab check` / `homelab apply [--limit] [--tags]`. Ctrl-C cancels cleanly and exit codes are passed through
- [ ] M7.4 `homelab status` showing `up` and firing alerts
- [ ] M7.5 `homelab logs <host> [--unit] [--since]` via the Loki API
- [ ] M7.6 `homelab doctor`: tools, vault file, SSH reachability, stack health

Done when `go test -race` passes with ≥ 80% coverage and golangci-lint is clean.

### M8: Production cutover

- [ ] M8.1 `inventory/prod/` with a separate vault
- [ ] M8.2 Back up the real server, apply v2, verify the dashboards and alerts
- [ ] M8.3 Delete `legacy/v1`, tag `v2.0.0`

## Alert set (start here, grow only from real incidents)

| Alert | Condition |
|---|---|
| `InstanceDown` | `up == 0` for 2m |
| `HostCPUHigh` | busy > 90% for 10m |
| `HostMemoryLow` | available < 10% for 5m |
| `HostLoadHigh` | `load5 / cores > 2` for 15m |
| `HostDiskWillFill` | `predict_linear` says full within 24h |
| `HostDiskAlmostFull` | free < 10% |
| `HostOOMKill` | `increase(node_vmstat_oom_kill[5m]) > 0` |
| `SystemdUnitFailed` | a unit is in the `failed` state |
| `AlloyDown` | Alloy self-metrics `up == 0` |
| `Nginx5xxHigh` | 5xx > 5% of requests for 5m |
| `EgressOverBudget` | bytes out per day > budget |
| `CVECriticalFixable` | a critical CVE has a fix available |
| `TextfileStale` | scan or package metrics older than 26h |
| `Watchdog` | always firing, sent to an external heartbeat |

## Open decisions (answer in M0)

1. Backup: convert it to a role in M6, or delete it?
2. Tethering and networkd: still needed on the real server?
3. Docker: Ubuntu archive (`docker.io`) or Docker's apt repo?
4. Dotfiles role: keep or drop?
5. Alert receiver: email, Telegram, or ntfy?

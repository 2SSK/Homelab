# 0001. Healthcheck Strategies for Minimal Container Images

**Status:** Accepted  
**Date:** 2026-01-24  
**Decision Makers:** Infrastructure Team  
**Tags:** docker, healthchecks, observability, containers, reliability

## Context

Docker healthchecks are critical for service reliability, enabling automatic restart of unhealthy containers and ensuring proper service startup ordering through `depends_on` conditions.

The standard approach uses `wget` or `curl` to query HTTP health endpoints:

```yaml
healthcheck:
  test: ["CMD", "wget", "-q", "--spider", "http://localhost:9090/-/healthy"]
```

However, we encountered an issue with the Promtail container (`grafana/promtail:2.9.3`):
- The image is intentionally minimal (Alpine-based, ~50MB)
- It does not include `wget`, `curl`, or `nc` utilities
- Adding these tools would increase image size by ~2-3MB (4-6% increase)
- The Promtail service does expose a health endpoint at `:9080/ready`

This created a conflict between:
1. **Minimalism**: Respecting upstream's decision for small, focused images
2. **Reliability**: Needing proper healthchecks for production deployment
3. **Maintainability**: Avoiding custom image builds that add maintenance burden

## Decision

We will implement a three-tier healthcheck strategy:

### Tier 1 (Preferred): HTTP Endpoint Check with Dedicated Tools

Use `wget` or `curl` when available in the base image:

```yaml
healthcheck:
  test: ["CMD", "wget", "-q", "--spider", "http://localhost:PORT/ENDPOINT"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

**When to use:**
- Base image includes wget/curl
- Service has HTTP health endpoint
- Simple, readable, well-understood pattern

**Examples:** Prometheus, Grafana, Loki, Alertmanager, Node Exporter, cAdvisor

### Tier 2 (Fallback): Bash TCP Socket Check

For minimal images without wget/curl but with bash:

```yaml
healthcheck:
  test:
    [
      "CMD-SHELL",
      "bash -lc 'exec 3<>/dev/tcp/127.0.0.1/PORT; printf \"GET /endpoint HTTP/1.1\\r\\nHost: localhost\\r\\nConnection: close\\r\\n\\r\\n\" >&3; read -r line <&3; [[ \"$$line\" == *\"200\"* ]]'",
    ]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

**How it works:**
1. Opens TCP connection using bash's built-in `/dev/tcp` feature
2. Sends HTTP GET request to health endpoint
3. Reads response and validates HTTP 200 status
4. Returns exit code 0 (success) or non-zero (failure)

**When to use:**
- Image lacks wget/curl but has bash
- Service has HTTP health endpoint
- Want to avoid custom image builds

**Requirements:**
- Bash shell (not just sh/busybox)
- HTTP health endpoint returning 200 OK

**Examples:** Promtail

### Tier 3 (Last Resort): Process or Port Check

When no HTTP endpoint exists:

```yaml
# Port listening check
healthcheck:
  test: ["CMD-SHELL", "netstat -tlnp | grep :PORT"]

# Process check
healthcheck:
  test: ["CMD-SHELL", "pgrep -x process_name"]
```

**When to use:**
- No HTTP health endpoint available
- Basic liveness check needed
- Legacy services

## Consequences

### Positive

1. **Reliability Without Customization**
   - Proper healthchecks for all services
   - No need to maintain custom container images
   - Respects upstream image design decisions

2. **Dependency-Free Pattern**
   - Bash TCP check uses only built-in bash features
   - No external utilities required
   - Works with minimal images

3. **Production-Ready**
   - Proper HTTP health endpoint validation (checks for 200 status)
   - Suitable for service orchestration
   - Enables `depends_on` with health conditions

4. **Portable Pattern**
   - Can be applied to other minimal images
   - Template for future service additions
   - Well-documented for team knowledge

### Negative

1. **Complexity**
   - Bash TCP check is more complex than `wget`
   - Requires understanding of bash redirections and HTTP protocol
   - More difficult to troubleshoot for beginners

2. **Escaping Requirements**
   - Docker Compose requires `$$` for literal `$` in shell commands
   - Easy to get wrong when copying patterns
   - Must be careful with quote escaping

3. **Bash Dependency**
   - Requires bash specifically (not sh/busybox)
   - Risk if upstream switches to even more minimal base (e.g., distroless)
   - Would need fallback to Tier 3 if bash is removed

4. **Maintainability**
   - Long one-liner commands are harder to read
   - Inline documentation with comments is critical
   - Team members must understand the pattern

## Alternatives Considered

### Alternative 1: Custom Container Image

Build custom Promtail image with wget added:

```dockerfile
FROM grafana/promtail:2.9.3
RUN apk add --no-cache wget
```

**Rejected because:**
- Adds maintenance burden (rebuilds on upstream updates)
- Defeats upstream's minimalism goals
- Creates supply chain complexity
- Requires private registry or build process
- Only saves ~20 characters of healthcheck config

### Alternative 2: Simple Port Check

Use `netstat` or `nc` to verify port is listening:

```yaml
healthcheck:
  test: ["CMD-SHELL", "netstat -tlnp | grep 9080"]
```

**Rejected because:**
- Only checks if port is listening, not if service is healthy
- Promtail could be listening but unable to ship logs
- Less robust than endpoint check
- Doesn't validate HTTP 200 response

### Alternative 3: No Healthcheck

Omit healthcheck entirely:

```yaml
promtail:
  # No healthcheck defined
```

**Rejected because:**
- Loses automatic restart on failure
- Can't use `depends_on` health conditions properly
- Reduces production reliability
- Goes against infrastructure best practices

### Alternative 4: External Health Probe

Use separate container to perform healthchecks:

```yaml
healthcheck-probe:
  image: alpine/curl
  command: curl http://promtail:9080/ready
```

**Rejected because:**
- Adds complexity (extra container)
- Doesn't integrate with Docker's native healthcheck system
- Can't use for `depends_on` conditions
- Overkill for this problem

## Implementation Details

### Bash TCP Check Breakdown

```bash
bash -lc '
  exec 3<>/dev/tcp/127.0.0.1/9080;           # Open bidirectional TCP connection (fd 3)
  printf "GET /ready HTTP/1.1\r\n            # Send HTTP GET request
          Host: localhost\r\n                # Required HTTP/1.1 header
          Connection: close\r\n\r\n" >&3;    # Close connection after response
  read -r line <&3;                          # Read first response line
  [[ "$line" == *"200"* ]]                   # Check for "200" in response
'
```

**Note:** In Docker Compose YAML, use `$$line` to escape the `$` character.

### Testing the Healthcheck

**Inside container:**
```bash
# Test TCP connection
docker exec promtail bash -c 'exec 3<>/dev/tcp/127.0.0.1/9080 && echo "Connection OK"'

# Check if port is listening
docker exec promtail netstat -tlnp | grep 9080

# Run full healthcheck command
docker exec promtail bash -lc 'exec 3<>/dev/tcp/127.0.0.1/9080; printf "GET /ready HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n" >&3; read -r line <&3; [[ "$line" == *"200"* ]]' && echo "Healthy"
```

**View healthcheck logs:**
```bash
docker inspect promtail | jq '.[0].State.Health.Log[-3:]'
```

## Decision Tree

Use this flowchart when implementing healthchecks:

```
Does service have HTTP health endpoint?
├─ NO → Use Tier 3 (port/process check)
└─ YES
   └─ Does image include wget or curl?
      ├─ YES → Use Tier 1 (wget/curl check)
      └─ NO
         └─ Does image include bash?
            ├─ YES → Use Tier 2 (bash TCP check)
            └─ NO → Consider:
                   1. Use Tier 3 (port check)
                   2. Switch to image with bash
                   3. Build custom image with wget
```

## Future Considerations

1. **Image Updates**
   - Pin exact versions to prevent surprises
   - Test healthchecks when updating images
   - Document any changes to base image utilities

2. **Pattern Library**
   - Create reusable healthcheck templates
   - Share across multiple stacks
   - Consider helper script volume mounts for complex checks

3. **Monitoring**
   - Track healthcheck failure rates in Prometheus
   - Alert on repeated healthcheck failures
   - Dashboard for container health status

4. **Documentation**
   - Inline comments in compose.yaml
   - Link to this ADR from configuration files
   - Update troubleshooting guides

## References

- [Docker Healthcheck Documentation](https://docs.docker.com/engine/reference/builder/#healthcheck)
- [Bash TCP Redirections](https://www.gnu.org/software/bash/manual/html_node/Redirections.html)
- [Grafana Promtail Image](https://hub.docker.com/r/grafana/promtail)
- [HTTP/1.1 Specification RFC 2616](https://www.rfc-editor.org/rfc/rfc2616)

## Related ADRs

- None yet (first ADR)

## Revision History

- 2026-01-24: Initial version (accepted)

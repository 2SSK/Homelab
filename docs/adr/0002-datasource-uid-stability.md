# 0002. Grafana Datasource UID Stability

**Status:** Accepted  
**Date:** 2026-01-24  
**Decision Makers:** Infrastructure Team  
**Tags:** grafana, observability, configuration, portability, dashboard

## Context

Grafana uses UIDs (unique identifiers) to reference datasources in dashboards, alerts, and API calls. When datasources are provisioned through configuration files without explicit UIDs, Grafana automatically generates random UIDs like `P4F5DE9A7C23B1234`.

### The Problem

Without stable UIDs, we experienced several issues:

1. **Dashboard Portability**: Exported dashboards contain datasource references by UID. When importing to another Grafana instance, the UIDs don't match, requiring manual remapping of every panel.

2. **Git Instability**: Dashboard JSON files change on every export due to random UID regeneration, creating noise in version control.

3. **API Integration**: External tools can't reliably reference datasources because UIDs are unpredictable.

4. **Configuration Drift**: Each Grafana instance generates different UIDs for the same logical datasources, making multi-environment setups fragile.

### Example Dashboard JSON

```json
{
  "panels": [
    {
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "P4F5DE9A7C23B1234"  // Random - breaks on import
          },
          "expr": "up"
        }
      ]
    }
  ]
}
```

When importing this dashboard to a new Grafana instance with different UIDs, all panels show "N/A" or "No Data" until manually remapped.

## Decision

We will explicitly define stable, predictable UIDs for all provisioned Grafana datasources using a simple, consistent naming convention.

### Implementation

**Datasource provisioning configuration** (`grafana/provisioning/datasources/datasources.yml`):

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    uid: prometheus        # ✅ Explicit stable UID
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false

  - name: Loki
    uid: loki             # ✅ Explicit stable UID
    type: loki
    access: proxy
    url: http://loki:3100
    editable: false

  - name: Alertmanager
    uid: alertmanager     # ✅ Explicit stable UID
    type: alertmanager
    access: proxy
    url: http://alertmanager:9093
    editable: false
```

### Naming Convention

UIDs follow this pattern:

**Single instance:**
```
uid: <service-name>
```
Examples: `prometheus`, `loki`, `alertmanager`, `testdata`

**Multiple instances (future-proofing):**
```
uid: <service-name>-<qualifier>
```
Examples: `prometheus-internal`, `prometheus-external`, `prometheus-dev`

**Rules:**
- All lowercase
- No special characters except hyphens
- Descriptive and predictable
- Match service names when possible

## Consequences

### Positive

1. **Dashboard Portability** ✅
   - Dashboards exported from one instance work on another without modification
   - Pre-built dashboards from Grafana.com can use standard UIDs
   - Team members can share dashboards via JSON files
   - CI/CD can provision identical dashboards across environments

2. **Configuration as Code** ✅
   - UIDs tracked in Git provide full configuration history
   - Reproducible deployments across dev/staging/prod
   - No configuration drift between instances
   - Infrastructure as Code principles fully applied

3. **API Reliability** ✅
   - External tools can reliably reference datasources
   - Automation scripts don't break on datasource recreation
   - Monitoring tools can use stable references

4. **Disaster Recovery** ✅
   - Restore from backup without breaking dashboards
   - No manual UID remapping after recovery
   - Alert rules maintain datasource references

5. **Git Hygiene** ✅
   - Dashboard JSON files remain stable in version control
   - No noisy diffs from UID changes
   - Easier code review of dashboard changes

6. **Cross-Datasource References** ✅
   - Loki derived fields can reliably reference Prometheus
   - Alert rules with multiple datasources remain stable
   - Template variables work consistently

### Negative

1. **Migration Requirement**
   - Existing Grafana instances need UID migration
   - Dashboards created before UID stabilization need manual update
   - One-time effort to align with standard

2. **Collision Risk**
   - Must ensure UIDs are unique across all datasources
   - Manual tracking needed (addressed by naming convention)

3. **Manual Configuration**
   - UIDs must be explicitly set in provisioning files
   - Can't rely on Grafana's auto-generation
   - Requires documentation and adherence to convention

## Alternatives Considered

### Alternative 1: Auto-Generated UIDs (Status Quo)

Continue using Grafana's automatic UID generation.

**Rejected because:**
- Breaks dashboard portability (primary pain point)
- Creates git noise in dashboard JSON files
- Prevents reliable API integration
- No way to predict UIDs for automation

### Alternative 2: Numeric UIDs

Use simple numeric identifiers:

```yaml
datasources:
  - name: Prometheus
    uid: "1"
  - name: Loki
    uid: "2"
```

**Rejected because:**
- Not self-documenting
- Requires lookup table to understand meaning
- Collision-prone in multi-environment setups
- Doesn't scale well

### Alternative 3: UUID Format

Use proper UUIDs for strong uniqueness:

```yaml
datasources:
  - name: Prometheus
    uid: "f7a8b3c4-d5e6-47f8-9a0b-1c2d3e4f5a6b"
```

**Rejected because:**
- Defeats the purpose of human-readable references
- Not memorable or type-able
- Overkill for this use case
- Doesn't improve portability over random IDs

### Alternative 4: Namespace-Prefixed UIDs

Include environment or namespace in UID:

```yaml
datasources:
  - name: Prometheus
    uid: "homelab-prod-prometheus"
```

**Rejected because:**
- Reduces portability (defeats the purpose)
- Dashboards wouldn't work across environments
- Unnecessarily verbose
- Better handled by Grafana organization/folder structure

## Implementation Details

### Current Datasources

| Datasource | UID | Type | Purpose |
|------------|-----|------|---------|
| Prometheus | `prometheus` | prometheus | Metrics queries and alerts |
| Loki | `loki` | loki | Log queries and exploration |
| Alertmanager | `alertmanager` | alertmanager | Alert management UI |

### Dashboard Compatibility

**Pre-provisioned dashboards** in `grafana/provisioning/dashboards/homelab-system.json` already use these UIDs:

```json
"datasource": {
  "type": "prometheus",
  "uid": "prometheus"
}
```

Adding explicit UIDs to provisioning config **fixed a latent dependency issue** - dashboards were assuming UIDs that weren't guaranteed.

### Loki Derived Fields

Cross-datasource references now work reliably:

```yaml
datasources:
  - name: Loki
    uid: loki
    jsonData:
      derivedFields:
        - datasourceUid: prometheus  # ✅ Stable reference
          matcherRegex: "container_id=(\\w+)"
          name: ContainerID
```

This allows jumping from logs to metrics with consistent navigation.

## Migration Guide

For existing Grafana instances with random UIDs:

### Step 1: Identify Current UIDs

```bash
# Query Grafana API
curl -s http://admin:password@localhost:3000/api/datasources | jq '.[] | {name, uid, type}'
```

### Step 2: Update Dashboards

```bash
# Update dashboard JSON to use new stable UIDs
sed -i 's/"uid": "OLD_RANDOM_UID"/"uid": "prometheus"/g' dashboards/*.json
```

### Step 3: Update Provisioning Config

Add explicit UIDs to `datasources.yml` (as shown in Decision section).

### Step 4: Restart Grafana

```bash
docker restart grafana
```

Grafana will update datasources to use new UIDs. Dashboards updated in Step 2 will continue working.

## Validation

After implementation, verify:

1. **Datasource UIDs are correct:**
   ```bash
   curl -s http://localhost:3000/api/datasources | jq '.[] | {name, uid}'
   ```

2. **Dashboards reference correct UIDs:**
   ```bash
   grep -r '"uid"' grafana/provisioning/dashboards/*.json
   ```

3. **Cross-datasource links work:**
   - View logs in Loki
   - Click "Show in Prometheus" derived field link
   - Verify it opens correct Prometheus query

## Future Considerations

### Additional Datasources

When adding new datasources, follow the naming convention:

**Single instance:**
```yaml
- name: Thanos
  uid: thanos
  type: prometheus
```

**Multiple instances:**
```yaml
- name: Prometheus (Internal)
  uid: prometheus-internal
  type: prometheus

- name: Prometheus (External)
  uid: prometheus-external
  type: prometheus
```

### Dashboard Library

Create a library of reusable dashboards with stable UID references:

```
grafana/dashboards/
├── infrastructure/
│   ├── node-metrics.json      # Uses uid: prometheus
│   └── container-logs.json    # Uses uid: loki, uid: prometheus
└── applications/
    └── service-overview.json  # Uses uid: prometheus, uid: loki
```

These dashboards work across any Grafana instance using the same UID convention.

### Multi-Tenant Scenarios

If running multiple independent homelab instances:

**Option 1: Same UIDs (recommended for portability)**
```yaml
# Both instances use same UIDs
homelab-a: uid: prometheus
homelab-b: uid: prometheus
```

Dashboards are fully portable.

**Option 2: Namespaced UIDs (for shared Grafana)**
```yaml
# Single Grafana instance with multiple data sources
homelab-a: uid: homelab-a-prometheus
homelab-b: uid: homelab-b-prometheus
```

Requires dashboard variants per namespace.

## References

- [Grafana Datasource Provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/#datasources)
- [Grafana Datasource API](https://grafana.com/docs/grafana/latest/developers/http_api/data_source/)
- [Dashboard JSON Model](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/view-dashboard-json-model/)

## Related ADRs

- [0001: Healthcheck Strategies](0001-healthcheck-strategies.md) - Infrastructure reliability patterns

## Revision History

- 2026-01-24: Initial version (accepted)

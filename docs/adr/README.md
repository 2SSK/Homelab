# Architecture Decision Records (ADR)

## Overview

This directory contains Architecture Decision Records (ADRs) for the Homelab project. ADRs document significant architectural decisions, providing context for why certain approaches were chosen and what alternatives were considered.

## Format

Each ADR follows this structure:

```markdown
# [Number]. [Title]

**Status:** [Proposed | Accepted | Deprecated | Superseded]
**Date:** YYYY-MM-DD
**Decision Makers:** [Who was involved]
**Tags:** [relevant, tags]

## Context

What is the issue we're addressing? What factors are we considering?

## Decision

What did we decide to do and why?

## Consequences

What are the positive and negative outcomes of this decision?

## Alternatives Considered

What other options did we evaluate?
```

## When to Create an ADR

Create an ADR when making decisions about:

- Infrastructure architecture and patterns
- Technology selection for core components
- Security and compliance approaches
- Data management strategies
- Service integration patterns
- Performance optimization strategies
- Significant changes to existing patterns

## ADR Process

1. **Draft**: Create a new ADR with status "Proposed"
2. **Review**: Discuss with relevant stakeholders
3. **Decide**: Update status to "Accepted" once consensus is reached
4. **Implement**: Apply the decision in code/configuration
5. **Update**: If superseded, mark old ADR as "Superseded by ADR-XXXX"

## Numbering Convention

ADRs are numbered sequentially starting from 0001. Use four digits with leading zeros (e.g., 0001, 0002, 0010, 0123).

## Current ADRs

| Number | Title | Status | Date |
|--------|-------|--------|------|
| [0001](0001-healthcheck-strategies.md) | Healthcheck Strategies for Minimal Container Images | Accepted | 2026-01-24 |
| [0002](0002-datasource-uid-stability.md) | Grafana Datasource UID Stability | Accepted | 2026-01-24 |

## Resources

- [Michael Nygard's ADR documentation](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [ADR GitHub organization](https://adr.github.io/)

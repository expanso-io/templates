# Walkthrough 19: Circuit Breakers & Fallbacks

**Track:** Advanced Patterns
**Difficulty:** Advanced
**Time:** 35 minutes
**Prerequisites:** W10 (DLQ), W09 (Routing)

## Overview

Implement circuit breaker patterns with fallback outputs for resilient pipelines.

## The Pipeline

`pipeline-circuit-breaker.yaml`:

```yaml
input:
  stdin:
    codec: lines

output:
  try:
    # Primary output (may fail)
    - file:
        path: "output/primary-${!timestamp_unix}.json"

    # Fallback if primary fails
    - file:
        path: "output/fallback-${!timestamp_unix}.json"
```

## Test Data

`test-data/events.json`:

```json
{"event_id":"evt-001","data":"test"}
{"event_id":"evt-002","data":"test"}
```

## Run It

```bash
cat test-data/events.json | expanso-edge run pipeline-circuit-breaker.yaml
```

## Related: Template 22 (`templates/patterns/circuit-breaker.yaml`)

# Walkthrough 20: Production-Grade Pipeline Blueprint

**Track:** Advanced Patterns
**Difficulty:** Advanced
**Time:** 45 minutes
**Prerequisites:** W10, W19, W16-W18

## Overview

Build a production-grade pipeline combining DLQs, circuit breakers, monitoring, and multi-cloud routing.

## The Pipeline

`pipeline-production.yaml`:

```yaml
input:
  stdin:
    codec: lines

pipeline:
  processors:
    # Validate and enrich
    - mapping: |
        root = this
        root.processed_at = now().ts_format("2006-01-02T15:04:05Z")
        root.pipeline_version = "1.0"

output:
  broker:
    pattern: fan_out
    outputs:
      # Archive
      - try:
          - file:
              path: "output/archive/${!timestamp_unix:2006/01/02}/${!this.event_id}.json"
          - file:
              path: "output/dlq/archive-failed-${!timestamp_unix}.json"

      # Real-time
      - try:
          - stdout:
              codec: lines
          - file:
              path: "output/dlq/realtime-failed-${!timestamp_unix}.json"
```

## Test Data

`test-data/events.json`:

```json
{"event_id":"evt-001","user_id":"user-123","action":"login"}
{"event_id":"evt-002","user_id":"user-456","action":"purchase","amount":99.99}
```

## Run It

```bash
cat test-data/events.json | expanso-edge run pipeline-production.yaml
```

This combines fan-out, circuit breakers, and DLQs for production resilience.

## Related: Templates 22, 23, 19

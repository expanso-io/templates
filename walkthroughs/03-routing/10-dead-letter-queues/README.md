# Walkthrough 10: Dead Letter Queues & Retries

**Track:** Routing & Distribution
**Difficulty:** Intermediate
**Time:** 30 minutes
**Prerequisites:** W02, W09

## Overview

Implement error handling with dead letter queues (DLQs) and retry logic for failed messages.

## The Pipeline

`pipeline-with-dlq.yaml`:

```yaml
input:
  stdin:
    codec: lines

pipeline:
  processors:
    - mapping: |
        root = this
        # Simulate processing that might fail
        root.validated = if this.exists("required_field") { true } else { throw("missing required_field") }

output:
  fallback:
    # Primary output - only succeeds if no errors
    - file:
        path: "output/processed.json"

    # DLQ - catches failures from primary
    - file:
        path: "output/dlq-${!timestamp_unix}.json"
        codec: lines
```

## Test Data

`test-data/events.json`:

```json
{"event_id":"evt-001","required_field":"value","data":"good"}
{"event_id":"evt-002","data":"bad"}
{"event_id":"evt-003","required_field":"value","data":"good"}
```

## Run It

```bash
cat test-data/events.json | expanso-edge run pipeline-with-dlq.yaml
```

Good events → `processed.json`, bad event → DLQ

## Related: Template 23 (`templates/patterns/dead-letter-queue.yaml`)

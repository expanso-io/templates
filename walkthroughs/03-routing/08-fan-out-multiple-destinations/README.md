# Walkthrough 08: Fan-Out to Multiple Destinations

**Track:** Routing & Distribution
**Difficulty:** Intermediate
**Time:** 30 minutes
**Prerequisites:** W01, W03

## Overview

Learn to route data to multiple destinations simultaneously using the fan-out pattern. Send events to S3 for archival, Elasticsearch for search, and stdout for monitoring.

## What You'll Build

A pipeline that duplicates each event to multiple outputs in parallel.

## The Pipeline

`pipeline-fan-out.yaml`:

```yaml
input:
  stdin:
    codec: lines

output:
  broker:
    pattern: fan_out
    outputs:
      - file:
          path: "output/archive-${!count:timestamp_unix}.json"
          codec: lines

      - file:
          path: "output/search-${!count:timestamp_unix}.json"
          codec: lines

      - stdout:
          codec: lines
```

## Test Data

`test-data/events.json`:

```json
{"event_id":"evt-001","action":"login","user_id":"user-123"}
{"event_id":"evt-002","action":"purchase","user_id":"user-456","amount":99.99}
```

## Run It

```bash
cat test-data/events.json | expanso-edge run pipeline-fan-out.yaml
```

Each event appears in all three outputs: two files + stdout.

## Related Templates

- Template 19: `templates/patterns/fan-out.yaml`

## Next Steps

- W09: Content-Based Routing
- W11: Cross-Region Data Distribution

# Walkthrough 09: Content-Based Routing

**Track:** Routing & Distribution
**Difficulty:** Intermediate
**Time:** 25 minutes
**Prerequisites:** W02 (Understanding Bloblang), W08 (Fan-Out)

## Overview

Route events to different destinations based on their content using the `switch` processor.

## The Pipeline

`pipeline-content-routing.yaml`:

```yaml
input:
  stdin:
    codec: lines

output:
  switch:
    cases:
      - check: this.severity == "critical"
        output:
          file:
            path: "output/critical-alerts.json"

      - check: this.amount.number() > 1000
        output:
          file:
            path: "output/high-value-transactions.json"

      - check: this.action == "login" || this.action == "logout"
        output:
          file:
            path: "output/auth-events.json"

      - output:
          file:
            path: "output/general-events.json"
```

## Test Data

`test-data/mixed-events.json`:

```json
{"event_id":"evt-001","severity":"critical","message":"Database down"}
{"event_id":"evt-002","action":"login","user_id":"user-123"}
{"event_id":"evt-003","action":"purchase","amount":1500}
{"event_id":"evt-004","action":"view","page":"/products"}
```

## Run & Verify

```bash
cat test-data/mixed-events.json | expanso-edge run pipeline-content-routing.yaml
ls output/
```

Each event routes to the appropriate file based on its content.

## Related: Template 20 (`templates/patterns/content-routing.yaml`)

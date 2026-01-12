# Walkthrough 11: Cross-Region Data Distribution

**Track:** Routing & Distribution
**Difficulty:** Advanced
**Time:** 30 minutes
**Prerequisites:** W08, W09, W16-W18 (Cloud Integrations)

## Overview

Route data to different cloud regions based on content, implementing multi-region data distribution.

## The Pipeline

`pipeline-multi-region.yaml`:

```yaml
input:
  stdin:
    codec: lines

output:
  switch:
    cases:
      - check: this.region == "us-east"
        output:
          file:
            path: "output/us-east/${!this.event_id}.json"

      - check: this.region == "eu-west"
        output:
          file:
            path: "output/eu-west/${!this.event_id}.json"

      - check: this.region == "ap-south"
        output:
          file:
            path: "output/ap-south/${!this.event_id}.json"

      - output:
          file:
            path: "output/default/${!this.event_id}.json"
```

## Test Data

`test-data/events.json`:

```json
{"event_id":"evt-001","region":"us-east","user_id":"user-123"}
{"event_id":"evt-002","region":"eu-west","user_id":"user-456"}
{"event_id":"evt-003","region":"ap-south","user_id":"user-789"}
```

## Run It

```bash
cat test-data/events.json | expanso-edge run pipeline-multi-region.yaml
ls output/*
```

## Related: Template 24 (`templates/patterns/multi-cloud-routing.yaml`)

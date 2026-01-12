# Walkthrough 17: GCP Integration Suite

**Track:** Cloud Integrations
**Difficulty:** Intermediate
**Time:** 45 minutes
**Prerequisites:** Walkthrough 03 (From Template to Cloud), GCP account with BigQuery access

## Overview

This walkthrough demonstrates Google Cloud Platform (GCP) integration patterns using Expanso. You'll learn to:
- Stream data to BigQuery for analytics
- Configure GCP credentials securely
- Work with BigQuery schemas and partitioning
- Implement common GCP data pipeline patterns

BigQuery is Google's serverless data warehouse, ideal for analytics, reporting, and machine learning.

## Learning Objectives

By the end of this walkthrough, you will:
- Configure GCP credentials for Expanso pipelines
- Stream events to BigQuery tables
- Understand BigQuery schema auto-discovery and management
- Implement batching for optimal performance and cost
- Handle errors and monitor pipeline health

## Architecture

```
Pattern 1: Local Data → Transform → BigQuery
Pattern 2: API/Webhook → Enrich → BigQuery (Real-time Analytics)
Pattern 3: Multi-table Fan-out (Events → multiple BQ tables)
```

## What You'll Build

Three pipelines demonstrating:
1. **Basic streaming to BigQuery** - Ingest events into a single table
2. **Schema validation and enrichment** - Add metadata before BigQuery write
3. **Multi-table routing** - Route different event types to different tables

## Prerequisites

- Expanso CLI and Edge runtime installed
- GCP account with BigQuery API enabled
- GCP credentials configured (see Setup section)
- BigQuery dataset created (or use auto-create)

## Setup: GCP Credentials

### Option 1: Application Default Credentials (ADC) - Recommended

Install gcloud CLI and authenticate:

```bash
# Install gcloud CLI
# https://cloud.google.com/sdk/docs/install

# Authenticate
gcloud auth application-default login

# Set default project
gcloud config set project YOUR_PROJECT_ID
```

This creates credentials that Expanso automatically uses.

### Option 2: Service Account JSON

Create a service account with BigQuery Data Editor role:

```bash
# Create service account
gcloud iam service-accounts create expanso-bigquery \\
  --display-name="Expanso BigQuery Writer"

# Grant BigQuery Data Editor role
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \\
  --member="serviceAccount:expanso-bigquery@YOUR_PROJECT_ID.iam.gserviceaccount.com" \\
  --role="roles/bigquery.dataEditor"

# Create and download key
gcloud iam service-accounts keys create ~/expanso-gcp-key.json \\
  --iam-account=expanso-bigquery@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Set environment variable
export GCP_CREDENTIALS_FILE=~/expanso-gcp-key.json
```

**Security Warning:** Never commit service account keys to version control. Use Workload Identity for GKE/Cloud Run.

### Verify Setup

```bash
# List BigQuery datasets
bq ls --project_id=YOUR_PROJECT_ID

# Or test with gcloud
gcloud auth list
```

## Step 1: Basic Streaming to BigQuery

Stream JSON events to a BigQuery table with auto-schema detection.

### Create BigQuery Dataset

```bash
export GCP_PROJECT="your-project-id"
export BQ_DATASET="expanso_demo"

# Create dataset
bq mk --dataset --location=US $GCP_PROJECT:$BQ_DATASET
```

### The Pipeline

Create `pipeline-stream-to-bigquery.yaml`:

```yaml
input:
  stdin:
    codec: lines

pipeline:
  processors:
    # Add ingestion metadata
    - mapping: |
        root = this
        root.ingestion_timestamp = now().ts_format("2006-01-02T15:04:05Z")
        root.pipeline_version = "1.0"

output:
  gcp_bigquery:
    project: "${GCP_PROJECT}"
    dataset: "${BQ_DATASET}"
    table: "${BQ_TABLE:events}"
    credentials_json: "${GCP_CREDENTIALS_FILE:}"
    auto_create: true
    batching:
      count: 100
      period: "10s"
```

### Test Data

Create `test-data/events.json`:

```json
{"event_id":"evt-001","user_id":"user-123","action":"login","timestamp":"2024-01-15T10:00:00Z"}
{"event_id":"evt-002","user_id":"user-456","action":"purchase","amount":99.99,"timestamp":"2024-01-15T10:15:00Z"}
{"event_id":"evt-003","user_id":"user-789","action":"logout","timestamp":"2024-01-15T10:30:00Z"}
```

### Run It

```bash
cd walkthroughs/05-integrations/17-gcp-integration-suite
export GCP_PROJECT="your-project-id"
export BQ_DATASET="expanso_demo"
export BQ_TABLE="events"

cat test-data/events.json | expanso-edge run pipeline-stream-to-bigquery.yaml
```

### Verify in BigQuery

Query the table:

```bash
bq query --use_legacy_sql=false \\
  "SELECT * FROM \`$GCP_PROJECT.$BQ_DATASET.$BQ_TABLE\` ORDER BY timestamp DESC LIMIT 10"
```

Or use BigQuery Console: https://console.cloud.google.com/bigquery

### Expected Result

Table `events` created with schema auto-detected:
- event_id: STRING
- user_id: STRING
- action: STRING
- timestamp: STRING
- amount: FLOAT (nullable, from evt-002)
- ingestion_timestamp: STRING
- pipeline_version: STRING

### Key Concepts

**Auto-create:** `auto_create: true` creates the table if it doesn't exist, inferring schema from the first batch.

**Batching:** Groups messages into batches of 100 or 10 seconds to reduce API calls and improve performance.

**Schema Evolution:** BigQuery supports adding new fields. Existing fields cannot change types.

## Step 2: Schema Validation and Type Handling

Control schema explicitly and handle type conversions before BigQuery write.

### Pre-create Table with Schema

```bash
bq mk --table \\
  --schema=event_id:STRING,user_id:STRING,action:STRING,timestamp:TIMESTAMP,amount:FLOAT64,metadata:JSON,ingestion_timestamp:TIMESTAMP \\
  $GCP_PROJECT:$BQ_DATASET.validated_events
```

### The Pipeline

Create `pipeline-validated-to-bigquery.yaml`:

```yaml
input:
  stdin:
    codec: lines

pipeline:
  processors:
    # Validate and transform
    - mapping: |
        # Ensure required fields exist
        root = if this.exists("event_id") && this.exists("user_id") && this.exists("action") {
          this
        } else {
          throw("Missing required fields")
        }

    # Type conversion and schema mapping
    - mapping: |
        root.event_id = this.event_id.string()
        root.user_id = this.user_id.string()
        root.action = this.action.string()

        # Convert timestamp to BigQuery TIMESTAMP format
        root.timestamp = this.timestamp.ts_parse("2006-01-02T15:04:05Z").ts_format("2006-01-02 15:04:05")

        # Handle optional fields
        root.amount = this.amount.number() catch null

        # Store extra fields as JSON
        root.metadata = this.without("event_id", "user_id", "action", "timestamp", "amount")

        # Add ingestion timestamp
        root.ingestion_timestamp = now().ts_format("2006-01-02 15:04:05")

output:
  gcp_bigquery:
    project: "${GCP_PROJECT}"
    dataset: "${BQ_DATASET}"
    table: "validated_events"
    credentials_json: "${GCP_CREDENTIALS_FILE:}"
    auto_create: false
    batching:
      count: 100
      period: "10s"
```

### Test Data

Create `test-data/mixed-events.json`:

```json
{"event_id":"evt-001","user_id":"user-123","action":"login","timestamp":"2024-01-15T10:00:00Z","device":"mobile"}
{"event_id":"evt-002","user_id":"user-456","action":"purchase","amount":99.99,"timestamp":"2024-01-15T10:15:00Z","cart_items":3}
{"user_id":"user-789","action":"logout"}
{"event_id":"evt-004","user_id":"user-111","action":"view","timestamp":"2024-01-15T10:45:00Z","page":"/products"}
```

### Run It

```bash
cat test-data/mixed-events.json | expanso-edge run pipeline-validated-to-bigquery.yaml 2>&1
```

### Expected Behavior

- **Valid events (evt-001, evt-002, evt-004):** Written to BigQuery
- **Invalid event (missing event_id):** Rejected with error logged
- **Extra fields:** Stored in `metadata` JSON column

## Step 3: Multi-table Routing

Route different event types to different BigQuery tables.

### Create Tables

```bash
# User events table
bq mk --table \\
  --schema=event_id:STRING,user_id:STRING,action:STRING,timestamp:TIMESTAMP,ingestion_timestamp:TIMESTAMP \\
  $GCP_PROJECT:$BQ_DATASET.user_events

# Transaction events table
bq mk --table \\
  --schema=event_id:STRING,user_id:STRING,action:STRING,amount:FLOAT64,currency:STRING,timestamp:TIMESTAMP,ingestion_timestamp:TIMESTAMP \\
  $GCP_PROJECT:$BQ_DATASET.transaction_events
```

### The Pipeline

Create `pipeline-multi-table-routing.yaml`:

```yaml
input:
  stdin:
    codec: lines

pipeline:
  processors:
    # Add metadata and determine routing
    - mapping: |
        root = this
        root.ingestion_timestamp = now().ts_format("2006-01-02 15:04:05")

        # Convert timestamp
        root.timestamp = this.timestamp.ts_parse("2006-01-02T15:04:05Z").ts_format("2006-01-02 15:04:05")

        # Determine table based on action
        root.target_table = if ["purchase", "refund", "charge"].contains(this.action) {
          "transaction_events"
        } else {
          "user_events"
        }

output:
  switch:
    cases:
      # Route transactions to transaction_events
      - check: this.target_table == "transaction_events"
        output:
          gcp_bigquery:
            project: "${GCP_PROJECT}"
            dataset: "${BQ_DATASET}"
            table: "transaction_events"
            credentials_json: "${GCP_CREDENTIALS_FILE:}"
            batching:
              count: 100
              period: "10s"

      # Route user events to user_events
      - check: this.target_table == "user_events"
        output:
          gcp_bigquery:
            project: "${GCP_PROJECT}"
            dataset: "${BQ_DATASET}"
            table: "user_events"
            credentials_json: "${GCP_CREDENTIALS_FILE:}"
            batching:
              count: 100
              period: "10s"
```

### Test Data

Create `test-data/multi-type-events.json`:

```json
{"event_id":"evt-001","user_id":"user-123","action":"login","timestamp":"2024-01-15T10:00:00Z"}
{"event_id":"evt-002","user_id":"user-456","action":"purchase","amount":99.99,"currency":"USD","timestamp":"2024-01-15T10:15:00Z"}
{"event_id":"evt-003","user_id":"user-789","action":"view","timestamp":"2024-01-15T10:30:00Z"}
{"event_id":"evt-004","user_id":"user-456","action":"refund","amount":25.00,"currency":"USD","timestamp":"2024-01-15T10:45:00Z"}
```

### Run It

```bash
cat test-data/multi-type-events.json | expanso-edge run pipeline-multi-table-routing.yaml
```

### Verify

```bash
# Check user_events (should have evt-001, evt-003)
bq query --use_legacy_sql=false \\
  "SELECT * FROM \`$GCP_PROJECT.$BQ_DATASET.user_events\`"

# Check transaction_events (should have evt-002, evt-004)
bq query --use_legacy_sql=false \\
  "SELECT * FROM \`$GCP_PROJECT.$BQ_DATASET.transaction_events\`"
```

## Production Considerations

### 1. Cost Optimization

- **Batching:** Larger batches reduce API calls (BigQuery charges per-query)
- **Partitioning:** Use partitioned tables for large datasets
- **Streaming vs Batch:** Batch loads (via GCS) are cheaper than streaming for high volumes

### 2. Partitioned Tables

Create a date-partitioned table:

```bash
bq mk --table \\
  --time_partitioning_field=timestamp \\
  --time_partitioning_type=DAY \\
  --schema=event_id:STRING,user_id:STRING,timestamp:TIMESTAMP \\
  $GCP_PROJECT:$BQ_DATASET.partitioned_events
```

Benefits: Faster queries, automatic data retention policies, lower costs.

### 3. Error Handling

Route failed writes to a dead-letter table:

```yaml
output:
  fallback:
    - gcp_bigquery:
        project: "${GCP_PROJECT}"
        dataset: "${BQ_DATASET}"
        table: "events"
    - gcp_bigquery:
        project: "${GCP_PROJECT}"
        dataset: "${BQ_DATASET}"
        table: "failed_events"
```

### 4. Monitoring

Track ingestion metrics:

```yaml
processors:
  - mapping: |
      root = this
      meta batch_size = count_batch()
      meta ingestion_latency_ms = (now().ts_unix_nano() - this.timestamp.ts_parse("2006-01-02T15:04:05Z").ts_unix_nano()) / 1000000
```

Export to Cloud Monitoring/Logging.

## Related Templates

- **Template 8:** `templates/outputs/to-bigquery.yaml` - BigQuery writer template
- **Template 20:** `templates/patterns/content-routing.yaml` - Content-based routing
- **Template 19:** `templates/patterns/fan-out.yaml` - Multi-output patterns

## Next Steps

- **Walkthrough 18:** Azure Integration Suite - Blob Storage and Event Hubs
- **Walkthrough 16:** AWS Integration Suite - S3 integration patterns
- **Walkthrough 11:** Cross-Region Data Distribution - Multi-cloud routing

## Summary

You've learned:
- How to configure GCP credentials securely
- How to stream data to BigQuery with auto-schema
- How to handle schema validation and type conversion
- How to route events to multiple BigQuery tables
- Production best practices for cost and performance

BigQuery integration enables real-time analytics, dashboards, and machine learning on streaming data.

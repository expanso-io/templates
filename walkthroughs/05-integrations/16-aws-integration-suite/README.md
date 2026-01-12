# Walkthrough 16: AWS Integration Suite

**Track:** Cloud Integrations
**Difficulty:** Intermediate
**Time:** 45 minutes
**Prerequisites:** Walkthrough 03 (From Template to Cloud), AWS account with S3 access

## Overview

This walkthrough demonstrates end-to-end AWS integration patterns using Expanso. You'll learn to:
- Read data from S3 buckets
- Write data to S3 with partitioning strategies
- Configure AWS credentials securely
- Implement common AWS data pipeline patterns
- Test locally before deploying to cloud

AWS S3 is a foundational service for data lakes, archives, and inter-service data transfer.

## Learning Objectives

By the end of this walkthrough, you will:
- Configure AWS credentials for Expanso pipelines
- Read objects from S3 with prefix filtering
- Write to S3 with date-based partitioning
- Implement S3-to-S3 transformation pipelines
- Understand batching and performance optimization for S3

## Architecture

```
Pattern 1: S3 Reader → Transform → Local Output
Pattern 2: Local Input → Transform → S3 Writer
Pattern 3: S3 Reader → Transform → S3 Writer (S3-to-S3 ETL)
```

## What You'll Build

Three pipelines demonstrating:
1. **S3 to Local** - Read from S3, transform, output locally
2. **Local to S3** - Read locally, transform, write to S3 with partitioning
3. **S3 to S3 ETL** - Read from raw bucket, transform, write to processed bucket

## Prerequisites

- Expanso CLI and Edge runtime installed
- AWS account with S3 access
- AWS credentials configured (see Setup section)
- Two S3 buckets for testing (or use prefixes in one bucket)

## Setup: AWS Credentials

### Option 1: AWS CLI Configuration (Recommended)

Install AWS CLI and configure credentials:

```bash
# Install AWS CLI (if not installed)
# macOS: brew install awscli
# Linux: pip install awscli
# Windows: https://aws.amazon.com/cli/

# Configure credentials
aws configure
# Enter: Access Key ID, Secret Access Key, Region, Output format
```

This creates `~/.aws/credentials` and `~/.aws/config` files that Expanso will automatically use.

### Option 2: Environment Variables

Export credentials as environment variables:

```bash
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="wJalr..."
export AWS_REGION="us-east-1"
```

**Security Warning:** Never commit credentials to version control. Use IAM roles in production.

### Option 3: IAM Roles (Production)

When running on EC2, ECS, or Lambda, use IAM roles instead of credentials. Expanso automatically uses the instance profile.

### Verify Setup

Test AWS access:

```bash
aws s3 ls --no-cli-pager
# Should list your S3 buckets
```

## Step 1: Reading from S3

Read JSON log files from an S3 bucket and process them locally.

### Create Test Data in S3

First, create sample data in your S3 bucket:

```bash
# Create local test file
cat > sample-log.json <<EOF
{"timestamp":"2024-01-15T10:00:00Z","level":"INFO","service":"api","message":"Request processed","duration_ms":45}
{"timestamp":"2024-01-15T10:01:00Z","level":"WARN","service":"api","message":"Slow query detected","duration_ms":1200}
{"timestamp":"2024-01-15T10:02:00Z","level":"ERROR","service":"db","message":"Connection timeout","duration_ms":5000}
EOF

# Upload to S3 (replace with your bucket name)
export S3_BUCKET="your-test-bucket"
aws s3 cp sample-log.json s3://$S3_BUCKET/raw-logs/2024/01/15/log-001.json --no-cli-pager
```

### The Pipeline

Create `pipeline-s3-to-local.yaml`:

```yaml
input:
  aws_s3:
    bucket: "${S3_BUCKET}"
    prefix: "${S3_PREFIX:raw-logs/}"
    region: "${AWS_REGION:us-east-1}"
    credentials:
      profile: "${AWS_PROFILE:}"
      id: "${AWS_ACCESS_KEY_ID:}"
      secret: "${AWS_SECRET_ACCESS_KEY:}"
    scanner:
      to_the_end: {}

pipeline:
  processors:
    # Parse JSON
    - mapping: |
        root = this.parse_json()

    # Transform and enrich
    - mapping: |
        root = this
        root.severity_score = match this.level {
          "ERROR" => 3,
          "WARN" => 2,
          "INFO" => 1,
          _ => 0
        }
        root.is_slow = this.duration_ms.number() > 1000
        root.processed_at = now().ts_format("2006-01-02T15:04:05Z")

output:
  stdout:
    codec: lines
```

### Run It

```bash
cd walkthroughs/05-integrations/16-aws-integration-suite
export S3_BUCKET="your-test-bucket"
export S3_PREFIX="raw-logs/"

expanso-edge run pipeline-s3-to-local.yaml
```

### Expected Output

Transformed log entries with added fields:

```json
{"timestamp":"2024-01-15T10:00:00Z","level":"INFO","service":"api","message":"Request processed","duration_ms":45,"severity_score":1,"is_slow":false,"processed_at":"2026-01-12T12:00:00Z"}
{"timestamp":"2024-01-15T10:01:00Z","level":"WARN","service":"api","message":"Slow query detected","duration_ms":1200,"severity_score":2,"is_slow":true,"processed_at":"2026-01-12T12:00:00Z"}
{"timestamp":"2024-01-15T10:02:00Z","level":"ERROR","service":"db","message":"Connection timeout","duration_ms":5000,"severity_score":3,"is_slow":true,"processed_at":"2026-01-12T12:00:00Z"}
```

### Key Concepts

**Prefix Filtering:** The `prefix` parameter reads only objects matching the prefix (e.g., `raw-logs/`).

**Scanner:** The `to_the_end` scanner reads all existing objects in the bucket. For continuous polling, use `sqs_bucket_notifications` or S3 event notifications.

**Credentials Chain:** Expanso tries credentials in this order: environment variables → AWS profile → IAM role.

## Step 2: Writing to S3 with Partitioning

Write processed data to S3 with date-based partitioning for efficient querying.

### The Pipeline

Create `pipeline-local-to-s3.yaml`:

```yaml
input:
  stdin:
    codec: lines

pipeline:
  processors:
    # Add partition metadata
    - mapping: |
        root = this
        root.partition_date = now().ts_format("2006-01-02")
        root.write_timestamp = now().ts_unix()

output:
  aws_s3:
    bucket: "${S3_BUCKET}"
    # Date-based partitioning: processed/YYYY/MM/DD/data-TIMESTAMP.json
    path: "${S3_PREFIX:processed/}${!timestamp_unix:2006}/${!timestamp_unix:01}/${!timestamp_unix:02}/data-${!count:timestamp_unix_nano}.json"
    region: "${AWS_REGION:us-east-1}"
    credentials:
      profile: "${AWS_PROFILE:}"
      id: "${AWS_ACCESS_KEY_ID:}"
      secret: "${AWS_SECRET_ACCESS_KEY:}"
    content_type: "application/json"
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
export S3_BUCKET="your-test-bucket"
export S3_PREFIX="processed/"

cat test-data/events.json | expanso-edge run pipeline-local-to-s3.yaml
```

### Verify

Check S3 for partitioned output:

```bash
aws s3 ls s3://$S3_BUCKET/processed/ --recursive --no-cli-pager
# Should show: processed/2026/01/12/data-1736684400123456789.json
```

Download and inspect:

```bash
aws s3 cp s3://$S3_BUCKET/processed/2026/01/12/data-*.json - --no-cli-pager
```

### Key Concepts

**Path Interpolation:** `${!timestamp_unix:2006}` uses the current timestamp formatted as year. This creates dynamic paths like `processed/2026/01/12/`.

**Batching:** The `batching` section buffers up to 100 messages or 10 seconds before writing, reducing S3 API calls and costs.

**Content Type:** Setting `content_type: application/json` helps S3 console and tools display files correctly.

## Step 3: S3-to-S3 ETL Pipeline

Read from a "raw" prefix, transform data, and write to a "processed" prefix. This is a common data lake pattern.

### The Pipeline

Create `pipeline-s3-to-s3-etl.yaml`:

```yaml
input:
  aws_s3:
    bucket: "${SOURCE_BUCKET:${S3_BUCKET}}"
    prefix: "${SOURCE_PREFIX:raw-logs/}"
    region: "${AWS_REGION:us-east-1}"
    credentials:
      profile: "${AWS_PROFILE:}"
      id: "${AWS_ACCESS_KEY_ID:}"
      secret: "${AWS_SECRET_ACCESS_KEY:}"
    delete_objects: ${DELETE_AFTER_PROCESSING:false}
    scanner:
      to_the_end: {}

pipeline:
  processors:
    # Parse JSON
    - mapping: |
        root = this.parse_json()

    # Data quality: filter and validate
    - mapping: |
        # Only process valid log levels
        root = if ["INFO", "WARN", "ERROR", "DEBUG"].contains(this.level) {
          this
        } else {
          deleted()
        }

    # Transform and enrich
    - mapping: |
        root = this

        # Severity scoring
        root.severity_score = match this.level {
          "ERROR" => 3,
          "WARN" => 2,
          "INFO" => 1,
          "DEBUG" => 0,
          _ => 0
        }

        # Performance classification
        root.performance_class = match {
          this.duration_ms.number() < 100 => "fast",
          this.duration_ms.number() < 1000 => "normal",
          _ => "slow"
        }

        # Add processing metadata
        root.processed_at = now().ts_format("2006-01-02T15:04:05Z")
        root.processing_pipeline = "s3-to-s3-etl"
        root.source_file = meta("s3_key")

output:
  aws_s3:
    bucket: "${TARGET_BUCKET:${S3_BUCKET}}"
    path: "${TARGET_PREFIX:processed/}${!timestamp_unix:2006}/${!timestamp_unix:01}/${!timestamp_unix:02}/${!this.level}-${!count:timestamp_unix_nano}.json"
    region: "${AWS_REGION:us-east-1}"
    credentials:
      profile: "${AWS_PROFILE:}"
      id: "${AWS_ACCESS_KEY_ID:}"
      secret: "${AWS_SECRET_ACCESS_KEY:}"
    content_type: "application/json"
    batching:
      count: 100
      period: "10s"
```

### Run It

```bash
export S3_BUCKET="your-test-bucket"
export SOURCE_PREFIX="raw-logs/"
export TARGET_PREFIX="processed/"

expanso-edge run pipeline-s3-to-s3-etl.yaml
```

### Verify

```bash
aws s3 ls s3://$S3_BUCKET/processed/ --recursive --no-cli-pager
# Should show files like: processed/2026/01/12/ERROR-1736684400123456789.json
```

### Key Concepts

**Delete After Processing:** Set `delete_objects: true` to remove source objects after successful processing (use cautiously).

**Dynamic Output Paths:** Including `${!this.level}` in the path creates separate files for each log level (INFO, WARN, ERROR).

**Metadata Access:** `meta("s3_key")` accesses the source S3 object key for audit trails.

## Production Considerations

### 1. IAM Permissions

Minimum IAM policy for S3 reader:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-bucket",
        "arn:aws:s3:::your-bucket/*"
      ]
    }
  ]
}
```

For writer, add `s3:PutObject`. For delete, add `s3:DeleteObject`.

### 2. S3 Event Notifications

Instead of polling, use S3 event notifications with SQS for real-time processing:

```yaml
input:
  aws_s3:
    bucket: "${S3_BUCKET}"
    sqs:
      url: "${SQS_QUEUE_URL}"
      max_messages: 10
```

Create SQS queue and configure S3 to send event notifications to it.

### 3. Error Handling

Add a dead-letter S3 prefix for failed records:

```yaml
output:
  switch:
    cases:
      - check: errored()
        output:
          aws_s3:
            bucket: "${S3_BUCKET}"
            path: "errors/${!timestamp_unix:2006/01/02}/error-${!count:timestamp_unix_nano}.json"
      - output:
          aws_s3:
            bucket: "${S3_BUCKET}"
            path: "processed/${!timestamp_unix:2006/01/02}/data-${!count:timestamp_unix_nano}.json"
```

### 4. Cost Optimization

- **Batching:** Increase batch size to reduce API calls
- **Partitioning:** Use date/time partitioning for efficient querying (reduces data scanned)
- **Storage Classes:** Use S3 lifecycle policies to move old data to cheaper storage (Glacier, Deep Archive)
- **Compression:** Enable gzip compression for text data

```yaml
output:
  aws_s3:
    bucket: "${S3_BUCKET}"
    path: "data/${!timestamp_unix:2006/01/02}/data.json.gz"
    content_encoding: "gzip"
    batching:
      count: 1000
      period: "1m"
```

### 5. Monitoring

Track S3 metrics:

```yaml
pipeline:
  processors:
    - mapping: |
        root = this
        meta object_size = content().length()
        meta processing_time = now().ts_unix()
```

Export metrics to CloudWatch or your monitoring system.

## Common Patterns

### Pattern: Incremental Processing

Process only new files added after a certain timestamp:

```yaml
input:
  aws_s3:
    bucket: "${S3_BUCKET}"
    prefix: "logs/"
    scanner:
      to_the_end: {}
    # Filter by last modified time (requires custom logic)
```

### Pattern: Multi-Region Replication

Read from one region, write to another:

```yaml
input:
  aws_s3:
    bucket: "source-bucket"
    region: "us-east-1"

output:
  aws_s3:
    bucket: "replica-bucket"
    region: "eu-west-1"
```

### Pattern: CSV to Parquet (via S3)

Read CSV from S3, convert to Parquet (requires external tool), write back:

```yaml
# Read CSV from S3, convert to JSON
input:
  aws_s3:
    bucket: "${S3_BUCKET}"
    codec: csv

# Write as JSON (then use Glue/Spark for Parquet conversion)
output:
  aws_s3:
    bucket: "${S3_BUCKET}"
    path: "json-output/${!timestamp_unix:2006/01/02}/data.json"
```

## Troubleshooting

**Problem:** "AccessDenied" or "403 Forbidden" errors

**Solution:** Verify IAM permissions, bucket policies, and credential configuration. Check `aws s3 ls` works from CLI.

**Problem:** Pipeline reads old objects repeatedly

**Solution:** Use `delete_objects: true` or implement state tracking with SQS notifications instead of `to_the_end` scanner.

**Problem:** Too many small files in S3

**Solution:** Increase batch size and period to write fewer, larger files:

```yaml
batching:
  count: 10000
  period: "5m"
```

**Problem:** High S3 costs

**Solution:** Enable batching, use partitioning for efficient queries, configure lifecycle policies to archive old data.

## Related Templates

- **Template 4:** `templates/inputs/s3-reader.yaml` - S3 reader template
- **Template 7:** `templates/outputs/to-s3.yaml` - S3 writer with partitioning
- **Template 24:** `templates/patterns/multi-cloud-routing.yaml` - Route to S3, GCS, or Azure

## Next Steps

- **Walkthrough 17:** GCP Integration Suite - BigQuery and Cloud Storage
- **Walkthrough 18:** Azure Integration Suite - Blob Storage and Event Hubs
- **Walkthrough 11:** Cross-Region Data Distribution - Multi-region patterns

## Summary

You've learned:
- How to configure AWS credentials securely
- How to read from S3 with prefix filtering
- How to write to S3 with date-based partitioning
- How to build S3-to-S3 ETL pipelines
- Production best practices for cost, performance, and reliability

AWS S3 integration is foundational for building scalable data pipelines, data lakes, and cloud-native architectures.

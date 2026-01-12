# Walkthrough 18: Azure Integration Suite

**Track:** Cloud Integrations
**Difficulty:** Intermediate
**Time:** 45 minutes
**Prerequisites:** Walkthrough 03 (From Template to Cloud), Azure account

## Overview

This walkthrough demonstrates Microsoft Azure integration patterns using Expanso. You'll learn to:
- Write data to Azure Blob Storage
- Stream events to Azure Event Hubs
- Configure Azure credentials securely
- Implement common Azure data pipeline patterns

Azure Blob Storage and Event Hubs are foundational for data lakes and real-time streaming architectures.

## Learning Objectives

By the end of this walkthrough, you will:
- Configure Azure credentials for Expanso pipelines
- Write data to Blob Storage with date-based paths
- Stream events to Event Hubs with partitioning
- Implement batching for performance and cost optimization
- Understand Azure security best practices

## Architecture

```
Pattern 1: Local Data → Transform → Azure Blob Storage
Pattern 2: API/Events → Enrich → Azure Event Hubs (Real-time Streaming)
Pattern 3: Blob Storage → Event Hubs (Archive + Stream)
```

## What You'll Build

Three pipelines demonstrating:
1. **Write to Blob Storage** - Store processed data with partitioning
2. **Stream to Event Hubs** - Real-time event streaming with partitioning
3. **Combined pattern** - Archive to Blob + Stream to Event Hubs

## Prerequisites

- Expanso CLI and Edge runtime installed
- Azure account with Storage Account and Event Hubs namespace
- Azure credentials configured (see Setup section)

## Setup: Azure Resources

### Create Storage Account

```bash
# Set variables
export RESOURCE_GROUP="expanso-demo-rg"
export LOCATION="eastus"
export STORAGE_ACCOUNT="expansodemo$(date +%s | tail -c 10)"
export CONTAINER_NAME="data"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create storage account
az storage account create \\
  --name $STORAGE_ACCOUNT \\
  --resource-group $RESOURCE_GROUP \\
  --location $LOCATION \\
  --sku Standard_LRS

# Create container
az storage container create \\
  --name $CONTAINER_NAME \\
  --account-name $STORAGE_ACCOUNT
```

### Create Event Hubs Namespace

```bash
export EVENTHUBS_NAMESPACE="expanso-demo-eh"
export EVENTHUB_NAME="events"

# Create Event Hubs namespace
az eventhubs namespace create \\
  --name $EVENTHUBS_NAMESPACE \\
  --resource-group $RESOURCE_GROUP \\
  --location $LOCATION

# Create Event Hub
az eventhubs eventhub create \\
  --name $EVENTHUB_NAME \\
  --namespace-name $EVENTHUBS_NAMESPACE \\
  --resource-group $RESOURCE_GROUP \\
  --partition-count 4
```

### Get Credentials

```bash
# Get storage account key
export AZURE_STORAGE_ACCESS_KEY=$(az storage account keys list \\
  --account-name $STORAGE_ACCOUNT \\
  --resource-group $RESOURCE_GROUP \\
  --query '[0].value' -o tsv)

# Get Event Hubs connection string
export EVENTHUBS_CONNECTION_STRING=$(az eventhubs namespace authorization-rule keys list \\
  --resource-group $RESOURCE_GROUP \\
  --namespace-name $EVENTHUBS_NAMESPACE \\
  --name RootManageSharedAccessKey \\
  --query primaryConnectionString -o tsv)

echo "AZURE_STORAGE_ACCOUNT=$STORAGE_ACCOUNT"
echo "AZURE_STORAGE_ACCESS_KEY=$AZURE_STORAGE_ACCESS_KEY"
echo "AZURE_CONTAINER=$CONTAINER_NAME"
echo "EVENTHUBS_CONNECTION_STRING=$EVENTHUBS_CONNECTION_STRING"
```

**Security Warning:** Never commit these credentials. Use Azure Managed Identity in production.

## Step 1: Write to Azure Blob Storage

Stream processed data to Blob Storage with date-based partitioning.

### The Pipeline

Create `pipeline-to-blob-storage.yaml`:

```yaml
input:
  stdin:
    codec: lines

pipeline:
  processors:
    # Add processing metadata
    - mapping: |
        root = this
        root.processed_at = now().ts_format("2006-01-02T15:04:05Z")
        root.storage_tier = "standard"

output:
  azure_blob_storage:
    storage_account: "${AZURE_STORAGE_ACCOUNT}"
    storage_access_key: "${AZURE_STORAGE_ACCESS_KEY}"
    container: "${AZURE_CONTAINER}"
    # Date-based path: data/YYYY/MM/DD/events-TIMESTAMP.json
    path: "${BLOB_PREFIX:data/}${!timestamp_unix:2006}/${!timestamp_unix:01}/${!timestamp_unix:02}/events-${!count:timestamp_unix_nano}.json"
    blob_type: BLOCK
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
cd walkthroughs/05-integrations/18-azure-integration-suite

cat test-data/events.json | expanso-edge run pipeline-to-blob-storage.yaml
```

### Verify

```bash
# List blobs
az storage blob list \\
  --account-name $STORAGE_ACCOUNT \\
  --container-name $CONTAINER_NAME \\
  --output table

# Download a blob
az storage blob download \\
  --account-name $STORAGE_ACCOUNT \\
  --container-name $CONTAINER_NAME \\
  --name "data/2026/01/12/events-1736684400123456789.json" \\
  --file downloaded-blob.json
```

### Key Concepts

**Path Interpolation:** `${!timestamp_unix:2006}` creates year/month/day directories dynamically.

**Blob Types:** BLOCK blobs support large files and parallel uploads. APPEND blobs support append-only operations.

**Batching:** Groups messages to reduce API calls and improve throughput.

## Step 2: Stream to Azure Event Hubs

Stream events to Event Hubs for real-time processing by consumers.

### The Pipeline

Create `pipeline-to-event-hubs.yaml`:

```yaml
input:
  stdin:
    codec: lines

pipeline:
  processors:
    # Add event metadata
    - mapping: |
        root = this
        root.ingestion_timestamp = now().ts_format("2006-01-02T15:04:05Z")
        root.pipeline_version = "1.0"

        # Set partition key for consistent routing
        root.partition_key = this.user_id

output:
  azure_event_hubs:
    connection_string: "${EVENTHUBS_CONNECTION_STRING}"
    eventhub: "${EVENTHUB_NAME}"
    partition_key: ${! json("partition_key") }
    batching:
      count: 100
      period: "10s"
      byte_size: 1000000
```

### Run It

```bash
export EVENTHUB_NAME="events"

cat test-data/events.json | expanso-edge run pipeline-to-event-hubs.yaml
```

### Verify

Use Azure Portal or CLI to check Event Hub metrics:

```bash
# Get Event Hub metrics
az eventhubs eventhub show \\
  --resource-group $RESOURCE_GROUP \\
  --namespace-name $EVENTHUBS_NAMESPACE \\
  --name $EVENTHUB_NAME \\
  --query status
```

Or consume events:

```bash
# Read from Event Hub (requires consumer group setup)
# Use Azure Stream Analytics, Functions, or custom consumer
```

### Key Concepts

**Partition Key:** Events with the same partition key go to the same partition, preserving order for that key.

**Batching:** Reduces cost and latency. Event Hubs supports up to 1MB per batch.

**Connection String:** Contains namespace, Event Hub name, and credentials in one string.

## Step 3: Combined Pattern (Archive + Stream)

Write to Blob Storage for archival AND stream to Event Hubs for real-time processing.

### The Pipeline

Create `pipeline-archive-and-stream.yaml`:

```yaml
input:
  stdin:
    codec: lines

pipeline:
  processors:
    # Enrich with metadata
    - mapping: |
        root = this
        root.processed_at = now().ts_format("2006-01-02T15:04:05Z")
        root.partition_key = this.user_id catch "default"

# Fan-out to both outputs
output:
  broker:
    pattern: fan_out
    outputs:
      # Output 1: Archive to Blob Storage
      - azure_blob_storage:
          storage_account: "${AZURE_STORAGE_ACCOUNT}"
          storage_access_key: "${AZURE_STORAGE_ACCESS_KEY}"
          container: "${AZURE_CONTAINER}"
          path: "archive/${!timestamp_unix:2006}/${!timestamp_unix:01}/${!timestamp_unix:02}/${!this.event_id}.json"
          batching:
            count: 100
            period: "10s"

      # Output 2: Stream to Event Hubs
      - azure_event_hubs:
          connection_string: "${EVENTHUBS_CONNECTION_STRING}"
          eventhub: "${EVENTHUB_NAME}"
          partition_key: ${! json("partition_key") }
          batching:
            count: 100
            period: "10s"
```

### Run It

```bash
cat test-data/events.json | expanso-edge run pipeline-archive-and-stream.yaml
```

### Verify

Check both Blob Storage and Event Hubs:

```bash
# Check Blob Storage
az storage blob list \\
  --account-name $STORAGE_ACCOUNT \\
  --container-name $CONTAINER_NAME \\
  --prefix "archive/" \\
  --output table

# Check Event Hubs metrics
az monitor metrics list \\
  --resource "/subscriptions/SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.EventHub/namespaces/$EVENTHUBS_NAMESPACE/eventhubs/$EVENTHUB_NAME" \\
  --metric IncomingMessages \\
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \\
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ)
```

### Key Concepts

**Fan-out Pattern:** The `broker` output with `pattern: fan_out` sends each message to multiple destinations.

**Dual Write:** Common pattern for "hot path" (Event Hubs for real-time) and "cold path" (Blob Storage for archive/analysis).

## Production Considerations

### 1. Managed Identity (Recommended)

Use Azure Managed Identity instead of access keys:

```yaml
output:
  azure_blob_storage:
    storage_account: "${AZURE_STORAGE_ACCOUNT}"
    # Omit storage_access_key - uses Managed Identity
    container: "${AZURE_CONTAINER}"
```

Assign identity roles:

```bash
# Assign Storage Blob Data Contributor role
az role assignment create \\
  --role "Storage Blob Data Contributor" \\
  --assignee-object-id $MANAGED_IDENTITY_OBJECT_ID \\
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT"
```

### 2. Cost Optimization

- **Batching:** Increase batch size to reduce transaction costs
- **Storage Tiers:** Use Cool or Archive tiers for infrequently accessed data
- **Lifecycle Policies:** Automatically move old data to cheaper tiers

```bash
# Set lifecycle policy
az storage account management-policy create \\
  --account-name $STORAGE_ACCOUNT \\
  --policy @lifecycle-policy.json
```

### 3. Error Handling

Add fallback for failed writes:

```yaml
output:
  fallback:
    - azure_blob_storage:
        storage_account: "${AZURE_STORAGE_ACCOUNT}"
        container: "data"
    - azure_blob_storage:
        storage_account: "${AZURE_STORAGE_ACCOUNT}"
        container: "failed-events"
```

### 4. Monitoring

Enable Azure Monitor and diagnostic logs:

```bash
# Enable diagnostic logs
az monitor diagnostic-settings create \\
  --name expanso-blob-logs \\
  --resource "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT" \\
  --logs '[{"category": "StorageWrite", "enabled": true}]' \\
  --workspace $LOG_ANALYTICS_WORKSPACE_ID
```

## Related Templates

- **Template 13:** `templates/outputs/to-azure-blob.yaml` - Blob Storage writer
- **Template 14:** `templates/outputs/to-azure-eventhubs.yaml` - Event Hubs writer
- **Template 19:** `templates/patterns/fan-out.yaml` - Multi-output pattern

## Next Steps

- **Walkthrough 16:** AWS Integration Suite - S3 and cloud patterns
- **Walkthrough 17:** GCP Integration Suite - BigQuery integration
- **Walkthrough 11:** Cross-Region Data Distribution - Multi-cloud routing

## Summary

You've learned:
- How to configure Azure credentials securely
- How to write data to Blob Storage with partitioning
- How to stream events to Event Hubs with partition keys
- How to implement archive + stream patterns
- Production best practices for security and cost

Azure integration enables scalable data lakes, real-time analytics, and event-driven architectures.

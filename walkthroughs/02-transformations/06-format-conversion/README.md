# Walkthrough 06: Format Conversion Pipeline

**Track:** Data Transformations
**Difficulty:** Beginner
**Time:** 20 minutes
**Prerequisites:** Walkthrough 01 (Your First Pipeline), Walkthrough 02 (Understanding Bloblang)

## Overview

This walkthrough teaches you how to convert between different data formats using Expanso. You'll learn to:
- Parse CSV files and convert them to JSON
- Validate JSON against a schema
- Combine format conversion with validation
- Handle type conversions and data quality

Format conversion is essential when integrating systems that use different data formats or enforcing data quality standards.

## Learning Objectives

By the end of this walkthrough, you will:
- Understand how the `csv` processor converts CSV to JSON
- Use JSON Schema validation to enforce data quality
- Apply type conversions during format conversion
- Combine multiple processors for data quality pipelines

## Architecture

```
CSV Input → Parse CSV → Type Conversion → Schema Validation → JSON Output
```

## What You'll Build

Three pipelines demonstrating:
1. **Basic CSV to JSON conversion** with type handling
2. **JSON Schema validation** for data quality
3. **Combined pipeline** with conversion + validation

## Prerequisites

- Expanso CLI installed (`expanso-cli`)
- Expanso Edge runtime installed (`expanso-edge`)
- Basic understanding of CSV and JSON formats

## Step 1: CSV to JSON Conversion

CSV (Comma-Separated Values) is common for data exports, spreadsheets, and legacy systems. Expanso's `csv` codec automatically parses CSV into JSON objects.

### The Pipeline

Create `pipeline-csv-to-json.yaml`:

```yaml
input:
  stdin:
    codec: csv
    csv:
      delimiter: ","
      lazy_quotes: false

pipeline:
  processors:
    - mapping: |
        # CSV processor outputs JSON with string values
        # Apply type conversions for proper data types

        root.id = this.id
        root.user_id = this.user_id.number() catch 0
        root.email = this.email
        root.amount = this.amount.number() catch 0.0
        root.enabled = this.enabled.bool() catch false
        root.created_at = this.created_at

        # Add metadata
        root.converted_at = now().ts_format("2006-01-02T15:04:05Z")
        root.source_format = "csv"

output:
  stdout:
    codec: lines
```

### Test Data

Create `test-data/users.csv`:

```csv
id,user_id,email,amount,enabled,created_at
evt-001,12345,alice@example.com,99.50,true,2024-01-15T10:00:00Z
evt-002,67890,bob@example.com,150.25,false,2024-01-15T11:30:00Z
evt-003,11223,charlie@example.com,75.00,true,2024-01-15T12:45:00Z
```

### Run It

```bash
cd walkthroughs/02-transformations/06-format-conversion
cat test-data/users.csv | expanso-edge run pipeline-csv-to-json.yaml
```

### Expected Output

Each CSV row becomes a JSON object with proper types:

```json
{"id":"evt-001","user_id":12345,"email":"alice@example.com","amount":99.5,"enabled":true,"created_at":"2024-01-15T10:00:00Z","converted_at":"2026-01-12T10:00:00Z","source_format":"csv"}
{"id":"evt-002","user_id":67890,"email":"bob@example.com","amount":150.25,"enabled":false,"created_at":"2024-01-15T11:30:00Z","converted_at":"2026-01-12T10:00:00Z","source_format":"csv"}
{"id":"evt-003","user_id":11223,"email":"charlie@example.com","amount":75,"enabled":true,"created_at":"2024-01-15T12:45:00Z","converted_at":"2026-01-12T10:00:00Z","source_format":"csv"}
```

### Key Concepts

**CSV Codec:** The `codec: csv` automatically parses CSV headers and rows into JSON objects. Each header becomes a field name.

**Type Conversion:** CSV values are strings by default. Use Bloblang functions:
- `.number()` - convert to number (integer or float)
- `.bool()` - convert to boolean
- `.catch` - provide default value if conversion fails

**Error Handling:** The `catch` operator ensures the pipeline doesn't fail on malformed data - invalid numbers become 0, invalid booleans become false.

## Step 2: JSON Schema Validation

JSON Schema defines the expected structure, types, and constraints of your data. Use it to enforce data quality before processing or storing data.

### The Schema

Create `schemas/user-event-schema.json`:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["id", "user_id", "email", "amount"],
  "properties": {
    "id": {
      "type": "string",
      "pattern": "^evt-[0-9]+$"
    },
    "user_id": {
      "type": "integer",
      "minimum": 1
    },
    "email": {
      "type": "string",
      "format": "email"
    },
    "amount": {
      "type": "number",
      "minimum": 0
    },
    "enabled": {
      "type": "boolean"
    },
    "created_at": {
      "type": "string",
      "format": "date-time"
    }
  },
  "additionalProperties": true
}
```

### The Pipeline

Create `pipeline-validation.yaml`:

```yaml
input:
  stdin:
    codec: lines

pipeline:
  processors:
    - json_schema:
        schema_path: "schemas/user-event-schema.json"

    - mapping: |
        root = this
        root.validated_at = now().ts_format("2006-01-02T15:04:05Z")
        root.schema_version = "1.0"

output:
  stdout:
    codec: lines
```

### Test Data

Create `test-data/events-mixed.json` (some valid, some invalid):

```json
{"id":"evt-001","user_id":12345,"email":"alice@example.com","amount":99.5,"enabled":true,"created_at":"2024-01-15T10:00:00Z"}
{"id":"invalid","user_id":-1,"email":"not-an-email","amount":-50,"enabled":"yes","created_at":"not-a-date"}
{"id":"evt-002","user_id":67890,"email":"bob@example.com","amount":150.25,"enabled":false,"created_at":"2024-01-15T11:30:00Z"}
```

### Run It

```bash
cat test-data/events-mixed.json | expanso-edge run pipeline-validation.yaml 2>&1
```

### Expected Behavior

- **Valid messages** pass through with `validated_at` timestamp
- **Invalid messages** are rejected (stderr shows validation errors)

The second line fails validation because:
- `id` doesn't match pattern `^evt-[0-9]+$`
- `user_id` is negative (minimum: 1)
- `email` is not a valid email format
- `amount` is negative (minimum: 0)

## Step 3: Combined Pipeline

Combine CSV conversion with schema validation for a complete data quality pipeline.

### The Pipeline

Create `pipeline-combined.yaml`:

```yaml
input:
  stdin:
    codec: csv
    csv:
      delimiter: ","

pipeline:
  processors:
    # Step 1: Type conversion
    - mapping: |
        root.id = this.id
        root.user_id = this.user_id.number() catch 0
        root.email = this.email
        root.amount = this.amount.number() catch 0.0
        root.enabled = this.enabled.bool() catch false
        root.created_at = this.created_at
        root.converted_at = now().ts_format("2006-01-02T15:04:05Z")

    # Step 2: Schema validation
    - json_schema:
        schema_path: "schemas/user-event-schema.json"

    # Step 3: Add validation metadata
    - mapping: |
        root = this
        root.validated_at = now().ts_format("2006-01-02T15:04:05Z")
        root.quality_checked = true

output:
  stdout:
    codec: lines
```

### Run It

```bash
cat test-data/users.csv | expanso-edge run pipeline-combined.yaml
```

### Expected Output

CSV is converted, validated, and enriched:

```json
{"id":"evt-001","user_id":12345,"email":"alice@example.com","amount":99.5,"enabled":true,"created_at":"2024-01-15T10:00:00Z","converted_at":"2026-01-12T10:00:00Z","validated_at":"2026-01-12T10:00:00Z","quality_checked":true}
{"id":"evt-002","user_id":67890,"email":"bob@example.com","amount":150.25,"enabled":false,"created_at":"2024-01-15T11:30:00Z","converted_at":"2026-01-12T10:00:00Z","validated_at":"2026-01-12T10:00:00Z","quality_checked":true}
{"id":"evt-003","user_id":11223,"email":"charlie@example.com","amount":75,"enabled":true,"created_at":"2024-01-15T12:45:00Z","converted_at":"2026-01-12T10:00:00Z","validated_at":"2026-01-12T10:00:00Z","quality_checked":true}
```

## Understanding the Flow

```
Raw CSV
    ↓
CSV Parser (automatically creates JSON with string values)
    ↓
Type Conversion Mapping (convert strings to proper types)
    ↓
JSON Schema Validation (enforce structure and constraints)
    ↓
Metadata Enrichment (add timestamps, flags)
    ↓
Valid JSON Output
```

## Production Considerations

### 1. Error Handling

Add a dead-letter queue for invalid records:

```yaml
output:
  switch:
    cases:
      - check: errored()
        output:
          file:
            path: "./rejected/${!timestamp_unix()}.json"
      - output:
          stdout:
            codec: lines
```

### 2. External Schema Files

Store schemas in version control or a schema registry:

```yaml
processors:
  - json_schema:
      schema_path: "${SCHEMA_FILE}"  # Load from environment
```

### 3. Schema Versioning

Track which schema version validated each message:

```yaml
processors:
  - mapping: |
      root = this
      root.schema_version = "${SCHEMA_VERSION:1.0}"
      root.validated_at = now().ts_format("2006-01-02T15:04:05Z")
```

### 4. Performance

For high-volume pipelines:
- Keep schemas simple (fewer nested objects)
- Use `additionalProperties: false` to reject unexpected fields early
- Consider caching for schema files loaded from remote sources

## Common Patterns

### Nested CSV (Arrays)

Some CSV formats use delimited values within cells:

```csv
id,tags,scores
evt-001,"tag1,tag2,tag3","10,20,30"
```

Parse with Bloblang:

```yaml
processors:
  - mapping: |
      root.id = this.id
      root.tags = this.tags.split(",")
      root.scores = this.scores.split(",").map_each(ele -> ele.number())
```

### Conditional Validation

Apply different schemas based on content:

```yaml
processors:
  - switch:
      cases:
        - check: this.event_type == "user"
          processors:
            - json_schema:
                schema_path: "schemas/user-schema.json"
        - check: this.event_type == "order"
          processors:
            - json_schema:
                schema_path: "schemas/order-schema.json"
```

## Troubleshooting

**Problem:** CSV parsing fails with "record on line X: wrong number of fields"

**Solution:** Check for unescaped delimiters. Use `lazy_quotes: true` for messy CSV:

```yaml
csv:
  delimiter: ","
  lazy_quotes: true
```

**Problem:** Type conversion fails silently

**Solution:** Add logging to see which conversions are using `catch` defaults:

```yaml
processors:
  - mapping: |
      root.user_id = this.user_id.number().catch(err -> {
        root.conversion_error = "user_id: %s".format(err)
        0
      })
```

**Problem:** Schema validation too strict

**Solution:** Use `additionalProperties: true` to allow extra fields, or make fields optional by removing them from `required`.

## Related Templates

- **Template 17:** `templates/processors/csv-to-json.yaml` - Full CSV conversion template
- **Template 18:** `templates/processors/schema-validation.yaml` - Standalone schema validation

## Next Steps

- **Walkthrough 07:** Enrichment with Cache - Add lookup data during transformation
- **Walkthrough 10:** Dead Letter Queues - Handle validation failures gracefully
- **Walkthrough 15:** Building a Compliance Pipeline - Combine validation with security

## Summary

You've learned:
- How to parse CSV and convert to JSON with proper types
- How to validate JSON against a schema
- How to combine format conversion with validation
- Best practices for data quality pipelines

Format conversion and validation are foundational for data integration. These patterns ensure data quality before processing, storage, or forwarding to downstream systems.

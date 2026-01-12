# Walkthrough 07: Enrichment with Cache

**Track:** Data Transformations
**Difficulty:** Intermediate
**Time:** 30 minutes
**Prerequisites:** Walkthrough 02 (Understanding Bloblang), Walkthrough 05 (Structured Data Transformation)

## Overview

This walkthrough teaches you how to enrich streaming data with reference information using lookups. You'll learn to:
- Perform lookups against static reference data
- Enrich events with user profiles, product info, or configuration
- Handle missing lookup data gracefully
- Implement efficient enrichment patterns

Enrichment adds valuable context to raw events, making them more useful for analytics, alerting, and business logic.

## Learning Objectives

By the end of this walkthrough, you will:
- Use Bloblang to perform JSON-based lookups
- Enrich events with multiple reference datasets
- Handle lookup failures and missing data
- Structure enriched data effectively

## Architecture

```
Raw Events → Extract Key → Lookup Reference → Merge Data → Enriched Output
                               ↓
                         Reference Files
                         (users.json,
                          products.json,
                          config.json)
```

## What You'll Build

Three pipelines demonstrating:
1. **File-based lookup enrichment** - Load reference data and enrich events
2. **Multiple enrichment sources** - Combine user + product data
3. **Fallback and error handling** - Gracefully handle missing data

## Prerequisites

- Expanso CLI installed (`expanso-cli`)
- Expanso Edge runtime installed (`expanso-edge`)
- Understanding of Bloblang (Walkthrough 02)

## Step 1: Simple Lookup Enrichment

Load reference data from a file and enrich events by looking up user IDs.

### Reference Data

Create `reference-data/users.json`:

```json
{
  "user-123": {
    "name": "Alice Johnson",
    "email": "alice@example.com",
    "tier": "premium",
    "region": "us-west",
    "joined": "2023-01-15"
  },
  "user-456": {
    "name": "Bob Smith",
    "email": "bob@example.com",
    "tier": "free",
    "region": "eu-west",
    "joined": "2023-06-20"
  },
  "user-789": {
    "name": "Charlie Brown",
    "email": "charlie@example.com",
    "tier": "pro",
    "region": "ap-south",
    "joined": "2024-02-10"
  }
}
```

### The Pipeline

Create `pipeline-simple-enrichment.yaml`:

```yaml
input:
  stdin:
    codec: lines

pipeline:
  processors:
    # Load reference data as a global variable
    - mapping: |
        # On first message, load users lookup table
        let users = if !meta("users_loaded").bool() {
          file("reference-data/users.json").parse_json()
        } else {
          meta("lookup_users")
        }

        # Save to metadata for subsequent messages
        meta users_loaded = true
        meta lookup_users = $users

        # Perform lookup
        root = this
        root.user_profile = $users.get(this.user_id) catch {
          "name": "Unknown User",
          "tier": "free",
          "region": "unknown"
        }

        # Add enrichment metadata
        root.enriched_at = now().ts_format("2006-01-02T15:04:05Z")
        root.enrichment_source = if $users.exists(this.user_id) {
          "user_cache"
        } else {
          "default_profile"
        }

output:
  stdout:
    codec: lines
```

### Test Data

Create `test-data/events.json`:

```json
{"event_id":"evt-001","user_id":"user-123","action":"login","timestamp":"2024-01-15T10:00:00Z"}
{"event_id":"evt-002","user_id":"user-456","action":"purchase","amount":99.99,"timestamp":"2024-01-15T10:15:00Z"}
{"event_id":"evt-003","user_id":"user-999","action":"view","timestamp":"2024-01-15T10:30:00Z"}
{"event_id":"evt-004","user_id":"user-789","action":"logout","timestamp":"2024-01-15T10:45:00Z"}
```

### Run It

```bash
cd walkthroughs/02-transformations/07-enrichment-with-cache
cat test-data/events.json | expanso-edge run pipeline-simple-enrichment.yaml
```

### Expected Output

Each event is enriched with user profile data:

```json
{"event_id":"evt-001","user_id":"user-123","action":"login","timestamp":"2024-01-15T10:00:00Z","user_profile":{"name":"Alice Johnson","email":"alice@example.com","tier":"premium","region":"us-west","joined":"2023-01-15"},"enriched_at":"2026-01-12T11:00:00Z","enrichment_source":"user_cache"}
{"event_id":"evt-002","user_id":"user-456","action":"purchase","amount":99.99,"timestamp":"2024-01-15T10:15:00Z","user_profile":{"name":"Bob Smith","email":"bob@example.com","tier":"free","region":"eu-west","joined":"2023-06-20"},"enriched_at":"2026-01-12T11:00:00Z","enrichment_source":"user_cache"}
{"event_id":"evt-003","user_id":"user-999","action":"view","timestamp":"2024-01-15T10:30:00Z","user_profile":{"name":"Unknown User","tier":"free","region":"unknown"},"enriched_at":"2026-01-12T11:00:00Z","enrichment_source":"default_profile"}
{"event_id":"evt-004","user_id":"user-789","action":"logout","timestamp":"2024-01-15T10:45:00Z","user_profile":{"name":"Charlie Brown","email":"charlie@example.com","tier":"pro","region":"ap-south","joined":"2024-02-10"},"enriched_at":"2026-01-12T11:00:00Z","enrichment_source":"user_cache"}
```

### Key Concepts

**File-based Lookups:** The `file()` function loads reference data from disk. This is loaded once and cached in metadata.

**Metadata Caching:** Using `meta()` to store the lookup table avoids re-reading the file for every message.

**Lookup with Fallback:** The `catch` operator provides a default profile when the user_id isn't found.

**Enrichment Tracking:** The `enrichment_source` field indicates whether data came from cache or fallback.

## Step 2: Multiple Enrichment Sources

Enrich events with both user profiles and product information.

### Additional Reference Data

Create `reference-data/products.json`:

```json
{
  "prod-001": {
    "name": "Premium Subscription",
    "category": "subscription",
    "price": 99.99,
    "features": ["unlimited", "priority_support", "analytics"]
  },
  "prod-002": {
    "name": "API Credits Bundle",
    "category": "credits",
    "price": 49.99,
    "features": ["10000_credits", "rollover"]
  },
  "prod-003": {
    "name": "Enterprise License",
    "category": "license",
    "price": 999.99,
    "features": ["unlimited", "sla", "dedicated_support", "custom_integration"]
  }
}
```

### The Pipeline

Create `pipeline-multi-enrichment.yaml`:

```yaml
input:
  stdin:
    codec: lines

pipeline:
  processors:
    - mapping: |
        # Load reference data on first message
        let users = if !meta("users_loaded").bool() {
          file("reference-data/users.json").parse_json()
        } else {
          meta("lookup_users")
        }

        let products = if !meta("products_loaded").bool() {
          file("reference-data/products.json").parse_json()
        } else {
          meta("lookup_products")
        }

        # Cache in metadata
        meta users_loaded = true
        meta products_loaded = true
        meta lookup_users = $users
        meta lookup_products = $products

        # Enrich with user profile
        root = this
        root.user = $users.get(this.user_id) catch {
          "name": "Unknown User",
          "tier": "free"
        }

        # Enrich with product details (if product_id exists)
        root.product = if this.exists("product_id") {
          $products.get(this.product_id) catch {
            "name": "Unknown Product",
            "category": "other"
          }
        }

        # Compute derived fields
        root.is_premium_user = root.user.tier == "premium" || root.user.tier == "pro"
        root.is_high_value_purchase = (this.exists("amount") && this.amount.number() > 100) ||
                                       (root.exists("product.price") && root.product.price.number() > 100)

        # Add metadata
        root.enriched_at = now().ts_format("2006-01-02T15:04:05Z")
        root.enrichment_sources = ["users", "products"]

output:
  stdout:
    codec: lines
```

### Test Data

Create `test-data/purchase-events.json`:

```json
{"event_id":"evt-101","user_id":"user-123","action":"purchase","product_id":"prod-001","timestamp":"2024-01-15T10:00:00Z"}
{"event_id":"evt-102","user_id":"user-456","action":"purchase","product_id":"prod-002","timestamp":"2024-01-15T10:15:00Z"}
{"event_id":"evt-103","user_id":"user-789","action":"view","timestamp":"2024-01-15T10:30:00Z"}
{"event_id":"evt-104","user_id":"user-999","action":"purchase","product_id":"prod-999","amount":150.00,"timestamp":"2024-01-15T10:45:00Z"}
```

### Run It

```bash
cat test-data/purchase-events.json | expanso-edge run pipeline-multi-enrichment.yaml
```

### Expected Output

Events enriched with both user and product data:

```json
{"event_id":"evt-101","user_id":"user-123","action":"purchase","product_id":"prod-001","timestamp":"2024-01-15T10:00:00Z","user":{"name":"Alice Johnson","email":"alice@example.com","tier":"premium","region":"us-west","joined":"2023-01-15"},"product":{"name":"Premium Subscription","category":"subscription","price":99.99,"features":["unlimited","priority_support","analytics"]},"is_premium_user":true,"is_high_value_purchase":false,"enriched_at":"2026-01-12T11:00:00Z","enrichment_sources":["users","products"]}
```

## Step 3: Conditional Enrichment with Validation

Enrich data only when certain conditions are met, and validate enriched data.

### The Pipeline

Create `pipeline-conditional-enrichment.yaml`:

```yaml
input:
  stdin:
    codec: lines

pipeline:
  processors:
    - mapping: |
        # Load reference data
        let users = if !meta("users_loaded").bool() {
          file("reference-data/users.json").parse_json()
        } else {
          meta("lookup_users")
        }

        meta users_loaded = true
        meta lookup_users = $users

        root = this

        # Only enrich if user_id is present and valid format
        root.user = if this.exists("user_id") && this.user_id.string().has_prefix("user-") {
          let profile = $users.get(this.user_id) catch null
          if $profile != null {
            $profile.merge({
              "lookup_success": true,
              "lookup_timestamp": now().ts_format("2006-01-02T15:04:05Z")
            })
          } else {
            {
              "lookup_success": false,
              "lookup_error": "user_not_found",
              "user_id_attempted": this.user_id
            }
          }
        } else {
          {
            "lookup_success": false,
            "lookup_error": "invalid_user_id_format"
          }
        }

        # Apply business logic based on enriched data
        root.route_to = match {
          this.user.lookup_success && this.user.tier == "premium" => "premium_queue",
          this.user.lookup_success && this.user.tier == "pro" => "pro_queue",
          this.user.lookup_success => "standard_queue",
          _ => "unidentified_queue"
        }

output:
  stdout:
    codec: lines
```

### Test Data

Create `test-data/mixed-events.json`:

```json
{"event_id":"evt-201","user_id":"user-123","action":"login"}
{"event_id":"evt-202","user_id":"invalid","action":"login"}
{"event_id":"evt-203","action":"view"}
{"event_id":"evt-204","user_id":"user-999","action":"purchase"}
```

### Run It

```bash
cat test-data/mixed-events.json | expanso-edge run pipeline-conditional-enrichment.yaml
```

### Expected Behavior

- **Valid user IDs found in cache:** Full enrichment with `lookup_success: true`
- **Valid format but not in cache:** Partial enrichment with error details
- **Invalid format or missing:** Error indication for routing

## Production Considerations

### 1. Large Reference Data

For reference data too large to load into memory, use external cache systems:

```yaml
# Use Redis or Memcached (requires cache resource configuration)
cache_resources:
  - label: user_cache
    redis:
      url: "${REDIS_URL}"
      default_ttl: "1h"

processors:
  - cache:
      resource: user_cache
      operator: get
      key: ${! json("user_id") }
```

### 2. Refreshing Reference Data

Reload reference data periodically or use a separate pipeline to update caches:

```yaml
# Pipeline to refresh cache every hour
input:
  generate:
    interval: "1h"
    count: 1
    mapping: 'root = {}'

processors:
  - mapping: |
      # Reload reference data
      meta users_loaded = false
      root = "cache_refreshed"
```

### 3. Performance Optimization

- **Load once:** Use metadata to cache parsed JSON
- **Batch lookups:** If possible, batch multiple lookups in a single operation
- **Async enrichment:** Use `branch` processor for non-blocking enrichment

### 4. Error Handling

Always provide meaningful fallback data:

```yaml
processors:
  - mapping: |
      root = this
      root.user = $users.get(this.user_id) catch {
        "error": "lookup_failed",
        "user_id": this.user_id,
        "fallback_tier": "free",
        "message": "Using default profile"
      }
```

## Common Patterns

### IP Geolocation Enrichment

```yaml
processors:
  - mapping: |
      let geo_db = file("reference-data/ip-geo.json").parse_json()
      root = this
      root.geo = $geo_db.get(this.ip_address) catch {
        "country": "unknown",
        "city": "unknown"
      }
```

### Configuration-based Routing

```yaml
processors:
  - mapping: |
      let routing_config = file("reference-data/routing-rules.json").parse_json()
      root = this
      root.destination = $routing_config.get(this.tenant_id).destination catch "default_output"
```

### Feature Flag Enrichment

```yaml
processors:
  - mapping: |
      let feature_flags = file("reference-data/feature-flags.json").parse_json()
      root = this
      root.features_enabled = $feature_flags.get(this.user_id).features catch []
```

## Troubleshooting

**Problem:** "file() function not found" error

**Solution:** Ensure you're using a recent version of Expanso that supports the `file()` function. Alternatively, use an input to read the file once.

**Problem:** Memory usage growing over time

**Solution:** Reference data cached in metadata persists for the pipeline lifetime. For very large datasets, use external cache resources (Redis, Memcached).

**Problem:** Lookups are slow

**Solution:** Ensure reference data is pre-parsed and stored in metadata, not re-parsed for each message.

## Related Templates

- **Template 15:** `templates/processors/json-transform.yaml` - Base transformation template
- **Template 19:** `templates/patterns/fan-out.yaml` - Route enriched data to multiple destinations
- **Template 20:** `templates/patterns/content-routing.yaml` - Route based on enriched fields

## Next Steps

- **Walkthrough 08:** Fan-Out to Multiple Destinations - Route enriched data
- **Walkthrough 09:** Content-Based Routing - Use enriched fields for routing decisions
- **Walkthrough 16:** AWS Integration Suite - Enrich with data from DynamoDB or S3

## Summary

You've learned:
- How to load reference data and perform lookups in Bloblang
- How to enrich events with multiple data sources
- How to handle missing data and validation errors
- Best practices for production enrichment pipelines

Enrichment transforms raw events into actionable data by adding context, enabling smarter routing, analytics, and business logic.

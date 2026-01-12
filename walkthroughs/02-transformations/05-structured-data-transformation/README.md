# Walkthrough 05: Structured Data Transformation

**Level**: Intermediate
**Time**: 30 minutes
**Prerequisites**: Completed W02 (Understanding Bloblang)

## Overview

This walkthrough explores advanced Bloblang patterns for complex data transformations: nested object manipulation, array operations, conditionals, and error handling strategies for production pipelines.

## What You'll Learn

- Advanced nested object transformations
- Array filtering, mapping, and aggregation
- Complex conditional logic
- Type coercion and validation
- Error handling patterns
- Data enrichment techniques

## Exercise 1: Nested Object Restructuring

Real-world data often has deeply nested structures that need flattening or reshaping.

### Step 1: Review Nested Data

Open `test-data/nested-events.json`. These events have nested user and metadata objects.

### Step 2: Flatten Nested Objects

Open `pipeline-flatten.yaml`. The mapping:
- Flattens nested user.profile fields to top level
- Extracts array elements
- Handles missing nested fields gracefully

```bloblang
root.user_id = this.user.id
root.user_name = this.user.profile.name
root.user_email = this.user.profile.email catch ""
```

### Step 3: Run and Verify

```bash
cd walkthroughs/02-transformations/05-structured-data-transformation
cat test-data/nested-events.json | expanso-edge run pipeline-flatten.yaml
```

Compare with `expected-output/flattened.json`.

## Exercise 2: Array Operations

Arrays require special handling: filtering, mapping, reducing.

### Step 1: Review Array Data

Open `test-data/array-data.json`. Events contain arrays of items, tags, and metrics.

### Step 2: Array Filtering and Mapping

Open `pipeline-arrays.yaml`. Key operations:

```bloblang
# Filter array elements
root.high_priority_items = this.items.filter(item -> item.priority > 7)

# Map array to new structure
root.item_ids = this.items.map_each(item -> item.id)

# Count array elements
root.total_items = this.items.length()

# Check array contains
root.has_urgent = this.tags.contains("urgent")
```

### Step 3: Run and Verify

```bash
cat test-data/array-data.json | expanso-edge run pipeline-arrays.yaml
```

## Exercise 3: Complex Conditionals

Real pipelines need sophisticated routing and transformation logic.

### Step 1: Review Complex Data

Open `test-data/complex-events.json`. Various event types with different structures.

### Step 2: Multi-Level Conditionals

Open `pipeline-conditionals.yaml`. Demonstrates:
- Nested if/else chains
- Boolean logic (AND, OR)
- Null checking and defaults
- Type-based routing

```bloblang
root.category = if this.type == "error" && this.severity > 7 {
  "critical_incident"
} else if this.type == "error" {
  "standard_error"
} else if this.type == "warning" && this.user.role == "admin" {
  "admin_warning"
} else {
  "informational"
}
```

### Step 3: Test All Paths

```bash
cat test-data/complex-events.json | expanso-edge run pipeline-conditionals.yaml
```

Verify all conditional branches work correctly.

## Exercise 4: Data Enrichment

Enrich incoming data with calculated fields and metadata.

### Step 1: Review Raw Data

Open `test-data/raw-events.json`. Basic events needing enrichment.

### Step 2: Add Computed Fields

Open `pipeline-enrichment.yaml`. Adds:
- Calculated risk scores
- Business logic flags
- Timestamp conversions
- Data quality indicators

```bloblang
# Calculate risk score from multiple factors
root.risk_score = (this.priority.number() catch 0) * 10 +
                  (this.failed_attempts.number() catch 0) * 5 +
                  if this.source == "external" { 20 } else { 0 }

# Add business logic flags
root.requires_review = root.risk_score > 50
root.auto_approved = root.risk_score < 20 && this.user.verified.bool() catch false
```

### Step 3: Verify Enrichment

```bash
cat test-data/raw-events.json | expanso-edge run pipeline-enrichment.yaml
```

## Exercise 5: Production Error Handling

Robust pipelines never fail - they handle errors gracefully.

### Step 1: Review Messy Data

Open `test-data/messy-data.json`. Missing fields, wrong types, null values.

### Step 2: Error-Proof Transformations

Open `pipeline-error-handling.yaml`. Patterns:

```bloblang
# Chained catch for multiple fallbacks
root.user_id = this.user.id catch this.userId catch this.user_identifier catch "unknown"

# Type conversion with defaults
root.count = this.count.number() catch 0
root.amount = this.amount.number() catch 0.0
root.enabled = this.enabled.bool() catch true

# Safe array access
root.first_tag = (this.tags catch []).index(0) catch "untagged"

# Null-safe nested access
root.city = this.user.address.city catch ""
```

### Step 3: Test with Bad Data

```bash
cat test-data/messy-data.json | expanso-edge run pipeline-error-handling.yaml
```

No errors - all handled gracefully!

## Advanced Bloblang Patterns

### Pattern 1: Object Merging

```bloblang
# Merge two objects
root = this.defaults.merge(this.overrides)
```

### Pattern 2: Conditional Field Inclusion

```bloblang
# Only include field if condition met
root.admin_data = if this.user.role == "admin" {
  this.admin_metadata
} else {
  deleted()
}
```

### Pattern 3: Array Aggregation

```bloblang
# Sum array values
root.total = this.items.map_each(item -> item.amount.number() catch 0).sum()

# Find max value
root.max_priority = this.items.map_each(item -> item.priority.number() catch 0).max()
```

### Pattern 4: Dynamic Field Names

```bloblang
# Create fields based on data
root = this.metrics.map_each(m -> {m.name: m.value}).merge()
```

## Expected Output

After completing all exercises:
- ✓ Flattened nested objects
- ✓ Filtered and transformed arrays
- ✓ Applied complex conditional logic
- ✓ Enriched data with computed fields
- ✓ Handled errors without pipeline failures

See `expected-output/` for all examples.

## Key Takeaways

✓ Use `.catch` for every field access that might fail
✓ Array operations: `.filter()`, `.map_each()`, `.length()`, `.contains()`
✓ Nested conditionals with if/else chains
✓ Computed fields add business logic at ingestion time
✓ Chained catches provide multiple fallbacks
✓ `deleted()` removes fields conditionally
✓ Always test with messy real-world data

## Production Best Practices

**Performance:**
- Avoid expensive operations in tight loops
- Use `.exists()` to check before accessing
- Cache computed values with `let` variables

**Maintainability:**
- Document complex transformations with comments
- Break complex mappings into multiple processors
- Use meaningful variable names

**Reliability:**
- Test with null, empty, and wrong-type values
- Add data quality flags for downstream monitoring
- Log transformation failures for debugging

## Next Steps

- **Walkthrough 06**: Format Conversion Pipeline - CSV/JSON with validation
- **Walkthrough 07**: Enrichment with Cache - External data lookups
- **Template**: `templates/processors/json-transform.yaml` - Full reference

## Related Templates

- `templates/processors/json-transform.yaml` - Comprehensive Bloblang examples
- `templates/processors/schema-validation.yaml` - Pre/post transformation validation

## Troubleshooting

**Q: "My array filter returns nothing"**
A: Check your filter lambda syntax. Use `->` not `=>`. Example: `.filter(x -> x.value > 5)`

**Q: "Nested field access causes errors"**
A: Add `.catch` at each level: `this.a.b.c catch this.a.b catch ""`

**Q: "Performance is slow on large arrays"**
A: Avoid nested `.map_each()` calls. Process arrays once and cache results with `let`.

**Q: "How do I debug complex Bloblang?"**
A: Add intermediate fields: `root.debug_step1 = ...` then remove after testing.

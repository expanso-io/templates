# Walkthrough 02: Understanding Bloblang

**Level**: Beginner
**Time**: 20 minutes
**Prerequisites**: Completed Walkthrough 01 (Your First Pipeline)

## Overview

Bloblang is Expanso's native mapping language for transforming data. This walkthrough teaches you the fundamentals of Bloblang through hands-on examples, from basic field access to complex transformations.

## What You'll Learn

- Bloblang syntax basics
- Field access and assignment
- Using functions for transformation
- Conditional logic with `if`
- Error handling with `catch`
- Deleting and renaming fields

## Bloblang Fundamentals

Bloblang runs in the `mapping` processor and uses a simple syntax:

```bloblang
# Assign the entire input to output (pass-through)
root = this

# Access a field
root.output_field = this.input_field

# Use a function
root.uppercase_name = this.name.uppercase()

# Delete a field
root = this.without("sensitive_field")
```

## Exercise 1: Basic Field Mapping

### Step 1: Review Input Data

Open `test-data/raw-events.json`. These are unstructured events from various sources.

### Step 2: Review the Pipeline

Open `pipeline-basic-mapping.yaml`. The mapping processor:
- Normalizes field names
- Adds a `processed_at` timestamp
- Renames fields for consistency

### Step 3: Run the Pipeline

```bash
cd walkthroughs/01-getting-started/02-understanding-bloblang
cat test-data/raw-events.json | expanso-edge run pipeline-basic-mapping.yaml
```

### Step 4: Compare Output

Check your output against `expected-output/basic-mapping-output.json`. Notice:
- `event_type` normalized from mixed casing
- `processed_at` added with current timestamp
- Field structure is now consistent

## Exercise 2: Using Functions

Bloblang has 100+ built-in functions. Let's explore common ones.

### Step 1: Review the Pipeline

Open `pipeline-functions.yaml`. This demonstrates:
- String functions: `uppercase()`, `lowercase()`, `trim()`
- Time functions: `now()`, `ts_parse()`, `ts_format()`
- Type conversion: `.string()`, `.number()`
- UUIDs: `uuid_v4()`

### Step 2: Run the Pipeline

```bash
cat test-data/raw-events.json | expanso-edge run pipeline-functions.yaml
```

### Step 3: Understand the Transformations

Key transformations:
```bloblang
# Generate UUID
root.id = uuid_v4()

# Format timestamp
root.timestamp = now().ts_format("2006-01-02T15:04:05Z")

# Convert and calculate
root.priority_score = (this.priority.number() catch 0) * 10
```

## Exercise 3: Conditional Logic

### Step 1: Review the Pipeline

Open `pipeline-conditionals.yaml`. This uses `if` statements to:
- Route high-priority events differently
- Set default values for missing fields
- Apply transformations based on event type

### Step 2: Run the Pipeline

```bash
cat test-data/raw-events.json | expanso-edge run pipeline-conditionals.yaml
```

### Step 3: Understand the Logic

Bloblang `if` syntax:
```bloblang
root.severity = if this.priority.number() catch 0 > 7 {
  "high"
} else if this.priority.number() catch 0 > 4 {
  "medium"
} else {
  "low"
}
```

## Exercise 4: Error Handling

Real-world data is messy. Bloblang's `catch` handles missing or invalid fields.

### Step 1: Review the Pipeline

Open `pipeline-error-handling.yaml`. It uses `catch` to:
- Provide defaults for missing fields
- Handle type conversion errors
- Avoid pipeline failures

### Step 2: Run the Pipeline

```bash
cat test-data/raw-events.json | expanso-edge run pipeline-error-handling.yaml
```

### Step 3: Understand Error Handling

```bloblang
# If this.count is missing or non-numeric, use 0
root.count = this.count.number() catch 0

# If this.tags is missing, use empty array
root.tags = this.tags catch []

# Chain multiple catches
root.user_id = this.user.id catch this.userId catch "unknown"
```

## Expected Output

After completing all exercises, you should understand:
- How to map fields from input to output
- Common Bloblang functions and their usage
- Conditional transformations with `if`
- Error-safe transformations with `catch`

See `expected-output/` for all example outputs.

## Key Takeaways

✓ Bloblang uses `root` for output and `this` for input
✓ Functions are called with dot notation: `.uppercase()`
✓ Use `catch` to handle missing or invalid data gracefully
✓ Conditional logic uses `if/else` expressions
✓ All Bloblang runs in the `mapping` processor

## Bloblang Quick Reference

| Operation | Example |
|-----------|---------|
| Pass-through | `root = this` |
| Field access | `this.field` or `this."field-with-dash"` |
| Nested access | `this.user.email` |
| Function call | `this.name.uppercase()` |
| Conditionals | `if X { Y } else { Z }` |
| Error handling | `this.field catch "default"` |
| Delete field | `root = this.without("field")` |

## Next Steps

- **Walkthrough 03**: From Template to Cloud - Deploy a pipeline to S3
- **Walkthrough 05**: Structured Data Transformation - Advanced Bloblang patterns

## Related Templates

- `templates/processors/json-transform.yaml` - Complex Bloblang mappings
- `templates/processors/log-parser.yaml` - Parsing with Grok and Bloblang

## Further Reading

- [Bloblang Official Guide](https://docs.expanso.io/getting-started/core-concepts/)
- [Bloblang Function Reference](https://docs.expanso.io/guides/bloblang/functions)
- [Bloblang Cookbook](https://docs.expanso.io/cookbooks/bloblang)

## Troubleshooting

**Q: "expected object but got null" error**
A: Use `catch` to handle null/missing fields: `this.field catch {}`

**Q: Pipeline fails on certain inputs**
A: Add `.catch` to handle type conversion errors: `.number() catch 0`

**Q: How do I debug my Bloblang?**
A: Use `root = this` first to see raw input, then add transformations incrementally.

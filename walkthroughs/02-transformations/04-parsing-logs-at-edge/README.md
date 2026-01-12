# Walkthrough 04: Parsing Logs at the Edge

**Level**: Intermediate
**Time**: 25 minutes
**Prerequisites**: Completed W01 and W02

## Overview

Real-world logs come in unstructured text formats. This walkthrough teaches you how to parse common log formats (Apache, Nginx, application logs) into structured JSON using Grok patterns at the edge, before sending to downstream systems.

## What You'll Learn

- Grok pattern syntax and common patterns
- Parsing Apache/Nginx access logs
- Parsing application logs with timestamps and levels
- Combining Grok with Bloblang for post-processing
- Handling parsing failures gracefully

## Why Parse at the Edge?

**Benefits:**
- Reduce storage costs (structured data compresses better)
- Enable downstream filtering and routing
- Validate data quality before it reaches central systems
- Add context and enrichment immediately

## Exercise 1: Parse Application Logs

Application logs typically follow a pattern: timestamp, level, message.

### Step 1: Review Sample Logs

Open `test-data/app-logs.txt`. These are typical application logs with varying formats.

### Step 2: Understand the Grok Pattern

Open `pipeline-app-logs.yaml`. The Grok pattern:

```grok
%{TIMESTAMP_ISO8601:timestamp} %{LOGLEVEL:level} %{GREEDYDATA:message}
```

Breaking it down:
- `%{TIMESTAMP_ISO8601:timestamp}` - Matches ISO timestamps, extracts to `timestamp` field
- `%{LOGLEVEL:level}` - Matches INFO, WARN, ERROR, etc., extracts to `level` field
- `%{GREEDYDATA:message}` - Matches rest of line, extracts to `message` field

### Step 3: Run the Pipeline

```bash
cd walkthroughs/02-transformations/04-parsing-logs-at-edge
cat test-data/app-logs.txt | expanso-edge run pipeline-app-logs.yaml
```

### Step 4: Verify Structured Output

Compare output to `expected-output/app-logs-parsed.json`. Each log line is now structured JSON with extracted fields.

## Exercise 2: Parse HTTP Access Logs

Apache and Nginx access logs follow the Common Log Format or Combined Log Format.

### Step 1: Review Access Logs

Open `test-data/access-logs.txt`. These follow the Combined Log Format.

### Step 2: Understand the Complex Pattern

Open `pipeline-access-logs.yaml`. The Grok pattern handles:
- Client IP address
- Timestamp with timezone
- HTTP method, path, and version
- Status code
- Response size
- User agent

### Step 3: Run the Pipeline

```bash
cat test-data/access-logs.txt | expanso-edge run pipeline-access-logs.yaml
```

### Step 4: Add Post-Processing

The pipeline includes Bloblang post-processing to:
- Normalize HTTP status codes
- Calculate response time categories
- Extract browser from user agent
- Add success/error flags

## Exercise 3: Handle Multi-Line Logs

Some logs span multiple lines (stack traces, JSON logs).

### Step 1: Review Multi-Line Logs

Open `test-data/multiline-logs.txt` containing Java stack traces.

### Step 2: Configure Multi-Line Input

Open `pipeline-multiline-logs.yaml`. The `multiline` codec groups lines:

```yaml
codec: lines
multiline:
  max_buffer_size: 10000
  begin_pattern: '^\d{4}-\d{2}-\d{2}'  # Lines starting with dates
```

### Step 3: Run the Pipeline

```bash
cat test-data/multiline-logs.txt | expanso-edge run pipeline-multiline-logs.yaml
```

Stack traces are now grouped with their log entries.

## Exercise 4: Handle Parsing Failures

Not all logs match expected patterns. Handle failures gracefully.

### Step 1: Add Fallback Pattern

Open `pipeline-with-fallback.yaml`. It includes multiple Grok patterns:
1. Primary pattern (ISO timestamp format)
2. Alternative pattern (Unix timestamp format)
3. Fallback: Pass through unparsed

### Step 2: Test with Mixed Formats

```bash
cat test-data/mixed-logs.txt | expanso-edge run pipeline-with-fallback.yaml
```

### Step 3: Verify Error Handling

Check output - unparsed logs are marked with `parse_error: true` field.

## Common Grok Patterns Reference

| Pattern | Matches | Example |
|---------|---------|---------|
| `%{IP:field}` | IP addresses | 192.168.1.1 |
| `%{TIMESTAMP_ISO8601:field}` | ISO timestamps | 2026-01-11T10:00:00Z |
| `%{LOGLEVEL:field}` | Log levels | INFO, ERROR |
| `%{NUMBER:field}` | Numbers | 123, 45.67 |
| `%{WORD:field}` | Single words | alpha123 |
| `%{GREEDYDATA:field}` | Rest of line | Any text... |
| `%{HTTPDATE:field}` | Apache log dates | 11/Jan/2026:10:00:00 +0000 |
| `%{URIPATHPARAM:field}` | URL paths | /api/v1/users?id=123 |

## Expected Output

After completing all exercises:
- ✓ Parsed application logs to structured JSON
- ✓ Extracted HTTP access log fields (IP, status, user agent)
- ✓ Handled multi-line stack traces
- ✓ Gracefully handled parsing failures

See `expected-output/` for all examples.

## Key Takeaways

✓ Grok patterns extract structured data from unstructured text
✓ Common patterns cover most log formats (ISO timestamps, IP addresses, etc.)
✓ Combine Grok with Bloblang for normalization and enrichment
✓ Use multiple patterns with fallbacks for robust parsing
✓ Multi-line codec handles stack traces and wrapped logs
✓ Always mark unparsed logs for debugging

## Production Considerations

**Performance:**
- Parse at the edge to reduce network bandwidth
- Use specific patterns before GREEDYDATA for efficiency
- Batch processing for high-volume logs

**Reliability:**
- Always include fallback patterns
- Add parse_error fields for monitoring
- Test with real production log samples

**Maintainability:**
- Document your Grok patterns
- Use named captures for clarity
- Version your patterns with log format changes

## Next Steps

- **Walkthrough 05**: Structured Data Transformation - Advanced Bloblang
- **Walkthrough 06**: Format Conversion Pipeline - CSV to JSON with schema validation
- **Template**: `templates/processors/log-parser.yaml` - Complete log parsing reference

## Related Templates

- `templates/processors/log-parser.yaml` - Grok log parsing
- `templates/processors/json-transform.yaml` - Bloblang transformations

## Troubleshooting

**Q: "Pattern doesn't match my logs"**
A: Test patterns incrementally. Start with timestamp, then add fields one by one.

**Q: "Performance is slow"**
A: Avoid GREEDYDATA at the beginning of patterns. Use more specific patterns first.

**Q: "Multi-line logs aren't grouping"**
A: Check your begin_pattern regex. It should match the first line of each log entry.

**Q: "Where can I find more patterns?"**
A: See https://github.com/logstash-plugins/logstash-patterns-core for comprehensive pattern library.

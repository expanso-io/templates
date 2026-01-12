# Walkthrough 13: PII Detection and Masking

**Track:** Security & Compliance
**Difficulty:** Intermediate
**Time:** 30 minutes
**Prerequisites:** W02 (Bloblang), W12 (Secret Management)

## Overview

Detect and mask personally identifiable information (PII) for GDPR/CCPA compliance.

## The Pipeline

`pipeline-pii-masking.yaml`:

```yaml
input:
  stdin:
    codec: lines

pipeline:
  processors:
    - mapping: |
        root = this

        # Mask email
        root.email = if this.exists("email") {
          this.email.re_replace_all("[^@]+", "***")
        }

        # Mask credit card
        root.credit_card = if this.exists("credit_card") {
          this.credit_card.re_replace_all("\\d{4}\\s?\\d{4}\\s?\\d{4}\\s?(\\d{4})", "****-****-****-$1")
        }

        # Mask SSN
        root.ssn = if this.exists("ssn") {
          this.ssn.re_replace_all("\\d{3}-\\d{2}-(\\d{4})", "***-**-$1")
        }

        root.masked_at = now().ts_format("2006-01-02T15:04:05Z")

output:
  stdout:
    codec: lines
```

## Test Data

`test-data/pii-data.json`:

```json
{"user_id":"123","email":"alice@example.com","credit_card":"1234 5678 9012 3456"}
{"user_id":"456","email":"bob@example.com","ssn":"123-45-6789"}
```

## Run It

```bash
cat test-data/pii-data.json | expanso-edge run pipeline-pii-masking.yaml
```

## Related: Template 21 (`templates/patterns/pii-masking.yaml`)

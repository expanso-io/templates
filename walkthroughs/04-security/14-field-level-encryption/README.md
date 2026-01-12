# Walkthrough 14: Field-Level Encryption

**Track:** Security & Compliance
**Difficulty:** Intermediate
**Time:** 30 minutes
**Prerequisites:** W02, W12

## Overview

Encrypt sensitive fields using AES encryption for data protection.

## The Pipeline

`pipeline-encryption.yaml`:

```yaml
input:
  stdin:
    codec: lines

pipeline:
  processors:
    - mapping: |
        root = this

        # Encrypt sensitive field with AES
        root.ssn_encrypted = if this.exists("ssn") {
          this.ssn.encrypt_aes("${ENCRYPTION_KEY}")
        }

        # Remove plaintext
        root = root.without("ssn")

        root.encrypted_at = now().ts_format("2006-01-02T15:04:05Z")

output:
  stdout:
    codec: lines
```

## Setup

```bash
# Generate encryption key
export ENCRYPTION_KEY=$(openssl rand -base64 32)
```

## Test Data

`test-data/sensitive-data.json`:

```json
{"user_id":"123","name":"Alice","ssn":"123-45-6789"}
{"user_id":"456","name":"Bob","ssn":"987-65-4321"}
```

## Run It

```bash
cat test-data/sensitive-data.json | expanso-edge run pipeline-encryption.yaml
```

## Related: Template 25 (`templates/patterns/field-encryption.yaml`)

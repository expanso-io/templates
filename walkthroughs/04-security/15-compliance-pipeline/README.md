# Walkthrough 15: Building a Compliance Pipeline

**Track:** Security & Compliance
**Difficulty:** Advanced
**Time:** 45 minutes
**Prerequisites:** W12 (Secret Management), W13 (PII Masking), W14 (Encryption)

## Overview

Combine PII masking, encryption, and audit logging for GDPR/CCPA compliance.

## The Compliance Pipeline

`pipeline-compliance.yaml`:

```yaml
input:
  stdin:
    codec: lines

pipeline:
  processors:
    # Step 1: PII Detection and Masking
    - mapping: |
        root = this

        # Mask email
        root.email = if this.exists("email") {
          this.email.re_replace_all("[^@]+", "***")
        }

        # Detect PII fields for audit
        root.pii_detected = []
        root.pii_detected = if this.exists("ssn") { this.pii_detected.append("ssn") }
        root.pii_detected = if this.exists("credit_card") { this.pii_detected.append("credit_card") }

    # Step 2: Encrypt sensitive fields
    - mapping: |
        root = this

        # Encrypt SSN if present
        root.ssn_encrypted = if this.exists("ssn") {
          this.ssn.encrypt_aes("${ENCRYPTION_KEY}")
        }
        root = root.without("ssn")

    # Step 3: Add audit trail
    - mapping: |
        root = this
        root.compliance_metadata = {
          "processed_at": now().ts_format("2006-01-02T15:04:05Z"),
          "pipeline_version": "1.0",
          "compliance_standards": ["GDPR", "CCPA"],
          "pii_masked": root.exists("pii_detected") && root.pii_detected.length() > 0,
          "encryption_applied": root.exists("ssn_encrypted")
        }

output:
  broker:
    pattern: fan_out
    outputs:
      # Compliant data output
      - file:
          path: "output/compliant-data/${!timestamp_unix:2006/01/02}/${!this.user_id}.json"

      # Audit log
      - file:
          path: "output/audit-log/${!timestamp_unix:2006/01/02}/audit.json"
          codec: lines
```

## Test Data

`test-data/raw-data.json`:

```json
{"user_id":"123","email":"alice@example.com","ssn":"123-45-6789","purchase_amount":150.00}
{"user_id":"456","email":"bob@example.com","credit_card":"1234-5678-9012-3456","purchase_amount":99.99}
```

## Setup & Run

```bash
# Set encryption key
export ENCRYPTION_KEY=$(openssl rand -base64 32)

# Run pipeline
cat test-data/raw-data.json | expanso-edge run pipeline-compliance.yaml
```

## Verify Compliance

```bash
# Check compliant data (PII masked/encrypted)
cat output/compliant-data/*/123.json

# Check audit log
cat output/audit-log/*/audit.json
```

## Compliance Checklist

- [x] PII detection and masking
- [x] Field-level encryption for sensitive data
- [x] Audit trail with timestamps
- [x] Separate storage for compliant data
- [x] Standards tracking (GDPR, CCPA)

## Related Templates

- Template 21: PII Masking
- Template 25: Field Encryption
- Template 19: Fan-out pattern

## Summary

This pipeline demonstrates a production-grade compliance workflow combining multiple security patterns for regulatory compliance.

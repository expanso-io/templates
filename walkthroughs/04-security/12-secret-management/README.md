# Walkthrough 12: Secret Management

**Track:** Security & Compliance
**Difficulty:** Beginner
**Time:** 20 minutes
**Prerequisites:** W01, W03

## Overview

Learn secure credential handling using environment variables and best practices.

## Best Practices

1. **Use Environment Variables**
```yaml
output:
  aws_s3:
    bucket: "${S3_BUCKET}"
    credentials:
      id: "${AWS_ACCESS_KEY_ID}"
      secret: "${AWS_SECRET_ACCESS_KEY}"
```

2. **Never Commit Credentials**
```bash
# Add to .gitignore
.env
credentials.json
*.key
```

3. **Use IAM Roles in Production**
- AWS: IAM roles for EC2/ECS
- GCP: Workload Identity
- Azure: Managed Identity

## The Pipeline

`pipeline-secure.yaml`:

```yaml
input:
  stdin:
    codec: lines

pipeline:
  processors:
    - mapping: |
        root = this
        root.api_key = "${API_KEY}"  # From environment
        root.processed = true

output:
  stdout:
    codec: lines
```

## Run It

```bash
export API_KEY="your-secret-key"
echo '{"data":"test"}' | expanso-edge run pipeline-secure.yaml
```

## Security Checklist

- [ ] Use environment variables for all credentials
- [ ] Add credential files to .gitignore
- [ ] Use IAM roles/Managed Identity in production
- [ ] Rotate credentials regularly
- [ ] Enable audit logging

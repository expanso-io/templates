# Walkthrough 03: From Template to Cloud

**Level**: Beginner
**Time**: 15 minutes
**Prerequisites**:
- Completed Walkthrough 01 & 02
- AWS account with S3 access (or use local simulation mode)
- AWS credentials configured (optional for simulation)

## Overview

This walkthrough teaches you how to adapt a template from the repository for your own use case and deploy it to cloud storage. You'll learn about environment variables, credential management, and the path from local testing to production deployment.

## What You'll Learn

- How to customize repository templates
- Using environment variables for configuration
- Credential management best practices
- Local testing before cloud deployment
- Writing to S3 with date partitioning

## The Journey: Local → Cloud

```
1. Find template     → Choose from repository
2. Test locally      → Use stdin to simulate data
3. Configure        → Set environment variables
4. Test with cloud  → Deploy to actual S3
5. Verify           → Check output in S3 bucket
```

## Exercise 1: Choose and Customize a Template

### Step 1: Review the Template

We'll start with `templates/outputs/to-s3.yaml` (which we'll create in this walkthrough as a reference).

The template has three customization points:
- **Input**: Where data comes from
- **Processing**: Optional transformations
- **Output**: S3 configuration

### Step 2: Understand Environment Variables

Open `pipeline-to-s3.yaml`. Notice the `${VAR_NAME:default}` syntax:

```yaml
bucket: "${S3_BUCKET}"  # Required, no default
prefix: "${S3_PREFIX:data/}"  # Optional, defaults to "data/"
```

This pattern lets you:
- Keep credentials out of YAML files
- Reuse pipelines across environments (dev/staging/prod)
- Override defaults without editing files

## Exercise 2: Test Locally (Without S3)

Before touching AWS, test the pipeline logic locally.

### Step 1: Use Stdout Instead of S3

Open `pipeline-local-test.yaml`. This version uses `stdout` instead of `aws_s3` so you can verify transformations without cloud access.

### Step 2: Run with Test Data

```bash
cd walkthroughs/01-getting-started/03-from-template-to-cloud
cat test-data/sample-events.json | expanso-edge run pipeline-local-test.yaml
```

### Step 3: Verify Output Format

Check that the output matches your expectations before sending to S3.

## Exercise 3: Configure AWS Credentials

### Option A: Use AWS Credential Chain (Recommended)

Expanso uses the standard AWS SDK credential chain:
1. Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
2. AWS credentials file (`~/.aws/credentials`)
3. IAM instance profile (for EC2/ECS deployments)

```bash
# Using AWS CLI configuration
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID="your-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"
```

### Option B: Use AWS Profiles

```bash
export AWS_PROFILE="my-profile"
```

### Security Best Practices

⚠️ **NEVER commit credentials to version control**

✓ Use `~/.aws/credentials` for local development
✓ Use IAM roles for production deployments
✓ Use environment variables in CI/CD pipelines
✓ Rotate credentials regularly

## Exercise 4: Deploy to S3

Now let's run the actual cloud deployment.

### Step 1: Create an S3 Bucket (if needed)

```bash
aws s3 mb s3://my-expanso-test-bucket --region us-east-1
```

### Step 2: Configure Environment Variables

```bash
export S3_BUCKET="my-expanso-test-bucket"
export S3_PREFIX="expanso-data/"
export AWS_REGION="us-east-1"
```

### Step 3: Run the Pipeline

```bash
cat test-data/sample-events.json | expanso-edge run pipeline-to-s3.yaml
```

### Step 4: Verify Data in S3

```bash
# List objects in your bucket
aws s3 ls s3://${S3_BUCKET}/${S3_PREFIX} --recursive

# Download and view a file
aws s3 cp s3://${S3_BUCKET}/${S3_PREFIX}2026/01/11/data.json - | head
```

## Exercise 5: Add Date Partitioning

Date partitioning organizes data by time, improving query performance and cost.

### Step 1: Review Partitioning Config

Open `pipeline-to-s3.yaml` and find the `path` configuration:

```yaml
path: "${S3_PREFIX}${!timestamp_unix:2006}/\
${!timestamp_unix:01}/${!timestamp_unix:02}/data-\
${!count:timestamp_unix_nano}.json"
```

This creates paths like:
```
expanso-data/2026/01/11/data-1736637600123456789.json
```

### Step 2: Run with Partitioning

```bash
cat test-data/sample-events.json | expanso-edge run pipeline-to-s3.yaml
```

### Step 3: Verify Partitioning

```bash
aws s3 ls s3://${S3_BUCKET}/${S3_PREFIX}2026/ --recursive
```

You should see organized folders by year/month/day.

## Expected Output

After completing this walkthrough:
- ✓ Tested pipeline locally with stdout
- ✓ Configured AWS credentials securely
- ✓ Deployed data to S3
- ✓ Verified data with date partitioning

See `expected-output/` for S3 object examples.

## Key Takeaways

✓ Templates are starting points - customize for your needs
✓ Test locally with stdout before deploying to cloud
✓ Use environment variables for all configuration
✓ Never commit credentials to version control
✓ Date partitioning improves data organization
✓ Use AWS credential chain for flexible auth

## Production Checklist

Before deploying to production:
- [ ] Credentials use IAM roles, not access keys
- [ ] S3 bucket has encryption enabled
- [ ] Bucket policy restricts access appropriately
- [ ] Pipeline tested with production-like data volume
- [ ] Monitoring/alerting configured
- [ ] Dead-letter queue configured for failures (see W10)

## Next Steps

- **Walkthrough 04**: Parsing Logs at the Edge - Transform unstructured data
- **Walkthrough 16**: AWS Integration Suite - Advanced S3 patterns
- **Template**: `templates/patterns/dead-letter-queue.yaml` - Add error handling

## Related Templates

- `templates/outputs/to-s3.yaml` - Full S3 output configuration
- `templates/outputs/to-azure-blob.yaml` - Azure alternative
- `templates/outputs/to-bigquery.yaml` - GCP alternative

## Troubleshooting

**Q: "Access Denied" error from S3**
A: Check IAM permissions. Your credentials need `s3:PutObject` permission on the bucket.

**Q: "NoSuchBucket" error**
A: Create the bucket first with `aws s3 mb s3://bucket-name` or use an existing bucket.

**Q: Data not appearing in S3**
A: Check the bucket and prefix. List with: `aws s3 ls s3://${S3_BUCKET}/${S3_PREFIX} --recursive`

**Q: How do I use Azure/GCP instead?**
A: Replace `aws_s3` output with `azure_blob_storage` or `gcp_cloud_storage`. See related templates above.

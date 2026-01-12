# Walkthrough 01: Your First Pipeline

**Level**: Beginner
**Time**: 10 minutes
**Prerequisites**: Expanso CLI installed (`expanso-edge` available in PATH)

## Overview

This walkthrough introduces you to Expanso pipelines by running two simple examples. You'll learn the basic anatomy of a pipeline YAML file and how to execute it with `expanso-edge run`.

## What You'll Learn

- Pipeline structure (input, processors, output)
- Running pipelines with `expanso-edge run`
- Testing with the `generate` input
- Reading from files with the `file` input

## Pipeline Anatomy

Every Expanso pipeline has three main sections:

```yaml
input:
  # Where data comes FROM

pipeline:
  # Optional: How to TRANSFORM data
  processors: []

output:
  # Where data goes TO
```

## Exercise 1: Generate Synthetic Data

Let's start with the simplest possible pipeline using synthetic test data.

### Step 1: Review the Pipeline

Open `pipeline-generate.yaml` in this directory. It uses the `generate` input to create test data and sends it to `stdout`.

Key components:
- **Input**: `generate` - creates synthetic sensor readings
- **Output**: `stdout` - prints to your terminal

### Step 2: Run the Pipeline

```bash
# Generate 5 test messages
cd walkthroughs/01-getting-started/01-your-first-pipeline
GEN_COUNT=5 expanso-edge run pipeline-generate.yaml
```

You should see JSON output like:

```json
{"id":"a7f3e2c1-...","timestamp":"2026-01-11T18:30:00Z","sensor_id":"sensor-42",...}
```

### Step 3: Experiment with Parameters

Try different configurations:

```bash
# Generate messages as fast as possible
GEN_INTERVAL=0 GEN_COUNT=10 expanso-edge run pipeline-generate.yaml

# Generate infinite stream (Ctrl+C to stop)
GEN_INTERVAL=1s GEN_COUNT=0 expanso-edge run pipeline-generate.yaml
```

## Exercise 2: Read from a File

Now let's read actual data from a file.

### Step 1: Review the Test Data

Open `test-data/sample-logs.txt` to see sample log entries.

### Step 2: Review the Pipeline

Open `pipeline-file.yaml`. This pipeline reads from a file and outputs to stdout.

Key components:
- **Input**: `file` - reads from a file path
- **Codec**: `lines` - treats each line as a separate message

### Step 3: Run the Pipeline

```bash
FILE_PATH=test-data/sample-logs.txt expanso-edge run pipeline-file.yaml
```

You should see each log line printed to your terminal.

### Step 4: Understand the Output

Notice that:
- Each line becomes a separate message
- Messages are processed in order
- The pipeline exits after processing all lines

## Expected Output

After completing both exercises, you should have:

1. Generated 5+ synthetic JSON sensor readings
2. Read and printed sample log file contents
3. Understood the basic pipeline structure

See `expected-output/` for example outputs.

## Key Takeaways

✓ Pipelines have three sections: input, processors (optional), output
✓ Use `expanso-edge run <file.yaml>` to execute pipelines
✓ Environment variables configure pipeline behavior
✓ The `generate` input is great for testing
✓ The `file` input reads data from disk

## Next Steps

- **Walkthrough 02**: Understanding Bloblang - Learn to transform data
- **Walkthrough 03**: From Template to Cloud - Deploy to S3

## Related Templates

- `templates/inputs/file-to-stdout.yaml` - Simple file reader
- `templates/inputs/generate-test-data.yaml` - Synthetic data generator

## Troubleshooting

**Q: "command not found: expanso-edge"**
A: Ensure Expanso CLI is installed and in your PATH. See [installation docs](https://docs.expanso.io/getting-started/installation).

**Q: "file not found" error**
A: Use absolute paths or ensure FILE_PATH is relative to where you run the command.

**Q: Pipeline runs but no output**
A: Check that GEN_COUNT > 0 for the generate pipeline, or that the input file exists and has content.

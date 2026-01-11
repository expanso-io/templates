# Contributing to Expanso Templates

Thank you for your interest in contributing! This guide explains how to add new templates and walkthroughs.

## Quick Start

1. **Clone the repo**
   ```bash
   git clone https://github.com/expanso/expanso-templates.git
   cd expanso-templates
   ```

2. **Install git hooks**
   ```bash
   ./scripts/install-hooks.sh
   ```

3. **Find work to do**
   ```bash
   bd ready  # Shows available issues
   ```

## Contribution Process

### 1. Issue First

Before starting work, open an issue or claim an existing one:

```bash
# See available work
bd ready

# Claim an issue
bd update <issue-id> --status=in_progress
```

### 2. Create Your Template/Walkthrough

**Templates** go in `templates/<category>/`:
- `inputs/` - Source connectors
- `outputs/` - Destination connectors
- `processors/` - Transformation patterns
- `patterns/` - Multi-component patterns

**Walkthroughs** go in `walkthroughs/<track>/`:
- `01-getting-started/`
- `02-transformations/`
- `03-routing/`
- `04-security/`
- `05-integrations/`
- `06-advanced/`

### 3. Follow the Standards

#### Template Header (Required)

Every template MUST include this header:

```yaml
# Template: <template-name>
# Description: <one-line description>
# Components: <input> → <processors> → <output>
# Docs: https://docs.expanso.io/components/<component>
#
# Usage:
#   expanso-edge run templates/<category>/<template-name>.yaml
#
# Configuration:
#   - ENV_VAR: Description of what to set

input:
  # ...
```

#### Security Warning (Required for credentials)

If your template uses credentials:

```yaml
# ## SECURITY WARNING ##
# This template requires credentials. NEVER commit real secrets.
# Use environment variables: ${AWS_ACCESS_KEY_ID}
# See: walkthroughs/04-security/secret-management/
```

#### Walkthrough Structure (Required)

```
walkthroughs/<track>/<walkthrough-name>/
├── README.md           # Full tutorial
├── pipeline.yaml       # Working pipeline
├── test-data/          # Sample input
│   └── sample.json
└── expected-output/    # Expected results
    └── output.json
```

### 4. Validate Before Committing

```bash
# Validate a single file
expanso-cli job validate templates/inputs/my-template.yaml

# Validate all files
./scripts/validate-pipelines.sh
```

The pre-commit hook will also validate automatically.

### 5. Submit Your PR

```bash
# Stage and commit
git add .
git commit -m "Add <template-name>: <description>"

# Close the issue
bd close <issue-id>

# Push and create PR
git push -u origin <branch-name>
gh pr create --draft --title "Add <template-name>"
```

## Parallel Development with Worktrees

For working on multiple templates simultaneously:

```bash
# Launch worktrees for available work
./scripts/swarm-launch.sh --count 3 --priority P1

# List active worktrees
git worktree list

# Work in a worktree
cd .worktrees/<template-name>
# ... make changes ...
git commit -m "Implement template"
bd close <issue-id>
```

## Validation Scripts

| Script | Purpose |
|--------|---------|
| `scripts/validate-pipelines.sh` | Validate all YAML files |
| `scripts/update-and-validate.sh` | Re-validate after binary updates |
| `scripts/swarm-launch.sh` | Set up parallel worktrees |
| `scripts/install-hooks.sh` | Install git hooks |

## Code Review Checklist

- [ ] YAML passes `expanso-cli job validate`
- [ ] Header comment block is complete
- [ ] Security warning present (if credentials used)
- [ ] No hardcoded secrets (use `${ENV_VAR}` syntax)
- [ ] Test data included for walkthroughs
- [ ] README is clear and follows template

## Getting Help

- [Expanso Documentation](https://docs.expanso.io/)
- [Components Reference](https://docs.expanso.io/components/)
- [Bloblang Guide](https://docs.expanso.io/getting-started/core-concepts/)

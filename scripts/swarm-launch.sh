#!/usr/bin/env bash
# Launch parallel Claude agents on multiple beads using worktrees
# Usage: ./scripts/swarm-launch.sh [--count N] [--priority P1|P2|P3|P4] [--prefix T|W]
#
# This script:
# 1. Gets available beads matching filters
# 2. Creates worktrees for each
# 3. Launches Claude agents in parallel (tmux or background)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
WORKTREES_DIR="$REPO_ROOT/.worktrees"

# Defaults
COUNT=5
PRIORITY=""
PREFIX=""
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --count|-n)
            COUNT="$2"
            shift 2
            ;;
        --priority|-p)
            PRIORITY="$2"
            shift 2
            ;;
        --prefix)
            PREFIX="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--count N] [--priority P1|P2|P3|P4] [--prefix T|W]"
            echo ""
            echo "Options:"
            echo "  --count N      Number of agents to launch (default: 5)"
            echo "  --priority P   Filter by priority (P1, P2, P3, P4)"
            echo "  --prefix T|W   Filter by prefix (T=templates, W=walkthroughs)"
            echo "  --dry-run      Show what would be done without doing it"
            echo ""
            echo "Examples:"
            echo "  $0 --count 3 --priority P1        # 3 agents on P1 items"
            echo "  $0 --prefix T --count 5           # 5 agents on templates"
            echo "  $0 --priority P1 --prefix T       # All P1 templates"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Swarm Launch - Parallel Agent Development${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Build bd command to get ready issues
BD_CMD="bd ready"
if [[ -n "$PRIORITY" ]]; then
    BD_CMD="bd list --status=open --priority=$PRIORITY"
fi

echo -e "${CYAN}Finding available work items...${NC}"

# Get issues
ISSUES=$(eval "$BD_CMD" 2>/dev/null | grep -E "^\w+-\w+" | head -"$COUNT" || true)

if [[ -z "$ISSUES" ]]; then
    echo -e "${YELLOW}No matching issues found${NC}"
    exit 0
fi

# Filter by prefix if specified
if [[ -n "$PREFIX" ]]; then
    ISSUES=$(echo "$ISSUES" | grep "\[$PREFIX" || true)
fi

if [[ -z "$ISSUES" ]]; then
    echo -e "${YELLOW}No issues match prefix filter [$PREFIX]${NC}"
    exit 0
fi

# Count and display
ISSUE_COUNT=$(echo "$ISSUES" | wc -l | tr -d ' ')
echo -e "Found ${GREEN}$ISSUE_COUNT${NC} issue(s) to work on"
echo ""

# Create worktrees directory
mkdir -p "$WORKTREES_DIR"

# Process each issue
LAUNCHED=0
while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    # Extract issue ID and title
    ISSUE_ID=$(echo "$line" | awk '{print $1}')
    ISSUE_TITLE=$(echo "$line" | cut -d']' -f2- | sed 's/^ *//')

    # Create branch name from title
    BRANCH_NAME=$(echo "$ISSUE_TITLE" | \
        sed 's/\[T\([0-9]*\)\]/t\1/' | \
        sed 's/\[W\([0-9]*\)\]/w\1/' | \
        tr '[:upper:]' '[:lower:]' | \
        tr ' ' '-' | \
        sed 's/[^a-z0-9-]//g' | \
        cut -c1-50)

    WORKTREE_PATH="$WORKTREES_DIR/$BRANCH_NAME"

    echo -e "${CYAN}Processing: $ISSUE_ID${NC}"
    echo -e "  Title: $ISSUE_TITLE"
    echo -e "  Branch: $BRANCH_NAME"
    echo -e "  Worktree: $WORKTREE_PATH"

    if $DRY_RUN; then
        echo -e "  ${YELLOW}[DRY RUN] Would create worktree and launch agent${NC}"
        continue
    fi

    # Create branch if it doesn't exist
    if ! git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
        git -C "$REPO_ROOT" branch "$BRANCH_NAME" main 2>/dev/null || true
    fi

    # Create worktree if it doesn't exist
    if [[ ! -d "$WORKTREE_PATH" ]]; then
        git -C "$REPO_ROOT" worktree add "$WORKTREE_PATH" "$BRANCH_NAME" 2>/dev/null || {
            echo -e "  ${RED}Failed to create worktree${NC}"
            continue
        }
    fi

    # Mark issue as in_progress
    bd update "$ISSUE_ID" --status=in_progress 2>/dev/null || true

    # Create agent instructions file
    cat > "$WORKTREE_PATH/.claude-task" << EOF
# Task: $ISSUE_TITLE
# Issue: $ISSUE_ID
# Branch: $BRANCH_NAME

## Instructions

Implement this template/walkthrough according to the PRD specification.

1. Read PRD.md for the full specification
2. Check CLAUDE.md for coding standards
3. Create the YAML file with proper header comments
4. Validate with: expanso-cli job validate <file>
5. When done, commit and close the bead:
   - git add .
   - git commit -m "Implement $ISSUE_ID: $ISSUE_TITLE"
   - bd close $ISSUE_ID

## Template Location

For templates [T##]: templates/<category>/<name>.yaml
For walkthroughs [W##]: walkthroughs/<track>/<name>/

Refer to PRD.md Content Specification for exact paths.
EOF

    echo -e "  ${GREEN}✓ Worktree ready${NC}"
    ((LAUNCHED++))

done <<< "$ISSUES"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Launched $LAUNCHED worktree(s)${NC}"
echo ""

# Show worktree list
echo -e "${CYAN}Active worktrees:${NC}"
git -C "$REPO_ROOT" worktree list

echo ""
echo -e "${CYAN}To work on a specific worktree:${NC}"
echo -e "  cd $WORKTREES_DIR/<name>"
echo -e "  claude  # or your preferred editor"
echo ""
echo -e "${CYAN}To launch Claude in all worktrees (tmux):${NC}"
echo -e "  for wt in $WORKTREES_DIR/*/; do"
echo -e "    tmux new-window -n \"\$(basename \$wt)\" \"cd \$wt && claude\""
echo -e "  done"

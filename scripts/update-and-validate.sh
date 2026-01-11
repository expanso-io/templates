#!/usr/bin/env bash
# Update workflow: Re-validate all pipelines after binary updates
# Usage: ./scripts/update-and-validate.sh [--auto-fix] [--report]
#
# This script is designed to be run after updating expanso-cli/expanso-edge
# to detect and optionally fix breaking changes across all templates.

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
REPORT_FILE="$REPO_ROOT/.update-report-$(date +%Y%m%d-%H%M%S).md"

AUTO_FIX=false
GENERATE_REPORT=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto-fix)
            AUTO_FIX=true
            shift
            ;;
        --report)
            GENERATE_REPORT=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--auto-fix] [--report]"
            echo ""
            echo "Options:"
            echo "  --auto-fix   Create git branches with fixes for each broken template"
            echo "  --report     Generate a markdown report of all issues"
            echo ""
            echo "This script validates all templates after an expanso binary update"
            echo "and helps identify what needs to be fixed."
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Get current expanso versions
get_versions() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Expanso Binary Update Workflow${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    echo -e "${CYAN}Current versions:${NC}"

    if command -v expanso-cli &> /dev/null; then
        local cli_version
        cli_version=$(expanso-cli --version 2>/dev/null | head -1 || echo "unknown")
        echo -e "  expanso-cli: ${GREEN}$cli_version${NC}"
    else
        echo -e "  expanso-cli: ${RED}NOT FOUND${NC}"
    fi

    if command -v expanso-edge &> /dev/null; then
        local edge_version
        edge_version=$(expanso-edge --version 2>/dev/null | head -1 || echo "unknown")
        echo -e "  expanso-edge: ${GREEN}$edge_version${NC}"
    else
        echo -e "  expanso-edge: ${RED}NOT FOUND${NC}"
    fi

    echo ""
}

# Initialize report
init_report() {
    if $GENERATE_REPORT; then
        cat > "$REPORT_FILE" << EOF
# Expanso Templates Update Report

**Generated:** $(date)
**expanso-cli version:** $(expanso-cli --version 2>/dev/null | head -1 || echo "unknown")
**expanso-edge version:** $(expanso-edge --version 2>/dev/null | head -1 || echo "unknown")

## Summary

EOF
    fi
}

# Validate all files and collect results
validate_all() {
    local failed_templates=()
    local failed_walkthroughs=()
    local passed_count=0
    local total_count=0

    echo -e "${BLUE}Validating all pipeline files...${NC}"
    echo ""

    # Find all YAML files
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        ((total_count++))

        local relative="${file#$REPO_ROOT/}"
        local output
        local exit_code=0

        output=$(expanso-cli job validate "$file" 2>&1) || exit_code=$?

        if [[ $exit_code -eq 0 ]]; then
            ((passed_count++))
            echo -e "${GREEN}✓${NC} $relative"
        else
            echo -e "${RED}✗${NC} $relative"

            if [[ "$relative" == templates/* ]]; then
                failed_templates+=("$relative|$output")
            else
                failed_walkthroughs+=("$relative|$output")
            fi
        fi
    done < <(find "$REPO_ROOT/templates" "$REPO_ROOT/walkthroughs" \
        \( -name "*.yaml" -o -name "*.yml" \) -type f 2>/dev/null | sort)

    # Print summary
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Results${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "Total files: $total_count"
    echo -e "${GREEN}Passed: $passed_count${NC}"
    echo -e "${RED}Failed: $((${#failed_templates[@]} + ${#failed_walkthroughs[@]}))${NC}"

    # Generate detailed report
    if $GENERATE_REPORT; then
        {
            echo "| Status | Count |"
            echo "|--------|-------|"
            echo "| Passed | $passed_count |"
            echo "| Failed Templates | ${#failed_templates[@]} |"
            echo "| Failed Walkthroughs | ${#failed_walkthroughs[@]} |"
            echo "| **Total** | **$total_count** |"
            echo ""
        } >> "$REPORT_FILE"
    fi

    # List failed templates
    if [[ ${#failed_templates[@]} -gt 0 ]]; then
        echo ""
        echo -e "${RED}Failed Templates:${NC}"

        if $GENERATE_REPORT; then
            echo "## Failed Templates" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
        fi

        for entry in "${failed_templates[@]}"; do
            local file="${entry%%|*}"
            local error="${entry#*|}"

            echo -e "  ${RED}•${NC} $file"
            echo "$error" | head -5 | sed 's/^/      /'

            if $GENERATE_REPORT; then
                {
                    echo "### \`$file\`"
                    echo ""
                    echo "\`\`\`"
                    echo "$error"
                    echo "\`\`\`"
                    echo ""
                } >> "$REPORT_FILE"
            fi

            # Auto-fix mode: create a branch for each broken template
            if $AUTO_FIX; then
                create_fix_branch "$file" "$error"
            fi
        done
    fi

    # List failed walkthroughs
    if [[ ${#failed_walkthroughs[@]} -gt 0 ]]; then
        echo ""
        echo -e "${RED}Failed Walkthroughs:${NC}"

        if $GENERATE_REPORT; then
            echo "## Failed Walkthroughs" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
        fi

        for entry in "${failed_walkthroughs[@]}"; do
            local file="${entry%%|*}"
            local error="${entry#*|}"

            echo -e "  ${RED}•${NC} $file"
            echo "$error" | head -5 | sed 's/^/      /'

            if $GENERATE_REPORT; then
                {
                    echo "### \`$file\`"
                    echo ""
                    echo "\`\`\`"
                    echo "$error"
                    echo "\`\`\`"
                    echo ""
                } >> "$REPORT_FILE"
            fi
        done
    fi

    if $GENERATE_REPORT; then
        echo ""
        echo -e "${CYAN}Report written to: $REPORT_FILE${NC}"
    fi

    # Return appropriate exit code
    if [[ ${#failed_templates[@]} -gt 0 ]] || [[ ${#failed_walkthroughs[@]} -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Create a worktree branch for fixing a specific template
create_fix_branch() {
    local file="$1"
    local error="$2"

    # Extract template name for branch
    local template_name
    template_name=$(basename "$file" .yaml)
    local branch_name="fix/$template_name-$(date +%Y%m%d)"

    echo -e "    ${YELLOW}Creating fix branch: $branch_name${NC}"

    # Check if branch already exists
    if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$branch_name" 2>/dev/null; then
        echo -e "    ${YELLOW}Branch already exists, skipping${NC}"
        return 0
    fi

    # Create branch from current HEAD
    git -C "$REPO_ROOT" branch "$branch_name" 2>/dev/null || true

    # Create a worktree for parallel development
    local worktree_path="$REPO_ROOT/.worktrees/$template_name"
    if [[ ! -d "$worktree_path" ]]; then
        git -C "$REPO_ROOT" worktree add "$worktree_path" "$branch_name" 2>/dev/null || true
    fi

    echo -e "    ${GREEN}Worktree created at: .worktrees/$template_name${NC}"
}

# Main
main() {
    get_versions
    init_report

    if validate_all; then
        echo ""
        echo -e "${GREEN}All pipelines are valid! No updates needed.${NC}"
        exit 0
    else
        echo ""
        echo -e "${YELLOW}Some pipelines need attention.${NC}"

        if $AUTO_FIX; then
            echo -e "${CYAN}Fix branches and worktrees have been created.${NC}"
            echo -e "Run: ${BLUE}git worktree list${NC} to see all worktrees"
        fi

        exit 1
    fi
}

main "$@"

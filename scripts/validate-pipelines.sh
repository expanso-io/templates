#!/usr/bin/env bash
# Validate all Expanso pipeline YAML files
# Usage: ./scripts/validate-pipelines.sh [--fix] [--verbose] [file1.yaml file2.yaml ...]
#
# Exit codes:
#   0 - All validations passed
#   1 - Validation failed
#   2 - Missing dependencies

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
VERBOSE=false
FIX_MODE=false
SPECIFIC_FILES=()
FAILED_FILES=()
PASSED_FILES=()
SKIPPED_FILES=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --fix)
            FIX_MODE=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--fix] [--verbose] [file1.yaml file2.yaml ...]"
            echo ""
            echo "Options:"
            echo "  --fix       Attempt to fix common issues (not yet implemented)"
            echo "  --verbose   Show detailed output for each file"
            echo "  --help      Show this help message"
            echo ""
            echo "If no files specified, validates all YAML files in templates/ and walkthroughs/"
            exit 0
            ;;
        *.yaml|*.yml)
            SPECIFIC_FILES+=("$1")
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Check for expanso-cli
check_dependencies() {
    if ! command -v expanso-cli &> /dev/null; then
        echo -e "${RED}Error: expanso-cli not found in PATH${NC}"
        echo "Install from: https://docs.expanso.io/getting-started/installation/"
        exit 2
    fi

    if $VERBOSE; then
        echo -e "${BLUE}Using expanso-cli: $(which expanso-cli)${NC}"
        expanso-cli --version 2>/dev/null || true
    fi
}

# Validate a single YAML file
validate_file() {
    local file="$1"
    local relative_path="${file#$REPO_ROOT/}"

    # Skip empty files
    if [[ ! -s "$file" ]]; then
        SKIPPED_FILES+=("$relative_path (empty)")
        return 0
    fi

    # Skip non-pipeline files (like CI workflows, etc.)
    if [[ "$file" == *".github"* ]]; then
        SKIPPED_FILES+=("$relative_path (not a pipeline)")
        return 0
    fi

    if $VERBOSE; then
        echo -e "${BLUE}Validating: $relative_path${NC}"
    fi

    # Run validation
    local output
    local exit_code=0
    output=$(expanso-cli job validate "$file" 2>&1) || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        PASSED_FILES+=("$relative_path")
        if $VERBOSE; then
            echo -e "${GREEN}  ✓ Valid${NC}"
        fi
        return 0
    else
        FAILED_FILES+=("$relative_path")
        echo -e "${RED}✗ FAILED: $relative_path${NC}"
        echo "$output" | sed 's/^/    /'
        return 1
    fi
}

# Find all YAML files to validate
find_yaml_files() {
    if [[ ${#SPECIFIC_FILES[@]} -gt 0 ]]; then
        printf '%s\n' "${SPECIFIC_FILES[@]}"
    else
        find "$REPO_ROOT/templates" "$REPO_ROOT/walkthroughs" \
            -name "*.yaml" -o -name "*.yml" 2>/dev/null | sort
    fi
}

# Main validation loop
main() {
    check_dependencies

    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Expanso Pipeline Validation${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    local files
    mapfile -t files < <(find_yaml_files)

    if [[ ${#files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No YAML files found to validate${NC}"
        exit 0
    fi

    echo -e "Found ${#files[@]} file(s) to validate"
    echo ""

    local has_failures=false

    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            validate_file "$file" || has_failures=true
        fi
    done

    # Print summary
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Summary${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

    if [[ ${#PASSED_FILES[@]} -gt 0 ]]; then
        echo -e "${GREEN}✓ Passed: ${#PASSED_FILES[@]}${NC}"
    fi

    if [[ ${#SKIPPED_FILES[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⊘ Skipped: ${#SKIPPED_FILES[@]}${NC}"
        if $VERBOSE; then
            for f in "${SKIPPED_FILES[@]}"; do
                echo -e "    ${YELLOW}$f${NC}"
            done
        fi
    fi

    if [[ ${#FAILED_FILES[@]} -gt 0 ]]; then
        echo -e "${RED}✗ Failed: ${#FAILED_FILES[@]}${NC}"
        for f in "${FAILED_FILES[@]}"; do
            echo -e "    ${RED}$f${NC}"
        done
        echo ""
        echo -e "${RED}Validation FAILED${NC}"
        exit 1
    fi

    echo ""
    echo -e "${GREEN}All validations passed!${NC}"
    exit 0
}

main "$@"

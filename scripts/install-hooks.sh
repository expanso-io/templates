#!/usr/bin/env bash
# Install git hooks for this repository
# Usage: ./scripts/install-hooks.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

echo "Installing git hooks..."

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_DIR"

# Create pre-commit hook
cat > "$HOOKS_DIR/pre-commit" << 'HOOK'
#!/usr/bin/env bash
# Pre-commit hook: Validate all changed pipeline YAML files

set -euo pipefail

# Colors (disable if not a terminal)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

echo -e "${BLUE}🔍 Pre-commit: Validating Expanso pipelines...${NC}"

# Check if expanso-cli is available
if ! command -v expanso-cli &> /dev/null; then
    echo -e "${YELLOW}⚠️  expanso-cli not found - skipping validation${NC}"
    exit 0
fi

# Get staged YAML files in templates/ or walkthroughs/
STAGED_YAMLS=$(git diff --cached --name-only --diff-filter=ACM | \
    grep -E '^(templates|walkthroughs)/.*\.(yaml|yml)$' || true)

if [[ -z "$STAGED_YAMLS" ]]; then
    echo -e "${GREEN}✓ No pipeline files staged${NC}"
    exit 0
fi

FILE_COUNT=$(echo "$STAGED_YAMLS" | wc -l | tr -d ' ')
echo -e "  Found $FILE_COUNT pipeline file(s) to validate"

FAILED=()
PASSED=0

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ ! -s "$file" ]] && continue

    if expanso-cli job validate "$file" > /dev/null 2>&1; then
        ((PASSED++))
        echo -e "  ${GREEN}✓${NC} $file"
    else
        FAILED+=("$file")
        echo -e "  ${RED}✗${NC} $file"
        expanso-cli job validate "$file" 2>&1 | head -10 | sed 's/^/      /'
    fi
done <<< "$STAGED_YAMLS"

echo ""
if [[ ${#FAILED[@]} -eq 0 ]]; then
    echo -e "${GREEN}✓ All $PASSED pipeline(s) valid${NC}"
    exit 0
else
    echo -e "${RED}✗ Validation failed for ${#FAILED[@]} file(s)${NC}"
    echo -e "${YELLOW}Fix issues or use 'git commit --no-verify' to bypass${NC}"
    exit 1
fi
HOOK

chmod +x "$HOOKS_DIR/pre-commit"

echo "✓ Pre-commit hook installed"
echo ""
echo "Hooks will now validate all pipeline YAML files before each commit."
echo "To bypass (not recommended): git commit --no-verify"

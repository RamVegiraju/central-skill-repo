#!/bin/bash
#
# Push Skills to Genie Code
#
# Pushes skills from multiple local sources to the Databricks workspace
# for Genie Code / Assistant, skipping any that already exist.
#
# By default, scans two sources:
#   1. This repo directory (skills at top level with SKILL.md)
#   2. ~/.claude/skills/ (skills installed via AI Dev Kit)
#
# Usage:
#   ./push_skills_to_genie.sh                         # Push missing skills only
#   ./push_skills_to_genie.sh --force                 # Push all skills (overwrite existing)
#   ./push_skills_to_genie.sh --profile prod          # Use a specific Databricks CLI profile
#   ./push_skills_to_genie.sh --dry-run               # Show what would be uploaded without doing it
#   ./push_skills_to_genie.sh --repo-only             # Only push skills from this repo
#   ./push_skills_to_genie.sh --claude-only            # Only push skills from ~/.claude/skills
#   ./push_skills_to_genie.sh databricks-bundles agent-evaluation  # Push specific skills only
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Defaults
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"
DB_PROFILE="${DATABRICKS_CONFIG_PROFILE:-DEFAULT}"
FORCE=false
DRY_RUN=false
LIST_MODE=false
REPO_ONLY=false
CLAUDE_ONLY=false
SPECIFIC_SKILLS=""

# Parse arguments
while [ $# -gt 0 ]; do
    case $1 in
        --help|-h)
            echo -e "${BLUE}Push Skills to Genie Code${NC}"
            echo ""
            echo "Pushes skills from local sources to your Databricks workspace"
            echo "for Genie Code / Assistant. Scans two sources by default:"
            echo "  1. This repo (skills with SKILL.md at top level)"
            echo "  2. ~/.claude/skills/ (AI Dev Kit installed skills)"
            echo ""
            echo "When the same skill exists in both sources, the repo version wins."
            echo "Skills already in the workspace are skipped unless --force is used."
            echo ""
            echo "Usage:"
            echo "  ./push_skills_to_genie.sh [options] [skill1 skill2 ...]"
            echo ""
            echo "Options:"
            echo "  --help, -h           Show this help message"
            echo "  --force, -f          Overwrite existing skills in workspace"
            echo "  --dry-run, -n        Show what would be uploaded without doing it"
            echo "  --profile <name>     Databricks CLI profile (default: DEFAULT or \$DATABRICKS_CONFIG_PROFILE)"
            echo "  --repo-only          Only push skills from this repo (skip ~/.claude/skills)"
            echo "  --claude-only        Only push skills from ~/.claude/skills (skip repo)"
            echo "  --list, -l           List all discovered skills and workspace status"
            echo ""
            echo "Examples:"
            echo "  ./push_skills_to_genie.sh                              # Push missing skills from all sources"
            echo "  ./push_skills_to_genie.sh --force                      # Push all, overwrite existing"
            echo "  ./push_skills_to_genie.sh --dry-run                    # Preview what would happen"
            echo "  ./push_skills_to_genie.sh --repo-only                  # Only push repo skills"
            echo "  ./push_skills_to_genie.sh databricks-bundles           # Push specific skill"
            echo "  ./push_skills_to_genie.sh --profile prod --force       # Force push with prod profile"
            exit 0
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --repo-only)
            REPO_ONLY=true
            shift
            ;;
        --claude-only)
            CLAUDE_ONLY=true
            shift
            ;;
        --profile)
            if [ -z "$2" ] || [ "${2:0:1}" = "-" ]; then
                echo -e "${RED}Error: --profile requires a profile name${NC}"
                exit 1
            fi
            DB_PROFILE="$2"
            shift 2
            ;;
        --list|-l)
            LIST_MODE=true
            shift
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information."
            exit 1
            ;;
        *)
            SPECIFIC_SKILLS="$SPECIFIC_SKILLS $1"
            shift
            ;;
    esac
done

if [ "$REPO_ONLY" = true ] && [ "$CLAUDE_ONLY" = true ]; then
    echo -e "${RED}Error: --repo-only and --claude-only are mutually exclusive${NC}"
    exit 1
fi

# Validate prerequisites
if ! command -v databricks >/dev/null 2>&1; then
    echo -e "${RED}Error: databricks CLI not found. Install it first:${NC}"
    echo "  pip install databricks-cli"
    exit 1
fi

# Discover skills from all sources into a temp file: "name|path|source" per line
# Repo entries overwrite ~/.claude/skills entries (higher priority)
SKILL_INDEX=$(mktemp)
trap "rm -f '$SKILL_INDEX'" EXIT

# Scan ~/.claude/skills first (lower priority)
if [ "$REPO_ONLY" != true ] && [ -d "$CLAUDE_SKILLS_DIR" ]; then
    for skill_dir in "$CLAUDE_SKILLS_DIR"/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        case "$skill_name" in .*) continue ;; esac
        [ -f "$skill_dir/SKILL.md" ] || continue
        echo "${skill_name}|${skill_dir%/}|claude" >> "$SKILL_INDEX"
    done
fi

# Scan repo directory (higher priority — removes and replaces ~/.claude/skills entries)
if [ "$CLAUDE_ONLY" != true ] && [ -d "$SCRIPT_DIR" ]; then
    for skill_dir in "$SCRIPT_DIR"/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        case "$skill_name" in .*|node_modules) continue ;; esac
        [ -f "$skill_dir/SKILL.md" ] || continue
        # Remove any existing entry for this skill (claude source) so repo wins
        grep -v "^${skill_name}|" "$SKILL_INDEX" > "${SKILL_INDEX}.tmp" 2>/dev/null || true
        mv "${SKILL_INDEX}.tmp" "$SKILL_INDEX"
        echo "${skill_name}|${skill_dir%/}|repo" >> "$SKILL_INDEX"
    done
fi

# Sort the index by skill name
sort -t'|' -k1,1 -o "$SKILL_INDEX" "$SKILL_INDEX"

TOTAL_SKILLS=$(wc -l < "$SKILL_INDEX" | tr -d ' ')

if [ "$TOTAL_SKILLS" -eq 0 ]; then
    echo -e "${RED}Error: No skills found in any source directory.${NC}"
    exit 1
fi

# Filter to specific skills if provided
SPECIFIC_SKILLS=$(echo "$SPECIFIC_SKILLS" | xargs)  # trim whitespace
if [ -n "$SPECIFIC_SKILLS" ]; then
    FILTERED_INDEX=$(mktemp)
    for requested in $SPECIFIC_SKILLS; do
        if grep -q "^${requested}|" "$SKILL_INDEX"; then
            grep "^${requested}|" "$SKILL_INDEX" >> "$FILTERED_INDEX"
        else
            echo -e "${YELLOW}Warning: Skill '$requested' not found in any source, skipping${NC}"
        fi
    done
    mv "$FILTERED_INDEX" "$SKILL_INDEX"
    TOTAL_SKILLS=$(wc -l < "$SKILL_INDEX" | tr -d ' ')
fi

# Helper: look up a field for a skill from the index
skill_path() { grep "^${1}|" "$SKILL_INDEX" | head -1 | cut -d'|' -f2; }
skill_source() { grep "^${1}|" "$SKILL_INDEX" | head -1 | cut -d'|' -f3; }
skill_names() { cut -d'|' -f1 "$SKILL_INDEX"; }
skill_exists_in_index() { grep -q "^${1}|" "$SKILL_INDEX"; }

# Get workspace username
echo -e "${BLUE}Authenticating with profile: ${DB_PROFILE}${NC}"
USER_NAME=$(databricks current-user me --profile "$DB_PROFILE" --output json 2>/dev/null \
    | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('userName', ''))" 2>/dev/null || echo "")

if [ -z "$USER_NAME" ]; then
    echo -e "${RED}Error: Could not determine workspace user. Check authentication and --profile.${NC}"
    exit 1
fi

WORKSPACE_SKILLS_PATH="/Users/$USER_NAME/.assistant/skills"
echo -e "Workspace user: ${GREEN}${USER_NAME}${NC}"
echo -e "Workspace path: ${WORKSPACE_SKILLS_PATH}"
echo ""

# Count sources
repo_count=$(grep '|repo$' "$SKILL_INDEX" | wc -l | tr -d ' ')
claude_count=$(grep '|claude$' "$SKILL_INDEX" | wc -l | tr -d ' ')
echo -e "Discovered ${TOTAL_SKILLS} skills (${CYAN}${repo_count} from repo${NC}, ${GREEN}${claude_count} from ~/.claude/skills${NC})"
echo ""

# Get list of skills already in workspace
echo -e "${BLUE}Checking existing skills in workspace...${NC}"
EXISTING_SKILLS=$(databricks workspace list "$WORKSPACE_SKILLS_PATH" --profile "$DB_PROFILE" --output JSON 2>/dev/null \
    | python3 -c "
import sys, json
try:
    items = json.load(sys.stdin)
    for item in items:
        if item.get('object_type') == 'DIRECTORY':
            path = item.get('path', '')
            print(path.split('/')[-1])
except:
    pass
" 2>/dev/null || echo "")

# Categorize skills
TO_UPLOAD=""
ALREADY_EXISTS=""
upload_count=0
exists_count=0

while IFS= read -r skill; do
    [ -z "$skill" ] && continue
    if echo "$EXISTING_SKILLS" | grep -q "^${skill}$"; then
        if [ "$FORCE" = true ]; then
            TO_UPLOAD="$TO_UPLOAD $skill"
            upload_count=$((upload_count + 1))
        else
            ALREADY_EXISTS="$ALREADY_EXISTS $skill"
            exists_count=$((exists_count + 1))
        fi
    else
        TO_UPLOAD="$TO_UPLOAD $skill"
        upload_count=$((upload_count + 1))
    fi
done <<< "$(skill_names)"

TO_UPLOAD=$(echo "$TO_UPLOAD" | xargs)
ALREADY_EXISTS=$(echo "$ALREADY_EXISTS" | xargs)

# List mode
if [ "$LIST_MODE" = true ]; then
    echo -e "${BLUE}Skills and workspace status:${NC}"
    echo ""
    echo -e "${CYAN}From repo (${SCRIPT_DIR}):${NC}"
    while IFS= read -r skill; do
        [ -z "$skill" ] && continue
        [ "$(skill_source "$skill")" = "repo" ] || continue
        if echo "$EXISTING_SKILLS" | grep -q "^${skill}$"; then
            echo -e "  ${GREEN}✓${NC} $skill (in workspace)"
        else
            echo -e "  ${YELLOW}○${NC} $skill (missing from workspace)"
        fi
    done <<< "$(skill_names)"

    echo ""
    echo -e "${GREEN}From ~/.claude/skills:${NC}"
    while IFS= read -r skill; do
        [ -z "$skill" ] && continue
        [ "$(skill_source "$skill")" = "claude" ] || continue
        if echo "$EXISTING_SKILLS" | grep -q "^${skill}$"; then
            echo -e "  ${GREEN}✓${NC} $skill (in workspace)"
        else
            echo -e "  ${YELLOW}○${NC} $skill (missing from workspace)"
        fi
    done <<< "$(skill_names)"

    # Show workspace-only skills
    echo ""
    echo -e "${BLUE}Workspace-only skills (not found locally):${NC}"
    ws_only=0
    while IFS= read -r ws_skill; do
        [ -z "$ws_skill" ] && continue
        if ! skill_exists_in_index "$ws_skill"; then
            echo -e "  ${BLUE}☁${NC}  $ws_skill"
            ws_only=$((ws_only + 1))
        fi
    done <<< "$EXISTING_SKILLS"
    if [ $ws_only -eq 0 ]; then
        echo -e "  (none)"
    fi
    echo ""
    exit 0
fi

# Summary
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
if [ "$FORCE" = true ]; then
    echo -e "${YELLOW}Force mode: will overwrite existing skills${NC}"
fi
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}Dry run mode: no changes will be made${NC}"
fi
echo -e "Total skills found:       ${TOTAL_SKILLS}"
echo -e "Already in workspace:     ${exists_count}"
echo -e "To upload:                ${upload_count}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

if [ $upload_count -eq 0 ]; then
    echo -e "${GREEN}All skills are already in the workspace. Nothing to do.${NC}"
    echo "Use --force to overwrite existing skills."
    exit 0
fi

echo -e "${GREEN}Skills to upload:${NC}"
for skill in $TO_UPLOAD; do
    src_label=$(skill_source "$skill")
    if echo "$EXISTING_SKILLS" | grep -q "^${skill}$"; then
        echo -e "  ${YELLOW}↻${NC} $skill (overwrite) [${src_label}]"
    else
        echo -e "  ${GREEN}+${NC} $skill (new) [${src_label}]"
    fi
done
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}Dry run complete. No changes made.${NC}"
    exit 0
fi

# Ensure workspace skills directory exists
databricks workspace mkdirs "$WORKSPACE_SKILLS_PATH" --profile "$DB_PROFILE" 2>/dev/null || true

# Upload skills
uploaded=0
failed=0

for skill in $TO_UPLOAD; do
    skill_dir=$(skill_path "$skill")
    src_label=$(skill_source "$skill")
    echo -e "\n${BLUE}Uploading: ${skill}${NC} [${src_label}]"

    # Create skill directory in workspace
    databricks workspace mkdirs "$WORKSPACE_SKILLS_PATH/$skill" --profile "$DB_PROFILE" 2>/dev/null || true

    skill_failed=false
    while IFS= read -r -d '' file; do
        rel_path="${file#$skill_dir/}"
        dest_path="$WORKSPACE_SKILLS_PATH/$skill/$rel_path"

        # Create parent directory if needed
        parent_dir=$(dirname "$dest_path")
        if [ "$parent_dir" != "$WORKSPACE_SKILLS_PATH/$skill" ]; then
            databricks workspace mkdirs "$parent_dir" --profile "$DB_PROFILE" 2>/dev/null || true
        fi

        if databricks workspace import "$dest_path" --file "$file" --profile "$DB_PROFILE" --format AUTO --overwrite 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $rel_path"
        else
            echo -e "  ${RED}✗${NC} $rel_path"
            skill_failed=true
        fi
    done < <(find "$skill_dir" -type f \( -name "*.md" -o -name "*.py" -o -name "*.yaml" -o -name "*.yml" -o -name "*.sh" \) -print0)

    if [ "$skill_failed" = true ]; then
        failed=$((failed + 1))
    else
        uploaded=$((uploaded + 1))
    fi
done

# Final summary
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Upload complete!${NC}"
echo -e "  Uploaded:  ${uploaded} skills"
echo -e "  Skipped:   ${exists_count} skills (already in workspace)"
if [ $failed -gt 0 ]; then
    echo -e "  ${RED}Failed:    ${failed} skills${NC}"
fi
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"

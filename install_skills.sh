#!/bin/bash
#
# Install Skills to Claude Code
#
# Copies skills from this repo into ~/.claude/skills/ so they're
# available globally across all Claude Code projects. Skips skills
# that already exist unless --force is used.
#
# Usage:
#   ./install_skills.sh                              # Install all skills
#   ./install_skills.sh langgraph-human-in-the-loop  # Install specific skills
#   ./install_skills.sh --force                      # Overwrite existing
#   ./install_skills.sh --dry-run                    # Preview changes
#   ./install_skills.sh --list                       # List available skills
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="${HOME}/.claude/skills"
FORCE=false
DRY_RUN=false
LIST_MODE=false
SPECIFIC_SKILLS=""

# Parse arguments
while [ $# -gt 0 ]; do
    case $1 in
        --help|-h)
            echo -e "${BLUE}Install Skills to Claude Code${NC}"
            echo ""
            echo "Copies skills from this repo into ~/.claude/skills/ so they're"
            echo "available globally across all Claude Code projects."
            echo ""
            echo "Usage:"
            echo "  ./install_skills.sh [options] [skill1 skill2 ...]"
            echo ""
            echo "Options:"
            echo "  --help, -h           Show this help message"
            echo "  --force, -f          Overwrite existing skills"
            echo "  --dry-run, -n        Show what would be installed without doing it"
            echo "  --list, -l           List all available skills in this repo"
            echo "  --dest <path>        Install to a custom directory (default: ~/.claude/skills)"
            echo ""
            echo "Examples:"
            echo "  ./install_skills.sh                              # Install all skills"
            echo "  ./install_skills.sh langgraph-human-in-the-loop  # Install specific skill"
            echo "  ./install_skills.sh --force                      # Overwrite existing"
            echo "  ./install_skills.sh --dry-run                    # Preview changes"
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
        --list|-l)
            LIST_MODE=true
            shift
            ;;
        --dest)
            if [ -z "$2" ] || [ "${2:0:1}" = "-" ]; then
                echo -e "${RED}Error: --dest requires a directory path${NC}"
                exit 1
            fi
            DEST_DIR="$2"
            shift 2
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

# Discover skills in this repo
REPO_SKILLS=""
repo_count=0
for skill_dir in "$SCRIPT_DIR"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    case "$skill_name" in .*|node_modules) continue ;; esac
    [ -f "$skill_dir/SKILL.md" ] || continue
    REPO_SKILLS="$REPO_SKILLS $skill_name"
    repo_count=$((repo_count + 1))
done
REPO_SKILLS=$(echo "$REPO_SKILLS" | xargs | tr ' ' '\n' | sort | tr '\n' ' ')

if [ $repo_count -eq 0 ]; then
    echo -e "${RED}Error: No skills found in this repo.${NC}"
    exit 1
fi

# List mode
if [ "$LIST_MODE" = true ]; then
    echo -e "${BLUE}Available skills in this repo (${repo_count}):${NC}"
    echo ""
    for skill in $REPO_SKILLS; do
        if [ -d "$DEST_DIR/$skill" ]; then
            echo -e "  ${GREEN}✓${NC} $skill (installed)"
        else
            echo -e "  ${YELLOW}○${NC} $skill"
        fi
    done
    echo ""
    exit 0
fi

# Filter to specific skills if requested
SPECIFIC_SKILLS=$(echo "$SPECIFIC_SKILLS" | xargs)
if [ -n "$SPECIFIC_SKILLS" ]; then
    FILTERED=""
    for requested in $SPECIFIC_SKILLS; do
        found=false
        for skill in $REPO_SKILLS; do
            if [ "$requested" = "$skill" ]; then
                FILTERED="$FILTERED $requested"
                found=true
                break
            fi
        done
        if [ "$found" = false ]; then
            echo -e "${YELLOW}Warning: Skill '$requested' not found in repo, skipping${NC}"
        fi
    done
    REPO_SKILLS=$(echo "$FILTERED" | xargs)
    repo_count=$(echo "$REPO_SKILLS" | wc -w | tr -d ' ')
fi

# Categorize
TO_INSTALL=""
ALREADY_EXISTS=""
install_count=0
exists_count=0

for skill in $REPO_SKILLS; do
    if [ -d "$DEST_DIR/$skill" ]; then
        if [ "$FORCE" = true ]; then
            TO_INSTALL="$TO_INSTALL $skill"
            install_count=$((install_count + 1))
        else
            ALREADY_EXISTS="$ALREADY_EXISTS $skill"
            exists_count=$((exists_count + 1))
        fi
    else
        TO_INSTALL="$TO_INSTALL $skill"
        install_count=$((install_count + 1))
    fi
done
TO_INSTALL=$(echo "$TO_INSTALL" | xargs)

# Header
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Install Skills to Claude Code                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Source:      ${SCRIPT_DIR}"
echo -e "Destination: ${DEST_DIR}"
echo ""

if [ "$FORCE" = true ]; then
    echo -e "${YELLOW}Force mode: will overwrite existing skills${NC}"
fi
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}Dry run mode: no changes will be made${NC}"
fi

echo -e "Skills in repo:           ${repo_count}"
echo -e "Already installed:        ${exists_count}"
echo -e "To install:               ${install_count}"
echo ""

if [ $install_count -eq 0 ]; then
    echo -e "${GREEN}All skills are already installed. Nothing to do.${NC}"
    echo "Use --force to overwrite existing skills."
    exit 0
fi

echo -e "${GREEN}Skills to install:${NC}"
for skill in $TO_INSTALL; do
    if [ -d "$DEST_DIR/$skill" ]; then
        echo -e "  ${YELLOW}↻${NC} $skill (overwrite)"
    else
        echo -e "  ${GREEN}+${NC} $skill (new)"
    fi
done
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}Dry run complete. No changes made.${NC}"
    exit 0
fi

# Create destination directory
mkdir -p "$DEST_DIR"

# Install skills
installed=0
failed=0

for skill in $TO_INSTALL; do
    src="$SCRIPT_DIR/$skill"
    dest="$DEST_DIR/$skill"

    echo -e "${BLUE}Installing: ${skill}${NC}"

    # Remove existing to ensure clean install
    if [ -d "$dest" ]; then
        rm -rf "$dest"
    fi

    if cp -r "$src" "$dest" 2>/dev/null; then
        # Count files copied
        file_count=$(find "$dest" -type f | wc -l | tr -d ' ')
        echo -e "  ${GREEN}✓${NC} Copied ${file_count} files"
        installed=$((installed + 1))
    else
        echo -e "  ${RED}✗${NC} Failed to copy"
        failed=$((failed + 1))
    fi
done

# Summary
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Installation complete!${NC}"
echo -e "  Installed: ${installed} skills to ${DEST_DIR}"
echo -e "  Skipped:   ${exists_count} skills (already installed)"
if [ $failed -gt 0 ]; then
    echo -e "  ${RED}Failed:    ${failed} skills${NC}"
fi
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "Skills are now available globally in all Claude Code projects."
echo -e "To also push to Genie Code, run: ${BLUE}./push_skills_to_genie.sh${NC}"

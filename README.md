# central-skill-repo
Curation of skills for my ML/Data Engineering development.

## How Skills Work

Claude Code loads skills from multiple locations with a strict priority order:

| Location | Scope | Priority |
|----------|-------|----------|
| `~/.claude/skills/` | **Global** — all projects | Highest (personal) |
| `.claude/skills/` | **Project** — single repo | Lower (project) |

Skills in this repo live at the top level (e.g., `langgraph-human-in-the-loop/SKILL.md`). They need to be installed to one of the above locations to be picked up by Claude Code, or pushed to Databricks for Genie Code.

## Install Skills to Claude Code

Copy skills from this repo into `~/.claude/skills/` so they're available across **all** your Claude Code projects.

```bash
# Install all skills from this repo to ~/.claude/skills/ (global)
./install_skills.sh

# Install specific skills only
./install_skills.sh langgraph-human-in-the-loop huggingface-papers

# Preview what would be installed
./install_skills.sh --dry-run

# List all available skills in this repo
./install_skills.sh --list
```

### Options

| Flag | Description |
|------|-------------|
| `--force, -f` | Overwrite existing skills in `~/.claude/skills/` |
| `--dry-run, -n` | Show what would be installed without making changes |
| `--list, -l` | List all skills in this repo |
| `--dest <path>` | Install to a custom directory instead of `~/.claude/skills/` |
| `--help, -h` | Show help message |

## Push Skills to Genie Code

Use `push_skills_to_genie.sh` to push skills to your Databricks workspace for Genie Code / Assistant. By default it scans **both** this repo and `~/.claude/skills/`, and only uploads skills missing from the workspace.

When the same skill exists in both sources, the repo version takes priority.

### Prerequisites

- [Databricks CLI](https://docs.databricks.com/dev-tools/cli/install.html) installed and authenticated

### Usage

```bash
# Push missing skills from all sources (repo + ~/.claude/skills)
./push_skills_to_genie.sh

# Preview what would be uploaded
./push_skills_to_genie.sh --dry-run

# Force push all skills (overwrite existing)
./push_skills_to_genie.sh --force

# Only push skills from this repo
./push_skills_to_genie.sh --repo-only

# Only push skills from ~/.claude/skills
./push_skills_to_genie.sh --claude-only

# Push specific skills only
./push_skills_to_genie.sh databricks-bundles agent-evaluation

# Use a different Databricks CLI profile
./push_skills_to_genie.sh --profile prod

# See sync status between local and workspace
./push_skills_to_genie.sh --list
```

### Options

| Flag | Description |
|------|-------------|
| `--force, -f` | Overwrite existing skills in workspace |
| `--dry-run, -n` | Show what would be uploaded without making changes |
| `--list, -l` | List all discovered skills and their workspace status |
| `--repo-only` | Only push skills from this repo |
| `--claude-only` | Only push skills from `~/.claude/skills/` |
| `--profile <name>` | Databricks CLI profile (default: `DEFAULT` or `$DATABRICKS_CONFIG_PROFILE`) |
| `--help, -h` | Show help message |

## Resources/Credits

- [Databricks AI Dev Kit](https://github.com/databricks-solutions/ai-dev-kit) — source for Databricks and MLflow skills, including the original `install_skills.sh` installer that the scripts in this repo are adapted from
- [MLflow Skills](https://github.com/mlflow/skills) — MLflow tracing, evaluation, and onboarding skills
- [Databricks App Templates](https://github.com/databricks/app-templates/tree/main/.claude/skills)
- [HuggingFace Skills](https://github.com/huggingface/skills)
- [LangChain/DeepAgents Skills](https://github.com/langchain-ai/langchain-skills/tree/main/config/skills)

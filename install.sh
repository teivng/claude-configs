#!/bin/bash
# install.sh — one-click installer for claude-configs.
#
# Reads a profile from profiles/<name>.yaml and installs its skills,
# plugins, hooks, and CLAUDE.md templates.
#
# Usage:
#   ./install.sh --profile orchestration
#   ./install.sh --profile coding --project ~/work/my-repo
#   ./install.sh --profile all
#   ./install.sh --hooks-only --project ~/work/my-repo
#   ./install.sh --list-profiles
#
# Flags:
#   --profile <name>      Profile to install (one of: orchestration, coding,
#                         science, all). Required unless --hooks-only.
#   --project <dir>       Target project directory for hooks + CLAUDE.md
#                         pieces. Defaults to current directory. Skills and
#                         plugins always go to ~/.claude/.
#   --hooks-only          Install just the hooks (PreToolUse, Stop,
#                         SessionStart) and the per-project hook-config.
#                         Skips skills and plugins.
#   --dry-run             Print what would be installed without doing it.
#   --list-profiles       List available profiles and exit.
#   -h, --help            Show this help.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROFILE=""
PROJECT="$(pwd)"
HOOKS_ONLY=0
DRY_RUN=0

usage() {
  sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' | head -25
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --project)
      # Resolve to absolute path; allow non-existent paths in dry-run mode.
      if [ -d "$2" ]; then
        PROJECT="$(cd "$2" && pwd)"
      else
        # Lightly canonicalize without requiring existence.
        case "$2" in
          /*) PROJECT="$2" ;;
          *) PROJECT="$(pwd)/$2" ;;
        esac
      fi
      shift 2 ;;
    --hooks-only) HOOKS_ONLY=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --list-profiles)
      echo "Available profiles:"
      for p in "$REPO_DIR"/profiles/*.yaml; do
        name="$(basename "$p" .yaml)"
        desc=$(awk '/^description:/{flag=1; sub(/^description: \|?/,""); print; next} flag && /^[a-zA-Z]/{exit} flag{print}' "$p" | head -3 | tr '\n' ' ')
        printf "  %-15s  %s\n" "$name" "$desc"
      done
      exit 0
      ;;
    -h|--help) usage 0 ;;
    *) echo "unknown flag: $1" >&2; usage 1 ;;
  esac
done

run() {
  if [ "$DRY_RUN" = "1" ]; then
    echo "  [dry-run] $*"
  else
    echo "  $*"
    "$@"
  fi
}

mkdir_p() { run mkdir -p "$@"; }
copy() { run cp "$1" "$2"; }
copy_dir() { run cp -r "$1" "$2"; }

# --------------------------------------------------------------------
# Hooks installation (project-local)
# --------------------------------------------------------------------

install_hooks() {
  local proj="$1"
  echo "==> Installing hooks into $proj/.claude/"
  mkdir_p "$proj/.claude/hooks/pretooluse"
  mkdir_p "$proj/.claude/hooks/stop"
  mkdir_p "$proj/.claude/hooks/sessionstart"
  mkdir_p "$proj/.claude/brain-dumps"

  copy "$REPO_DIR/hooks/pretooluse/block-loose-files.sh"      "$proj/.claude/hooks/pretooluse/"
  copy "$REPO_DIR/hooks/pretooluse/block-loose-files.py"      "$proj/.claude/hooks/pretooluse/"
  copy "$REPO_DIR/hooks/pretooluse/block-hardcoded-paths.sh"  "$proj/.claude/hooks/pretooluse/"
  copy "$REPO_DIR/hooks/pretooluse/block-hardcoded-paths.py"  "$proj/.claude/hooks/pretooluse/"
  copy "$REPO_DIR/hooks/stop/warn-untracked-artifacts.sh"     "$proj/.claude/hooks/stop/"
  copy "$REPO_DIR/hooks/sessionstart/brain-dump-on-resume.sh" "$proj/.claude/hooks/sessionstart/"

  if [ ! -f "$proj/.claude/hook-config.json" ]; then
    copy "$REPO_DIR/hooks/default-hook-config.json" "$proj/.claude/hook-config.json"
    echo "  (wrote $proj/.claude/hook-config.json — edit to customize per-project policy)"
  else
    echo "  (kept existing $proj/.claude/hook-config.json — edit manually if you want updated defaults)"
  fi

  # Smoke-test each PreToolUse hook on a fixture; refuse to wire if any fail.
  echo "==> Smoke-testing hooks..."
  if [ "$DRY_RUN" = "0" ]; then
    fail=0
    if ! echo '{"tool_input":{"file_path":"'"$proj"'/scratch_x.py"}}' | "$proj/.claude/hooks/pretooluse/block-loose-files.sh" 2>/dev/null; then
      [ "$?" = "2" ] || fail=1
    fi
    if [ "$fail" = "1" ]; then
      echo "  hook smoke test failed; please investigate before wiring." >&2
      exit 1
    fi
    echo "  hooks pass smoke test."
  fi

  # Wire into .claude/settings.local.json
  python3 "$REPO_DIR/install/wire_hooks.py" --project-root "$proj" --dry-run="$DRY_RUN"
  echo "==> Hooks installed."
}

# --------------------------------------------------------------------
# Skills installation (user-level, ~/.claude/skills/)
# --------------------------------------------------------------------

install_skill() {
  local skill_name="$1"
  echo "==> Installing skill: $skill_name"
  mkdir_p "$HOME/.claude/skills"
  if [ -d "$HOME/.claude/skills/$skill_name" ]; then
    echo "  (already present — kept as-is. Remove first if you want to reinstall.)"
    return 0
  fi
  copy_dir "$REPO_DIR/skills/$skill_name" "$HOME/.claude/skills/"
}

# --------------------------------------------------------------------
# Plugins installation (via claude plugin)
# --------------------------------------------------------------------

install_plugin() {
  local plugin_id="$1"
  echo "==> Installing plugin: $plugin_id"
  run claude plugin install "$plugin_id"
}

install_marketplace() {
  local repo="$1"
  echo "==> Registering marketplace: $repo"
  if claude plugin marketplace list 2>/dev/null | grep -q "$repo"; then
    echo "  (already registered)"
    return 0
  fi
  run claude plugin marketplace add "$repo"
}

# --------------------------------------------------------------------
# CLAUDE.md template hint (we don't paste automatically — the templates
# require human edits of the {{placeholders}})
# --------------------------------------------------------------------

print_template_hint() {
  local proj="$1"
  shift
  echo "==> CLAUDE.md templates (paste these manually):"
  for tmpl in "$@"; do
    echo "    $REPO_DIR/claude-md-templates/$tmpl  →  $proj/CLAUDE.md"
    echo "      (edit the {{placeholders}}, strip the leading HTML comment)"
  done
}

# --------------------------------------------------------------------
# Main
# --------------------------------------------------------------------

if [ "$HOOKS_ONLY" = "1" ]; then
  install_hooks "$PROJECT"
  exit 0
fi

if [ -z "$PROFILE" ]; then
  echo "error: --profile required (or --hooks-only). Try --list-profiles." >&2
  exit 1
fi

PROFILE_FILE="$REPO_DIR/profiles/${PROFILE}.yaml"
if [ ! -f "$PROFILE_FILE" ]; then
  echo "error: profile not found: $PROFILE_FILE" >&2
  echo "available profiles:" >&2
  ls "$REPO_DIR/profiles/" >&2
  exit 1
fi

echo "==> Installing profile: $PROFILE"
echo "    Profile file: $PROFILE_FILE"
echo "    Target project (for hooks + CLAUDE.md hints): $PROJECT"
echo

# Parse profile YAML via a tiny Python helper (avoids needing a yaml gem).
parse() {
  python3 - "$PROFILE_FILE" "$1" <<'PY'
import sys, yaml
with open(sys.argv[1]) as f:
    cfg = yaml.safe_load(f)
print("\n".join(cfg.get(sys.argv[2], []) or []))
PY
}

# Skills
echo "==> Skills"
while IFS= read -r skill; do
  [ -z "$skill" ] && continue
  install_skill "$skill"
done < <(parse skills)

# Plugins (register marketplaces first, then install)
echo
echo "==> Plugins"
# Register all needed marketplaces from plugins.yaml
python3 - "$REPO_DIR/plugins.yaml" "$PROFILE_FILE" <<'PY' | while IFS= read -r line; do
import sys, yaml
with open(sys.argv[1]) as f:
    plugs = yaml.safe_load(f)
with open(sys.argv[2]) as f:
    prof = yaml.safe_load(f)
wanted = set(prof.get("plugins", []) or [])
needed_mps = set()
for p in plugs.get("plugins", []):
    if p["id"] in wanted:
        needed_mps.add(p["marketplace"])
for mp in plugs.get("marketplaces", []):
    if mp["name"] in needed_mps:
        print(f"marketplace {mp['repo']}")
for pid in wanted:
    print(f"plugin {pid}")
PY
  case "$line" in
    "marketplace "*) install_marketplace "${line#marketplace }" ;;
    "plugin "*) install_plugin "${line#plugin }" ;;
  esac
done

# CLAUDE.md templates (hint only — manual paste)
echo
echo "==> CLAUDE.md templates"
mapfile -t TEMPLATES < <(parse claude_md_templates)
if [ "${#TEMPLATES[@]}" -gt 0 ]; then
  print_template_hint "$PROJECT" "${TEMPLATES[@]}"
fi

# Hooks (only if any are listed in profile)
echo
echo "==> Hooks"
mapfile -t HOOKS < <(parse hooks)
if [ "${#HOOKS[@]}" -gt 0 ]; then
  install_hooks "$PROJECT"
else
  echo "  (no hooks in this profile)"
fi

echo
echo "==> Install complete. Restart your Claude Code session to pick up plugin changes."

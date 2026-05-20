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

# Parse profile YAML via a stdlib-only Python helper. Avoids depending
# on PyYAML (not in stdlib) and on bash 4+ builtins like `mapfile`.
#
# Format assumptions for profiles/*.yaml (kept intentionally narrow):
#   key:
#     - item-1
#     - item-2
# That's it. No nested structures, no flow style. Comments (`#`) and
# blank lines are skipped. Multiline scalars (`key: |`) are ignored
# (the description field uses one but we don't read it from here).
parse() {
  python3 - "$PROFILE_FILE" "$1" <<'PY'
import re, sys
key_wanted = sys.argv[2]
with open(sys.argv[1]) as f:
    lines = f.read().splitlines()
current = None
items = []
for raw in lines:
    line = raw.rstrip()
    if not line.strip() or line.lstrip().startswith("#"):
        continue
    m_top = re.match(r"^([A-Za-z_][\w-]*):\s*(.*)$", line)
    if m_top and not line.startswith((" ", "\t")):
        if current == key_wanted:
            break
        current = m_top.group(1)
        rest = m_top.group(2)
        # `key: |` or `key: >` introduces a block scalar — skip it.
        if rest and rest not in ("|", ">"):
            current = None
        continue
    if current == key_wanted:
        m_item = re.match(r"^\s+-\s+(.+?)\s*$", line)
        if m_item:
            items.append(m_item.group(1).strip().strip('"').strip("'"))
print("\n".join(items))
PY
}

# Collect into a portable array (no `mapfile`).
collect() {
  # Usage: collect VARNAME <command-that-prints-one-per-line>
  local __var="$1"; shift
  local __tmp=()
  while IFS= read -r __line; do
    [ -z "$__line" ] && continue
    __tmp+=("$__line")
  done < <("$@")
  # Re-emit through eval; safe because items come from our own YAML parser.
  eval "$__var=()"
  local __i
  for __i in "${__tmp[@]}"; do
    eval "$__var+=(\"\$__i\")"
  done
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
# Walk plugins.yaml in stdlib-only mode: collect plugin entries (id +
# marketplace), then for each one wanted by the active profile, emit
# its marketplace repo first, then the plugin id.
python3 - "$REPO_DIR/plugins.yaml" "$PROFILE_FILE" <<'PY' | while IFS= read -r line; do
import re, sys

def parse_list(text, list_key):
    """Yield dicts under a top-level list `list_key:`."""
    lines = text.splitlines()
    in_list = False
    current = None
    block_scalar_indent = None
    for raw in lines:
        line = raw.rstrip()
        stripped = line.lstrip()
        if not stripped or stripped.startswith("#"):
            continue
        m_top = re.match(r"^([A-Za-z_][\w-]*):\s*(.*)$", line)
        if m_top and not line.startswith((" ", "\t")):
            if current is not None:
                yield current
                current = None
            in_list = (m_top.group(1) == list_key)
            block_scalar_indent = None
            continue
        if not in_list:
            continue
        # Skip block scalar continuations.
        if block_scalar_indent is not None and (line.startswith(" " * block_scalar_indent) or not stripped):
            continue
        block_scalar_indent = None
        m_item = re.match(r"^(\s+)-\s+([A-Za-z_][\w-]*):\s*(.*)$", line)
        if m_item:
            if current is not None:
                yield current
            current = {}
            key, val = m_item.group(2), m_item.group(3).strip()
            if val in ("|", ">"):
                block_scalar_indent = len(m_item.group(1)) + 2
            else:
                current[key] = val.strip('"').strip("'")
            continue
        m_kv = re.match(r"^\s+([A-Za-z_][\w-]*):\s*(.*)$", line)
        if m_kv and current is not None:
            key, val = m_kv.group(1), m_kv.group(2).strip()
            if val in ("|", ">"):
                block_scalar_indent = (len(line) - len(stripped)) + 2
            else:
                current[key] = val.strip('"').strip("'")
    if current is not None:
        yield current

def parse_profile_plugins(path):
    with open(path) as f:
        text = f.read()
    out = []
    in_plugins = False
    for raw in text.splitlines():
        line = raw.rstrip()
        stripped = line.lstrip()
        if not stripped or stripped.startswith("#"):
            continue
        m_top = re.match(r"^([A-Za-z_][\w-]*):\s*$", line)
        if m_top and not line.startswith((" ", "\t")):
            in_plugins = (m_top.group(1) == "plugins")
            continue
        if in_plugins:
            m = re.match(r"^\s+-\s+(.+?)\s*$", line)
            if m:
                out.append(m.group(1).strip().strip('"').strip("'"))
    return out

with open(sys.argv[1]) as f:
    plug_text = f.read()
wanted = set(parse_profile_plugins(sys.argv[2]))
plugins = list(parse_list(plug_text, "plugins"))
marketplaces = list(parse_list(plug_text, "marketplaces"))

needed_mps = {p["marketplace"] for p in plugins if p.get("id") in wanted and "marketplace" in p}
for mp in marketplaces:
    if mp.get("name") in needed_mps and "repo" in mp:
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
collect TEMPLATES parse claude_md_templates
if [ "${#TEMPLATES[@]}" -gt 0 ]; then
  print_template_hint "$PROJECT" "${TEMPLATES[@]}"
fi

# Hooks (only if any are listed in profile)
echo
echo "==> Hooks"
collect HOOKS parse hooks
if [ "${#HOOKS[@]}" -gt 0 ]; then
  install_hooks "$PROJECT"
else
  echo "  (no hooks in this profile)"
fi

echo
echo "==> Install complete. Restart your Claude Code session to pick up plugin changes."

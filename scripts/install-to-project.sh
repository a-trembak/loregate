#!/usr/bin/env bash
# Install / update Loregate (lgt) into ~/.cursor and optionally a consumer project.
# Prefer: bin/lgt install <project>   |   bin/lgt update <project>
# Legacy: bin/csp → warns and forwards to bin/lgt
#
# Default: symlink kit skills/commands/agents into ~/.cursor;
#          copy always-on plain-language-chat and pipeline-language-no-russian rules into ~/.cursor/rules;
#          copy hooks + rules (+ optional patterns helper) into the project.
# Kit-only evals/ (agent-trajectory golden set) is never copied into consumer apps.

set -euo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=mapped-third-party-skills.sh
source "$KIT_ROOT/scripts/mapped-third-party-skills.sh"
PROJECT=""
USER_ONLY=0
WITH_HUMANIZER=0
COPY_MODE=0
FORCE_REFRESH=0
MODE="install" # install | update
SKIP_THIRD_PARTY_SKILLS=0
# Prefer LGT_*; accept legacy CSP_* for existing installs / continuous integration.
PIPELINE_LANGUAGE="${LGT_PIPELINE_LANGUAGE:-${CSP_PIPELINE_LANGUAGE:-}}"
AGREE_POLICY=0
# Non-interactive CI: LGT_AGREE_POLICY=1 or CSP_AGREE_POLICY=1 ≡ --agree-policy
_agree_env="${LGT_AGREE_POLICY:-${CSP_AGREE_POLICY:-}}"
if [[ "$_agree_env" == "1" || "$_agree_env" == "true" || "$_agree_env" == "yes" ]]; then
  AGREE_POLICY=1
fi
# Core public policy docs that must be accepted at install (order matches scripts/csp-policy-hash.sh).
POLICY_DOC_NAMES=(PRIVACY.md TERMS.md DISCLAIMER.md NOTICE.md)

usage() {
  cat <<'EOF'
Install or update Loregate (short mark LGT; see docs/legal/NAME-OPTIONS.md).

Usage:
  install-to-project.sh [project-path] [flags]
  install-to-project.sh --user-only [flags]
  install-to-project.sh --update [project-path] [flags]

With no project-path: uses the current repo / multi-repo workspace (cwd).
In --update mode with no resolvable project: refreshes ~/.cursor only.

Flags:
  --update         Refresh mode (same as `lgt update`): re-link kit bits, refresh project hooks/rules
  --user-only      Only ~/.cursor (no project files); still copies plain-language-chat, pipeline-language-no-russian, and code-via-coding-agents rules
  --humanizer      Also install english-humanizer (or keep it if already linked)
  --copy           Copy into ~/.cursor instead of symlink
  --agree-policy, --i-agree
                   Accept Privacy, Terms, Disclaimer, and NOTICE (docs/legal/).
                   Required for install. Same as LGT_AGREE_POLICY=1 (alias CSP_AGREE_POLICY=1).
                   Interactive [y/N] prompt when flag omitted and stdin is a terminal.
  --language <code>, --lang <code>
                   Set pipeline chat language (writes .cursor/lgt-pipeline-language and legacy .cursor/csp-pipeline-language).
                   Same as LGT_PIPELINE_LANGUAGE (alias CSP_PIPELINE_LANGUAGE). Default when omitted: leave unset
                   (helper defaults to en; /lgt-start-task asks if unset).
                   Russian (ru) is rejected — sanctions-based language policy.
  --skip-third-party-skills
                   Do not run npx skills add for mapped third-party skills
                   (air-gapped). Same as LGT_SKIP_THIRD_PARTY_SKILLS=1 (alias CSP_SKIP_THIRD_PARTY_SKILLS=1)
  -h, --help       Show help

Keep one clone of this kit; install/update per project. Do not vendor the
kit inside every repository. Curated third-party skills come from skill-map.md
on install/update; agents never auto-install them mid-review.
EOF
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage 0 ;;
    --update) MODE="update"; FORCE_REFRESH=1; shift ;;
    --user-only|--global) USER_ONLY=1; shift ;;
    --humanizer) WITH_HUMANIZER=1; shift ;;
    --copy) COPY_MODE=1; shift ;;
    --agree-policy|--i-agree)
      AGREE_POLICY=1
      shift
      ;;
    --language|--lang)
      if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
        echo "error: $1 requires a language code (for example uk or en)" >&2
        usage 1
      fi
      PIPELINE_LANGUAGE="$2"
      shift 2
      ;;
    --skip-third-party-skills)
      SKIP_THIRD_PARTY_SKILLS=1
      shift
      ;;
    --user-skills|--hooks|--rule|--no-hooks|--no-rule)
      # Accepted no-ops / legacy aliases (hooks+rules always install with a project)
      shift
      ;;
    --*)
      echo "Unknown flag: $1" >&2
      usage 1
      ;;
    *)
      if [[ -n "$PROJECT" ]]; then
        echo "Unexpected argument: $1" >&2
        usage 1
      fi
      PROJECT="$1"
      shift
      ;;
  esac
done

# Resolve default project when path omitted: current git repo or multi-repo workspace.
resolve_default_project() {
  local cwd root count d
  cwd="$(pwd)"

  # 1) Inside a git work tree → that repo's toplevel (leaf repo in a multi-repo is fine)
  if root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    printf '%s\n' "$root"
    return 0
  fi

  # 2) Multi-repo / workspace parent markers at cwd
  if [[ -f "$cwd/.cursor/multi-repo.json" || -d "$cwd/graphify-out" ]]; then
    printf '%s\n' "$cwd"
    return 0
  fi

  # 3) Cwd looks like a workspace parent: 2+ immediate child git repos
  count=0
  for d in "$cwd"/*/; do
    [[ -d "$d" ]] || continue
    if git -C "$d" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      count=$((count + 1))
    fi
  done
  if [[ "$count" -ge 2 ]]; then
    printf '%s\n' "$cwd"
    return 0
  fi

  return 1
}

if [[ "$USER_ONLY" -eq 0 && -z "$PROJECT" ]]; then
  if PROJECT="$(resolve_default_project)"; then
    echo "project (auto): $PROJECT"
  elif [[ "$MODE" == "update" ]]; then
    # `csp update` with no resolvable project → refresh ~/.cursor only
    # (kit pull already happened in bin/cursor-spells). Restores pre-a4c66ea UX
    # so `csp update` from ~ or any non-repo cwd still succeeds.
    USER_ONLY=1
    echo "no project in cwd → refreshing ~/.cursor only (pass a path to sync a project)"
  else
    echo "No project path given, and cwd is not a git repo or multi-repo workspace." >&2
    echo "Run from inside a repo/workspace, pass a path, or use --user-only." >&2
    usage 1
  fi
fi

if [[ -n "$PROJECT" ]]; then
  if [[ ! -d "$PROJECT" ]]; then
    echo "Project path does not exist: $PROJECT" >&2
    exit 1
  fi
  PROJECT="$(cd "$PROJECT" && pwd)"
  if [[ "$PROJECT" == "$KIT_ROOT" ]]; then
    if [[ "$MODE" == "update" ]]; then
      echo "note: refusing project bits into the cursor-spells kit itself; refreshing ~/.cursor only"
      USER_ONLY=1
      PROJECT=""
    else
      echo "Refusing to install project bits into the cursor-spells kit itself ($KIT_ROOT)." >&2
      echo "cd into your app or multi-repo workspace, or pass its path. Use --user-only for ~/.cursor only." >&2
      exit 1
    fi
  fi
fi

is_our_link() {
  local dest="$1"
  local src="$2"
  [[ -L "$dest" ]] || return 1
  local target
  target="$(readlink "$dest")"
  [[ "$target" == "$src" ]] && return 0
  # Allow relative or older absolute links that still resolve into this kit
  local resolved
  resolved="$(cd "$(dirname "$dest")" && cd "$(dirname "$target")" 2>/dev/null && pwd)/$(basename "$target")" || return 1
  [[ "$resolved" == "$src" ]] && return 0
  case "$target" in
    "$KIT_ROOT"/*) return 0 ;;
  esac
  return 1
}

link_or_copy() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"

  if [[ "$COPY_MODE" -eq 1 ]]; then
    if [[ -e "$dest" || -L "$dest" ]]; then
      if [[ "$FORCE_REFRESH" -eq 1 ]]; then
        rm -rf "$dest"
        cp -R "$src" "$dest"
        echo "refreshed (copy): $dest"
        return 0
      fi
      echo "skip (exists): $dest"
      return 0
    fi
    cp -R "$src" "$dest"
    echo "copied: $dest"
    return 0
  fi

  # Symlink mode
  if [[ -L "$dest" ]]; then
    if is_our_link "$dest" "$src"; then
      if [[ "$FORCE_REFRESH" -eq 1 ]]; then
        rm -f "$dest"
        ln -s "$src" "$dest"
        echo "relinked: $dest -> $src"
      else
        echo "ok (linked): $dest"
      fi
      return 0
    fi
    if [[ "$FORCE_REFRESH" -eq 1 ]]; then
      echo "skip (foreign symlink): $dest -> $(readlink "$dest")"
      return 0
    fi
    echo "skip (exists): $dest"
    return 0
  fi

  if [[ -e "$dest" ]]; then
    echo "skip (exists, not a symlink): $dest"
    return 0
  fi

  ln -s "$src" "$dest"
  echo "linked: $dest -> $src"
}

want_skill() {
  local name="$1"
  if [[ "$name" == "english-humanizer" ]]; then
    [[ "$WITH_HUMANIZER" -eq 1 ]] && return 0
    # Keep syncing humanizer on update if it was installed earlier
    [[ -e "$HOME/.cursor/skills/english-humanizer" || -L "$HOME/.cursor/skills/english-humanizer" ]] && return 0
    [[ -n "${PROJECT:-}" && ( -e "$PROJECT/.cursor/skills/english-humanizer" || -L "$PROJECT/.cursor/skills/english-humanizer" ) ]] && return 0
    return 1
  fi
  return 0
}

# Remove prior unprefixed command/agent symlinks (or refresh copies) that this
# kit used to own under the old name. Never delete foreign files/links.
# Prefixed twins may be lgt-* (primary) or csp-* (legacy stubs / agents).
remove_owned_unprefixed_kit_links() {
  local cursor_root="$1"
  local kind="$2" # commands | agents
  local dir="$cursor_root/$kind"
  local dest base target resolved kit_dir
  [[ -d "$dir" ]] || return 0
  kit_dir="$KIT_ROOT/$kind"

  for dest in "$dir"/*.md; do
    [[ -e "$dest" || -L "$dest" ]] || continue
    base="$(basename "$dest")"
    [[ "$base" == csp-* || "$base" == lgt-* ]] && continue
    # Only migrate when a prefixed twin exists in this kit
    [[ -e "$kit_dir/lgt-$base" || -e "$kit_dir/csp-$base" ]] || continue

    if [[ -L "$dest" ]]; then
      target="$(readlink "$dest")"
      resolved=""
      resolved="$(cd "$(dirname "$dest")" && cd "$(dirname "$target")" 2>/dev/null && pwd)/$(basename "$target")" || true
      # Owned if link target is/was under this kit's commands|agents dir
      if [[ "$target" == "$kit_dir"/* || "$resolved" == "$kit_dir"/* || "$target" == "$KIT_ROOT/$kind"/* ]]; then
        rm -f "$dest"
        echo "removed stale kit link: $dest"
      fi
    elif [[ -f "$dest" && "$COPY_MODE" -eq 1 && "$FORCE_REFRESH" -eq 1 ]]; then
      rm -rf "$dest"
      echo "removed stale kit copy: $dest"
    fi
  done
}

# Link/copy every kit skill, command, and agent into a Cursor root
# ($1 = ~/.cursor or <project>/.cursor).
sync_kit_entries_into() {
  local cursor_root="$1"
  mkdir -p "$cursor_root/skills" "$cursor_root/commands" "$cursor_root/agents"

  local src name
  for src in "$KIT_ROOT"/skills/*; do
    [[ -e "$src" ]] || continue
    name="$(basename "$src")"
    want_skill "$name" || continue
    link_or_copy "$src" "$cursor_root/skills/$name"
  done

  remove_owned_unprefixed_kit_links "$cursor_root" commands
  for src in "$KIT_ROOT"/commands/*.md; do
    [[ -e "$src" ]] || continue
    name="$(basename "$src")"
    link_or_copy "$src" "$cursor_root/commands/$name"
  done

  remove_owned_unprefixed_kit_links "$cursor_root" agents
  for src in "$KIT_ROOT"/agents/*.md; do
    [[ -e "$src" ]] || continue
    name="$(basename "$src")"
    link_or_copy "$src" "$cursor_root/agents/$name"
  done

  printf '%s\n' "$KIT_ROOT" > "$cursor_root/cursor-spells-kit-path"
  echo "wrote: $cursor_root/cursor-spells-kit-path"
}

install_user_bits() {
  # shellcheck source=teach-review.sh
  source "$KIT_ROOT/scripts/teach-review.sh"
  tr_install_learn_config "$HOME/.cursor/cursor-spells-learn.json" \
    "$KIT_ROOT/skills/teach-review/references/cursor-spells-learn.json"
  echo "learn-config: $HOME/.cursor/cursor-spells-learn.json"
  sync_kit_entries_into "$HOME/.cursor"
  # Always-on chat language + Russian sanctions ban. Pipeline gate rules stay project-only.
  mkdir -p "$HOME/.cursor/rules"
  cp "$KIT_ROOT/rules/plain-language-chat.mdc" "$HOME/.cursor/rules/plain-language-chat.mdc"
  echo "copied: $HOME/.cursor/rules/plain-language-chat.mdc"
  cp "$KIT_ROOT/rules/pipeline-language-no-russian.mdc" "$HOME/.cursor/rules/pipeline-language-no-russian.mdc"
  echo "copied: $HOME/.cursor/rules/pipeline-language-no-russian.mdc"
  cp "$KIT_ROOT/rules/code-via-coding-agents.mdc" "$HOME/.cursor/rules/code-via-coding-agents.mdc"
  echo "copied: $HOME/.cursor/rules/code-via-coding-agents.mdc"
  cp "$KIT_ROOT/scripts/statusline-loregate.sh" "$HOME/.cursor/statusline-loregate.sh"
  chmod +x "$HOME/.cursor/statusline-loregate.sh"
  echo "copied: $HOME/.cursor/statusline-loregate.sh"
  echo "hint: enable Cursor CLI statusLine → command ~/.cursor/statusline-loregate.sh (see README)"
}

install_project_bits() {
  mkdir -p "$PROJECT/.cursor/hooks" "$PROJECT/.cursor/rules" "$PROJECT/.cursor"
  # shellcheck source=teach-review.sh
  source "$KIT_ROOT/scripts/teach-review.sh"
  tr_install_learn_config "$PROJECT/.cursor/cursor-spells-learn.json" \
    "$KIT_ROOT/skills/teach-review/references/cursor-spells-learn.json"
  echo "learn-config: $PROJECT/.cursor/cursor-spells-learn.json"

  # Mirror skills/commands/agents into the project so Cursor UI/CLI reliably lists them.
  # User-global ~/.cursor alone is easy to miss (and Cursor CLI only completes project agents).
  sync_kit_entries_into "$PROJECT/.cursor"

  # Hook scripts — always refresh from kit (owned by cursor-spells)
  local hook
  for hook in post-plan-review-gate.sh pre-build-gate.sh; do
    cp "$KIT_ROOT/hooks/$hook" "$PROJECT/.cursor/hooks/$hook"
    chmod +x "$PROJECT/.cursor/hooks/$hook"
    echo "copied: $PROJECT/.cursor/hooks/$hook"
  done

  if [[ ! -f "$PROJECT/.cursor/hooks.json" ]]; then
    cp "$KIT_ROOT/hooks/hooks.json" "$PROJECT/.cursor/hooks.json"
    echo "copied: $PROJECT/.cursor/hooks.json"
  elif [[ "$FORCE_REFRESH" -eq 1 ]]; then
    cp "$KIT_ROOT/hooks/hooks.json" "$PROJECT/.cursor/hooks.json"
    echo "refreshed: $PROJECT/.cursor/hooks.json"
  else
    echo "skip (exists): $PROJECT/.cursor/hooks.json (re-run with update to refresh)"
  fi

  # Rules — always refresh from kit
  local rule
  for rule in after-plan-review-gate.mdc before-build-critique-gate.mdc clean-decision-docs.mdc hitl-askquestion.mdc plain-language-chat.mdc pipeline-language-no-russian.mdc code-via-coding-agents.mdc; do
    cp "$KIT_ROOT/rules/$rule" "$PROJECT/.cursor/rules/$rule"
    echo "copied: $PROJECT/.cursor/rules/$rule"
  done

  # Optional CI helper — create once; refresh on update
  mkdir -p "$PROJECT/scripts"
  if [[ ! -f "$PROJECT/scripts/check-project-patterns.sh" || "$FORCE_REFRESH" -eq 1 ]]; then
    cp "$KIT_ROOT/scripts/check-project-patterns.sh" "$PROJECT/scripts/check-project-patterns.sh"
    chmod +x "$PROJECT/scripts/check-project-patterns.sh"
    echo "copied: $PROJECT/scripts/check-project-patterns.sh"
  else
    echo "skip (exists): $PROJECT/scripts/check-project-patterns.sh"
  fi
  # Snippet helper for review evidence backfill (always refresh — small script)
  cp "$KIT_ROOT/scripts/extract-review-snippet.sh" "$PROJECT/scripts/extract-review-snippet.sh"
  chmod +x "$PROJECT/scripts/extract-review-snippet.sh"
  echo "copied: $PROJECT/scripts/extract-review-snippet.sh"
  # Report validator — reject Verdict/Blockers digests missing evidence
  cp "$KIT_ROOT/scripts/validate-review-report.sh" "$PROJECT/scripts/validate-review-report.sh"
  chmod +x "$PROJECT/scripts/validate-review-report.sh"
  echo "copied: $PROJECT/scripts/validate-review-report.sh"
  cp "$KIT_ROOT/scripts/pipeline-gates.sh" "$PROJECT/scripts/pipeline-gates.sh"
  chmod +x "$PROJECT/scripts/pipeline-gates.sh"
  echo "copied: $PROJECT/scripts/pipeline-gates.sh"
  cp "$KIT_ROOT/scripts/pipeline-status.sh" "$PROJECT/scripts/pipeline-status.sh"
  chmod +x "$PROJECT/scripts/pipeline-status.sh"
  echo "copied: $PROJECT/scripts/pipeline-status.sh"
  cp "$KIT_ROOT/scripts/pipeline-run-log.sh" "$PROJECT/scripts/pipeline-run-log.sh"
  chmod +x "$PROJECT/scripts/pipeline-run-log.sh"
  echo "copied: $PROJECT/scripts/pipeline-run-log.sh"
  echo "recommend: add .cursor/gates/run-log/ to .gitignore (pipeline run journals stay local)"
  cp "$KIT_ROOT/scripts/csp-pipeline-language.sh" "$PROJECT/scripts/csp-pipeline-language.sh"
  chmod +x "$PROJECT/scripts/csp-pipeline-language.sh"
  echo "copied: $PROJECT/scripts/csp-pipeline-language.sh"
  # Primary alias name (same body); relative symlink when possible
  ln -sfn csp-pipeline-language.sh "$PROJECT/scripts/lgt-pipeline-language.sh" 2>/dev/null \
    || cp "$KIT_ROOT/scripts/csp-pipeline-language.sh" "$PROJECT/scripts/lgt-pipeline-language.sh"
  chmod +x "$PROJECT/scripts/lgt-pipeline-language.sh" 2>/dev/null || true
  echo "copied: $PROJECT/scripts/lgt-pipeline-language.sh"
  cp "$KIT_ROOT/scripts/csp-policy-hash.sh" "$PROJECT/scripts/csp-policy-hash.sh"
  chmod +x "$PROJECT/scripts/csp-policy-hash.sh"
  echo "copied: $PROJECT/scripts/csp-policy-hash.sh"
  cp "$KIT_ROOT/scripts/jira-issue.sh" "$PROJECT/scripts/jira-issue.sh"
  chmod +x "$PROJECT/scripts/jira-issue.sh"
  echo "copied: $PROJECT/scripts/jira-issue.sh"
  cp "$KIT_ROOT/scripts/pr-merge-ci.sh" "$PROJECT/scripts/pr-merge-ci.sh"
  chmod +x "$PROJECT/scripts/pr-merge-ci.sh"
  echo "copied: $PROJECT/scripts/pr-merge-ci.sh"
}

# Write pipeline chat language when --language / --lang / LGT_PIPELINE_LANGUAGE / CSP_PIPELINE_LANGUAGE is set.
# Project install → <project>/.cursor/lgt-pipeline-language (+ legacy csp twin)
# --user-only → ~/.cursor/lgt-pipeline-language (+ legacy twin)
apply_pipeline_language() {
  if [[ -z "$PIPELINE_LANGUAGE" ]]; then
    return 0
  fi
  local helper="$KIT_ROOT/scripts/csp-pipeline-language.sh"
  if [[ ! -x "$helper" ]]; then
    chmod +x "$helper" 2>/dev/null || true
  fi
  if [[ "$USER_ONLY" -eq 1 || -z "$PROJECT" ]]; then
    if ! "$helper" set --root "$HOME" --lang "$PIPELINE_LANGUAGE"; then
      echo "error: refused pipeline language '$PIPELINE_LANGUAGE' (Russian is impossible in this pipeline)" >&2
      exit 1
    fi
    echo "pipeline-language (user): $HOME/.cursor/lgt-pipeline-language → $($helper get --root "$HOME")"
    return 0
  fi
  if ! "$helper" set --root "$PROJECT" --lang "$PIPELINE_LANGUAGE"; then
    echo "error: refused pipeline language '$PIPELINE_LANGUAGE' (Russian is impossible in this pipeline)" >&2
    exit 1
  fi
  echo "pipeline-language (project): $PROJECT/.cursor/lgt-pipeline-language → $($helper get --root "$PROJECT")"
}

# --- Public policy acceptance (docs/legal/) -----------------------------------

policy_docs_hash() {
  local hasher="$KIT_ROOT/scripts/csp-policy-hash.sh"
  chmod +x "$hasher" 2>/dev/null || true
  "$hasher" --kit-root "$KIT_ROOT"
}

policy_acceptance_matches() {
  local marker="$1"
  local want_hash="$2"
  local got=""
  [[ -f "$marker" ]] || return 1
  got="$(awk -F= '/^policy_hash=/{print $2; exit}' "$marker" 2>/dev/null || true)"
  [[ -n "$got" && "$got" == "$want_hash" ]]
}

write_policy_acceptance() {
  local marker="$1"
  local hash="$2"
  local via="${3:-flag}"
  local when kit_commit docs_csv
  when="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  kit_commit="$(git -C "$KIT_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  docs_csv="$(IFS=,; echo "${POLICY_DOC_NAMES[*]}")"
  mkdir -p "$(dirname "$marker")"
  cat >"$marker" <<EOF
# Policy acceptance record — Loregate (LGT); see docs/legal/NAME-OPTIONS.md
# Written by lgt install / lgt update after the operator agreed to docs/legal/.
# Re-acceptance is required when policy_hash no longer matches the kit docs.
accepted_at=$when
agree_via=$via
policy_hash=$hash
policy_docs=$docs_csv
kit_commit=$kit_commit
kit_root=$KIT_ROOT
EOF
  echo "policy accepted → $marker (hash $hash)"
}

# Write both primary (lgt-*) and legacy (csp-*) markers so older installs keep working.
write_policy_acceptance_pair() {
  local dir="$1"
  local hash="$2"
  local via="$3"
  write_policy_acceptance "$dir/lgt-policy-accepted" "$hash" "$via"
  write_policy_acceptance "$dir/csp-policy-accepted" "$hash" "$via"
}

# True if either lgt or legacy csp marker matches.
policy_acceptance_matches_any() {
  local dir="$1"
  local want_hash="$2"
  policy_acceptance_matches "$dir/lgt-policy-accepted" "$want_hash" \
    || policy_acceptance_matches "$dir/csp-policy-accepted" "$want_hash"
}

# Ensure both marker names exist when one already matches (upgrade path). Does not
# overwrite a matching marker (preserves agree_via / accepted_at).
ensure_policy_acceptance_twins() {
  local dir="$1"
  local hash="$2"
  local via="${3:-prior-marker}"
  if ! policy_acceptance_matches "$dir/lgt-policy-accepted" "$hash"; then
    write_policy_acceptance "$dir/lgt-policy-accepted" "$hash" "$via"
  fi
  if ! policy_acceptance_matches "$dir/csp-policy-accepted" "$hash"; then
    write_policy_acceptance "$dir/csp-policy-accepted" "$hash" "$via"
  fi
}

require_policy_agreement() {
  local hash legal_dir name marker_user_dir marker_project_dir via="" origin="" web="" answer=""
  legal_dir="$KIT_ROOT/docs/legal"
  if [[ ! -d "$legal_dir" ]]; then
    echo "error: public policy directory missing: $legal_dir" >&2
    echo "Clone/update the kit so docs/legal/ is present, then re-run install." >&2
    exit 1
  fi
  for name in "${POLICY_DOC_NAMES[@]}"; do
    if [[ ! -f "$legal_dir/$name" ]]; then
      echo "error: missing public policy document: $legal_dir/$name" >&2
      exit 1
    fi
  done
  hash="$(policy_docs_hash)" || exit 1
  if [[ ${#hash} -ne 64 ]]; then
    echo "error: invalid policy hash (refusing empty/broken digest)" >&2
    exit 1
  fi
  # Empty SHA-256 of zero bytes — must never accept (guards against empty doc set bugs).
  if [[ "$hash" == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" ]]; then
    echo "error: policy hash is empty-document digest — refusing install" >&2
    exit 1
  fi

  marker_user_dir="$HOME/.cursor"
  marker_project_dir=""
  if [[ -n "${PROJECT:-}" && "$USER_ONLY" -eq 0 ]]; then
    marker_project_dir="$PROJECT/.cursor"
  fi

  if [[ -n "$marker_project_dir" ]] && policy_acceptance_matches_any "$marker_project_dir" "$hash"; then
    echo "policy: already accepted ($marker_project_dir/lgt-policy-accepted or csp-policy-accepted)"
    ensure_policy_acceptance_twins "$marker_project_dir" "$hash" "prior-marker"
    return 0
  fi
  if policy_acceptance_matches_any "$marker_user_dir" "$hash"; then
    echo "policy: already accepted ($marker_user_dir/lgt-policy-accepted or csp-policy-accepted)"
    ensure_policy_acceptance_twins "$marker_user_dir" "$hash" "prior-marker"
    if [[ -n "$marker_project_dir" ]]; then
      write_policy_acceptance_pair "$marker_project_dir" "$hash" "prior-user"
    fi
    return 0
  fi

  echo
  echo "Public policy agreement required before install/update continues."
  echo "Product: Loregate (LGT) — $legal_dir/NAME-OPTIONS.md"
  echo "Please read these documents in the kit checkout:"
  for name in "${POLICY_DOC_NAMES[@]}"; do
    echo "  - $legal_dir/$name"
  done
  echo "Index: $legal_dir/README.md"
  origin="$(git -C "$KIT_ROOT" remote get-url origin 2>/dev/null || true)"
  if [[ -n "$origin" ]]; then
    case "$origin" in
      *github.com*)
        web="${origin%.git}"
        web="${web/#git@github.com:/https://github.com/}"
        echo "Or on GitHub (if published): $web/tree/HEAD/docs/legal"
        ;;
    esac
  fi
  echo

  if [[ "$AGREE_POLICY" -eq 1 ]]; then
    via="flag"
  elif [[ -t 0 ]]; then
    echo "Do you agree to the Privacy Policy, Terms, Disclaimer, and NOTICE?"
    printf "Agree? [y/N]: "
    IFS= read -r answer || true
    case "$answer" in
      yes|YES|Yes|y|Y)
        via="prompt"
        ;;
      *)
        echo "Aborted: public policy not accepted. Re-run with --agree-policy / --i-agree (or LGT_AGREE_POLICY=1 / CSP_AGREE_POLICY=1)." >&2
        exit 1
        ;;
    esac
  else
    echo "error: non-interactive install requires --agree-policy (or --i-agree / LGT_AGREE_POLICY=1 / CSP_AGREE_POLICY=1)" >&2
    echo "       after you have read docs/legal/ (Privacy, Terms, Disclaimer, NOTICE)." >&2
    exit 1
  fi

  write_policy_acceptance_pair "$marker_user_dir" "$hash" "$via"
  if [[ -n "$marker_project_dir" ]]; then
    write_policy_acceptance_pair "$marker_project_dir" "$hash" "$via"
  fi
}

echo "kit: $KIT_ROOT"
echo "mode: $MODE"

require_policy_agreement

install_user_bits

if [[ "$USER_ONLY" -eq 0 && -n "$PROJECT" ]]; then
  install_project_bits
fi

apply_pipeline_language

# Curated third-party skills from skill-map (human-launched installer only).
# npx/network failure must not brick kit links.
if [[ "$SKIP_THIRD_PARTY_SKILLS" -eq 1 ]]; then
  export LGT_SKIP_THIRD_PARTY_SKILLS=1
  export CSP_SKIP_THIRD_PARTY_SKILLS=1
fi
mtp_install_curated "${PROJECT:-}"

echo "done."
if [[ -n "$PROJECT" && "$USER_ONLY" -eq 0 ]]; then
  echo "project: $PROJECT"
  echo "agents also in: $PROJECT/.cursor/agents/  (visible in this project’s Cursor UI/CLI)"
elif [[ "$USER_ONLY" -eq 1 ]]; then
  echo
  echo "NOTE: --user-only only links into ~/.cursor/agents|commands|skills."
  echo "  • In Cursor IDE: reload the window, then @csp-engineer-reviewer / @csp-pr-reviewer (subagents)."
  echo "  • Cursor CLI completions often list only <project>/.cursor/agents — run \`lgt install\` from your app (no --user-only) for project-visible agents."
  echo "  • Check: ls -la ~/.cursor/agents"
fi
echo "next: open the project in Cursor → /lgt-start-task  /lgt-approve-plan  /lgt-pr-review  /lgt-engineer-review"
echo "tip: deprecated /csp-* command stubs still install and forward to /lgt-*"
echo "tip: mapped third-party skills are installed from skill-map.md unless --skip-third-party-skills"
echo "tip: policy agreement → .cursor/lgt-policy-accepted (and legacy csp-policy-accepted); docs/legal/"
if [[ -z "$PIPELINE_LANGUAGE" ]]; then
  echo "tip: set chat language with --language <code> / --lang <code> or LGT_PIPELINE_LANGUAGE (alias CSP_PIPELINE_LANGUAGE; default en when unset; Russian forbidden)"
fi

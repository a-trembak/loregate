#!/usr/bin/env bash
# Jira key / site / issue-type helpers (sourceable library).
# Usage: source scripts/jira-issue.sh

jira_extract_key() {
  local input="$1" key=""
  if [[ "$input" =~ ([A-Za-z][A-Za-z0-9]+-[0-9]+) ]]; then
    key="${BASH_REMATCH[1]}"
    # Bash 3.2 (macOS) has no ${var^^}; use tr.
    printf '%s' "$key" | tr '[:lower:]' '[:upper:]'
    return 0
  fi
  return 1
}

jira_extract_site() {
  local input="$1"
  if [[ "$input" =~ https?://([A-Za-z0-9.-]+\.atlassian\.net) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

jira_looks_like_issue() {
  local input="$1"
  [[ "$input" == *atlassian.net* ]] || [[ "$input" =~ ^[A-Za-z][A-Za-z0-9]+-[0-9]+$ ]]
}

jira_classify_type() {
  local raw="${1:-}" name
  name="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  case "$name" in
    bug|defect|fault|incident|problem|error)
      printf 'bug'
      ;;
    story|task|feature|"new feature"|epic|improvement|"change request")
      printf 'feature'
      ;;
    *)
      printf 'unknown'
      ;;
  esac
}

# Lowercase and strip spaces, hyphens, underscores, apostrophes for status compare.
jira_normalize_status() {
  local s
  s="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
  s="${s// /}"
  s="${s//	/}"
  s="${s//-/}"
  s="${s//_/}"
  s="${s//\'/}"
  printf '%s' "$s"
}

# Usage: jira_status_matches_target in_progress|review "<status or to.name>"
jira_status_matches_target() {
  local target="${1:-}" n
  n="$(jira_normalize_status "${2:-}")"
  case "$target" in
    in_progress)
      case "$n" in
        inprogress|indevelopment|doing|wip|started) return 0 ;;
      esac
      ;;
    review)
      case "$n" in
        review|inreview|esreview|codereview|peerreview|toreview|readyforreview) return 0 ;;
      esac
      ;;
  esac
  return 1
}

# stdin: lines of "id<TAB>destination-status-name". Prints the first matching id.
# Usage: jira_pick_transition_id in_progress|review
jira_pick_transition_id() {
  local target="${1:-}" id name
  while IFS=$'\t' read -r id name || [[ -n "${id:-}" ]]; do
    [[ -z "$id" ]] && continue
    if jira_status_matches_target "$target" "$name"; then
      printf '%s' "$id"
      return 0
    fi
  done
  return 1
}

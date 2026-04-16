#!/usr/bin/env bash
# Unified prompt-logging hook for Claude Code
# Usage: bash .claude/hooks/log.sh <prompt|tool|stop>

set -euo pipefail

# ── JSON helper ──────────────────────────────────────────────────────
extract_json() {
  local key="$1" json="$2"
  printf '%s' "$json" | awk -v k="$key" '
  {
    pattern = "\"" k "\":\""
    if (match($0, pattern)) {
      rest = substr($0, RSTART + RLENGTH)
      val = ""
      for (i = 1; i <= length(rest); i++) {
        c = substr(rest, i, 1)
        if (c == "\\") {
          i++
          nc = substr(rest, i, 1)
          if      (nc == "n") val = val "\n"
          else if (nc == "t") val = val "\t"
          else if (nc == "r") val = val ""
          else                val = val nc
        } else if (c == "\"") {
          break
        } else {
          val = val c
        }
      }
      printf "%s", val
    }
  }'
}

# ── Read stdin + determine mode ──────────────────────────────────────
MODE="${1:-}"
INPUT=$(cat | tr '\n' ' ')

# ── PROMPT ───────────────────────────────────────────────────────────
hook_prompt() {
  local session_id prompt cwd
  session_id=$(extract_json "session_id" "$INPUT")
  prompt=$(extract_json "prompt" "$INPUT" \
    | sed 's/<ide_opened_file>[^<]*<\/ide_opened_file> *//g' \
    | sed 's/<ide_selection>[^<]*<\/ide_selection> *//g' \
    | sed 's/^ *//;s/ *$//')
  cwd=$(extract_json "cwd" "$INPUT")

  [ -z "$session_id" ] && return 0
  [ -z "$cwd" ]        && return 0
  cd "$cwd" || return 0

  local date_str timestamp
  date_str=$(date +"%Y-%m-%d")
  timestamp=$(date +"%H:%M:%S")

  # Use first 8 chars of session_id as unique file identifier
  local short_id="${session_id:0:8}"

  local log_dir="$cwd/.ai-logs"
  mkdir -p "$log_dir"
  local log_file="$log_dir/${date_str}_${short_id}.md"

  # Write file header once
  if [ ! -f "$log_file" ]; then
    local project_name
    project_name=$(basename "$cwd")
    printf '# AI-Log — %s\n' "$project_name" > "$log_file"
  fi

  # Store log path + cwd for tool/stop hooks
  printf '%s\n%s\n' "$log_file" "$cwd" > "/tmp/claude-${session_id}-meta.txt"

  # Append entry header (timestamp only, no title)
  {
    printf '\n### %s\n\n' "$timestamp"
    printf '**Prompt:** %s\n' "$prompt"
    printf '\n**Project:** %s\n\n' "$cwd"
  } >> "$log_file"
}

# ── TOOL ─────────────────────────────────────────────────────────────
hook_tool() {
  local session_id tool_name file_path
  session_id=$(extract_json "session_id" "$INPUT")
  tool_name=$(extract_json "tool_name" "$INPUT")
  file_path=$(extract_json "file_path" "$INPUT")

  [ -z "$session_id" ] && return 0
  [ -z "$file_path" ]  && return 0

  local meta_file="/tmp/claude-${session_id}-meta.txt"
  [ ! -f "$meta_file" ] && return 0

  local cwd
  cwd=$(sed -n '2p' "$meta_file")
  [ -z "$cwd" ] && return 0
  cd "$cwd" || return 0

  # Relative path
  local rel_path
  if [ "${file_path#$cwd/}" != "$file_path" ]; then
    rel_path="${file_path#$cwd/}"
  else
    rel_path="$file_path"
  fi

  local changes_file="/tmp/claude-${session_id}-changes.txt"

  if [ "$tool_name" = "Write" ]; then
    local total_lines
    total_lines=$(wc -l < "$file_path" 2>/dev/null | tr -d ' ')
    printf 'FILE:%s:L1-%s\n' "$rel_path" "$total_lines" >> "$changes_file"
    return 0
  fi

  # Edit tool: use git diff for precise line ranges
  local diff_raw
  diff_raw=$(git diff --unified=0 -- "$file_path" 2>/dev/null)

  if [ -z "$diff_raw" ]; then
    local total_lines
    total_lines=$(wc -l < "$file_path" 2>/dev/null | tr -d ' ')
    printf 'FILE:%s:L1-%s\n' "$rel_path" "$total_lines" >> "$changes_file"
    return 0
  fi

  local line_ranges
  line_ranges=$(
    printf '%s\n' "$diff_raw" \
      | grep "^@@" \
      | sed 's/.*+\([0-9][0-9,]*\).*/\1/' \
      | awk -F',' 'BEGIN { first=1 } {
          start = $1 + 0
          count = (NF > 1) ? $2 + 0 : 1
          if (count == 0) next
          end = start + count - 1
          if (!first) printf ","
          first = 0
          if (start == end) printf "L%d", start
          else printf "L%d-%d", start, end
        } END { print "" }' \
      | tr -d '\n'
  )

  printf 'FILE:%s:%s\n' "$rel_path" "$line_ranges" >> "$changes_file"
}

# ── STOP ─────────────────────────────────────────────────────────────
hook_stop() {
  local session_id
  session_id=$(extract_json "session_id" "$INPUT")
  [ -z "$session_id" ] && return 0

  local meta_file="/tmp/claude-${session_id}-meta.txt"
  local changes_file="/tmp/claude-${session_id}-changes.txt"
  [ ! -f "$meta_file" ] && return 0

  local log_file
  log_file=$(sed -n '1p' "$meta_file")
  [ -z "$log_file" ] && return 0

  if [ -f "$changes_file" ] && [ -s "$changes_file" ]; then
    printf '**Files:**\n' >> "$log_file"
    awk '/^FILE:/ {
      sub(/^FILE:/, "")
      colon = index($0, ":")
      if (colon > 0) {
        file_name = substr($0, 1, colon - 1)
        line_ref  = substr($0, colon + 1)
        printf "- `%s` (%s)\n", file_name, line_ref
      }
    }' "$changes_file" >> "$log_file"
  fi

  printf '\n---\n' >> "$log_file"
  rm -f "$meta_file" "$changes_file"
}

# ── Dispatch ─────────────────────────────────────────────────────────
case "$MODE" in
  prompt) hook_prompt ;;
  tool)   hook_tool   ;;
  stop)   hook_stop   ;;
  *)      echo "Usage: log.sh <prompt|tool|stop>" >&2; exit 1 ;;
esac

exit 0

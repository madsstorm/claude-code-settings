#!/usr/bin/env bash
input=$(cat)

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; BLUE='\033[34m'; RESET='\033[0m'

# Git repo (owner/name)
repo=$(echo "$input" | jq -r '.workspace.repo | if . then .owner + "/" + .name else empty end')

if [ -n "$repo" ]; then
  branch=$(git branch --show-current 2>/dev/null)
  staged=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
  modified=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')

  branchstatus=""
  [ "$staged" -gt 0 ] && branchstatus="${branchstatus} ${GREEN}+${staged}${RESET}"
  [ "$modified" -gt 0 ] && branchstatus="${branchstatus} ${RED}~${modified}${RESET}"

  echo -e "${YELLOW}$repo ${CYAN}[$branch$branchstatus${CYAN}]${RESET}"
fi

inputtokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
outputtokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')
kilotokens=$(( ( ${inputtokens} + ${outputtokens} )  / 1000 ))

used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

parts=()

model=$(echo "$input" | jq -r '.model.display_name')

parts+="[$model]"

if [ -n "$used" ]; then
  used_int=$(printf '%.0f' "$used")
  # Build a 10-cell block bar: filled cells = floor(used/10)
  filled=$(( used_int / 10 ))
  empty=$(( 10 - filled ))
  bar=""
  for (( i=0; i<filled; i++ )); do bar="${bar}█"; done
  for (( i=0; i<empty;  i++ )); do bar="${bar}░"; done

  if [ "$used_int" -ge 60 ]; then BAR_COLOR="$RED"
  elif [ "$used_int" -ge 40 ]; then BAR_COLOR="$YELLOW"
  else BAR_COLOR="$GREEN"; fi

  parts+=("${BAR_COLOR}${bar} ${kilotokens}k (${used_int}%)${RESET}")
fi

format_duration() {
  local secs=$1
  [ "$secs" -le 0 ] && echo "0m" && return
  local days=$(( secs / 86400 ))
  local hours=$(( (secs % 86400) / 3600 ))
  local mins=$(( (secs % 3600) / 60 ))
  if [ "$days" -gt 0 ]; then echo "${days}d${hours}h"
  elif [ "$hours" -gt 0 ]; then echo "${hours}h${mins}m"
  else echo "${mins}m"; fi
}

rate_bar() {
  local pct_int=$1 label=$2
  local filled=$(( pct_int / 10 ))
  local empty=$(( 10 - filled ))
  local bar=""
  for (( i=0; i<filled; i++ )); do bar="${bar}█"; done
  for (( i=0; i<empty;  i++ )); do bar="${bar}░"; done
  if [ "$pct_int" -ge 60 ]; then local color="$RED"
  elif [ "$pct_int" -ge 40 ]; then local color="$YELLOW"
  else local color="$GREEN"; fi
  echo "${color}${bar} ${label}${RESET}"
}

now=$(date +%s)

five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

if [ -n "$five" ]; then
  five_int=$(printf '%.0f' "$five")
  five_label="5h"
  [ -n "$five_resets" ] && five_label="$(format_duration $(( five_resets - now )))/5h"
  parts+=("$(rate_bar "$five_int" "$five_label")")
fi

week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_resets=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

if [ -n "$week" ]; then
  week_int=$(printf '%.0f' "$week")
  week_label="7d"
  [ -n "$week_resets" ] && week_label="$(format_duration $(( week_resets - now )))/7d"
  parts+=("$(rate_bar "$week_int" "$week_label")")
fi

if [ ${#parts[@]} -eq 0 ]; then
  exit 0
fi

echo -e "${parts[*]}"

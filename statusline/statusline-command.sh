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
  [ "$modified" -gt 0 ] && branchstatus="${branchstatus} ${RED}+${modified}${RESET}"

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
  # Build a 10-cell block bar: filled cells = floor(used/10)
  filled=$(( ${used%.*} / 10 ))
  empty=$(( 10 - filled ))
  bar=""
  for (( i=0; i<filled; i++ )); do bar="${bar}█"; done
  for (( i=0; i<empty;  i++ )); do bar="${bar}░"; done
  
  if [ "$used" -ge 60 ]; then BAR_COLOR="$RED"
  elif [ "$used" -ge 40 ]; then BAR_COLOR="$YELLOW"
  else BAR_COLOR="$GREEN"; fi
  
  parts+=("${BAR_COLOR}${bar} ${kilotokens}k (${used}%)${RESET}")
fi

five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

if [ -n "$five" ]; then
  five_int=$(printf '%.0f' "$five")
  if [ "$five_int" -ge 80 ]; then
  RATE_COLOR="$RED"
  parts+=("🕑${RATE_COLOR}${five_int}%${RESET}")
  fi
fi

if [ -n "$week" ]; then
  week_int=$(printf '%.0f' "$week")
  if [ "$week_int" -ge 80 ]; then
  RATE_COLOR="$RED"
  parts+=("📅${RATE_COLOR}${week_int}%${RESET}")
  fi
fi

if [ ${#parts[@]} -eq 0 ]; then
  exit 0
fi

echo -e "${parts[*]}"

# printf '%s' "$(IFS=' | '; echo "${parts[*]}")"

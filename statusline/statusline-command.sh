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

used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

parts=()

model=$(echo "$input" | jq -r '.model.display_name')

parts+=("[$model]")

if [ -n "$used" ]; then
  used_int=$(printf '%.0f' "$used")

  # Current context occupancy. Mirrors used_percentage, which is input-only:
  # input + cache_creation + cache_read (output_tokens are deliberately excluded).
  contexttokens=$(echo "$input" | jq -r '[.context_window.current_usage.input_tokens, .context_window.current_usage.cache_creation_input_tokens, .context_window.current_usage.cache_read_input_tokens] | map(. // 0) | add')
  kilotokens=$(( contexttokens / 1000 ))
  # Build a 10-cell block bar: filled cells = floor(used/10)
  filled=$(( used_int / 10 ))
  empty=$(( 10 - filled ))
  bar=""
  for (( i=0; i<filled; i++ )); do bar="${bar}█"; done
  for (( i=0; i<empty;  i++ )); do bar="${bar}░"; done

  # Color tracks model quality degradation, which scales with ABSOLUTE tokens
  # (attention dilution), not window fraction. So absolute is the primary signal;
  # the percent test is a safety net for small windows where the absolute
  # thresholds would never trip before the window is exhausted. Color = the more
  # severe of the two. Independent of rate_bar.
  #
  # Thresholds are tolerance dials, not a measured cliff: degradation is gradual
  # and task-dependent (NoLiMa shows it from single-digit-K on adversarial recall;
  # Chroma shows Opus 4 degrades slowest, no clean boundary). 100k/250k keeps the
  # bar from crying wolf on Opus while still warning before the under-measured
  # deep end (>113k is essentially untested in public benchmarks).
  if [ "$kilotokens" -ge 250 ] || [ "$used_int" -ge 85 ]; then BAR_COLOR="$RED"
  elif [ "$kilotokens" -ge 100 ] || [ "$used_int" -ge 70 ]; then BAR_COLOR="$YELLOW"
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

# Rate-limit color by BURN PACE, not raw usage: a budget meant to be spent is
# only worrying if you're on track to exhaust it before the window resets.
# pace = used% / elapsed%, where elapsed% = (window - remaining) / window * 100.
# Integer-only: ratio >= R  <=>  used*window >= R*100*elapsed.
#   yellow at 1.2x pace, red at 1.5x. Below a 10% floor, low usage is never at risk.
pace_color() {
  local used=$1 window=$2 remaining=$3
  if [ "$used" -lt 10 ]; then echo "$GREEN"; return; fi
  [ "$remaining" -lt 0 ] && remaining=0
  [ "$remaining" -gt "$window" ] && remaining=$window
  local elapsed=$(( window - remaining ))
  if [ "$elapsed" -le 0 ]; then echo "$GREEN"; return; fi
  if [ $(( used * window )) -ge $(( 150 * elapsed )) ]; then echo "$RED"
  elif [ $(( used * window )) -ge $(( 120 * elapsed )) ]; then echo "$YELLOW"
  else echo "$GREEN"; fi
}

rate_bar() {
  local pct_int=$1 label=$2 window=$3 remaining=$4
  local filled=$(( pct_int / 10 ))
  local empty=$(( 10 - filled ))
  local bar=""
  for (( i=0; i<filled; i++ )); do bar="${bar}█"; done
  for (( i=0; i<empty;  i++ )); do bar="${bar}░"; done
  local color
  if [ -n "$remaining" ]; then
    color=$(pace_color "$pct_int" "$window" "$remaining")
  else
    # No reset time available: fall back to raw usage with high cutoffs.
    if [ "$pct_int" -ge 90 ]; then color="$RED"
    elif [ "$pct_int" -ge 75 ]; then color="$YELLOW"
    else color="$GREEN"; fi
  fi
  echo "${color}${bar} ${label}${RESET}"
}

now=$(date +%s)

five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

if [ -n "$five" ]; then
  five_int=$(printf '%.0f' "$five")
  five_label="5h"
  five_remaining=""
  if [ -n "$five_resets" ]; then
    five_remaining=$(( five_resets - now ))
    five_label="$(format_duration $five_remaining)/5h"
  fi
  parts+=("$(rate_bar "$five_int" "$five_label" 18000 "$five_remaining")")
fi

week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_resets=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

if [ -n "$week" ]; then
  week_int=$(printf '%.0f' "$week")
  week_label="7d"
  week_remaining=""
  if [ -n "$week_resets" ]; then
    week_remaining=$(( week_resets - now ))
    week_label="$(format_duration $week_remaining)/7d"
  fi
  parts+=("$(rate_bar "$week_int" "$week_label" 604800 "$week_remaining")")
fi

if [ ${#parts[@]} -eq 0 ]; then
  exit 0
fi

echo -e "${parts[*]}"

#!/bin/bash
#
# ui.sh - UI library for Bold Origins scripts
# This library provides consistent formatting and logging for scripts
#

# Define log levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_SUCCESS=2
LOG_LEVEL_WARNING=3
LOG_LEVEL_ERROR=4

# Default log level if not set by parent script
CURRENT_LOG_LEVEL=${CURRENT_LOG_LEVEL:-$LOG_LEVEL_INFO}

# Colors
RESET="\033[0m"
BOLD="\033[1m"
UNDERLINE="\033[4m"
BLACK="\033[30m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"
BG_BLACK="\033[40m"
BG_RED="\033[41m"
BG_GREEN="\033[42m"
BG_YELLOW="\033[43m"
BG_BLUE="\033[44m"
BG_MAGENTA="\033[45m"
BG_CYAN="\033[46m"
BG_WHITE="\033[47m"

# Function to check if we're in a terminal
function is_terminal() {
  [ -t 1 ]
}

# Function to check if a log level should be displayed
function should_log() {
  local log_level=$1
  [ $log_level -ge $CURRENT_LOG_LEVEL ]
}

# Clear the current line
function clear_line() {
  if is_terminal; then
    echo -ne "\r\033[K"
  fi
}

# Display a header
function ui_header() {
  if is_terminal; then
    echo -e "\n${BOLD}${BG_BLUE}${WHITE} $1 ${RESET}\n"
  else
    echo -e "\n=== $1 ===\n"
  fi
}

# Display a subheader
function ui_subheader() {
  if is_terminal; then
    echo -e "\n${BOLD}${BLUE} $1 ${RESET}\n"
  else
    echo -e "\n--- $1 ---\n"
  fi
}

# Log an info message
function ui_log_info() {
  if should_log $LOG_LEVEL_INFO; then
    if is_terminal; then
      echo -e "${CYAN}ℹ ${RESET}$1"
    else
      echo "INFO: $1"
    fi
  fi
}

# Log a debug message
function ui_log_debug() {
  if should_log $LOG_LEVEL_DEBUG; then
    if is_terminal; then
      echo -e "${MAGENTA}🔍 ${RESET}$1"
    else
      echo "DEBUG: $1"
    fi
  fi
}

# Log a success message
function ui_log_success() {
  if should_log $LOG_LEVEL_SUCCESS; then
    if is_terminal; then
      echo -e "${GREEN}✓ ${RESET}$1"
    else
      echo "SUCCESS: $1"
    fi
  fi
}

# Log a warning message
function ui_log_warning() {
  if should_log $LOG_LEVEL_WARNING; then
    if is_terminal; then
      echo -e "${YELLOW}⚠ ${RESET}$1"
    else
      echo "WARNING: $1"
    fi
  fi
}

# Log an error message
function ui_log_error() {
  if should_log $LOG_LEVEL_ERROR; then
    if is_terminal; then
      echo -e "${RED}✘ ${RESET}$1" >&2
    else
      echo "ERROR: $1" >&2
    fi
  fi
}

# Display a progress spinner
# Usage: ui_spinner "Loading..." sleep 5
function ui_spinner() {
  local message=$1
  local command=$2
  local args=${@:3}
  
  if ! is_terminal; then
    echo "$message..."
    $command $args
    return $?
  fi
  
  local SPINNER='/-\|'
  local i=0
  local pid
  
  # Start the command in the background
  $command $args &
  pid=$!
  
  # Display spinner while command is running
  while kill -0 $pid 2>/dev/null; do
    i=$(( (i+1) % 4 ))
    printf "\r${CYAN}${SPINNER:$i:1}${RESET} %s" "$message"
    sleep 0.1
  done
  
  # Get the exit status of the command
  wait $pid
  local status=$?
  
  # Clear the spinner line
  clear_line
  
  return $status
}

# Display a progress bar
# Usage: ui_progress_bar "Processing" 10 5
function ui_progress_bar() {
  local message=$1
  local total=$2
  local current=$3
  local width=30
  
  if ! is_terminal; then
    echo "$message ($current/$total)..."
    return 0
  fi
  
  local percent=$((current * 100 / total))
  local completed=$((width * current / total))
  local remaining=$((width - completed))
  
  printf "\r${CYAN}%s${RESET} [" "$message"
  printf "%${completed}s" | tr ' ' '='
  printf "%${remaining}s" | tr ' ' ' '
  printf "] %d%%" "$percent"
}

# Ask the user for confirmation
# Returns 0 for yes, 1 for no
function ui_confirm() {
  local message=$1
  local default=${2:-"n"}
  
  if [[ $default == "y" ]]; then
    local prompt="[Y/n]"
  else
    local prompt="[y/N]"
  fi
  
  read -p "$message $prompt " response
  
  if [[ -z $response ]]; then
    response=$default
  fi
  
  case "$response" in
    [yY][eE][sS]|[yY])
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Wait for a process to finish and display a spinner
# Usage: ui_wait_for_pid "Waiting for process" $pid
function ui_wait_for_pid() {
  local message=$1
  local pid=$2
  
  if ! is_terminal; then
    echo "$message..."
    wait $pid
    return $?
  fi
  
  local SPINNER='/-\|'
  local i=0
  
  # Display spinner while process is running
  while kill -0 $pid 2>/dev/null; do
    i=$(( (i+1) % 4 ))
    printf "\r${CYAN}${SPINNER:$i:1}${RESET} %s" "$message"
    sleep 0.1
  done
  
  # Get the exit status of the process
  wait $pid
  local status=$?
  
  # Clear the spinner line
  clear_line
  
  return $status
}

# Display a table
# Usage: ui_table "ID|Name|Status" "1|Test|Running" "2|Example|Stopped"
function ui_table() {
  local header=$1
  local rows=${@:2}
  local IFS="|"
  
  # Calculate column widths
  local -a columns=($header)
  local -a widths=()
  
  for column in "${columns[@]}"; do
    widths+=(${#column})
  done
  
  for row in $rows; do
    local -a fields=($row)
    for i in "${!fields[@]}"; do
      if [ ${#fields[$i]} -gt ${widths[$i]} ]; then
        widths[$i]=${#fields[$i]}
      fi
    done
  done
  
  # Print header
  local -a header_fields=($header)
  local header_line=""
  
  for i in "${!header_fields[@]}"; do
    if [ $i -eq 0 ]; then
      printf "| %-${widths[$i]}s " "${header_fields[$i]}"
    else
      printf "| %-${widths[$i]}s " "${header_fields[$i]}"
    fi
    header_line+="|-"
    for j in $(seq 1 ${widths[$i]}); do
      header_line+="-"
    done
    header_line+=" "
  done
  printf "|\n"
  
  echo "$header_line|"
  
  # Print rows
  for row in $rows; do
    local -a fields=($row)
    for i in "${!fields[@]}"; do
      if [ $i -eq 0 ]; then
        printf "| %-${widths[$i]}s " "${fields[$i]}"
      else
        printf "| %-${widths[$i]}s " "${fields[$i]}"
      fi
    done
    printf "|\n"
  done
}

# Export functions
export -f ui_header
export -f ui_subheader
export -f ui_log_info
export -f ui_log_debug
export -f ui_log_success
export -f ui_log_warning
export -f ui_log_error
export -f ui_spinner
export -f ui_progress_bar
export -f ui_confirm
export -f ui_wait_for_pid
export -f ui_table 
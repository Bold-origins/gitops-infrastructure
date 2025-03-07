#!/bin/bash
# ui.sh: UI Helper Functions
# Provides consistent UI elements for all GitOps scripts

# Color definitions
export UI_COLOR_RESET='\033[0m'
export UI_COLOR_GREEN='\033[0;32m'
export UI_COLOR_YELLOW='\033[0;33m'
export UI_COLOR_RED='\033[0;31m'
export UI_COLOR_BLUE='\033[0;34m'
export UI_COLOR_CYAN='\033[0;36m'
export UI_COLOR_MAGENTA='\033[0;35m'
export UI_COLOR_GRAY='\033[0;90m'

# Icons for various states
export UI_ICON_INFO="ℹ️"
export UI_ICON_WARNING="⚠️"
export UI_ICON_ERROR="❌"
export UI_ICON_SUCCESS="✅"
export UI_ICON_QUESTION="❓"
export UI_ICON_LOADING="🔄"
export UI_ICON_CLOCK="⏱️"
export UI_ICON_GEAR="⚙️"

# Log a message with timestamp
ui_log() {
  local color="$1"
  local icon="$2"
  local message="$3"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo -e "${color}[${timestamp}] ${icon} ${message}${UI_COLOR_RESET}"
}

# Log an info message
ui_log_info() {
  ui_log "${UI_COLOR_BLUE}" "${UI_ICON_INFO}" "$1"
}

# Log a success message
ui_log_success() {
  ui_log "${UI_COLOR_GREEN}" "${UI_ICON_SUCCESS}" "$1"
}

# Log a warning message
ui_log_warning() {
  ui_log "${UI_COLOR_YELLOW}" "${UI_ICON_WARNING}" "$1"
}

# Log an error message
ui_log_error() {
  ui_log "${UI_COLOR_RED}" "${UI_ICON_ERROR}" "$1"
}

# Display a header
ui_header() {
  local message="$1"
  local width=80
  local line=$(printf "%${width}s" | tr ' ' '=')
  echo -e "\n${UI_COLOR_CYAN}${line}${UI_COLOR_RESET}"
  echo -e "${UI_COLOR_CYAN}   ${message}${UI_COLOR_RESET}"
  echo -e "${UI_COLOR_CYAN}${line}${UI_COLOR_RESET}\n"
}

# Display a subheader
ui_subheader() {
  local message="$1"
  echo -e "\n${UI_COLOR_CYAN}== ${message} ==${UI_COLOR_RESET}\n"
}

# Ask for confirmation
ui_confirm() {
  local message="$1"
  local default="${2:-y}"
  
  if [[ "$default" == "y" ]]; then
    read -p "${UI_ICON_QUESTION} ${message} (Y/n): " response
    response=${response:-y}
  else
    read -p "${UI_ICON_QUESTION} ${message} (y/N): " response
    response=${response:-n}
  fi
  
  [[ "$response" =~ ^[Yy] ]]
}

# Prompt for input
ui_prompt() {
  local message="$1"
  local default="$2"
  
  if [[ -n "$default" ]]; then
    read -p "${UI_ICON_QUESTION} ${message} [${default}]: " response
    echo "${response:-$default}"
  else
    read -p "${UI_ICON_QUESTION} ${message}: " response
    echo "$response"
  fi
}

# Show a spinner while running a command
ui_spinner() {
  local message="$1"
  local cmd="$2"
  
  # Start the spinner
  echo -n "${UI_ICON_LOADING} ${message}... "
  
  # Run the command in the background
  eval "$cmd" &
  local pid=$!
  
  # Display spinner while command is running
  local spin='-\|/'
  local i=0
  while kill -0 $pid 2>/dev/null; do
    i=$(( (i+1) % 4 ))
    printf "\r${UI_ICON_LOADING} ${message}... ${spin:$i:1}"
    sleep 0.1
  done
  
  # Wait for command to finish and get exit code
  wait $pid
  local exit_code=$?
  
  if [[ $exit_code -eq 0 ]]; then
    printf "\r${UI_ICON_SUCCESS} ${message}... ${UI_COLOR_GREEN}done${UI_COLOR_RESET}\n"
  else
    printf "\r${UI_ICON_ERROR} ${message}... ${UI_COLOR_RED}failed${UI_COLOR_RESET}\n"
  fi
  
  return $exit_code
}

# Show progress bar
ui_progress_bar() {
  local current="$1"
  local total="$2"
  local message="${3:-Progress}"
  local width=50
  
  # Calculate percentage
  local percent=$((current * 100 / total))
  local completed=$((width * current / total))
  
  # Build progress bar
  local bar=""
  for ((i=0; i<width; i++)); do
    if [[ $i -lt $completed ]]; then
      bar="${bar}${UI_COLOR_GREEN}█${UI_COLOR_RESET}"
    else
      bar="${bar}${UI_COLOR_GRAY}░${UI_COLOR_RESET}"
    fi
  done
  
  # Display progress bar
  printf "\r${message}: [${bar}] ${percent}%% (${current}/${total})"
  
  # Add newline if complete
  if [[ $current -eq $total ]]; then
    echo ""
  fi
} 
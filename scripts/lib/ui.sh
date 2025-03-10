#!/bin/bash
# UI Utilities for GitOps Scripts
# Provides common UI functions for all component scripts

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Formatting
BOLD='\033[1m'
UNDERLINE='\033[4m'

# Log levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARNING=2
LOG_LEVEL_ERROR=3
LOG_LEVEL_SUCCESS=4

# Set default log level
CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}

# Header functions
ui_header() {
  echo -e "${BOLD}${BLUE}==== $1 ====${NC}"
}

ui_subheader() {
  echo -e "${BOLD}${CYAN}--- $1 ---${NC}"
}

# Log functions
ui_log_debug() {
  if [[ ${CURRENT_LOG_LEVEL} -le ${LOG_LEVEL_DEBUG} ]]; then
    echo -e "${PURPLE}[DEBUG]${NC} $1"
  fi
}

ui_log_info() {
  if [[ ${CURRENT_LOG_LEVEL} -le ${LOG_LEVEL_INFO} ]]; then
    echo -e "${BLUE}[INFO]${NC} $1"
  fi
}

ui_log_warning() {
  if [[ ${CURRENT_LOG_LEVEL} -le ${LOG_LEVEL_WARNING} ]]; then
    echo -e "${YELLOW}[WARNING]${NC} $1"
  fi
}

ui_log_error() {
  if [[ ${CURRENT_LOG_LEVEL} -le ${LOG_LEVEL_ERROR} ]]; then
    echo -e "${RED}[ERROR]${NC} $1"
  fi
}

ui_log_success() {
  if [[ ${CURRENT_LOG_LEVEL} -le ${LOG_LEVEL_SUCCESS} ]]; then
    echo -e "${GREEN}[SUCCESS]${NC} $1"
  fi
}

# Progress functions
ui_spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

ui_progress() {
  local current=$1
  local total=$2
  local message=$3
  local percent=$(( ($current * 100) / $total ))
  local progress=$(( ($current * 50) / $total ))
  
  printf "[%-50s] %d%% %s" $(printf "%${progress}s" | tr ' ' '#') $percent "$message"
  echo -ne "\r"
  
  if [[ $current -eq $total ]]; then
    echo
  fi
}

# Prompt functions
ui_confirm() {
  local message=${1:-"Continue?"}
  local defaultvalue=${2:-"Y"}
  
  if [[ $defaultvalue == "Y" ]]; then
    prompt="[Y/n]"
  else
    prompt="[y/N]"
  fi
  
  echo -ne "${YELLOW}$message $prompt ${NC}"
  read -r answer
  
  if [[ -z "$answer" ]]; then
    answer=$defaultvalue
  fi
  
  case "$answer" in
    [yY][eE][sS]|[yY])
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

ui_prompt() {
  local message=$1
  local defaultvalue=$2
  
  if [[ -n "$defaultvalue" ]]; then
    echo -ne "${YELLOW}$message [${defaultvalue}]: ${NC}"
  else
    echo -ne "${YELLOW}$message: ${NC}"
  fi
  
  read -r answer
  
  if [[ -z "$answer" && -n "$defaultvalue" ]]; then
    answer=$defaultvalue
  fi
  
  echo "$answer"
}

# Display functions
ui_divider() {
  echo -e "${BLUE}----------------------------------------${NC}"
}

ui_title() {
  ui_divider
  echo -e "${BOLD}${BLUE}$1${NC}"
  ui_divider
}

ui_section() {
  echo
  echo -e "${BOLD}${CYAN}$1${NC}"
  echo -e "${CYAN}$(printf '%*s' "${#1}" '' | tr ' ' '-')${NC}"
}

# Export all functions
export -f ui_header
export -f ui_subheader
export -f ui_log_debug
export -f ui_log_info
export -f ui_log_warning
export -f ui_log_error
export -f ui_log_success
export -f ui_spinner
export -f ui_progress
export -f ui_confirm
export -f ui_prompt
export -f ui_divider
export -f ui_title
export -f ui_section 
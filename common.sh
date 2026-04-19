# common.sh
#
# Shared output helpers for infrastructure and automation scripts.
#
# Purpose:
#  - Provide consistent, color-coded terminal output
#  - Separate neutrual progress message for check/result messages
#  - keep loggin simple and resuable across many projects
#
# Design:
#  - Use step/info for general workflow output
#  - Use pass/warn/fail only for check or result-style output
#  - Disable colors automatically when stdout is not a terminal
#
# Author:
#  - Jared Husson
#
#   ===============================================================
#   Color Initialization
#   ===============================================================
#
# init_colors
# Description:
#   Initalizes ANSI color variables when running in a terminal.
#
# Preconditions:
#  - None
#
# Postconditions:
#  - Color variables are set
#  - Colors are disabled automaticallu for non-interactive output
#
# Returns:
# - 0
#
# Notes:
#  - This function is intended to be called once when the file is sourced.
init_colors() {
	if [[ -t 1 ]]; then
		RED="\033[0;31m"
		YELLOW="\033[1;33m"
		GREEN="\033[0;32m"
		BLUE="\033[0;34m"
		CYAN="\033[0;36m"
		BOLD="\033[1m"
		NC="\033[0m"
	else
		RED=""
		YELLOW=""
		GREEN=""
		BLUE=""
		CYAN=""
		BOLD=""
		NC=""
	fi
}

# =================================================================================
# General output helpers
# =================================================================================
#
# step
# Description:
#  - Prints a major section heading for the current script stage.
#
# Preconditions:
#  - Accepts one or more arguments as the displayed message
#
# Postconditions:
#  - A formatted section header is written to stdout
#
# Returns:
#  - 0
#
# Notes:
#  - Use for major phases like install, configure, validate, or cleanup.
#
step() {
	echo
	echo -e "${BOLD}${CYAN}==> $*${NC}"
}

# info
# Description:
#  - Prints a neutral informational message.
#
# Preconditions:
#  - Accepts one or more arguments as the displayed message
#
# Postconditions:
#  - A formatted informational line is written to stdout
#
# Returns:
#  - 0
#
# Notes:
#  - Use for progress messages that are not pass/fail checks.
#
info() {
	echo -e "${BLUE}[INFO]${NC} $*"
}

# =================================================================================
# Check/result output helpers
# =================================================================================
#
# pass
# Description:
# - Prints a successful check/result message.
#
# Preconditions:
#  - Accepts one or more arguments as the displayed message.
#
# Postconditions:
#  - A formatted PASS line is written to stdout
#
# Notes:
#  - Use when a validation or verification step succeeds.
#
pass() {
	echo -e "${GREEN}[PASS]${NC} $*"
}

# fail
# Description:
# - Prints a failure message for a failed check or operation.
#
# Preconditions:
#  - Accepts one or more arguments as the displayed message.
#
# Postconditions:
#  - A formatted FAIL line is written to stdout
#
# Returns:
#  - 0
#
# Notes:
#  - This function only prints a failure message. 
#  - It does not exit the script.
#
fail() {
	echo -e "${RED}[FAIL]${NC} $*"
}

# die
# Description:
#  - Prints a failure message and terminates the current script.
#
# Preconditions:
#  - Accepts one or more arguments as the displayed message.
# 
# Postconditions:
#  - A fail line is printed
#  - The script exits with status code 1
#
# Returns:
#  - Does not return on failure
#
# Notes:
#  - Use for fatal errors where the script cannot continue safely.
#
die() {
	fail "$*"
	exit 1
}

# =================================================================================
# Initialization
# =================================================================================

init_colors

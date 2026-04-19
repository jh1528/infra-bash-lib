# health.sh
#
# Shared health-check helpers for infrastructure and automation scripts.
#
# Purpose:
#  - Provide reusable system health checks
#  - Report disk, memory, and CPU/load conditions consistently
#  - Support both runtime health validation and install-readiness checks
#  - Use common.sh output helpers for clean check/result messaging
#
# Design:
#  - Keep checks small, focused, and reusable
#  - Use pass/warn/fail only for result-style output
#  - Return meaningful status codes for script logic
#  - Avoid auto-running checks when the file is sourced
#
# Dependencies:
#  - common.sh should be sourced before this file
#
# Author:
#  - Jared Husson
#
# ================================================================================
# Internal validation helpers
# ================================================================================

_is_integer() {
	[[ "$1" =~ ^[0-9]+$ ]]
}

_is_number() {
	[[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

_validate_percent_thresholds() {
	local warn_threshold="$1"
	local fail_threshold="$2"

	if [[ -z "$warn_threshold" || -z "$fail_threshold" ]]; then
		fail "Threshold validation failed: missing warning or failure threshold"
		return 2
	fi

	if ! _is_integer "$warn_threshold" || ! _is_integer "$fail_threshold"; then
		fail "Threshold validation failed: percentage thresholds must be integers"
		return 2
	fi

	if (( warn_threshold < 0 || warn_threshold > 100 )); then
		fail "Threshold validation failed: warning threshold must be between 0 and 100"
		return 2
	fi

	if (( fail_threshold < 0 || fail_threshold > 100 )); then
		fail "Threshold validation failed: failure threshold must be between 0 and 100"
		return 2
	fi

	if (( warn_threshold >= fail_threshold )); then
		fail "Threshold validation failed: warning threshold must be less than failure threshold"
		return 2
	fi

	return 0
}

_validate_load_thresholds() {
	local warn_threshold="$1"
	local fail_threshold="$2"

	if [[ -z "$warn_threshold" || -z "$fail_threshold" ]]; then
		fail "Threshold validation failed: missing warning or failure threshold"
		return 2
	fi

	if ! _is_number "$warn_threshold" || ! _is_number "$fail_threshold"; then
		fail "Threshold validation failed: load thresholds must be numeric"
		return 2
	fi

	if awk "BEGIN {exit !($warn_threshold >= $fail_threshold)}"; then
		fail "Threshold validation failed: warning threshold must be less than failure threshold"
		return 2
	fi

	return 0
}

_validate_minimum_gb_thresholds() {
	local warn_min_gb="$1"
	local fail_min_gb="$2"

	if [[ -z "$warn_min_gb" || -z "$fail_min_gb" ]]; then
		fail "Threshold validation failed: missing warning or failure minimum"
		return 2
	fi

	if ! _is_integer "$warn_min_gb" || ! _is_integer "$fail_min_gb"; then
		fail "Threshold validation failed: GB minimum thresholds must be integers"
		return 2
	fi

	if (( warn_min_gb < 0 || fail_min_gb < 0 )); then
		fail "Threshold validation failed: GB minimum thresholds must be zero or greater"
		return 2
	fi

	if (( warn_min_gb <= fail_min_gb )); then
		fail "Threshold validation failed: warning minimum must be greater than failure minimum"
		return 2
	fi

	return 0
}

# ================================================================================
# Health check helpers
# ================================================================================
#
# check_disk
# Description:
#  - Checks disk usage percentage for a given mount point.
#
# Preconditions:
#  - Accepts three arguments:
#    1. mount point
#    2. warning threshold percentage
#    3. failure threshold percentage
#  - The mount point must exist in df output
#
# Postconditions:
#  - A formatted PASS/WARN/FAIL line is written to stdout
#
# Returns:
#  - 0 if usage is below warning threshold
#  - 1 if usage is at or above warning threshold
#  - 2 if usage is at or above failure threshold, or on invalid input/runtime error
#
# Notes:
#  - Uses df -P for predictable POSIX-style output
#  - Intended for mounted filesystems such as /, /var, /data, etc.
#
check_disk() {
	local mount_point="$1"
	local warn_threshold="$2"
	local fail_threshold="$3"
	local usage

	if [[ -z "$mount_point" || -z "$warn_threshold" || -z "$fail_threshold" ]]; then
		fail "Usage: check_disk <mount_point> <warn_threshold> <fail_threshold>"
		return 2
	fi

	if ! command -v df >/dev/null 2>&1; then
		fail "Disk check failed: df command not found"
		return 2
	fi

	_validate_percent_thresholds "$warn_threshold" "$fail_threshold" || return 2

	usage="$(df -P "$mount_point" 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}')"

	if [[ -z "$usage" ]]; then
		fail "Disk check failed for ${mount_point}: unable to determine disk usage"
		return 2
	fi

	if ! _is_integer "$usage"; then
		fail "Disk check failed for ${mount_point}: invalid disk usage value"
		return 2
	fi

	if (( usage >= fail_threshold )); then
		fail "Disk usage on ${mount_point} is ${usage}% (threshold: ${fail_threshold}%)"
		return 2
	elif (( usage >= warn_threshold )); then
		warn "Disk usage on ${mount_point} is ${usage}% (threshold: ${warn_threshold}%)"
		return 1
	else
		pass "Disk usage on ${mount_point} is ${usage}%"
		return 0
	fi
}

#
# check_disk_free_gb
# Description:
#  - Checks available disk space in GB for a given mount point.
#
# Preconditions:
#  - Accepts three arguments:
#    1. mount point
#    2. warning minimum free space in GB
#    3. failure minimum free space in GB
#  - The mount point must exist in df output
#
# Postconditions:
#  - A formatted PASS/WARN/FAIL line is written to stdout
#
# Returns:
#  - 0 if free space is at or above the warning minimum
#  - 1 if free space is below the warning minimum but at or above the failure minimum
#  - 2 if free space is below the failure minimum, or on invalid input/runtime error
#
# Notes:
#  - Uses df -Pk so available space is read in kilobytes
#  - Converts the available value to whole GB using integer division
#  - Intended for install-readiness checks such as minimum free space requirements
#
check_disk_free_gb() {
	local mount_point="$1"
	local warn_min_gb="$2"
	local fail_min_gb="$3"
	local available_kb
	local available_gb

	if [[ -z "$mount_point" || -z "$warn_min_gb" || -z "$fail_min_gb" ]]; then
		fail "Usage: check_disk_free_gb <mount_point> <warn_min_gb> <fail_min_gb>"
		return 2
	fi

	if ! command -v df >/dev/null 2>&1; then
		fail "Disk free-space check failed: df command not found"
		return 2
	fi

	_validate_minimum_gb_thresholds "$warn_min_gb" "$fail_min_gb" || return 2

	available_kb="$(df -Pk "$mount_point" 2>/dev/null | awk 'NR==2 {print $4}')"

	if [[ -z "$available_kb" ]]; then
		fail "Disk free-space check failed for ${mount_point}: unable to determine available space"
		return 2
	fi

	if ! _is_integer "$available_kb"; then
		fail "Disk free-space check failed for ${mount_point}: invalid available space value"
		return 2
	fi

	available_gb=$(( available_kb / 1024 / 1024 ))

	if (( available_gb < fail_min_gb )); then
		fail "Free disk on ${mount_point} is ${available_gb}GB (minimum: ${fail_min_gb}GB)"
		return 2
	elif (( available_gb < warn_min_gb )); then
		warn "Free disk on ${mount_point} is ${available_gb}GB (recommended: ${warn_min_gb}GB)"
		return 1
	else
		pass "Free disk on ${mount_point} is ${available_gb}GB"
		return 0
	fi
}

#
# check_memory
# Description:
#  - Checks memory usage percentage based on system memory statistics.
#
# Preconditions:
#  - Accepts two arguments:
#    1. warning threshold percentage
#    2. failure threshold percentage
#  - free command must be available
#
# Postconditions:
#  - A formatted PASS/WARN/FAIL line is written to stdout
#
# Returns:
#  - 0 if usage is below warning threshold
#  - 1 if usage is at or above warning threshold
#  - 2 if usage is at or above failure threshold, or on invalid input/runtime error
#
# Notes:
#  - Uses free output and calculates memory usage as:
#      used / total * 100
#  - This is intended for Linux systems
#
check_memory() {
	local warn_threshold="$1"
	local fail_threshold="$2"
	local total
	local used
	local usage

	if [[ -z "$warn_threshold" || -z "$fail_threshold" ]]; then
		fail "Usage: check_memory <warn_threshold> <fail_threshold>"
		return 2
	fi

	if ! command -v free >/dev/null 2>&1; then
		fail "Memory check failed: free command not found"
		return 2
	fi

	_validate_percent_thresholds "$warn_threshold" "$fail_threshold" || return 2

	read -r total used < <(free -m | awk '/^Mem:/ {print $2, $3}')

	if [[ -z "$total" || -z "$used" ]]; then
		fail "Memory check failed: unable to determine memory usage"
		return 2
	fi

	if ! _is_integer "$total" || ! _is_integer "$used" || (( total == 0 )); then
		fail "Memory check failed: invalid memory values returned"
		return 2
	fi

	usage=$(( used * 100 / total ))

	if (( usage >= fail_threshold )); then
		fail "Memory usage is ${usage}% (threshold: ${fail_threshold}%)"
		return 2
	elif (( usage >= warn_threshold )); then
		warn "Memory usage is ${usage}% (threshold: ${warn_threshold}%)"
		return 1
	else
		pass "Memory usage is ${usage}%"
		return 0
	fi
}

#
# check_memory_total_gb
# Description:
#  - Checks total installed system memory in GB.
#
# Preconditions:
#  - Accepts two arguments:
#    1. warning minimum total memory in GB
#    2. failure minimum total memory in GB
#  - free command must be available
#
# Postconditions:
#  - A formatted PASS/WARN/FAIL line is written to stdout
#
# Returns:
#  - 0 if total memory is at or above the warning minimum
#  - 1 if total memory is below the warning minimum but at or above the failure minimum
#  - 2 if total memory is below the failure minimum, or on invalid input/runtime error
#
# Notes:
#  - Uses free -m and converts total memory to whole GB using integer division
#  - Intended for install-readiness checks such as minimum VM sizing requirements
#  - This checks total installed memory, not current memory usage
#
check_memory_total_gb() {
	local warn_min_gb="$1"
	local fail_min_gb="$2"
	local total_mb
	local total_gb

	if [[ -z "$warn_min_gb" || -z "$fail_min_gb" ]]; then
		fail "Usage: check_memory_total_gb <warn_min_gb> <fail_min_gb>"
		return 2
	fi

	if ! command -v free >/dev/null 2>&1; then
		fail "Memory capacity check failed: free command not found"
		return 2
	fi

	_validate_minimum_gb_thresholds "$warn_min_gb" "$fail_min_gb" || return 2

	total_mb="$(free -m | awk '/^Mem:/ {print $2}')"

	if [[ -z "$total_mb" ]]; then
		fail "Memory capacity check failed: unable to determine total memory"
		return 2
	fi

	if ! _is_integer "$total_mb"; then
		fail "Memory capacity check failed: invalid total memory value"
		return 2
	fi

	total_gb=$(( total_mb / 1024 ))

	if (( total_gb < fail_min_gb )); then
		fail "Total memory is ${total_gb}GB (minimum: ${fail_min_gb}GB)"
		return 2
	elif (( total_gb < warn_min_gb )); then
		warn "Total memory is ${total_gb}GB (recommended: ${warn_min_gb}GB)"
		return 1
	else
		pass "Total memory is ${total_gb}GB"
		return 0
	fi
}

#
# check_cpu_load
# Description:
#  - Checks the 1-minute system load average against a threshold.
#
# Preconditions:
#  - Accepts two arguments:
#    1. warning threshold
#    2. failure threshold
#  - /proc/loadavg must be available
#
# Postconditions:
#  - A formatted PASS/WARN/FAIL line is written to stdout
#
# Returns:
#  - 0 if load is below warning threshold
#  - 1 if load is at or above warning threshold
#  - 2 if load is at or above failure threshold, or on invalid input/runtime error
#
# Notes:
#  - This function checks load average, not direct CPU percentage
#  - Load average is often more useful for infrastructure health checks
#  - Thresholds may be decimal values such as 1.00, 2.50, or 4.00
#
check_cpu_load() {
	local warn_threshold="$1"
	local fail_threshold="$2"
	local load

	if [[ -z "$warn_threshold" || -z "$fail_threshold" ]]; then
		fail "Usage: check_cpu_load <warn_threshold> <fail_threshold>"
		return 2
	fi

	_validate_load_thresholds "$warn_threshold" "$fail_threshold" || return 2

	if [[ ! -r /proc/loadavg ]]; then
		fail "CPU load check failed: /proc/loadavg not available"
		return 2
	fi

	load="$(awk '{print $1}' /proc/loadavg)"

	if [[ -z "$load" ]]; then
		fail "CPU load check failed: unable to determine load average"
		return 2
	fi

	if ! _is_number "$load"; then
		fail "CPU load check failed: invalid load average value"
		return 2
	fi

	if awk "BEGIN {exit !($load >= $fail_threshold)}"; then
		fail "CPU load is ${load} (threshold: ${fail_threshold})"
		return 2
	elif awk "BEGIN {exit !($load >= $warn_threshold)}"; then
		warn "CPU load is ${load} (threshold: ${warn_threshold})"
		return 1
	else
		pass "CPU load is ${load}"
		return 0
	fi
}

# service.sh
#
# Shared service-management helpers for infrastructure and automation scripts.
#
# Purpose:
#  - Provide reusable service validation and control helpers
#  - Standardize service checks and actions across scripts
#  - Use common.sh output helpers for clean result messaging
#
# Design:
#  - Keep functions small, focused, and reusable
#  - Use pass/warn/fail only for result-style output
#  - Return meaningful status codes for script logic
#  - Avoid auto-running actions when the file is sourced
#
# Dependencies:
#  - common.sh should be sourced before this file
#
# Author:
#  - Jared Husson
#
# ================================================================================
# Internal helpers
# ================================================================================

_service_unit_name() {
	local service_name="$1"

	if [[ "$service_name" == *.service ]]; then
		printf '%s\n' "$service_name"
	else
		printf '%s.service\n' "$service_name"
	fi
}

# ================================================================================
# Service helpers
# ================================================================================
#
# service_exists
# Description:
#  - Checks whether a systemd service unit exists.
#
# Preconditions:
#  - Accepts one argument:
#    1. service name
#  - systemctl must be available
#
# Postconditions:
#  - A formatted PASS/FAIL line is written to stdout
#
# Returns:
#  - 0 if the service exists
#  - 2 if the service does not exist or on runtime error
#
# Notes:
#  - Accepts either "nginx" or "nginx.service"
#
service_exists() {
	local service_name="$1"
	local unit_name

	if [[ -z "$service_name" ]]; then
		fail "Usage: service_exists <service_name>"
		return 2
	fi

	if ! command -v systemctl >/dev/null 2>&1; then
		fail "Service check failed: systemctl command not found"
		return 2
	fi

	unit_name="$(_service_unit_name "$service_name")"

	if systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}' | grep -Fxq "$unit_name"; then
		pass "Service exists: ${unit_name}"
		return 0
	fi

	fail "Service not found: ${unit_name}"
	return 2
}

#
# service_running
# Description:
#  - Checks whether a systemd service is currently running.
#
# Preconditions:
#  - Accepts one argument:
#    1. service name
#  - systemctl must be available
#
# Postconditions:
#  - A formatted PASS/WARN/FAIL line is written to stdout
#
# Returns:
#  - 0 if the service is running
#  - 1 if the service exists but is not running
#  - 2 if the service does not exist or on runtime error
#
# Notes:
#  - Accepts either "nginx" or "nginx.service"
#
service_running() {
	local service_name="$1"
	local unit_name

	if [[ -z "$service_name" ]]; then
		fail "Usage: service_running <service_name>"
		return 2
	fi

	if ! command -v systemctl >/dev/null 2>&1; then
		fail "Service check failed: systemctl command not found"
		return 2
	fi

	unit_name="$(_service_unit_name "$service_name")"

	if ! service_exists "$service_name" >/dev/null; then
		fail "Service not found: ${unit_name}"
		return 2
	fi

	if systemctl is-active --quiet "$unit_name"; then
		pass "Service is running: ${unit_name}"
		return 0
	fi

	warn "Service is installed but not running: ${unit_name}"
	return 1
}

#
# start_service
# Description:
#  - Starts a systemd service.
#
# Preconditions:
#  - Accepts one argument:
#    1. service name
#  - systemctl must be available
#
# Postconditions:
#  - A formatted PASS/FAIL line is written to stdout
#
# Returns:
#  - 0 if the service was started successfully
#  - 2 if the service does not exist or failed to start
#
# Notes:
#  - Accepts either "nginx" or "nginx.service"
#
start_service() {
	local service_name="$1"
	local unit_name

	if [[ -z "$service_name" ]]; then
		fail "Usage: start_service <service_name>"
		return 2
	fi

	if ! command -v systemctl >/dev/null 2>&1; then
		fail "Service start failed: systemctl command not found"
		return 2
	fi

	unit_name="$(_service_unit_name "$service_name")"

	if ! service_exists "$service_name" >/dev/null; then
		fail "Cannot start missing service: ${unit_name}"
		return 2
	fi

	if systemctl start "$unit_name" >/dev/null 2>&1; then
		pass "Service started: ${unit_name}"
		return 0
	fi

	fail "Failed to start service: ${unit_name}"
	return 2
}

#
# enable_service
# Description:
#  - Enables a systemd service to start at boot.
#
# Preconditions:
#  - Accepts one argument:
#    1. service name
#  - systemctl must be available
#
# Postconditions:
#  - A formatted PASS/FAIL line is written to stdout
#
# Returns:
#  - 0 if the service was enabled successfully
#  - 2 if the service does not exist or failed to enable
#
# Notes:
#  - Accepts either "nginx" or "nginx.service"
#
enable_service() {
	local service_name="$1"
	local unit_name

	if [[ -z "$service_name" ]]; then
		fail "Usage: enable_service <service_name>"
		return 2
	fi

	if ! command -v systemctl >/dev/null 2>&1; then
		fail "Service enable failed: systemctl command not found"
		return 2
	fi

	unit_name="$(_service_unit_name "$service_name")"

	if ! service_exists "$service_name" >/dev/null; then
		fail "Cannot enable missing service: ${unit_name}"
		return 2
	fi

	if systemctl enable "$unit_name" >/dev/null 2>&1; then
		pass "Service enabled: ${unit_name}"
		return 0
	fi

	fail "Failed to enable service: ${unit_name}"
	return 2
}

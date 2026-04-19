# apt.sh
#
# Shared APT package-management helpers for infrastructure and automation scripts.
#
# Purpose:
#  - Provide reusable package installation and validation helpers
#  - Standardize apt-based package operations across scripts
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
# Package helpers
# ================================================================================
#
# package_installed
# Description:
#  - Checks whether a Debian package is installed.
#
# Preconditions:
#  - Accepts one argument:
#    1. package name
#  - dpkg-query must be available
#
# Postconditions:
#  - A formatted PASS/WARN/FAIL line is written to stdout
#
# Returns:
#  - 0 if the package is installed
#  - 1 if the package is not installed
#  - 2 on invalid input or runtime error
#
# Notes:
#  - Intended for Debian/Ubuntu systems
#
package_installed() {
	local package_name="$1"
	local package_status

	if [[ -z "$package_name" ]]; then
		fail "Usage: package_installed <package_name>"
		return 2
	fi

	if ! command -v dpkg-query >/dev/null 2>&1; then
		fail "Package check failed: dpkg-query command not found"
		return 2
	fi

	package_status="$(dpkg-query -W -f='${Status}' "$package_name" 2>/dev/null)"

	if [[ -z "$package_status" ]]; then
		warn "Package is not installed: ${package_name}"
		return 1
	fi

	if [[ "$package_status" == "install ok installed" ]]; then
		pass "Package is installed: ${package_name}"
		return 0
	fi

	warn "Package is not installed: ${package_name}"
	return 1
}

#
# apt_update
# Description:
#  - Updates the local APT package index.
#
# Preconditions:
#  - apt-get must be available
#  - The caller must have sufficient privileges
#
# Postconditions:
#  - A formatted PASS/FAIL line is written to stdout
#
# Returns:
#  - 0 if the package index was updated successfully
#  - 2 on failure
#
# Notes:
#  - Uses apt-get for stable non-interactive scripting behavior
#
apt_update() {
	if ! command -v apt-get >/dev/null 2>&1; then
		fail "APT update failed: apt-get command not found"
		return 2
	fi

	if apt-get update >/dev/null 2>&1; then
		pass "APT package index updated"
		return 0
	fi

	fail "APT update failed"
	return 2
}

#
# apt_install
# Description:
#  - Installs one or more Debian packages using APT.
#
# Preconditions:
#  - Accepts one or more package names
#  - apt-get must be available
#  - The caller must have sufficient privileges
#
# Postconditions:
#  - A formatted PASS/FAIL line is written to stdout
#
# Returns:
#  - 0 if all packages were installed successfully
#  - 2 on invalid input or installation failure
#
# Notes:
#  - Uses apt-get install -y for non-interactive scripting
#  - Accepts multiple package names
#
apt_install() {
	if [[ $# -eq 0 ]]; then
		fail "Usage: apt_install <package_name> [package_name ...]"
		return 2
	fi

	if ! command -v apt-get >/dev/null 2>&1; then
		fail "APT install failed: apt-get command not found"
		return 2
	fi

	if apt-get install -y "$@" >/dev/null 2>&1; then
		pass "Package installation succeeded: $*"
		return 0
	fi

	fail "Package installation failed: $*"
	return 2
}

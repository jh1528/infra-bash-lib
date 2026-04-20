# system.sh
#
# Shared system/file helpers for infrastructure and automation scripts.
#
# Purpose:
#  - Provide reusable filesystem and artifact helpers
#  - Standardize file, directory, download, and systemd-unit operations
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
# Command helpers
# ================================================================================

#
# command_exists
# Description:
#  - Checks whether a command is available in PATH.
#
# Preconditions:
#  - Accepts one argument:
#    1. command name
#
# Postconditions:
#  - A formatted PASS/WARN/FAIL line is written to stdout
#
# Returns:
#  - 0 if the command exists
#  - 1 if the command does not exist
#  - 2 on invalid input
#
command_exists() {
	local command_name="$1"

	if [[ -z "$command_name" ]]; then
		fail "Usage: command_exists <command_name>"
		return 2
	fi

	if command -v "$command_name" >/dev/null 2>&1; then
		pass "Command exists: ${command_name}"
		return 0
	fi

	warn "Command not found: ${command_name}"
	return 1
}

# ================================================================================
# Directory helpers
# ================================================================================

#
# directory_exists
# Description:
#  - Checks whether a directory exists.
#
# Preconditions:
#  - Accepts one argument:
#    1. directory path
#
# Postconditions:
#  - A formatted PASS/WARN/FAIL line is written to stdout
#
# Returns:
#  - 0 if the directory exists
#  - 1 if the directory does not exist
#  - 2 on invalid input
#
directory_exists() {
	local directory_path="$1"

	if [[ -z "$directory_path" ]]; then
		fail "Usage: directory_exists <directory_path>"
		return 2
	fi

	if [[ -d "$directory_path" ]]; then
		pass "Directory exists: ${directory_path}"
		return 0
	fi

	warn "Directory does not exist: ${directory_path}"
	return 1
}

#
# ensure_directory
# Description:
#  - Creates a directory if it does not already exist.
#
# Preconditions:
#  - Accepts one argument:
#    1. directory path
#  - mkdir must be available
#
# Postconditions:
#  - A formatted PASS/FAIL line is written to stdout
#
# Returns:
#  - 0 if the directory exists or was created successfully
#  - 2 on invalid input or runtime error
#
ensure_directory() {
	local directory_path="$1"

	if [[ -z "$directory_path" ]]; then
		fail "Usage: ensure_directory <directory_path>"
		return 2
	fi

	if ! command -v mkdir >/dev/null 2>&1; then
		fail "Directory creation failed: mkdir command not found"
		return 2
	fi

	if [[ -d "$directory_path" ]]; then
		pass "Directory already exists: ${directory_path}"
		return 0
	fi

	if mkdir -p "$directory_path" >/dev/null 2>&1; then
		pass "Directory created: ${directory_path}"
		return 0
	fi

	fail "Failed to create directory: ${directory_path}"
	return 2
}

# ================================================================================
# File helpers
# ================================================================================

#
# file_exists
# Description:
#  - Checks whether a regular file exists.
#
# Preconditions:
#  - Accepts one argument:
#    1. file path
#
# Postconditions:
#  - A formatted PASS/WARN/FAIL line is written to stdout
#
# Returns:
#  - 0 if the file exists
#  - 1 if the file does not exist
#  - 2 on invalid input
#
file_exists() {
	local file_path="$1"

	if [[ -z "$file_path" ]]; then
		fail "Usage: file_exists <file_path>"
		return 2
	fi

	if [[ -f "$file_path" ]]; then
		pass "File exists: ${file_path}"
		return 0
	fi

	warn "File does not exist: ${file_path}"
	return 1
}

#
# backup_file
# Description:
#  - Creates a backup copy of an existing file using a .bak suffix.
#
# Preconditions:
#  - Accepts one argument:
#    1. file path
#  - cp must be available
#
# Postconditions:
#  - A formatted PASS/WARN/FAIL line is written to stdout
#
# Returns:
#  - 0 if the backup was created successfully
#  - 1 if the source file does not exist
#  - 2 on invalid input or runtime error
#
backup_file() {
	local file_path="$1"
	local backup_path

	if [[ -z "$file_path" ]]; then
		fail "Usage: backup_file <file_path>"
		return 2
	fi

	if ! command -v cp >/dev/null 2>&1; then
		fail "File backup failed: cp command not found"
		return 2
	fi

	if [[ ! -f "$file_path" ]]; then
		warn "Cannot back up missing file: ${file_path}"
		return 1
	fi

	backup_path="${file_path}.bak"

	if cp "$file_path" "$backup_path" >/dev/null 2>&1; then
		pass "File backed up: ${backup_path}"
		return 0
	fi

	fail "Failed to back up file: ${file_path}"
	return 2
}

#
# write_file
# Description:
#  - Writes stdin content to a target file path.
#
# Preconditions:
#  - Accepts one argument:
#    1. file path
#  - Parent directory should already exist
#
# Postconditions:
#  - A formatted PASS/FAIL line is written to stdout
#
# Returns:
#  - 0 if the file was written successfully
#  - 2 on invalid input or runtime error
#
# Notes:
#  - Intended to be used with a here-document
#
# Example:
#  write_file /etc/example.conf <<'EOF'
#  key=value
#  EOF
#
write_file() {
	local file_path="$1"

	if [[ -z "$file_path" ]]; then
		fail "Usage: write_file <file_path>"
		return 2
	fi

	if cat >"$file_path"; then
		pass "File written: ${file_path}"
		return 0
	fi

	fail "Failed to write file: ${file_path}"
	return 2
}

#
# install_file
# Description:
#  - Copies a source file to a target destination.
#
# Preconditions:
#  - Accepts two arguments:
#    1. source file path
#    2. destination file path
#  - install command must be available
#
# Postconditions:
#  - A formatted PASS/FAIL line is written to stdout
#
# Returns:
#  - 0 if the file was installed successfully
#  - 2 on invalid input or runtime error
#
install_file() {
	local source_path="$1"
	local destination_path="$2"

	if [[ -z "$source_path" || -z "$destination_path" ]]; then
		fail "Usage: install_file <source_path> <destination_path>"
		return 2
	fi

	if [[ ! -f "$source_path" ]]; then
		fail "File install failed: source file not found: ${source_path}"
		return 2
	fi

	if ! command -v install >/dev/null 2>&1; then
		fail "File install failed: install command not found"
		return 2
	fi

	if install -m 0644 "$source_path" "$destination_path" >/dev/null 2>&1; then
		pass "File installed: ${destination_path}"
		return 0
	fi

	fail "Failed to install file: ${destination_path}"
	return 2
}

# ================================================================================
# Download helpers
# ================================================================================

#
# download_file
# Description:
#  - Downloads a remote file to a target destination using curl or wget.
#
# Preconditions:
#  - Accepts two arguments:
#    1. URL
#    2. destination file path
#
# Postconditions:
#  - A formatted PASS/FAIL line is written to stdout
#
# Returns:
#  - 0 if the file was downloaded successfully
#  - 2 on invalid input or runtime error
#
download_file() {
	local url="$1"
	local destination_path="$2"

	if [[ -z "$url" || -z "$destination_path" ]]; then
		fail "Usage: download_file <url> <destination_path>"
		return 2
	fi

	if command -v curl >/dev/null 2>&1; then
		if curl -fsSL "$url" -o "$destination_path" >/dev/null 2>&1; then
			pass "File downloaded: ${destination_path}"
			return 0
		fi
		fail "Failed to download file with curl: ${url}"
		return 2
	fi

	if command -v wget >/dev/null 2>&1; then
		if wget -q "$url" -O "$destination_path" >/dev/null 2>&1; then
			pass "File downloaded: ${destination_path}"
			return 0
		fi
		fail "Failed to download file with wget: ${url}"
		return 2
	fi

	fail "Download failed: neither curl nor wget is available"
	return 2
}

#
# make_executable
# Description:
#  - Adds executable permissions to a file.
#
# Preconditions:
#  - Accepts one argument:
#    1. file path
#  - chmod must be available
#
# Postconditions:
#  - A formatted PASS/FAIL line is written to stdout
#
# Returns:
#  - 0 if the file was updated successfully
#  - 2 on invalid input or runtime error
#
make_executable() {
	local file_path="$1"

	if [[ -z "$file_path" ]]; then
		fail "Usage: make_executable <file_path>"
		return 2
	fi

	if [[ ! -f "$file_path" ]]; then
		fail "Cannot mark missing file executable: ${file_path}"
		return 2
	fi

	if ! command -v chmod >/dev/null 2>&1; then
		fail "chmod command not found"
		return 2
	fi

	if chmod +x "$file_path" >/dev/null 2>&1; then
		pass "File marked executable: ${file_path}"
		return 0
	fi

	fail "Failed to mark file executable: ${file_path}"
	return 2
}

# ================================================================================
# systemd helpers
# ================================================================================

#
# write_systemd_unit
# Description:
#  - Writes stdin content to a systemd unit file under /etc/systemd/system.
#
# Preconditions:
#  - Accepts one argument:
#    1. unit name
#  - The unit name may be provided with or without .service
#
# Postconditions:
#  - A formatted PASS/FAIL line is written to stdout
#
# Returns:
#  - 0 if the unit file was written successfully
#  - 2 on invalid input or runtime error
#
# Notes:
#  - Intended to be used with a here-document
#
write_systemd_unit() {
	local unit_name="$1"
	local unit_path

	if [[ -z "$unit_name" ]]; then
		fail "Usage: write_systemd_unit <unit_name>"
		return 2
	fi

	if [[ "$unit_name" != *.service ]]; then
		unit_name="${unit_name}.service"
	fi

	unit_path="/etc/systemd/system/${unit_name}"

	if cat >"$unit_path"; then
		pass "systemd unit written: ${unit_path}"
		return 0
	fi

	fail "Failed to write systemd unit: ${unit_path}"
	return 2
}

#
# reload_systemd
# Description:
#  - Reloads the systemd manager configuration.
#
# Preconditions:
#  - systemctl must be available
#
# Postconditions:
#  - A formatted PASS/FAIL line is written to stdout
#
# Returns:
#  - 0 if systemd was reloaded successfully
#  - 2 on runtime error
#
reload_systemd() {
	if ! command -v systemctl >/dev/null 2>&1; then
		fail "systemd reload failed: systemctl command not found"
		return 2
	fi

	if systemctl daemon-reload >/dev/null 2>&1; then
		pass "systemd daemon reloaded"
		return 0
	fi

	fail "Failed to reload systemd daemon"
	return 2
}

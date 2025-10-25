#!/bin/bash
#
# Webhosting Installer - Utility Functions
# Copyright: Daniel Hiller
# License: AGPL-3 or later
#
# Core utility functions for logging, error handling, and system checks
#

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

# log: Write timestamped message to log file and stdout
# Usage: log "message"
log() {
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${timestamp}] ${message}" | tee -a "${LOG_FILE:-/var/log/webhosting-installer/install.log}"
}

# ============================================================================
# ERROR HANDLING
# ============================================================================

# error_exit: Log error, show dialog, and exit with code 1
# Usage: error_exit "error message"
error_exit() {
    local error_msg="$1"
    log "ERROR: ${error_msg}"

    if command -v dialog &> /dev/null; then
        dialog --title "Installation Error" \
            --msgbox "ERROR: ${error_msg}\n\nDetails in: ${LOG_FILE}\n\nPress OK to exit." \
            12 70
        clear
    else
        echo "ERROR: ${error_msg}" >&2
        echo "Details in: ${LOG_FILE}" >&2
    fi

    exit 1
}

# ============================================================================
# SYSTEM CHECKS
# ============================================================================

# check_root: Verify script is running as root
# Exit if not root user
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root. Please use: sudo $0"
    fi
    log "Root privileges verified"
}

# check_debian_13: Verify system is running Debian 13 (Trixie)
# Exit if not Debian 13
check_debian_13() {
    # Check if /etc/os-release exists
    if [[ ! -f /etc/os-release ]]; then
        error_exit "Cannot determine OS version: /etc/os-release not found"
    fi

    # Source OS information
    source /etc/os-release

    # Check if Debian
    if [[ "${ID}" != "debian" ]]; then
        error_exit "This installer only supports Debian. Detected: ${NAME}"
    fi

    # Check version (Debian 13 = Trixie)
    local version_id="${VERSION_ID:-0}"
    if [[ "${version_id}" != "13" ]]; then
        # Also check codename
        if [[ "${VERSION_CODENAME}" != "trixie" ]]; then
            error_exit "This installer requires Debian 13 (Trixie). Detected: ${VERSION}"
        fi
    fi

    DEBIAN_VERSION="${VERSION_ID}"
    log "Debian 13 (Trixie) verified"
}

# ============================================================================
# CONFIGURATION MANAGEMENT
# ============================================================================

# save_config: Save configuration to temporary file
# All global variables are exported to file
save_config() {
    log "Saving configuration to ${TEMP_CONFIG}..."

    cat > "${TEMP_CONFIG}" << EOF
# Webhosting Installer Configuration
# Generated: $(date)

# Webserver
WEBSERVER="${WEBSERVER}"

# PHP Versions
PHP_VERSIONS=(${PHP_VERSIONS[*]})
SURY_REPO_ADDED=${SURY_REPO_ADDED}

# MariaDB
INSTALL_MARIADB="${INSTALL_MARIADB}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD}"
CREATE_DATABASE="${CREATE_DATABASE}"
DB_NAME="${DB_NAME}"
DB_USER="${DB_USER}"
DB_PASSWORD="${DB_PASSWORD}"
DB_HOST="${DB_HOST}"

# Certbot
INSTALL_CERTBOT="${INSTALL_CERTBOT}"

# System
DEBIAN_VERSION="${DEBIAN_VERSION}"
INSTALL_DATE="${INSTALL_DATE}"
LOG_FILE="${LOG_FILE}"
EOF

    chmod 600 "${TEMP_CONFIG}"
    log "Configuration saved successfully"
}

# load_config: Load configuration from file
# Usage: load_config
load_config() {
    if [[ ! -f "${TEMP_CONFIG}" ]]; then
        error_exit "Configuration file not found: ${TEMP_CONFIG}"
    fi

    log "Loading configuration from ${TEMP_CONFIG}..."
    # shellcheck source=/dev/null
    source "${TEMP_CONFIG}"
    log "Configuration loaded successfully"
}

# ============================================================================
# PACKAGE MANAGEMENT
# ============================================================================

# is_installed: Check if package is installed
# Usage: is_installed "package-name"
# Returns: 0 if installed, 1 if not installed
is_installed() {
    local package="$1"
    dpkg -l "${package}" 2>/dev/null | grep -q '^ii'
    return $?
}

# install_package: Install package with error handling
# Usage: install_package "package-name"
install_package() {
    local package="$1"

    if is_installed "${package}"; then
        log "Package ${package} is already installed"
        return 0
    fi

    log "Installing package: ${package}"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${package}" || {
        error_exit "Failed to install package: ${package}"
    }

    log "Package ${package} installed successfully"
}

# ============================================================================
# FILE OPERATIONS
# ============================================================================

# backup_file: Create backup of file before modification
# Usage: backup_file "/path/to/file"
backup_file() {
    local file_path="$1"

    if [[ ! -f "${file_path}" ]]; then
        log "Warning: File does not exist, cannot backup: ${file_path}"
        return 1
    fi

    local backup_path="${file_path}.backup-$(date +%Y%m%d-%H%M%S)"
    cp -p "${file_path}" "${backup_path}" || {
        log "Warning: Failed to backup file: ${file_path}"
        return 1
    }

    log "File backed up: ${backup_path}"
    return 0
}

# ============================================================================
# PASSWORD GENERATION
# ============================================================================

# generate_password: Generate secure random password
# Usage: password=$(generate_password [length])
# Default length: 32 characters
generate_password() {
    local length="${1:-32}"

    # Use openssl for secure random password generation
    if command -v openssl &> /dev/null; then
        openssl rand -base64 48 | tr -d "=+/" | cut -c1-"${length}"
    else
        # Fallback to /dev/urandom
        tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c "${length}"
    fi
}

# ============================================================================
# SERVICE MANAGEMENT
# ============================================================================

# enable_service: Enable and start systemd service
# Usage: enable_service "service-name"
enable_service() {
    local service="$1"

    log "Enabling service: ${service}"
    systemctl enable "${service}" || {
        log "Warning: Failed to enable service: ${service}"
        return 1
    }

    log "Starting service: ${service}"
    systemctl start "${service}" || {
        log "Warning: Failed to start service: ${service}"
        return 1
    }

    log "Service ${service} enabled and started"
    return 0
}

# restart_service: Restart systemd service
# Usage: restart_service "service-name"
restart_service() {
    local service="$1"

    log "Restarting service: ${service}"
    systemctl restart "${service}" || {
        log "Warning: Failed to restart service: ${service}"
        return 1
    }

    log "Service ${service} restarted successfully"
    return 0
}

# reload_service: Reload systemd service configuration
# Usage: reload_service "service-name"
reload_service() {
    local service="$1"

    log "Reloading service: ${service}"
    systemctl reload "${service}" || {
        # Try restart if reload fails
        log "Reload failed, trying restart..."
        systemctl restart "${service}" || {
            log "Warning: Failed to reload/restart service: ${service}"
            return 1
        }
    }

    log "Service ${service} reloaded successfully"
    return 0
}

# is_service_active: Check if service is active
# Usage: is_service_active "service-name"
# Returns: 0 if active, 1 if not active
is_service_active() {
    local service="$1"
    systemctl is-active --quiet "${service}"
    return $?
}

# ============================================================================
# NETWORK FUNCTIONS
# ============================================================================

# get_primary_ip: Get primary IP address of system
# Usage: ip=$(get_primary_ip)
get_primary_ip() {
    hostname -I | awk '{print $1}'
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

# validate_db_name: Validate database name
# Usage: validate_db_name "dbname"
# Returns: 0 if valid, 1 if invalid
validate_db_name() {
    local db_name="$1"

    # Check if empty
    if [[ -z "${db_name}" ]]; then
        return 1
    fi

    # Check length (max 64 characters for MySQL)
    if [[ ${#db_name} -gt 64 ]]; then
        return 1
    fi

    # Check for valid characters (alphanumeric, underscore, hyphen)
    if [[ ! "${db_name}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 1
    fi

    return 0
}

# validate_username: Validate username
# Usage: validate_username "username"
# Returns: 0 if valid, 1 if invalid
validate_username() {
    local username="$1"

    # Check if empty
    if [[ -z "${username}" ]]; then
        return 1
    fi

    # Check length (max 32 characters for MySQL)
    if [[ ${#username} -gt 32 ]]; then
        return 1
    fi

    # Check for valid characters
    if [[ ! "${username}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 1
    fi

    return 0
}

# ============================================================================
# SYSTEM INFORMATION
# ============================================================================

# get_total_memory: Get total system memory in MB
# Usage: memory=$(get_total_memory)
get_total_memory() {
    free -m | awk '/^Mem:/{print $2}'
}

# get_cpu_cores: Get number of CPU cores
# Usage: cores=$(get_cpu_cores)
get_cpu_cores() {
    nproc
}

# ============================================================================
# CLEANUP FUNCTIONS
# ============================================================================

# cleanup_temp_files: Remove temporary files
# Usage: cleanup_temp_files
cleanup_temp_files() {
    log "Cleaning up temporary files..."

    local temp_files=(
        "${TEMP_CONFIG}"
        "/tmp/webhosting-install-*.conf"
    )

    for file in "${temp_files[@]}"; do
        if [[ -f "${file}" ]]; then
            rm -f "${file}"
            log "Removed: ${file}"
        fi
    done
}

# ============================================================================
# END OF UTILS
# ============================================================================

log "Utils library loaded successfully"

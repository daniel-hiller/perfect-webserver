#!/bin/bash
#
# Webhosting Installer - PHP Installation Functions
# Copyright: Daniel Hiller
# License: AGPL-3 or later
#
# PHP multi-version installation and configuration
#

# ============================================================================
# SURY REPOSITORY MANAGEMENT
# ============================================================================

# add_php_repositories: Add Sury PHP repository for all PHP versions
add_php_repositories() {
    if [[ "${SURY_REPO_ADDED}" == "true" ]]; then
        log "Sury PHP repository already added"
        return 0
    fi

    log "Adding Sury PHP repository..."

    # Install prerequisites
    log "Installing repository prerequisites..."
    install_package "lsb-release"
    install_package "apt-transport-https"
    install_package "ca-certificates"
    install_package "wget"
    install_package "gnupg2"

    # Download and add GPG key
    log "Adding Sury repository GPG key..."
    wget -q -O /tmp/php-sury.gpg https://packages.sury.org/php/apt.gpg || {
        error_exit "Failed to download Sury GPG key"
    }

    # Install GPG key
    mv /tmp/php-sury.gpg /etc/apt/trusted.gpg.d/php.gpg
    chmod 644 /etc/apt/trusted.gpg.d/php.gpg

    # Add repository
    log "Adding Sury repository to sources..."
    local codename
    codename=$(lsb_release -sc)
    echo "deb https://packages.sury.org/php/ ${codename} main" > /etc/apt/sources.list.d/php.list

    # Update package lists
    log "Updating package lists with PHP repository..."
    apt-get update -qq || {
        error_exit "Failed to update package lists after adding PHP repository"
    }

    SURY_REPO_ADDED=true
    log "Sury PHP repository added successfully"
}

# ============================================================================
# PHP VERSION INSTALLATION
# ============================================================================

# install_php_version: Install specific PHP version with all extensions
# Usage: install_php_version "8.3"
install_php_version() {
    local version="$1"

    if [[ -z "${version}" ]]; then
        error_exit "PHP version not specified"
    fi

    log "Installing PHP ${version}..."

    # Check if already installed
    if command -v "php${version}" &> /dev/null && systemctl is-active --quiet "php${version}-fpm"; then
        log "PHP ${version} is already installed and running"
        log "Skipping PHP ${version} installation..."
        return 0
    fi

    # Define package list
    local packages=(
        "php${version}-fpm"
        "php${version}-cli"
        "php${version}-common"
        "php${version}-mysql"
        "php${version}-curl"
        "php${version}-gd"
        "php${version}-mbstring"
        "php${version}-xml"
        "php${version}-zip"
        "php${version}-intl"
        "php${version}-bcmath"
        "php${version}-opcache"
    )

    # Add imagick if available (not available for all versions)
    if apt-cache show "php${version}-imagick" &> /dev/null; then
        packages+=("php${version}-imagick")
        log "Package php${version}-imagick is available"
    else
        log "Package php${version}-imagick not available for PHP ${version}"
    fi

    # Install all packages
    log "Installing PHP ${version} packages: ${packages[*]}"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${packages[@]}" || {
        error_exit "Failed to install PHP ${version}"
    }

    log "PHP ${version} installed successfully"

    # Verify installation
    if ! command -v "php${version}" &> /dev/null; then
        error_exit "PHP ${version} installation verification failed"
    fi

    local php_version_output
    php_version_output=$(php${version} -v | head -n 1)
    log "Installed: ${php_version_output}"
}

# ============================================================================
# PHP.INI CONFIGURATION
# ============================================================================

# configure_php_ini: Optimize php.ini settings for webhosting
# Usage: configure_php_ini "8.3"
configure_php_ini() {
    local version="$1"

    if [[ -z "${version}" ]]; then
        error_exit "PHP version not specified for php.ini configuration"
    fi

    log "Configuring php.ini for PHP ${version}..."

    local ini_files=(
        "/etc/php/${version}/fpm/php.ini"
        "/etc/php/${version}/cli/php.ini"
    )

    for ini_file in "${ini_files[@]}"; do
        if [[ ! -f "${ini_file}" ]]; then
            log "Warning: php.ini not found: ${ini_file}"
            continue
        fi

        log "Configuring: ${ini_file}"

        # Backup original file
        backup_file "${ini_file}"

        # Apply optimizations
        sed -i 's/^memory_limit = .*/memory_limit = 256M/' "${ini_file}"
        sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 64M/' "${ini_file}"
        sed -i 's/^post_max_size = .*/post_max_size = 64M/' "${ini_file}"
        sed -i 's/^max_execution_time = .*/max_execution_time = 300/' "${ini_file}"
        sed -i 's/^max_input_time = .*/max_input_time = 300/' "${ini_file}"
        sed -i 's/^;date.timezone =.*/date.timezone = Europe\/Berlin/' "${ini_file}"

        # Enable opcache optimizations (only for FPM)
        if [[ "${ini_file}" == *"/fpm/"* ]]; then
            sed -i 's/^;opcache.enable=.*/opcache.enable=1/' "${ini_file}"
            sed -i 's/^;opcache.memory_consumption=.*/opcache.memory_consumption=128/' "${ini_file}"
            sed -i 's/^;opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=8/' "${ini_file}"
            sed -i 's/^;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=10000/' "${ini_file}"
            sed -i 's/^;opcache.revalidate_freq=.*/opcache.revalidate_freq=2/' "${ini_file}"
            sed -i 's/^;opcache.fast_shutdown=.*/opcache.fast_shutdown=1/' "${ini_file}"
        fi

        log "php.ini configured: ${ini_file}"
    done

    log "php.ini configuration completed for PHP ${version}"
}

# ============================================================================
# PHP-FPM POOL CONFIGURATION
# ============================================================================

# configure_php_fpm_pool: Configure PHP-FPM pool settings
# Usage: configure_php_fpm_pool "8.3"
configure_php_fpm_pool() {
    local version="$1"

    if [[ -z "${version}" ]]; then
        error_exit "PHP version not specified for FPM pool configuration"
    fi

    log "Configuring PHP-FPM pool for PHP ${version}..."

    local pool_file="/etc/php/${version}/fpm/pool.d/www.conf"

    if [[ ! -f "${pool_file}" ]]; then
        error_exit "FPM pool file not found: ${pool_file}"
    fi

    # Backup original file
    backup_file "${pool_file}"

    # Configure pool settings based on system resources
    local cpu_cores
    local total_memory
    cpu_cores=$(get_cpu_cores)
    total_memory=$(get_total_memory)

    # Calculate pm.max_children based on memory (assuming 50MB per child)
    local max_children=$((total_memory / 50))
    [[ ${max_children} -lt 5 ]] && max_children=5
    [[ ${max_children} -gt 50 ]] && max_children=50

    local start_servers=$((max_children / 4))
    [[ ${start_servers} -lt 2 ]] && start_servers=2

    local min_spare=$((start_servers / 2))
    [[ ${min_spare} -lt 1 ]] && min_spare=1

    local max_spare=$((start_servers * 2))

    log "Calculated FPM pool settings: max_children=${max_children}, start_servers=${start_servers}"

    # Apply settings
    sed -i "s/^pm.max_children = .*/pm.max_children = ${max_children}/" "${pool_file}"
    sed -i "s/^pm.start_servers = .*/pm.start_servers = ${start_servers}/" "${pool_file}"
    sed -i "s/^pm.min_spare_servers = .*/pm.min_spare_servers = ${min_spare}/" "${pool_file}"
    sed -i "s/^pm.max_spare_servers = .*/pm.max_spare_servers = ${max_spare}/" "${pool_file}"

    # Set request termination timeout
    sed -i 's/^;request_terminate_timeout = .*/request_terminate_timeout = 300/' "${pool_file}"

    # Enable status page
    sed -i 's/^;pm.status_path = .*/pm.status_path = \/fpm-status/' "${pool_file}"

    # Enable ping page
    sed -i 's/^;ping.path = .*/ping.path = \/fpm-ping/' "${pool_file}"

    log "PHP-FPM pool configured: ${pool_file}"
}

# ============================================================================
# PHP-FPM SERVICE MANAGEMENT
# ============================================================================

# enable_php_fpm_service: Enable and start PHP-FPM service
# Usage: enable_php_fpm_service "8.3"
enable_php_fpm_service() {
    local version="$1"

    if [[ -z "${version}" ]]; then
        error_exit "PHP version not specified for service management"
    fi

    local service_name="php${version}-fpm"

    log "Enabling and starting ${service_name} service..."

    # Enable service
    systemctl enable "${service_name}" || {
        error_exit "Failed to enable ${service_name} service"
    }

    # Start service
    systemctl start "${service_name}" || {
        error_exit "Failed to start ${service_name} service"
    }

    # Verify service is running
    if ! is_service_active "${service_name}"; then
        error_exit "${service_name} service is not running"
    fi

    # Check socket exists
    local socket_path="/run/php/php${version}-fpm.sock"
    if [[ ! -S "${socket_path}" ]]; then
        error_exit "PHP-FPM socket not found: ${socket_path}"
    fi

    log "${service_name} service enabled and running"
    log "Socket available: ${socket_path}"
}

# ============================================================================
# PHP VERSION VERIFICATION
# ============================================================================

# verify_php_installation: Verify PHP installation and configuration
# Usage: verify_php_installation "8.3"
verify_php_installation() {
    local version="$1"

    log "Verifying PHP ${version} installation..."

    # Check PHP CLI
    if ! command -v "php${version}" &> /dev/null; then
        error_exit "PHP ${version} CLI not found"
    fi

    # Check PHP-FPM
    if ! systemctl is-active --quiet "php${version}-fpm"; then
        error_exit "PHP ${version} FPM service not running"
    fi

    # Check socket
    local socket_path="/run/php/php${version}-fpm.sock"
    if [[ ! -S "${socket_path}" ]]; then
        error_exit "PHP ${version} FPM socket not found: ${socket_path}"
    fi

    # Get PHP version info
    local php_info
    php_info=$(php${version} -v | head -n 1)
    log "Verified: ${php_info}"

    # Check loaded extensions
    local extensions
    extensions=$(php${version} -m | wc -l)
    log "Loaded extensions: ${extensions}"

    log "PHP ${version} verification successful"
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# get_php_fpm_socket: Get socket path for PHP version
# Usage: socket=$(get_php_fpm_socket "8.3")
get_php_fpm_socket() {
    local version="$1"
    echo "/run/php/php${version}-fpm.sock"
}

# list_installed_php_versions: List all installed PHP versions
list_installed_php_versions() {
    log "Listing installed PHP versions..."

    local installed_versions=()

    for version in 5.6 7.0 7.1 7.2 7.3 7.4 8.0 8.1 8.2 8.3 8.4; do
        if command -v "php${version}" &> /dev/null; then
            installed_versions+=("${version}")
        fi
    done

    if [[ ${#installed_versions[@]} -gt 0 ]]; then
        log "Installed PHP versions: ${installed_versions[*]}"
        echo "${installed_versions[@]}"
    else
        log "No PHP versions installed"
        return 1
    fi
}

# ============================================================================
# PHP EXTENSIONS MANAGEMENT
# ============================================================================

# install_additional_php_extension: Install additional PHP extension
# Usage: install_additional_php_extension "8.3" "redis"
install_additional_php_extension() {
    local version="$1"
    local extension="$2"

    log "Installing PHP ${version} extension: ${extension}"

    local package="php${version}-${extension}"

    if is_installed "${package}"; then
        log "Extension already installed: ${package}"
        return 0
    fi

    install_package "${package}"

    # Restart PHP-FPM to load extension
    restart_service "php${version}-fpm"

    log "Extension installed: ${package}"
}

# ============================================================================
# END OF PHP INSTALLER
# ============================================================================

log "PHP installer library loaded successfully"

#!/bin/bash
#
# Webhosting Installer - Node.js Installation Functions
# Copyright: Daniel Hiller
# License: AGPL-3 or later
#
# Functions for installing and managing Node.js
#

# ============================================================================
# NODEJS VERSION CONSTANTS
# ============================================================================

# Node.js LTS and Current versions
declare -A NODEJS_VERSIONS=(
    ["25"]="Current (v25 - Latest)"
    ["24"]="Active LTS - Krypton (v24 - Recommended)"
    ["22"]="Maintenance LTS - Jod (v22)"
    ["20"]="Maintenance LTS - Iron (v20)"
)

# ============================================================================
# NODEJS INSTALLATION FUNCTIONS
# ============================================================================

# install_nodejs: Install Node.js with selected version
# Globals: NODEJS_VERSION
# Arguments: None
# Returns: 0 on success, exits on error
install_nodejs() {
    if [[ -z "${NODEJS_VERSION}" ]] || [[ "${NODEJS_VERSION}" == "no" ]]; then
        log "Node.js installation skipped"
        return 0
    fi

    log "Starting Node.js ${NODEJS_VERSION} installation..."

    # Check if Node.js is already installed
    if command -v node &> /dev/null; then
        local installed_version
        installed_version=$(node -v | grep -oP '\d+' | head -1)

        if [[ "${installed_version}" == "${NODEJS_VERSION}" ]]; then
            log "Node.js ${NODEJS_VERSION} is already installed"

            # Update npm anyway
            log "Updating npm to latest version..."
            if npm install -g npm &>> "${LOG_FILE}"; then
                local npm_version
                npm_version=$(npm -v)
                log "npm updated successfully to version ${npm_version}"
            else
                log "WARNING: Failed to update npm, but continuing..."
            fi

            return 0
        else
            log "Node.js ${installed_version} is installed, but version ${NODEJS_VERSION} was requested"
            log "Proceeding with installation of Node.js ${NODEJS_VERSION}..."
        fi
    fi

    # Download and execute NodeSource setup script
    log "Adding NodeSource repository for Node.js ${NODEJS_VERSION}..."

    local setup_script="/tmp/nodesource_setup.sh"

    if ! curl -fsSL "https://deb.nodesource.com/setup_${NODEJS_VERSION}.x" -o "${setup_script}"; then
        error_exit "Failed to download NodeSource setup script"
    fi

    log "Executing NodeSource setup script..."
    if ! bash "${setup_script}" &>> "${LOG_FILE}"; then
        rm -f "${setup_script}"
        error_exit "Failed to setup NodeSource repository"
    fi

    rm -f "${setup_script}"
    log "NodeSource repository added successfully"

    # Update package lists
    log "Updating package lists..."
    if ! apt-get update -qq &>> "${LOG_FILE}"; then
        error_exit "Failed to update package lists after adding NodeSource repository"
    fi

    # Install Node.js
    log "Installing Node.js ${NODEJS_VERSION}..."
    if ! apt-get install -y -qq nodejs &>> "${LOG_FILE}"; then
        error_exit "Failed to install Node.js"
    fi

    # Verify installation
    if ! command -v node &> /dev/null; then
        error_exit "Node.js installation verification failed: node command not found"
    fi

    if ! command -v npm &> /dev/null; then
        error_exit "Node.js installation verification failed: npm command not found"
    fi

    local node_version
    local npm_version
    node_version=$(node -v)
    npm_version=$(npm -v)

    log "Node.js installed successfully: ${node_version}"
    log "npm installed: ${npm_version}"

    # Update npm to latest version
    log "Updating npm to latest version..."
    if npm install -g npm &>> "${LOG_FILE}"; then
        npm_version=$(npm -v)
        log "npm updated successfully to version ${npm_version}"
    else
        log "WARNING: Failed to update npm, but continuing..."
    fi

    # Install common global packages (optional - can be extended)
    install_global_npm_packages

    log "Node.js ${NODEJS_VERSION} installation completed successfully"
    return 0
}

# install_global_npm_packages: Install common global npm packages
# This can be extended based on requirements
install_global_npm_packages() {
    log "Installing common global npm packages..."

    # Add any global packages you want to install by default
    # Example: npm install -g pm2 yarn

    # Currently empty - can be extended later
    log "Global npm packages installation completed"
}

# check_nodejs_installed: Check if Node.js is installed
# Returns: 0 if installed, 1 if not
check_nodejs_installed() {
    if command -v node &> /dev/null && command -v npm &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# get_nodejs_version: Get installed Node.js version
# Outputs: Node.js version number (major version only)
get_nodejs_version() {
    if check_nodejs_installed; then
        node -v | grep -oP '\d+' | head -1
    else
        echo "not installed"
    fi
}

# get_npm_version: Get installed npm version
# Outputs: npm version number
get_npm_version() {
    if command -v npm &> /dev/null; then
        npm -v
    else
        echo "not installed"
    fi
}

# uninstall_nodejs: Remove Node.js installation
# This function can be used for switching versions
uninstall_nodejs() {
    log "Removing Node.js..."

    if ! apt-get remove -y -qq nodejs &>> "${LOG_FILE}"; then
        log "WARNING: Failed to remove Node.js package"
    fi

    if ! apt-get autoremove -y -qq &>> "${LOG_FILE}"; then
        log "WARNING: Failed to autoremove packages"
    fi

    log "Node.js removed"
}

# ============================================================================
# NODEJS VERSION SWITCHING
# ============================================================================

# switch_nodejs_version: Switch to a different Node.js version
# Arguments: $1 - target version (e.g., "20", "22", "24")
# Returns: 0 on success, 1 on error
switch_nodejs_version() {
    local target_version="$1"

    if [[ -z "${target_version}" ]]; then
        echo "ERROR: No target version specified"
        return 1
    fi

    # Validate version
    if [[ ! -v NODEJS_VERSIONS["${target_version}"] ]]; then
        echo "ERROR: Invalid Node.js version: ${target_version}"
        echo "Available versions: ${!NODEJS_VERSIONS[*]}"
        return 1
    fi

    local current_version
    current_version=$(get_nodejs_version)

    if [[ "${current_version}" == "${target_version}" ]]; then
        echo "Node.js ${target_version} is already installed"
        return 0
    fi

    echo "Switching from Node.js ${current_version} to ${target_version}..."

    # Uninstall current version
    uninstall_nodejs

    # Install new version
    NODEJS_VERSION="${target_version}"
    install_nodejs

    echo "Node.js version switched successfully to $(node -v)"
    return 0
}

# ============================================================================
# END OF NODEJS INSTALLER
# ============================================================================

log "Node.js installer library loaded successfully"

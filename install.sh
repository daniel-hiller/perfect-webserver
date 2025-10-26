#!/bin/bash
#
# Webhosting VM/LXC Installer for Debian 13
# Copyright: Daniel Hiller
# License: AGPL-3 or later
#
# Main orchestrator script for automated webhosting environment setup
#

set -euo pipefail

# ============================================================================
# CONSTANTS
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR="${SCRIPT_DIR}/lib"
readonly CONFIG_DIR="${SCRIPT_DIR}/config"
readonly LOG_DIR="/var/log/webhosting-installer"
readonly LOG_FILE="${LOG_DIR}/install.log"
readonly TEMP_CONFIG="/tmp/webhosting-install-$$.conf"

# ============================================================================
# LOAD LIBRARY MODULES
# ============================================================================

# Check if lib directory exists
if [[ ! -d "${LIB_DIR}" ]]; then
    echo "ERROR: Library directory not found: ${LIB_DIR}"
    exit 1
fi

# Source all library modules in correct order
source "${LIB_DIR}/utils.sh"
source "${LIB_DIR}/dialog-menus.sh"
source "${LIB_DIR}/php-installer.sh"
source "${LIB_DIR}/webserver-installer.sh"
source "${LIB_DIR}/database-installer.sh"
source "${LIB_DIR}/certbot-installer.sh"

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================

# Webserver selection
WEBSERVER=""

# PHP configuration
declare -a PHP_VERSIONS=()
SURY_REPO_ADDED=false

# MariaDB configuration
INSTALL_MARIADB=""
DB_ROOT_PASSWORD=""
CREATE_DATABASE=""
DB_NAME=""
DB_USER=""
DB_PASSWORD=""
DB_HOST="localhost"

# Certbot configuration
INSTALL_CERTBOT=""

# System information
DEBIAN_VERSION=""
INSTALL_DATE=""

# ============================================================================
# PRE-FLIGHT CHECKS
# ============================================================================

pre_flight_checks() {
    log "Starting pre-flight checks..."

    # Check root privileges
    check_root

    # Verify supported OS (Debian 12/13, Ubuntu 22.04/24.04)
    check_supported_os

    # Check for LXC container and verify unprivileged
    check_lxc_container

    # Check for previous installation
    if check_previous_installation; then
        dialog --title "Previous Installation Detected" \
            --yesno "A previous installation was detected.\n\nDate: ${INSTALL_DATE}\nWebserver: ${WEBSERVER}\nMariaDB: ${INSTALL_MARIADB}\nCertbot: ${INSTALL_CERTBOT}\n\nContinuing will skip already installed components.\n\nDo you want to continue?" \
            15 70
        if [[ $? -ne 0 ]]; then
            clear
            log "Installation cancelled by user"
            exit 0
        fi
    fi

    # Setup locale (important for LXC containers)
    setup_locale

    # Create log directory
    mkdir -p "${LOG_DIR}"
    chmod 755 "${LOG_DIR}"

    # Initialize log file
    log "==================================================================="
    log "Webhosting Installer - Installation started"
    log "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    log "System: $(uname -a)"
    log "==================================================================="

    # Update package lists
    log "Updating package lists..."
    apt-get update -qq || error_exit "Failed to update package lists"

    # Install dialog if missing
    if ! command -v dialog &> /dev/null; then
        log "Installing dialog package..."
        apt-get install -y -qq dialog || error_exit "Failed to install dialog"
    fi

    log "Pre-flight checks completed successfully"
}

# ============================================================================
# INTERACTIVE CONFIGURATION
# ============================================================================

interactive_configuration() {
    log "Starting interactive configuration..."

    # Welcome screen
    show_welcome

    # Select webserver (Nginx only)
    select_webserver

    # Select PHP version (single version)
    select_php_version

    # Configure MariaDB
    configure_mariadb_menu

    # Configure Certbot
    configure_certbot_menu

    # Show summary and confirm
    show_summary

    # Save configuration
    save_config

    log "Interactive configuration completed"
}

# ============================================================================
# INSTALLATION EXECUTION
# ============================================================================

execute_installation() {
    log "==================================================================="
    log "Starting installation process..."
    log "==================================================================="

    # Set timestamp
    INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')

    # Phase 1: PHP Installation
    if [[ ${#PHP_VERSIONS[@]} -gt 0 ]]; then
        log "Phase 1: PHP Installation"
        log "Selected PHP versions: ${PHP_VERSIONS[*]}"

        add_php_repositories

        for version in "${PHP_VERSIONS[@]}"; do
            log "Installing PHP ${version}..."
            install_php_version "${version}"
            configure_php_ini "${version}"
            configure_php_fpm_pool "${version}"
            enable_php_fpm_service "${version}"
        done

        log "PHP installation completed"
    else
        log "No PHP versions selected, skipping PHP installation"
    fi

    # Phase 2: Webserver Installation
    if [[ -n "${WEBSERVER}" ]]; then
        log "Phase 2: Webserver Installation"

        if [[ "${WEBSERVER}" == "nginx" ]]; then
            install_nginx
        elif [[ "${WEBSERVER}" == "apache" ]]; then
            install_apache
        fi

        log "Webserver installation completed"
    else
        log "No webserver selected, skipping webserver installation"
    fi

    # Phase 3: MariaDB Installation
    if [[ "${INSTALL_MARIADB}" == "yes" ]]; then
        log "Phase 3: MariaDB Installation"

        install_mariadb
        secure_mariadb

        if [[ "${CREATE_DATABASE}" == "yes" ]]; then
            create_database
            create_db_user
            grant_privileges
        fi

        log "MariaDB installation completed"
    else
        log "MariaDB installation skipped"
    fi

    # Phase 4: Certbot Installation
    if [[ "${INSTALL_CERTBOT}" == "yes" ]]; then
        log "Phase 4: Certbot Installation"

        install_certbot
        install_certbot_plugin

        log "Certbot installation completed"
    else
        log "Certbot installation skipped"
    fi

    # Phase 5: Firewall Configuration
    log "Phase 5: Firewall Configuration"
    configure_firewall

    # Phase 6: Webserver Configuration Test
    if [[ -n "${WEBSERVER}" ]]; then
        log "Phase 6: Webserver Configuration Test"
        test_webserver_config
    fi

    log "==================================================================="
    log "Installation process completed successfully"
    log "==================================================================="
}

# ============================================================================
# FINALIZATION
# ============================================================================

finalize_installation() {
    log "Finalizing installation..."

    # Save installation state
    save_installation_state

    # Save credentials if MariaDB was installed
    if [[ "${INSTALL_MARIADB}" == "yes" ]]; then
        save_credentials
    fi

    # Install PHP switcher tool
    log "Installing PHP version switcher..."
    cp "${SCRIPT_DIR}/switch-php" /usr/local/bin/switch-php
    chmod +x /usr/local/bin/switch-php
    log "PHP switcher installed: /usr/local/bin/switch-php"

    # Create installation report
    create_installation_report

    # Show completion dialog
    show_completion

    # Cleanup
    log "Cleaning up temporary files..."
    [[ -f "${TEMP_CONFIG}" ]] && rm -f "${TEMP_CONFIG}"

    log "Installation finalized successfully"
    log "Logfile: ${LOG_FILE}"
}

# ============================================================================
# INSTALLATION REPORT
# ============================================================================

create_installation_report() {
    local report_file="${LOG_DIR}/installation-report.txt"

    cat > "${report_file}" << EOF
=================================================================
WEBHOSTING INSTALLER - INSTALLATION REPORT
=================================================================

Installation Date: ${INSTALL_DATE}
System: $(hostname)
OS: Debian $(cat /etc/debian_version)

-----------------------------------------------------------------
INSTALLED COMPONENTS
-----------------------------------------------------------------

Webserver: ${WEBSERVER:-None}

PHP Versions:
EOF

    if [[ ${#PHP_VERSIONS[@]} -gt 0 ]]; then
        for version in "${PHP_VERSIONS[@]}"; do
            echo "  - PHP ${version} (FPM socket: /run/php/php${version}-fpm.sock)" >> "${report_file}"
        done
        echo "" >> "${report_file}"
        echo "  Switch PHP version: switch-php switch <version>" >> "${report_file}"
        echo "  Install new PHP version: switch-php install <version>" >> "${report_file}"
        echo "  Show status: switch-php status" >> "${report_file}"
    else
        echo "  - None" >> "${report_file}"
    fi

    cat >> "${report_file}" << EOF

MariaDB: ${INSTALL_MARIADB:-no}
EOF

    if [[ "${INSTALL_MARIADB}" == "yes" ]]; then
        local mariadb_version
        mariadb_version=$(mysql_cmd --version 2>/dev/null | awk '{print $5}' | sed 's/,//' || echo "unknown")
        cat >> "${report_file}" << EOF
  - Version: ${mariadb_version}
  - Root Password: [CONFIGURED]
  - Host: ${DB_HOST}
  - Credentials File: /root/.webhosting-credentials
EOF
        if [[ "${CREATE_DATABASE}" == "yes" ]]; then
            cat >> "${report_file}" << EOF
  - Database: ${DB_NAME}
  - User: ${DB_USER}
  - Password: [CONFIGURED]
EOF
        fi
    fi

    cat >> "${report_file}" << EOF

Certbot/SSL: ${INSTALL_CERTBOT:-no}

-----------------------------------------------------------------
NEXT STEPS
-----------------------------------------------------------------

EOF

    if [[ "${WEBSERVER}" == "nginx" ]]; then
        cat >> "${report_file}" << EOF
1. Access your webserver: http://$(hostname -I | awk '{print $1}')
2. Configure virtual hosts in: /etc/nginx/sites-available/
3. Enable sites: ln -s /etc/nginx/sites-available/mysite /etc/nginx/sites-enabled/
4. Reload nginx: systemctl reload nginx
EOF
    elif [[ "${WEBSERVER}" == "apache" ]]; then
        cat >> "${report_file}" << EOF
1. Access your webserver: http://$(hostname -I | awk '{print $1}')
2. Configure virtual hosts in: /etc/apache2/sites-available/
3. Enable sites: a2ensite mysite
4. Reload apache: systemctl reload apache2
EOF
    fi

    if [[ "${INSTALL_CERTBOT}" == "yes" ]]; then
        cat >> "${report_file}" << EOF

5. Obtain SSL certificate: certbot --${WEBSERVER} -d yourdomain.com
EOF
    fi

    cat >> "${report_file}" << EOF

-----------------------------------------------------------------
IMPORTANT FILES & DIRECTORIES
-----------------------------------------------------------------

Installation State: /root/.webhosting-installer-state
Credentials Backup: /root/.webhosting-credentials (if MariaDB installed)
Logs: ${LOG_DIR}/
PHP-FPM Sockets: /run/php/
PHP Configuration: /etc/php/*/fpm/
Webserver Config: /etc/${WEBSERVER}/

NOTE: You can re-run the installer. Already installed components will be skipped.

=================================================================
EOF

    log "Installation report created: ${report_file}"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    # Trap errors
    trap 'error_exit "Installation aborted unexpectedly (Exit code: $?)"' ERR

    # Phase 1: Pre-flight checks
    pre_flight_checks

    # Phase 2: Interactive configuration
    interactive_configuration

    # Phase 3: Execute installation
    execute_installation

    # Phase 4: Finalize
    finalize_installation

    # Exit successfully
    exit 0
}

# Run main function
main "$@"

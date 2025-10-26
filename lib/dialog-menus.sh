#!/bin/bash
#
# Webhosting Installer - Dialog Menu Functions
# Copyright: Daniel Hiller
# License: AGPL-3 or later
#
# Interactive dialog-based UI for configuration
#

# ============================================================================
# WELCOME SCREEN
# ============================================================================

# show_welcome: Display welcome message and introduction
show_welcome() {
    dialog --title "Webhosting Installer" \
        --msgbox "Welcome to the Webhosting VM/LXC Installer!\n\n\
This installer automatically sets up a complete\n\
webhosting environment on Debian 13:\n\n\
  • PHP 5.6 to 8.4 (Multi-Version Support)\n\
  • Nginx or Apache Webserver\n\
  • MariaDB Database (optional)\n\
  • Certbot/Let's Encrypt SSL (optional)\n\n\
The installation is interactive.\n\
Press OK to continue." \
        20 70
    clear
}

# ============================================================================
# WEBSERVER SELECTION
# ============================================================================

# select_webserver: Set webserver to Nginx (Apache support removed)
select_webserver() {
    WEBSERVER="nginx"
    log "Webserver: Nginx (high-performance, modern)"

    dialog --title "Web Server" \
        --msgbox "This installer uses Nginx as the web server.\n\nNginx is a modern, high-performance web server that is:\n- Faster and more efficient than Apache\n- Better suited for hosting single sites\n- Industry standard for modern web applications" \
        12 65

    clear
}

# ============================================================================
# PHP VERSION SELECTION
# ============================================================================

# select_php_version: Select single PHP version
select_php_version() {
    local choice

    choice=$(dialog --stdout --title "PHP Version Selection" \
        --menu "Select ONE PHP version for your site:\n\nYou can switch versions later using the switch-php tool." \
        20 70 11 \
        "5.6" "PHP 5.6 (EOL - Legacy Only)" \
        "7.0" "PHP 7.0 (EOL - Legacy Only)" \
        "7.1" "PHP 7.1 (EOL - Legacy Only)" \
        "7.2" "PHP 7.2 (EOL - Legacy Only)" \
        "7.3" "PHP 7.3 (EOL - Legacy Only)" \
        "7.4" "PHP 7.4 (EOL - Legacy Only)" \
        "8.0" "PHP 8.0 (Security Support)" \
        "8.1" "PHP 8.1 (Security Support)" \
        "8.2" "PHP 8.2 (Active Support)" \
        "8.3" "PHP 8.3 (Recommended)" \
        "8.4" "PHP 8.4 (Latest)")

    if [[ -z "${choice}" ]]; then
        error_exit "Installation cancelled: No PHP version selected"
    fi

    PHP_VERSIONS=("${choice}")
    log "PHP version selected: ${choice}"

    clear
}

# ============================================================================
# MARIADB CONFIGURATION
# ============================================================================

# configure_mariadb_menu: Ask if MariaDB should be installed
configure_mariadb_menu() {
    if dialog --title "MariaDB Installation" \
        --yesno "Do you want to install MariaDB (MySQL)?\n\n\
MariaDB is required for:\n\
  • WordPress, Joomla, Drupal\n\
  • Most Content Management Systems\n\
  • Database-driven applications\n\n\
Recommended: Yes" 15 60; then
        INSTALL_MARIADB="yes"
        log "MariaDB installation: yes"
        mariadb_root_password
        database_creation_menu
    else
        INSTALL_MARIADB="no"
        log "MariaDB installation: no"
    fi

    clear
}

# mariadb_root_password: Prompt for MariaDB root password
mariadb_root_password() {
    local password1
    local password2

    while true; do
        password1=$(dialog --stdout --title "MariaDB Root Password" \
            --insecure --passwordbox \
            "Please enter a root password for MariaDB:\n\n\
(At least 8 characters recommended)" 12 60)

        if [[ -z "${password1}" ]]; then
            dialog --title "Error" --msgbox "Password cannot be empty!" 7 50
            continue
        fi

        if [[ ${#password1} -lt 8 ]]; then
            if ! dialog --title "Warning" \
                --yesno "Password is shorter than 8 characters.\n\nUse anyway?" 8 50; then
                continue
            fi
        fi

        password2=$(dialog --stdout --title "MariaDB Root Password" \
            --insecure --passwordbox \
            "Please confirm the root password:" 10 60)

        if [[ "${password1}" != "${password2}" ]]; then
            dialog --title "Error" --msgbox "Passwords do not match!" 7 50
            continue
        fi

        break
    done

    DB_ROOT_PASSWORD="${password1}"
    log "MariaDB root password set (hidden)"
    clear
}

# database_creation_menu: Ask if database and user should be created
database_creation_menu() {
    if dialog --title "Create Database" \
        --yesno "Do you want to create a database and user now?\n\n\
You can also do this manually later." 10 60; then
        CREATE_DATABASE="yes"
        log "Database creation: yes"
        prompt_database_details
    else
        CREATE_DATABASE="no"
        log "Database creation: no"
    fi

    clear
}

# prompt_database_details: Get database name, user, and password
prompt_database_details() {
    # Database name
    while true; do
        DB_NAME=$(dialog --stdout --title "Database Name" \
            --inputbox "Please enter a database name:\n\n\
(Alphanumeric, underscores and hyphens allowed)" 12 60)

        if [[ -z "${DB_NAME}" ]]; then
            dialog --title "Error" --msgbox "Database name cannot be empty!" 7 50
            continue
        fi

        if ! validate_db_name "${DB_NAME}"; then
            dialog --title "Error" \
                --msgbox "Invalid database name!\n\n\
Allowed: a-z, A-Z, 0-9, _ and -\nMax. 64 characters" 10 50
            continue
        fi

        break
    done

    # Database user
    while true; do
        DB_USER=$(dialog --stdout --title "Database User" \
            --inputbox "Please enter a username:\n\n\
(Alphanumeric, underscores and hyphens allowed)" 12 60)

        if [[ -z "${DB_USER}" ]]; then
            dialog --title "Error" --msgbox "Username cannot be empty!" 7 50
            continue
        fi

        if ! validate_username "${DB_USER}"; then
            dialog --title "Error" \
                --msgbox "Invalid username!\n\n\
Allowed: a-z, A-Z, 0-9, _ and -\nMax. 32 characters" 10 50
            continue
        fi

        break
    done

    # Database password
    local password1
    local password2

    while true; do
        password1=$(dialog --stdout --title "Database Password" \
            --insecure --passwordbox \
            "Please enter a password for user '${DB_USER}':\n\n\
(At least 8 characters recommended)" 12 60)

        if [[ -z "${password1}" ]]; then
            dialog --title "Error" --msgbox "Password cannot be empty!" 7 50
            continue
        fi

        password2=$(dialog --stdout --title "Database Password" \
            --insecure --passwordbox \
            "Please confirm the password:" 10 60)

        if [[ "${password1}" != "${password2}" ]]; then
            dialog --title "Error" --msgbox "Passwords do not match!" 7 50
            continue
        fi

        break
    done

    DB_PASSWORD="${password1}"

    log "Database details collected: DB=${DB_NAME}, User=${DB_USER}"
    clear
}

# ============================================================================
# CERTBOT CONFIGURATION
# ============================================================================

# configure_certbot_menu: Ask if Certbot should be installed
configure_certbot_menu() {
    if dialog --title "Certbot/Let's Encrypt" \
        --yesno "Do you want to install Certbot for free SSL certificates?\n\n\
Certbot provides:\n\
  • Free SSL/TLS certificates from Let's Encrypt\n\
  • Automatic certificate renewal\n\
  • HTTPS for your websites\n\n\
Note: Certificates must be requested manually\n\
per domain after installation.\n\n\
Recommended: Yes" 18 65; then
        INSTALL_CERTBOT="yes"
        log "Certbot installation: yes"
    else
        INSTALL_CERTBOT="no"
        log "Certbot installation: no"
    fi

    clear
}

# ============================================================================
# SUMMARY AND CONFIRMATION
# ============================================================================

# show_summary: Display configuration summary and confirm
show_summary() {
    local summary_text="INSTALLATION SUMMARY\n"
    summary_text+="===============================================\n\n"

    # Webserver
    summary_text+="Webserver:       ${WEBSERVER:-None}\n\n"

    # PHP Versions
    summary_text+="PHP Versions:    "
    if [[ ${#PHP_VERSIONS[@]} -gt 0 ]]; then
        summary_text+="${PHP_VERSIONS[*]}\n"
    else
        summary_text+="None\n"
    fi
    summary_text+="\n"

    # MariaDB
    summary_text+="MariaDB:         ${INSTALL_MARIADB}\n"
    if [[ "${INSTALL_MARIADB}" == "yes" ]]; then
        summary_text+="  Root-PW:       [Configured]\n"
        if [[ "${CREATE_DATABASE}" == "yes" ]]; then
            summary_text+="  Database:      ${DB_NAME}\n"
            summary_text+="  User:          ${DB_USER}\n"
            summary_text+="  User-PW:       [Configured]\n"
        fi
    fi
    summary_text+="\n"

    # Certbot
    summary_text+="Certbot/SSL:     ${INSTALL_CERTBOT}\n\n"

    summary_text+="===============================================\n\n"
    summary_text+="Proceed with installation?"

    if ! dialog --title "Confirmation" \
        --yes-label "Start Installation" \
        --no-label "Cancel" \
        --yesno "${summary_text}" 24 70; then
        dialog --title "Cancelled" \
            --msgbox "Installation was cancelled." 7 40
        clear
        log "Installation cancelled by user"
        exit 0
    fi

    clear
    log "Installation confirmed by user"
}

# ============================================================================
# COMPLETION SCREEN
# ============================================================================

# show_completion: Display success message with details
show_completion() {
    local ip_address
    ip_address=$(get_primary_ip)

    local completion_text="INSTALLATION SUCCESSFUL!\n"
    completion_text+="===============================================\n\n"

    # Webserver info
    if [[ -n "${WEBSERVER}" ]]; then
        completion_text+="Webserver:       ${WEBSERVER}\n"
        completion_text+="URL:             http://${ip_address}/\n\n"
    fi

    # PHP info
    if [[ ${#PHP_VERSIONS[@]} -gt 0 ]]; then
        completion_text+="PHP Versions:    ${PHP_VERSIONS[*]}\n"
        completion_text+="FPM Sockets:     /run/php/php*-fpm.sock\n\n"
    fi

    # MariaDB info
    if [[ "${INSTALL_MARIADB}" == "yes" ]]; then
        completion_text+="MariaDB:         localhost:3306\n"
        if [[ "${CREATE_DATABASE}" == "yes" ]]; then
            completion_text+="Database:        ${DB_NAME}\n"
            completion_text+="User:            ${DB_USER}\n"
        fi
        completion_text+="\n"
    fi

    # Certbot info
    if [[ "${INSTALL_CERTBOT}" == "yes" ]]; then
        completion_text+="Certbot:         Installed\n"
        completion_text+="SSL Certificate: certbot --${WEBSERVER} -d domain.com\n\n"
    fi

    completion_text+="===============================================\n\n"
    completion_text+="Log files:       ${LOG_DIR}/\n"
    completion_text+="Report:          ${LOG_DIR}/installation-report.txt\n\n"
    completion_text+="Press OK to exit."

    dialog --title "Installation Complete" \
        --msgbox "${completion_text}" 24 70

    clear

    # Also print to console
    echo ""
    echo "==============================================="
    echo "  INSTALLATION COMPLETED SUCCESSFULLY"
    echo "==============================================="
    echo ""
    if [[ -n "${WEBSERVER}" ]]; then
        echo "Webserver:   http://${ip_address}/"
    fi
    if [[ ${#PHP_VERSIONS[@]} -gt 0 ]]; then
        echo "PHP:         ${PHP_VERSIONS[*]}"
    fi
    if [[ "${INSTALL_MARIADB}" == "yes" ]]; then
        echo "MariaDB:     localhost:3306"
    fi
    echo ""
    echo "Details:     ${LOG_DIR}/installation-report.txt"
    echo ""
}

# ============================================================================
# PROGRESS INDICATORS
# ============================================================================

# show_progress: Display progress gauge (for long operations)
# Usage: show_progress "title" "message" percentage
show_progress() {
    local title="$1"
    local message="$2"
    local percent="$3"

    echo "${percent}" | dialog --title "${title}" \
        --gauge "${message}" 8 60 0
}

# ============================================================================
# END OF DIALOG MENUS
# ============================================================================

log "Dialog menus library loaded successfully"

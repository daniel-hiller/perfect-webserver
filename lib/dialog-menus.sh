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
# PHP CONFIGURATION
# ============================================================================

# configure_php_settings: Configure PHP.ini settings
configure_php_settings() {
    if dialog --title "PHP Configuration" \
        --yesno "Do you want to configure PHP settings now?\n\n\
You can configure:\n\
  • Upload max filesize\n\
  • Memory limit\n\
  • Execution time\n\
  • Timezone\n\n\
You can change these later with:\nwebserver-manager php config\n\n\
Configure now?" 17 65; then

        # Get current defaults or use sensible defaults
        local upload_max="64M"
        local memory_limit="256M"
        local exec_time="300"
        local timezone="Europe/Berlin"

        # Upload size
        upload_max=$(dialog --stdout --title "Upload Max Filesize" \
            --inputbox "Maximum file upload size:\n\n(e.g., 64M, 128M, 256M)" 10 50 "${upload_max}")

        # Memory limit
        memory_limit=$(dialog --stdout --title "Memory Limit" \
            --inputbox "PHP memory limit:\n\n(e.g., 128M, 256M, 512M)" 10 50 "${memory_limit}")

        # Execution time
        exec_time=$(dialog --stdout --title "Max Execution Time" \
            --inputbox "Maximum execution time in seconds:\n\n(e.g., 30, 60, 300)" 10 50 "${exec_time}")

        # Timezone
        timezone=$(dialog --stdout --title "Timezone" \
            --inputbox "PHP timezone:\n\n(e.g., Europe/Berlin, America/New_York, UTC)" 10 60 "${timezone}")

        # Save settings
        PHP_UPLOAD_MAX="${upload_max}"
        PHP_MEMORY_LIMIT="${memory_limit}"
        PHP_EXEC_TIME="${exec_time}"
        PHP_TIMEZONE="${timezone}"

        log "PHP settings configured: upload=${upload_max}, memory=${memory_limit}, time=${exec_time}, tz=${timezone}"
    else
        log "PHP configuration skipped (will use defaults)"
    fi

    clear
}

# ============================================================================
# BACKUP CONFIGURATION
# ============================================================================

# configure_backup_menu: Setup automatic backups
configure_backup_menu() {
    if dialog --title "Automatic Backups" \
        --yesno "Do you want to setup automatic backups?\n\n\
Backups include:\n\
  • Website files (/var/www/html)\n\
  • Database(s) (if MariaDB installed)\n\
  • 7-day retention\n\n\
You can configure this later with:\nwebserver-manager backup setup\n\n\
Setup now?" 17 65; then

        CONFIGURE_BACKUP="yes"

        # Backup schedule
        local schedule=$(dialog --stdout --title "Backup Schedule" \
            --menu "When should backups run?" 15 60 4 \
            "1" "Daily at 2:00 AM (Recommended)" \
            "2" "Daily at 3:00 AM" \
            "3" "Weekly (Sunday 2:00 AM)" \
            "4" "Skip - Configure later")

        case $schedule in
            1) BACKUP_SCHEDULE="0 2 * * *" ;;
            2) BACKUP_SCHEDULE="0 3 * * *" ;;
            3) BACKUP_SCHEDULE="0 2 * * 0" ;;
            4)
                CONFIGURE_BACKUP="no"
                log "Backup configuration skipped"
                ;;
        esac

        if [[ "${CONFIGURE_BACKUP}" == "yes" ]]; then
            log "Backup configured: ${BACKUP_SCHEDULE}"
        fi
    else
        CONFIGURE_BACKUP="no"
        log "Backup configuration skipped"
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

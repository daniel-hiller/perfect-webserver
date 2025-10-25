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
        --msgbox "Willkommen zum Webhosting VM/LXC Installer!\n\n\
Dieser Installer richtet automatisch eine vollständige\n\
Webhosting-Umgebung auf Debian 13 ein:\n\n\
  • PHP 5.6 bis 8.4 (Multi-Version Support)\n\
  • Nginx oder Apache Webserver\n\
  • MariaDB Datenbank (optional)\n\
  • Certbot/Let's Encrypt SSL (optional)\n\n\
Die Installation erfolgt interaktiv.\n\
Drücken Sie OK zum Fortfahren." \
        20 70
    clear
}

# ============================================================================
# WEBSERVER SELECTION
# ============================================================================

# select_webserver: Choose between Nginx and Apache
select_webserver() {
    local choice

    choice=$(dialog --stdout --title "Webserver Auswahl" \
        --menu "Bitte wählen Sie einen Webserver:" 15 60 2 \
        "nginx" "Nginx (Empfohlen, leichtgewichtig)" \
        "apache" "Apache (Klassisch, .htaccess Support)")

    if [[ -z "${choice}" ]]; then
        error_exit "Installation abgebrochen: Kein Webserver ausgewählt"
    fi

    WEBSERVER="${choice}"
    log "Webserver selected: ${WEBSERVER}"
    clear
}

# ============================================================================
# PHP VERSION SELECTION
# ============================================================================

# select_php_versions: Multi-select PHP versions
select_php_versions() {
    local selected

    selected=$(dialog --stdout --separate-output \
        --title "PHP Versionen" \
        --checklist "Wählen Sie PHP-Versionen aus (SPACE zum Auswählen, ENTER zum Bestätigen):\n\n\
Mehrfachauswahl möglich - alle Versionen laufen parallel via PHP-FPM." \
        22 75 11 \
        "5.6" "PHP 5.6 (EOL - Legacy Support)" OFF \
        "7.0" "PHP 7.0 (EOL - Legacy Support)" OFF \
        "7.1" "PHP 7.1 (EOL - Legacy Support)" OFF \
        "7.2" "PHP 7.2 (EOL - Legacy Support)" OFF \
        "7.3" "PHP 7.3 (EOL - Legacy Support)" OFF \
        "7.4" "PHP 7.4 (EOL - Legacy Support)" OFF \
        "8.0" "PHP 8.0 (Security Support)" OFF \
        "8.1" "PHP 8.1 (Security Support)" OFF \
        "8.2" "PHP 8.2 (Active Support)" ON \
        "8.3" "PHP 8.3 (Recommended)" ON \
        "8.4" "PHP 8.4 (Latest)" OFF)

    if [[ -z "${selected}" ]]; then
        dialog --title "Warnung" \
            --yesno "Keine PHP-Version ausgewählt.\n\nMöchten Sie ohne PHP fortfahren?" 10 50

        if [[ $? -ne 0 ]]; then
            select_php_versions
            return
        fi
        log "No PHP versions selected (user confirmed)"
    else
        # Convert newline-separated list to array
        mapfile -t PHP_VERSIONS <<< "${selected}"
        log "PHP versions selected: ${PHP_VERSIONS[*]}"
    fi

    clear
}

# ============================================================================
# MARIADB CONFIGURATION
# ============================================================================

# configure_mariadb_menu: Ask if MariaDB should be installed
configure_mariadb_menu() {
    dialog --title "MariaDB Installation" \
        --yesno "Möchten Sie MariaDB (MySQL) installieren?\n\n\
MariaDB ist erforderlich für:\n\
  • WordPress, Joomla, Drupal\n\
  • Die meisten Content-Management-Systeme\n\
  • Datenbankbasierte Anwendungen\n\n\
Installation empfohlen: Ja" 15 60

    if [[ $? -eq 0 ]]; then
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
        password1=$(dialog --stdout --title "MariaDB Root-Passwort" \
            --insecure --passwordbox \
            "Bitte geben Sie ein Root-Passwort für MariaDB ein:\n\n\
(Mindestens 8 Zeichen empfohlen)" 12 60)

        if [[ -z "${password1}" ]]; then
            dialog --title "Fehler" --msgbox "Passwort darf nicht leer sein!" 7 50
            continue
        fi

        if [[ ${#password1} -lt 8 ]]; then
            dialog --title "Warnung" \
                --yesno "Passwort ist kürzer als 8 Zeichen.\n\nTrotzdem verwenden?" 8 50
            if [[ $? -ne 0 ]]; then
                continue
            fi
        fi

        password2=$(dialog --stdout --title "MariaDB Root-Passwort" \
            --insecure --passwordbox \
            "Bitte bestätigen Sie das Root-Passwort:" 10 60)

        if [[ "${password1}" != "${password2}" ]]; then
            dialog --title "Fehler" --msgbox "Passwörter stimmen nicht überein!" 7 50
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
    dialog --title "Datenbank erstellen" \
        --yesno "Möchten Sie jetzt eine Datenbank und einen Benutzer erstellen?\n\n\
Sie können dies auch später manuell durchführen." 10 60

    if [[ $? -eq 0 ]]; then
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
        DB_NAME=$(dialog --stdout --title "Datenbank Name" \
            --inputbox "Bitte geben Sie einen Datenbanknamen ein:\n\n\
(Alphanumerisch, Unterstriche und Bindestriche erlaubt)" 12 60)

        if [[ -z "${DB_NAME}" ]]; then
            dialog --title "Fehler" --msgbox "Datenbankname darf nicht leer sein!" 7 50
            continue
        fi

        if ! validate_db_name "${DB_NAME}"; then
            dialog --title "Fehler" \
                --msgbox "Ungültiger Datenbankname!\n\n\
Erlaubt: a-z, A-Z, 0-9, _ und -\nMax. 64 Zeichen" 10 50
            continue
        fi

        break
    done

    # Database user
    while true; do
        DB_USER=$(dialog --stdout --title "Datenbank Benutzer" \
            --inputbox "Bitte geben Sie einen Benutzernamen ein:\n\n\
(Alphanumerisch, Unterstriche und Bindestriche erlaubt)" 12 60)

        if [[ -z "${DB_USER}" ]]; then
            dialog --title "Fehler" --msgbox "Benutzername darf nicht leer sein!" 7 50
            continue
        fi

        if ! validate_username "${DB_USER}"; then
            dialog --title "Fehler" \
                --msgbox "Ungültiger Benutzername!\n\n\
Erlaubt: a-z, A-Z, 0-9, _ und -\nMax. 32 Zeichen" 10 50
            continue
        fi

        break
    done

    # Database password
    local password1
    local password2

    while true; do
        password1=$(dialog --stdout --title "Datenbank Passwort" \
            --insecure --passwordbox \
            "Bitte geben Sie ein Passwort für den Benutzer '${DB_USER}' ein:\n\n\
(Mindestens 8 Zeichen empfohlen)" 12 60)

        if [[ -z "${password1}" ]]; then
            dialog --title "Fehler" --msgbox "Passwort darf nicht leer sein!" 7 50
            continue
        fi

        password2=$(dialog --stdout --title "Datenbank Passwort" \
            --insecure --passwordbox \
            "Bitte bestätigen Sie das Passwort:" 10 60)

        if [[ "${password1}" != "${password2}" ]]; then
            dialog --title "Fehler" --msgbox "Passwörter stimmen nicht überein!" 7 50
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
    dialog --title "Certbot/Let's Encrypt" \
        --yesno "Möchten Sie Certbot für kostenlose SSL-Zertifikate installieren?\n\n\
Certbot ermöglicht:\n\
  • Kostenlose SSL/TLS Zertifikate von Let's Encrypt\n\
  • Automatische Erneuerung der Zertifikate\n\
  • HTTPS für Ihre Websites\n\n\
Hinweis: Zertifikate müssen nach der Installation\n\
manuell pro Domain angefordert werden.\n\n\
Installation empfohlen: Ja" 18 65

    if [[ $? -eq 0 ]]; then
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
    local summary_text="INSTALLATIONS-ZUSAMMENFASSUNG\n"
    summary_text+="===============================================\n\n"

    # Webserver
    summary_text+="Webserver:       ${WEBSERVER:-Keiner}\n\n"

    # PHP Versions
    summary_text+="PHP Versionen:   "
    if [[ ${#PHP_VERSIONS[@]} -gt 0 ]]; then
        summary_text+="${PHP_VERSIONS[*]}\n"
    else
        summary_text+="Keine\n"
    fi
    summary_text+="\n"

    # MariaDB
    summary_text+="MariaDB:         ${INSTALL_MARIADB}\n"
    if [[ "${INSTALL_MARIADB}" == "yes" ]]; then
        summary_text+="  Root-PW:       [Konfiguriert]\n"
        if [[ "${CREATE_DATABASE}" == "yes" ]]; then
            summary_text+="  Datenbank:     ${DB_NAME}\n"
            summary_text+="  Benutzer:      ${DB_USER}\n"
            summary_text+="  User-PW:       [Konfiguriert]\n"
        fi
    fi
    summary_text+="\n"

    # Certbot
    summary_text+="Certbot/SSL:     ${INSTALL_CERTBOT}\n\n"

    summary_text+="===============================================\n\n"
    summary_text+="Fortfahren mit der Installation?"

    dialog --title "Bestätigung" \
        --yes-label "Installation starten" \
        --no-label "Abbrechen" \
        --yesno "${summary_text}" 24 70

    if [[ $? -ne 0 ]]; then
        dialog --title "Abbruch" \
            --msgbox "Installation wurde abgebrochen." 7 40
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

    local completion_text="INSTALLATION ERFOLGREICH!\n"
    completion_text+="===============================================\n\n"

    # Webserver info
    if [[ -n "${WEBSERVER}" ]]; then
        completion_text+="Webserver:       ${WEBSERVER}\n"
        completion_text+="URL:             http://${ip_address}/\n\n"
    fi

    # PHP info
    if [[ ${#PHP_VERSIONS[@]} -gt 0 ]]; then
        completion_text+="PHP Versionen:   ${PHP_VERSIONS[*]}\n"
        completion_text+="FPM Sockets:     /run/php/php*-fpm.sock\n\n"
    fi

    # MariaDB info
    if [[ "${INSTALL_MARIADB}" == "yes" ]]; then
        completion_text+="MariaDB:         localhost:3306\n"
        if [[ "${CREATE_DATABASE}" == "yes" ]]; then
            completion_text+="Datenbank:       ${DB_NAME}\n"
            completion_text+="Benutzer:        ${DB_USER}\n"
        fi
        completion_text+="\n"
    fi

    # Certbot info
    if [[ "${INSTALL_CERTBOT}" == "yes" ]]; then
        completion_text+="Certbot:         Installiert\n"
        completion_text+="SSL-Zertifikat:  certbot --${WEBSERVER} -d domain.com\n\n"
    fi

    completion_text+="===============================================\n\n"
    completion_text+="Logdateien:      ${LOG_DIR}/\n"
    completion_text+="Report:          ${LOG_DIR}/installation-report.txt\n\n"
    completion_text+="Drücken Sie OK zum Beenden."

    dialog --title "Installation Abgeschlossen" \
        --msgbox "${completion_text}" 24 70

    clear

    # Also print to console
    echo ""
    echo "==============================================="
    echo "  INSTALLATION ERFOLGREICH ABGESCHLOSSEN"
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

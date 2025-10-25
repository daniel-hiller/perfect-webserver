# Coding Agent Plan: Webhosting VM/LXC Installer

## Copyright
Daniel Hiller
AGPL -3 or later

## Projekt-Übersicht
Ein modulares Bash-Script-System zur automatisierten Installation und Konfiguration einer Debian 13 Webhosting-Umgebung mit interaktiver Dialog-Oberfläche.

## Technische Spezifikationen

### Unterstützte Software
- **OS**: Debian 13 (Trixie) only
- **PHP**: 5.6, 7.0, 7.1, 7.2, 7.3, 7.4, 8.0, 8.1, 8.2, 8.3, 8.4
- **Webserver**: Nginx oder Apache
- **Datenbank**: MariaDB (optional)
- **SSL**: Certbot (optional)

### Dependencies
- `dialog` für UI
- `apt` Package Manager
- Standard Debian 13 Tools

---

## Dateistruktur

```
webhosting-installer/
│
├── install.sh                          # MAIN: Einstiegspunkt, orchestriert Installation
│   ├── Root-Check
│   ├── Debian 13 Verification
│   ├── dialog Installation (falls fehlt)
│   ├── Lade alle lib/*.sh Module
│   ├── Rufe dialog-menus.sh auf
│   ├── Führe Installationen aus
│   └── Zeige Zusammenfassung
│
├── lib/
│   ├── utils.sh                        # Basis-Funktionen
│   │   ├── log()                       # Timestamp-Logging nach logs/install.log
│   │   ├── error_exit()                # Fehlerbehandlung + Exit
│   │   ├── check_root()                # Root-Rechte prüfen
│   │   ├── check_debian_13()           # OS-Version prüfen
│   │   ├── save_config()               # Config in /tmp speichern
│   │   ├── load_config()               # Config laden
│   │   ├── is_installed()              # Paket installiert?
│   │   ├── backup_file()               # Datei vor Änderung sichern
│   │   └── generate_password()         # Sicheres Passwort generieren
│   │
│   ├── dialog-menus.sh                 # UI/UX Layer
│   │   ├── show_welcome()              # Willkommensbildschirm
│   │   ├── select_webserver()          # Nginx/Apache Auswahl
│   │   ├── select_php_versions()       # Multi-Select PHP 5.6-8.4
│   │   ├── configure_mariadb_menu()    # MariaDB Ja/Nein
│   │   ├── mariadb_root_password()     # Root-PW Eingabe
│   │   ├── database_creation_menu()    # DB + User erstellen?
│   │   ├── configure_certbot_menu()    # Certbot Ja/Nein
│   │   ├── show_summary()              # Bestätigungs-Übersicht
│   │   └── show_completion()           # Erfolgs-Meldung
│   │
│   ├── php-installer.sh                # PHP Installation & Config
│   │   ├── add_php_repositories()      # Sury Repository hinzufügen
│   │   ├── install_php_version()       # Einzelne PHP-Version installieren
│   │   │   ├── php${VERSION}-fpm
│   │   │   ├── php${VERSION}-cli
│   │   │   └── Standard Extensions:
│   │   │       - mysql/mysqli
│   │   │       - curl
│   │   │       - gd
│   │   │       - mbstring
│   │   │       - xml
│   │   │       - zip
│   │   │       - intl
│   │   │       - bcmath
│   │   │       - imagick (wenn verfügbar)
│   │   │       - opcache
│   │   ├── configure_php_ini()         # php.ini Optimierungen
│   │   │   ├── memory_limit = 256M
│   │   │   ├── upload_max_filesize = 64M
│   │   │   ├── post_max_size = 64M
│   │   │   └── max_execution_time = 300
│   │   ├── configure_php_fpm_pool()    # FPM Pool Config
│   │   └── enable_php_fpm_service()    # Systemd aktivieren
│   │
│   ├── webserver-installer.sh          # Nginx/Apache Installation
│   │   ├── install_nginx()
│   │   │   ├── nginx Paket installieren
│   │   │   ├── Basis-Config aus nginx-templates/
│   │   │   ├── PHP-FPM Integration (alle Versionen)
│   │   │   ├── Sicherheits-Header setzen
│   │   │   └── Default vHost erstellen
│   │   ├── install_apache()
│   │   │   ├── apache2 Paket installieren
│   │   │   ├── Module aktivieren (rewrite, ssl, headers)
│   │   │   ├── PHP-FPM Integration via mod_proxy_fcgi
│   │   │   └── Default vHost aus apache-templates/
│   │   ├── configure_firewall()        # ufw Rules (80, 443)
│   │   └── test_webserver_config()     # nginx -t / apache2ctl -t
│   │
│   ├── database-installer.sh           # MariaDB Setup
│   │   ├── install_mariadb()           # mariadb-server installieren
│   │   ├── secure_mariadb()            # mysql_secure_installation
│   │   │   ├── Root-Passwort setzen
│   │   │   ├── Anonymous User entfernen
│   │   │   ├── Remote Root Login verbieten
│   │   │   └── Test-DB entfernen
│   │   ├── create_database()           # Optional: DB erstellen
│   │   ├── create_db_user()            # Optional: User erstellen
│   │   └── grant_privileges()          # Rechte vergeben
│   │
│   └── certbot-installer.sh            # SSL/TLS Setup
│       ├── install_certbot()           # certbot + Plugin installieren
│       ├── detect_webserver()          # Nginx oder Apache?
│       └── install_certbot_plugin()    # python3-certbot-nginx/apache
│
├── config/
│   ├── nginx-templates/
│   │   ├── nginx.conf.template         # Haupt-Config Vorlage
│   │   ├── default-vhost.conf          # Default Site
│   │   └── php-fpm-*.conf              # PHP-FPM Upstream Configs
│   │
│   ├── apache-templates/
│   │   ├── apache2.conf.template       # Haupt-Config Vorlage
│   │   ├── default-vhost.conf          # Default Site
│   │   └── php-fpm-*.conf              # PHP-FPM ProxyPass Configs
│   │
│   └── php-templates/
│       └── www.conf.template           # FPM Pool Template
│
├── logs/
│   └── install.log                     # Wird während Installation erstellt
│
└── README.md                           # Dokumentation & Usage
```

---

## Globale Variablen (Config)

```bash
# Gespeichert in: /tmp/webhosting-install-$$.conf

# Webserver
WEBSERVER=""                    # "nginx" oder "apache"

# PHP
PHP_VERSIONS=()                 # Array: ("5.6" "7.4" "8.3")
SURY_REPO_ADDED=false          # Flag für Repository

# MariaDB
INSTALL_MARIADB=""             # "yes" oder "no"
DB_ROOT_PASSWORD=""            # Root-Passwort
CREATE_DATABASE=""             # "yes" oder "no"
DB_NAME=""                     # Datenbank-Name
DB_USER=""                     # DB-User
DB_PASSWORD=""                 # DB-User Passwort
DB_HOST="localhost"            # Standard

# Certbot
INSTALL_CERTBOT=""             # "yes" oder "no"

# System
DEBIAN_VERSION=""              # Wird erkannt
INSTALL_DATE=""                # Timestamp
LOG_FILE="/var/log/webhosting-installer/install.log"
```

---

## Installations-Flow (Sequenz)

### Phase 1: Pre-Flight Checks
```
1. check_root()              → Exit wenn nicht root
2. check_debian_13()         → Exit wenn nicht Debian 13
3. Erstelle log-Verzeichnis  → mkdir -p /var/log/webhosting-installer
4. Initialisiere LOG_FILE    → log "Installation gestartet"
5. apt update                → Package-Listen aktualisieren
6. Install dialog            → Falls nicht vorhanden
```

### Phase 2: Interaktive Konfiguration (Dialog)
```
1. show_welcome()
   ↓
2. select_webserver()         → WEBSERVER Variable setzen
   ↓
3. select_php_versions()      → PHP_VERSIONS Array füllen
   ↓
4. configure_mariadb_menu()
   ├─ Ja → mariadb_root_password()
   │       ↓
   │       database_creation_menu()
   │       ├─ Ja → DB_NAME, DB_USER, DB_PASSWORD erfragen
   │       └─ Nein
   └─ Nein
   ↓
5. configure_certbot_menu()   → INSTALL_CERTBOT setzen
   ↓
6. show_summary()             → Bestätigung oder Abbruch
```

### Phase 3: Installation (Sequential Execution)
```
1. save_config()              → Config persistent speichern

2. IF PHP_VERSIONS nicht leer:
   ├─ add_php_repositories()
   └─ FOR EACH version IN PHP_VERSIONS:
      └─ install_php_version($version)
         ├─ configure_php_ini($version)
         ├─ configure_php_fpm_pool($version)
         └─ enable_php_fpm_service($version)

3. IF WEBSERVER == "nginx":
      install_nginx()
   ELIF WEBSERVER == "apache":
      install_apache()

4. IF INSTALL_MARIADB == "yes":
   ├─ install_mariadb()
   ├─ secure_mariadb()
   └─ IF CREATE_DATABASE == "yes":
      ├─ create_database()
      ├─ create_db_user()
      └─ grant_privileges()

5. IF INSTALL_CERTBOT == "yes":
   ├─ install_certbot()
   └─ install_certbot_plugin()

6. configure_firewall()       → ufw allow 80,443

7. test_webserver_config()    → Syntax-Check
```

### Phase 4: Finalisierung
```
1. Erstelle Installations-Report
2. show_completion()          → Erfolgs-Dialog mit Details
3. log "Installation erfolgreich abgeschlossen"
4. Cleanup temporäre Dateien
```

---

## Spezielle Implementierungs-Details

### PHP Multi-Version Support
```bash
# Sury Repository für alle PHP Versionen
add_php_repositories() {
    apt install -y lsb-release apt-transport-https ca-certificates wget
    wget -O /etc/apt/trusted.gpg.d/php.gpg \
        https://packages.sury.org/php/apt.gpg
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" \
        > /etc/apt/sources.list.d/php.list
    apt update
}

# Installations-Loop
for version in "${PHP_VERSIONS[@]}"; do
    VERSION_NODOT=$(echo $version | tr -d '.')
    apt install -y \
        php${version}-fpm \
        php${version}-cli \
        php${version}-mysql \
        php${version}-curl \
        php${version}-gd \
        php${version}-mbstring \
        php${version}-xml \
        php${version}-zip
    
    # FPM Socket: /run/php/php${version}-fpm.sock
done
```

### Nginx Multi-PHP Config
```nginx
# Upstream Blocks für jede PHP-Version
upstream php56 { server unix:/run/php/php5.6-fpm.sock; }
upstream php74 { server unix:/run/php/php7.4-fpm.sock; }
upstream php83 { server unix:/run/php/php8.3-fpm.sock; }

# Default vHost kann PHP-Version wählen
location ~ \.php$ {
    fastcgi_pass php83;  # Standard
    fastcgi_index index.php;
    include fastcgi_params;
}
```

### MariaDB Secure Installation (Non-Interactive)
```bash
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -e "FLUSH PRIVILEGES;"
```

### Dialog Multi-Select für PHP
```bash
select_php_versions() {
    local options=(
        "5.6" "PHP 5.6 (Legacy)" OFF
        "7.0" "PHP 7.0 (Legacy)" OFF
        "7.1" "PHP 7.1 (Legacy)" OFF
        "7.2" "PHP 7.2 (Legacy)" OFF
        "7.3" "PHP 7.3 (Legacy)" OFF
        "7.4" "PHP 7.4 (Legacy)" OFF
        "8.0" "PHP 8.0" OFF
        "8.1" "PHP 8.1" OFF
        "8.2" "PHP 8.2" ON
        "8.3" "PHP 8.3 (Empfohlen)" ON
        "8.4" "PHP 8.4 (Aktuell)" OFF
    )
    
    local selected=$(dialog --stdout --checklist \
        "PHP Versionen auswählen (Mehrfachauswahl mit SPACE):" \
        20 60 11 "${options[@]}")
    
    # Array füllen
    PHP_VERSIONS=($selected)
}
```

---

## Error Handling & Logging

```bash
# Jede Funktion loggt
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Fehler-Exit mit Rollback-Möglichkeit
error_exit() {
    log "ERROR: $1"
    dialog --msgbox "Fehler: $1\n\nDetails in: $LOG_FILE" 10 60
    exit 1
}

# Trap für unerwartete Exits
trap 'error_exit "Installation abgebrochen (Exit-Code: $?)"' ERR
```

---

## Testing Checklist

- [ ] Debian 13 Clean-Installation
- [ ] Root-Check funktioniert
- [ ] Dialog Installation klappt
- [ ] Alle PHP Versionen 5.6-8.4 installierbar
- [ ] Nginx + Multi-PHP funktioniert
- [ ] Apache + Multi-PHP funktioniert
- [ ] MariaDB Installation & Securing
- [ ] DB + User Creation
- [ ] Certbot Installation
- [ ] Firewall Rules
- [ ] Alle Logs werden geschrieben
- [ ] Error-Handling bei Abbruch
- [ ] Idempotenz (wiederholte Ausführung)

---

## README.md Struktur

```markdown
# Webhosting VM/LXC Installer für Debian 13

## Features
- PHP 5.6 bis 8.4 (Multi-Version Support)
- Nginx oder Apache
- MariaDB (optional)
- Certbot/Let's Encrypt (optional)
- Interaktive Dialog-UI

## Voraussetzungen
- Debian 13 (Trixie)
- Root-Rechte
- Internet-Verbindung

## Installation
```bash
git clone <repo>
cd webhosting-installer
chmod +x install.sh
sudo ./install.sh
```

## Nach der Installation
- Webserver: http://your-server-ip
- PHP-FPM Sockets: /run/php/php*-fpm.sock
- MariaDB: localhost:3306
- Logs: /var/log/webhosting-installer/

## Support
Nur für Debian 13 getestet.
```

---

## Prioritäten für Coding Agent

### Phase 1 (Core)
1. `install.sh` - Hauptscript mit Flow
2. `lib/utils.sh` - Basis-Funktionen
3. `lib/dialog-menus.sh` - Komplette UI

### Phase 2 (Installer)
4. `lib/php-installer.sh` - PHP Multi-Version
5. `lib/webserver-installer.sh` - Nginx/Apache

### Phase 3 (Optional Features)
6. `lib/database-installer.sh` - MariaDB
7. `lib/certbot-installer.sh` - SSL

### Phase 4 (Templates & Docs)
8. `config/*` - Alle Template-Dateien
9. `README.md` - Dokumentation

---

**Hinweis für Coding Agent**: 
- Alle Scripts müssen `#!/bin/bash` als Shebang haben
- Shellcheck-kompatibel schreiben
- Ausführliche Kommentare
- Jede Funktion mit Beschreibung
- Fehlerbehandlung in JEDER Funktion
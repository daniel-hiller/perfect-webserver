# Webhosting VM/LXC Installer für Debian 13

**Copyright:** Daniel Hiller
**License:** AGPL-3 or later

Ein vollautomatischer, modularer Installer für produktionsreife Webhosting-Umgebungen auf Debian 13 (Trixie).

## 🚀 Features

- **Multi-Version PHP Support**: PHP 5.6 bis 8.4 parallel installierbar
- **Webserver Auswahl**: Nginx oder Apache mit optimierter Konfiguration
- **Datenbank**: MariaDB mit automatischer Sicherheitshärtung
- **SSL/TLS**: Certbot für kostenlose Let's Encrypt Zertifikate
- **Interaktive Installation**: Benutzerfreundliche Dialog-basierte UI
- **Produktionsreif**: Optimierte Konfigurationen und Security-Hardening
- **Modular**: Klare Trennung der Komponenten für einfache Wartung

## 📋 Voraussetzungen

- **Betriebssystem**: Debian 13 (Trixie) - **NUR Debian 13!**
- **Berechtigungen**: Root-Rechte erforderlich
- **Netzwerk**: Aktive Internetverbindung
- **Speicher**: Mindestens 1 GB RAM (2+ GB empfohlen)
- **Speicherplatz**: Mindestens 5 GB freier Festplattenspeicher

## 🔧 Installation

### Schnellstart

```bash
# Repository klonen
git clone https://github.com/daniel-hiller/perfect-webserver.git
cd perfect-webserver

# Installer ausführbar machen
chmod +x install.sh

# Installation starten
sudo ./install.sh
```

### Interaktiver Installationsprozess

Der Installer führt Sie durch folgende Schritte:

1. **Willkommensbildschirm** - Übersicht über den Installer
2. **Webserver Auswahl** - Nginx oder Apache
3. **PHP Versionen** - Mehrfachauswahl von PHP 5.6 bis 8.4
4. **MariaDB Konfiguration** - Optional mit Datenbank-/Benutzererstellung
5. **Certbot Installation** - Optional für SSL-Zertifikate
6. **Zusammenfassung** - Bestätigung vor Installation
7. **Automatische Installation** - Alle Komponenten werden installiert
8. **Abschluss** - Erfolgsbestätigung mit Zugangsdaten

## 📦 Installierte Komponenten

### PHP-FPM (Multi-Version)

Nach der Installation sind alle ausgewählten PHP-Versionen parallel verfügbar:

```bash
# PHP-FPM Sockets
/run/php/php5.6-fpm.sock
/run/php/php7.4-fpm.sock
/run/php/php8.2-fpm.sock
/run/php/php8.3-fpm.sock
# ... weitere installierte Versionen
```

**Installierte PHP Extensions:**
- mysql/mysqli
- curl
- gd
- mbstring
- xml
- zip
- intl
- bcmath
- imagick (falls verfügbar)
- opcache

### Nginx (falls ausgewählt)

```bash
# Konfiguration
/etc/nginx/nginx.conf
/etc/nginx/sites-available/
/etc/nginx/sites-enabled/

# Webroot
/var/www/html/

# Logs
/var/log/nginx/
```

**Features:**
- HTTP/2 Support
- Optimierte SSL/TLS Konfiguration
- Security Headers
- Gzip Kompression
- Rate Limiting
- PHP-FPM Integration für alle Versionen

### Apache (falls ausgewählt)

```bash
# Konfiguration
/etc/apache2/apache2.conf
/etc/apache2/sites-available/
/etc/apache2/sites-enabled/

# Webroot
/var/www/html/

# Logs
/var/log/apache2/
```

**Aktivierte Module:**
- mod_rewrite
- mod_ssl
- mod_headers
- mod_proxy
- mod_proxy_fcgi

### MariaDB (falls ausgewählt)

```bash
# Verbindung
Host: localhost
Port: 3306
Root-Passwort: [während Installation festgelegt]

# Konfiguration
/etc/mysql/mariadb.conf.d/
```

**Sicherheitsmaßnahmen:**
- Root-Passwort gesetzt
- Anonymous Users entfernt
- Remote Root Login deaktiviert
- Test-Datenbank entfernt
- Optimierte Performance-Einstellungen

### Certbot (falls ausgewählt)

```bash
# Zertifikat anfordern
certbot --nginx -d example.com -d www.example.com
# oder
certbot --apache -d example.com -d www.example.com
```

**Features:**
- Automatische Erneuerung via Systemd Timer
- Nginx/Apache Plugin Integration
- HTTPS Redirect Konfiguration

## 📖 Nach der Installation

### Webserver testen

```bash
# IP-Adresse ermitteln
hostname -I

# Im Browser öffnen
http://YOUR-SERVER-IP/

# PHP testen
http://YOUR-SERVER-IP/info.php
```

### PHP-Version pro Virtual Host wählen

#### Nginx

```nginx
# /etc/nginx/sites-available/example.com
server {
    listen 80;
    server_name example.com;
    root /var/www/example.com;

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass php83;  # php74, php82, php83, etc.
    }
}
```

#### Apache

```apache
# /etc/apache2/sites-available/example.com.conf
<VirtualHost *:80>
    ServerName example.com
    DocumentRoot /var/www/example.com

    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/php/php8.3-fpm.sock|fcgi://localhost"
    </FilesMatch>
</VirtualHost>
```

### Virtual Host erstellen

#### Nginx

```bash
# Neue Site erstellen
sudo nano /etc/nginx/sites-available/example.com

# Site aktivieren
sudo ln -s /etc/nginx/sites-available/example.com /etc/nginx/sites-enabled/

# Konfiguration testen
sudo nginx -t

# Nginx neu laden
sudo systemctl reload nginx
```

#### Apache

```bash
# Neue Site erstellen
sudo nano /etc/apache2/sites-available/example.com.conf

# Site aktivieren
sudo a2ensite example.com

# Konfiguration testen
sudo apache2ctl configtest

# Apache neu laden
sudo systemctl reload apache2
```

### SSL-Zertifikat einrichten

```bash
# Nginx
sudo certbot --nginx -d example.com -d www.example.com

# Apache
sudo certbot --apache -d example.com -d www.example.com

# Zertifikate anzeigen
sudo certbot certificates

# Erneuerung testen
sudo certbot renew --dry-run
```

### MariaDB verwalten

```bash
# MySQL Shell öffnen
sudo mysql

# Datenbank erstellen
CREATE DATABASE mydb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

# Benutzer erstellen
CREATE USER 'myuser'@'localhost' IDENTIFIED BY 'secure_password';

# Rechte vergeben
GRANT ALL PRIVILEGES ON mydb.* TO 'myuser'@'localhost';
FLUSH PRIVILEGES;
```

## 📂 Projektstruktur

```
perfect-webserver/
├── install.sh                    # Haupt-Installationsskript
├── lib/                          # Bibliotheken
│   ├── utils.sh                  # Hilfsfunktionen
│   ├── dialog-menus.sh           # UI/Dialog-Menüs
│   ├── php-installer.sh          # PHP Installation
│   ├── webserver-installer.sh    # Nginx/Apache Installation
│   ├── database-installer.sh     # MariaDB Installation
│   └── certbot-installer.sh      # SSL/Certbot Installation
├── config/                       # Konfigurations-Templates
│   ├── nginx-templates/
│   ├── apache-templates/
│   └── php-templates/
├── logs/                         # Log-Verzeichnis (wird erstellt)
└── README.md                     # Diese Datei
```

## 🔍 Wichtige Dateien & Verzeichnisse

| Pfad | Beschreibung |
|------|--------------|
| `/var/log/webhosting-installer/` | Installations-Logs |
| `/var/log/webhosting-installer/install.log` | Haupt-Logfile |
| `/var/log/webhosting-installer/installation-report.txt` | Installations-Report |
| `/var/log/webhosting-installer/certbot-guide.txt` | Certbot Anleitung |
| `/var/www/html/` | Standard Webroot |
| `/etc/nginx/` oder `/etc/apache2/` | Webserver Config |
| `/etc/php/*/fpm/` | PHP-FPM Konfigurationen |

## 🛠️ Troubleshooting

### PHP-FPM startet nicht

```bash
# Status prüfen
sudo systemctl status php8.3-fpm

# Logs prüfen
sudo journalctl -u php8.3-fpm -n 50

# Neu starten
sudo systemctl restart php8.3-fpm
```

### Webserver startet nicht

```bash
# Nginx
sudo nginx -t                     # Konfiguration testen
sudo systemctl status nginx
sudo tail -f /var/log/nginx/error.log

# Apache
sudo apache2ctl configtest        # Konfiguration testen
sudo systemctl status apache2
sudo tail -f /var/log/apache2/error.log
```

### MariaDB Probleme

```bash
# Status prüfen
sudo systemctl status mariadb

# Logs prüfen
sudo tail -f /var/log/mysql/error.log

# Neu starten
sudo systemctl restart mariadb
```

### Port 80/443 nicht erreichbar

```bash
# Firewall Status prüfen
sudo ufw status

# Ports öffnen (falls nötig)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

## 🔒 Sicherheitshinweise

### Nach der Installation

1. **info.php entfernen** (Security-Risiko):
   ```bash
   sudo rm /var/www/html/info.php
   ```

2. **Regelmäßige Updates**:
   ```bash
   sudo apt update && sudo apt upgrade
   ```

3. **Firewall konfigurieren**:
   ```bash
   sudo ufw status
   sudo ufw enable
   ```

4. **SSH absichern** (falls noch nicht geschehen):
   ```bash
   # SSH-Port ändern, Key-Auth aktivieren, Root-Login deaktivieren
   sudo nano /etc/ssh/sshd_config
   ```

5. **Fail2ban installieren** (optional):
   ```bash
   sudo apt install fail2ban
   sudo systemctl enable fail2ban
   ```

## 📚 Weitere Ressourcen

### Offizielle Dokumentation

- [Nginx Dokumentation](https://nginx.org/en/docs/)
- [Apache Dokumentation](https://httpd.apache.org/docs/)
- [PHP Dokumentation](https://www.php.net/docs.php)
- [MariaDB Dokumentation](https://mariadb.com/kb/en/)
- [Certbot Dokumentation](https://certbot.eff.org/docs/)

### Template-Dateien

Alle Konfigurations-Templates finden Sie im `config/` Verzeichnis:
- Nginx Virtual Host Templates
- Apache Virtual Host Templates
- PHP-FPM Pool Templates

Diese können als Basis für eigene Konfigurationen dienen.

## 🐛 Fehler melden

Bei Problemen oder Fragen:
1. Prüfen Sie die Logs in `/var/log/webhosting-installer/`
2. Erstellen Sie ein Issue im GitHub Repository
3. Fügen Sie relevante Log-Auszüge bei

## 📝 Lizenz

Dieses Projekt steht unter der **GNU Affero General Public License v3.0 oder neuer (AGPL-3.0-or-later)**.

```
Webhosting VM/LXC Installer
Copyright (C) 2024 Daniel Hiller

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
```

## 🎯 Unterstützte Anwendungsfälle

Dieser Installer ist ideal für:

- ✅ Entwicklungsumgebungen
- ✅ Staging-Server
- ✅ Produktions-Webhosting
- ✅ WordPress/Joomla/Drupal Hosting
- ✅ Laravel/Symfony/Custom PHP Apps
- ✅ Multi-Tenant Hosting
- ✅ LXC/Docker Container Basis-Images
- ✅ VM Templates für Proxmox/VMware/VirtualBox

## 🌟 Credits

Entwickelt von **Daniel Hiller**

---

**Hinweis:** Dieser Installer wurde ausschließlich für Debian 13 (Trixie) entwickelt und getestet. Die Verwendung auf anderen Distributionen wird nicht unterstützt und kann zu Fehlfunktionen führen.

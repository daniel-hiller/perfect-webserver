# Perfect Webserver - Single Site Hosting Installer

**Copyright:** Daniel Hiller
**License:** AGPL-3 or later

A fully automated installer for production-ready single-site web hosting environments. Optimized for Debian and Ubuntu LTS releases.

## 🚀 Features

- **Single PHP Version**: Choose one PHP version (5.6 - 8.4) with easy switching
- **Nginx Web Server**: High-performance, modern web server
- **MariaDB Database**: Latest LTS version from official repository
- **SSL/TLS**: Certbot for free Let's Encrypt certificates
- **Composer**: PHP dependency manager installed globally
- **PHP Version Switcher**: Switch between PHP versions with one command
- **Security Hardening**: Fail2ban, automatic updates, resource monitoring
- **Interactive Installation**: User-friendly dialog-based UI
- **Production-Ready**: Optimized configurations and security best practices
- **Modern OS Support**: Debian 12/13 and Ubuntu 22.04/24.04 LTS

## 📋 Requirements

- **Operating System**:
  - Debian 12 (Bookworm) or 13 (Trixie)
  - Ubuntu 22.04 LTS (Jammy) or 24.04 LTS (Noble)
- **Permissions**: Root privileges required
- **Network**: Active internet connection
- **Memory**: At least 1 GB RAM (2+ GB recommended)
- **Disk Space**: At least 5 GB free disk space

### LXC Container Requirements (Proxmox)

If running in an LXC container, **unprivileged containers are REQUIRED**:

```bash
# On Proxmox host, configure container:
pct set <CTID> -unprivileged 1 -features keyctl=1,nesting=1
```

**Important Notes:**
- **Unprivileged containers ONLY** - Privileged containers are NOT supported
- Required features: `keyctl=1` and `nesting=1` for MariaDB and systemd compatibility
- The installer will abort if a privileged container is detected
- For VMs or bare metal installations, no special configuration is needed

## 🔧 Installation

### Quick Start

\`\`\`bash
# Clone repository
git clone https://github.com/yourusername/perfect-webserver.git
cd perfect-webserver

# Make installer executable
chmod +x install.sh

# Start installation
sudo ./install.sh

# Optional: Override MariaDB version (default: 11.8)
sudo MARIADB_VERSION=11.4 ./install.sh
\`\`\`

### Re-running the Installer

The installer is **idempotent** - you can safely re-run it:

- Already installed components are automatically detected and skipped
- New components can be added without reinstalling existing ones
- Installation state is tracked in: `/root/.webhosting-installer-state`
- Credentials are backed up in: `/root/.webhosting-credentials`

**Example:** If you initially installed only Nginx+PHP, you can re-run to add MariaDB without affecting your existing setup.

### Interactive Installation Process

The installer guides you through the following steps:

1. **Welcome Screen** - Overview of the installer
2. **Web Server** - Nginx (optimized for single sites)
3. **PHP Version** - Choose ONE PHP version (5.6 - 8.4)
4. **MariaDB Configuration** - Optional with database/user creation
5. **Certbot Installation** - Optional for SSL certificates
6. **Security Setup** - Fail2ban and automatic security updates
7. **PHP Configuration** - php.ini settings (optional)
8. **Backup Configuration** - Automatic backup schedule (optional)
9. **Summary** - Confirmation before installation
10. **Automatic Installation** - All components are installed
11. **Completion** - Success confirmation with access details

## 📦 Installed Components

### Nginx Web Server

**Configuration:**
- `/etc/nginx/nginx.conf`
- `/etc/nginx/sites-available/default`
- Webroot: `/var/www/html/`

**Features:**
- HTTP/2, Optimized SSL/TLS, Security Headers
- Gzip Compression, Rate Limiting
- PHP-FPM integration
- Optimized for single-site hosting

### PHP-FPM (Single Version)

Your selected PHP version is installed with FPM:

\`\`\`bash
# PHP-FPM Socket (example for PHP 8.3)
/run/php/php8.3-fpm.sock

# Webserver Manager - All-in-one management tool:
webserver-manager php status              # Show PHP version
webserver-manager php switch 8.4          # Switch PHP version
webserver-manager php install 7.4         # Install new version
webserver-manager php config              # Configure php.ini

# Database Management:
webserver-manager db create               # Create database/user
webserver-manager db list                 # List databases

# System & Security:
webserver-manager system update           # Update system & Composer
webserver-manager system security         # Run security check

# Backups:
webserver-manager backup setup            # Configure backups
webserver-manager backup now              # Run backup now
\`\`\`

**Installed PHP Extensions:**
- mysql/mysqli, curl, gd, mbstring, xml, zip
- intl, bcmath, imagick (if available), opcache

**Composer (Dependency Manager):**
- Installed globally: `/usr/local/bin/composer`
- Usage: `composer install`, `composer require vendor/package`
- Auto-updated to latest stable version

### MariaDB (if selected)

- Host: `localhost:3306`
- Root password set during installation
- Security hardening applied automatically

### Certbot (if selected)

- Automatic renewal via Systemd timer
- Easy certificate requests: `certbot --nginx -d example.com`

### Security Features (if enabled)

**Fail2ban:**
- SSH protection: Auto-bans after 3 failed login attempts
- Nginx protection: HTTP auth, bad bots, noscript, noproxy
- Configuration: `/etc/fail2ban/jail.local`
- Check status: `fail2ban-client status`

**Unattended-Upgrades:**
- Automatic security updates only (not all packages)
- Daily checks for security patches
- Configuration: `/etc/apt/apt.conf.d/50unattended-upgrades`
- Automatic cleanup of old packages

**System Resource Monitoring:**
- SSH login displays: CPU, RAM, Disk usage
- Service status: Nginx, PHP-FPM, MariaDB
- Color-coded warnings for high resource usage
- Security reminders and tips

## 📖 After Installation

### Test Webserver

\`\`\`bash
# Get IP address
hostname -I

# Open in browser: http://YOUR-SERVER-IP/
# Test PHP: http://YOUR-SERVER-IP/info.php
\`\`\`

### Select PHP Version per Virtual Host

**Nginx:**
\`\`\`nginx
location ~ \\.php$ {
    fastcgi_pass php83;  # php74, php82, php83, etc.
}
\`\`\`

**Apache:**
\`\`\`apache
<FilesMatch \\.php$>
    SetHandler "proxy:unix:/run/php/php8.3-fpm.sock|fcgi://localhost"
</FilesMatch>
\`\`\`

### Create Virtual Host

**Nginx:**
\`\`\`bash
sudo nano /etc/nginx/sites-available/example.com
sudo ln -s /etc/nginx/sites-available/example.com /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
\`\`\`

**Apache:**
\`\`\`bash
sudo nano /etc/apache2/sites-available/example.com.conf
sudo a2ensite example.com
sudo apache2ctl configtest && sudo systemctl reload apache2
\`\`\`

### Setup SSL Certificate

\`\`\`bash
# Nginx
sudo certbot --nginx -d example.com -d www.example.com

# Apache
sudo certbot --apache -d example.com -d www.example.com
\`\`\`

### Manage MariaDB

\`\`\`bash
sudo mysql
CREATE DATABASE mydb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'myuser'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON mydb.* TO 'myuser'@'localhost';
FLUSH PRIVILEGES;
\`\`\`

## 📂 Project Structure

\`\`\`
perfect-webserver/
├── install.sh                    # Main installation script
├── lib/                          # Libraries
│   ├── utils.sh                  # Utility functions
│   ├── dialog-menus.sh           # UI/Dialog menus
│   ├── php-installer.sh          # PHP installation
│   ├── webserver-installer.sh    # Nginx/Apache installation
│   ├── database-installer.sh     # MariaDB installation
│   └── certbot-installer.sh      # SSL/Certbot installation
├── config/                       # Configuration templates
│   ├── nginx-templates/
│   ├── apache-templates/
│   └── php-templates/
└── README.md                     # This file
\`\`\`

## 🛠️ Troubleshooting

### LXC Container Issues (Proxmox)

**Installer aborts: "PRIVILEGED LXC container detected"**

The installer requires unprivileged LXC containers. To fix:

1. Create a new unprivileged container:
   \`\`\`bash
   # On Proxmox host:
   pct set <CTID> -unprivileged 1 -features keyctl=1,nesting=1
   \`\`\`

2. Verify container type inside the container:
   \`\`\`bash
   cat /proc/self/uid_map
   # "0 0 4294967295" = privileged (NOT supported)
   # "0 100000 65536" = unprivileged (required)
   \`\`\`

**Locale warnings during installation:**
- Automatically fixed by installer via \`setup_locale()\` function
- Generates \`en_US.UTF-8\` locale for LXC containers

### PHP-FPM Issues
\`\`\`bash
sudo systemctl status php8.3-fpm
sudo journalctl -u php8.3-fpm -n 50
sudo systemctl restart php8.3-fpm
\`\`\`

### Webserver Issues
\`\`\`bash
# Nginx
sudo nginx -t && sudo systemctl status nginx

# Apache
sudo apache2ctl configtest && sudo systemctl status apache2
\`\`\`

### MariaDB Issues
\`\`\`bash
sudo systemctl status mariadb
sudo journalctl -u mariadb -n 50
sudo tail -f /var/log/mysql/error.log
\`\`\`

### Firewall
\`\`\`bash
sudo ufw status
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
\`\`\`

## 🔒 Security Features

### Built-in Security
- ✅ `.git` directory access blocked (prevents source code exposure)
- ✅ Environment files (`.env`) blocked
- ✅ Configuration files (`.yml`, `.ini`, `.conf`) blocked
- ✅ Package manager files (`composer.json`, `package.json`) blocked
- ✅ Version control files blocked
- ✅ Security headers enabled (X-Frame-Options, X-Content-Type-Options, etc.)
- ✅ Server tokens disabled (hides Nginx version)
- ✅ Rate limiting configured

### Post-Installation Security

1. **Run security check**: `webserver-manager system security`
   - Checks for common security issues (info.php, firewall, SSH, etc.)
   - Provides actionable fix recommendations
   - Run regularly to verify security posture

2. **Remove test files**: `sudo rm /var/www/html/info.php`

3. **Regular updates**: `webserver-manager system update`
   - Updates all packages (apt upgrade)
   - Updates Composer to latest version
   - Recommended: Weekly or use automatic updates

4. **Review Fail2ban status** (if installed):
   ```bash
   fail2ban-client status          # Overview
   fail2ban-client status sshd     # SSH jail details
   fail2ban-client status nginx-*  # Nginx jails
   ```

5. **Monitor system resources**:
   - Automatic on SSH login (MOTD)
   - Check logs: `/var/log/webhosting-installer/`
   - Webserver logs: `/var/log/nginx/`

6. **Review security configurations**:
   - Firewall: `ufw status verbose`
   - Nginx security: `/etc/nginx/sites-enabled/default`
   - Fail2ban: `/etc/fail2ban/jail.local`

## 📚 Resources

- [Nginx Documentation](https://nginx.org/en/docs/)
- [Apache Documentation](https://httpd.apache.org/docs/)
- [PHP Documentation](https://www.php.net/docs.php)
- [MariaDB Documentation](https://mariadb.com/kb/en/)
- [Certbot Documentation](https://certbot.eff.org/docs/)

## 🐛 Report Issues

1. Check logs in `/var/log/webhosting-installer/`
2. Create an issue on GitHub
3. Include relevant log excerpts

## 📝 License

GNU Affero General Public License v3.0 or later (AGPL-3.0-or-later)

Copyright (C) 2024 Daniel Hiller

## 🎯 Supported Use Cases

- Development/Staging/Production environments
- WordPress/Joomla/Drupal/Laravel/Symfony hosting
- Multi-tenant hosting
- LXC/Docker base images
- VM templates (Proxmox/VMware/VirtualBox)

## 🌟 Credits

Developed by **Daniel Hiller**

---

**Note:** Developed and tested exclusively for Debian 13 (Trixie).

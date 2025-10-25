# Webhosting VM/LXC Installer for Debian 13

**Copyright:** Daniel Hiller  
**License:** AGPL-3 or later

A fully automated, modular installer for production-ready webhosting environments on Debian 13 (Trixie).

## 🚀 Features

- **Multi-Version PHP Support**: Install PHP 5.6 to 8.4 in parallel
- **Webserver Choice**: Nginx or Apache with optimized configuration
- **Database**: MariaDB with automatic security hardening
- **SSL/TLS**: Certbot for free Let's Encrypt certificates
- **Interactive Installation**: User-friendly dialog-based UI
- **Production-Ready**: Optimized configurations and security hardening
- **Modular**: Clear separation of components for easy maintenance

## 📋 Requirements

- **Operating System**: Debian 13 (Trixie) - **ONLY Debian 13!**
- **Permissions**: Root privileges required
- **Network**: Active internet connection
- **Memory**: At least 1 GB RAM (2+ GB recommended)
- **Disk Space**: At least 5 GB free disk space

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
\`\`\`

### Interactive Installation Process

The installer guides you through the following steps:

1. **Welcome Screen** - Overview of the installer
2. **Webserver Selection** - Nginx or Apache
3. **PHP Versions** - Multiple selection from PHP 5.6 to 8.4
4. **MariaDB Configuration** - Optional with database/user creation
5. **Certbot Installation** - Optional for SSL certificates
6. **Summary** - Confirmation before installation
7. **Automatic Installation** - All components are installed
8. **Completion** - Success confirmation with access details

## 📦 Installed Components

### PHP-FPM (Multi-Version)

After installation, all selected PHP versions are available in parallel:

\`\`\`bash
# PHP-FPM Sockets
/run/php/php5.6-fpm.sock
/run/php/php7.4-fpm.sock
/run/php/php8.2-fpm.sock
/run/php/php8.3-fpm.sock
# ... additional installed versions
\`\`\`

**Installed PHP Extensions:**
- mysql/mysqli, curl, gd, mbstring, xml, zip
- intl, bcmath, imagick (if available), opcache

### Nginx (if selected)

**Configuration:**
- `/etc/nginx/nginx.conf`
- `/etc/nginx/sites-available/`
- Webroot: `/var/www/html/`

**Features:**
- HTTP/2, Optimized SSL/TLS, Security Headers
- Gzip Compression, Rate Limiting
- PHP-FPM integration for all versions

### Apache (if selected)

**Configuration:**
- `/etc/apache2/apache2.conf`
- `/etc/apache2/sites-available/`
- Webroot: `/var/www/html/`

**Enabled Modules:**
- mod_rewrite, mod_ssl, mod_headers, mod_proxy, mod_proxy_fcgi

### MariaDB (if selected)

- Host: `localhost:3306`
- Root password set during installation
- Security hardening applied automatically

### Certbot (if selected)

- Automatic renewal via Systemd timer
- Easy certificate requests: `certbot --nginx -d example.com`

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
sudo tail -f /var/log/mysql/error.log
\`\`\`

### Firewall
\`\`\`bash
sudo ufw status
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
\`\`\`

## 🔒 Security Notes

1. **Remove info.php**: `sudo rm /var/www/html/info.php`
2. **Regular updates**: `sudo apt update && sudo apt upgrade`
3. **Configure firewall**: `sudo ufw enable`
4. **Secure SSH**: Edit `/etc/ssh/sshd_config`
5. **Install Fail2ban**: `sudo apt install fail2ban`

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

#!/bin/bash
#
# Webhosting Installer - MariaDB Installation Functions
# Copyright: Daniel Hiller
# License: AGPL-3 or later
#
# MariaDB installation, security hardening, and database management
#

# ============================================================================
# MARIADB INSTALLATION
# ============================================================================

# install_mariadb: Install MariaDB server and client from official repository
install_mariadb() {
    log "Installing MariaDB server..."

    # Check if MariaDB is already installed
    if systemctl is-active --quiet mariadb && command -v mariadb &> /dev/null; then
        local installed_version
        installed_version=$(mysql_cmd --version | awk '{print $5}' | sed 's/,//')
        log "MariaDB is already installed (version: ${installed_version})"
        log "Skipping MariaDB installation..."
        return 0
    fi

    # Install dependencies first
    log "Installing MariaDB dependencies..."
    local deps=("gawk" "rsync" "socat" "libdbi-perl" "pv")
    for dep in "${deps[@]}"; do
        install_package "$dep" || log "Warning: Failed to install $dep"
    done

    # Add official MariaDB repository for latest version
    log "Adding official MariaDB repository..."

    # Get Debian codename
    local codename
    codename=$(lsb_release -sc)

    # Download and install MariaDB GPG key
    log "Adding MariaDB GPG key..."
    wget -qO /tmp/mariadb-keyring.gpg https://mariadb.org/mariadb_release_signing_key.asc || {
        error_exit "Failed to download MariaDB GPG key"
    }

    gpg --dearmor < /tmp/mariadb-keyring.gpg > /usr/share/keyrings/mariadb-keyring.gpg 2>/dev/null
    rm -f /tmp/mariadb-keyring.gpg

    # MariaDB version selection
    # 11.8 = Current LTS (Long Term Support) - maintained until May 2031
    # 11.4 = Previous LTS - maintained until May 2029
    # See: https://mariadb.org/about/#maintenance-policy
    # Override with: MARIADB_VERSION=11.4 ./install.sh
    local mariadb_version="${MARIADB_VERSION:-11.8}"
    log "Using MariaDB version: ${mariadb_version} (LTS)"

    # Add MariaDB repository
    cat > /etc/apt/sources.list.d/mariadb.list << EOF
# MariaDB ${mariadb_version} repository
deb [signed-by=/usr/share/keyrings/mariadb-keyring.gpg] http://mirror.mariadb.org/repo/${mariadb_version}/debian ${codename} main
EOF

    # Set debconf to disable feedback plugin
    echo "mariadb-server-${mariadb_version} mariadb-server/feedback boolean false" | debconf-set-selections

    # Update package lists
    log "Updating package lists with MariaDB repository..."
    apt-get update -qq || error_exit "Failed to update package lists"

    # Install MariaDB packages
    log "Installing MariaDB ${mariadb_version} packages..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq mariadb-server mariadb-client || {
        error_exit "Failed to install MariaDB packages"
    }

    # Enable and start MariaDB
    log "Enabling and starting MariaDB service..."
    systemctl enable mariadb || log "Warning: Failed to enable MariaDB service"

    # Start MariaDB with retry logic
    local start_attempts=3
    local attempt=0
    local service_started=false

    while [[ ${attempt} -lt ${start_attempts} ]]; do
        attempt=$((attempt + 1))
        log "Starting MariaDB (attempt ${attempt}/${start_attempts})..."

        if systemctl start mariadb; then
            service_started=true
            break
        else
            log "Failed to start MariaDB, waiting 3 seconds before retry..."
            sleep 3
        fi
    done

    if [[ "${service_started}" != "true" ]]; then
        log "ERROR: Failed to start MariaDB after ${start_attempts} attempts"
        log "Checking MariaDB logs..."
        journalctl -u mariadb -n 50 --no-pager | tee -a "${LOG_FILE}" || true

        error_exit "MariaDB service failed to start. Check logs for details."
    fi

    # Wait for MariaDB to be ready
    log "Waiting for MariaDB to be ready..."
    local retries=30
    local count=0

    while ! mysqladmin_cmd ping --silent 2>/dev/null; do
        count=$((count + 1))
        if [[ ${count} -ge ${retries} ]]; then
            log "ERROR: MariaDB not responding after ${retries} seconds"
            log "Checking MariaDB status..."
            systemctl status mariadb --no-pager | tee -a "${LOG_FILE}" || true
            error_exit "MariaDB failed to become ready within timeout period"
        fi
        sleep 1
    done

    log "MariaDB is ready"

    # Verify installation
    local mariadb_version_installed
    mariadb_version_installed=$(mysql_cmd --version | awk '{print $5}' | sed 's/,//')
    log "MariaDB version: ${mariadb_version_installed}"

    log "MariaDB installation completed successfully"
}

# ============================================================================
# SECURITY HARDENING
# ============================================================================

# secure_mariadb: Run mysql_secure_installation equivalent
secure_mariadb() {
    log "Securing MariaDB installation..."

    if [[ -z "${DB_ROOT_PASSWORD}" ]]; then
        error_exit "DB_ROOT_PASSWORD is not set"
    fi

    # Set root password
    log "Setting MariaDB root password..."
    mysql_cmd -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';" || {
        error_exit "Failed to set MariaDB root password"
    }

    # Create .my.cnf for root user to allow non-interactive access
    cat > /root/.my.cnf << EOF
[client]
user=root
password=${DB_ROOT_PASSWORD}
EOF
    chmod 600 /root/.my.cnf

    # Remove anonymous users
    log "Removing anonymous users..."
    mysql_cmd -e "DELETE FROM mysql.user WHERE User='';" || {
        log "Warning: Failed to remove anonymous users"
    }

    # Disallow root login remotely
    log "Disabling remote root login..."
    mysql_cmd -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" || {
        log "Warning: Failed to disable remote root login"
    }

    # Remove test database
    log "Removing test database..."
    mysql_cmd -e "DROP DATABASE IF EXISTS test;" || {
        log "Warning: Failed to remove test database"
    }
    mysql_cmd -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" || {
        log "Warning: Failed to remove test database privileges"
    }

    # Flush privileges
    log "Flushing privileges..."
    mysql_cmd -e "FLUSH PRIVILEGES;" || {
        error_exit "Failed to flush privileges"
    }

    log "MariaDB security hardening completed"
}

# ============================================================================
# DATABASE MANAGEMENT
# ============================================================================

# create_database: Create a new database
create_database() {
    log "Creating database: ${DB_NAME}"

    if [[ -z "${DB_NAME}" ]]; then
        error_exit "DB_NAME is not set"
    fi

    # Check if database exists
    local db_exists
    db_exists=$(mysql_cmd -sNe "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${DB_NAME}'")

    if [[ -n "${db_exists}" ]]; then
        log "Database ${DB_NAME} already exists"
        return 0
    fi

    # Create database
    mysql_cmd -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" || {
        error_exit "Failed to create database: ${DB_NAME}"
    }

    log "Database created: ${DB_NAME}"
}

# create_db_user: Create database user
create_db_user() {
    log "Creating database user: ${DB_USER}"

    if [[ -z "${DB_USER}" ]]; then
        error_exit "DB_USER is not set"
    fi

    if [[ -z "${DB_PASSWORD}" ]]; then
        error_exit "DB_PASSWORD is not set"
    fi

    # Check if user exists
    local user_exists
    user_exists=$(mysql_cmd -sNe "SELECT User FROM mysql.user WHERE User='${DB_USER}' AND Host='localhost'")

    if [[ -n "${user_exists}" ]]; then
        log "User ${DB_USER} already exists, updating password..."
        mysql_cmd -e "ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';" || {
            error_exit "Failed to update password for user: ${DB_USER}"
        }
    else
        # Create user
        mysql_cmd -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';" || {
            error_exit "Failed to create user: ${DB_USER}"
        }
        log "User created: ${DB_USER}"
    fi
}

# grant_privileges: Grant privileges to user on database
grant_privileges() {
    log "Granting privileges to ${DB_USER} on ${DB_NAME}..."

    if [[ -z "${DB_USER}" ]]; then
        error_exit "DB_USER is not set"
    fi

    if [[ -z "${DB_NAME}" ]]; then
        error_exit "DB_NAME is not set"
    fi

    # Grant all privileges on database
    mysql_cmd -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';" || {
        error_exit "Failed to grant privileges to ${DB_USER} on ${DB_NAME}"
    }

    # Flush privileges
    mysql_cmd -e "FLUSH PRIVILEGES;" || {
        error_exit "Failed to flush privileges"
    }

    log "Privileges granted successfully"
}

# ============================================================================
# END OF DATABASE INSTALLER
# ============================================================================

log "Database installer library loaded successfully"

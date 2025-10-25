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

# install_mariadb: Install MariaDB server and client
install_mariadb() {
    log "Installing MariaDB server..."

    # Install MariaDB packages
    install_package "mariadb-server"
    install_package "mariadb-client"

    # Enable and start MariaDB
    enable_service "mariadb"

    # Wait for MariaDB to be ready
    log "Waiting for MariaDB to be ready..."
    local retries=30
    local count=0

    while ! mysqladmin ping --silent; do
        count=$((count + 1))
        if [[ ${count} -ge ${retries} ]]; then
            error_exit "MariaDB failed to start within timeout period"
        fi
        sleep 1
    done

    log "MariaDB is ready"

    # Verify installation
    local mariadb_version
    mariadb_version=$(mysql --version | awk '{print $5}' | sed 's/,//')
    log "MariaDB version: ${mariadb_version}"

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
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';" || {
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
    mysql -e "DELETE FROM mysql.user WHERE User='';" || {
        log "Warning: Failed to remove anonymous users"
    }

    # Disallow root login remotely
    log "Disabling remote root login..."
    mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" || {
        log "Warning: Failed to disable remote root login"
    }

    # Remove test database
    log "Removing test database..."
    mysql -e "DROP DATABASE IF EXISTS test;" || {
        log "Warning: Failed to remove test database"
    }
    mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" || {
        log "Warning: Failed to remove test database privileges"
    }

    # Flush privileges
    log "Flushing privileges..."
    mysql -e "FLUSH PRIVILEGES;" || {
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
    db_exists=$(mysql -sNe "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${DB_NAME}'")

    if [[ -n "${db_exists}" ]]; then
        log "Database ${DB_NAME} already exists"
        return 0
    fi

    # Create database
    mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" || {
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
    user_exists=$(mysql -sNe "SELECT User FROM mysql.user WHERE User='${DB_USER}' AND Host='localhost'")

    if [[ -n "${user_exists}" ]]; then
        log "User ${DB_USER} already exists, updating password..."
        mysql -e "ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';" || {
            error_exit "Failed to update password for user: ${DB_USER}"
        }
    else
        # Create user
        mysql -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';" || {
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
    mysql -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';" || {
        error_exit "Failed to grant privileges to ${DB_USER} on ${DB_NAME}"
    }

    # Flush privileges
    mysql -e "FLUSH PRIVILEGES;" || {
        error_exit "Failed to flush privileges"
    }

    log "Privileges granted successfully"
}

# ============================================================================
# MARIADB CONFIGURATION
# ============================================================================

# optimize_mariadb_config: Optimize MariaDB configuration based on system resources
optimize_mariadb_config() {
    log "Optimizing MariaDB configuration..."

    local config_file="/etc/mysql/mariadb.conf.d/99-webhosting-optimization.cnf"

    # Get system resources
    local total_memory
    total_memory=$(get_total_memory)

    # Calculate buffer pool size (50% of RAM for systems with >= 2GB, 25% for smaller)
    local innodb_buffer_pool_size
    if [[ ${total_memory} -ge 2048 ]]; then
        innodb_buffer_pool_size=$((total_memory / 2))
    else
        innodb_buffer_pool_size=$((total_memory / 4))
    fi

    # Ensure minimum size
    [[ ${innodb_buffer_pool_size} -lt 128 ]] && innodb_buffer_pool_size=128

    log "Calculated InnoDB buffer pool size: ${innodb_buffer_pool_size}M"

    # Create optimization config
    cat > "${config_file}" << EOF
# MariaDB Optimization Configuration
# Auto-generated by Webhosting Installer
# System Memory: ${total_memory}M

[mysqld]

# InnoDB Settings
innodb_buffer_pool_size = ${innodb_buffer_pool_size}M
innodb_log_file_size = 64M
innodb_flush_log_at_trx_commit = 2
innodb_file_per_table = 1

# Query Cache (disabled in MariaDB 10.5+)
# query_cache_type = 0
# query_cache_size = 0

# Connection Settings
max_connections = 150
max_allowed_packet = 64M

# Logging
log_error = /var/log/mysql/error.log
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow-query.log
long_query_time = 2

# Character Set
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

# Performance Schema (disable for lower memory usage)
performance_schema = OFF
EOF

    # Restart MariaDB to apply changes
    log "Restarting MariaDB to apply optimizations..."
    restart_service "mariadb"

    log "MariaDB optimization completed"
}

# ============================================================================
# BACKUP AND MAINTENANCE
# ============================================================================

# create_backup_script: Create automated backup script
create_backup_script() {
    log "Creating database backup script..."

    local backup_script="/usr/local/bin/mysql-backup.sh"
    local backup_dir="/var/backups/mysql"

    # Create backup directory
    mkdir -p "${backup_dir}"
    chmod 700 "${backup_dir}"

    # Create backup script
    cat > "${backup_script}" << 'EOF'
#!/bin/bash
#
# MySQL/MariaDB Backup Script
# Auto-generated by Webhosting Installer
#

BACKUP_DIR="/var/backups/mysql"
RETENTION_DAYS=7
DATE=$(date +%Y%m%d-%H%M%S)

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Get all databases
DATABASES=$(mysql -sNe "SHOW DATABASES" | grep -Ev '^(information_schema|performance_schema|mysql|sys)$')

# Backup each database
for db in ${DATABASES}; do
    BACKUP_FILE="${BACKUP_DIR}/${db}-${DATE}.sql.gz"
    echo "Backing up database: ${db}"
    mysqldump --single-transaction --routines --triggers "${db}" | gzip > "${BACKUP_FILE}"

    if [[ $? -eq 0 ]]; then
        echo "Backup created: ${BACKUP_FILE}"
    else
        echo "ERROR: Backup failed for database: ${db}"
    fi
done

# Remove old backups
find "${BACKUP_DIR}" -name "*.sql.gz" -mtime +${RETENTION_DAYS} -delete
echo "Old backups removed (older than ${RETENTION_DAYS} days)"

echo "Backup completed: $(date)"
EOF

    chmod 755 "${backup_script}"

    log "Backup script created: ${backup_script}"
    log "Usage: ${backup_script}"
}

# ============================================================================
# DATABASE UTILITIES
# ============================================================================

# test_database_connection: Test database connection
test_database_connection() {
    log "Testing database connection..."

    if ! mysqladmin ping --silent; then
        error_exit "Database connection test failed"
    fi

    log "Database connection test successful"
}

# list_databases: List all databases
list_databases() {
    log "Listing databases..."
    mysql -sNe "SHOW DATABASES"
}

# list_users: List all users
list_users() {
    log "Listing users..."
    mysql -sNe "SELECT User, Host FROM mysql.user ORDER BY User"
}

# get_database_size: Get size of specific database
# Usage: get_database_size "database_name"
get_database_size() {
    local db_name="$1"

    if [[ -z "${db_name}" ]]; then
        error_exit "Database name not specified"
    fi

    mysql -sNe "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
                FROM information_schema.TABLES
                WHERE table_schema = '${db_name}'"
}

# ============================================================================
# USER MANAGEMENT
# ============================================================================

# create_additional_user: Create additional database user with specific privileges
# Usage: create_additional_user "username" "password" "database" "privileges"
create_additional_user() {
    local username="$1"
    local password="$2"
    local database="$3"
    local privileges="${4:-ALL PRIVILEGES}"

    log "Creating user: ${username} with ${privileges} on ${database}"

    # Validate inputs
    if [[ -z "${username}" ]] || [[ -z "${password}" ]] || [[ -z "${database}" ]]; then
        error_exit "Missing parameters for user creation"
    fi

    # Create user if not exists
    mysql -e "CREATE USER IF NOT EXISTS '${username}'@'localhost' IDENTIFIED BY '${password}';" || {
        error_exit "Failed to create user: ${username}"
    }

    # Grant privileges
    mysql -e "GRANT ${privileges} ON \`${database}\`.* TO '${username}'@'localhost';" || {
        error_exit "Failed to grant privileges to ${username}"
    }

    # Flush privileges
    mysql -e "FLUSH PRIVILEGES;" || {
        error_exit "Failed to flush privileges"
    }

    log "User created and privileges granted: ${username}"
}

# delete_user: Delete database user
# Usage: delete_user "username"
delete_user() {
    local username="$1"

    if [[ -z "${username}" ]]; then
        error_exit "Username not specified"
    fi

    log "Deleting user: ${username}"

    mysql -e "DROP USER IF EXISTS '${username}'@'localhost';" || {
        error_exit "Failed to delete user: ${username}"
    }

    mysql -e "FLUSH PRIVILEGES;"

    log "User deleted: ${username}"
}

# ============================================================================
# DATABASE OPERATIONS
# ============================================================================

# import_database: Import SQL file into database
# Usage: import_database "database_name" "/path/to/file.sql"
import_database() {
    local db_name="$1"
    local sql_file="$2"

    if [[ -z "${db_name}" ]] || [[ -z "${sql_file}" ]]; then
        error_exit "Missing parameters for database import"
    fi

    if [[ ! -f "${sql_file}" ]]; then
        error_exit "SQL file not found: ${sql_file}"
    fi

    log "Importing ${sql_file} into ${db_name}..."

    mysql "${db_name}" < "${sql_file}" || {
        error_exit "Failed to import database from ${sql_file}"
    }

    log "Database import completed"
}

# export_database: Export database to SQL file
# Usage: export_database "database_name" "/path/to/output.sql"
export_database() {
    local db_name="$1"
    local output_file="$2"

    if [[ -z "${db_name}" ]] || [[ -z "${output_file}" ]]; then
        error_exit "Missing parameters for database export"
    fi

    log "Exporting ${db_name} to ${output_file}..."

    mysqldump --single-transaction --routines --triggers "${db_name}" > "${output_file}" || {
        error_exit "Failed to export database to ${output_file}"
    }

    log "Database export completed: ${output_file}"
}

# ============================================================================
# MONITORING
# ============================================================================

# show_mariadb_status: Display MariaDB status information
show_mariadb_status() {
    log "MariaDB Status:"
    echo "==============================================="

    echo -e "\nVersion:"
    mysql -sNe "SELECT VERSION()"

    echo -e "\nUptime:"
    mysql -sNe "SHOW GLOBAL STATUS LIKE 'Uptime'" | awk '{print $2}'

    echo -e "\nConnections:"
    mysql -sNe "SHOW GLOBAL STATUS LIKE 'Threads_connected'" | awk '{print $2}'

    echo -e "\nDatabases:"
    list_databases

    echo "==============================================="
}

# ============================================================================
# END OF DATABASE INSTALLER
# ============================================================================

log "Database installer library loaded successfully"

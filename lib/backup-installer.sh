#!/bin/bash
#
# Webhosting Installer - Backup Configuration
# Copyright: Daniel Hiller
# License: AGPL-3 or later
#
# Automatic backup setup for webroot and databases
#

# ============================================================================
# BACKUP SETUP
# ============================================================================

# setup_automatic_backups: Configure automatic backups
setup_automatic_backups() {
    if [[ "${CONFIGURE_BACKUP}" != "yes" ]]; then
        log "Backup configuration skipped"
        return 0
    fi

    log "Setting up automatic backups..."

    local backup_dir="/var/backups/webserver"
    mkdir -p "$backup_dir"
    chmod 700 "$backup_dir"

    # Get list of databases to backup
    local selected_dbs=()
    if [[ "${INSTALL_MARIADB}" == "yes" ]] && [[ "${CREATE_DATABASE}" == "yes" ]]; then
        selected_dbs+=("${DB_NAME}")
        log "Will backup database: ${DB_NAME}"
    fi

    # Create backup script
    local backup_script="/usr/local/bin/webserver-backup.sh"
    cat > "$backup_script" << 'BACKUP_EOF'
#!/bin/bash
set -euo pipefail

BACKUP_DIR="/var/backups/webserver"
KEEP_DAYS=7
DATE=$(date +%Y%m%d_%H%M%S)

# Webroot backup
tar -czf "${BACKUP_DIR}/webroot_${DATE}.tar.gz" -C /var/www html 2>/dev/null || true

BACKUP_EOF

    # Add database backups
    for db in "${selected_dbs[@]}"; do
        cat >> "$backup_script" << BACKUP_EOF
# Database backup: ${db}
if command -v mariadb &> /dev/null; then
    mariadb-dump --single-transaction --quick --lock-tables=false "${db}" | gzip > "\${BACKUP_DIR}/db_${db}_\${DATE}.sql.gz" 2>/dev/null || true
else
    mysqldump --single-transaction --quick --lock-tables=false "${db}" | gzip > "\${BACKUP_DIR}/db_${db}_\${DATE}.sql.gz" 2>/dev/null || true
fi

BACKUP_EOF
    done

    cat >> "$backup_script" << 'BACKUP_EOF'

# Cleanup old backups
find "${BACKUP_DIR}" -name "*.tar.gz" -mtime +${KEEP_DAYS} -delete 2>/dev/null || true
find "${BACKUP_DIR}" -name "*.sql.gz" -mtime +${KEEP_DAYS} -delete 2>/dev/null || true

echo "Backup completed: $(date)"
BACKUP_EOF

    chmod +x "$backup_script"

    # Add to root crontab
    log "Adding backup to crontab: ${BACKUP_SCHEDULE}"
    (crontab -l 2>/dev/null || true; echo "${BACKUP_SCHEDULE} ${backup_script} >> /var/log/webserver-backup.log 2>&1") | crontab -

    log "Automatic backups configured successfully"
    log "Backup directory: ${backup_dir}"
    log "Schedule: ${BACKUP_SCHEDULE}"
    log "Log file: /var/log/webserver-backup.log"
}

# ============================================================================
# END OF BACKUP INSTALLER
# ============================================================================

log "Backup installer library loaded successfully"

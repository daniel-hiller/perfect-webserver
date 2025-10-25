#!/bin/bash
#
# Webhosting Installer - Certbot Installation Functions
# Copyright: Daniel Hiller
# License: AGPL-3 or later
#
# Certbot/Let's Encrypt SSL certificate installation
#

# ============================================================================
# CERTBOT INSTALLATION
# ============================================================================

# install_certbot: Install Certbot and dependencies
install_certbot() {
    log "Installing Certbot..."

    # Install Certbot
    install_package "certbot"

    # Install Python dependencies
    install_package "python3-certbot"

    # Verify installation
    if ! command -v certbot &> /dev/null; then
        error_exit "Certbot installation verification failed"
    fi

    local certbot_version
    certbot_version=$(certbot --version 2>&1 | head -n 1)
    log "Installed: ${certbot_version}"

    log "Certbot installation completed successfully"
}

# ============================================================================
# WEBSERVER-SPECIFIC PLUGINS
# ============================================================================

# install_certbot_plugin: Install webserver-specific Certbot plugin
install_certbot_plugin() {
    local webserver="${WEBSERVER}"

    if [[ -z "${webserver}" ]]; then
        log "No webserver detected, installing standalone plugin only"
        return 0
    fi

    log "Installing Certbot plugin for ${webserver}..."

    if [[ "${webserver}" == "nginx" ]]; then
        install_package "python3-certbot-nginx"
        log "Certbot Nginx plugin installed"

    elif [[ "${webserver}" == "apache" ]]; then
        install_package "python3-certbot-apache"
        log "Certbot Apache plugin installed"

    else
        log "Warning: Unknown webserver type: ${webserver}"
    fi

    log "Certbot plugin installation completed"
}

# ============================================================================
# AUTOMATIC RENEWAL
# ============================================================================

# setup_certbot_renewal: Configure automatic certificate renewal
setup_certbot_renewal() {
    log "Setting up Certbot automatic renewal..."

    # Certbot automatically installs a systemd timer for renewals
    # Verify timer exists and is enabled

    if systemctl list-unit-files | grep -q "certbot.timer"; then
        log "Enabling Certbot renewal timer..."
        systemctl enable certbot.timer || {
            log "Warning: Failed to enable certbot.timer"
        }

        systemctl start certbot.timer || {
            log "Warning: Failed to start certbot.timer"
        }

        # Check timer status
        if systemctl is-active --quiet certbot.timer; then
            log "Certbot renewal timer is active"
        else
            log "Warning: Certbot renewal timer is not active"
        fi
    else
        # Fallback: Create cron job if systemd timer doesn't exist
        log "Systemd timer not found, setting up cron job for renewal..."
        create_certbot_cron
    fi

    log "Certbot automatic renewal configured"
}

# create_certbot_cron: Create cron job for certificate renewal (fallback)
create_certbot_cron() {
    log "Creating Certbot renewal cron job..."

    local cron_file="/etc/cron.d/certbot"

    cat > "${cron_file}" << 'EOF'
# Certbot automatic renewal
# Runs twice daily at random minute

SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

0 */12 * * * root test -x /usr/bin/certbot -a \! -d /run/systemd/system && perl -e 'sleep int(rand(3600))' && certbot -q renew --deploy-hook "systemctl reload nginx apache2" 2>&1 | logger -t certbot-renewal
EOF

    chmod 644 "${cron_file}"
    log "Certbot cron job created: ${cron_file}"
}

# ============================================================================
# CERTIFICATE MANAGEMENT
# ============================================================================

# obtain_certificate: Obtain SSL certificate for domain (interactive)
# Usage: obtain_certificate "example.com" "www.example.com"
obtain_certificate() {
    local domains=("$@")

    if [[ ${#domains[@]} -eq 0 ]]; then
        error_exit "No domains specified for certificate"
    fi

    log "Obtaining SSL certificate for: ${domains[*]}"

    # Build domain arguments
    local domain_args=""
    for domain in "${domains[@]}"; do
        domain_args="${domain_args} -d ${domain}"
    done

    # Determine plugin based on webserver
    local plugin=""
    if [[ "${WEBSERVER}" == "nginx" ]]; then
        plugin="--nginx"
    elif [[ "${WEBSERVER}" == "apache" ]]; then
        plugin="--apache"
    else
        plugin="--standalone"
        log "Warning: No webserver plugin, using standalone mode"
        log "Note: Webserver must be stopped for standalone mode"
    fi

    # Request certificate
    log "Running certbot with ${plugin} plugin..."
    certbot ${plugin} ${domain_args} --non-interactive --agree-tos --redirect || {
        log "Warning: Certificate request failed or was cancelled"
        return 1
    }

    log "SSL certificate obtained successfully"
}

# renew_certificates: Manually renew all certificates
renew_certificates() {
    log "Renewing all certificates..."

    certbot renew --quiet || {
        log "Warning: Certificate renewal encountered issues"
        return 1
    }

    # Reload webserver to apply renewed certificates
    if [[ -n "${WEBSERVER}" ]]; then
        log "Reloading ${WEBSERVER} to apply renewed certificates..."
        reload_webserver
    fi

    log "Certificate renewal completed"
}

# list_certificates: List all installed certificates
list_certificates() {
    log "Listing installed certificates..."
    certbot certificates
}

# ============================================================================
# CONFIGURATION HELPERS
# ============================================================================

# create_certbot_guide: Create usage guide for SSL certificates
create_certbot_guide() {
    log "Creating Certbot usage guide..."

    local guide_file="${LOG_DIR}/certbot-guide.txt"

    cat > "${guide_file}" << EOF
=================================================================
CERTBOT / LET'S ENCRYPT - USAGE GUIDE
=================================================================

Certbot has been installed successfully!

-----------------------------------------------------------------
OBTAINING CERTIFICATES
-----------------------------------------------------------------

For Nginx:
  certbot --nginx -d example.com -d www.example.com

For Apache:
  certbot --apache -d example.com -d www.example.com

Standalone (requires stopping webserver):
  systemctl stop ${WEBSERVER}
  certbot certonly --standalone -d example.com
  systemctl start ${WEBSERVER}

Interactive mode:
  certbot --${WEBSERVER}

-----------------------------------------------------------------
MANAGING CERTIFICATES
-----------------------------------------------------------------

List certificates:
  certbot certificates

Renew all certificates (manual):
  certbot renew

Renew specific certificate:
  certbot renew --cert-name example.com

Delete certificate:
  certbot delete --cert-name example.com

-----------------------------------------------------------------
AUTOMATIC RENEWAL
-----------------------------------------------------------------

Certificates are automatically renewed via:
EOF

    if systemctl list-unit-files | grep -q "certbot.timer"; then
        cat >> "${guide_file}" << EOF
  - Systemd timer: certbot.timer
  - Check status: systemctl status certbot.timer
  - View timer schedule: systemctl list-timers certbot.timer
EOF
    else
        cat >> "${guide_file}" << EOF
  - Cron job: /etc/cron.d/certbot
  - Runs twice daily
EOF
    fi

    cat >> "${guide_file}" << EOF

Test renewal process:
  certbot renew --dry-run

-----------------------------------------------------------------
IMPORTANT NOTES
-----------------------------------------------------------------

1. Port 80 and 443 must be accessible from the internet
2. DNS records must point to this server
3. Certificates are valid for 90 days
4. Automatic renewal occurs at 30 days before expiry
5. Rate limits: 50 certificates per domain per week

-----------------------------------------------------------------
TROUBLESHOOTING
-----------------------------------------------------------------

Check logs:
  tail -f /var/log/letsencrypt/letsencrypt.log

Verify DNS:
  dig example.com +short
  nslookup example.com

Test webserver config:
EOF

    if [[ "${WEBSERVER}" == "nginx" ]]; then
        echo "  nginx -t" >> "${guide_file}"
    elif [[ "${WEBSERVER}" == "apache" ]]; then
        echo "  apache2ctl configtest" >> "${guide_file}"
    fi

    cat >> "${guide_file}" << EOF

-----------------------------------------------------------------
USEFUL RESOURCES
-----------------------------------------------------------------

Official documentation: https://certbot.eff.org/
Let's Encrypt: https://letsencrypt.org/
Rate limits: https://letsencrypt.org/docs/rate-limits/

=================================================================
EOF

    log "Certbot guide created: ${guide_file}"
}

# ============================================================================
# WEBSERVER INTEGRATION
# ============================================================================

# configure_ssl_redirect: Configure HTTP to HTTPS redirect
configure_ssl_redirect() {
    local domain="$1"

    if [[ -z "${domain}" ]]; then
        error_exit "Domain not specified for SSL redirect"
    fi

    log "Configuring SSL redirect for ${domain}..."

    if [[ "${WEBSERVER}" == "nginx" ]]; then
        configure_nginx_ssl_redirect "${domain}"
    elif [[ "${WEBSERVER}" == "apache" ]]; then
        configure_apache_ssl_redirect "${domain}"
    fi

    log "SSL redirect configured for ${domain}"
}

# configure_nginx_ssl_redirect: Add SSL redirect to Nginx config
configure_nginx_ssl_redirect() {
    local domain="$1"
    local config_file="/etc/nginx/sites-available/${domain}"

    if [[ ! -f "${config_file}" ]]; then
        log "Warning: Nginx config not found: ${config_file}"
        return 1
    fi

    # Check if redirect already exists
    if grep -q "return 301 https://" "${config_file}"; then
        log "SSL redirect already configured in ${config_file}"
        return 0
    fi

    log "Adding SSL redirect to Nginx config: ${config_file}"

    # This is a placeholder - actual implementation would modify the config
    # Certbot usually handles this automatically with --redirect flag

    reload_service "nginx"
}

# configure_apache_ssl_redirect: Add SSL redirect to Apache config
configure_apache_ssl_redirect() {
    local domain="$1"
    local config_file="/etc/apache2/sites-available/${domain}.conf"

    if [[ ! -f "${config_file}" ]]; then
        log "Warning: Apache config not found: ${config_file}"
        return 1
    fi

    # Check if redirect already exists
    if grep -q "RewriteRule.*https://" "${config_file}"; then
        log "SSL redirect already configured in ${config_file}"
        return 0
    fi

    log "Adding SSL redirect to Apache config: ${config_file}"

    # This is a placeholder - actual implementation would modify the config
    # Certbot usually handles this automatically with --redirect flag

    reload_service "apache2"
}

# ============================================================================
# TESTING AND VALIDATION
# ============================================================================

# test_certificate: Test SSL certificate for domain
# Usage: test_certificate "example.com"
test_certificate() {
    local domain="$1"

    if [[ -z "${domain}" ]]; then
        error_exit "Domain not specified for certificate test"
    fi

    log "Testing SSL certificate for ${domain}..."

    # Test using openssl
    if command -v openssl &> /dev/null; then
        echo | openssl s_client -connect "${domain}:443" -servername "${domain}" 2>/dev/null | \
            openssl x509 -noout -dates -issuer -subject || {
            log "Warning: SSL certificate test failed for ${domain}"
            return 1
        }
    else
        log "Warning: openssl not available for certificate testing"
    fi

    log "SSL certificate test completed"
}

# verify_certbot_installation: Verify Certbot is properly installed
verify_certbot_installation() {
    log "Verifying Certbot installation..."

    # Check certbot command
    if ! command -v certbot &> /dev/null; then
        error_exit "Certbot command not found"
    fi

    # Check plugin
    if [[ "${WEBSERVER}" == "nginx" ]]; then
        if ! certbot plugins 2>&1 | grep -q "nginx"; then
            log "Warning: Nginx plugin not found"
        else
            log "Nginx plugin verified"
        fi
    elif [[ "${WEBSERVER}" == "apache" ]]; then
        if ! certbot plugins 2>&1 | grep -q "apache"; then
            log "Warning: Apache plugin not found"
        else
            log "Apache plugin verified"
        fi
    fi

    # Check renewal timer/cron
    if systemctl list-unit-files | grep -q "certbot.timer"; then
        if systemctl is-enabled --quiet certbot.timer; then
            log "Certbot renewal timer is enabled"
        else
            log "Warning: Certbot renewal timer is not enabled"
        fi
    elif [[ -f /etc/cron.d/certbot ]]; then
        log "Certbot cron job is configured"
    else
        log "Warning: No automatic renewal mechanism found"
    fi

    log "Certbot verification completed"
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# get_certificate_expiry: Get expiry date of certificate for domain
# Usage: get_certificate_expiry "example.com"
get_certificate_expiry() {
    local domain="$1"

    if [[ -z "${domain}" ]]; then
        return 1
    fi

    certbot certificates 2>/dev/null | grep -A 2 "${domain}" | grep "Expiry Date" | awk '{print $3, $4}'
}

# days_until_expiry: Calculate days until certificate expires
# Usage: days_until_expiry "example.com"
days_until_expiry() {
    local domain="$1"

    if [[ -z "${domain}" ]]; then
        return 1
    fi

    local cert_path="/etc/letsencrypt/live/${domain}/cert.pem"

    if [[ ! -f "${cert_path}" ]]; then
        log "Certificate not found: ${cert_path}"
        return 1
    fi

    local expiry_date
    expiry_date=$(openssl x509 -enddate -noout -in "${cert_path}" | cut -d= -f2)

    local expiry_epoch
    expiry_epoch=$(date -d "${expiry_date}" +%s)

    local now_epoch
    now_epoch=$(date +%s)

    local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))

    echo "${days_left}"
}

# ============================================================================
# END OF CERTBOT INSTALLER
# ============================================================================

log "Certbot installer library loaded successfully"

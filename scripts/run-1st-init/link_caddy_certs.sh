#!/bin/bash
set -e

MAILDOMAIN="whispr.dev"
CADDY_CERT_DIR="/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory"

echo "╔════════════════════════════════════════════════╗"
echo "║  Linking Caddy Certs to Mail Services         ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

# Find Caddy's cert directory for mail subdomain
if [ -d "$CADDY_CERT_DIR/mail.$MAILDOMAIN" ]; then
    CERT_DIR="$CADDY_CERT_DIR/mail.$MAILDOMAIN"
    echo "[✓] Found Caddy certs at: $CERT_DIR"
else
    echo "[❌] Caddy certs not found for mail.$MAILDOMAIN"
    echo "[ℹ️] Make sure you've added mail.$MAILDOMAIN to Caddyfile and reloaded Caddy"
    echo ""
    echo "Expected location: $CADDY_CERT_DIR/mail.$MAILDOMAIN"
    echo ""
    echo "Add this to Caddyfile:"
    echo ""
    echo "mail.$MAILDOMAIN {"
    echo "    tls youremail@example.com"
    echo "}"
    echo ""
    echo "Then run: sudo systemctl reload caddy"
    exit 1
fi

# Find the actual cert and key files
CERT_FILE=$(find "$CERT_DIR" -name "mail.$MAILDOMAIN.crt" | head -1)
KEY_FILE=$(find "$CERT_DIR" -name "mail.$MAILDOMAIN.key" | head -1)

if [ -z "$CERT_FILE" ] || [ -z "$KEY_FILE" ]; then
    echo "[❌] Could not find cert/key files in $CERT_DIR"
    ls -la "$CERT_DIR"
    exit 1
fi

echo "[✓] Found certificate: $CERT_FILE"
echo "[✓] Found private key: $KEY_FILE"
echo ""

# Configure Postfix to use Caddy's certs
echo "[🔧] Configuring Postfix..."
sudo postconf -e "smtpd_tls_cert_file=$CERT_FILE"
sudo postconf -e "smtpd_tls_key_file=$KEY_FILE"
sudo postconf -e "smtpd_tls_security_level=may"
sudo postconf -e "smtp_tls_security_level=may"

# Configure Dovecot to use Caddy's certs
echo "[🔧] Configuring Dovecot..."
sudo sed -i "s|^ssl_cert = <.*|ssl_cert = <$CERT_FILE|" /etc/dovecot/conf.d/10-ssl.conf
sudo sed -i "s|^ssl_key = <.*|ssl_key = <$KEY_FILE|" /etc/dovecot/conf.d/10-ssl.conf

# Set up automatic cert renewal hook
echo "[🔧] Setting up cert renewal hook..."
sudo mkdir -p /etc/caddy/renewal-hooks

# Create hook script that restarts mail services when certs renew
sudo tee /etc/caddy/renewal-hooks/restart-mail.sh > /dev/null << 'HOOK'
#!/bin/bash
# Restart mail services after Caddy renews certs
systemctl restart postfix dovecot
logger "Restarted mail services after Caddy cert renewal"
HOOK

sudo chmod +x /etc/caddy/renewal-hooks/restart-mail.sh

# Restart services to apply new certs
echo "[🔄] Restarting mail services..."
sudo systemctl restart postfix dovecot

echo ""
echo "[✅] Caddy certs linked successfully!"
echo ""
echo "[🔐] Verify TLS is working:"
echo "   openssl s_client -connect mail.$MAILDOMAIN:993 -starttls imap"
echo "   openssl s_client -connect mail.$MAILDOMAIN:587 -starttls smtp"
echo ""
echo "[📋] Cert details:"
openssl x509 -in "$CERT_FILE" -noout -subject -dates 2>/dev/null || echo "   (unable to parse cert)"
echo ""

#!/bin/bash
set -e

echo "[✓] Installing Postfix + Dovecot (CADDY-COMPATIBLE VERSION)..."
echo "[ℹ️] This version integrates with existing Caddy setup"
echo ""

# Update system
sudo apt update && sudo apt upgrade -y

# ═══════════════════════════════════════════════
# PRE-SEED POSTFIX CONFIG (prevents pink dialogs)
# ═══════════════════════════════════════════════
echo "[🔧] Pre-configuring Postfix to avoid prompts..."
echo "postfix postfix/main_mailer_type select Internet Site" | sudo debconf-set-selections
echo "postfix postfix/mailname string whispr.dev" | sudo debconf-set-selections

# Install mail stack NON-INTERACTIVELY (NO certbot, we'll use Caddy's certs)
echo "[📦] Installing packages (no prompts, no certbot)..."
export DEBIAN_FRONTEND=noninteractive
sudo -E apt install -y \
    postfix \
    dovecot-core \
    dovecot-imapd \
    dovecot-pop3d \
    dovecot-lmtpd \
    dovecot-sieve \
    dovecot-managesieved \
    mailutils

echo "[✓] Configuring Postfix..."
# Set domain and hostname
MAILDOMAIN="whispr.dev"
MAILUSER="tom"

# Postfix main.cf (basic setup)
sudo postconf -e "myhostname=mail.$MAILDOMAIN"
sudo postconf -e "myorigin=/etc/mailname"
sudo postconf -e "mydestination=$MAILDOMAIN,localhost"
sudo postconf -e "relayhost="
sudo postconf -e "mynetworks=127.0.0.0/8"
sudo postconf -e "mailbox_size_limit=0"
sudo postconf -e "recipient_delimiter=+"
sudo postconf -e "inet_interfaces=all"
sudo postconf -e "inet_protocols=all"
sudo postconf -e "home_mailbox=Maildir/"

# TLS/SSL configuration (using Caddy's certs)
# We'll configure these AFTER Caddy generates the certs
sudo postconf -e "smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem"
sudo postconf -e "smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key"
sudo postconf -e "smtpd_tls_security_level=may"
sudo postconf -e "smtp_tls_security_level=may"
sudo postconf -e "smtpd_tls_protocols=!SSLv2,!SSLv3,!TLSv1,!TLSv1.1"
sudo postconf -e "smtp_tls_protocols=!SSLv2,!SSLv3,!TLSv1,!TLSv1.1"

# Write domain to /etc/mailname
echo "$MAILDOMAIN" | sudo tee /etc/mailname > /dev/null

echo "[✓] Configuring Dovecot..."

# Enable maildir
sudo sed -i 's|^#mail_location =.*|mail_location = maildir:~/Maildir|' /etc/dovecot/conf.d/10-mail.conf

# SSL configuration (using Caddy's certs - we'll update this)
sudo sed -i 's|^#ssl = yes|ssl = yes|' /etc/dovecot/conf.d/10-ssl.conf
sudo sed -i 's|^ssl_cert = <.*|ssl_cert = </etc/ssl/certs/ssl-cert-snakeoil.pem|' /etc/dovecot/conf.d/10-ssl.conf
sudo sed -i 's|^ssl_key = <.*|ssl_key = </etc/ssl/private/ssl-cert-snakeoil.key|' /etc/dovecot/conf.d/10-ssl.conf

# Authentication settings
sudo sed -i 's|^#disable_plaintext_auth = yes|disable_plaintext_auth = no|' /etc/dovecot/conf.d/10-auth.conf
sudo sed -i 's|^auth_mechanisms =.*|auth_mechanisms = plain login|' /etc/dovecot/conf.d/10-auth.conf

# Enable PAM auth and add passwdfile include
sudo sed -i 's|^#!include auth-system.conf.ext|!include auth-system.conf.ext|' /etc/dovecot/conf.d/10-auth.conf
echo '!include auth-passwdfile.conf.ext' | sudo tee -a /etc/dovecot/conf.d/10-auth.conf > /dev/null

# Create mail user
echo "[✓] Adding mail user..."
sudo useradd $MAILUSER -m -s /sbin/nologin 2>/dev/null || echo "User $MAILUSER already exists"

# Set password for the mail user
echo "$MAILUSER:changeme" | sudo chpasswd

# Create Maildir for the user
sudo mkdir -p /home/$MAILUSER/Maildir/{cur,new,tmp}
sudo chown -R $MAILUSER:$MAILUSER /home/$MAILUSER/Maildir

# Create password file for dovecot
echo "$MAILUSER:{PLAIN}devnull0" | sudo tee /etc/dovecot/users > /dev/null
sudo chmod 640 /etc/dovecot/users
sudo chown root:dovecot /etc/dovecot/users

# Dovecot password file config
sudo tee /etc/dovecot/conf.d/auth-passwdfile.conf.ext > /dev/null << 'EOF'
passdb {
  driver = passwd-file
  args = scheme=PLAIN username_format=%u /etc/dovecot/users
}
userdb {
  driver = passwd
}
EOF

# Enable and restart services
echo "[🔄] Restarting services..."
sudo systemctl restart postfix dovecot
sudo systemctl enable postfix dovecot

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ✅ MAIL SERVER BASE INSTALL COMPLETE                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "[📧] IMAP ready at mail.$MAILDOMAIN for user $MAILUSER"
echo ""
echo "[🔐] NEXT STEPS (Caddy Integration):"
echo ""
echo "1️⃣  Add to your Caddyfile:"
echo ""
echo "mail.$MAILDOMAIN {"
echo "    # Caddy will auto-generate certs for this domain"
echo "    tls {your-email@example.com}"
echo "}"
echo ""
echo "2️⃣  Reload Caddy to generate certs:"
echo "   sudo systemctl reload caddy"
echo ""
echo "3️⃣  Link Caddy's certs to mail services:"
echo "   sudo ./link_caddy_certs.sh"
echo ""
echo "4️⃣  Configure SPF/DKIM/DMARC from 2ndry.md"
echo ""
echo "5️⃣  Test with: telnet localhost 25"
echo ""

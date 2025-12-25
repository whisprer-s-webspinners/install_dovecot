#!/bin/bash
set -e

echo "[🔥] woflOS Mail Server Cleanup Script"
echo "[⚠️] This will DESTROY all mail server configs and data!"
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "[❌] Aborted."
    exit 0
fi

MAILDOMAIN="whispr.dev"
MAILUSER="tom"

echo "[🛑] Stopping services..."
sudo systemctl stop postfix dovecot opendkim 2>/dev/null || true
sudo systemctl disable postfix dovecot opendkim 2>/dev/null || true

# ============================================
# PHASE 1: Reverse 2ndry.md (DKIM + Forwarding)
# ============================================

echo "[🧹] Removing DKIM integration from Postfix..."
if [ -f /etc/postfix/main.cf ]; then
    # Remove OpenDKIM milter lines
    sudo sed -i '/^milter_protocol/d' /etc/postfix/main.cf
    sudo sed -i '/^milter_default_action/d' /etc/postfix/main.cf
    sudo sed -i '/^smtpd_milters/d' /etc/postfix/main.cf
    sudo sed -i '/^non_smtpd_milters/d' /etc/postfix/main.cf
    
    # Remove virtual alias configuration
    sudo sed -i '/^virtual_alias_domains/d' /etc/postfix/main.cf
    sudo sed -i '/^virtual_alias_maps/d' /etc/postfix/main.cf
fi

echo "[🧹] Removing virtual alias maps..."
sudo rm -f /etc/postfix/virtual /etc/postfix/virtual.db

echo "[🧹] Removing OpenDKIM configuration..."
sudo rm -rf /etc/opendkim/
sudo rm -f /etc/default/opendkim

echo "[🧹] Purging OpenDKIM packages..."
sudo apt purge -y opendkim opendkim-tools 2>/dev/null || true
sudo apt autoremove -y

# ============================================
# PHASE 2: Reverse install_mailserver.sh
# ============================================

echo "[🧹] Removing Dovecot password file..."
sudo rm -f /etc/dovecot/users
sudo rm -f /etc/dovecot/conf.d/auth-passwdfile.conf.ext

echo "[🧹] Restoring Dovecot default configs..."
# Revert mail location
if [ -f /etc/dovecot/conf.d/10-mail.conf ]; then
    sudo sed -i 's|^mail_location = maildir|#mail_location =|' /etc/dovecot/conf.d/10-mail.conf
fi

# Revert authentication
if [ -f /etc/dovecot/conf.d/10-auth.conf ]; then
    sudo sed -i 's|^disable_plaintext_auth = no|#disable_plaintext_auth = yes|' /etc/dovecot/conf.d/10-auth.conf
    sudo sed -i 's|^auth_mechanisms = plain login|auth_mechanisms = plain|' /etc/dovecot/conf.d/10-auth.conf
    sudo sed -i 's|^!include auth-system.conf.ext|#!include auth-system.conf.ext|' /etc/dovecot/conf.d/10-auth.conf
    sudo sed -i '/^!include auth-passwdfile.conf.ext/d' /etc/dovecot/conf.d/10-auth.conf
fi

echo "[🧹] Removing mail user and Maildir..."
if id "$MAILUSER" &>/dev/null; then
    sudo userdel -r "$MAILUSER" 2>/dev/null || true
fi
sudo rm -rf /home/$MAILUSER

echo "[🧹] Clearing Postfix configuration..."
if [ -f /etc/postfix/main.cf ]; then
    # Reset to defaults or remove custom settings
    sudo postconf -e "myhostname=$(hostname)"
    sudo postconf -e "mydestination=\$myhostname, localhost.\$mydomain, localhost"
    sudo postconf -e "relayhost="
    sudo postconf -e "mynetworks=127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128"
    sudo postconf -e "mailbox_size_limit=51200000"
    sudo postconf -e "recipient_delimiter=+"
    sudo postconf -e "inet_interfaces=loopback-only"
    sudo postconf -e "inet_protocols=all"
    sudo postconf -e "home_mailbox="
fi

echo "[🧹] Removing /etc/mailname..."
sudo rm -f /etc/mailname

echo "[🧹] Cleaning mail spool and logs..."
sudo rm -rf /var/mail/*
sudo rm -rf /var/spool/mail/*
sudo rm -rf /var/log/mail.*

# ============================================
# OPTIONAL: Full package purge
# ============================================

read -p "[⚠️] Purge ALL mail packages? (yes/no): " PURGE_ALL

if [ "$PURGE_ALL" = "yes" ]; then
    echo "[🔥] Purging Postfix, Dovecot, Certbot..."
    sudo apt purge -y postfix dovecot-core dovecot-imapd dovecot-pop3d \
        dovecot-lmtpd dovecot-sieve dovecot-managesieved \
        mailutils certbot 2>/dev/null || true
    
    sudo apt autoremove -y
    sudo apt autoclean
    
    echo "[🧹] Removing leftover config directories..."
    sudo rm -rf /etc/postfix /etc/dovecot /etc/letsencrypt
else
    echo "[⏭️] Skipping package removal (configs cleared, services stopped)"
fi

echo ""
echo "[✅] Cleanup complete!"
echo "[ℹ️] Services stopped and disabled"
echo "[ℹ️] Configs reset/removed"
echo "[ℹ️] Mail user '$MAILUSER' deleted"
echo ""
echo "[🔄] Ready for fresh install!"
#!/bin/bash

set -e

echo "[✓] woflOS Mail Server Installation Script"
echo ""

# Prompt for domain and user
read -p "Enter your mail domain (e.g., whispr.dev): " MAILDOMAIN
read -p "Enter the mail username (e.g., tom): " MAILUSER

echo ""
echo "[📋] Configuration:"
echo "    Domain: $MAILDOMAIN"
echo "    User: $MAILUSER"
echo "    Email: $MAILUSER@$MAILDOMAIN"
echo ""
read -p "Continue with this configuration? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "[❌] Installation aborted."
    exit 0
fi

echo "[✓] Installing Postfix + Dovecot..."

# Update system
sudo apt update && sudo apt upgrade -y

# Install mail stack
sudo apt install -y postfix dovecot-core dovecot-imapd dovecot-pop3d dovecot-lmtpd dovecot-sieve dovecot-managesieved mailutils certbot

echo "[✓] Configuring Postfix..."

# Postfix main.cf (basic setup)
postconf -e "myhostname=mail.$MAILDOMAIN"
postconf -e "myorigin=/etc/mailname"
postconf -e "mydestination=$MAILDOMAIN,localhost"
postconf -e "relayhost="
postconf -e "mynetworks=127.0.0.0/8"
postconf -e "mailbox_size_limit=0"
postconf -e "recipient_delimiter=+"
postconf -e "inet_interfaces=all"
postconf -e "inet_protocols=all"
postconf -e "home_mailbox=Maildir/"

# Write domain to /etc/mailname
echo "$MAILDOMAIN" | sudo tee /etc/mailname > /dev/null

echo "[✓] Configuring Dovecot..."

# Enable maildir
sudo sed -i 's|^#mail_location =.*|mail_location = maildir|' /etc/dovecot/conf.d/10-mail.conf

# Authentication settings
sudo sed -i 's|^#disable_plaintext_auth = yes|disable_plaintext_auth = no|' /etc/dovecot/conf.d/10-auth.conf
sudo sed -i 's|^auth_mechanisms =.*|auth_mechanisms = plain login|' /etc/dovecot/conf.d/10-auth.conf

# Enable PAM auth and add passwdfile include
sudo sed -i 's|^#!include auth-system.conf.ext|!include auth-system.conf.ext|' /etc/dovecot/conf.d/10-auth.conf
echo '!include auth-passwdfile.conf.ext' | sudo tee -a /etc/dovecot/conf.d/10-auth.conf > /dev/null

# Create mail user
echo "[✓] Adding mail user..."
sudo useradd $MAILUSER -m -s /sbin/nologin

# Set password for the mail user
echo "$MAILUSER:changeme" | sudo chpasswd

# Create Maildir for the user
sudo mkdir -p /home/$MAILUSER/Maildir
sudo chown -R $MAILUSER:$MAILUSER /home/$MAILUSER/Maildir

# Create password file for dovecot
echo "$MAILUSER:{PLAIN}devnull0" | sudo tee /etc/dovecot/users > /dev/null
sudo chmod 640 /etc/dovecot/users
sudo chown root:dovecot /etc/dovecot/users

# Dovecot password file config
sudo cat << EOF > /etc/dovecot/conf.d/auth-passwdfile.conf.ext
passdb {
  driver = passwd-file
  args = scheme=PLAIN /etc/dovecot/users
}

userdb {
  driver = passwd
}
EOF

# Enable and restart services
sudo systemctl restart postfix dovecot
sudo systemctl enable postfix dovecot

echo ""
echo "[✓] Mail server setup complete!"
echo ""
echo "[📧] Email address: $MAILUSER@$MAILDOMAIN"
echo "[🔐] Default password: changeme (change with: sudo passwd $MAILUSER)"
echo "[🔐] IMAP password: devnull0 (edit /etc/dovecot/users to change)"
echo ""
echo "[🔒] Next step: Obtain SSL certificate"
echo "Run: sudo certbot certonly --standalone -d mail.$MAILDOMAIN"
echo ""
echo "[✅] IMAP ready at mail.$MAILDOMAIN for user $MAILUSER"

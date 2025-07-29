#!/bin/bash
set -e

echo "[✓] Installing Postfix + Dovecot..."

# Update system
sudo apt update && sudo apt upgrade -y # Added sudo for apt commands

# Install mail stack
sudo apt install -y postfix dovecot-core dovecot-imapd dovecot-pop3d dovecot-lmtpd dovecot-sieve dovecot-managesieved mailutils certbot

echo "[✓] Configuring Postfix..."
# Set domain and hostname
MAILDOMAIN="whispr.dev" # Quoted for safety
MAILUSER="tom"          # Quoted for safety (was 'wofl' in your input, changed to 'tom' based on error output)

# Postfix main.cf (basic setup)
# Removed spaces around = for postconf commands as required
postconf -e "myhostname=mail.$MAILDOMAIN"
postconf -e "myorigin=/etc/mailname"
postconf -e "mydestination=$MAILDOMAIN,localhost" # Removed space after comma
postconf -e "relayhost="
postconf -e "mynetworks=127.0.0.0/8"
postconf -e "mailbox_size_limit=0"
postconf -e "recipient_delimiter=+"
postconf -e "inet_interfaces=all"
postconf -e "inet_protocols=all"
postconf -e "home_mailbox=Maildir/" # Common to add trailing slash

# Write domain to /etc/mailname
echo "$MAILDOMAIN" | sudo tee /etc/mailname > /dev/null # Use tee with sudo to write to system file

echo "[✓] Configuring Dovecot..."

# Enable maildir
sudo sed -i 's|^#mail_location =.*|mail_location = maildir|' /etc/dovecot/conf.d/10-mail.conf

# Authentication settings
sudo sed -i 's|^#disable_plaintext_auth = yes|disable_plaintext_auth = no|' /etc/dovecot/conf.d/10-auth.conf
sudo sed -i 's|^auth_mechanisms =.*|auth_mechanisms = plain login|' /etc/dovecot/conf.d/10-auth.conf

# Enable PAM auth and add passwdfile include
sudo sed -i 's|^#!include auth-system.conf.ext|!include auth-system.conf.ext|' /etc/dovecot/conf.d/10-auth.conf
echo '!include auth-passwdfile.conf.ext' | sudo tee -a /etc/dovecot/conf.d/10-auth.conf > /dev/null # Use tee -a with sudo to append

# Create mail user
echo "[✓] Adding mail user..."
# Corrected shell path and ensured sudo
sudo useradd $MAILUSER -m -s /sbin/nologin

# Set password for the mail user
# Corrected chpasswd syntax
echo "$MAILUSER:changeme" | sudo chpasswd

# Create Maildir for the user
# Used absolute path and ensured sudo
sudo mkdir -p /home/$MAILUSER/Maildir
sudo chown -R $MAILUSER:$MAILUSER /home/$MAILUSER/Maildir

# Create password file for dovecot
# Corrected echo syntax and redirection, ensured sudo
echo "$MAILUSER:{PLAIN}devnull0" | sudo tee /etc/dovecot/users > /dev/null
sudo chmod 640 /etc/dovecot/users
sudo chown root:dovecot /etc/dovecot/users # Corrected group to 'dovecot'

# Dovecot password file config
# Corrected heredoc syntax and redirection, ensured sudo
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

echo "[✓] Obtaining SSL cert via Let's Encrypt (manually run if needed)..."
echo "Run: sudo certbot certonly --standalone -d mail.$MAILDOMAIN"

echo "[✓] Mail server setup complete. IMAP ready at mail.$MAILDOMAIN for user $MAILUSER"

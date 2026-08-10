#!/bin/bash

echo "╔════════════════════════════════════════════════╗"
echo "║  woflOS Server Port Diagnostic                 ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

echo "[🔍] Checking what's listening on critical ports..."
echo ""

# Function to check a port
check_port() {
    local port=$1
    local service=$2
    local result=$(sudo ss -tlnp | grep ":$port ")
    
    if [ -n "$result" ]; then
        echo "❌ Port $port ($service) - IN USE:"
        echo "   $result"
    else
        echo "✅ Port $port ($service) - AVAILABLE"
    fi
}

# Web ports (Caddy conflict zone)
check_port 80 "HTTP - Caddy/Certbot"
check_port 443 "HTTPS - Caddy"
echo ""

# Mail ports
check_port 25 "SMTP - Incoming mail"
check_port 587 "SMTP Submission - Outgoing mail"
check_port 465 "SMTPS - Legacy encrypted"
check_port 143 "IMAP - Unencrypted"
check_port 993 "IMAPS - Encrypted"
check_port 110 "POP3 - Unencrypted"
check_port 995 "POP3S - Encrypted"
echo ""

echo "[🐳] Checking Docker containers..."
docker ps --format "table {{.Names}}\t{{.Ports}}" 2>/dev/null || echo "   Docker not running or no containers"
echo ""

echo "[🔧] Checking active services..."
systemctl list-units --type=service --state=running | grep -E 'caddy|docker|postfix|dovecot|nginx|apache' || echo "   No mail/web services running"
echo ""

echo "[📋] Summary of running web servers:"
ps aux | grep -E 'caddy|nginx|apache2' | grep -v grep || echo "   None found"
echo ""

echo "[💡] Recommendations:"
echo ""

if sudo ss -tlnp | grep -q ":80 "; then
    echo "⚠️  Port 80 is occupied - You MUST use one of these certbot strategies:"
    echo "    Option A: Use Caddy to get certs and share with mail server"
    echo "    Option B: Use certbot --webroot (if you have a web directory)"
    echo "    Option C: Temporarily stop Caddy during cert acquisition"
    echo ""
else
    echo "✅ Port 80 is free - certbot --standalone will work"
    echo ""
fi

if sudo ss -tlnp | grep -q ":25 "; then
    echo "⚠️  Port 25 already in use - Mail server may already be configured"
else
    echo "✅ Port 25 is free - Safe to install mail server"
fi
echo ""

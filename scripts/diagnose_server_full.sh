#!/bin/bash

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  woflOS Server Setup Diagnostic - Full Scan                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Color codes for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ═══════════════════════════════════════════════
# SECTION 1: Docker Status
# ═══════════════════════════════════════════════
echo "[1] 🐳 DOCKER STATUS"
echo "────────────────────────────────────────────"

if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker is installed"
    docker --version
    echo ""
    
    echo "   Running containers:"
    if [ "$(docker ps -q | wc -l)" -gt 0 ]; then
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        echo -e "   ${YELLOW}No containers running${NC}"
    fi
    echo ""
    
    echo "   All containers (including stopped):"
    if [ "$(docker ps -aq | wc -l)" -gt 0 ]; then
        docker ps -a --format "table {{.Names}}\t{{.Status}}"
    else
        echo -e "   ${YELLOW}No containers exist${NC}"
    fi
    echo ""
    
    echo "   Docker Compose:"
    if command -v docker-compose &> /dev/null; then
        echo -e "   ${GREEN}✓${NC} docker-compose installed"
        docker-compose --version
    else
        echo -e "   ${RED}✗${NC} docker-compose NOT installed"
    fi
else
    echo -e "${RED}✗${NC} Docker is NOT installed"
fi
echo ""

# ═══════════════════════════════════════════════
# SECTION 2: Caddy Status
# ═══════════════════════════════════════════════
echo "[2] 🌐 CADDY STATUS"
echo "────────────────────────────────────────────"

if command -v caddy &> /dev/null; then
    echo -e "${GREEN}✓${NC} Caddy is installed"
    caddy version
    echo ""
    
    if systemctl is-active --quiet caddy; then
        echo -e "   ${GREEN}✓${NC} Caddy service is RUNNING"
        systemctl status caddy --no-pager | head -5
    else
        echo -e "   ${RED}✗${NC} Caddy service is STOPPED"
    fi
    echo ""
    
    echo "   Caddyfile location:"
    if [ -f /etc/caddy/Caddyfile ]; then
        echo "   ✓ /etc/caddy/Caddyfile exists"
        echo "   First 20 lines:"
        head -20 /etc/caddy/Caddyfile | sed 's/^/      /'
    else
        echo -e "   ${YELLOW}No Caddyfile at /etc/caddy/Caddyfile${NC}"
    fi
    echo ""
    
    echo "   Caddy certificates:"
    if [ -d /var/lib/caddy/.local/share/caddy/certificates ]; then
        echo "   Cert directory exists, domains:"
        find /var/lib/caddy/.local/share/caddy/certificates -type d -name "*.dev" -o -name "*.com" | sed 's/^/      /'
    else
        echo -e "   ${YELLOW}No certs directory${NC}"
    fi
else
    echo -e "${RED}✗${NC} Caddy is NOT installed"
    
    # Check if Caddy might be running in Docker
    if command -v docker &> /dev/null; then
        if docker ps | grep -q caddy; then
            echo -e "   ${YELLOW}⚠${NC}  But Caddy IS running in Docker!"
            docker ps | grep caddy
        fi
    fi
fi
echo ""

# ═══════════════════════════════════════════════
# SECTION 3: Web Servers
# ═══════════════════════════════════════════════
echo "[3] 🖥️  OTHER WEB SERVERS"
echo "────────────────────────────────────────────"

# Check for Nginx
if command -v nginx &> /dev/null; then
    echo -e "${GREEN}✓${NC} Nginx is installed"
    nginx -v
    if systemctl is-active --quiet nginx; then
        echo "   Status: RUNNING"
    else
        echo "   Status: STOPPED"
    fi
else
    echo "✗ Nginx not installed"
fi
echo ""

# Check for Apache
if command -v apache2 &> /dev/null || command -v httpd &> /dev/null; then
    echo -e "${GREEN}✓${NC} Apache is installed"
    apache2 -v 2>/dev/null || httpd -v
    if systemctl is-active --quiet apache2 || systemctl is-active --quiet httpd; then
        echo "   Status: RUNNING"
    else
        echo "   Status: STOPPED"
    fi
else
    echo "✗ Apache not installed"
fi
echo ""

# ═══════════════════════════════════════════════
# SECTION 4: Port Usage
# ═══════════════════════════════════════════════
echo "[4] 🔌 PORT USAGE (Critical Ports)"
echo "────────────────────────────────────────────"

check_port() {
    local port=$1
    local service=$2
    local result=$(sudo ss -tlnp 2>/dev/null | grep ":$port " || echo "")
    
    if [ -n "$result" ]; then
        echo -e "${YELLOW}❌ Port $port ($service)${NC} - IN USE:"
        echo "$result" | sed 's/^/   /'
    else
        echo -e "${GREEN}✅ Port $port ($service)${NC} - AVAILABLE"
    fi
}

check_port 80 "HTTP"
check_port 443 "HTTPS"
check_port 25 "SMTP"
check_port 587 "SMTP-Submission"
check_port 993 "IMAPS"
echo ""

# ═══════════════════════════════════════════════
# SECTION 5: Directory Structure
# ═══════════════════════════════════════════════
echo "[5] 📁 DIRECTORY STRUCTURE"
echo "────────────────────────────────────────────"

# Check common Docker compose locations
echo "Checking common docker-compose locations:"
locations=(
    "/root/n8n-docker-caddy"
    "/home/*/n8n-docker-caddy"
    "/opt/n8n-docker-caddy"
    "/srv/n8n-docker-caddy"
    "/var/www"
    "/opt/docker"
    "/root/docker"
)

found=0
for loc in "${locations[@]}"; do
    if [ -d "$loc" ] 2>/dev/null || ls -d $loc 2>/dev/null; then
        echo -e "   ${GREEN}✓${NC} Found: $loc"
        found=1
    fi
done

if [ $found -eq 0 ]; then
    echo -e "   ${YELLOW}No standard docker-compose directories found${NC}"
fi
echo ""

# Look for docker-compose.yml files anywhere
echo "Searching for docker-compose.yml files..."
compose_files=$(sudo find /home /root /opt /srv -name "docker-compose.yml" 2>/dev/null | head -10)
if [ -n "$compose_files" ]; then
    echo "$compose_files" | sed 's/^/   /'
else
    echo -e "   ${YELLOW}No docker-compose.yml files found${NC}"
fi
echo ""

# ═══════════════════════════════════════════════
# SECTION 6: Mail Server Status
# ═══════════════════════════════════════════════
echo "[6] 📧 MAIL SERVER STATUS"
echo "────────────────────────────────────────────"

# Check Postfix
if command -v postfix &> /dev/null; then
    echo -e "${GREEN}✓${NC} Postfix is installed"
    if systemctl is-active --quiet postfix; then
        echo "   Status: RUNNING"
    else
        echo "   Status: STOPPED"
    fi
else
    echo "✗ Postfix not installed"
fi
echo ""

# Check Dovecot
if command -v doveadm &> /dev/null; then
    echo -e "${GREEN}✓${NC} Dovecot is installed"
    if systemctl is-active --quiet dovecot; then
        echo "   Status: RUNNING"
    else
        echo "   Status: STOPPED"
    fi
else
    echo "✗ Dovecot not installed"
fi
echo ""

# ═══════════════════════════════════════════════
# SECTION 7: System Info
# ═══════════════════════════════════════════════
echo "[7] 💻 SYSTEM INFO"
echo "────────────────────────────────────────────"
echo "Hostname: $(hostname)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d '"' -f 2)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo "Public IP: $(curl -s ifconfig.me || echo "Unable to detect")"
echo ""

# ═══════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  SUMMARY & RECOMMENDATIONS                                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Determine server state
if command -v docker &> /dev/null && command -v caddy &> /dev/null; then
    echo "🎯 Server Type: DOCKER + CADDY (Configured)"
    echo "   → Use: install_mailserver_caddy.sh"
    echo "   → Strategy: Let Caddy manage certs, mail services borrow them"
elif command -v caddy &> /dev/null; then
    echo "🎯 Server Type: CADDY ONLY (No Docker)"
    echo "   → Use: install_mailserver_caddy.sh"
    echo "   → Strategy: Let Caddy manage certs, mail services borrow them"
elif command -v docker &> /dev/null; then
    echo "🎯 Server Type: DOCKER ONLY (No Caddy)"
    echo "   → Use: install_mailserver_fixed.sh (with certbot)"
    echo "   → Strategy: Certbot can use --standalone safely"
elif sudo ss -tlnp 2>/dev/null | grep -q ":80 "; then
    echo "🎯 Server Type: SOMETHING ELSE on Port 80"
    echo "   → Check what's using port 80 above"
    echo "   → May need custom solution"
else
    echo "🎯 Server Type: VANILLA/FRESH"
    echo "   → Use: install_mailserver_fixed.sh (with certbot)"
    echo "   → Strategy: Nothing blocking port 80, certbot --standalone is safe"
fi
echo ""

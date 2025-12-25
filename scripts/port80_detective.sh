#!/bin/bash

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  🔍 Port 80 Detective - Who's Squatting on Your Port?        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

# ═══════════════════════════════════════════════
# PHASE 1: What's on Port 80?
# ═══════════════════════════════════════════════
echo -e "${BLUE}[PHASE 1]${NC} Checking Port 80 Status..."
echo "──────────────────────────────────────────"

PORT80=$(sudo ss -tlnp | grep ':80 ')

if [ -z "$PORT80" ]; then
    echo -e "${GREEN}✓ Port 80 is FREE!${NC}"
    echo "Nothing to investigate - you're good to go!"
    exit 0
fi

echo -e "${YELLOW}❌ Port 80 is OCCUPIED!${NC}"
echo "$PORT80"
echo ""

# Extract PID from ss output
# Format: users:(("nginx",pid=1234,fd=6))
PID=$(echo "$PORT80" | grep -oP 'pid=\K[0-9]+' | head -1)

if [ -z "$PID" ]; then
    echo -e "${RED}Could not extract PID. Raw output above.${NC}"
    exit 1
fi

echo -e "${BLUE}Process ID (PID):${NC} $PID"
echo ""

# ═══════════════════════════════════════════════
# PHASE 2: Who is this process?
# ═══════════════════════════════════════════════
echo -e "${BLUE}[PHASE 2]${NC} Identifying the Culprit..."
echo "──────────────────────────────────────────"

# Get process name
PROC_NAME=$(ps -p $PID -o comm= 2>/dev/null)
echo -e "${BLUE}Process Name:${NC} $PROC_NAME"

# Get full command line
PROC_CMD=$(ps -p $PID -o args= 2>/dev/null)
echo -e "${BLUE}Full Command:${NC} $PROC_CMD"

# Get user running it
PROC_USER=$(ps -p $PID -o user= 2>/dev/null)
echo -e "${BLUE}Running as:${NC} $PROC_USER"

# Get when it started
PROC_START=$(ps -p $PID -o lstart= 2>/dev/null)
echo -e "${BLUE}Started:${NC} $PROC_START"

# Get memory usage
PROC_MEM=$(ps -p $PID -o rss= 2>/dev/null)
PROC_MEM_MB=$((PROC_MEM / 1024))
echo -e "${BLUE}Memory:${NC} ${PROC_MEM_MB}MB"

echo ""

# ═══════════════════════════════════════════════
# PHASE 3: Is it a systemd service?
# ═══════════════════════════════════════════════
echo -e "${BLUE}[PHASE 3]${NC} Checking if it's a Service..."
echo "──────────────────────────────────────────"

# Check if it's managed by systemd
SERVICE_NAME=$(systemctl status $PID 2>/dev/null | grep 'Loaded:' | grep -oP '(?<=\().+?(?=;)')

if [ -n "$SERVICE_NAME" ]; then
    echo -e "${GREEN}✓ This is a systemd service!${NC}"
    echo -e "${BLUE}Service Name:${NC} $SERVICE_NAME"
    echo ""
    systemctl status "$SERVICE_NAME" --no-pager | head -10
else
    echo -e "${YELLOW}⚠ Not a systemd service (standalone process)${NC}"
fi
echo ""

# ═══════════════════════════════════════════════
# PHASE 4: What binary is running?
# ═══════════════════════════════════════════════
echo -e "${BLUE}[PHASE 4]${NC} Binary Location..."
echo "──────────────────────────────────────────"

# Get the actual binary path
BINARY=$(readlink -f /proc/$PID/exe 2>/dev/null)
if [ -n "$BINARY" ]; then
    echo -e "${BLUE}Binary:${NC} $BINARY"
    
    # Check what package it belongs to
    if command -v dpkg &> /dev/null; then
        PACKAGE=$(dpkg -S "$BINARY" 2>/dev/null | cut -d: -f1)
        if [ -n "$PACKAGE" ]; then
            echo -e "${BLUE}Package:${NC} $PACKAGE"
        fi
    fi
else
    echo -e "${YELLOW}Could not determine binary${NC}"
fi
echo ""

# ═══════════════════════════════════════════════
# PHASE 5: What config files?
# ═══════════════════════════════════════════════
echo -e "${BLUE}[PHASE 5]${NC} Configuration Files..."
echo "──────────────────────────────────────────"

# Check for common config locations based on process name
case "$PROC_NAME" in
    nginx)
        echo "Nginx detected!"
        if [ -f /etc/nginx/nginx.conf ]; then
            echo "  Config: /etc/nginx/nginx.conf"
            echo "  Sites enabled:"
            ls -la /etc/nginx/sites-enabled/ 2>/dev/null | grep -v '^total' | sed 's/^/    /'
        fi
        ;;
    apache2|httpd)
        echo "Apache detected!"
        if [ -f /etc/apache2/apache2.conf ]; then
            echo "  Config: /etc/apache2/apache2.conf"
            echo "  Sites enabled:"
            ls -la /etc/apache2/sites-enabled/ 2>/dev/null | grep -v '^total' | sed 's/^/    /'
        elif [ -f /etc/httpd/conf/httpd.conf ]; then
            echo "  Config: /etc/httpd/conf/httpd.conf"
        fi
        ;;
    lighttpd)
        echo "Lighttpd detected!"
        echo "  Config: /etc/lighttpd/lighttpd.conf"
        ;;
    *)
        echo "  Unknown web server type"
        # Try to find open config files
        echo "  Open files:"
        sudo lsof -p $PID 2>/dev/null | grep -E '\.(conf|cfg|yaml|yml|json)' | sed 's/^/    /' | head -5
        ;;
esac
echo ""

# ═══════════════════════════════════════════════
# PHASE 6: Network connections
# ═══════════════════════════════════════════════
echo -e "${BLUE}[PHASE 6]${NC} What Ports is it Using?"
echo "──────────────────────────────────────────"
sudo ss -tlnp | grep "pid=$PID" | sed 's/^/  /'
echo ""

# ═══════════════════════════════════════════════
# PHASE 7: Can we test it?
# ═══════════════════════════════════════════════
echo -e "${BLUE}[PHASE 7]${NC} Testing HTTP Response..."
echo "──────────────────────────────────────────"

# Try to curl localhost:80
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80 2>/dev/null)
echo "HTTP Status Code: $RESPONSE"

# Get headers
echo "Response Headers:"
curl -sI http://localhost:80 2>/dev/null | head -10 | sed 's/^/  /'
echo ""

# Get first few lines of response
echo "Page Preview:"
curl -s http://localhost:80 2>/dev/null | head -5 | sed 's/^/  /'
echo ""

# ═══════════════════════════════════════════════
# VERDICT & RECOMMENDATIONS
# ═══════════════════════════════════════════════
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  🎯 VERDICT & RECOMMENDATIONS                                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo -e "${YELLOW}🔍 SUMMARY:${NC}"
echo "  Process: $PROC_NAME (PID: $PID)"
echo "  User: $PROC_USER"
if [ -n "$SERVICE_NAME" ]; then
    echo "  Service: $SERVICE_NAME"
fi
echo ""

echo -e "${GREEN}💡 YOUR OPTIONS:${NC}"
echo ""

echo "1️⃣  TEMPORARY STOP (for testing)"
if [ -n "$SERVICE_NAME" ]; then
    echo "    sudo systemctl stop $SERVICE_NAME"
else
    echo "    sudo kill $PID"
fi
echo ""

echo "2️⃣  PERMANENT DISABLE"
if [ -n "$SERVICE_NAME" ]; then
    echo "    sudo systemctl stop $SERVICE_NAME"
    echo "    sudo systemctl disable $SERVICE_NAME"
else
    echo "    sudo kill $PID"
    echo "    # Then remove from startup scripts"
fi
echo ""

echo "3️⃣  KEEP IT, WORK AROUND IT"
echo "    Use: install_mailserver_fixed.sh"
echo "    Strategy: Use certbot --webroot instead of --standalone"
if [ -n "$SERVICE_NAME" ] && [ "$PROC_NAME" = "nginx" ]; then
    echo "    OR: Install Caddy, replace nginx"
fi
echo ""

echo "4️⃣  CHECK IF IT'S NEEDED"
echo "    Is this serving a website you need?"
echo "    Check: http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_IP')"
echo ""

echo -e "${YELLOW}⚠️  SAFETY TIP:${NC}"
echo "Before stopping/removing, make sure you're not breaking something important!"
echo "If unsure, try option 1 (temporary stop) first, test mail server, then re-enable."
echo ""

echo -e "${BLUE}🔬 DEEP DIVE COMMANDS:${NC}"
echo "  View all ports: sudo ss -tlnp"
echo "  Process tree: pstree -p $PID"
echo "  Full process info: sudo cat /proc/$PID/cmdline | tr '\\0' ' '"
echo "  Open files: sudo lsof -p $PID"
if [ -n "$SERVICE_NAME" ]; then
    echo "  Service logs: sudo journalctl -u $SERVICE_NAME -n 50"
fi
echo ""

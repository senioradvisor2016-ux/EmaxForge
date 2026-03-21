#!/bin/bash

echo "=========================================="
echo "KOMPLETT VNC FIX"
echo "=========================================="
echo ""

# Färger för output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Diagnostik
echo "📊 1. DIAGNOSTIK"
echo "=========================================="

# Kolla port 5900
echo ""
echo "🔍 Port 5900 status:"
PORT_5900=$(lsof -i :5900 2>/dev/null | grep LISTEN)
if [ ! -z "$PORT_5900" ]; then
    echo -e "${YELLOW}   ⚠️  Port 5900 är öppen${NC}"
    echo "   $PORT_5900"
    
    # Försök identifiera process utan sudo
    PROCESS=$(lsof -i :5900 2>/dev/null | grep LISTEN | awk '{print $1, $2}' | head -1)
    if [ ! -z "$PROCESS" ]; then
        echo "   Process: $PROCESS"
    fi
else
    echo -e "${GREEN}   ✅ Port 5900 är stängd${NC}"
fi

# Kolla ARDAgent
echo ""
echo "🔍 ARDAgent (Remote Desktop) status:"
ARDAgent_PID=$(ps aux | grep -i "ARDAgent" | grep -v grep | awk '{print $2}' | head -1)
if [ ! -z "$ARDAgent_PID" ]; then
    echo -e "${YELLOW}   ⚠️  ARDAgent körs (PID: $ARDAgent_PID)${NC}"
else
    echo -e "${GREEN}   ✅ ARDAgent körs inte${NC}"
fi

# Kolla Screen Sharing
echo ""
echo "🔍 Screen Sharing status:"
SCREEN_SHARING_PID=$(ps aux | grep -i "Screen Sharing" | grep -v grep | awk '{print $2}' | head -1)
if [ ! -z "$SCREEN_SHARING_PID" ]; then
    echo -e "${YELLOW}   ⚠️  Screen Sharing körs (PID: $SCREEN_SHARING_PID)${NC}"
else
    echo -e "${GREEN}   ✅ Screen Sharing körs inte${NC}"
fi

# Kolla TCP keepalive
echo ""
echo "🔍 TCP Keepalive inställningar:"
KEEPIDLE=$(sysctl -n net.inet.tcp.keepidle 2>/dev/null)
KEEPINTVL=$(sysctl -n net.inet.tcp.keepintvl 2>/dev/null)
echo "   keepidle: $KEEPIDLE ms"
echo "   keepintvl: $KEEPINTVL ms"
if [ "$KEEPIDLE" -lt 300000 ] || [ "$KEEPINTVL" -lt 30000 ]; then
    echo -e "${YELLOW}   ⚠️  Keepalive kan behöva ökas${NC}"
else
    echo -e "${GREEN}   ✅ Keepalive är korrekt konfigurerad${NC}"
fi

# Kolla Docker containers
echo ""
echo "🔍 Docker containers med VNC:"
DOCKER_VNC=$(docker ps -a --format "{{.Names}}" | grep -i vnc || echo "")
if [ ! -z "$DOCKER_VNC" ]; then
    echo -e "${YELLOW}   ⚠️  Hittade VNC-containers:${NC}"
    echo "$DOCKER_VNC"
else
    echo -e "${GREEN}   ✅ Inga VNC-containers hittades${NC}"
fi

# 2. Fixar
echo ""
echo "=========================================="
echo "🔧 2. FIXAR"
echo "=========================================="

# Fix 1: Öka TCP keepalive (om behövs)
if [ "$KEEPIDLE" -lt 300000 ] || [ "$KEEPINTVL" -lt 30000 ]; then
    echo ""
    echo "🔧 Fix 1: Ökar TCP keepalive timeout..."
    echo "   Detta kräver sudo-lösenord"
    sudo sysctl -w net.inet.tcp.keepidle=300000 2>/dev/null && \
    sudo sysctl -w net.inet.tcp.keepintvl=30000 2>/dev/null && \
    echo -e "${GREEN}   ✅ TCP keepalive ökat!${NC}" || \
    echo -e "${RED}   ❌ Kunde inte öka keepalive (kräver sudo)${NC}"
fi

# Fix 2: Visa instruktioner för att stänga VNC-tjänster
echo ""
echo "🔧 Fix 2: Stänga VNC-tjänster"
echo ""
if [ ! -z "$PORT_5900" ]; then
    echo -e "${YELLOW}   Port 5900 är öppen - här är hur du stänger den:${NC}"
    echo ""
    echo "   Metod 1: System Preferences"
    echo "   1. Öppna System Preferences → Sharing"
    echo "   2. Avmarkera 'Screen Sharing'"
    echo "   3. Avmarkera 'Remote Management'"
    echo ""
    echo "   Metod 2: Kommandorad (kräver sudo)"
    echo "   sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.screensharing.plist"
    echo "   sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -configure -access -off"
    echo ""
fi

# Fix 3: Permanent keepalive fix
echo ""
echo "🔧 Fix 3: Permanent keepalive fix"
read -p "   Vill du skapa permanent keepalive fix? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -f "/etc/sysctl.conf" ]; then
        if grep -q "net.inet.tcp.keepidle" /etc/sysctl.conf; then
            echo -e "${YELLOW}   ℹ️  Keepalive inställningar finns redan i /etc/sysctl.conf${NC}"
        else
            echo "   Lägger till keepalive inställningar..."
            sudo sh -c 'echo "" >> /etc/sysctl.conf && echo "# VNC Keepalive Fix" >> /etc/sysctl.conf && echo "net.inet.tcp.keepidle=300000" >> /etc/sysctl.conf && echo "net.inet.tcp.keepintvl=30000" >> /etc/sysctl.conf' && \
            echo -e "${GREEN}   ✅ Permanent fix tillagd!${NC}" || \
            echo -e "${RED}   ❌ Kunde inte lägga till permanent fix (kräver sudo)${NC}"
        fi
    else
        echo "   Skapar /etc/sysctl.conf..."
        sudo touch /etc/sysctl.conf && \
        sudo sh -c 'echo "# VNC Keepalive Fix" >> /etc/sysctl.conf && echo "net.inet.tcp.keepidle=300000" >> /etc/sysctl.conf && echo "net.inet.tcp.keepintvl=30000" >> /etc/sysctl.conf' && \
        echo -e "${GREEN}   ✅ Permanent fix skapad!${NC}" || \
        echo -e "${RED}   ❌ Kunde inte skapa permanent fix (kräver sudo)${NC}"
    fi
fi

# 3. Verifiering
echo ""
echo "=========================================="
echo "✅ 3. VERIFIERING"
echo "=========================================="

echo ""
echo "📊 Slutlig status:"
echo ""

# Port 5900
PORT_5900_FINAL=$(lsof -i :5900 2>/dev/null | grep LISTEN)
if [ -z "$PORT_5900_FINAL" ]; then
    echo -e "${GREEN}   ✅ Port 5900: Stängd${NC}"
else
    echo -e "${YELLOW}   ⚠️  Port 5900: Fortfarande öppen${NC}"
    echo "   Du behöver stänga Screen Sharing eller Remote Desktop manuellt"
fi

# Keepalive
KEEPIDLE_FINAL=$(sysctl -n net.inet.tcp.keepidle 2>/dev/null)
KEEPINTVL_FINAL=$(sysctl -n net.inet.tcp.keepintvl 2>/dev/null)
if [ "$KEEPIDLE_FINAL" -ge 300000 ] && [ "$KEEPINTVL_FINAL" -ge 30000 ]; then
    echo -e "${GREEN}   ✅ TCP Keepalive: Korrekt konfigurerad${NC}"
else
    echo -e "${YELLOW}   ⚠️  TCP Keepalive: Kan behöva ökas${NC}"
fi

echo ""
echo "=========================================="
echo "✅ KLART!"
echo "=========================================="
echo ""
echo "💡 NÄSTA STEG:"
echo ""
if [ ! -z "$PORT_5900_FINAL" ]; then
    echo "1. Stäng Screen Sharing eller Remote Desktop:"
    echo "   System Preferences → Sharing → Avmarkera 'Screen Sharing' och 'Remote Management'"
    echo ""
fi
echo "2. Testa VNC-anslutning igen"
echo ""
echo "3. Om problemet kvarstår:"
echo "   - Kontrollera nätverksanslutning (packet loss)"
echo "   - Använd kabelanslutning istället för WiFi"
echo "   - Kontrollera firewall-inställningar"
echo ""

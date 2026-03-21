#!/bin/bash

echo "=========================================="
echo "AGGRESSIV VNC DISCONNECT FIX"
echo "=========================================="
echo ""
echo "Detta fixar VNC disconnect-problem genom att:"
echo "  1. Öka TCP keepalive timeout"
echo "  2. Öka Remote Desktop timeout"
echo "  3. Konfigurera system för stabila anslutningar"
echo ""

# Färger
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 1. Öka TCP Keepalive (mer aggressivt)
echo "🔧 Fix 1: Ökar TCP Keepalive timeout (aggressivt)..."
echo "   Detta kräver sudo-lösenord"
echo ""

# Öka keepalive till ännu längre timeout
sudo sysctl -w net.inet.tcp.keepidle=600000 2>/dev/null && \
sudo sysctl -w net.inet.tcp.keepintvl=15000 2>/dev/null && \
echo -e "${GREEN}   ✅ TCP keepalive ökat till 10 minuter idle, 15 sekunder interval${NC}" || \
echo -e "${RED}   ❌ Kunde inte öka keepalive (kräver sudo)${NC}"

# Verifiera
echo ""
echo "   Nuvarande keepalive-inställningar:"
sysctl net.inet.tcp.keepidle net.inet.tcp.keepintvl

# 2. Öka Remote Desktop Timeout
echo ""
echo "🔧 Fix 2: Ökar Remote Desktop timeout..."
echo "   Detta kräver sudo-lösenord"
echo ""

# Sätt timeout till 0 (ingen timeout) eller mycket lång timeout
sudo defaults write /Library/Preferences/com.apple.RemoteDesktop.plist DisconnectTime -int 0 2>/dev/null && \
echo -e "${GREEN}   ✅ Remote Desktop timeout satt till 0 (ingen timeout)${NC}" || \
echo -e "${YELLOW}   ⚠️  Kunde inte ändra Remote Desktop timeout (kanske inte aktivt)${NC}"

# 3. Uppdatera permanent fix i /etc/sysctl.conf
echo ""
echo "🔧 Fix 3: Uppdaterar permanent keepalive fix..."
echo "   Detta kräver sudo-lösenord"
echo ""

if [ -f "/etc/sysctl.conf" ]; then
    # Ta bort gamla keepalive-inställningar
    sudo sed -i '' '/net.inet.tcp.keepidle/d' /etc/sysctl.conf 2>/dev/null
    sudo sed -i '' '/net.inet.tcp.keepintvl/d' /etc/sysctl.conf 2>/dev/null
    sudo sed -i '' '/net.inet.tcp.keepalive/d' /etc/sysctl.conf 2>/dev/null
    sudo sed -i '' '/# VNC Keepalive Fix/d' /etc/sysctl.conf 2>/dev/null
fi

# Lägg till nya (mer aggressiva) inställningar
sudo sh -c 'cat >> /etc/sysctl.conf << EOL

# VNC Keepalive Fix - Aggressiv (förhindrar disconnect)
net.inet.tcp.keepidle=600000
net.inet.tcp.keepintvl=15000
EOL' 2>/dev/null && \
echo -e "${GREEN}   ✅ Permanent fix uppdaterad!${NC}" || \
echo -e "${RED}   ❌ Kunde inte uppdatera permanent fix (kräver sudo)${NC}"

# 4. Kontrollera och fixa Screen Sharing inställningar
echo ""
echo "🔧 Fix 4: Kontrollerar Screen Sharing inställningar..."
echo ""

# Kolla om Screen Sharing är aktivt
SCREEN_SHARING=$(defaults read /Library/Preferences/com.apple.RemoteDesktop.plist 2>/dev/null | grep -i "DOCAllowRemoteConnections" || echo "")
if [ ! -z "$SCREEN_SHARING" ]; then
    echo "   Screen Sharing/Remote Desktop konfiguration hittad"
    echo "   💡 För bästa resultat: Använd Screen Sharing istället för Remote Desktop"
    echo "   System Preferences → Sharing → Screen Sharing"
fi

# 5. Ytterligare optimeringar
echo ""
echo "🔧 Fix 5: Ytterligare optimeringar..."
echo ""

# Kontrollera om systemet går i viloläge (detta kan orsaka disconnect)
echo "   💡 Tips: Förhindra system viloläge när VNC används:"
echo "   System Preferences → Energy Saver → Prevent computer from sleeping"
echo ""

# 6. Verifiering
echo "=========================================="
echo "✅ VERIFIERING"
echo "=========================================="
echo ""

echo "📊 Slutlig status:"
echo ""

# Keepalive
KEEPIDLE=$(sysctl -n net.inet.tcp.keepidle 2>/dev/null)
KEEPINTVL=$(sysctl -n net.inet.tcp.keepintvl 2>/dev/null)
echo "   TCP Keepalive:"
echo "   - keepidle: $KEEPIDLE ms ($(($KEEPIDLE / 1000)) sekunder)"
echo "   - keepintvl: $KEEPINTVL ms ($(($KEEPINTVL / 1000)) sekunder)"

if [ "$KEEPIDLE" -ge 300000 ]; then
    echo -e "   ${GREEN}✅ Keepalive är korrekt konfigurerad${NC}"
else
    echo -e "   ${YELLOW}⚠️  Keepalive kan behöva ökas${NC}"
fi

# Remote Desktop timeout
RD_TIMEOUT=$(defaults read /Library/Preferences/com.apple.RemoteDesktop.plist DisconnectTime 2>/dev/null || echo "N/A")
echo ""
echo "   Remote Desktop timeout: $RD_TIMEOUT"
if [ "$RD_TIMEOUT" = "0" ]; then
    echo -e "   ${GREEN}✅ Timeout är avstängd (ingen timeout)${NC}"
else
    echo -e "   ${YELLOW}⚠️  Timeout kan orsaka disconnect${NC}"
fi

echo ""
echo "=========================================="
echo "✅ KLART!"
echo "=========================================="
echo ""
echo "💡 NÄSTA STEG:"
echo ""
echo "1. Testa VNC-anslutning igen"
echo "   Anslutningen borde nu vara mycket mer stabil"
echo ""
echo "2. Om problemet kvarstår:"
echo "   - Kontrollera nätverksanslutning (packet loss)"
echo "   - Använd kabelanslutning istället för WiFi"
echo "   - Kontrollera firewall-inställningar"
echo "   - Överväg att använda Screen Sharing istället för Remote Desktop"
echo ""
echo "3. Förhindra system viloläge:"
echo "   System Preferences → Energy Saver → Prevent computer from sleeping"
echo ""
echo "4. Om du behöver återställa keepalive:"
echo "   sudo sysctl -w net.inet.tcp.keepidle=72000"
echo "   sudo sysctl -w net.inet.tcp.keepintvl=75000"
echo ""

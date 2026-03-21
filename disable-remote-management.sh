#!/bin/bash

echo "=========================================="
echo "STÄNGER AV REMOTE MANAGEMENT"
echo "=========================================="
echo ""

# Färger
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Kontrollera nuvarande status
echo "📊 Nuvarande status:"
ARDAgent_PID=$(ps aux | grep -i "ARDAgent" | grep -v grep | awk '{print $2}' | head -1)
if [ ! -z "$ARDAgent_PID" ]; then
    echo -e "${YELLOW}   ⚠️  ARDAgent körs (PID: $ARDAgent_PID)${NC}"
    echo "   Remote Management är aktivt"
else
    echo -e "${GREEN}   ✅ ARDAgent körs inte${NC}"
    echo "   Remote Management är redan avstängt"
fi

echo ""
echo "🔧 Stänger av Remote Management..."
echo "   Detta kräver sudo-lösenord"
echo ""

# Stäng av Remote Management
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -configure -access -off

if [ $? -eq 0 ]; then
    echo -e "${GREEN}   ✅ Remote Management stängd av!${NC}"
else
    echo -e "${RED}   ❌ Kunde inte stänga av Remote Management${NC}"
    echo "   Kontrollera att du har sudo-behörighet"
    exit 1
fi

# Vänta lite för att processen ska stängas
sleep 2

# Verifiera
echo ""
echo "=========================================="
echo "✅ VERIFIERING"
echo "=========================================="
echo ""

ARDAgent_PID_AFTER=$(ps aux | grep -i "ARDAgent" | grep -v grep | awk '{print $2}' | head -1)
if [ -z "$ARDAgent_PID_AFTER" ]; then
    echo -e "${GREEN}   ✅ ARDAgent körs inte längre${NC}"
    echo -e "${GREEN}   ✅ Remote Management är avstängt${NC}"
else
    echo -e "${YELLOW}   ⚠️  ARDAgent körs fortfarande (PID: $ARDAgent_PID_AFTER)${NC}"
    echo "   Du kan behöva starta om datorn eller stänga av via System Preferences"
fi

# Kolla port 5900
echo ""
echo "📊 Port 5900 status:"
PORT_5900=$(lsof -i :5900 2>/dev/null | grep LISTEN)
if [ -z "$PORT_5900" ]; then
    echo -e "${GREEN}   ✅ Port 5900 är stängd${NC}"
else
    echo -e "${YELLOW}   ⚠️  Port 5900 är fortfarande öppen${NC}"
    echo "   Detta kan vara Screen Sharing eller annan VNC-server"
fi

echo ""
echo "=========================================="
echo "✅ KLART!"
echo "=========================================="
echo ""
echo "💡 NÄSTA STEG:"
echo ""
echo "1. Om du vill använda VNC, aktivera Screen Sharing istället:"
echo "   System Preferences → Sharing → Screen Sharing"
echo ""
echo "2. Detta bör förbättra VNC-stabiliteten"
echo ""

#!/bin/bash

echo "=========================================="
echo "FIXAR VNC DISCONNECT PROBLEM"
echo "=========================================="

echo ""
echo "🔧 Fix 1: Öka TCP Keepalive Timeout"
echo "   Detta förhindrar att TCP-anslutningar timeoutar"
echo ""
read -p "Vill du öka TCP keepalive timeout? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "   Ökar keepalive timeout..."
    sudo sysctl -w net.inet.tcp.keepidle=300000  # 5 minuter
    sudo sysctl -w net.inet.tcp.keepintvl=30000   # 30 sekunder
    sudo sysctl -w net.inet.tcp.keepalive=1
    
    echo "   ✅ TCP keepalive timeout ökat!"
    echo "   Nuvarande värden:"
    sysctl net.inet.tcp.keepidle net.inet.tcp.keepintvl net.inet.tcp.keepalive
else
    echo "   Hoppade över TCP keepalive fix"
fi

echo ""
echo "🔧 Fix 2: Kontrollera Remote Desktop Timeout"
echo "   Remote Desktop kan ha timeout-inställningar"
echo ""
read -p "Vill du kontrollera Remote Desktop timeout? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "   Nuvarande Remote Desktop inställningar:"
    defaults read /Library/Preferences/com.apple.RemoteDesktop.plist 2>/dev/null || echo "   Kunde inte läsa config"
    
    echo ""
    echo "   💡 För att öka timeout, kör:"
    echo "   sudo defaults write /Library/Preferences/com.apple.RemoteDesktop.plist DisconnectTime -int 0"
fi

echo ""
echo "🔧 Fix 3: Använd Screen Sharing istället"
echo "   Screen Sharing kan vara mer stabil än Remote Desktop"
echo ""
read -p "Vill du stänga Remote Desktop och aktivera Screen Sharing? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "   Stänger Remote Desktop..."
    sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -configure -access -off 2>/dev/null
    
    echo "   Aktiverar Screen Sharing..."
    sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null
    
    echo "   ✅ Screen Sharing aktiverad!"
    echo "   💡 Gå till System Preferences → Sharing → Screen Sharing för att konfigurera"
fi

echo ""
echo "=========================================="
echo "✅ KLART!"
echo "=========================================="
echo ""
echo "💡 ANDRA TIPS:"
echo "   1. Kontrollera nätverksanslutning (packet loss)"
echo "   2. Använd stabil nätverksanslutning (kabel istället för WiFi)"
echo "   3. Kontrollera firewall inställningar"
echo "   4. Överväg att använda VPN om nätverket är instabilt"
echo ""


#!/bin/bash

echo "=========================================="
echo "FIXAR VNC SERVER KONFLIKTER"
echo "=========================================="

# Identifiera processer
echo ""
echo "📊 Identifierar VNC processer..."

SCREEN_SHARING_PID=$(ps aux | grep -i "Screen Sharing" | grep -v grep | awk '{print $2}' | head -1)
ARDAgent_PID=$(ps aux | grep -i "ARDAgent" | grep -v grep | awk '{print $2}' | head -1)

if [ ! -z "$SCREEN_SHARING_PID" ]; then
    echo "   ✅ Screen Sharing körs (PID: $SCREEN_SHARING_PID)"
else
    echo "   ℹ️  Screen Sharing körs inte"
fi

if [ ! -z "$ARDAgent_PID" ]; then
    echo "   ✅ ARDAgent körs (PID: $ARDAgent_PID)"
else
    echo "   ℹ️  ARDAgent körs inte"
fi

# Kolla port 5900
echo ""
echo "📊 Port 5900 status:"
PORT_5900=$(lsof -i :5900 2>/dev/null | grep LISTEN)
if [ ! -z "$PORT_5900" ]; then
    echo "   ⚠️  Port 5900 är öppen"
    echo "   $PORT_5900"
else
    echo "   ✅ Port 5900 är stängd"
fi

echo ""
echo "💡 REKOMMENDATIONER:"
echo ""
echo "1. Stäng Screen Sharing:"
echo "   System Preferences → Sharing → Screen Sharing → Avmarkera"
echo ""
echo "2. Stäng Remote Desktop:"
echo "   System Preferences → Sharing → Remote Management → Avmarkera"
echo ""
echo "3. Eller använd kommandorad (kräver sudo):"
echo "   sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.screensharing.plist"
echo "   sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -configure -access -off"
echo ""


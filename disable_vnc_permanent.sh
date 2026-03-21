#!/bin/bash

echo "=========================================="
echo "PERMANENT VNC FIX"
echo "=========================================="
echo ""
echo "Detta script stänger Screen Sharing och Remote Desktop permanent."
echo "Kräver sudo lösenord."
echo ""
read -p "Fortsätt? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🔧 Stänger Screen Sharing..."
    sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null
    
    echo "🔧 Stänger Remote Desktop..."
    sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -configure -access -off 2>/dev/null
    
    echo ""
    echo "✅ Klart!"
    echo ""
    echo "💡 Alternativt: Gå till System Preferences → Sharing"
    echo "   och avmarkera Screen Sharing och Remote Management"
else
    echo "Avbruten."
fi


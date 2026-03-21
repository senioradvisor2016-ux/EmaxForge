#!/bin/bash

echo "=========================================="
echo "PERMANENT VNC KEEPALIVE FIX"
echo "=========================================="
echo ""
echo "Detta skapar en permanent fix för TCP keepalive"
echo "som förhindrar VNC disconnect."
echo ""

# Skapa sysctl config
if [ ! -f /etc/sysctl.conf ]; then
    echo "Skapar /etc/sysctl.conf..."
    sudo touch /etc/sysctl.conf
fi

# Lägg till keepalive inställningar
echo ""
echo "Lägger till keepalive inställningar till /etc/sysctl.conf..."
sudo sh -c 'cat >> /etc/sysctl.conf << EOL

# VNC Keepalive Fix (förhindrar disconnect)
net.inet.tcp.keepidle=300000
net.inet.tcp.keepintvl=30000
net.inet.tcp.keepalive=1
EOL'

echo "✅ Keepalive inställningar tillagda!"
echo ""
echo "💡 För att applicera nuvarande session:"
echo "   sudo sysctl -w net.inet.tcp.keepidle=300000"
echo "   sudo sysctl -w net.inet.tcp.keepintvl=30000"
echo "   sudo sysctl -w net.inet.tcp.keepalive=1"
echo ""
echo "✅ Permanent fix tillagd - kommer att gälla efter omstart!"
echo ""


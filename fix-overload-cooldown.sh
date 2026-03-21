#!/bin/bash

echo "=========================================="
echo "FIXAR OVERLOAD/COOLDOWN PROBLEM"
echo "=========================================="
echo ""

# Färger
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "📊 Problem:"
echo "   - Opus 4.6: Överbelastad (temporärt)"
echo "   - Sonnet 4.5: I cooldown (probe redan försökt)"
echo ""

echo "🔧 Lösning 1: Lägg till Opus 4.5 som fallback"
echo "   Opus 4.5 finns i modellistan och kan fungera som backup"
echo ""

read -p "Vill du lägga till Opus 4.5 som fallback? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "   Uppdaterar config..."
    
    # Backup config
    cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.backup
    
    # Lägg till Opus 4.5 i fallbacks
    python3 << 'EOF'
import json
import os

config_path = os.path.expanduser("~/.openclaw/openclaw.json")

with open(config_path, 'r') as f:
    config = json.load(f)

# Lägg till Opus 4.5 i fallbacks om den inte redan finns
fallbacks = config.get("agents", {}).get("defaults", {}).get("model", {}).get("fallbacks", [])
if "anthropic/claude-opus-4-5" not in fallbacks:
    fallbacks.append("anthropic/claude-opus-4-5")
    config["agents"]["defaults"]["model"]["fallbacks"] = fallbacks
    print("   ✅ Opus 4.5 tillagd som fallback")
else:
    print("   ℹ️  Opus 4.5 finns redan i fallbacks")

# Spara config
with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)

print("   ✅ Config uppdaterad!")
EOF

    echo ""
    echo "   Startar om gateway..."
    ~/.npm-global/bin/openclaw gateway restart
    echo ""
    echo -e "${GREEN}   ✅ Opus 4.5 tillagd som fallback!${NC}"
fi

echo ""
echo "=========================================="
echo "💡 ANDRA LÖSNINGAR"
echo "=========================================="
echo ""
echo "1. Vänta 10-60 minuter"
echo "   Rate limits återställs automatiskt"
echo "   Open Claw försöker automatiskt igen"
echo ""
echo "2. Kontrollera Anthropic Console"
echo "   https://console.anthropic.com/"
echo "   Se din användning och rate limits"
echo ""
echo "3. Testa igen om en stund"
echo "   ~/.npm-global/bin/openclaw gateway status"
echo ""
echo "4. Om problemet kvarstår:"
echo "   - Kontrollera om API key används på flera ställen"
echo "   - Överväg att uppgradera till betald plan"
echo "   - Minska antal requests"
echo ""
echo "=========================================="
echo "✅ KLART!"
echo "=========================================="
echo ""

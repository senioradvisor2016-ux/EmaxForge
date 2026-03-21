#!/bin/bash

echo "=========================================="
echo "INSTALLERAR msvcr140.dll I WHISKEY"
echo "=========================================="
echo ""
echo "Detta script hjälper dig att installera msvcr140.dll i Whiskey."
echo ""

BOTTLE_PATH="$HOME/Library/Containers/com.isaacmarovitz.Whisky/Bottles/785BA294-9A93-4E87-9C1B-FB9A251D6B4A"
SYSTEM32="$BOTTLE_PATH/drive_c/windows/system32"

# Kolla om msvcr140.dll redan finns
if [ -f "$SYSTEM32/msvcr140.dll" ]; then
    echo "✅ msvcr140.dll finns redan!"
    exit 0
fi

echo "📊 SÖKER EFTER msvcr140.dll I ANDRA BOTTLES..."
echo ""

# Sök i andra bottles
BOTTLES_DIR="$HOME/Library/Containers/com.isaacmarovitz.Whisky/Bottles"
if [ -d "$BOTTLES_DIR" ]; then
    for bottle in "$BOTTLES_DIR"/*; do
        if [ -d "$bottle" ] && [ "$(basename "$bottle")" != "785BA294-9A93-4E87-9C1B-FB9A251D6B4A" ]; then
            other_dll="$bottle/drive_c/windows/system32/msvcr140.dll"
            if [ -f "$other_dll" ]; then
                echo "✅ Hittade msvcr140.dll i: $(basename "$bottle")"
                echo "   Kopierar..."
                cp "$other_dll" "$SYSTEM32/msvcr140.dll"
                if [ -f "$SYSTEM32/msvcr140.dll" ]; then
                    SIZE=$(stat -f%z "$SYSTEM32/msvcr140.dll" 2>/dev/null || stat -c%s "$SYSTEM32/msvcr140.dll" 2>/dev/null)
                    echo "   ✅ Kopierad! ($SIZE bytes)"
                    echo ""
                    echo "✅ msvcr140.dll INSTALLERAD!"
                    exit 0
                fi
            fi
        fi
    done
fi

echo "❌ msvcr140.dll hittades inte i andra bottles"
echo ""
echo "💡 MANUELL INSTALLATION VIA WHISKEY:"
echo ""
echo "1. Öppna Whiskey.app"
echo "2. Välj din Whisky bottle (785BA294-9A93-4E87-9C1B-FB9A251D6B4A)"
echo "3. Klicka på 'Run' → 'Run Command'"
echo "4. Skriv: winetricks vcrun2015"
echo "5. Vänta tills installationen är klar"
echo ""
echo "Detta kommer att installera msvcr140.dll automatiskt!"
echo ""

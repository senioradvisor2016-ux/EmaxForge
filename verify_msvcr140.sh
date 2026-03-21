#!/bin/bash

echo "=========================================="
echo "VERIFIERAR msvcr140.dll"
echo "=========================================="

BOTTLE_PATH="$HOME/Library/Containers/com.isaacmarovitz.Whisky/Bottles/785BA294-9A93-4E87-9C1B-FB9A251D6B4A"
SYSTEM32="$BOTTLE_PATH/drive_c/windows/system32/msvcr140.dll"
SYSWOW64="$BOTTLE_PATH/drive_c/windows/syswow64/msvcr140.dll"

echo ""
if [ -f "$SYSTEM32" ]; then
    SIZE=$(stat -f%z "$SYSTEM32" 2>/dev/null || stat -c%s "$SYSTEM32" 2>/dev/null)
    echo "✅ msvcr140.dll finns i system32 ($SIZE bytes)"
    exit 0
elif [ -f "$SYSWOW64" ]; then
    SIZE=$(stat -f%z "$SYSWOW64" 2>/dev/null || stat -c%s "$SYSWOW64" 2>/dev/null)
    echo "✅ msvcr140.dll finns i syswow64 ($SIZE bytes)"
    echo "💡 Kopierar till system32..."
    cp "$SYSWOW64" "$SYSTEM32"
    if [ -f "$SYSTEM32" ]; then
        echo "✅ Kopierad till system32!"
        exit 0
    fi
fi

echo "❌ msvcr140.dll saknas"
echo ""
echo "💡 Installera via Whiskey:"
echo "   1. Öppna Whiskey"
echo "   2. Välj bottle → Run → Run Command"
echo "   3. Kör: winetricks vcrun2015 --force"
echo ""
exit 1

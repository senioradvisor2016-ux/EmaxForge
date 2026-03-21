#!/bin/bash
# Force mount script för SD-kort

echo "🔍 Söker efter SD-kort (force mode)..."
echo ""

# Vänta lite så systemet hinner detektera
echo "⏳ Väntar 3 sekunder för detektering..."
sleep 3

# Lista alla diskar
echo "📋 Alla diskar:"
diskutil list
echo ""

# Försök hitta alla möjliga diskar (inklusive de som inte visas normalt)
echo "🔍 Söker efter removable/externa diskar..."
found=false

# Kolla alla diskar från disk4 och uppåt (disk0-3 är vanligtvis interna)
for i in {4..20}; do
    disk="/dev/disk${i}"
    if [ -e "$disk" ]; then
        echo "✅ Hittade disk: $disk"
        info=$(diskutil info "$disk" 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "$info" | grep -E "(Device Node|Volume Name|Mounted|File System|Total Size|Removable Media)" | head -6
            echo ""
            
            # Försök mounta om den inte är mountad
            mounted=$(echo "$info" | grep "Mounted" | awk -F': ' '{print $2}')
            if echo "$mounted" | grep -q "No"; then
                vol_name=$(echo "$info" | grep "Volume Name" | awk -F': ' '{print $2}')
                if [ "$vol_name" != "Not applicable (no file system)" ] && [ ! -z "$vol_name" ]; then
                    echo "🔄 Försöker mounta $disk..."
                    diskutil mount "$disk" 2>&1
                    if [ $? -eq 0 ]; then
                        echo "✅ Mountad!"
                        mount_point=$(diskutil info "$disk" | grep "Mount Point" | awk -F': ' '{print $2}')
                        echo "📍 Mount point: $mount_point"
                        found=true
                    else
                        echo "⚠️  Kunde inte mounta automatiskt"
                    fi
                fi
            else
                mount_point=$(echo "$info" | grep "Mount Point" | awk -F': ' '{print $2}')
                echo "✅ Redan mountad på: $mount_point"
                found=true
            fi
            echo ""
        fi
    fi
done

# Om inget hittades, försök mounta alla unmounted volymer
if [ "$found" = "false" ]; then
    echo "🔄 Försöker mounta alla unmounted volymer..."
    diskutil mountDisk all 2>&1 | grep -v "does not appear to be" || true
    echo ""
fi

# Visa mountade volymer
echo "📂 Mountade volymer:"
ls -la /Volumes/ | grep -v "^total\|^d.*\.$"

if [ "$found" = "false" ]; then
    echo ""
    echo "⚠️  Inget SD-kort hittades."
    echo ""
    echo "💡 Försök manuellt:"
    echo "   1. Kör: diskutil list"
    echo "   2. Hitta SD-kortet (t.ex. /dev/disk4)"
    echo "   3. Kör: diskutil mountDisk /dev/disk4"
    echo "   4. Eller: diskutil mount /dev/disk4s1 (för första partitionen)"
fi

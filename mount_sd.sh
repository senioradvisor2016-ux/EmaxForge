#!/bin/bash
# Script för att mounta SD-kort

echo "🔍 Söker efter SD-kort..."
echo ""

# Lista alla diskar
diskutil list

echo ""
echo "📋 Kontrollerar unmounted volymer..."
echo ""

# Hitta unmounted volymer (exkludera interna diskar och APFS containers)
found_any=false
for disk in $(diskutil list | grep -E "^/dev/disk" | awk '{print $1}' | grep -v "disk0\|disk1\|disk2\|disk3"); do
    info=$(diskutil info "$disk" 2>/dev/null)
    if [ $? -eq 0 ]; then
        mounted=$(echo "$info" | grep "Mounted" | awk -F': ' '{print $2}')
        vol_name=$(echo "$info" | grep "Volume Name" | awk -F': ' '{print $2}')
        fs_type=$(echo "$info" | grep "File System Personality" | awk -F': ' '{print $2}')
        size=$(echo "$info" | grep "Total Size" | awk -F': ' '{print $2}')
        
        # Skip physical disks without file system
        if [ "$vol_name" = "Not applicable (no file system)" ]; then
            continue
        fi
        
        # Check if it's a partition/volume that can be mounted
        if echo "$mounted" | grep -q "No"; then
            found_any=true
            echo "📀 Hittade unmounted volym:"
            echo "   Disk: $disk"
            echo "   Namn: $vol_name"
            echo "   Filtyp: $fs_type"
            echo "   Storlek: $size"
            echo ""
            read -p "Vill du mounta denna volym? (j/n): " answer
            if [ "$answer" = "j" ] || [ "$answer" = "J" ]; then
                echo "🔄 Mountar $disk..."
                diskutil mount "$disk"
                if [ $? -eq 0 ]; then
                    echo "✅ Volym mountad!"
                    mount_point=$(diskutil info "$disk" | grep "Mount Point" | awk -F': ' '{print $2}')
                    echo "📍 Mount point: $mount_point"
                else
                    echo "❌ Kunde inte mounta volym"
                fi
            fi
            echo ""
        fi
    fi
done

if [ "$found_any" = "false" ]; then
    echo "⚠️  Inga unmounted volymer hittades."
    echo ""
    echo "💡 Tips:"
    echo "   1. Kontrollera att SD-kortet är inkopplat"
    echo "   2. Vänta några sekunder så macOS detekterar det"
    echo "   3. Kör 'diskutil list' för att se alla diskar"
    echo "   4. Om SD-kortet syns men inte mountas, försök:"
    echo "      diskutil mountDisk /dev/diskX (ersätt X med disknummer)"
fi

echo ""
echo "📂 Mountade volymer:"
ls -la /Volumes/

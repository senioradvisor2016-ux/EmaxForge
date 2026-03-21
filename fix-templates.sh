#!/bin/bash
# Fix FAT entry 0 in all EMAXII boot disk templates
# Should be 0x000F (little-endian: 0F 00), not 0x0080 (80 00)

TEMPLATES=(
    "EmaxForge/Resources/bootable_templates/EMAXII_IMAGE_96.EZ2"
    "EmaxForge/Resources/bootable_templates/EMAXII_IMAGE_239.EZ2"
    "EmaxForge/Resources/bootable_templates/EMAXII_IMAGE_481.EZ2"
    "EmaxForge/Resources/bootable_templates/EMAXII_IMAGE_633.EZ2"
    "EmaxForge/Resources/bootable_templates/EMAXII_IMAGE_962.EZ2"
)

for template in "${TEMPLATES[@]}"; do
    if [[ ! -f "$template" ]]; then
        echo "⚠️  Not found: $template"
        continue
    fi
    
    # Backup
    cp "$template" "$template.backup"
    
    # Check current value
    current=$(xxd -s 0x400 -l 2 -p "$template")
    echo "📄 $template"
    echo "   Before: 0x$current"
    
    # Write correct value: 0x0F 0x00 at offset 0x400
    printf '\x0f\x00' | dd of="$template" bs=1 seek=$((0x400)) count=2 conv=notrunc 2>/dev/null
    
    # Verify
    after=$(xxd -s 0x400 -l 2 -p "$template")
    echo "   After:  0x$after"
    
    if [[ "$after" == "0f00" ]]; then
        echo "   ✅ Fixed!"
    else
        echo "   ❌ FAILED - restoring backup"
        mv "$template.backup" "$template"
    fi
    echo
done

echo "✅ Template fixes complete!"

# Bygga och köra EmaxForge med nya UX-förbättringar

## 🚀 Snabbstart

### Metod 1: Xcode (Rekommenderat)

1. **Öppna projektet:**
   ```bash
   open EmaxForge.xcodeproj
   ```

2. **Välj scheme:** `EmaxForge` → `My Mac`

3. **Bygg och kör:**
   - Tryck **Cmd+R** eller klicka på Play-knappen
   - Eller: **Product** → **Run**

4. **Testa nya features:**
   - ✅ Undo/Redo: Cmd+Z / Cmd+Shift+Z
   - ✅ Multi-select: Cmd+Click på images
   - ✅ Toast notifications: Delete en image
   - ✅ Hover states: Hover över list items
   - ✅ Progress: Starta en lång operation

---

### Metod 2: Swift Package Manager (om SDK matchar)

```bash
cd /Users/senioradvisor/clawd/EmaxForge
swift build -c release
.build/release/EmaxForge &
```

**OBS:** Om du får SDK/toolchain mismatch errors, använd Xcode istället.

---

## 📝 Nya Features att testa

### 1. Undo/Redo
- **Delete en image** → Tryck **Cmd+Z** → Image återställs
- **Rename en image** → Tryck **Cmd+Z** → Namnet återställs

### 2. Multi-Select
- **Cmd+Click** på flera images → Toolbar visar "X images selected"
- **Delete All** → Confirmation dialog → Batch delete

### 3. Toast Notifications
- **Delete image** → Toast visas i bottom-right
- **Klicka "Undo"** i toast → Image återställs

### 4. Hover States
- **Hover över list item** → Background ändras
- **Select item** → Highlight med accent color

### 5. Progress Indicators
- **Starta backup/restore** → Progress bar i status bar
- **Import banks** → Progress uppdateras

---

## 🐛 Om build misslyckas

### Problem: SDK/toolchain mismatch
**Lösning:** Använd Xcode istället för command line tools

### Problem: "Operation not permitted"
**Lösning:** Kör i Xcode eller fixa cache permissions:
```bash
sudo chmod -R 755 ~/.cache/clang
```

---

## ✅ Verifiering

Efter build, kontrollera att dessa filer finns:
- ✅ `EmaxForge/Sources/Views/ToastView.swift` (ny fil)
- ✅ `EmaxForge/Sources/App/AppState.swift` (uppdaterad med undo/progress)
- ✅ `EmaxForge/Sources/Views/ImageListView.swift` (uppdaterad med multi-select)

---

**Status:** Alla UX-förbättringar är implementerade och redo för testning! 🎉

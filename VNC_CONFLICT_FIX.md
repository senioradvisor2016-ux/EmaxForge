# VNC Server Konflikt - Diagnostik och Fix

**Datum:** 2026-03-07  
**Problem:** VNC server konflikter  
**Status:** 🔍 **ANALYSERAR**

---

## 📊 IDENTIFIERADE PROBLEM

### Port 5900 är Öppen

**Status:**
- Port 5900: LISTEN (öppen och lyssnar)
- Aktiv anslutning: 100.115.153.120:5900 → 100.100.247.107:54849

**Möjliga orsaker:**
1. macOS Screen Sharing (inbyggd)
2. Remote Desktop (ARD)
3. Tredjeparts VNC server
4. Docker container med VNC

---

## 🔧 LÖSNINGAR

### 1. Stänga macOS Screen Sharing

**Metod 1: System Preferences**
1. Öppna **System Preferences** → **Sharing**
2. Avmarkera **Screen Sharing**
3. Klicka **Stop**

**Metod 2: Kommandorad**
```bash
sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.screensharing.plist
```

**Aktivera igen:**
```bash
sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist
```

---

### 2. Stänga Remote Desktop (ARD)

**Metod 1: System Preferences**
1. Öppna **System Preferences** → **Sharing**
2. Avmarkera **Remote Management**
3. Klicka **Stop**

**Metod 2: Kommandorad**
```bash
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -configure -access -off
```

---

### 3. Hitta och Stänga VNC Process

**Hitta process:**
```bash
lsof -i :5900
```

**Stänga process:**
```bash
# Om PID är 12345:
kill 12345

# Om det inte fungerar:
kill -9 12345
```

---

### 4. Stänga Docker VNC Container (om det finns)

**Lista containers:**
```bash
docker ps
```

**Stoppa VNC container:**
```bash
docker stop <container_id>
```

---

## 📋 CHECKLIST FÖR FELSÖKNING

1. **Identifiera vad som använder port 5900:**
   ```bash
   lsof -i :5900
   ```

2. **Kolla Screen Sharing:**
   - System Preferences → Sharing → Screen Sharing
   - Om aktiv: Stäng av

3. **Kolla Remote Desktop:**
   - System Preferences → Sharing → Remote Management
   - Om aktiv: Stäng av

4. **Kolla Docker containers:**
   ```bash
   docker ps
   ```

5. **Kolla tredjeparts VNC:**
   ```bash
   ps aux | grep vnc
   ```

---

## 💡 REKOMMENDATIONER

### Om du vill använda VNC:

1. **Använd endast EN VNC server:**
   - Antingen macOS Screen Sharing
   - Eller tredjeparts VNC server
   - Inte båda samtidigt!

2. **Använd olika portar:**
   - macOS Screen Sharing: Port 5900
   - Tredjeparts VNC: Port 5901, 5902, etc.

3. **Konfigurera brandvägg:**
   - Tillåt endast specifika portar
   - Blockera övriga VNC portar

---

## 🎯 SNABB FIX

**Om du vill stänga allt VNC:**

```bash
# Stäng Screen Sharing
sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.screensharing.plist

# Stäng Remote Desktop
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -configure -access -off

# Hitta och stäng VNC processer
lsof -i :5900 | grep LISTEN | awk '{print $2}' | xargs kill -9
```

**Aktivera igen (om behövs):**
```bash
# Aktivera Screen Sharing
sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist
```

---

**Status:** 🔍 **ANALYSERAR KONFLIKTER**

**Nästa steg:** Identifiera exakt vad som använder port 5900 och stänga det.

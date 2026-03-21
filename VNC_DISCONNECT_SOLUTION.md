# VNC Disconnect Problem - Lösning

**Datum:** 2026-03-07  
**Problem:** VNC klient kopplar ur hela tiden  
**Status:** ✅ **FIXAR TILLGÄNGLIGA**

---

## 🔍 IDENTIFIERAT PROBLEM

### Nuvarande Status:
- ✅ ARDAgent körs (Remote Desktop)
- ✅ Port 5900 är öppen med aktiv anslutning
- ✅ System förhindrar sleep
- ⚠️  TCP keepalive: 120s idle, 75s interval (kan vara för kort)

---

## 🔧 FIXAR

### 1. Öka TCP Keepalive Timeout (Rekommenderat)

**Problem:** TCP-anslutningar timeoutar efter 120 sekunder inaktivitet.

**Fix:**
```bash
# Öka keepalive timeout till 5 minuter
sudo sysctl -w net.inet.tcp.keepidle=300000

# Öka keepalive interval till 30 sekunder
sudo sysctl -w net.inet.tcp.keepintvl=30000

# Aktivera keepalive
sudo sysctl -w net.inet.tcp.keepalive=1
```

**Permanent (lägg till i /etc/sysctl.conf):**
```
net.inet.tcp.keepidle=300000
net.inet.tcp.keepintvl=30000
net.inet.tcp.keepalive=1
```

---

### 2. Använd Screen Sharing istället för Remote Desktop

**Problem:** Remote Desktop kan ha timeout-inställningar som orsakar disconnect.

**Fix:**
```bash
# Stäng Remote Desktop
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -configure -access -off

# Aktivera Screen Sharing
sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist
```

**Konfigurera:**
1. System Preferences → Sharing
2. Aktivera Screen Sharing
3. Konfigurera användare och behörigheter

---

### 3. Öka Remote Desktop Timeout (Om du behöver Remote Desktop)

```bash
# Sätt timeout till 0 (ingen timeout)
sudo defaults write /Library/Preferences/com.apple.RemoteDesktop.plist DisconnectTime -int 0
```

---

### 4. Kontrollera Nätverksanslutning

**Problem:** Packet loss kan orsaka disconnect.

**Fix:**
```bash
# Testa anslutning
ping -c 10 <vnc_client_ip>

# Kolla packet loss
# Om packet loss > 1%, kontrollera nätverksanslutning
```

---

## 📋 CHECKLIST

- [ ] Öka TCP keepalive timeout
- [ ] Kontrollera nätverksanslutning (packet loss)
- [ ] Överväg att använda Screen Sharing istället för Remote Desktop
- [ ] Kontrollera firewall inställningar
- [ ] Förhindra system viloläge (redan gjort ✅)

---

## 💡 REKOMMENDATIONER

1. **Använd Screen Sharing** istället för Remote Desktop (mer stabil)
2. **Öka TCP keepalive timeout** för stabilare anslutningar
3. **Använd kabelanslutning** istället för WiFi (mer stabil)
4. **Kontrollera nätverksanslutning** för packet loss

---

## 🎯 SNABB FIX

**Kör scriptet:**
```bash
cd /Users/senioradvisor/clawd/EmaxForge
./fix_vnc_disconnect.sh
```

**Eller manuellt:**
```bash
# Öka TCP keepalive
sudo sysctl -w net.inet.tcp.keepidle=300000
sudo sysctl -w net.inet.tcp.keepintvl=30000
sudo sysctl -w net.inet.tcp.keepalive=1
```

---

**Status:** ✅ **FIXAR TILLGÄNGLIGA**

**Nästa steg:** Applicera fixarna ovan för att lösa disconnect-problemet.

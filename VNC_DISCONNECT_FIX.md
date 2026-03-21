# VNC Disconnect Problem - Diagnostik och Fix

**Datum:** 2026-03-07  
**Problem:** VNC klient kopplar ur hela tiden  
**Status:** 🔍 **DIAGNOSTISERAR**

---

## 🔍 VANLIGA ORSAKER

### 1. Timeout (Inaktivitet)
- VNC server stänger anslutningar efter inaktivitet
- **Fix:** Öka timeout-värden

### 2. Nätverksproblem
- Packet loss eller instabil anslutning
- **Fix:** Kontrollera nätverksanslutning

### 3. Flera VNC Servrar
- Screen Sharing och Remote Desktop körs samtidigt
- **Fix:** Stäng en av dem

### 4. System Viloläge
- Mac går i viloläge och stänger VNC
- **Fix:** Förhindra viloläge

### 5. TCP Keepalive
- TCP-anslutningar timeoutar
- **Fix:** Öka keepalive-värden

---

## 🔧 FIXAR

### 1. Förhindra Viloläge

```bash
# Förhindra display sleep
sudo pmset -a displaysleep 0

# Förhindra disk sleep
sudo pmset -a disksleep 0

# Förhindra system sleep (endast när ansluten till ström)
sudo pmset -c sleep 0
```

**Återställ:**
```bash
sudo pmset -a displaysleep 10
sudo pmset -a disksleep 10
sudo pmset -c sleep 0
```

---

### 2. Öka TCP Keepalive

```bash
# Öka keepalive timeout
sudo sysctl -w net.inet.tcp.keepidle=60000
sudo sysctl -w net.inet.tcp.keepintvl=10000
sudo sysctl -w net.inet.tcp.keepalive=1
```

**Permanent (lägg till i /etc/sysctl.conf):**
```
net.inet.tcp.keepidle=60000
net.inet.tcp.keepintvl=10000
net.inet.tcp.keepalive=1
```

---

### 3. Stäng Konflikterande VNC Servrar

```bash
# Stäng Screen Sharing
sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.screensharing.plist

# Stäng Remote Desktop
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -configure -access -off
```

---

### 4. Öka VNC Timeout (Remote Desktop)

```bash
# Öka timeout för Remote Desktop
sudo defaults write /Library/Preferences/com.apple.RemoteDesktop.plist DisconnectTime -int 0
```

---

## 📋 CHECKLIST

- [ ] Kontrollera att endast EN VNC server körs
- [ ] Förhindra system viloläge
- [ ] Öka TCP keepalive timeout
- [ ] Kontrollera nätverksanslutning
- [ ] Kontrollera firewall inställningar

---

## 💡 REKOMMENDATIONER

1. **Använd endast Screen Sharing** (inte Remote Desktop samtidigt)
2. **Förhindra viloläge** när VNC används
3. **Öka keepalive timeout** för stabilare anslutningar
4. **Kontrollera nätverksanslutning** för packet loss

---

**Status:** 🔍 **DIAGNOSTISERAR PROBLEM**

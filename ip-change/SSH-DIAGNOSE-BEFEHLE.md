# SSH-Diagnose Befehle für SLES (über ESX Webconsole)

## 🔍 Schnelle Diagnose-Befehle

Führen Sie diese Befehle nacheinander in der ESX-Webconsole aus:

### 1. IP-Adressen prüfen
```bash
ip addr show
```
**Erwartung:** Beide IPs (alte und neue) sollten sichtbar sein

---

### 2. SSH-Dienst Status
```bash
systemctl status sshd
```
**Erwartung:** `active (running)` in grün

**Falls nicht aktiv:**
```bash
sudo systemctl start sshd
sudo systemctl enable sshd
```

---

### 3. SSH hört auf welchen IPs?
```bash
ss -tlnp | grep sshd
```
**Problem:** Wenn nur `127.0.0.1:22` oder alte IP sichtbar ist

**Lösung:**
```bash
# Prüfe SSH-Konfiguration
grep "^ListenAddress" /etc/ssh/sshd_config

# Falls ListenAddress auf alte IP zeigt:
sudo sed -i 's/^ListenAddress/#ListenAddress/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

---

### 4. Firewall prüfen
```bash
# Firewall-Status
sudo firewall-cmd --state

# SSH erlaubt?
sudo firewall-cmd --list-services | grep ssh

# Falls SSH nicht erlaubt:
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload
```

---

### 5. Routing prüfen
```bash
# Default Gateway
ip route show

# Gateway erreichbar?
ping -c 3 9.125.190.1
```

---

### 6. SSH-Logs prüfen
```bash
# Letzte SSH-Fehler
journalctl -u sshd -n 50 --no-pager | tail -20

# Echtzeit-Logs (während Sie SSH-Verbindung versuchen)
journalctl -u sshd -f
```

---

### 7. Netzwerk-Konfiguration prüfen
```bash
# Interface-Konfiguration
cat /etc/sysconfig/network/ifcfg-eth0

# Routing-Konfiguration
cat /etc/sysconfig/network/routes

# DNS-Konfiguration
cat /etc/sysconfig/network/config
```

---

### 8. Wicked-Status
```bash
# Wicked-Dienst
systemctl status wickedd

# Interface-Status
wicked ifstatus eth0

# Alle Interfaces
wicked show all
```

---

## 🔧 Häufigste Probleme und Lösungen

### Problem 1: SSH hört nur auf 127.0.0.1

**Diagnose:**
```bash
ss -tlnp | grep sshd
# Zeigt nur: 127.0.0.1:22
```

**Lösung:**
```bash
# Entferne ListenAddress-Einschränkung
sudo sed -i 's/^ListenAddress/#ListenAddress/' /etc/ssh/sshd_config

# SSH neu starten
sudo systemctl restart sshd

# Prüfen
ss -tlnp | grep sshd
# Sollte jetzt zeigen: 0.0.0.0:22 oder *:22
```

---

### Problem 2: Firewall blockiert neue IP

**Diagnose:**
```bash
sudo firewall-cmd --list-all
```

**Lösung:**
```bash
# SSH erlauben
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload

# Prüfen
sudo firewall-cmd --list-services
```

---

### Problem 3: SSH-Dienst läuft nicht

**Diagnose:**
```bash
systemctl status sshd
```

**Lösung:**
```bash
# Starten
sudo systemctl start sshd

# Automatisch starten
sudo systemctl enable sshd

# Status prüfen
systemctl status sshd
```

---

### Problem 4: Routing-Problem

**Diagnose:**
```bash
ip route show
# Prüfe ob Default-Gateway vorhanden ist
```

**Lösung:**
```bash
# Prüfe routes-Datei
cat /etc/sysconfig/network/routes

# Falls Gateway fehlt, manuell hinzufügen:
echo "default 9.125.190.1 - eth0" | sudo tee -a /etc/sysconfig/network/routes

# Netzwerk neu laden
sudo wicked ifreload all
```

---

## 🚀 Schnell-Fix (wenn alles andere fehlschlägt)

```bash
# 1. SSH-Konfiguration zurücksetzen
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sudo sed -i 's/^ListenAddress/#ListenAddress/' /etc/ssh/sshd_config

# 2. Firewall SSH erlauben
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload

# 3. SSH neu starten
sudo systemctl restart sshd

# 4. Status prüfen
systemctl status sshd
ss -tlnp | grep sshd

# 5. Von anderem Server testen
# ssh user@neue-ip
```

---

## 📊 Vollständige Diagnose (alle Befehle auf einmal)

```bash
echo "=== IP-Adressen ==="
ip addr show | grep -E "inet |^[0-9]:"

echo -e "\n=== SSH-Status ==="
systemctl status sshd | grep Active

echo -e "\n=== SSH Listening ==="
ss -tlnp | grep sshd

echo -e "\n=== Firewall ==="
sudo firewall-cmd --list-services 2>/dev/null || echo "Firewall nicht aktiv"

echo -e "\n=== Routing ==="
ip route show | head -3

echo -e "\n=== Gateway-Test ==="
ping -c 2 $(ip route show | grep default | awk '{print $3}' | head -n 1)

echo -e "\n=== SSH-Logs (letzte 10) ==="
journalctl -u sshd -n 10 --no-pager
```

---

## 🎯 Nach dem Fix: Verbindung testen

Von einem anderen Server:
```bash
# Mit neuer IP
ssh -v user@9.125.190.41

# Mit alter IP (sollte auch noch funktionieren)
ssh -v user@9.155.64.151
```

---

## 💡 Tipps

1. **Beide IPs sollten funktionieren** - alte und neue
2. **SSH muss auf 0.0.0.0:22 hören** - nicht nur auf einer spezifischen IP
3. **Firewall muss SSH erlauben** - auf allen Interfaces
4. **Gateway muss erreichbar sein** - sonst keine externe Verbindung

---

## 📞 Wenn nichts hilft

```bash
# Rollback durchführen
sudo ./rollback-sles.sh backups/hostname_TIMESTAMP

# Oder manuell:
sudo cp backups/hostname_TIMESTAMP/ifcfg-* /etc/sysconfig/network/
sudo wicked ifreload all
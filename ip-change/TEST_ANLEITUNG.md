# Test-Anleitung für network-update.yml

## 🧪 Lokaler Test (auf der VM selbst)

### Voraussetzungen:
- Sie sind auf der VM eingeloggt (z.B. itcoavp151)
- Ansible ist installiert
- Sie haben Root-Rechte

### Test-Schritte:

```bash
# 1. In das Verzeichnis wechseln
cd /path/to/ip-change

# 2. Dry-Run durchführen (zeigt nur was passieren würde)
ansible-playbook -i localhost, -c local network-update.yml --check

# 3. Ausgabe prüfen:
# - Sollte Hostname korrekt erkennen (z.B. itcoavp151.itc.ibm.com)
# - Sollte passenden CSV-Eintrag finden
# - Sollte alle Felder korrekt identifizieren
```

### Erwartete Ausgabe (Beispiel):
```
TASK [Debug - Zeige aktuelle Hostnamen]
ok: [localhost] => {
    "msg": [
        "=== HOSTNAME IDENTIFIKATION ===",
        "Hostname (short): itcoavp151",
        "Hostname (FQDN): itcoavp151.itc.ibm.com"
    ]
}

TASK [Debug - Zeige ALLE identifizierten Felder]
ok: [localhost] => {
    "msg": [
        "=== IDENTIFIZIERTE KONFIGURATION ===",
        "Aktueller Hostname: itcoavp151.itc.ibm.com",
        "",
        "Gefundener CSV-Eintrag:",
        "  Hostname-alt: itcoavp151.itc.ibm.com",
        "  Hostname-neu: itcopreq41.itc.ibm.com",
        "  Ip-alt (9.x): 9.155.64.151",
        "  ip-neu (9.x): 9.125.190.41",
        "  10-alt (10.x): 10.10.64.151",
        "  10-neu (10.x): 10.10.64.41"
    ]
}
```

## 🌐 Remote Test (von einem anderen System)

### Voraussetzungen:
- Ansible ist auf dem Control Node installiert
- SSH-Zugriff zur Ziel-VM
- SSH-Key oder Passwort für Root-Zugriff

### Test-Schritte:

```bash
# 1. Inventory-Datei anpassen
nano inventory.ini

# Beispiel-Eintrag:
# [redhat_vms]
# itcoavp151.itc.ibm.com ansible_host=9.155.64.151 ansible_user=root

# 2. SSH-Verbindung testen
ssh root@9.155.64.151

# 3. Ansible Ping testen
ansible -i inventory.ini redhat_vms -m ping

# 4. Dry-Run durchführen
ansible-playbook -i inventory.ini network-update.yml --check

# 5. Mit Passwort-Abfrage (falls kein SSH-Key)
ansible-playbook -i inventory.ini network-update.yml --check --ask-pass
```

## 🔍 Troubleshooting

### Problem: "Hostname (short): " und "Hostname (FQDN): " sind leer

**Ursache:** Bei lokaler Ausführung auf `localhost` liefern die `hostname` Befehle manchmal leere Werte.

**Lösung:** Das Script verwendet automatisch Ansible Facts als Fallback:
- `ansible_hostname` für Short-Name
- `ansible_fqdn` für FQDN

**Prüfen Sie die Debug-Ausgabe:**
```
TASK [Debug - Zeige rohe Hostname-Ausgaben]
ok: [localhost] => {
    "msg": [
        "hostname -s output: ''",
        "hostname -f output: ''",
        "ansible_hostname: 'itcoavp151'",
        "ansible_fqdn: 'itcoavp151.itc.ibm.com'"
    ]
}
```

### Problem: "FQDN-Suche: Nicht gefunden"

**Mögliche Ursachen:**
1. Hostname stimmt nicht mit CSV überein
2. CSV-Datei hat Formatierungsfehler
3. Hostname hat Leerzeichen oder andere Zeichen

**Lösungsschritte:**

```bash
# 1. CSV validieren
./validate-csv.sh

# 2. CSV bereinigen falls nötig
./fix-csv.sh

# 3. Aktuellen Hostname prüfen
hostname -f
# oder
hostnamectl --static

# 4. In CSV suchen
grep $(hostname -s) ip-change.csv
```

### Problem: CSV-Datei wird nicht gefunden

**Lösung:**
```bash
# Prüfen ob Datei existiert
ls -la ip-change.csv

# Pfad explizit angeben
ansible-playbook network-update.yml -e "csv_file=/vollständiger/pfad/zu/ip-change.csv"
```

## ✅ Checkliste vor produktiver Ausführung

- [ ] CSV-Datei mit `./validate-csv.sh` geprüft
- [ ] Dry-Run erfolgreich durchgeführt (`--check`)
- [ ] Hostname wird korrekt erkannt
- [ ] Passender CSV-Eintrag wird gefunden
- [ ] Alle 6 Felder werden korrekt identifiziert
- [ ] Backup-Verzeichnis ist beschreibbar
- [ ] Console/IPMI-Zugriff zur VM ist verfügbar (für Notfall)
- [ ] Rollback-Script ist getestet

## 🚀 Produktive Ausführung

Erst nach erfolgreichen Tests:

```bash
# Lokal
ansible-playbook -i localhost, -c local network-update.yml

# Remote
ansible-playbook -i inventory.ini network-update.yml
```

## 📊 Erwartete Änderungen

Nach erfolgreicher Ausführung:

1. **Hostname geändert:**
   ```bash
   hostname -f
   # Sollte neuen Hostname zeigen
   ```

2. **IP-Adressen geändert:**
   ```bash
   ip addr show
   # Sollte neue IPs zeigen
   ```

3. **Netzwerk funktioniert:**
   ```bash
   ping -c 3 9.125.190.1  # Gateway
   ping -c 3 8.8.8.8      # Internet
   ```

4. **Backup erstellt:**
   ```bash
   ls -la backups/
   # Sollte neues Backup-Verzeichnis zeigen
   ```

5. **Log erstellt:**
   ```bash
   ls -la logs/
   # Sollte neue Log-Datei zeigen
   ```

## 🔄 Rollback bei Problemen

Falls etwas schief geht:

```bash
# Neuestes Backup wiederherstellen
sudo ./rollback.sh

# Oder spezifisches Backup
sudo ./rollback.sh hostname_20260313_083000
```

## 📝 Hinweise

- **Immer zuerst Dry-Run:** `--check --diff`
- **Schrittweise vorgehen:** Erst ein Host, dann mehrere
- **Logs prüfen:** Nach jeder Ausführung
- **Backup-Zugriff:** Console/IPMI sollte verfügbar sein
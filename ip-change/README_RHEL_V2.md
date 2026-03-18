# RHEL/Oracle Linux IP-Migration Playbook v2.0

## Übersicht

Dieses Playbook migriert IP-Adressen und Hostnamen auf RHEL/Oracle Linux Systemen basierend auf einer CSV-Datei. Es identifiziert Systeme **anhand ihrer aktuellen IP-Adressen** (nicht Hostnamen) und führt umfassende Vorabprüfungen durch.

## Hauptmerkmale

### ✅ CSV-basierte System-Identifikation
- Erkennt Systeme anhand **aktueller IPs** (9.x oder 10.x, alt oder neu)
- Funktioniert auch bei bereits geänderten Hostnamen
- Unterstützt teilweise migrierte Systeme

### ✅ Umfassende Vorabprüfungen
- NetworkManager Status
- Vorhandene Interface-Konfigurationen
- Aktuelle IP-Adressen und Interfaces
- CSV-Validierung

### ✅ Detailliertes Logging
- Zeitgestempelte Log-Einträge
- Vollständige Migrations-Historie
- Vor/Nach-Vergleich der Netzwerk-Konfiguration
- Log-Datei: `/var/log/ansible-ip-migration/migration-YYYYMMDDTHHMMSS.log`

### ✅ Backup und Rollback
- Automatisches Backup aller Konfigurationsdateien
- Snapshot der IP-Konfiguration vor/nach Migration
- Automatisch generiertes Rollback-Script
- Backup-Verzeichnis: `/root/network-backup-<timestamp>/`

### ✅ Sichere Netzwerk-Änderungen
- Verwendet `nmcli device reapply` (keine Verbindungsunterbrechung)
- Fallback auf `nmcli connection up`
- Asynchrone Ausführung mit Timeout

## Voraussetzungen

### System-Anforderungen
- RHEL/Oracle Linux 7.x oder 8.x
- NetworkManager installiert und aktiv
- Root-Rechte (become: yes)
- Ansible 2.9 oder höher

### Erforderliche Dateien
1. **CSV-Datei** (`ip-change.csv`) mit Spalten:
   - `Hostname-alt` - Alter FQDN
   - `Hostname-neu` - Neuer FQDN
   - `Ip-alt` - Alte 9.x IP
   - `ip-neu` - Neue 9.x IP
   - `10-alt` - Alte 10.x IP
   - `10-neu` - Neue 10.x IP

2. **Template-Datei** (`ifcfg-template.j2`) für Interface-Konfiguration

### CSV-Format Beispiel
```csv
Hostname-alt;Hostname-neu;Ip-alt;ip-neu;10-alt;10-neu
itcoavp190.itc.ibm.com;itcopreq52.itc.ibm.com;9.155.64.190;9.125.190.52;10.10.64.190;10.10.64.52
```

## Verwendung

### 1. Vorbereitung

```bash
# Wechsle ins Arbeitsverzeichnis
cd /home/ansible/ansible-mr-tower/ip-change

# Prüfe CSV-Datei
cat ip-change.csv

# Prüfe Template
cat ifcfg-template.j2
```

### 2. Playbook ausführen

```bash
# Einzelnes System
ansible-playbook -i "9.155.64.190," network-update-rhel-v2.yml

# Mehrere Systeme aus Inventory
ansible-playbook -i inventory.ini network-update-rhel-v2.yml

# Mit zusätzlichem Logging
ansible-playbook -i "9.155.64.190," network-update-rhel-v2.yml -v
```

### 3. Nach der Migration

```bash
# Prüfe neue IP-Konfiguration
ip addr

# Prüfe neuen Hostname
hostname -f

# Prüfe Log-Datei
cat /var/log/ansible-ip-migration/migration-*.log

# System neu starten (empfohlen)
reboot
```

## System-Identifikation

Das Playbook identifiziert Systeme in dieser Reihenfolge:

1. **9.x IP (alt)** - Suche nach `Ip-alt` in aktuellen IPs
2. **9.x IP (neu)** - Suche nach `ip-neu` in aktuellen IPs
3. **10.x IP (alt)** - Suche nach `10-alt` in aktuellen IPs
4. **10.x IP (neu)** - Suche nach `10-neu` in aktuellen IPs

**Vorteil:** Funktioniert auch wenn:
- Hostname bereits geändert wurde
- Eine IP bereits migriert wurde
- System teilweise konfiguriert ist

## Ablauf

### Phase 1: Initialisierung
1. Log-Verzeichnis erstellen
2. Log-Datei initialisieren
3. System-Informationen sammeln

### Phase 2: CSV-Verarbeitung
1. CSV-Datei laden und validieren
2. Netzwerk-Interfaces identifizieren
3. System anhand IPs in CSV finden
4. Migrations-Plan erstellen

### Phase 3: Vorabprüfungen
1. NetworkManager Status prüfen
2. Vorhandene ifcfg-Dateien finden
3. Interfaces identifizieren (9.x und 10.x)
4. Migrations-Plan anzeigen

### Phase 4: Backup
1. Backup-Verzeichnis erstellen
2. Hostname-Dateien sichern
3. Netzwerk-Konfiguration sichern
4. IP-Konfiguration snapshot

### Phase 5: Migration
1. Hostname ändern (`/etc/hostname`, `/etc/hosts`)
2. 9.x Interface konfigurieren
3. 10.x Interface konfigurieren
4. Netzwerk-Änderungen anwenden

### Phase 6: Validierung
1. Neue IP-Konfiguration sammeln
2. Vor/Nach-Vergleich erstellen
3. Rollback-Script generieren
4. Abschluss-Log schreiben

## Logging

### Log-Struktur
```
/var/log/ansible-ip-migration/
└── migration-20260318T203000.log
```

### Log-Inhalt
- Zeitgestempelte Einträge
- System-Informationen
- CSV-Identifikation
- Interface-Erkennung
- Migrations-Schritte
- Vor/Nach-Vergleich

### Beispiel-Log
```
================================================================================
RHEL/Oracle Linux IP-Migration Log
================================================================================
Start: 2026-03-18T20:30:00+01:00
Host: itcoavp190
IP: 9.155.64.190
OS: RedHat 8.5
================================================================================

[20:30:01] CSV-Datei geladen: 16 Einträge
[20:30:02] Gefundene Interfaces:
ens33 9.155.64.190/25
[20:30:03] System in CSV identifiziert:
[20:30:03]   Hostname-alt: itcoavp190.itc.ibm.com
[20:30:03]   Hostname-neu: itcopreq52.itc.ibm.com
[20:30:03]   9.x IP-alt: 9.155.64.190
[20:30:03]   9.x IP-neu: 9.125.190.52
[20:30:04] Backup erstellt: /root/network-backup-1710792600
[20:30:05] Hostname geändert: itcoavp190 → itcopreq52.itc.ibm.com
[20:30:06] 9.x Interface konfiguriert: ens33 → 9.125.190.52/25
[20:30:07] 10.x Interface konfiguriert: ens35 → 10.10.64.52/24
[20:30:08] Netzwerk-Änderungen angewendet
================================================================================
Migration abgeschlossen
================================================================================
```

## Backup und Rollback

### Backup-Verzeichnis
```
/root/network-backup-<timestamp>/
├── hostname                          # Alte /etc/hostname
├── hosts                            # Alte /etc/hosts
├── ifcfg-ens33                      # Alte Interface-Konfiguration
├── ifcfg-ens35                      # Alte Interface-Konfiguration
├── ip-addr-before.txt               # IP-Konfiguration vor Migration
├── ip-route-before.txt              # Routing-Tabelle vor Migration
├── nmcli-connections-before.txt     # NetworkManager Connections vor Migration
├── ip-addr-after.txt                # IP-Konfiguration nach Migration
├── ip-route-after.txt               # Routing-Tabelle nach Migration
└── rollback.sh                      # Automatisches Rollback-Script
```

### Rollback durchführen

```bash
# Finde neuestes Backup
ls -lt /root/network-backup-* | head -1

# Führe Rollback aus
bash /root/network-backup-<timestamp>/rollback.sh

# System neu starten
reboot
```

### Manuelles Rollback

```bash
# Hostname zurücksetzen
hostnamectl set-hostname <alter-hostname>

# Netzwerk-Konfiguration zurücksetzen
cp /root/network-backup-<timestamp>/ifcfg-* /etc/sysconfig/network-scripts/

# NetworkManager neu starten
systemctl restart NetworkManager

# System neu starten
reboot
```

## Fehlerbehandlung

### Problem: System nicht in CSV gefunden

**Symptom:**
```
FEHLER: System konnte nicht in CSV identifiziert werden!
Aktuelle IPs: 9.155.64.190, 10.10.64.190
```

**Lösung:**
1. Prüfe ob eine der aktuellen IPs in der CSV vorhanden ist
2. Prüfe CSV-Format (Semikolon-getrennt)
3. Prüfe Spalten-Namen (Groß-/Kleinschreibung beachten)

### Problem: NetworkManager nicht aktiv

**Symptom:**
```
WARNUNG: NetworkManager ist nicht aktiv. Netzwerk-Neustart könnte fehlschlagen!
```

**Lösung:**
```bash
# NetworkManager starten
systemctl start NetworkManager
systemctl enable NetworkManager

# Playbook erneut ausführen
```

### Problem: Interface nicht gefunden

**Symptom:**
```
FEHLER: Konnte kein Interface mit 9.x IP identifizieren!
```

**Lösung:**
1. Prüfe aktuelle IP-Konfiguration: `ip addr`
2. Prüfe ob 9.x IP vorhanden ist
3. Prüfe ob Interface aktiv ist: `ip link show`

### Problem: Netzwerk-Verbindung verloren

**Symptom:**
- SSH-Verbindung bricht ab
- System nicht mehr erreichbar

**Lösung:**
1. Zugriff über Console (VMware, iLO, etc.)
2. Rollback durchführen: `bash /root/network-backup-*/rollback.sh`
3. System neu starten: `reboot`

## Unterschiede zu v1

| Feature | v1 (network-update.yml) | v2 (network-update-rhel-v2.yml) |
|---------|------------------------|--------------------------------|
| System-Identifikation | Hostname-basiert | IP-basiert |
| Vorabprüfungen | Basis | Umfassend |
| Logging | Minimal | Detailliert mit Timestamps |
| Backup | Basis | Vollständig mit Vor/Nach-Vergleich |
| Rollback | Manuell | Automatisches Script |
| Teilweise migrierte Systeme | Problematisch | Unterstützt |
| Idempotenz | Eingeschränkt | Vollständig |

## Best Practices

### Vor der Migration
1. ✅ CSV-Datei validieren
2. ✅ Backup des Systems erstellen (VM-Snapshot)
3. ✅ Test auf einem System durchführen
4. ✅ Wartungsfenster planen

### Während der Migration
1. ✅ Log-Ausgabe beobachten
2. ✅ Bei Fehlern sofort stoppen
3. ✅ Backup-Verzeichnis notieren

### Nach der Migration
1. ✅ IP-Konfiguration prüfen (`ip addr`)
2. ✅ Hostname prüfen (`hostname -f`)
3. ✅ Netzwerk-Konnektivität testen (`ping`)
4. ✅ Log-Datei prüfen
5. ✅ System neu starten (empfohlen)

## Sicherheit

### Berechtigungen
- Playbook benötigt Root-Rechte (`become: yes`)
- Log-Dateien: `0644` (lesbar für alle)
- Backup-Verzeichnis: `0700` (nur Root)
- Rollback-Script: `0755` (ausführbar)

### Sensible Daten
- CSV-Datei enthält IP-Adressen und Hostnamen
- Log-Dateien enthalten vollständige Netzwerk-Konfiguration
- Backup-Verzeichnis enthält alte Konfigurationen

**Empfehlung:** Logs und Backups nach erfolgreicher Migration archivieren oder löschen.

## Support

Bei Problemen:
1. Log-Datei prüfen: `/var/log/ansible-ip-migration/migration-*.log`
2. Backup-Verzeichnis prüfen: `/root/network-backup-*/`
3. Ansible-Ausgabe mit `-vvv` wiederholen
4. Rollback durchführen falls nötig

## Changelog

### v2.0 (2026-03-18)
- ✨ CSV-basierte System-Identifikation (anhand IPs)
- ✨ Umfassende Vorabprüfungen
- ✨ Detailliertes Logging mit Timestamps
- ✨ Vollständiges Backup mit Vor/Nach-Vergleich
- ✨ Automatisches Rollback-Script
- ✨ Unterstützung für teilweise migrierte Systeme
- ✨ Verbesserte Fehlerbehandlung
- ✨ Idempotenz-Unterstützung

### v1.0
- Initiale Version mit Hostname-basierter Identifikation
# IP-Change Projekt - Übersicht

## 📁 Projektstruktur

```
ip-change/
├── ip-change.csv                      # CSV-Datei mit IP-Änderungsdaten
├── ip-change.csv.backup               # Backup der Original-CSV
│
├── network-update.yml                 # RHEL/Oracle Linux Playbook
├── network-update-ubuntu.yml          # Ubuntu Playbook (NEU)
│
├── ifcfg-template.j2                  # Template für RHEL/Oracle Linux
├── netplan-template.j2                # Template für Ubuntu (NEU)
│
├── inventory.ini                      # Ansible Inventory-Beispiel
│
├── rollback.sh                        # Rollback für RHEL/Oracle Linux
├── rollback-ubuntu.sh                 # Rollback für Ubuntu (NEU)
│
├── validate-csv.sh                    # CSV-Validierungs-Script
├── fix-csv.sh                         # CSV-Bereinigungsscript
│
├── README.md                          # Dokumentation RHEL/Oracle Linux
├── README_UBUNTU.md                   # Dokumentation Ubuntu (NEU)
├── SCHNELLSTART.md                    # Schnellstart-Anleitung
├── TEST_ANLEITUNG.md                  # Test-Anleitung
├── PROJEKT_UEBERSICHT.md              # Diese Datei
├── ORACLE_LINUX_KOMPATIBILITAET.md    # Oracle Linux Details
├── UBUNTU_KOMPATIBILITAET.md          # Ubuntu Details (NEU)
│
├── backups/                           # Backup-Verzeichnis (wird erstellt)
└── logs/                              # Log-Verzeichnis (wird erstellt)
```

## 🎯 Hauptkomponenten

### Unterstützte Betriebssysteme:

| OS | Playbook | Template | Rollback |
|----|----------|----------|----------|
| **RHEL 7/8/9** | [`network-update.yml`](network-update.yml:1) | [`ifcfg-template.j2`](ifcfg-template.j2:1) | [`rollback.sh`](rollback.sh:1) |
| **Oracle Linux 7/8/9** | [`network-update.yml`](network-update.yml:1) | [`ifcfg-template.j2`](ifcfg-template.j2:1) | [`rollback.sh`](rollback.sh:1) |
| **Ubuntu 18.04-24.04** | [`network-update-ubuntu.yml`](network-update-ubuntu.yml:1) | [`netplan-template.j2`](netplan-template.j2:1) | [`rollback-ubuntu.sh`](rollback-ubuntu.sh:1) |

### 1. Ansible Playbook RHEL/Oracle Linux ([`network-update.yml`](network-update.yml:1))
**Zweck:** Automatisiert die Netzwerkkonfiguration auf Red Hat/Oracle Linux VMs

**Features:**
- ✅ Liest CSV-Datei ein und identifiziert Host
- ✅ Validiert aktuelle Konfiguration gegen CSV
- ✅ Erstellt automatische Backups
- ✅ Ändert Hostname und beide Netzwerkinterfaces
- ✅ Setzt Gateway (9.125.190.1) und Netzmaske (255.255.255.128)
- ✅ Startet Netzwerk neu
- ✅ Validiert Änderungen
- ✅ Erstellt detaillierte Logs

**Verwendung:**
```bash
# Lokal
ansible-playbook -i localhost, -c local network-update.yml --check

# Remote
ansible-playbook -i inventory.ini network-update.yml
```

### 1b. Ansible Playbook Ubuntu ([`network-update-ubuntu.yml`](network-update-ubuntu.yml:1))
**Zweck:** Automatisiert die Netzwerkkonfiguration auf Ubuntu Linux VMs

**Features:**
- ✅ Netplan-Unterstützung (Ubuntu 18.04+)
- ✅ YAML-basierte Konfiguration
- ✅ Netplan-Validierung vor Anwendung
- ✅ Unterstützt Ubuntu 18.04, 20.04, 22.04, 24.04 LTS

**Verwendung:**
```bash
# Lokal
ansible-playbook -i localhost, -c local network-update-ubuntu.yml --check

# Remote
ansible-playbook -i inventory.ini network-update-ubuntu.yml
```

### 2. Netzwerk-Templates

#### RHEL/Oracle Linux Template ([`ifcfg-template.j2`](ifcfg-template.j2:1))
**Zweck:** Jinja2-Template für Red Hat Netzwerk-Interface-Konfiguration

**Generiert:** `/etc/sysconfig/network-scripts/ifcfg-*` Dateien

#### Ubuntu Template ([`netplan-template.j2`](netplan-template.j2:1))
**Zweck:** Jinja2-Template für Ubuntu Netplan-Konfiguration

**Generiert:** `/etc/netplan/01-netcfg.yaml` Datei

### 3. Inventory-Datei ([`inventory.ini`](inventory.ini:1))
**Zweck:** Ansible Inventory für Remote-Ausführung

**Anpassen für Ihre Umgebung:**
```ini
[redhat_vms]
ihr-host.domain.com ansible_host=9.155.64.xxx ansible_user=root
```

### 4. Rollback-Scripts

#### RHEL/Oracle Linux ([`rollback.sh`](rollback.sh:1))
**Zweck:** Stellt Konfiguration aus Backup wieder her

**Features:**
- ✅ Listet verfügbare Backups
- ✅ Verwendet neuestes Backup automatisch
- ✅ Stellt Hostname und Netzwerk-Interfaces wieder her
- ✅ Startet Netzwerk neu mit NetworkManager

**Verwendung:**
```bash
# Neuestes Backup verwenden
sudo ./rollback.sh

# Spezifisches Backup
sudo ./rollback.sh hostname_20260313_083000

# Backups auflisten
./rollback.sh --list
```

#### Ubuntu ([`rollback-ubuntu.sh`](rollback-ubuntu.sh:1))
**Zweck:** Stellt Ubuntu Netplan-Konfiguration aus Backup wieder her

**Features:**
- ✅ Listet verfügbare Backups
- ✅ Verwendet neuestes Backup automatisch
- ✅ Stellt Hostname und Netzwerk-Interfaces wieder her
- ✅ Startet Netzwerk neu

**Features:**
- ✅ Listet verfügbare Backups
- ✅ Stellt Netplan-Konfiguration wieder her
- ✅ Verwendet `netplan try` für sicheren Rollback
- ✅ 120 Sekunden Timeout mit automatischem Rollback

**Verwendung:**
```bash
# Neuestes Backup verwenden
sudo ./rollback-ubuntu.sh

# Spezifisches Backup
sudo ./rollback-ubuntu.sh hostname_20260313_083000

# Backups auflisten
./rollback-ubuntu.sh --list
```

### 5. CSV-Validierung ([`validate-csv.sh`](validate-csv.sh:1))
**Zweck:** Prüft CSV-Datei auf Fehler

**Prüfungen:**
- ✅ Header-Format
- ✅ Leere Felder
- ✅ Hostname-Format
- ✅ IP-Adress-Format (9.x und 10.x)
- ✅ Subnetz-Konsistenz
- ✅ Duplikate

**Verwendung:**
```bash
./validate-csv.sh
./validate-csv.sh /path/to/other.csv
```

### 6. CSV-Bereinigung ([`fix-csv.sh`](fix-csv.sh:1))
**Zweck:** Bereinigt CSV-Datei von häufigen Problemen

**Bereinigt:**
- ✅ BOM (Byte Order Mark)
- ✅ Windows-Zeilenenden
- ✅ Leerzeichen in Hostnamen
- ✅ Führende/nachfolgende Leerzeichen

**Verwendung:**
```bash
./fix-csv.sh
```

## 📊 CSV-Daten ([`ip-change.csv`](ip-change.csv:1))

### Format:
```csv
Hostname-alt;Hostname-neu;Ip-alt;ip-neu;10-alt;10-neu
itcoavp147.itc.ibm.com;itcopreq40.itc.ibm.com;9.155.64.147;9.125.190.40;10.10.64.147;10.10.64.40
```

### Spalten:
| Spalte | Beschreibung | Beispiel |
|--------|--------------|----------|
| Hostname-alt | Aktueller Hostname | itcoavp147.itc.ibm.com |
| Hostname-neu | Neuer Hostname | itcopreq40.itc.ibm.com |
| Ip-alt | Aktuelle 9.x IP | 9.155.64.147 |
| ip-neu | Neue 9.x IP | 9.125.190.40 |
| 10-alt | Aktuelle 10.x IP | 10.10.64.147 |
| 10-neu | Neue 10.x IP | 10.10.64.40 |

### Statistik:
- **Anzahl Hosts:** 16
- **IP-Bereich alt:** 9.155.64.x
- **IP-Bereich neu:** 9.125.190.x
- **Internes Netz:** 10.10.64.x

## 🚀 Workflow

### Vorbereitung:
```bash
# 1. CSV-Datei bereinigen
./fix-csv.sh

# 2. CSV-Datei validieren
./validate-csv.sh

# 3. Inventory anpassen (für Remote)
nano inventory.ini
```

### Ausführung:
```bash
# 4. Dry-Run durchführen
ansible-playbook -i inventory.ini network-update.yml --check --diff

# 5. Tatsächlich ausführen
ansible-playbook -i inventory.ini network-update.yml
```

### Im Fehlerfall:
```bash
# 6. Rollback durchführen
sudo ./rollback.sh
```

## 📝 Änderungen pro Host

Für jeden Host werden folgende Änderungen durchgeführt:

### 1. Hostname
- **Datei:** `/etc/hostname`
- **Befehl:** `hostnamectl set-hostname`
- **Beispiel:** itcoavp147 → itcopreq40

### 2. Netzwerk-Interface 1 (9.x)
- **Datei:** `/etc/sysconfig/network-scripts/ifcfg-ethX`
- **IP:** Neue 9.x IP aus CSV
- **Gateway:** 9.125.190.1
- **Netmask:** 255.255.255.128 (/25)
- **DEFROUTE:** yes (primäres Interface)

### 3. Netzwerk-Interface 2 (10.x)
- **Datei:** `/etc/sysconfig/network-scripts/ifcfg-ethY`
- **IP:** Neue 10.x IP aus CSV
- **Netmask:** 255.255.255.128 (/25)
- **DEFROUTE:** no (sekundäres Interface)

## 🔒 Sicherheit

### Automatische Backups
Vor jeder Änderung werden Backups erstellt:
```
backups/
└── hostname_20260313_083000/
    ├── hostname
    ├── ifcfg-eth0
    ├── ifcfg-eth1
    └── backup_manifest.txt
```

### Validierung
Das Playbook validiert vor Änderungen:
1. ✅ Host existiert in CSV
2. ✅ Aktuelle IPs stimmen mit CSV überein
3. ✅ Beide Netzwerkinterfaces existieren

**Bei Validierungsfehler wird abgebrochen!**

### Logs
Alle Änderungen werden protokolliert:
```
logs/
└── hostname_20260313_083000.log
```

## 📚 Dokumentation

- **[README.md](README.md:1)** - Ausführliche Dokumentation mit allen Details
- **[SCHNELLSTART.md](SCHNELLSTART.md:1)** - Schnellstart für eilige Admins
- **[PROJEKT_UEBERSICHT.md](PROJEKT_UEBERSICHT.md:1)** - Diese Übersicht

## 🔧 Systemanforderungen

### Control Node (wo Ansible läuft):
- Ansible 2.9+
- Python 3.x
- SSH-Zugriff zu Ziel-VMs (für Remote)

### Ziel-VMs:
- Red Hat Enterprise Linux 7/8/9
- Python 3.x
- Root-Zugriff oder sudo
- Zwei Netzwerkinterfaces (9.x und 10.x)

## 📞 Troubleshooting

### Problem: CSV-Validierung schlägt fehl
**Lösung:**
```bash
./fix-csv.sh
./validate-csv.sh
```

### Problem: Host nicht in CSV gefunden
**Lösung:**
```bash
# Aktuellen Hostname prüfen
hostname -s

# In CSV suchen
grep $(hostname -s) ip-change.csv
```

### Problem: Netzwerk nach Änderung nicht erreichbar
**Lösung:**
```bash
# Rollback durchführen (lokaler Zugriff nötig)
sudo ./rollback.sh
```

### Problem: Ansible kann sich nicht verbinden
**Lösung:**
```bash
# SSH testen
ssh root@9.155.64.147

# Ansible Ping
ansible -i inventory.ini redhat_vms -m ping --ask-pass
```

## 🎓 Best Practices

1. **Immer zuerst Dry-Run:** `--check --diff`
2. **CSV validieren:** `./validate-csv.sh`
3. **Backup-Zugriff sicherstellen:** Console/IPMI verfügbar
4. **Schrittweise vorgehen:** Erst ein Host, dann mehrere
5. **Logs prüfen:** Nach jeder Ausführung
6. **Rollback-Plan:** Immer bereit haben

## 📈 Fortschritt

### Abgeschlossen:
- ✅ Ansible Playbook erstellt
- ✅ Netzwerk-Template erstellt
- ✅ Inventory-Beispiel erstellt
- ✅ Rollback-Script erstellt
- ✅ CSV-Validierung erstellt
- ✅ CSV-Bereinigung erstellt
- ✅ Dokumentation erstellt
- ✅ CSV-Datei bereinigt und validiert

### Bereit für:
- 🚀 Test-Ausführung auf Test-VM
- 🚀 Produktiv-Ausführung

## 📄 Lizenz

Dieses Projekt ist für den internen Gebrauch bei IBM ITC bestimmt.

---

**Erstellt:** 2026-03-13  
**Version:** 1.0  
**Autor:** Automatisierte IP-Migration für IBM ITC Server
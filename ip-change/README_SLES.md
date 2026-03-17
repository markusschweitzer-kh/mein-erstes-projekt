# SLES Netzwerk-Konfiguration Update

Automatisierte Änderung von Hostname und IP-Adressen auf SUSE Linux Enterprise Server (SLES) Systemen mittels Ansible.

## 📋 Inhaltsverzeichnis

- [Überblick](#überblick)
- [Voraussetzungen](#voraussetzungen)
- [Schnellstart](#schnellstart)
- [Detaillierte Anleitung](#detaillierte-anleitung)
- [Verwendung](#verwendung)
- [Rollback](#rollback)
- [Troubleshooting](#troubleshooting)
- [Sicherheit](#sicherheit)

## 🎯 Überblick

Dieses Projekt automatisiert die Änderung von:
- **Hostname** (alt → neu)
- **Primäre IP-Adresse** (9.x Netzwerk)
- **Sekundäre IP-Adresse** (10.x Netzwerk)
- **Gateway und Routing**
- **DNS-Konfiguration**

### Unterstützte SLES-Versionen

| Version | Release | Support bis | Getestet |
|---------|---------|-------------|----------|
| SLES 15 SP5 | 2023 | 2031 | ✅ |
| SLES 15 SP4 | 2022 | 2027 | ✅ |
| SLES 15 SP3 | 2021 | 2025 | ✅ |
| SLES 12 SP5 | 2019 | 2024 | ⚠️ |

### SLES-Spezifika

SLES verwendet **Wicked** als Netzwerk-Management-Framework:
- Konfigurationsdateien: `/etc/sysconfig/network/`
- Interface-Konfiguration: `ifcfg-*` Dateien
- Routing: Separate `routes` Datei
- DNS: Separate `config` Datei
- Management: `wicked` Befehle

## 📦 Voraussetzungen

### Auf dem Control Node (wo Ansible läuft)

```bash
# Ansible installieren
sudo zypper install ansible

# Python-Module
sudo zypper install python3-jinja2
```

### Auf den Ziel-Servern (SLES)

```bash
# Python für Ansible
sudo zypper install python3

# Wicked (normalerweise vorinstalliert)
sudo zypper install wicked

# Optional: SSH-Key-basierte Authentifizierung einrichten
ssh-copy-id user@target-server
```

### Benötigte Dateien

```
ip-change/
├── ip-change.csv                    # CSV mit Host-Daten
├── network-update-sles.yml          # Ansible Playbook
├── ifcfg-sles-template.j2          # Interface-Template
├── routes-sles-template.j2         # Routing-Template
├── rollback-sles.sh                # Rollback-Script
├── remove-old-ip-sles.sh           # IP-Entfernungs-Script
└── README_SLES.md                  # Diese Datei
```

## 🚀 Schnellstart

### 1. CSV-Datei vorbereiten

```csv
Hostname-alt;Hostname-neu;Ip-alt;ip-neu;10-alt;10-neu
sles-server1.example.com;sles-new1.example.com;9.155.64.151;9.125.190.41;10.10.64.151;10.10.64.41
```

### 2. CSV validieren

```bash
./validate-csv.sh
```

### 3. Playbook ausführen

```bash
# Lokal auf dem Server
ansible-playbook -i localhost, -c local network-update-sles.yml

# Remote auf mehreren Servern
ansible-playbook -i inventory.ini network-update-sles.yml
```

### 4. Ergebnis prüfen

```bash
# Hostname prüfen
hostname

# IP-Adressen prüfen
ip addr show

# Wicked-Status prüfen
wicked ifstatus eth0
```

## 📖 Detaillierte Anleitung

### Schritt 1: CSV-Datei erstellen

Die CSV-Datei enthält die Mapping-Informationen für alle Server:

```csv
Hostname-alt;Hostname-neu;Ip-alt;ip-neu;10-alt;10-neu
sles01.old.com;sles01.new.com;9.155.64.151;9.125.190.41;10.10.64.151;10.10.64.41
sles02.old.com;sles02.new.com;9.155.64.152;9.125.190.42;10.10.64.152;10.10.64.42
```

**Wichtig:**
- Trennzeichen: Semikolon (`;`)
- Keine Leerzeichen um die Werte
- UTF-8 Encoding ohne BOM
- Erste Zeile ist Header

### Schritt 2: Inventory erstellen (für Remote-Ausführung)

Erstellen Sie `inventory.ini`:

```ini
[sles_servers]
sles01.old.com ansible_user=root
sles02.old.com ansible_user=root

[sles_servers:vars]
ansible_python_interpreter=/usr/bin/python3
```

### Schritt 3: Dry-Run durchführen

Testen Sie die Änderungen ohne sie anzuwenden:

```bash
ansible-playbook network-update-sles.yml --check --diff
```

### Schritt 4: Backup erstellen

Das Playbook erstellt automatisch Backups in `./backups/`, aber Sie können auch manuell ein Backup erstellen:

```bash
# Backup der Netzwerk-Konfiguration
sudo tar -czf network-backup-$(date +%Y%m%d).tar.gz /etc/sysconfig/network/

# Backup des Hostnamens
hostname > hostname-backup.txt
```

### Schritt 5: Playbook ausführen

#### Lokal auf einem Server

```bash
ansible-playbook -i localhost, -c local network-update-sles.yml
```

#### Remote auf mehreren Servern

```bash
# Alle Server
ansible-playbook -i inventory.ini network-update-sles.yml

# Nur ein Server
ansible-playbook -i inventory.ini network-update-sles.yml --limit sles01.old.com

# Mit Verbose-Output
ansible-playbook -i inventory.ini network-update-sles.yml -v
```

#### Mit spezifischer CSV-Datei

```bash
ansible-playbook network-update-sles.yml -e "csv_file=/path/to/custom.csv"
```

### Schritt 6: Validierung

Nach der Ausführung prüfen Sie:

```bash
# 1. Hostname
hostname
hostnamectl

# 2. IP-Adressen
ip addr show
wicked ifstatus eth0

# 3. Routing
ip route show
cat /etc/sysconfig/network/routes

# 4. DNS
cat /etc/sysconfig/network/config | grep DNS

# 5. Gateway-Erreichbarkeit
ping -c 3 9.125.190.1

# 6. Netzwerk-Konnektivität
ping -c 3 google.com
```

## 🔄 Rollback

Falls etwas schief geht, können Sie die Konfiguration wiederherstellen:

### Automatisches Rollback-Script

```bash
# Liste verfügbare Backups
sudo ./rollback-sles.sh

# Stelle spezifisches Backup wieder her
sudo ./rollback-sles.sh backups/hostname_1234567890
```

### Manuelles Rollback

```bash
# 1. Finde Backup-Verzeichnis
ls -la backups/

# 2. Stelle Konfiguration wieder her
sudo cp backups/hostname_1234567890/ifcfg-* /etc/sysconfig/network/
sudo cp backups/hostname_1234567890/routes /etc/sysconfig/network/
sudo cp backups/hostname_1234567890/config /etc/sysconfig/network/

# 3. Stelle Hostname wieder her
sudo hostnamectl set-hostname $(cat backups/hostname_1234567890/hostname)

# 4. Starte Netzwerk neu
sudo wicked ifreload all
```

## 🛠️ Verwendung

### Alte IP-Adresse entfernen

Nach erfolgreicher Migration können alte IP-Adressen entfernt werden:

```bash
# Liste alle konfigurierten IPs
sudo ./remove-old-ip-sles.sh --list

# Entferne spezifische IP
sudo ./remove-old-ip-sles.sh 9.155.64.146

# Hilfe anzeigen
sudo ./remove-old-ip-sles.sh --help
```

### Wicked-Befehle

```bash
# Interface-Status anzeigen
wicked ifstatus eth0

# Interface neu starten
sudo wicked ifdown eth0
sudo wicked ifup eth0

# Alle Interfaces neu laden
sudo wicked ifreload all

# Konfiguration anzeigen
wicked show-config

# XML-Konfiguration anzeigen
wicked show-xml eth0
```

### Netzwerk-Konfiguration prüfen

```bash
# Interface-Konfiguration
cat /etc/sysconfig/network/ifcfg-eth0

# Routing-Konfiguration
cat /etc/sysconfig/network/routes

# DNS-Konfiguration
cat /etc/sysconfig/network/config

# Aktive Verbindungen
ss -tuln

# Netzwerk-Statistiken
ip -s link show eth0
```

## 🔍 Troubleshooting

### Problem: Wicked startet nicht

```bash
# Prüfe Wicked-Status
systemctl status wickedd

# Starte Wicked-Dienst
sudo systemctl start wickedd

# Prüfe Logs
journalctl -u wickedd -n 50
```

### Problem: Interface kommt nicht hoch

```bash
# Prüfe Interface-Status
wicked ifstatus eth0

# Prüfe Konfiguration
cat /etc/sysconfig/network/ifcfg-eth0

# Manuell hochfahren
sudo wicked ifup eth0

# Debug-Modus
sudo wicked --debug all ifup eth0
```

### Problem: Keine Netzwerk-Verbindung nach Neustart

```bash
# 1. Prüfe IP-Konfiguration
ip addr show

# 2. Prüfe Routing
ip route show

# 3. Prüfe Gateway
ping -c 3 9.125.190.1

# 4. Prüfe DNS
cat /etc/resolv.conf
nslookup google.com

# 5. Starte Netzwerk neu
sudo wicked ifreload all
```

### Problem: SSH-Verbindung verloren

Wenn die SSH-Verbindung während des Updates verloren geht:

1. **Warten Sie 2-3 Minuten** - Das Netzwerk startet neu
2. **Verbinden Sie mit neuer IP**:
   ```bash
   ssh user@9.125.190.41
   ```
3. **Falls nicht erreichbar**: Zugriff über Console (iLO, iDRAC, etc.)
4. **Rollback durchführen** (siehe oben)

### Problem: Hostname wird nicht korrekt gesetzt

```bash
# Prüfe aktuellen Hostname
hostname
hostnamectl

# Setze Hostname manuell
sudo hostnamectl set-hostname new-hostname.example.com

# Prüfe /etc/hostname
cat /etc/hostname

# Prüfe /etc/hosts
cat /etc/hosts
```

### Problem: DNS funktioniert nicht

```bash
# Prüfe DNS-Konfiguration
cat /etc/sysconfig/network/config | grep DNS

# Prüfe /etc/resolv.conf
cat /etc/resolv.conf

# Teste DNS
nslookup google.com 9.0.0.1

# Aktualisiere DNS-Konfiguration
sudo netconfig update -f
```

## 🔒 Sicherheit

### Backup-Strategie

1. **Automatische Backups**: Das Playbook erstellt automatisch Backups
2. **Aufbewahrung**: Backups werden in `./backups/` gespeichert
3. **Retention**: Alte Backups sollten regelmäßig archiviert werden

```bash
# Backup archivieren
tar -czf backups-archive-$(date +%Y%m%d).tar.gz backups/

# Alte Backups löschen (älter als 30 Tage)
find backups/ -type d -mtime +30 -exec rm -rf {} \;
```

### Berechtigungen

```bash
# Setze korrekte Berechtigungen für Konfigurationsdateien
sudo chmod 644 /etc/sysconfig/network/ifcfg-*
sudo chmod 644 /etc/sysconfig/network/routes
sudo chmod 644 /etc/sysconfig/network/config

# Setze korrekte Eigentümer
sudo chown root:root /etc/sysconfig/network/*
```

### Audit-Log

Das Playbook erstellt detaillierte Logs:

```bash
# Logs anzeigen
ls -la logs/

# Letztes Log anzeigen
cat logs/$(ls -t logs/ | head -n 1)
```

## 📊 Konfigurationsbeispiele

### Einfache Konfiguration (eine IP)

`/etc/sysconfig/network/ifcfg-eth0`:
```bash
BOOTPROTO='static'
STARTMODE='auto'
NAME='Primary Network Interface'
IPADDR='9.125.190.41/25'
```

### Erweiterte Konfiguration (zwei IPs)

`/etc/sysconfig/network/ifcfg-eth0`:
```bash
BOOTPROTO='static'
STARTMODE='auto'
NAME='Primary Network Interface'

# Primäre IP
IPADDR='9.125.190.41/25'

# Sekundäre IP
LABEL_0='secondary'
IPADDR_0='10.10.64.41/24'
```

### Routing-Konfiguration

`/etc/sysconfig/network/routes`:
```bash
# Default Gateway
default 9.125.190.1 - eth0

# Lokales Netzwerk
10.10.64.0 0.0.0.0 255.255.255.0 eth0
```

### DNS-Konfiguration

`/etc/sysconfig/network/config`:
```bash
NETCONFIG_DNS_STATIC_SERVERS="9.0.0.1 9.0.0.2"
NETCONFIG_DNS_STATIC_SEARCHLIST=""
```

## 📚 Weitere Ressourcen

- [SLES Dokumentation](https://documentation.suse.com/)
- [Wicked Dokumentation](https://github.com/openSUSE/wicked)
- [Ansible Dokumentation](https://docs.ansible.com/)
- [SLES_KOMPATIBILITAET.md](SLES_KOMPATIBILITAET.md) - Detaillierte Kompatibilitätsinformationen
- [SLES_ANALYSE.md](SLES_ANALYSE.md) - Technische Analyse

## 🤝 Support

Bei Problemen:
1. Prüfen Sie die [Troubleshooting](#troubleshooting) Sektion
2. Überprüfen Sie die Logs in `./logs/`
3. Führen Sie ein Rollback durch wenn nötig
4. Kontaktieren Sie den Support

## 📝 Changelog

### Version 1.0.0 (2024)
- Initiale Version für SLES 15
- Unterstützung für Wicked
- Automatische Backups
- Rollback-Funktionalität
- IP-Entfernungs-Script

---

**Hinweis**: Dieses Projekt ist speziell für SLES optimiert. Für andere Distributionen siehe:
- [README.md](README.md) - RHEL/Oracle Linux
- [README_UBUNTU.md](README_UBUNTU.md) - Ubuntu
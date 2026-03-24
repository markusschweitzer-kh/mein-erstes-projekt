# Ubuntu Netzwerkkonfiguration Update mit Ansible

Dieses Ansible Playbook automatisiert die Änderung von Hostname und Netzwerkkonfiguration auf Ubuntu Linux VMs basierend auf einer CSV-Datei.

## 📋 Inhaltsverzeichnis

- [Features](#features)
- [Voraussetzungen](#voraussetzungen)
- [Installation](#installation)
- [Verwendung](#verwendung)
- [Unterschiede zu RHEL](#unterschiede-zu-rhel)
- [Troubleshooting](#troubleshooting)

## ✨ Features

- ✅ **Automatische Host-Identifikation** - Findet den Host automatisch in der CSV-Datei
- ✅ **Validierung vor Änderungen** - Prüft Hostname und IPs gegen CSV-Daten
- ✅ **Automatisches Backup** - Erstellt Backups aller Konfigurationsdateien
- ✅ **Netplan-Unterstützung** - Verwendet Netplan für moderne Ubuntu-Versionen
- ✅ **Dual-Interface Support** - Unterstützt zwei Netzwerkschnittstellen (9.x und 10.x)
- ✅ **Automatisches Backup** - Erstellt Backups aller Konfigurationsdateien
- ✅ **Detailliertes Logging** - Protokolliert alle Änderungen
- ✅ **Dry-Run Modus** - Testet Änderungen ohne sie durchzuführen
- ✅ **Remote & Lokal** - Kann remote oder lokal ausgeführt werden

## 📦 Voraussetzungen

### Auf dem Control Node (wo Ansible läuft):
```bash
# Ansible installieren
sudo apt update
sudo apt install ansible -y
# oder
pip3 install ansible
```

### Auf den Ziel-VMs:
- Ubuntu 24.04 LTS (Noble Numbat)
- Ubuntu 22.04 LTS (Jammy Jellyfish)
- Ubuntu 20.04 LTS (Focal Fossa)
- Ubuntu 18.04 LTS (Bionic Beaver)
- Python 3.x
- Root-Zugriff oder sudo-Rechte
- SSH-Zugriff (für Remote-Ausführung)
- Netplan installiert (Standard ab Ubuntu 18.04)

## 🚀 Installation

1. **Repository klonen oder Dateien kopieren:**
```bash
cd /path/to/ip-change
```

2. **Dateien prüfen:**
```bash
ls -la
# Sollte enthalten:
# - network-update-ubuntu.yml  (Ubuntu Playbook)
# - netplan-template.j2        (Netplan Template)
# - ip-change.csv              (Ihre Daten)
# - inventory.ini              (Inventory-Beispiel)
# - rollback-ubuntu.sh         (Rollback-Script)
```

3. **CSV-Datei vorbereiten:**
   - Stellen Sie sicher, dass [`ip-change.csv`](ip-change.csv:1) korrekt formatiert ist
   - Verwenden Sie `./fix-csv.sh` falls nötig

## 📖 Verwendung

### Lokal auf der Ubuntu VM ausführen

Wenn Sie direkt auf der VM sind, die geändert werden soll:

```bash
# Dry-Run (zeigt nur was geändert würde)
ansible-playbook -i localhost, -c local network-update-ubuntu.yml --check --diff

# Tatsächliche Ausführung
ansible-playbook -i localhost, -c local network-update-ubuntu.yml
```

### Remote auf einer Ubuntu VM ausführen

1. **Inventory-Datei anpassen:**
```bash
nano inventory.ini
```

Beispiel:
```ini
[ubuntu_vms]
ubuntu-server.example.com ansible_host=192.168.1.100 ansible_user=root
```

2. **SSH-Zugriff testen:**
```bash
ansible -i inventory.ini ubuntu_vms -m ping
```

3. **Playbook ausführen:**
```bash
# Dry-Run
ansible-playbook -i inventory.ini network-update-ubuntu.yml --check --diff

# Tatsächliche Ausführung
ansible-playbook -i inventory.ini network-update-ubuntu.yml

# Mit Passwort-Abfrage
ansible-playbook -i inventory.ini network-update-ubuntu.yml --ask-pass --ask-become-pass
```

## 🔧 Was wird geändert?

Das Playbook führt folgende Änderungen durch:

### 1. Hostname
- ✏️ Ändert [`/etc/hostname`](file:///etc/hostname:1)
- ✏️ Setzt Hostname mit `hostnamectl`
- ✏️ Aktualisiert [`/etc/hosts`](file:///etc/hosts:1)

### 2. Netplan-Konfiguration
- ✏️ Erstellt/aktualisiert [`/etc/netplan/01-netcfg.yaml`](file:///etc/netplan/01-netcfg.yaml:1)
- ✏️ Konfiguriert primäres Interface mit 9.x IP
- ✏️ Konfiguriert sekundäres Interface mit 10.x IP (oder beide auf einem Interface)
- ✏️ Setzt Gateway: `9.125.190.1`
- ✏️ Setzt Netzmaske: `255.255.255.128` (/25)

### 3. Netzwerk-Neustart
- 🔄 Wendet Netplan-Konfiguration an mit `netplan apply`
- 🔄 Asynchrone Ausführung (SSH-Verbindung wird unterbrochen)

## 🆚 Unterschiede zu RHEL/Oracle Linux

| Aspekt | RHEL/Oracle Linux | Ubuntu |
|--------|-------------------|--------|
| **Playbook** | `network-update.yml` | `network-update-ubuntu.yml` |
| **Config-Verzeichnis** | `/etc/sysconfig/network-scripts/` | `/etc/netplan/` |
| **Config-Format** | ifcfg-Dateien | YAML (Netplan) |
| **Template** | `ifcfg-template.j2` | `netplan-template.j2` |
| **Netzwerk-Befehl** | `nmcli` | `netplan apply` |
| **Rollback-Script** | `rollback.sh` | `rollback-ubuntu.sh` |

## 📊 Netplan-Konfiguration

### Beispiel für ein Interface:
```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses:
        - 9.125.190.40/25
        - 10.10.64.40/25
      routes:
        - to: default
          via: 9.125.190.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
```

### Beispiel für zwei Interfaces:
```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses:
        - 9.125.190.40/25
      routes:
        - to: default
          via: 9.125.190.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
    
    eth1:
      addresses:
        - 10.10.64.40/25
```

## 🔒 Sicherheit

### Automatische Backups

Vor jeder Änderung werden Backups erstellt:

```
backups/
└── hostname_20260313_083000/
    ├── hostname
    ├── 01-netcfg.yaml
    └── netplan_backup.tar.gz
```

### Netplan-Validierung

Das Playbook validiert die Netplan-Konfiguration vor dem Anwenden:

```bash
netplan generate  # Prüft Syntax
```

### Rollback mit netplan try

Das Rollback-Script verwendet `netplan try` für sicheren Rollback:
- 120 Sekunden Timeout
- Automatischer Rollback bei Problemen
- Manuelle Bestätigung erforderlich

## 🔄 Rollback

Falls etwas schief geht, können Sie die Backups wiederherstellen:

```bash
# Rollback-Script verwenden (empfohlen)
sudo ./rollback-ubuntu.sh

# Spezifisches Backup
sudo ./rollback-ubuntu.sh hostname_20260313_083000

# Backups auflisten
./rollback-ubuntu.sh --list
```

### Manueller Rollback:

```bash
# Backup-Verzeichnis finden
ls -lt backups/

# Netplan-Konfiguration wiederherstellen
BACKUP_DIR="backups/hostname_20260313_083000"
sudo cp $BACKUP_DIR/01-netcfg.yaml /etc/netplan/

# Validieren und anwenden
sudo netplan generate
sudo netplan try
```

## 🐛 Troubleshooting

### Problem: "Netplan-Konfiguration ist ungültig"

**Lösung:**
```bash
# Syntax prüfen
sudo netplan generate

# Detaillierte Fehlerausgabe
sudo netplan --debug generate

# YAML-Syntax prüfen
yamllint /etc/netplan/01-netcfg.yaml
```

### Problem: "Netzwerk nach Änderung nicht erreichbar"

**Lösung:**
```bash
# Auf der VM (lokaler Zugriff nötig):

# Netplan-Status prüfen
sudo netplan status

# Konfiguration anzeigen
cat /etc/netplan/01-netcfg.yaml

# Mit Rollback testen
sudo netplan try

# Backup wiederherstellen
sudo ./rollback-ubuntu.sh
```

### Problem: "Cloud-Init überschreibt Konfiguration"

Auf Cloud-VMs (AWS, Azure, etc.):

**Lösung:**
```bash
# Cloud-Init Netzwerk-Konfiguration deaktivieren
sudo touch /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
echo "network: {config: disabled}" | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
```

### Problem: "YAML-Syntax-Fehler"

**Lösung:**
```bash
# Einrückung prüfen (muss Leerzeichen sein, keine Tabs)
cat -A /etc/netplan/01-netcfg.yaml

# YAML-Validator verwenden
python3 -c "import yaml; yaml.safe_load(open('/etc/netplan/01-netcfg.yaml'))"
```

## 📝 Beispiel-Ausgabe

```
PLAY [Update Ubuntu Linux Network Configuration] ******************************

TASK [Prüfe ob Ubuntu] *********************************************************
skipping: [ubuntu-server]

TASK [Debug - Zeige ALLE identifizierten Felder] ******************************
ok: [ubuntu-server] => {
    "msg": [
        "=== IDENTIFIZIERTE KONFIGURATION ===",
        "Aktueller Hostname: itcoavp151.itc.ibm.com",
        "Gefundener CSV-Eintrag:",
        "  Hostname-alt: itcoavp151.itc.ibm.com",
        "  Hostname-neu: itcopreq41.itc.ibm.com",
        "  Ip-alt (9.x): 9.155.64.151",
        "  ip-neu (9.x): 9.125.190.41",
        "  10-alt (10.x): 10.10.64.151",
        "  10-neu (10.x): 10.10.64.41"
    ]
}

TASK [Erstelle Netplan-Konfiguration] *****************************************
changed: [ubuntu-server]

TASK [Validiere Netplan-Konfiguration] ****************************************
ok: [ubuntu-server]

TASK [Zeige Zusammenfassung] ***************************************************
ok: [ubuntu-server] => {
    "msg": [
        "==========================================",
        "✓ MIGRATION ABGESCHLOSSEN",
        "==========================================",
        "Durchgeführte Änderungen:",
        "  Hostname: itcoavp151.itc.ibm.com → itcopreq41.itc.ibm.com",
        "  9.x IP: 9.155.64.151 → 9.125.190.41",
        "  10.x IP: 10.10.64.151 → 10.10.64.41",
        "  Gateway: 9.125.190.1",
        "  Netmask: 255.255.255.128"
    ]
}

PLAY RECAP *********************************************************************
ubuntu-server : ok=35   changed=5    unreachable=0    failed=0
```

## 🧪 Validierung nach Migration

Nach erfolgreicher Migration:

```bash
# Verbinden mit neuer IP
ssh root@9.125.190.41

# Hostname prüfen
hostname -f

# IP-Adressen prüfen
ip addr show

# Netplan-Status prüfen
netplan status

# Gateway testen
ping -c 3 9.125.190.1

# Internet-Konnektivität testen
ping -c 3 8.8.8.8
```

## 📚 Weitere Ressourcen

- [Netplan Dokumentation](https://netplan.io/)
- [Ubuntu Server Network Configuration](https://ubuntu.com/server/docs/network-configuration)
- [Netplan Examples](https://netplan.io/examples/)
- [Ubuntu 24.04 Release Notes](https://wiki.ubuntu.com/NobleNumbat/ReleaseNotes)

## ⚠️ Wichtige Hinweise

1. **Netplan-Syntax ist strikt:** Falsche Einrückung führt zu Fehlern
2. **Immer Dry-Run zuerst:** `--check --diff`
3. **Backup ist kritisch:** Automatische Backups werden erstellt
4. **SSH-Verbindung wird unterbrochen:** Normal beim Netzwerk-Neustart
5. **Cloud-Init beachten:** Kann Konfiguration überschreiben

## 📄 Lizenz

Dieses Projekt ist für den internen Gebrauch bestimmt.

---

**⚠️ WICHTIG:** Testen Sie das Playbook immer zuerst mit `--check --diff` bevor Sie es produktiv einsetzen!
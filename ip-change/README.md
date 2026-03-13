# Red Hat Linux Netzwerkkonfiguration Update mit Ansible

Dieses Ansible Playbook automatisiert die Änderung von Hostname und Netzwerkkonfiguration auf Red Hat Linux VMs basierend auf einer CSV-Datei.

## 📋 Inhaltsverzeichnis

- [Features](#features)
- [Voraussetzungen](#voraussetzungen)
- [Installation](#installation)
- [Verwendung](#verwendung)
- [CSV-Format](#csv-format)
- [Sicherheit](#sicherheit)
- [Troubleshooting](#troubleshooting)

## ✨ Features

- ✅ **Automatische Host-Identifikation** - Findet den Host automatisch in der CSV-Datei
- ✅ **Validierung vor Änderungen** - Prüft Hostname und IPs gegen CSV-Daten
- ✅ **Dual-Interface Support** - Unterstützt zwei Netzwerkschnittstellen (9.x und 10.x)
- ✅ **Automatisches Backup** - Erstellt Backups aller Konfigurationsdateien
- ✅ **Detailliertes Logging** - Protokolliert alle Änderungen
- ✅ **Dry-Run Modus** - Testet Änderungen ohne sie durchzuführen
- ✅ **Remote & Lokal** - Kann remote oder lokal ausgeführt werden

## 📦 Voraussetzungen

### Auf dem Control Node (wo Ansible läuft):
```bash
# Ansible installieren
sudo yum install ansible -y
# oder
sudo dnf install ansible -y
# oder
pip3 install ansible
```

### Auf den Ziel-VMs:
- Red Hat Enterprise Linux 7/8/9
- Python 3.x
- Root-Zugriff oder sudo-Rechte
- SSH-Zugriff (für Remote-Ausführung)

## 🚀 Installation

1. **Repository klonen oder Dateien kopieren:**
```bash
cd /path/to/ip-change
```

2. **Dateien prüfen:**
```bash
ls -la
# Sollte enthalten:
# - network-update.yml      (Hauptplaybook)
# - ifcfg-template.j2       (Netzwerk-Template)
# - ip-change.csv           (Ihre Daten)
# - inventory.ini           (Inventory-Beispiel)
# - README.md               (Diese Datei)
```

3. **CSV-Datei vorbereiten:**
   - Stellen Sie sicher, dass [`ip-change.csv`](ip-change.csv:1) korrekt formatiert ist
   - Siehe [CSV-Format](#csv-format) für Details

## 📖 Verwendung

### Lokal auf der VM ausführen

Wenn Sie direkt auf der VM sind, die geändert werden soll:

```bash
# Dry-Run (zeigt nur was geändert würde)
ansible-playbook -i localhost, -c local network-update.yml --check --diff

# Tatsächliche Ausführung
ansible-playbook -i localhost, -c local network-update.yml
```

### Remote auf einer VM ausführen

1. **Inventory-Datei anpassen:**
```bash
nano inventory.ini
```

Beispiel:
```ini
[redhat_vms]
itcoavp147.itc.ibm.com ansible_host=9.155.64.147 ansible_user=root
```

2. **SSH-Zugriff testen:**
```bash
ansible -i inventory.ini redhat_vms -m ping
```

3. **Playbook ausführen:**
```bash
# Dry-Run
ansible-playbook -i inventory.ini network-update.yml --check --diff

# Tatsächliche Ausführung
ansible-playbook -i inventory.ini network-update.yml

# Mit Passwort-Abfrage
ansible-playbook -i inventory.ini network-update.yml --ask-pass --ask-become-pass
```

### Mehrere VMs gleichzeitig

```bash
# Alle Hosts in der Gruppe
ansible-playbook -i inventory.ini network-update.yml

# Nur bestimmte Hosts
ansible-playbook -i inventory.ini network-update.yml --limit "itcoavp147.itc.ibm.com"

# Parallel ausführen (5 Hosts gleichzeitig)
ansible-playbook -i inventory.ini network-update.yml --forks 5
```

### Mit spezifischer CSV-Datei

```bash
ansible-playbook network-update.yml -e "csv_file=/path/to/other-file.csv"
```

## 📊 CSV-Format

Die CSV-Datei muss folgende Spalten enthalten (Semikolon-getrennt):

```csv
Hostname-alt;Hostname-neu;Ip-alt;ip-neu;10-alt;10-neu
itcoavp147.itc.ibm.com;itcopreq40.itc.ibm.com;9.155.64.147;9.125.190.40;10.10.64.147;10.10.64.40
```

### Spalten-Beschreibung:

| Spalte | Beschreibung | Beispiel |
|--------|--------------|----------|
| `Hostname-alt` | Aktueller Hostname | itcoavp147.itc.ibm.com |
| `Hostname-neu` | Neuer Hostname | itcopreq40.itc.ibm.com |
| `Ip-alt` | Aktuelle 9.x IP | 9.155.64.147 |
| `ip-neu` | Neue 9.x IP | 9.125.190.40 |
| `10-alt` | Aktuelle 10.x IP | 10.10.64.147 |
| `10-neu` | Neue 10.x IP | 10.10.64.40 |

**Wichtig:**
- Verwenden Sie Semikolon (`;`) als Trennzeichen
- Erste Zeile ist die Header-Zeile
- Keine Leerzeichen vor/nach den Werten (werden automatisch entfernt)

## 🔧 Was wird geändert?

Das Playbook führt folgende Änderungen durch:

### 1. Hostname
- ✏️ Ändert [`/etc/hostname`](file:///etc/hostname:1)
- ✏️ Setzt Hostname mit `hostnamectl`
- ✏️ Aktualisiert [`/etc/hosts`](file:///etc/hosts:1)

### 2. Netzwerk-Interface 1 (9.x Netzwerk)
- ✏️ IP-Adresse: Neue 9.x IP aus CSV
- ✏️ Gateway: `9.125.190.1`
- ✏️ Netzmaske: `255.255.255.128` (/25)
- ✏️ Primäres Interface (DEFROUTE=yes)

### 3. Netzwerk-Interface 2 (10.x Netzwerk)
- ✏️ IP-Adresse: Neue 10.x IP aus CSV
- ✏️ Netzmaske: `255.255.255.128` (/25)
- ✏️ Kein Gateway (DEFROUTE=no)

### 4. Netzwerk-Neustart
- 🔄 Lädt Konfiguration neu
- 🔄 Startet beide Interfaces neu
- 🔄 Unterstützt NetworkManager und network service

## 🔒 Sicherheit

### Backups

Vor jeder Änderung werden automatisch Backups erstellt:

```
backups/
└── hostname_20260313_083000/
    ├── hostname
    ├── ifcfg-eth0
    └── ifcfg-eth1
```

### Validierung

Das Playbook validiert:
1. ✅ CSV-Datei existiert
2. ✅ Hostname wird in CSV gefunden
3. ✅ Aktuelle IPs stimmen mit CSV überein
4. ✅ Beide Netzwerkinterfaces existieren

**Wenn eine Validierung fehlschlägt, wird das Playbook abgebrochen!**

### Logs

Alle Änderungen werden protokolliert:

```
logs/
└── hostname_20260313_083000.log
```

## 🔍 Ablauf im Detail

```
1. CSV-Datei einlesen
   ↓
2. Aktuellen Hostname ermitteln
   ↓
3. Host in CSV suchen
   ↓
4. Netzwerkinterfaces identifizieren
   ├─ Interface mit 9.x IP
   └─ Interface mit 10.x IP
   ↓
5. Aktuelle Konfiguration validieren
   ├─ Hostname-alt prüfen
   ├─ Ip-alt prüfen
   └─ 10-alt prüfen
   ↓
6. Backups erstellen
   ↓
7. Änderungen durchführen
   ├─ Hostname ändern
   ├─ 9.x Interface konfigurieren
   └─ 10.x Interface konfigurieren
   ↓
8. Netzwerk neu starten
   ↓
9. Validierung der Änderungen
   ↓
10. Log erstellen
```

## 🐛 Troubleshooting

### Problem: "Hostname nicht in CSV gefunden"

**Lösung:**
```bash
# Aktuellen Hostname prüfen
hostname -s

# CSV-Datei prüfen
cat ip-change.csv | grep $(hostname -s)

# Hostname in CSV korrigieren oder VM-Hostname anpassen
```

### Problem: "Konnte Netzwerkinterfaces nicht identifizieren"

**Lösung:**
```bash
# Alle Interfaces anzeigen
ip addr show

# Prüfen ob 9.x und 10.x IPs vorhanden sind
ip addr show | grep "inet 9\."
ip addr show | grep "inet 10\."
```

### Problem: "IP-Validierung fehlgeschlagen"

**Lösung:**
```bash
# Aktuelle IPs prüfen
ip -o addr show | grep -E 'inet ' | awk '{print $2, $4}'

# Mit CSV vergleichen
cat ip-change.csv | grep $(hostname -s)

# CSV korrigieren falls nötig
```

### Problem: "Netzwerk nach Änderung nicht erreichbar"

**Lösung:**
```bash
# Auf der VM (lokaler Zugriff nötig):

# Netzwerk-Status prüfen
systemctl status NetworkManager
systemctl status network

# Interfaces manuell neu starten
nmcli connection reload
nmcli connection up eth0
nmcli connection up eth1

# Oder mit network service
ifdown eth0 && ifup eth0
ifdown eth1 && ifup eth1

# Backup wiederherstellen falls nötig
cp backups/hostname_TIMESTAMP/ifcfg-eth0 /etc/sysconfig/network-scripts/
```

### Problem: "Ansible kann sich nicht verbinden"

**Lösung:**
```bash
# SSH-Verbindung testen
ssh root@9.155.64.147

# Ansible Ping testen
ansible -i inventory.ini redhat_vms -m ping

# Mit Passwort
ansible -i inventory.ini redhat_vms -m ping --ask-pass

# SSH-Key kopieren
ssh-copy-id root@9.155.64.147
```

## 📝 Beispiel-Ausgabe

```
PLAY [Update Red Hat Linux Network Configuration] *****************************

TASK [Erstelle Backup- und Log-Verzeichnisse] *********************************
ok: [itcoavp147.itc.ibm.com]

TASK [Lese CSV-Datei ein] ******************************************************
ok: [itcoavp147.itc.ibm.com]

TASK [Suche passenden Eintrag in CSV] ******************************************
ok: [itcoavp147.itc.ibm.com]

TASK [Zeige gefundene Konfiguration] *******************************************
ok: [itcoavp147.itc.ibm.com] => {
    "msg": [
        "Gefundene Konfiguration für Host: itcoavp147",
        "Hostname alt: itcoavp147.itc.ibm.com",
        "Hostname neu: itcopreq40.itc.ibm.com",
        "IP alt (9.x): 9.155.64.147",
        "IP neu (9.x): 9.125.190.40",
        "IP alt (10.x): 10.10.64.147",
        "IP neu (10.x): 10.10.64.40"
    ]
}

TASK [Validierung erfolgreich] *************************************************
ok: [itcoavp147.itc.ibm.com] => {
    "msg": "✓ System erfolgreich identifiziert. Änderungen können durchgeführt werden."
}

TASK [Setze neuen Hostname in /etc/hostname] ***********************************
changed: [itcoavp147.itc.ibm.com]

TASK [Konfiguriere 9.x Interface (eth0)] ***************************************
changed: [itcoavp147.itc.ibm.com]

TASK [Konfiguriere 10.x Interface (eth1)] **************************************
changed: [itcoavp147.itc.ibm.com]

TASK [Zeige Ergebnis] **********************************************************
ok: [itcoavp147.itc.ibm.com] => {
    "msg": [
        "=== Änderungen erfolgreich durchgeführt ===",
        "Neuer Hostname: itcopreq40.itc.ibm.com",
        "Neue Netzwerkkonfiguration:",
        "...",
        "Alte Konfiguration:",
        "  Hostname: itcoavp147.itc.ibm.com",
        "  9.x IP: 9.155.64.147",
        "  10.x IP: 10.10.64.147",
        "",
        "Neue Konfiguration:",
        "  Hostname: itcopreq40.itc.ibm.com",
        "  9.x IP: 9.125.190.40",
        "  10.x IP: 10.10.64.40",
        "  Gateway: 9.125.190.1",
        "  Netmask: 255.255.255.128"
    ]
}

PLAY RECAP *********************************************************************
itcoavp147.itc.ibm.com     : ok=25   changed=5    unreachable=0    failed=0
```

## 🔄 Rollback

Falls etwas schief geht, können Sie die Backups wiederherstellen:

```bash
# Backup-Verzeichnis finden
ls -lt backups/

# Dateien wiederherstellen
BACKUP_DIR="backups/hostname_20260313_083000"

# Hostname
sudo cp $BACKUP_DIR/hostname /etc/hostname
sudo hostnamectl set-hostname $(cat $BACKUP_DIR/hostname)

# Netzwerk-Interfaces
sudo cp $BACKUP_DIR/ifcfg-eth0 /etc/sysconfig/network-scripts/
sudo cp $BACKUP_DIR/ifcfg-eth1 /etc/sysconfig/network-scripts/

# Netzwerk neu starten
sudo systemctl restart NetworkManager
# oder
sudo systemctl restart network
```

## 📚 Weitere Ressourcen

- [Ansible Dokumentation](https://docs.ansible.com/)
- [Red Hat Netzwerk-Konfiguration](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_and_managing_networking/)
- [NetworkManager CLI](https://networkmanager.dev/docs/api/latest/nmcli.html)

## 📄 Lizenz

Dieses Projekt ist für den internen Gebrauch bestimmt.

## 👤 Autor

Erstellt für die IP-Migration von IBM ITC Servern.

---

**⚠️ WICHTIG:** Testen Sie das Playbook immer zuerst mit `--check --diff` bevor Sie es produktiv einsetzen!
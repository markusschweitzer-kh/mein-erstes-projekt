# System-Inventarisierung mit Ansible

Dieses Projekt sammelt umfassende System-Informationen von RHEL, Oracle Linux, Ubuntu und SLES Servern und bereitet sie übersichtlich auf.

## 📋 Übersicht

Das System sammelt automatisch folgende Informationen:

### 🌐 Netzwerk-Konfiguration
- IP-Adressen und Interfaces
- Routing-Tabellen
- DNS-Konfiguration
- Hostname-Einstellungen
- NetworkManager/Netplan/wicked Konfigurationen
- Firewall-Status (firewalld/ufw)
- Netzwerk-Statistiken und offene Ports

### 👥 Benutzer-Informationen
- Alle Benutzer-Accounts (System und normale Benutzer)
- Gruppen-Mitgliedschaften
- Sudo-Berechtigungen
- SSH authorized_keys
- Login-Historie
- Passwort-Richtlinien
- Cron-Jobs

### 💻 System-Ausstattung
- Hardware-Informationen (CPU, RAM, Disk)
- Betriebssystem-Details
- Installierte Pakete
- Repository-Konfiguration
- Systemd Services
- Virtualisierung
- Sicherheits-Features (SELinux/AppArmor)
- Performance-Metriken

## 📁 Verzeichnisstruktur

```
system-inventory/
├── collect-all.yml                    # Master-Playbook (alle Informationen)
├── inventory.ini                      # Ansible Inventar
├── README.md                          # Diese Datei
├── playbooks/                         # Einzelne Playbooks
│   ├── collect-network-info.yml      # Netzwerk-Informationen
│   ├── collect-user-info.yml         # Benutzer-Informationen
│   └── collect-system-info.yml       # System-Informationen
├── output/                            # Gesammelte Daten (wird erstellt)
│   ├── network/                      # Netzwerk-Reports
│   ├── users/                        # Benutzer-Reports
│   └── system/                       # System-Reports
└── templates/                         # Vorlagen (optional)
```

## 🚀 Schnellstart

### Voraussetzungen

1. **Ansible installiert** (Version 2.9+)
   ```bash
   # RHEL/Oracle Linux
   sudo yum install ansible
   
   # Ubuntu
   sudo apt install ansible
   
   # SLES
   sudo zypper install ansible
   ```

2. **SSH-Zugriff** zu allen Zielsystemen
   - Root-Zugriff oder sudo-Berechtigungen
   - SSH-Keys konfiguriert (empfohlen)

3. **Inventar anpassen**
   - Bearbeite `inventory.ini`
   - Füge deine Hosts hinzu
   - Passe Gruppen an (rhel_systems, ubuntu_systems, sles_systems)

### Verwendung

#### Alle Informationen sammeln (empfohlen)

```bash
cd system-inventory
ansible-playbook -i inventory.ini collect-all.yml
```

#### Nur spezifische Informationen sammeln

**Nur Netzwerk:**
```bash
ansible-playbook -i inventory.ini playbooks/collect-network-info.yml
```

**Nur Benutzer:**
```bash
ansible-playbook -i inventory.ini playbooks/collect-user-info.yml
```

**Nur System:**
```bash
ansible-playbook -i inventory.ini playbooks/collect-system-info.yml
```

#### Für spezifische Hosts

```bash
# Nur ein Host
ansible-playbook -i inventory.ini collect-all.yml --limit itcopreq40.itc.ibm.com

# Nur RHEL-Systeme
ansible-playbook -i inventory.ini collect-all.yml --limit rhel_systems

# Mehrere Hosts
ansible-playbook -i inventory.ini collect-all.yml --limit "itcopreq40.itc.ibm.com,itcopreq41.itc.ibm.com"
```

#### Mit SSH-Passwort (falls keine Keys)

```bash
ansible-playbook -i inventory.ini collect-all.yml --ask-pass --ask-become-pass
```

## 📊 Output-Format

Jeder Host erhält separate Dateien:

```
output/
├── network/
│   └── itcopreq40.itc.ibm.com_network_20260324T104500.txt
├── users/
│   └── itcopreq40.itc.ibm.com_users_20260324T104500.txt
└── system/
    ├── itcopreq40.itc.ibm.com_system_20260324T104500.txt
    └── itcopreq40.itc.ibm.com_packages_20260324T104500.txt
```

### Dateiformat

Alle Reports sind strukturierte Text-Dateien mit:
- Übersichtlichen Überschriften
- Zeitstempel
- OS-Informationen
- Kategorisierte Abschnitte

## 🔧 Konfiguration

### Inventar anpassen

Bearbeite `inventory.ini`:

```ini
[rhel_systems]
mein-server.example.com ansible_host=192.168.1.100

[ubuntu_systems]
ubuntu-server.example.com ansible_host=192.168.1.101

[sles_systems]
sles-server.example.com ansible_host=192.168.1.102
```

### Ansible-Variablen

In den Playbooks kannst du folgende Variablen anpassen:

```yaml
vars:
  output_dir: "../output"              # Ausgabe-Verzeichnis
  ansible_user: root                   # SSH-Benutzer
  ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
```

## 📝 Beispiele

### Beispiel 1: Vollständige Inventarisierung

```bash
# Alle Informationen von allen Hosts sammeln
ansible-playbook -i inventory.ini collect-all.yml

# Ergebnis prüfen
ls -lh output/network/
ls -lh output/users/
ls -lh output/system/
```

### Beispiel 2: Nur Netzwerk-Check

```bash
# Schneller Netzwerk-Check für alle Hosts
ansible-playbook -i inventory.ini playbooks/collect-network-info.yml

# Ergebnis ansehen
cat output/network/itcopreq40.itc.ibm.com_network_*.txt
```

### Beispiel 3: Vergleich zwischen Hosts

```bash
# Sammle Daten
ansible-playbook -i inventory.ini collect-all.yml

# Vergleiche Netzwerk-Konfigurationen
diff output/network/itcopreq40.itc.ibm.com_network_*.txt \
     output/network/itcopreq41.itc.ibm.com_network_*.txt
```

### Beispiel 4: Archivierung

```bash
# Sammle Daten
ansible-playbook -i inventory.ini collect-all.yml

# Erstelle Archiv
tar -czf system-inventory-$(date +%Y%m%d).tar.gz output/

# Archiv verschieben
mv system-inventory-*.tar.gz /backup/
```

## 🛠️ Troubleshooting

### Problem: "Host unreachable"

```bash
# Teste SSH-Verbindung
ansible -i inventory.ini all -m ping

# Teste mit verbose
ansible-playbook -i inventory.ini collect-all.yml -vvv
```

### Problem: "Permission denied"

```bash
# Verwende sudo
ansible-playbook -i inventory.ini collect-all.yml --become

# Mit Passwort-Abfrage
ansible-playbook -i inventory.ini collect-all.yml --ask-become-pass
```

### Problem: "Command not found"

Manche Befehle sind möglicherweise nicht installiert:
- `lspci` → Paket: pciutils
- `lsusb` → Paket: usbutils
- `dmidecode` → Paket: dmidecode
- `iostat` → Paket: sysstat

Die Playbooks ignorieren fehlende Befehle (`ignore_errors: yes`).

## 📚 Erweiterte Nutzung

### Parallele Ausführung

```bash
# Mehr parallele Prozesse (Standard: 5)
ansible-playbook -i inventory.ini collect-all.yml --forks 10
```

### Nur bestimmte Tasks ausführen

```bash
# Mit Tags (müssten erst hinzugefügt werden)
ansible-playbook -i inventory.ini collect-all.yml --tags "network"
```

### Dry-Run (Check-Modus)

```bash
# Zeigt was gemacht würde, ohne es auszuführen
ansible-playbook -i inventory.ini collect-all.yml --check
```

## 🔒 Sicherheitshinweise

1. **Sensible Daten**: Die Reports enthalten sensible Informationen:
   - Benutzer-Namen
   - Netzwerk-Konfigurationen
   - System-Details
   - SSH-Keys (nur Fingerprints, keine privaten Keys)

2. **Passwort-Hashes**: Shadow-File wird OHNE Passwort-Hashes gesammelt

3. **Zugriffskontrolle**: 
   - Schütze das `output/` Verzeichnis
   - Verwende Verschlüsselung für Archive
   - Lösche alte Reports regelmäßig

4. **SSH-Keys**: Verwende SSH-Keys statt Passwörter

## 📞 Support

Bei Fragen oder Problemen:
1. Prüfe die Ansible-Logs (`-vvv` für Details)
2. Teste einzelne Playbooks
3. Prüfe SSH-Verbindung manuell
4. Überprüfe Berechtigungen auf Zielsystemen

## 📄 Lizenz

Dieses Projekt ist für interne Nutzung bestimmt.

## 🔄 Updates

Letzte Aktualisierung: 2026-03-24

### Version 1.0
- Initiale Version
- Support für RHEL, Oracle Linux, Ubuntu, SLES
- Netzwerk-, Benutzer- und System-Informationen
- Strukturierte Text-Reports
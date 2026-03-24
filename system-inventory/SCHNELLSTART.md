# 🚀 Schnellstart-Anleitung

## In 5 Minuten loslegen

### 1. Voraussetzungen prüfen

```bash
# Ansible installiert?
ansible --version

# SSH-Zugriff testen
ssh root@9.125.190.40
```

### 2. Inventar anpassen

Bearbeite `inventory.ini` und passe die Hosts an:

```bash
cd system-inventory
nano inventory.ini
```

### 3. Verbindung testen

```bash
# Teste Verbindung zu allen Hosts
ansible -i inventory.ini all -m ping

# Teste nur RHEL-Systeme
ansible -i inventory.ini rhel_systems -m ping

# Teste einzelnen Host
ansible -i inventory.ini itcopreq40.itc.ibm.com -m ping
```

### 4. Daten sammeln

#### 🌍 Alle Remote-Systeme (Standard)
```bash
# Alle Informationen von allen Hosts sammeln
ansible-playbook -i inventory.ini collect-all.yml

# Oder nur spezifische Informationen:
ansible-playbook -i inventory.ini playbooks/collect-network-info.yml
ansible-playbook -i inventory.ini playbooks/collect-user-info.yml
ansible-playbook -i inventory.ini playbooks/collect-system-info.yml
```

#### 🖥️ Lokales System (localhost)
```bash
# Lokale Maschine inventarisieren (ohne SSH)
ansible-playbook -i "localhost," -c local collect-all.yml

# Nur Netzwerk-Info lokal
ansible-playbook -i "localhost," -c local playbooks/collect-network-info.yml
```

#### 🎯 Ein einzelnes Remote-System
```bash
# Nur einen spezifischen Host
ansible-playbook -i inventory.ini collect-all.yml --limit itcopreq40.itc.ibm.com

# Oder direkt mit IP
ansible-playbook -i "9.125.190.40," -u root collect-all.yml
```

#### 👥 Eine Gruppe von Systemen
```bash
# Nur RHEL/Oracle Linux Systeme
ansible-playbook -i inventory.ini collect-all.yml --limit rhel_systems

# Nur Ubuntu Systeme
ansible-playbook -i inventory.ini collect-all.yml --limit ubuntu_systems

# Nur SLES Systeme
ansible-playbook -i inventory.ini collect-all.yml --limit sles_systems
```

#### 🔢 Mehrere spezifische Hosts
```bash
# Mehrere Hosts mit Komma getrennt
ansible-playbook -i inventory.ini collect-all.yml --limit "itcopreq40.itc.ibm.com,itcopreq41.itc.ibm.com,itcopreq42.itc.ibm.com"
```

### 5. Ergebnisse prüfen

```bash
# Verzeichnisstruktur anzeigen
tree output/

# Oder mit ls
ls -lh output/network/
ls -lh output/users/
ls -lh output/system/

# Einen Report ansehen
less output/network/itcopreq40.itc.ibm.com_network_*.txt
```

## 📋 Aufruf-Beispiele im Detail

### 🖥️ Lokale Maschine (localhost)

```bash
# Komplette Inventarisierung der lokalen Maschine
ansible-playbook -i "localhost," -c local collect-all.yml

# Nur Netzwerk lokal
ansible-playbook -i "localhost," -c local playbooks/collect-network-info.yml

# Nur Benutzer lokal
ansible-playbook -i "localhost," -c local playbooks/collect-user-info.yml

# Nur System lokal
ansible-playbook -i "localhost," -c local playbooks/collect-system-info.yml
```

**Wichtig**:
- Das Komma nach `localhost` ist erforderlich!
- `-c local` bedeutet: keine SSH-Verbindung, direkt lokal ausführen
- Benötigt sudo-Rechte: `sudo ansible-playbook ...` oder `--ask-become-pass`

### 🌐 Ein Remote-System

```bash
# Mit Inventar-Datei (empfohlen)
ansible-playbook -i inventory.ini collect-all.yml --limit itcopreq40.itc.ibm.com

# Direkt mit IP (ohne Inventar)
ansible-playbook -i "9.125.190.40," -u root collect-all.yml

# Mit Hostname direkt
ansible-playbook -i "itcopreq40.itc.ibm.com," -u root collect-all.yml

# Nur Netzwerk-Info für einen Host
ansible-playbook -i inventory.ini playbooks/collect-network-info.yml --limit itcopreq40.itc.ibm.com
```

### 👥 Eine Gruppe von Systemen

```bash
# Alle RHEL/Oracle Linux Systeme
ansible-playbook -i inventory.ini collect-all.yml --limit rhel_systems

# Alle Ubuntu Systeme
ansible-playbook -i inventory.ini collect-all.yml --limit ubuntu_systems

# Alle SLES Systeme
ansible-playbook -i inventory.ini collect-all.yml --limit sles_systems

# Nur Netzwerk-Info für RHEL-Gruppe
ansible-playbook -i inventory.ini playbooks/collect-network-info.yml --limit rhel_systems
```

### 🌍 Alle Systeme

```bash
# Alle Hosts aus inventory.ini
ansible-playbook -i inventory.ini collect-all.yml

# Alle Hosts - nur Netzwerk
ansible-playbook -i inventory.ini playbooks/collect-network-info.yml

# Alle Hosts - nur Benutzer
ansible-playbook -i inventory.ini playbooks/collect-user-info.yml

# Alle Hosts - nur System
ansible-playbook -i inventory.ini playbooks/collect-system-info.yml
```

### 🔢 Mehrere spezifische Hosts

```bash
# Mehrere Hosts mit --limit
ansible-playbook -i inventory.ini collect-all.yml --limit "itcopreq40.itc.ibm.com,itcopreq41.itc.ibm.com,itcopreq42.itc.ibm.com"

# Oder direkt als Inventar (ohne inventory.ini)
ansible-playbook -i "9.125.190.40,9.125.190.41,9.125.190.42," -u root collect-all.yml
```

### 🔐 Mit Authentifizierung

```bash
# Mit SSH-Passwort (wird abgefragt)
ansible-playbook -i inventory.ini collect-all.yml --ask-pass

# Mit sudo-Passwort (wird abgefragt)
ansible-playbook -i inventory.ini collect-all.yml --ask-become-pass

# Beides zusammen
ansible-playbook -i inventory.ini collect-all.yml --ask-pass --ask-become-pass

# Mit spezifischem SSH-User
ansible-playbook -i inventory.ini collect-all.yml -u admin --ask-become-pass

# Mit SSH-Key-Datei
ansible-playbook -i inventory.ini collect-all.yml --private-key ~/.ssh/id_rsa
```

### Mit Passwort-Authentifizierung

```bash
ansible-playbook -i inventory.ini collect-all.yml --ask-pass --ask-become-pass
```

### Parallele Ausführung beschleunigen

```bash
# Standard: 5 parallele Prozesse
# Erhöhen auf 10:
ansible-playbook -i inventory.ini collect-all.yml --forks 10
```

### Verbose-Modus für Debugging

```bash
# Mehr Details anzeigen
ansible-playbook -i inventory.ini collect-all.yml -v

# Noch mehr Details
ansible-playbook -i inventory.ini collect-all.yml -vvv
```

## 🎯 Typische Anwendungsfälle

### Fall 1: Erste Inventarisierung

```bash
# Alle Daten sammeln
ansible-playbook -i inventory.ini collect-all.yml

# Archiv erstellen
tar -czf inventory-$(date +%Y%m%d).tar.gz output/
```

### Fall 2: Nur Netzwerk prüfen

```bash
# Schneller Netzwerk-Check
ansible-playbook -i inventory.ini playbooks/collect-network-info.yml

# Ergebnis ansehen
cat output/network/*.txt | grep -A 5 "IP ADRESSEN"
```

### Fall 3: Benutzer-Audit

```bash
# Benutzer sammeln
ansible-playbook -i inventory.ini playbooks/collect-user-info.yml

# Sudo-Berechtigungen prüfen
grep -r "sudo" output/users/
```

### Fall 4: System-Vergleich

```bash
# Daten sammeln
ansible-playbook -i inventory.ini collect-all.yml

# Zwei Hosts vergleichen
diff output/system/itcopreq40.itc.ibm.com_system_*.txt \
     output/system/itcopreq41.itc.ibm.com_system_*.txt
```

## ⚠️ Troubleshooting

### Problem: Host nicht erreichbar

```bash
# SSH manuell testen
ssh root@9.125.190.40

# Ansible Ping
ansible -i inventory.ini all -m ping -vvv
```

### Problem: Permission denied

```bash
# Mit sudo
ansible-playbook -i inventory.ini collect-all.yml --become

# Mit Passwort-Abfrage
ansible-playbook -i inventory.ini collect-all.yml --ask-become-pass
```

### Problem: Timeout

```bash
# Timeout erhöhen (in ansible.cfg oder als Parameter)
export ANSIBLE_TIMEOUT=60
ansible-playbook -i inventory.ini collect-all.yml
```

## 📊 Output verstehen

### Dateinamen-Format

```
<hostname>_<kategorie>_<timestamp>.txt

Beispiel:
itcopreq40.itc.ibm.com_network_20260324T104500.txt
```

### Verzeichnisstruktur

```
output/
├── network/          # Netzwerk-Konfigurationen
│   └── *.txt
├── users/            # Benutzer-Informationen
│   └── *.txt
└── system/           # System-Ausstattung
    ├── *_system_*.txt     # System-Details
    └── *_packages_*.txt   # Paketlisten
```

## 🔄 Regelmäßige Ausführung

### Cron-Job einrichten

```bash
# Crontab bearbeiten
crontab -e

# Täglich um 2 Uhr morgens
0 2 * * * cd /pfad/zu/system-inventory && ansible-playbook -i inventory.ini collect-all.yml

# Wöchentlich Sonntags um 3 Uhr
0 3 * * 0 cd /pfad/zu/system-inventory && ansible-playbook -i inventory.ini collect-all.yml
```

### Mit Archivierung

```bash
#!/bin/bash
cd /pfad/zu/system-inventory
ansible-playbook -i inventory.ini collect-all.yml
tar -czf /backup/inventory-$(date +%Y%m%d).tar.gz output/
# Alte Daten löschen (älter als 30 Tage)
find /backup/inventory-*.tar.gz -mtime +30 -delete
```

## 💡 Tipps

1. **Erste Ausführung**: Teste erst mit einem Host (`--limit`)
2. **Große Umgebungen**: Erhöhe `--forks` für Parallelität
3. **Regelmäßig**: Richte einen Cron-Job ein
4. **Archivierung**: Erstelle regelmäßig Backups der Daten
5. **Vergleiche**: Nutze `diff` um Änderungen zu erkennen

## 📞 Weitere Hilfe

Siehe vollständige Dokumentation: [README.md](README.md)
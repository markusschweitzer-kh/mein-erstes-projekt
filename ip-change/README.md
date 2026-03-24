# IP-Migration Projekt

Automatisierte IP-Migration für RHEL/Oracle Linux, SLES und Ubuntu Server mit Ansible.

## 📋 Übersicht

Dieses Projekt automatisiert die Migration von Server-IPs und Hostnamen:
- **9.x Netzwerk** (alte → neue IP)
- **10.x Netzwerk** (alte → neue IP)
- **Hostname** (alt → neu)
- **DNS-Server** (8.8.8.8 → 9.0.0.1, 9.0.0.2)

## 🚀 Schnellstart

### 1. Vorbereitung

```bash
cd ip-change
# CSV-Datei mit allen Hosts prüfen
cat data/ip-change.csv
```

### 2. IP-Migration durchführen

**RHEL/Oracle Linux:**
```bash
ansible-playbook playbooks/network-update-rhel-v3.yml -i "9.125.190.50," -u admin --ask-pass --ask-become-pass
```

**SLES:**
```bash
ansible-playbook playbooks/network-update-sles-v3.yml -i "9.125.190.50," -u admin --ask-pass --ask-become-pass
```

**Ubuntu:**
```bash
ansible-playbook playbooks/network-update-ubuntu.yml -i "9.125.190.50," -u admin --ask-pass --ask-become-pass
```

### 3. DNS-Server aktualisieren

```bash
ansible-playbook playbooks/update-dns-config.yml -i "9.125.190.50," -u admin --ask-pass --ask-become-pass
```

### 4. Status prüfen

```bash
ansible-playbook playbooks/check-migration-status.yml --ask-pass --ask-become-pass
```

## 📁 Projekt-Struktur

```
ip-change/
├── playbooks/              # Ansible Playbooks
│   ├── network-update-rhel-v3.yml    # RHEL/Oracle Linux
│   ├── network-update-sles-v3.yml    # SLES
│   ├── network-update-ubuntu.yml     # Ubuntu
│   ├── update-dns-config.yml         # DNS-Update
│   └── check-migration-status.yml    # Status-Check
│
├── templates/              # Jinja2 Templates
│   ├── ifcfg-template.j2            # RHEL/Oracle
│   ├── ifcfg-sles-template.j2       # SLES
│   ├── routes-sles-template.j2      # SLES Routes
│   └── netplan-template.j2          # Ubuntu
│
├── data/                   # Daten
│   ├── ip-change.csv               # Host-Daten
│   └── inventory.ini               # Ansible Inventory
│
├── docs/                   # Dokumentation
│   ├── README.md                   # Diese Datei
│   ├── SCHNELLSTART.md            # Quick-Start
│   ├── README_DNS_UPDATE.md       # DNS-Anleitung
│   └── README_CHECK_STATUS.md     # Status-Check Anleitung
│
└── archive/                # Archivierte Dateien
    ├── old-versions/              # Alte Playbook-Versionen
    ├── scripts/                   # Alte Bash-Scripts
    └── old-docs/                  # Alte Dokumentation
```

## 🎯 Playbooks

### IP-Migration

| Playbook | Betriebssystem | Beschreibung |
|----------|----------------|--------------|
| `network-update-rhel-v3.yml` | RHEL/Oracle Linux | IP-Migration mit NetworkManager |
| `network-update-sles-v3.yml` | SLES/openSUSE | IP-Migration mit wicked |
| `network-update-ubuntu.yml` | Ubuntu | IP-Migration mit netplan |

### DNS-Update

| Playbook | Beschreibung |
|----------|--------------|
| `update-dns-config.yml` | Ändert DNS von 8.8.8.8 auf 9.0.0.1, 9.0.0.2 |

### Status-Check

| Playbook | Beschreibung |
|----------|--------------|
| `check-migration-status.yml` | Prüft Migrations-Status aller Hosts |

## 📝 CSV-Format

Die Datei `data/ip-change.csv` enthält alle Host-Informationen:

```csv
Hostname-alt;Hostname-neu;Ip-alt;ip-neu;10-alt;10-neu
server01.old.com;server01.new.com;9.125.190.50;9.125.190.51;10.10.64.50;10.10.64.51
```

## 🔧 Typischer Workflow

### Einzelner Host

```bash
# 1. IP-Migration
ansible-playbook playbooks/network-update-rhel-v3.yml \
  -i "9.125.190.50," -u admin --ask-pass --ask-become-pass

# 2. DNS-Update
ansible-playbook playbooks/update-dns-config.yml \
  -i "9.125.190.51," -u admin --ask-pass --ask-become-pass

# 3. Status prüfen
ansible-playbook playbooks/check-migration-status.yml \
  --ask-pass --ask-become-pass
```

### Mehrere Hosts

```bash
# 1. Inventory erstellen
cat > hosts.ini << EOF
[migration]
9.125.190.50 ansible_user=admin
9.125.190.52 ansible_user=admin
9.125.190.54 ansible_user=admin
EOF

# 2. IP-Migration
ansible-playbook playbooks/network-update-rhel-v3.yml \
  -i hosts.ini --ask-pass --ask-become-pass

# 3. DNS-Update (mit neuen IPs!)
cat > hosts-new.ini << EOF
[migration]
9.125.190.51 ansible_user=admin
9.125.190.53 ansible_user=admin
9.125.190.55 ansible_user=admin
EOF

ansible-playbook playbooks/update-dns-config.yml \
  -i hosts-new.ini --ask-pass --ask-become-pass

# 4. Status prüfen
ansible-playbook playbooks/check-migration-status.yml \
  --ask-pass --ask-become-pass
```

## ✅ Was wird geprüft?

Der Status-Check validiert:
- ✅ 9.x IP korrekt migriert
- ✅ 10.x IP korrekt migriert
- ✅ Hostname geändert
- ✅ DNS-Server aktualisiert (9.0.0.1, 9.0.0.2)

## 🔄 Rollback

Jedes Playbook erstellt automatisch:
- Backup in `/root/network-backup-<timestamp>/`
- Rollback-Script: `/root/network-backup-<timestamp>/rollback.sh`

```bash
# Rollback durchführen
sudo /root/network-backup-<timestamp>/rollback.sh
sudo reboot
```

## 📊 Logs

Alle Aktionen werden protokolliert:
- IP-Migration: `/var/log/ansible-ip-migration/`
- DNS-Update: `/var/log/ansible-dns-update/`

## 🛠️ Troubleshooting

### Problem: Passwort-Abfragen

**Lösung:** SSH-Keys verwenden
```bash
ssh-copy-id admin@9.125.190.50
```

### Problem: Host nicht erreichbar

```bash
# Prüfe Erreichbarkeit
ping 9.125.190.50
ssh admin@9.125.190.50

# Prüfe mit Ansible
ansible all -i "9.125.190.50," -u admin --ask-pass -m ping
```

### Problem: DNS funktioniert nicht

```bash
# Prüfe DNS-Server
cat /etc/resolv.conf

# Teste DNS-Auflösung
nslookup google.com 9.0.0.1
```

## 📚 Weitere Dokumentation

- [SCHNELLSTART.md](docs/SCHNELLSTART.md) - Quick-Start Guide
- [README_DNS_UPDATE.md](docs/README_DNS_UPDATE.md) - DNS-Update Details
- [README_CHECK_STATUS.md](docs/README_CHECK_STATUS.md) - Status-Check Details

## 🔐 Sicherheit

- Alle Playbooks verwenden `become: yes` für sudo
- Backups werden automatisch erstellt
- Rollback-Scripts für Notfälle
- Logs für Audit-Trail

## 📞 Support

Bei Problemen:
1. Prüfe Logs in `/var/log/ansible-*/`
2. Prüfe Backup in `/root/network-backup-*/`
3. Verwende Rollback-Script falls nötig
4. Kontaktiere System-Administrator

---

**Version:** 3.0  
**Letzte Aktualisierung:** 2026-03-23  
**Autor:** Ansible Automation Team
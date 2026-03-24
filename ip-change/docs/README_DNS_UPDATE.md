# DNS-Konfiguration Update

Dieses Playbook aktualisiert die DNS-Server-Konfiguration von `8.8.8.8` auf die internen DNS-Server `9.0.0.1` und `9.0.0.2`.

## Wichtiger Hinweis

⚠️ **Alle Server sind nur noch unter den neuen IPs erreichbar!**

Stelle sicher, dass du die neuen IP-Adressen aus der `ip-change.csv` verwendest.

## Unterstützte Systeme

- **RHEL/Oracle Linux** (NetworkManager)
- **SLES/openSUSE** (wicked)
- **Ubuntu** (netplan)

## Voraussetzungen

1. Ansible installiert
2. SSH-Zugriff zu den Zielsystemen
3. Root/sudo-Rechte
4. Server sind unter neuen IPs erreichbar

## Verwendung

### Für lokale Maschine

```bash
cd ip-change
ansible-playbook update-dns-config.yml -i "localhost," --connection=local --ask-become-pass
```

### Für Remote-System mit neuer IP

```bash
ansible-playbook update-dns-config.yml -i "9.125.190.50," -u admin --ask-pass --ask-become-pass
```

### Für mehrere Systeme aus CSV

Erstelle eine Inventory-Datei mit den neuen IPs:

```bash
# inventory-dns.ini
[dns_update]
9.125.190.50 ansible_user=admin
9.125.190.51 ansible_user=admin
9.125.190.52 ansible_user=admin
```

Dann ausführen:

```bash
ansible-playbook update-dns-config.yml -i inventory-dns.ini --ask-pass --ask-become-pass
```

## Was macht das Playbook?

1. **Backup erstellen**
   - Sichert alle DNS-Konfigurationsdateien
   - Erstellt Rollback-Script

2. **DNS-Server aktualisieren**
   - RHEL: Aktualisiert NetworkManager Connections
   - SLES: Aktualisiert ifcfg-Dateien und netconfig
   - Ubuntu: Aktualisiert netplan-Konfiguration
   - Fallback: Aktualisiert `/etc/resolv.conf` direkt

3. **Validierung**
   - Prüft neue DNS-Server
   - Testet DNS-Auflösung

4. **Logging**
   - Erstellt detailliertes Log in `/var/log/ansible-dns-update/`

## Neue DNS-Server

- **Primär:** 9.0.0.1
- **Sekundär:** 9.0.0.2

## Backup und Rollback

### Backup-Verzeichnis

```
/root/dns-backup-<timestamp>/
├── resolv.conf.backup
├── ifcfg-*
├── *.yaml (netplan)
├── nmcli-before.txt
└── rollback-dns.sh
```

### Rollback durchführen

Falls etwas schief geht:

```bash
sudo /root/dns-backup-<timestamp>/rollback-dns.sh
```

## Logs

Alle Aktionen werden protokolliert:

```
/var/log/ansible-dns-update/dns-update-<timestamp>.log
```

## Validierung nach Update

### DNS-Server prüfen

```bash
cat /etc/resolv.conf
```

Sollte zeigen:
```
nameserver 9.0.0.1
nameserver 9.0.0.2
```

### DNS-Auflösung testen

```bash
nslookup google.com 9.0.0.1
dig @9.0.0.2 google.com
```

### NetworkManager Status (RHEL)

```bash
nmcli connection show
nmcli device show
```

### Wicked Status (SLES)

```bash
wicked show all
cat /etc/resolv.conf
```

### Netplan Status (Ubuntu)

```bash
netplan get
cat /etc/resolv.conf
```

## Troubleshooting

### DNS-Server werden nicht übernommen

**RHEL/Oracle Linux:**
```bash
# Prüfe NetworkManager
systemctl status NetworkManager
nmcli connection show

# Erzwinge Update
nmcli connection reload
nmcli connection down <interface>
nmcli connection up <interface>
```

**SLES:**
```bash
# Prüfe wicked
systemctl status wicked
wicked show all

# Erzwinge Update
netconfig update -f
systemctl restart wicked
```

**Ubuntu:**
```bash
# Prüfe netplan
netplan get
systemctl status systemd-resolved

# Erzwinge Update
netplan apply
systemctl restart systemd-resolved
```

### resolv.conf wird überschrieben

Falls `/etc/resolv.conf` automatisch überschrieben wird:

```bash
# Schütze die Datei
sudo chattr +i /etc/resolv.conf

# Zum Entsperren
sudo chattr -i /etc/resolv.conf
```

### DNS-Auflösung funktioniert nicht

```bash
# Teste DNS-Server direkt
nslookup google.com 9.0.0.1
ping 9.0.0.1

# Prüfe Firewall
sudo iptables -L -n | grep 53
sudo firewall-cmd --list-all

# Prüfe Routing
ip route show
```

## Anpassungen

### Andere DNS-Server verwenden

Bearbeite die `vars` Sektion im Playbook:

```yaml
vars:
  dns_servers:
    - "9.0.0.1"
    - "9.0.0.2"
    - "9.0.0.3"  # Optional: Dritter DNS-Server
```

### Nur bestimmte Interfaces aktualisieren

Füge eine Bedingung hinzu:

```yaml
when:
  - is_rhel
  - item == "ens33"  # Nur für bestimmtes Interface
```

## Best Practices

1. **Teste zuerst auf einem System**
   ```bash
   ansible-playbook update-dns-config.yml -i "test-server," --check
   ```

2. **Führe Backup durch**
   - Automatisches Backup wird erstellt
   - Zusätzlich manuelles Backup empfohlen

3. **Prüfe Erreichbarkeit**
   - Stelle sicher, dass DNS-Server 9.0.0.1 und 9.0.0.2 erreichbar sind
   - Teste vor dem Rollout: `ping 9.0.0.1`

4. **Dokumentiere Änderungen**
   - Logs werden automatisch erstellt
   - Notiere Zeitpunkt und betroffene Systeme

## Beispiel-Workflow

```bash
# 1. Teste auf einem System
ansible-playbook update-dns-config.yml -i "9.125.190.50," -u admin --ask-pass --ask-become-pass --check

# 2. Führe auf einem System aus
ansible-playbook update-dns-config.yml -i "9.125.190.50," -u admin --ask-pass --ask-become-pass

# 3. Validiere
ssh admin@9.125.190.50 "cat /etc/resolv.conf"
ssh admin@9.125.190.50 "nslookup google.com"

# 4. Bei Erfolg: Rollout auf alle Systeme
ansible-playbook update-dns-config.yml -i inventory-dns.ini --ask-pass --ask-become-pass
```

## Support

Bei Problemen:
1. Prüfe Log-Datei: `/var/log/ansible-dns-update/`
2. Prüfe Backup: `/root/dns-backup-<timestamp>/`
3. Führe Rollback aus falls nötig
4. Kontaktiere System-Administrator

---

**Erstellt:** 2026-03-23  
**Version:** 1.0  
**Autor:** Ansible Automation
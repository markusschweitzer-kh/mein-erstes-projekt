# Migrations-Status-Checker (Ansible Version)

Dieses Ansible Playbook prüft den Migrations-Status aller Hosts aus der CSV-Datei und zeigt eine übersichtliche Zusammenfassung.

## Vorteile gegenüber dem Bash-Script

✅ **Keine wiederholten Passwort-Abfragen** - Ansible fragt einmal nach Passwort  
✅ **Zentrale Authentifizierung** - Ein Passwort für alle Hosts  
✅ **Bessere Fehlerbehandlung** - Strukturierte Ausgabe  
✅ **Parallele Ausführung möglich** - Schneller bei vielen Hosts  
✅ **Detaillierte Logs** - Ansible-Logging verfügbar  

## Was wird geprüft?

- ✅ **9.x IP-Migration** (alte → neue IP)
- ✅ **10.x IP-Migration** (alte → neue IP)
- ✅ **Hostname-Änderung** (alt → neu)
- ✅ **DNS-Server-Konfiguration** (8.8.8.8 → 9.0.0.1, 9.0.0.2)

## Voraussetzungen

1. Ansible installiert
2. CSV-Datei `ip-change.csv` vorhanden
3. SSH-Zugriff zu den Hosts (alte oder neue IP)
4. Root/sudo-Rechte auf den Hosts

## Verwendung

### Standard-Aufruf

```bash
cd ip-change
ansible-playbook check-migration-status.yml --ask-pass --ask-become-pass
```

### Mit SSH-Key (kein Passwort nötig)

```bash
ansible-playbook check-migration-status.yml
```

### Mit spezifischem Benutzer

```bash
ansible-playbook check-migration-status.yml -u admin --ask-pass --ask-become-pass
```

### Mit Inventory-Datei

Falls du eine Inventory-Datei mit Credentials hast:

```bash
ansible-playbook check-migration-status.yml -i inventory.ini
```

## Ausgabe-Beispiel

```
================================================================================
                    IP-MIGRATIONS-STATUS ZUSAMMENFASSUNG
================================================================================

Gesamt: 10 Hosts

✓ Vollständig migriert: 7
◐ Teilweise migriert:   2
○ Nicht migriert:       1
✗ Nicht erreichbar:     0

=== VOLLSTÄNDIG MIGRIERTE HOSTS (7) ===
✓ server01.example.com
    9.x IP:  9.125.190.51 [NEU]
    10.x IP: 10.10.64.51 [NEU]
    Hostname: [NEU]
    DNS: [NEU]

=== TEILWEISE MIGRIERTE HOSTS (2) - AKTION ERFORDERLICH ===
◐ server02.example.com → server02-neu.example.com
    9.x IP:  NEU
    10.x IP: NEU
    Hostname: NEU
    DNS: ALT
    Erreichbar über: 9.125.190.52
    → Bitte Migration vervollständigen!

=== EMPFOHLENE AKTIONEN ===

Teilweise migrierte Hosts:
  1. Prüfe welche Komponente fehlt (9.x IP, 10.x IP, Hostname oder DNS)
  2. Für 9.x IP-Probleme: fix-9x-ip-manual.sh
  3. Für 10.x IP-Probleme: change-10x-ip.sh
  4. Für DNS-Probleme: ansible-playbook update-dns-config.yml
  5. Oder führe network-update-rhel-v3.yml erneut aus
```

## Status-Bedeutung

### ✓ Vollständig migriert (OK)
- 9.x IP: NEU ✓
- 10.x IP: NEU ✓
- Hostname: NEU ✓
- DNS: NEU ✓

### ◐ Teilweise migriert (AKTION ERFORDERLICH)
- Mindestens eine Komponente ist noch nicht migriert
- Host ist erreichbar, aber Migration unvollständig
- **Aktion:** Fehlende Komponente nachträglich migrieren

### ○ Nicht migriert (MIGRATION ERFORDERLICH)
- Alle Komponenten sind noch auf ALT
- Host ist erreichbar, aber nicht migriert
- **Aktion:** Migration durchführen

### ✗ Nicht erreichbar (PRÜFUNG ERFORDERLICH)
- Host antwortet weder auf alte noch auf neue IP
- **Aktion:** Host-Status prüfen (offline? Netzwerk-Problem?)

## Fehlerbehebung

### Problem: Passwort-Abfrage für jeden Host

**Lösung 1: SSH-Keys verwenden**
```bash
# SSH-Key auf alle Hosts kopieren
ssh-copy-id admin@9.125.190.50
ssh-copy-id admin@9.125.190.51
# etc.

# Dann ohne --ask-pass ausführen
ansible-playbook check-migration-status.yml
```

**Lösung 2: Inventory mit Credentials**
```ini
# inventory.ini
[all:vars]
ansible_user=admin
ansible_password=DEIN_PASSWORT
ansible_become_password=DEIN_SUDO_PASSWORT
```

```bash
ansible-playbook check-migration-status.yml -i inventory.ini
```

### Problem: SSH-Verbindung schlägt fehl

```bash
# Prüfe SSH-Verbindung manuell
ssh admin@9.125.190.50

# Prüfe mit Ansible
ansible all -i "9.125.190.50," -u admin --ask-pass -m ping
```

### Problem: Timeout zu kurz

Erhöhe den Timeout im Playbook:
```yaml
vars:
  ssh_timeout: 10  # Standard: 5 Sekunden
```

### Problem: Host wird als "nicht erreichbar" angezeigt

1. Prüfe ob Host online ist: `ping 9.125.190.50`
2. Prüfe SSH-Port: `telnet 9.125.190.50 22`
3. Prüfe Firewall-Regeln
4. Prüfe ob alte oder neue IP erreichbar ist

## Vergleich: Bash-Script vs. Ansible

| Feature | Bash-Script | Ansible Playbook |
|---------|-------------|------------------|
| Passwort-Abfragen | Für jeden Host | Einmal für alle |
| Parallele Ausführung | Nein | Ja (optional) |
| Fehlerbehandlung | Basis | Erweitert |
| Logging | Einfach | Detailliert |
| Wiederverwendbarkeit | Begrenzt | Hoch |
| Abhängigkeiten | ssh, ping | Ansible |

## Erweiterte Verwendung

### Nur bestimmte Hosts prüfen

Bearbeite die CSV oder verwende eine gefilterte Version:
```bash
# Erstelle gefilterte CSV
head -1 ip-change.csv > test-hosts.csv
grep "server01\|server02" ip-change.csv >> test-hosts.csv

# Verwende gefilterte CSV
ansible-playbook check-migration-status.yml -e "csv_file=test-hosts.csv"
```

### Parallele Ausführung aktivieren

Füge im Playbook hinzu:
```yaml
- name: IP-Migrations-Status prüfen
  hosts: localhost
  gather_facts: no
  strategy: free  # Parallele Ausführung
```

### Detailliertes Logging

```bash
ansible-playbook check-migration-status.yml -v    # Verbose
ansible-playbook check-migration-status.yml -vv   # Mehr Details
ansible-playbook check-migration-status.yml -vvv  # Debug-Level
```

### Ausgabe in Datei speichern

```bash
ansible-playbook check-migration-status.yml | tee migration-status-$(date +%Y%m%d-%H%M%S).log
```

## Integration in Workflow

### 1. Vor der Migration
```bash
# Status prüfen
ansible-playbook check-migration-status.yml
```

### 2. Migration durchführen
```bash
# IP-Migration
ansible-playbook network-update-rhel-v3.yml -i inventory.ini

# DNS-Update
ansible-playbook update-dns-config.yml -i inventory.ini
```

### 3. Nach der Migration
```bash
# Status erneut prüfen
ansible-playbook check-migration-status.yml

# Bei Problemen: Einzelne Komponenten nachbessern
ansible-playbook update-dns-config.yml -i "9.125.190.50," -u admin
```

## Automatisierung

### Cronjob für regelmäßige Prüfung

```bash
# Crontab bearbeiten
crontab -e

# Täglich um 8:00 Uhr prüfen
0 8 * * * cd /path/to/ip-change && ansible-playbook check-migration-status.yml > /var/log/migration-status-$(date +\%Y\%m\%d).log 2>&1
```

### Benachrichtigung bei Problemen

Erweitere das Playbook mit E-Mail-Benachrichtigung:
```yaml
- name: Sende E-Mail bei Problemen
  mail:
    host: smtp.example.com
    port: 587
    to: admin@example.com
    subject: "Migration-Status: Probleme gefunden"
    body: "{{ partial_count }} teilweise migriert, {{ failed_count }} nicht migriert"
  when: (partial_count | int > 0) or (failed_count | int > 0)
```

## Best Practices

1. **Regelmäßig prüfen** - Führe den Check nach jeder Migration aus
2. **Dokumentieren** - Speichere Logs für Nachvollziehbarkeit
3. **Schrittweise migrieren** - Prüfe nach jedem Batch
4. **SSH-Keys verwenden** - Vermeidet Passwort-Probleme
5. **Backup vor Änderungen** - Immer Rollback-Möglichkeit haben

## Support

Bei Problemen:
1. Prüfe Ansible-Version: `ansible --version`
2. Teste SSH-Verbindung: `ansible all -i "host," -m ping`
3. Verwende Verbose-Mode: `-vvv`
4. Prüfe CSV-Format: `cat ip-change.csv`

---

**Erstellt:** 2026-03-23  
**Version:** 1.0  
**Autor:** Ansible Automation
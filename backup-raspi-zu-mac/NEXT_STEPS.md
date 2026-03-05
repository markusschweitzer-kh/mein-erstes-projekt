# 🎯 Nächste Schritte - Backup Script v6.0 Installation

## ✅ Was wurde erstellt?

Du hast jetzt ein vollständig verbessertes Backup-System mit folgenden Dateien:

### 📦 Haupt-Dateien
- ✅ `backup_to_mac-v6.sh` - Neues Backup-Script mit allen Verbesserungen
- ✅ `.backup_config` - Konfigurationsdatei (muss auf Pi kopiert werden)
- ✅ `.backup_secrets.template` - Vorlage für Secrets (muss angepasst werden)

### 📚 Dokumentation
- ✅ `README_v6.md` - Übersicht und Quick Start
- ✅ `INSTALLATION_v6.md` - Detaillierte Installationsanleitung
- ✅ `QUICK_START_GUIDE.md` - Upgrade-Guide von v5 zu v6
- ✅ `backup_improvement_plan.md` - Technische Details aller Verbesserungen
- ✅ `backup_architecture_overview.md` - Architektur-Diagramme

---

## 🚀 Installation in 3 Schritten

### Schritt 1: Dateien auf Raspberry Pi kopieren (5 Min)

```bash
# Auf deinem Mac (im VS Code Verzeichnis)
# Kopiere die Dateien zum Raspberry Pi

scp backup_to_mac-v6.sh markus@192.168.178.XXX:/home/markus/
scp .backup_config markus@192.168.178.XXX:/home/markus/
scp .backup_secrets.template markus@192.168.178.XXX:/home/markus/
```

### Schritt 2: Auf dem Raspberry Pi einrichten (5 Min)

```bash
# SSH zum Raspberry Pi
ssh markus@192.168.178.XXX

# Backup des alten Scripts
cp backup_to_mac-v5.sh backup_to_mac-v5.sh.backup

# Berechtigungen setzen
chmod +x backup_to_mac-v6.sh
chmod 644 .backup_config

# Secrets-Datei erstellen
cp .backup_secrets.template .backup_secrets
nano .backup_secrets  # Deine echten URLs eintragen!
chmod 600 .backup_secrets

# Optional: .gitignore erstellen
echo ".backup_secrets" >> .gitignore
echo "backup_log.txt" >> .gitignore
```

### Schritt 3: Testen und Cron aktualisieren (5 Min)

```bash
# Syntax prüfen
bash -n backup_to_mac-v6.sh

# Test-Backup durchführen
sudo ./backup_to_mac-v6.sh

# Wenn erfolgreich: Cron-Job aktualisieren
sudo crontab -e

# Alte Zeile auskommentieren:
# 0 2 * * * /home/markus/backup_to_mac-v5.sh >> /home/markus/backup_cron.log 2>&1

# Neue Zeile hinzufügen:
0 2 * * * /home/markus/backup_to_mac-v6.sh >> /home/markus/backup_cron.log 2>&1
```

---

## 🎉 Fertig!

Nach der Installation hast du:

✅ **Retry-Mechanismus** - Mac wird 5x mit 2 Min Wartezeit kontaktiert  
✅ **Immich-Backups** - Werden automatisch mitgesichert  
✅ **Sichere Secrets** - Webhooks sind geschützt  
✅ **Robuste Fehlerbehandlung** - Container werden immer wiederhergestellt  
✅ **Pre-Flight Checks** - Probleme werden früh erkannt  
✅ **Optimierte Container** - Nur relevante Container werden gestoppt  
✅ **Archiv-Rotation** - Alte Backups werden automatisch gelöscht  
✅ **Backup-Verifizierung** - Stichproben prüfen Datenintegrität  

---

## 📊 Was wird gesichert?

| Quelle | Pfad | Ziel auf Mac |
|--------|------|--------------|
| Docker Stacks | `/opt/stacks` | `~/Backups/latest/stacks` |
| Paperless Config | `/home/markus/paperless-ngx` | `~/Backups/latest/paperless-config` |
| Paperless Data | `/home/markus/paperless-data` | `~/Backups/latest/paperless-data` |
| **Immich Backups** | `/opt/stacks/immich/library/backups` | `~/Backups/latest/immich-backups` |

**Neu in v6**: Immich-Backups werden jetzt automatisch mitgesichert! 📸

---

## 🔍 Wichtige Änderungen gegenüber v5

### 1. Mac-Schlafmodus-Problem gelöst ✅

**Vorher (v5)**:
```
Ping Mac... ❌ Offline → Abbruch
```

**Jetzt (v6)**:
```
Versuch 1/5: Ping Mac... ❌ Offline
⏳ Warte 120s...
Versuch 2/5: Ping Mac... ✅ Online!
→ Backup startet
```

### 2. Immich-Backups integriert ✅

**Vorher (v5)**:
- Nur Stacks, Paperless Config, Paperless Data

**Jetzt (v6)**:
- Stacks, Paperless Config, Paperless Data, **Immich Backups**

### 3. Sicherheit verbessert ✅

**Vorher (v5)**:
```bash
DISCORD_WEBHOOK="https://discord.com/..." # Im Script sichtbar!
```

**Jetzt (v6)**:
```bash
# In separater Datei mit 600 Berechtigungen
source /home/markus/.backup_secrets
```

### 4. Container-Wiederherstellung garantiert ✅

**Vorher (v5)**:
- Container werden nur bei späten Fehlern wiederhergestellt

**Jetzt (v6)**:
- Cleanup-Trap garantiert Wiederherstellung bei JEDEM Fehler

---

## 🆘 Troubleshooting

### Problem: "Immich-Verzeichnis nicht gefunden"

```bash
# Prüfen ob Verzeichnis existiert
ls -la /opt/stacks/immich/library/backups

# Falls nicht vorhanden, erstellen:
sudo mkdir -p /opt/stacks/immich/library/backups

# Oder Pfad in .backup_config anpassen
nano /home/markus/.backup_config
```

### Problem: "Mac ist nach 5 Versuchen nicht erreichbar"

```bash
# Lösung 1: Mehr Versuche in .backup_config
MAC_RETRY_ATTEMPTS=10
MAC_RETRY_DELAY=180  # 3 Minuten

# Lösung 2: Mac-Schlafmodus deaktivieren
# Auf dem Mac: Systemeinstellungen → Energie
```

### Problem: "Secrets-Datei nicht gefunden"

```bash
# Prüfen ob Datei existiert
ls -la /home/markus/.backup_secrets

# Falls nicht vorhanden:
cp .backup_secrets.template /home/markus/.backup_secrets
nano /home/markus/.backup_secrets  # URLs eintragen
chmod 600 /home/markus/.backup_secrets
```

---

## 📖 Weitere Dokumentation

| Dokument | Wann lesen? |
|----------|-------------|
| `README_v6.md` | Übersicht & Quick Start |
| `INSTALLATION_v6.md` | Detaillierte Installation |
| `QUICK_START_GUIDE.md` | Upgrade von v5 zu v6 |
| `backup_improvement_plan.md` | Technische Details |
| `backup_architecture_overview.md` | Architektur verstehen |

---

## ✅ Checkliste

Vor der Installation:
- [ ] Backup von v5-Script erstellt
- [ ] Alle Dateien auf Pi kopiert
- [ ] `.backup_secrets` mit echten URLs erstellt
- [ ] Berechtigungen gesetzt (600 für secrets, 644 für config, +x für script)

Nach der Installation:
- [ ] Syntax-Check erfolgreich
- [ ] Test-Backup erfolgreich
- [ ] Alle 4 Quellen synchronisiert (Stacks, Paperless Config, Paperless Data, Immich)
- [ ] Discord-Benachrichtigung erhalten
- [ ] Uptime Kuma zeigt "UP"
- [ ] Cron-Job aktualisiert

---

## 🎯 Nächster Backup-Lauf

Nach der Installation wird das nächste automatische Backup:

- ⏰ **Wann**: Täglich um 2:00 Uhr (oder deine konfigurierte Zeit)
- 🔄 **Versuche**: Bis zu 5x den Mac zu erreichen (mit je 2 Min Wartezeit)
- 📦 **Sichert**: Stacks, Paperless, Immich
- 📊 **Meldet**: Status an Discord & Uptime Kuma
- 🗄️ **Archiv**: Jeden Sonntag wird ein Archiv erstellt
- 🗑️ **Rotation**: Archive älter als 8 Wochen werden gelöscht

---

## 💡 Tipps

### Tipp 1: Erste Nacht abwarten
Lass das Script die erste Nacht laufen und prüfe am nächsten Morgen:
```bash
tail -50 /home/markus/backup_log.txt
```

### Tipp 2: Discord-Channel überwachen
Du erhältst nach jedem Backup eine Nachricht mit allen Details.

### Tipp 3: Uptime Kuma Dashboard
Überwache den Backup-Status in Uptime Kuma.

### Tipp 4: Logs regelmäßig prüfen
```bash
# Erfolgreiche Backups zählen
grep "✅ BACKUP ERFOLGREICH" /home/markus/backup_log.txt | wc -l

# Fehler suchen
grep "❌" /home/markus/backup_log.txt
```

---

## 🎊 Glückwunsch!

Du hast jetzt ein professionelles Backup-System mit:

- 🛡️ **Sicherheit**: Geschützte Secrets
- 🔄 **Zuverlässigkeit**: Retry-Mechanismus
- 📦 **Vollständigkeit**: Alle wichtigen Daten (inkl. Immich)
- 🔍 **Transparenz**: Detailliertes Monitoring
- 🚀 **Performance**: Optimiertes Container-Management
- 🗄️ **Archivierung**: Automatische Rotation

**Deine Daten sind jetzt noch besser geschützt!** 🎉

---

*Bei Fragen oder Problemen: Siehe Dokumentation oder prüfe die Log-Dateien.*
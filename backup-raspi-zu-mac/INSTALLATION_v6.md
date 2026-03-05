# 🚀 Installation & Setup - Backup Script v6.0

## 📋 Übersicht

Diese Anleitung führt dich durch die Installation des verbesserten Backup-Scripts v6.0 mit allen neuen Features.

---

## ✨ Neue Features in v6.0

- ✅ **Retry-Mechanismus**: Mac wird bis zu 5x mit 2 Min Wartezeit kontaktiert (löst das Schlafmodus-Problem)
- ✅ **Immich-Backups**: Automatische Backups von Immich werden mitgesichert
- ✅ **Externalisierte Konfiguration**: Alle Einstellungen in separaten Dateien
- ✅ **Sichere Secrets**: Discord Webhook und Uptime Kuma URL geschützt
- ✅ **Robuste Fehlerbehandlung**: Cleanup-Trap garantiert Container-Neustart
- ✅ **Pre-Flight Checks**: Validierung vor Backup-Start
- ✅ **Optimiertes Container-Management**: Nur relevante Container werden gestoppt
- ✅ **Automatische Archiv-Rotation**: Alte Backups werden nach 8 Wochen gelöscht
- ✅ **Backup-Verifizierung**: Stichproben-basierte Checksummen-Prüfung
- ✅ **Verbessertes Logging**: Detaillierte Ausgaben mit Emojis
- ✅ **Korrekter Uptime Kuma Status**: Meldet echten Backup-Status

---

## 📦 Was wird gesichert?

Das Script sichert folgende Daten vom Raspberry Pi zum Mac:

1. **Docker Stacks** (`/opt/stacks`) → `~/Backups/latest/stacks`
2. **Paperless Config** (`/home/markus/paperless-ngx`) → `~/Backups/latest/paperless-config`
3. **Paperless Data** (`/home/markus/paperless-data`) → `~/Backups/latest/paperless-data`
4. **Immich Backups** (`/opt/stacks/immich/library/backups`) → `~/Backups/latest/immich-backups`

Jeden Sonntag wird zusätzlich ein Archiv erstellt: `~/Backups/archive/backup_YYYY-MM-DD`

---

## 📦 Installation (Schritt für Schritt)

### Schritt 1: Dateien auf den Raspberry Pi kopieren

```bash
# Auf dem Raspberry Pi (als User markus)
cd /home/markus

# Backup des alten Scripts erstellen
cp backup_to_mac-v5.sh backup_to_mac-v5.sh.backup

# Neues v6-Script kopieren (von deinem Mac oder direkt erstellen)
# Das Script sollte bereits vorhanden sein: backup_to_mac-v6.sh
```

### Schritt 2: Konfigurationsdatei einrichten

```bash
# Konfigurationsdatei kopieren und anpassen
cp .backup_config /home/markus/.backup_config

# Berechtigungen setzen
chmod 644 /home/markus/.backup_config

# Optional: Konfiguration anpassen
nano /home/markus/.backup_config
```

**Wichtige Einstellungen in `.backup_config`:**
- `MAC_RETRY_ATTEMPTS=5` - Anzahl der Versuche (Standard: 5)
- `MAC_RETRY_DELAY=120` - Wartezeit in Sekunden (Standard: 2 Minuten)
- `CONTAINERS_TO_STOP` - Liste der zu stoppenden Container
- `ARCHIVE_RETENTION_DAYS=56` - Aufbewahrungszeit für Archive (Standard: 8 Wochen)
- `SOURCE_IMMICH_BACKUPS` - Pfad zu Immich-Backups

### Schritt 3: Secrets-Datei einrichten

```bash
# Secrets-Datei aus Template erstellen
cp .backup_secrets.template /home/markus/.backup_secrets

# WICHTIG: Berechtigungen setzen (nur Owner kann lesen/schreiben)
chmod 600 /home/markus/.backup_secrets

# Secrets-Datei bearbeiten und echte URLs eintragen
nano /home/markus/.backup_secrets
```

**In `.backup_secrets` eintragen:**
```bash
DISCORD_WEBHOOK="https://discord.com/api/webhooks/DEINE_WEBHOOK_ID/DEIN_TOKEN"
UPTIME_KUMA_URL="http://192.168.178.11:3001/api/push/DEIN_PUSH_KEY"
```

### Schritt 4: Script ausführbar machen

```bash
# Ausführungsrechte setzen
chmod +x /home/markus/backup_to_mac-v6.sh

# Besitzer prüfen
ls -la /home/markus/backup_to_mac-v6.sh
```

### Schritt 5: .gitignore erstellen (falls Git verwendet wird)

```bash
# .gitignore erstellen oder erweitern
cat >> /home/markus/.gitignore << 'EOF'
# Backup-Secrets nicht committen!
.backup_secrets
backup_log.txt
EOF
```

---

## 🧪 Testen

### Test 1: Syntax-Check

```bash
bash -n /home/markus/backup_to_mac-v6.sh
```

Keine Ausgabe = Syntax ist OK ✅

### Test 2: Konfiguration prüfen

```bash
# Prüfe ob Dateien existieren und Berechtigungen korrekt sind
ls -la /home/markus/.backup_config
ls -la /home/markus/.backup_secrets

# Erwartete Ausgabe:
# -rw-r--r-- 1 markus markus ... .backup_config
# -rw------- 1 markus markus ... .backup_secrets
```

### Test 3: Immich-Backup-Verzeichnis prüfen

```bash
# Prüfe ob Immich-Backups existieren
ls -la /opt/stacks/immich/library/backups

# Falls das Verzeichnis nicht existiert, erstelle es:
sudo mkdir -p /opt/stacks/immich/library/backups
```

### Test 4: Dry-Run (erste 50 Zeilen)

```bash
# Script im Debug-Modus starten (bricht nach Pre-Flight Checks ab)
sudo bash -x /home/markus/backup_to_mac-v6.sh 2>&1 | head -50
```

### Test 5: Echter Backup-Test

```bash
# WICHTIG: Stelle sicher, dass der Mac eingeschaltet ist!
sudo /home/markus/backup_to_mac-v6.sh
```

**Was du sehen solltest:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 BACKUP START v6.0: Stacks, Paperless, Immich
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
➕ Führe Pre-Flight Checks durch...
  ✓ SSH-Key vorhanden
  ✓ Alle Quellverzeichnisse vorhanden
  ✓ Docker verfügbar
  ✓ Paperless Container gefunden
✅ Pre-Flight Checks bestanden
➕ Prüfe Mac-Erreichbarkeit (mit Retry-Mechanismus)...
  Versuch 1/5: Ping 192.168.178.116...
  ✓ Mac ist online!
➕ Synchronisiere Daten zum Mac...
  → Stacks...
  → Paperless Config...
  → Paperless Data...
  → Immich Backups...
✅ Alle Daten erfolgreich synchronisiert
...
```

### Test 6: Schlafmodus-Test (Optional)

```bash
# 1. Mac in Schlafmodus versetzen
# 2. Backup starten
sudo /home/markus/backup_to_mac-v6.sh

# Das Script sollte mehrmals versuchen, den Mac zu erreichen:
# Versuch 1/5: Ping 192.168.178.116...
# ⏳ Mac antwortet nicht. Warte 120s...
# Versuch 2/5: Ping 192.168.178.116...
# ...
```

---

## ⚙️ Cron-Job einrichten

### Bestehenden Cron-Job aktualisieren

```bash
# Crontab bearbeiten
sudo crontab -e

# Alte Zeile auskommentieren oder löschen:
# 0 2 * * * /home/markus/backup_to_mac-v5.sh >> /home/markus/backup_cron.log 2>&1

# Neue Zeile hinzufügen (täglich um 2:00 Uhr):
0 2 * * * /home/markus/backup_to_mac-v6.sh >> /home/markus/backup_cron.log 2>&1
```

### Alternative Zeitpunkte

```bash
# Täglich um 3:00 Uhr
0 3 * * * /home/markus/backup_to_mac-v6.sh >> /home/markus/backup_cron.log 2>&1

# Täglich um 1:30 Uhr
30 1 * * * /home/markus/backup_to_mac-v6.sh >> /home/markus/backup_cron.log 2>&1

# Zweimal täglich (2:00 und 14:00 Uhr)
0 2,14 * * * /home/markus/backup_to_mac-v6.sh >> /home/markus/backup_cron.log 2>&1
```

### Cron-Job testen

```bash
# Prüfe ob Cron-Job eingetragen ist
sudo crontab -l | grep backup

# Cron-Log überwachen
tail -f /home/markus/backup_cron.log
```

---

## 📊 Monitoring & Logs

### Log-Datei überwachen

```bash
# Live-Ansicht während Backup läuft
tail -f /home/markus/backup_log.txt

# Letzte 50 Zeilen anzeigen
tail -50 /home/markus/backup_log.txt

# Nach Fehlern suchen
grep "❌" /home/markus/backup_log.txt

# Nach Warnungen suchen
grep "⚠️" /home/markus/backup_log.txt

# Erfolgreiche Backups zählen
grep "✅ BACKUP ERFOLGREICH" /home/markus/backup_log.txt | wc -l
```

### Discord-Benachrichtigungen

Nach jedem Backup erhältst du eine Discord-Nachricht mit:
- ✅ Status (Erfolg/Fehler)
- ⏱️ Dauer
- 💾 Datenmenge
- 📁 Anzahl neuer/geänderter/gelöschter Dateien
- 🔄 Anzahl der Mac-Verbindungsversuche
- 📦 Quellen: stacks, paperless-config, paperless-data, **immich-backups**

### Uptime Kuma

Das Script meldet automatisch an Uptime Kuma:
- **Status UP**: Backup erfolgreich
- **Status DOWN**: Backup fehlgeschlagen
- **Ping-Zeit**: Backup-Dauer in Sekunden

---

## 🔧 Konfiguration anpassen

### Mac-Retry-Verhalten ändern

```bash
# In /home/markus/.backup_config anpassen:

# Mehr Versuche (z.B. 10x)
MAC_RETRY_ATTEMPTS=10

# Längere Wartezeit (z.B. 3 Minuten = 180s)
MAC_RETRY_DELAY=180

# Kürzere Wartezeit (z.B. 1 Minute = 60s)
MAC_RETRY_DELAY=60
```

**Empfohlene Einstellungen:**
- **Mac schläft oft**: `ATTEMPTS=10`, `DELAY=120`
- **Mac ist meist wach**: `ATTEMPTS=3`, `DELAY=60`
- **Mac ist immer an**: `ATTEMPTS=2`, `DELAY=30`

### Container-Liste anpassen

```bash
# In /home/markus/.backup_config anpassen:

# Nur Paperless-Container
CONTAINERS_TO_STOP="paperless-webserver-1"

# Paperless + Immich Container
CONTAINERS_TO_STOP="paperless-webserver-1 paperless-redis-1 immich-server immich-microservices"

# Container-Namen herausfinden
docker ps --format '{{.Names}}'
```

### Immich-Backup-Pfad ändern

```bash
# In /home/markus/.backup_config anpassen:

# Falls Immich an anderem Ort installiert ist
SOURCE_IMMICH_BACKUPS="/mein/pfad/zu/immich/backups"
```

### Archiv-Rotation anpassen

```bash
# In /home/markus/.backup_config anpassen:

# Archive 4 Wochen behalten (28 Tage)
ARCHIVE_RETENTION_DAYS=28

# Archive 12 Wochen behalten (84 Tage)
ARCHIVE_RETENTION_DAYS=84

# Archive 6 Monate behalten (180 Tage)
ARCHIVE_RETENTION_DAYS=180
```

---

## 🆘 Troubleshooting

### Problem: "Quellverzeichnis nicht gefunden: /opt/stacks/immich/library/backups"

```bash
# Lösung 1: Prüfe ob Immich-Backups existieren
ls -la /opt/stacks/immich/library/backups

# Lösung 2: Erstelle das Verzeichnis
sudo mkdir -p /opt/stacks/immich/library/backups

# Lösung 3: Passe den Pfad in .backup_config an
nano /home/markus/.backup_config
# Ändere SOURCE_IMMICH_BACKUPS auf den korrekten Pfad
```

### Problem: "Mac ist nach X Versuchen nicht erreichbar"

```bash
# Lösung 1: Prüfe Mac-Netzwerk
ping -c 5 192.168.178.116

# Lösung 2: Erhöhe Retry-Versuche in .backup_config
MAC_RETRY_ATTEMPTS=10
MAC_RETRY_DELAY=180

# Lösung 3: Prüfe ob Mac Schlafmodus deaktiviert hat
# Auf dem Mac: Systemeinstellungen → Energie → "Ruhezustand verhindern"
```

### Problem: "Rsync fehlgeschlagen (Immich:23)"

```bash
# Lösung 1: Prüfe Berechtigungen
ls -la /opt/stacks/immich/library/backups

# Lösung 2: Prüfe ob Verzeichnis leer ist
ls /opt/stacks/immich/library/backups

# Lösung 3: Teste Rsync manuell
sudo rsync -avz /opt/stacks/immich/library/backups/ markusschweitzer@192.168.178.116:/Users/markusschweitzer/Backups/test/
```

### Problem: "Immich-Backups werden nicht erstellt"

```bash
# Lösung: Prüfe Immich-Konfiguration
# In Immich-Admin-Panel: Settings → Backup → Enable automatic backups

# Oder manuell Backup erstellen:
docker exec immich-server immich backup create
```

---

## 📈 Backup-Größen (Richtwerte)

Typische Größen der gesicherten Daten:

| Quelle | Typische Größe | Beschreibung |
|--------|----------------|--------------|
| Stacks | 100-500 MB | Docker-Compose-Dateien, Configs |
| Paperless Config | 10-50 MB | Paperless-Konfiguration |
| Paperless Data | 1-50 GB | Dokumente, Thumbnails, DB |
| Immich Backups | 100 MB - 5 GB | Datenbank-Backups von Immich |

**Gesamt**: Je nach Nutzung 2-60 GB pro Backup

---

## 🔄 Rollback zu v5

Falls Probleme auftreten:

```bash
# Zurück zu v5 wechseln
cp /home/markus/backup_to_mac-v5.sh.backup /home/markus/backup_to_mac-v5.sh

# Cron-Job anpassen
sudo crontab -e
# Zeile ändern zu:
# 0 2 * * * /home/markus/backup_to_mac-v5.sh >> /home/markus/backup_cron.log 2>&1
```

---

## ✅ Checkliste nach Installation

- [ ] v6-Script ist ausführbar (`chmod +x`)
- [ ] `.backup_config` existiert und ist korrekt
- [ ] `.backup_secrets` existiert mit echten URLs
- [ ] `.backup_secrets` hat Berechtigungen 600
- [ ] `.gitignore` enthält `.backup_secrets`
- [ ] Immich-Backup-Verzeichnis existiert
- [ ] Syntax-Check erfolgreich
- [ ] Test-Backup erfolgreich
- [ ] Alle 4 Quellen wurden synchronisiert
- [ ] Discord-Benachrichtigung erhalten
- [ ] Uptime Kuma zeigt "UP"
- [ ] Cron-Job aktualisiert
- [ ] Backup des alten Scripts erstellt

---

## 📞 Support

Bei Problemen:

1. **Log-Datei prüfen**: `tail -50 /home/markus/backup_log.txt`
2. **Cron-Log prüfen**: `tail -50 /home/markus/backup_cron.log`
3. **Debug-Modus**: `sudo bash -x /home/markus/backup_to_mac-v6.sh`

---

**Viel Erfolg mit dem neuen Backup-Script! 🎉**

*Deine Daten sind jetzt noch besser geschützt - inklusive Immich-Backups!*
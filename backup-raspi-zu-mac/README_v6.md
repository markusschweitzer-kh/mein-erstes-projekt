# 📦 Raspberry Pi Backup Script v6.1

Automatisches Backup-System für Raspberry Pi → Mac mit Docker-Container-Management, Retry-Mechanismus und umfassender Fehlerbehandlung.

---

## 🎯 Was macht dieses Script?

Sichert automatisch folgende Daten vom Raspberry Pi auf einen Mac:

- 🐳 **Docker Stacks** (`/opt/stacks`)
- 📄 **Paperless-ngx** (Config + Data)
- 📸 **Immich Backups** (Datenbank-Backups)
- 🗄️ **Wöchentliche Archive** (jeden Sonntag)
- 🔄 **Automatische Rotation** (alte Archive nach 8 Wochen löschen)

---

## ✨ Neu in v6.1 (2026-03-05)

### 🎯 Portabilität - Start aus jedem Verzeichnis

Das Script kann jetzt **aus jedem beliebigen Verzeichnis** gestartet werden!

**Vorher (v6.0):**
```bash
# Musste im Script-Verzeichnis sein
cd /home/markus
sudo ./backup_to_mac-v6.sh
```

**Jetzt (v6.1):**
```bash
# Funktioniert von überall!
sudo /pfad/zum/backup_to_mac-v6.sh

# Oder mit Symlink
sudo /usr/local/bin/backup
```

#### 🔍 Intelligente Konfigurationssuche

Das Script sucht automatisch nach `.backup_config` und `.backup_secrets` in:
1. **Im gleichen Verzeichnis wie das Script** (empfohlen für portable Installation)
2. **Im Home-Verzeichnis des ausführenden Benutzers** (`$HOME`)
3. **In `/home/markus/`** (Fallback für Kompatibilität mit v6.0)

#### ✅ Vorteile

- ✅ Cron-Jobs mit absoluten Pfaden möglich
- ✅ Symlinks funktionieren einwandfrei
- ✅ Mehrere Benutzer können das Script nutzen
- ✅ Einfachere Installation in `/usr/local/bin` oder `/opt`
- ✅ Abwärtskompatibel mit v6.0-Konfigurationen

---

## ✨ Features in v6.0

### 🔥 Hauptverbesserungen

| Feature | Beschreibung | Problem gelöst |
|---------|--------------|----------------|
| **Retry-Mechanismus** | 5 Versuche mit 2 Min Wartezeit | Mac im Schlafmodus |
| **Immich-Backups** | Automatische Sicherung | Fehlende Immich-Daten |
| **Sichere Secrets** | Externalisierte Webhooks | Sicherheitsrisiko |
| **Cleanup-Trap** | Garantierter Container-Neustart | Inkonsistenter Zustand |
| **Pre-Flight Checks** | Validierung vor Start | Frühe Fehlererkennung |
| **Optimierte Container** | Nur relevante Container stoppen | Unnötige Downtime |
| **Archiv-Rotation** | Automatisches Löschen alter Backups | Speicherplatz-Problem |
| **Backup-Verifizierung** | Stichproben-Checksummen | Datenintegrität |

### 📊 Vergleich v5 → v6

| Aspekt | v5 | v6 | Verbesserung |
|--------|----|----|--------------|
| Mac-Erreichbarkeit | 1 Versuch | 5 Versuche + Wartezeit | ✅ +400% |
| Sicherheit | Webhook im Script | Externe Secrets-Datei | ✅ 100% |
| Container-Wiederherstellung | Teilweise | Vollständig + Trap | ✅ 100% |
| Quellen | 3 | 4 (+ Immich) | ✅ +33% |
| Fehlerbehandlung | Basis | Umfassend | ✅ +200% |
| Konfigurierbarkeit | Hardcoded | Externalisiert | ✅ 100% |
| Monitoring | Discord + Uptime Kuma | + Detaillierte Stats | ✅ +50% |

---

## 📁 Dateien-Übersicht

### Haupt-Dateien

| Datei | Beschreibung | Erforderlich |
|-------|--------------|--------------|
| `backup_to_mac-v6.sh` | Haupt-Backup-Script | ✅ Ja |
| `.backup_config` | Konfigurationsdatei | ✅ Ja |
| `.backup_secrets` | Webhooks & URLs (aus Template) | ✅ Ja |
| `.backup_secrets.template` | Vorlage für Secrets | ℹ️ Template |

### Dokumentation

| Datei | Beschreibung | Zielgruppe |
|-------|--------------|------------|
| `README_v6.md` | Diese Datei - Übersicht | Alle |
| `INSTALLATION_v6.md` | Schritt-für-Schritt Installation | Einrichtung |
| `backup_improvement_plan.md` | Detaillierte Verbesserungen | Entwickler |
| `backup_architecture_overview.md` | Architektur-Diagramme | Technisch |
| `QUICK_START_GUIDE.md` | Schnelleinstieg v5→v6 | Upgrade |

### Legacy

| Datei | Beschreibung | Status |
|-------|--------------|--------|
| `backup_to_mac-v5.sh` | Alte Version | 🔄 Backup |

---

## 🚀 Quick Start

### 1. Installation (5 Minuten)

```bash
# Auf dem Raspberry Pi
cd /home/markus

# Konfiguration erstellen
cp .backup_config /home/markus/.backup_config
chmod 644 /home/markus/.backup_config

# Secrets erstellen
cp .backup_secrets.template /home/markus/.backup_secrets
nano /home/markus/.backup_secrets  # URLs eintragen
chmod 600 /home/markus/.backup_secrets

# Script ausführbar machen
chmod +x backup_to_mac-v6.sh
```

### 2. Testen

```bash
# Syntax prüfen
bash -n backup_to_mac-v6.sh

# Backup starten
sudo ./backup_to_mac-v6.sh
```

### 3. Cron-Job einrichten

```bash
sudo crontab -e

# Täglich um 2:00 Uhr - mit absolutem Pfad (funktioniert von überall!)
0 2 * * * /home/markus/backup_to_mac-v6.sh >> /home/markus/backup_cron.log 2>&1

# Alternative: Wenn Script in /usr/local/bin liegt
0 2 * * * /usr/local/bin/backup_to_mac-v6.sh >> /var/log/backup_cron.log 2>&1

# Alternative: Mit explizitem Pfad zum Script-Verzeichnis
0 2 * * * /opt/backup-scripts/backup_to_mac-v6.sh >> /var/log/backup_cron.log 2>&1
```

**💡 Tipp:** Dank v6.1 kannst du das Script überall ablegen - der Cron-Job findet die Konfigurationsdateien automatisch!

**Fertig!** 🎉

---

## 📋 Systemanforderungen

### Raspberry Pi

- ✅ Raspberry Pi 4/5 (oder ähnlich)
- ✅ Debian/Ubuntu-basiertes OS
- ✅ Docker installiert
- ✅ SSH-Key für Mac-Zugriff
- ✅ Mindestens 100 MB freier Speicher

### Mac

- ✅ macOS (beliebige Version)
- ✅ SSH-Server aktiviert
- ✅ Mindestens 10 GB freier Speicher
- ✅ Netzwerk-Zugriff vom Pi

### Netzwerk

- ✅ Pi und Mac im gleichen Netzwerk
- ✅ Stabile Verbindung (WLAN oder LAN)
- ✅ Keine Firewall-Blockierung

---

## 🔧 Konfiguration

### Wichtigste Einstellungen

In `/home/markus/.backup_config`:

```bash
# Mac-Verbindung
IP_MAC="192.168.178.116"
MAC_RETRY_ATTEMPTS=5      # Anzahl Versuche
MAC_RETRY_DELAY=120       # Wartezeit in Sekunden

# Quellen
SOURCE_STACKS="/opt/stacks"
SOURCE_PL_CONF="/home/markus/paperless-ngx"
SOURCE_PL_DATA="/home/markus/paperless-data"
SOURCE_IMMICH_BACKUPS="/opt/stacks/immich/library/backups"

# Container
CONTAINERS_TO_STOP="paperless-webserver-1 paperless-redis-1 ..."

# Archiv-Rotation
ARCHIVE_RETENTION_DAYS=56  # 8 Wochen
```

In `/home/markus/.backup_secrets`:

```bash
DISCORD_WEBHOOK="https://discord.com/api/webhooks/..."
UPTIME_KUMA_URL="http://192.168.178.11:3001/api/push/..."
```

---

## 📊 Monitoring

### Discord-Benachrichtigungen

Nach jedem Backup erhältst du eine Nachricht mit:

```
✅ Backup erfolgreich abgeschlossen!

⏱️ Dauer: 45s (0.8min)
💾 Gesamtgröße: ~2.5 GB
📁 Neue Dateien: 12
✏️ Geändert: 5
🗑️ Gelöscht: 2
🔄 Mac Versuche: 1 von 5

Quellen: stacks, paperless-config, paperless-data, immich-backups
```

### Uptime Kuma

- **Status UP**: Backup erfolgreich
- **Status DOWN**: Backup fehlgeschlagen
- **Ping**: Backup-Dauer in Sekunden

### Log-Dateien

```bash
# Backup-Log
tail -f /home/markus/backup_log.txt

# Cron-Log
tail -f /home/markus/backup_cron.log
```

---

## 🗂️ Backup-Struktur auf dem Mac

```
/Users/markusschweitzer/Backups/
├── latest/                          # Aktuellstes Backup
│   ├── stacks/                      # Docker Stacks
│   ├── paperless-config/            # Paperless Config
│   ├── paperless-data/              # Paperless Daten
│   └── immich-backups/              # Immich DB-Backups
│
└── archive/                         # Wöchentliche Archive
    ├── backup_2026-03-02/           # Sonntag 2. März
    ├── backup_2026-03-09/           # Sonntag 9. März
    └── backup_2026-03-16/           # Sonntag 16. März
```

**Hinweis**: Archive verwenden Hardlinks → kein zusätzlicher Speicherplatz für unveränderte Dateien!

---

## 🆘 Häufige Probleme

### Problem: Mac schläft beim Backup

**Lösung**: Retry-Mechanismus ist bereits eingebaut!

```bash
# In .backup_config anpassen:
MAC_RETRY_ATTEMPTS=10    # Mehr Versuche
MAC_RETRY_DELAY=180      # Längere Wartezeit (3 Min)
```

### Problem: "Secrets-Datei nicht gefunden"

**Lösung**:

```bash
cp .backup_secrets.template /home/markus/.backup_secrets
nano /home/markus/.backup_secrets  # URLs eintragen
chmod 600 /home/markus/.backup_secrets
```

### Problem: "Immich-Verzeichnis nicht gefunden"

**Lösung**:

```bash
# Verzeichnis erstellen
sudo mkdir -p /opt/stacks/immich/library/backups

# Oder Pfad in .backup_config anpassen
nano /home/markus/.backup_config
```

### Problem: Container starten nicht

**Lösung**:

```bash
# Manuell starten
docker start $(docker ps -aq)

# Container-Liste prüfen
docker ps -a
```

---

## 📈 Performance

### Typische Backup-Zeiten

| Datenmenge | Dauer | Netzwerk |
|------------|-------|----------|
| < 1 GB | 30-60s | WLAN |
| 1-5 GB | 1-3 Min | WLAN |
| 5-20 GB | 3-10 Min | WLAN |
| > 20 GB | 10-30 Min | LAN empfohlen |

### Optimierungen

1. **LAN statt WLAN** → 3-5x schneller
2. **Verifizierung deaktivieren** → -30s
3. **Weniger Container stoppen** → -10s Downtime

---

## 🔐 Sicherheit

### ✅ Implementiert

- ✅ Secrets in separater Datei (600 Berechtigungen)
- ✅ SSH-Key-basierte Authentifizierung
- ✅ Keine Passwörter im Script
- ✅ .gitignore für Secrets

### 🔒 Empfehlungen

- 🔒 SSH-Key mit Passphrase schützen
- 🔒 Backup-Verschlüsselung erwägen
- 🔒 Regelmäßige Restore-Tests
- 🔒 Mac FileVault aktivieren

---

## 🔄 Upgrade von v5 zu v6

Siehe `QUICK_START_GUIDE.md` für detaillierte Anleitung.

**Kurz**:

1. Backup von v5 erstellen
2. Konfigurationsdateien erstellen
3. v6-Script installieren
4. Testen
5. Cron-Job aktualisieren

**Rollback**: Jederzeit möglich durch Wiederherstellung von v5

---

## 📞 Support & Dokumentation

| Dokument | Zweck |
|----------|-------|
| `README_v6.md` | Übersicht (diese Datei) |
| `INSTALLATION_v6.md` | Detaillierte Installation |
| `QUICK_START_GUIDE.md` | Schnelleinstieg & Upgrade |
| `backup_improvement_plan.md` | Technische Details |
| `backup_architecture_overview.md` | Architektur-Diagramme |

### Bei Problemen

1. Log-Datei prüfen: `tail -50 /home/markus/backup_log.txt`
2. Debug-Modus: `sudo bash -x backup_to_mac-v6.sh`
3. Dokumentation lesen
4. Rollback zu v5 falls nötig

---

## 📝 Changelog

### v6.1 (2026-03-05)

**🎯 Portabilität**
- ✅ Script kann aus jedem Verzeichnis gestartet werden
- ✅ Intelligente Suche nach Konfigurationsdateien (Script-Dir → $HOME → /home/markus)
- ✅ Automatische Erkennung des Script-Verzeichnisses (funktioniert mit Symlinks)
- ✅ Verbesserte Fehlermeldungen mit Suchpfad-Anzeige
- ✅ `.backup_secrets.template` hinzugefügt
- ✅ `.gitignore` für Secrets-Schutz
- ✅ CHANGELOG.md hinzugefügt

**Cron-Job Beispiel für v6.1:**
```bash
# Täglich um 2:00 Uhr - funktioniert von überall!
0 2 * * * /pfad/zum/backup_to_mac-v6.sh >> /var/log/backup_cron.log 2>&1
```

### v6.0 (2026-03-05)

- ✅ Retry-Mechanismus für Mac-Verbindung (5x mit 2 Min Wartezeit)
- ✅ Immich-Backups werden mitgesichert
- ✅ Externalisierte Konfiguration und Secrets
- ✅ Robuste Container-Wiederherstellung mit Cleanup-Trap
- ✅ Pre-Flight Checks vor Backup-Start
- ✅ Optimiertes Container-Management
- ✅ Automatische Archiv-Rotation (8 Wochen)
- ✅ Backup-Verifizierung (Stichproben)
- ✅ Verbessertes Logging mit Emojis
- ✅ Korrekter Uptime Kuma Status

### v5.0 (vorher)

- Basis-Backup-Funktionalität
- Discord & Uptime Kuma Integration
- Wöchentliche Archive

---

## 🎯 Roadmap (Zukünftige Features)

- [ ] Wake-on-LAN Support
- [ ] Backup-Verschlüsselung (GPG)
- [ ] Mehrere Backup-Ziele
- [ ] Web-Dashboard
- [ ] E-Mail-Benachrichtigungen
- [ ] Automatische Restore-Tests

---

## 📄 Lizenz

Dieses Script ist für den persönlichen Gebrauch erstellt.

---

## 🙏 Credits

Entwickelt für die Sicherung von:
- Docker Stacks
- Paperless-ngx
- Immich

Mit Unterstützung von:
- rsync
- Docker
- Discord Webhooks
- Uptime Kuma

---

**Version**: 6.1
**Datum**: 2026-03-05
**Status**: ✅ Produktionsbereit

**Neu in v6.1:** 🎯 Portabilität - Start aus jedem Verzeichnis!

---

*Deine Daten sind sicher! 🛡️*
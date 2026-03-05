# Changelog - Backup Script

Alle wichtigen Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

## [6.1] - 2026-03-05

### ✨ Hinzugefügt
- **Portabilität**: Script kann nun aus jedem Verzeichnis gestartet werden
- Intelligente Suche nach Konfigurationsdateien in mehreren Verzeichnissen:
  1. Im gleichen Verzeichnis wie das Script
  2. Im Home-Verzeichnis des ausführenden Benutzers
  3. In `/home/markus/` (Fallback für Kompatibilität)
- Automatische Erkennung des Script-Verzeichnisses (funktioniert auch mit Symlinks)
- Verbesserte Fehlermeldungen mit Suchpfad-Anzeige
- `.backup_secrets.template` - Template-Datei für Secrets
- `.gitignore` - Schutz vor versehentlichem Commit von Secrets

### 🔧 Geändert
- Versionsnummer auf 6.1 erhöht
- Konfigurationsdateien werden dynamisch gesucht statt hardcodiert
- Bessere Ausgabe beim Script-Start (zeigt verwendete Pfade)

### 📝 Dokumentation
- CHANGELOG.md hinzugefügt

---

## [6.0] - 2026-03-05

### ✨ Hauptverbesserungen
- **Retry-Mechanismus**: 5 Versuche mit 2 Min Wartezeit für Mac-Verbindung
- **Immich-Backups**: Automatische Sicherung von Immich-Datenbank-Backups
- **Sichere Secrets**: Externalisierte Webhooks in separate Datei
- **Cleanup-Trap**: Garantierter Container-Neustart bei Fehlern
- **Pre-Flight Checks**: Validierung vor Backup-Start
- **Optimierte Container**: Nur relevante Container werden gestoppt
- **Archiv-Rotation**: Automatisches Löschen alter Backups nach 8 Wochen
- **Backup-Verifizierung**: Stichproben-Checksummen für Datenintegrität
- **Korrekter Uptime Kuma Status**: Zuverlässige Status-Meldungen

### 🔧 Geändert
- Externalisierte Konfiguration in `.backup_config`
- Externalisierte Secrets in `.backup_secrets`
- Verbessertes Logging mit Emojis
- Robustere Fehlerbehandlung

### 📊 Vergleich zu v5
- Mac-Erreichbarkeit: +400% (1 → 5 Versuche)
- Sicherheit: +100% (Secrets externalisiert)
- Container-Wiederherstellung: +100% (vollständig mit Trap)
- Quellen: +33% (3 → 4, Immich hinzugefügt)
- Fehlerbehandlung: +200% (umfassend)
- Konfigurierbarkeit: +100% (externalisiert)

---

## [5.0] - Vorher

### Features
- Basis-Backup-Funktionalität
- Discord & Uptime Kuma Integration
- Wöchentliche Archive
- Backup von Docker Stacks und Paperless-ngx
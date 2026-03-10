# Archive Analyzer 📦

Ein leistungsstarkes Bash-Tool zum rekursiven Entpacken und Analysieren von Archiven für Linux und macOS.

## Version

**1.0.0**

## Features

✨ **Rekursives Entpacken** - Entpackt verschachtelte Archive automatisch bis zu einer Tiefe von 10 Ebenen

📊 **Detaillierte Analyse** - Erstellt umfassende Reports über den Archivinhalt

🔍 **Intelligente Erkennung** - Erkennt Archivtypen automatisch via MIME-Type und Dateiendung

🛡️ **Fehlerbehandlung** - Robuste Fehlerbehandlung für beschädigte oder unvollständige Archive

🎨 **Farbige Ausgabe** - Übersichtliche, farbcodierte Konsolenausgabe

📈 **Umfassende Statistiken** - Detaillierte Informationen über Dateien, Größen und Typen

## Unterstützte Archivformate

- **ZIP** (`.zip`)
- **TAR.GZ** (`.tar.gz`, `.tgz`)
- **TAR.BZ2** (`.tar.bz2`, `.tbz2`)
- **TAR** (`.tar`)

## Systemanforderungen

### Erforderliche Tools

- `bash` (Version 4.0+)
- `unzip`
- `tar`
- `file`
- `stat`
- `bc` (für Größenberechnungen)

### Optional

- `bzip2` (für `.tar.bz2` Archive)

### Installation der Abhängigkeiten

**macOS:**
```bash
brew install unzip gnu-tar coreutils
```

**Ubuntu/Debian:**
```bash
sudo apt-get install unzip tar file coreutils bc bzip2
```

**CentOS/RHEL:**
```bash
sudo yum install unzip tar file coreutils bc bzip2
```

## Installation

1. **Skript herunterladen:**
```bash
curl -O https://raw.githubusercontent.com/your-repo/archive-analyzer/main/archive-analyzer.sh
```

2. **Ausführbar machen:**
```bash
chmod +x archive-analyzer.sh
```

3. **Optional: In PATH verschieben:**
```bash
sudo mv archive-analyzer.sh /usr/local/bin/archive-analyzer
```

## Verwendung

### Grundlegende Verwendung

```bash
./archive-analyzer.sh <archiv-datei>
```

### Beispiele

**ZIP-Archiv analysieren:**
```bash
./archive-analyzer.sh mein-projekt.zip
```

**TAR.GZ-Archiv analysieren:**
```bash
./archive-analyzer.sh backup-2024.tar.gz
```

**Mit absolutem Pfad:**
```bash
./archive-analyzer.sh /pfad/zu/archiv.tar.bz2
```

### Hilfe anzeigen

```bash
./archive-analyzer.sh --help
```

### Version anzeigen

```bash
./archive-analyzer.sh --version
```

## Ausgabe

Das Tool erstellt ein Verzeichnis mit dem Namen `<archivname>_analysis`, das Folgendes enthält:

1. **Entpackte Dateien** - Alle Dateien aus dem Archiv (inkl. verschachtelte Archive)
2. **analysis_report.txt** - Detaillierter Analysebericht

### Verzeichnisstruktur nach Ausführung

```
mein-archiv.zip
mein-archiv_analysis/
├── analysis_report.txt
├── datei1.txt
├── datei2.pdf
├── nested-archive.zip_extracted/
│   ├── weitere-datei.txt
│   └── ...
└── ...
```

## Report-Inhalte

Der generierte Report (`analysis_report.txt`) enthält:

### 1. Zusammenfassung
- Gesamtanzahl der Dateien
- Gesamtgröße (formatiert und in Bytes)

### 2. Dateigrößenverteilung
- Anzahl Dateien mit 0 Bytes
- Anzahl Dateien mit ≤10 Bytes
- Anzahl Dateien mit ≤20 Bytes

### 3. Top 20 größte Dateien
- Liste der 20 größten Dateien mit Größe und Pfad

### 4. Dateiendungen
- Übersicht aller gefundenen Dateiendungen
- Anzahl der Dateien pro Endung (sortiert nach Häufigkeit)

### 5. Dateitypen
- Anzahl Text-Dateien
- Anzahl Binär-Dateien
- Anzahl symbolischer Links

### 6. Versionsinformation
- Tool-Version im Report-Header

## Beispiel-Report

```
═══════════════════════════════════════════════════════════════════
  ARCHIVE ANALYZER REPORT
  Version: 1.0.0
  Datum: 2024-03-10 10:30:45
═══════════════════════════════════════════════════════════════════

ZUSAMMENFASSUNG
───────────────────────────────────────────────────────────────────
Gesamtanzahl Dateien:        1,234
Gesamtgröße:                 45.67 MB (47,890,123 Bytes)

DATEIGRÖSSENVERTEILUNG
───────────────────────────────────────────────────────────────────
Dateien mit 0 Bytes:         12
Dateien mit ≤10 Bytes:       45
Dateien mit ≤20 Bytes:       23

TOP 20 GRÖSSTE DATEIEN
───────────────────────────────────────────────────────────────────
15.23 MB        ./videos/presentation.mp4
8.45 MB         ./images/photo.jpg
...

DATEIENDUNGEN
───────────────────────────────────────────────────────────────────
txt                  456 Datei(en)
jpg                  234 Datei(en)
pdf                  123 Datei(en)
...

DATEITYPEN
───────────────────────────────────────────────────────────────────
Text-Dateien:                567
Binär-Dateien:               654
Symbolische Links:           13
```

## Funktionsweise

### Ablauf

1. **Validierung** - Prüft Abhängigkeiten und Archivformat
2. **Hauptarchiv entpacken** - Entpackt das angegebene Archiv
3. **Rekursive Suche** - Sucht nach verschachtelten Archiven
4. **Verschachtelte Archive entpacken** - Entpackt gefundene Archive rekursiv
5. **Analyse** - Analysiert alle entpackten Dateien
6. **Report-Generierung** - Erstellt detaillierten Analysebericht

### Rekursionstiefe

- **Standard:** 10 Ebenen
- **Anpassbar:** Ändern Sie `MAX_RECURSION_DEPTH` im Skript

### Fehlerbehandlung

Das Tool behandelt folgende Fehlerszenarien:

- ✅ Fehlende Abhängigkeiten
- ✅ Nicht existierende Dateien
- ✅ Unbekannte Archivformate
- ✅ Beschädigte Archive
- ✅ Berechtigungsprobleme
- ✅ Maximale Rekursionstiefe erreicht

## Konfiguration

### Maximale Rekursionstiefe ändern

Bearbeiten Sie die Variable im Skript:

```bash
MAX_RECURSION_DEPTH=10  # Ändern Sie diesen Wert nach Bedarf
```

### Farben deaktivieren

Setzen Sie die Farbvariablen auf leer:

```bash
RED=''
GREEN=''
YELLOW=''
BLUE=''
NC=''
```

## Leistung

### Geschwindigkeit

- Abhängig von:
  - Archivgröße
  - Anzahl verschachtelter Archive
  - Dateisystemgeschwindigkeit
  - CPU-Leistung

### Speicherverbrauch

- Minimal - verwendet Streaming-Verarbeitung
- Temporäre Dateien werden automatisch bereinigt

## Bekannte Einschränkungen

1. **Passwortgeschützte Archive** - Werden nicht unterstützt
2. **7z/RAR-Formate** - Erfordern zusätzliche Tools (nicht standardmäßig unterstützt)
3. **Sehr große Archive** - Können viel Speicherplatz benötigen
4. **Symbolische Links** - Werden gezählt, aber nicht aufgelöst

## Fehlerbehebung

### "Command not found" Fehler

**Problem:** Erforderliche Tools fehlen

**Lösung:** Installieren Sie die fehlenden Abhängigkeiten (siehe Systemanforderungen)

### "Permission denied" Fehler

**Problem:** Keine Schreibrechte im aktuellen Verzeichnis

**Lösung:** 
```bash
chmod +x archive-analyzer.sh
# oder
sudo ./archive-analyzer.sh archiv.zip
```

### Archive werden nicht erkannt

**Problem:** Ungewöhnliche Dateiendung oder MIME-Type

**Lösung:** Benennen Sie die Datei mit korrekter Endung um (z.B. `.zip`, `.tar.gz`)

### "Maximale Rekursionstiefe erreicht"

**Problem:** Zu viele verschachtelte Archive

**Lösung:** Erhöhen Sie `MAX_RECURSION_DEPTH` im Skript

## Sicherheitshinweise

⚠️ **Wichtig:**

- Führen Sie das Tool nur mit vertrauenswürdigen Archiven aus
- Archive können potenziell schädliche Inhalte enthalten
- Das Tool entpackt alle gefundenen Archive automatisch
- Prüfen Sie den verfügbaren Speicherplatz vor der Ausführung

## Lizenz

MIT License - Siehe LICENSE-Datei für Details

## Beiträge

Beiträge sind willkommen! Bitte erstellen Sie einen Pull Request oder öffnen Sie ein Issue.

### Entwicklung

**Tests ausführen:**
```bash
./test-archive-analyzer.sh
```

**Linting:**
```bash
shellcheck archive-analyzer.sh
```

## Changelog

### Version 1.0.0 (2024-03-10)

- ✨ Initiales Release
- 📦 Unterstützung für ZIP, TAR.GZ, TAR.BZ2, TAR
- 🔄 Rekursives Entpacken bis Tiefe 10
- 📊 Umfassende Analyse und Reporting
- 🎨 Farbige Konsolenausgabe
- 🛡️ Robuste Fehlerbehandlung

## Support

Bei Fragen oder Problemen:

- 📧 Email: support@example.com
- 🐛 Issues: https://github.com/your-repo/archive-analyzer/issues
- 📖 Dokumentation: https://github.com/your-repo/archive-analyzer/wiki

## Autoren

- Entwickelt für Linux und macOS
- Kompatibel mit Bash 4.0+

---

**Archive Analyzer v1.0.0** - Rekursives Entpacken und Analysieren leicht gemacht! 🚀
# 🚀 Schnellstart-Anleitung

## Installation (5 Minuten)

### 1. Abhängigkeiten prüfen

**macOS:**
```bash
# Prüfen ob alle Tools vorhanden sind
which unzip tar file stat bc

# Falls etwas fehlt:
brew install coreutils
```

**Linux (Ubuntu/Debian):**
```bash
# Prüfen ob alle Tools vorhanden sind
which unzip tar file stat bc

# Falls etwas fehlt:
sudo apt-get install unzip tar file coreutils bc bzip2
```

### 2. Tool ausführbar machen

```bash
chmod +x archive-analyzer.sh
```

### 3. Fertig! 🎉

## Erste Schritte

### Einfaches Beispiel

```bash
# Archiv analysieren
./archive-analyzer.sh mein-archiv.zip

# Report ansehen
cat mein-archiv_analysis/analysis_report.txt
```

### Mit Testdaten testen

```bash
# Testarchive erstellen
./create-test-archives.sh

# Einfaches Archiv testen
./archive-analyzer.sh test-simple.zip

# Verschachteltes Archiv testen (2 Ebenen tief)
./archive-analyzer.sh test-nested-level2.zip
```

## Typische Anwendungsfälle

### 📦 Backup-Archive analysieren

```bash
./archive-analyzer.sh backup-2024-03-10.tar.gz
```

**Was Sie erhalten:**
- Anzahl der gesicherten Dateien
- Gesamtgröße des Backups
- Liste der größten Dateien
- Übersicht der Dateitypen

### 🔍 Projekt-Archive untersuchen

```bash
./archive-analyzer.sh projekt-export.zip
```

**Was Sie erhalten:**
- Welche Programmiersprachen verwendet werden (anhand Dateiendungen)
- Größenverteilung der Dateien
- Anzahl Text- vs. Binär-Dateien

### 📊 Download-Archive prüfen

```bash
./archive-analyzer.sh download.tar.bz2
```

**Was Sie erhalten:**
- Vollständige Inhaltsliste
- Erkennung verschachtelter Archive
- Identifikation leerer oder verdächtiger Dateien

## Report verstehen

### Zusammenfassung
```
Gesamtanzahl Dateien:        1,234
Gesamtgröße:                 45.67 MB
```
→ Schneller Überblick über Umfang

### Dateigrößenverteilung
```
Dateien mit 0 Bytes:         12
Dateien mit ≤10 Bytes:       45
Dateien mit ≤20 Bytes:       23
```
→ Erkennung leerer oder sehr kleiner Dateien

### Top 20 größte Dateien
```
15.23 MB        ./videos/presentation.mp4
8.45 MB         ./images/photo.jpg
```
→ Identifikation der Speicherfresser

### Dateiendungen
```
txt                  456 Datei(en)
jpg                  234 Datei(en)
pdf                  123 Datei(en)
```
→ Übersicht der Dateitypen (sortiert nach Häufigkeit)

### Dateitypen
```
Text-Dateien:                567
Binär-Dateien:               654
Symbolische Links:           13
```
→ Klassifikation nach Inhalt

## Häufige Fragen

### ❓ Wie tief werden Archive entpackt?

**Standard:** 10 Ebenen

**Anpassen:** Bearbeiten Sie die Variable im Skript:
```bash
MAX_RECURSION_DEPTH=10  # Ändern Sie diesen Wert
```

### ❓ Werden die Original-Archive gelöscht?

**Nein!** Das Tool:
- Liest nur das Original-Archiv
- Erstellt ein neues Verzeichnis `<archivname>_analysis`
- Lässt das Original unverändert

### ❓ Was passiert mit verschachtelten Archiven?

Sie werden **automatisch erkannt und entpackt**:
```
archive.zip
  └─ inner.zip
      └─ deep.tar.gz
          └─ files...
```

Alle Ebenen werden analysiert!

### ❓ Welche Archivformate werden unterstützt?

- ✅ ZIP (`.zip`)
- ✅ TAR.GZ (`.tar.gz`, `.tgz`)
- ✅ TAR.BZ2 (`.tar.bz2`, `.tbz2`)
- ✅ TAR (`.tar`)

### ❓ Kann ich mehrere Archive gleichzeitig analysieren?

Ja, mit einer Schleife:
```bash
for archive in *.zip; do
    ./archive-analyzer.sh "$archive"
done
```

### ❓ Wo finde ich den Report?

Im Ausgabeverzeichnis:
```
<archivname>_analysis/analysis_report.txt
```

Beispiel:
```bash
./archive-analyzer.sh backup.zip
# Report: backup_analysis/analysis_report.txt
```

## Tipps & Tricks

### 💡 Report direkt anzeigen

```bash
./archive-analyzer.sh archiv.zip && cat archiv_analysis/analysis_report.txt
```

### 💡 Nur bestimmte Infos extrahieren

```bash
# Nur Dateiendungen
grep -A 20 "DATEIENDUNGEN" archiv_analysis/analysis_report.txt

# Nur Top 10 größte
grep -A 10 "TOP 20 GRÖSSTE" archiv_analysis/analysis_report.txt | head -11
```

### 💡 Mehrere Archive vergleichen

```bash
for archive in *.zip; do
    echo "=== $archive ==="
    ./archive-analyzer.sh "$archive" 2>/dev/null
    grep "Gesamtanzahl" "${archive%.*}_analysis/analysis_report.txt"
    echo ""
done
```

### 💡 In PATH installieren

```bash
# Für alle Benutzer verfügbar machen
sudo cp archive-analyzer.sh /usr/local/bin/archive-analyzer

# Dann von überall nutzbar:
archive-analyzer ~/Downloads/archiv.zip
```

## Fehlerbehebung

### Problem: "Command not found"

**Lösung:** Tool ausführbar machen
```bash
chmod +x archive-analyzer.sh
```

### Problem: "unzip: command not found"

**Lösung:** Abhängigkeiten installieren
```bash
# macOS
brew install unzip

# Linux
sudo apt-get install unzip
```

### Problem: "Permission denied"

**Lösung:** Schreibrechte prüfen
```bash
# Im aktuellen Verzeichnis
ls -la

# Oder in anderem Verzeichnis ausführen
cd ~/Documents
./pfad/zu/archive-analyzer.sh archiv.zip
```

## Nächste Schritte

📖 **Vollständige Dokumentation:** Siehe [`README.md`](README.md)

🧪 **Beispiele:** Siehe [`BEISPIEL_AUSGABE.md`](BEISPIEL_AUSGABE.md)

🐛 **Probleme melden:** Erstellen Sie ein Issue auf GitHub

---

**Viel Erfolg mit dem Archive Analyzer! 🎉**
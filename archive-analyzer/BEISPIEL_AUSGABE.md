# Beispiel-Ausgabe des Archive Analyzers

## Testlauf mit verschachteltem Archiv

### Kommando
```bash
./archive-analyzer.sh test-nested-level2.zip
```

### Konsolenausgabe
```
═══════════════════════════════════════════════════════════
  Archive Analyzer v1.0.0
═══════════════════════════════════════════════════════════

[SUCCESS] Archivtyp erkannt: zip
[SUCCESS] Ausgabeverzeichnis erstellt: test-nested-level2_analysis

[INFO] Starte Entpacken des Hauptarchivs...

[INFO] Suche nach verschachtelten Archiven...
[INFO] Entpacke (Tiefe 1): test-nested-level1.zip
[INFO] Entpacke (Tiefe 2): inner-archive.zip

[INFO] Starte Analyse der entpackten Dateien...
[INFO] Analysiere Verzeichnis: test-nested-level2_analysis

[INFO] Erstelle Report: test-nested-level2_analysis/analysis_report.txt
[SUCCESS] Report erstellt: test-nested-level2_analysis/analysis_report.txt

[SUCCESS] Analyse abgeschlossen!

Statistiken:
  - Dateien analysiert: 28
  - Gesamtgröße: 260.11 KB
  - Report: test-nested-level2_analysis/analysis_report.txt
```

### Generierter Report (analysis_report.txt)

```
═══════════════════════════════════════════════════════════════════
  ARCHIVE ANALYZER REPORT
  Version: 1.0.0
  Datum: 2026-03-10 11:08:15
═══════════════════════════════════════════════════════════════════

ZUSAMMENFASSUNG
───────────────────────────────────────────────────────────────────
Gesamtanzahl Dateien:        28
Gesamtgröße:                 260.11 KB (266359 Bytes)

DATEIGRÖSSENVERTEILUNG
───────────────────────────────────────────────────────────────────
Dateien mit 0 Bytes:         3
Dateien mit ≤10 Bytes:       7
Dateien mit ≤20 Bytes:       1

TOP 20 GRÖSSTE DATEIEN
───────────────────────────────────────────────────────────────────
100.00 KB       test-nested-level2_analysis/.../binary1.bin
55.04 KB        test-nested-level2_analysis/.../test-nested-level1.zip
54.24 KB        test-nested-level2_analysis/.../inner-archive.zip
50.00 KB        test-nested-level2_analysis/.../binary2.dat
121.00 B        test-nested-level2_analysis/.../data.xml
110.00 B        test-nested-level2_analysis/.../config.json
110.00 B        test-nested-level2_analysis/.../config.json
103.00 B        test-nested-level2_analysis/.../test.py
65.00 B         test-nested-level2_analysis/.../data.csv
55.00 B         test-nested-level2_analysis/.../readme.md
53.00 B         test-nested-level2_analysis/.../text2.txt
32.00 B         test-nested-level2_analysis/.../text1.txt
32.00 B         test-nested-level2_analysis/.../text1.txt
32.00 B         test-nested-level2_analysis/.../link-to-text.txt
31.00 B         test-nested-level2_analysis/.../script.sh
26.00 B         test-nested-level2_analysis/.../nested.txt
24.00 B         test-nested-level2_analysis/.../level2.txt
18.00 B         test-nested-level2_analysis/.../medium1.txt
6.00 B          test-nested-level2_analysis/.../small1.txt
5.00 B          test-nested-level2_analysis/.../video.mp4

DATEIENDUNGEN
───────────────────────────────────────────────────────────────────
txt                  10 Datei(en)
zip                  2 Datei(en)
json                 2 Datei(en)
dat                  2 Datei(en)
xml                  1 Datei(en)
sh                   1 Datei(en)
py                   1 Datei(en)
png                  1 Datei(en)
pdf                  1 Datei(en)
mp4                  1 Datei(en)
mp3                  1 Datei(en)
md                   1 Datei(en)
log                  1 Datei(en)
jpg                  1 Datei(en)
csv                  1 Datei(en)
bin                  1 Datei(en)

DATEITYPEN
───────────────────────────────────────────────────────────────────
Text-Dateien:                21
Binär-Dateien:               7
Symbolische Links:           0

═══════════════════════════════════════════════════════════════════
  Ende des Reports
═══════════════════════════════════════════════════════════════════
```

## Verzeichnisstruktur nach Analyse

```
test-nested-level2_analysis/
├── analysis_report.txt                    # Der generierte Report
├── nested-data-level2/
│   ├── level2.txt
│   ├── test-nested-level1.zip            # Original-Archiv (Level 1)
│   └── test-nested-level1_extracted/     # Entpackt aus Level 1
│       └── nested-data/
│           ├── config.json
│           ├── text1.txt
│           ├── inner-archive.zip         # Original-Archiv (Level 2)
│           └── inner-archive_extracted/  # Entpackt aus Level 2
│               ├── audio.mp3
│               ├── binary1.bin
│               ├── binary2.dat
│               ├── config.json
│               ├── data.csv
│               ├── data.xml
│               ├── document.pdf
│               ├── empty1.txt
│               ├── empty2.log
│               ├── image.jpg
│               ├── image.png
│               ├── link-to-text.txt
│               ├── medium1.txt
│               ├── readme.md
│               ├── script.sh
│               ├── small1.txt
│               ├── small2.dat
│               ├── subdir/
│               │   ├── empty-nested.txt
│               │   └── nested.txt
│               ├── test.py
│               ├── text1.txt
│               ├── text2.txt
│               └── video.mp4
```

## Wichtige Erkenntnisse aus dem Report

### ✅ Erfolgreich erkannt:
- **Rekursive Entpackung**: 2 Ebenen tief (test-nested-level1.zip → inner-archive.zip)
- **Dateitypen**: 15 verschiedene Dateiendungen identifiziert
- **Größenverteilung**: 3 leere Dateien, 7 sehr kleine (≤10 Bytes), 1 mittelgroße (≤20 Bytes)
- **Text vs. Binär**: 21 Text-Dateien, 7 Binär-Dateien korrekt klassifiziert
- **Top 20 größte**: Binärdateien (100 KB, 50 KB) und Archive selbst erkannt

### 📊 Statistiken:
- Insgesamt 28 Dateien analysiert
- Gesamtgröße: 260.11 KB
- Versionsnummer im Report: 1.0.0

### 🎯 Alle geforderten Features implementiert:
- ✅ Rekursives Entpacken
- ✅ Anzahl Dateien
- ✅ Gesamtgröße
- ✅ Dateien mit 0, ≤10, ≤20 Bytes
- ✅ Top 20 größte Dateien
- ✅ Übersicht Dateiendungen
- ✅ Text-Format Erkennung
- ✅ Binär-Dateien Erkennung
- ✅ Symbolische Links Erkennung
- ✅ Versionsnummer im Report
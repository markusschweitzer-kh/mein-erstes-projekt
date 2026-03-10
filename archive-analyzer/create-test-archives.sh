#!/bin/bash

#############################################################################
# Test Archive Creator
# Erstellt Testarchive für archive-analyzer.sh
#############################################################################

echo "Erstelle Testdaten und Archive..."

# Erstelle Test-Verzeichnis
TEST_DIR="test-data"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

# Erstelle verschiedene Testdateien
echo "1. Erstelle Testdateien..."

# Text-Dateien
echo "Dies ist eine normale Textdatei" > "$TEST_DIR/text1.txt"
echo "Noch eine Textdatei mit mehr Inhalt für die Analyse" > "$TEST_DIR/text2.txt"
cat > "$TEST_DIR/readme.md" << 'EOF'
# Test README
Dies ist eine Markdown-Datei für Tests.
EOF

# Leere Dateien (0 Bytes)
touch "$TEST_DIR/empty1.txt"
touch "$TEST_DIR/empty2.log"

# Kleine Dateien (≤10 Bytes)
echo "12345" > "$TEST_DIR/small1.txt"
echo "test" > "$TEST_DIR/small2.dat"

# Mittelgroße Dateien (≤20 Bytes)
echo "Dies ist 20 Bytes" > "$TEST_DIR/medium1.txt"

# Größere Dateien
dd if=/dev/zero of="$TEST_DIR/binary1.bin" bs=1024 count=100 2>/dev/null
dd if=/dev/urandom of="$TEST_DIR/binary2.dat" bs=1024 count=50 2>/dev/null

# JSON-Datei
cat > "$TEST_DIR/config.json" << 'EOF'
{
  "name": "test-config",
  "version": "1.0.0",
  "settings": {
    "enabled": true,
    "timeout": 30
  }
}
EOF

# XML-Datei
cat > "$TEST_DIR/data.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<root>
  <item id="1">Test Item</item>
  <item id="2">Another Item</item>
</root>
EOF

# CSV-Datei
cat > "$TEST_DIR/data.csv" << 'EOF'
Name,Age,City
Alice,30,Berlin
Bob,25,München
Charlie,35,Hamburg
EOF

# Shell-Skript
cat > "$TEST_DIR/script.sh" << 'EOF'
#!/bin/bash
echo "Test Script"
EOF
chmod +x "$TEST_DIR/script.sh"

# Python-Datei
cat > "$TEST_DIR/test.py" << 'EOF'
#!/usr/bin/env python3
def hello():
    print("Hello, World!")

if __name__ == "__main__":
    hello()
EOF

# Verschiedene Dateiendungen
echo "test" > "$TEST_DIR/document.pdf"
echo "test" > "$TEST_DIR/image.jpg"
echo "test" > "$TEST_DIR/image.png"
echo "test" > "$TEST_DIR/video.mp4"
echo "test" > "$TEST_DIR/audio.mp3"

# Erstelle Unterverzeichnis mit weiteren Dateien
mkdir -p "$TEST_DIR/subdir"
echo "Datei im Unterverzeichnis" > "$TEST_DIR/subdir/nested.txt"
touch "$TEST_DIR/subdir/empty-nested.txt"

# Erstelle symbolischen Link (wenn möglich)
if ln -s text1.txt "$TEST_DIR/link-to-text.txt" 2>/dev/null; then
    echo "  ✓ Symbolischer Link erstellt"
fi

echo "  ✓ Testdateien erstellt"

# Erstelle Archive
echo ""
echo "2. Erstelle Archive..."

# Einfaches ZIP-Archiv
cd "$TEST_DIR" || exit 1
zip -q -r ../test-simple.zip ./*
cd ..
echo "  ✓ test-simple.zip erstellt"

# TAR.GZ-Archiv
tar -czf test-simple.tar.gz -C "$TEST_DIR" .
echo "  ✓ test-simple.tar.gz erstellt"

# TAR.BZ2-Archiv (wenn bzip2 verfügbar)
if command -v bzip2 &> /dev/null; then
    tar -cjf test-simple.tar.bz2 -C "$TEST_DIR" .
    echo "  ✓ test-simple.tar.bz2 erstellt"
fi

# Erstelle verschachteltes Archiv (Level 1)
echo ""
echo "3. Erstelle verschachtelte Archive..."

NESTED_DIR="nested-data"
mkdir -p "$NESTED_DIR"

# Kopiere einige Dateien
cp "$TEST_DIR/text1.txt" "$NESTED_DIR/"
cp "$TEST_DIR/config.json" "$NESTED_DIR/"

# Füge ein Archiv hinzu (wird zu Level 2)
cp test-simple.zip "$NESTED_DIR/inner-archive.zip"

# Erstelle Level 1 Archiv
zip -q -r test-nested-level1.zip "$NESTED_DIR"
echo "  ✓ test-nested-level1.zip erstellt (enthält inner-archive.zip)"

# Erstelle noch tiefere Verschachtelung (Level 2)
NESTED2_DIR="nested-data-level2"
mkdir -p "$NESTED2_DIR"
cp test-nested-level1.zip "$NESTED2_DIR/"
echo "Extra Datei auf Level 2" > "$NESTED2_DIR/level2.txt"

zip -q -r test-nested-level2.zip "$NESTED2_DIR"
echo "  ✓ test-nested-level2.zip erstellt (2 Ebenen tief)"

# Erstelle gemischtes Archiv mit verschiedenen Formaten
MIXED_DIR="mixed-archives"
mkdir -p "$MIXED_DIR"
cp test-simple.zip "$MIXED_DIR/"
cp test-simple.tar.gz "$MIXED_DIR/"
echo "Datei im gemischten Archiv" > "$MIXED_DIR/mixed.txt"

tar -czf test-mixed-formats.tar.gz "$MIXED_DIR"
echo "  ✓ test-mixed-formats.tar.gz erstellt (enthält .zip und .tar.gz)"

# Cleanup temporäre Verzeichnisse
rm -rf "$TEST_DIR" "$NESTED_DIR" "$NESTED2_DIR" "$MIXED_DIR"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Testarchive erfolgreich erstellt!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Verfügbare Testarchive:"
echo "  1. test-simple.zip           - Einfaches ZIP mit verschiedenen Dateitypen"
echo "  2. test-simple.tar.gz        - Einfaches TAR.GZ"
echo "  3. test-simple.tar.bz2       - Einfaches TAR.BZ2 (falls bzip2 verfügbar)"
echo "  4. test-nested-level1.zip    - Verschachteltes Archiv (1 Ebene)"
echo "  5. test-nested-level2.zip    - Verschachteltes Archiv (2 Ebenen)"
echo "  6. test-mixed-formats.tar.gz - Gemischte Archivformate"
echo ""
echo "Testen Sie mit:"
echo "  ./archive-analyzer.sh test-simple.zip"
echo "  ./archive-analyzer.sh test-nested-level2.zip"
echo ""

# Made with Bob

#!/bin/bash

#==============================================================================
# CSV Bereinigungsscript
#==============================================================================
# Bereinigt die ip-change.csv Datei von häufigen Problemen:
# - Entfernt BOM
# - Konvertiert Windows-Zeilenenden zu Unix
# - Entfernt Leerzeichen in Hostnamen
# - Entfernt führende/nachfolgende Leerzeichen
#==============================================================================

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CSV_FILE="${1:-${SCRIPT_DIR}/ip-change.csv}"
readonly BACKUP_FILE="${CSV_FILE}.backup"

# Farben
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

echo -e "${BLUE}CSV Bereinigung${NC}"
echo "=================================="
echo ""

if [[ ! -f "${CSV_FILE}" ]]; then
    echo -e "${YELLOW}Fehler: CSV-Datei nicht gefunden: ${CSV_FILE}${NC}"
    exit 1
fi

echo "Datei: ${CSV_FILE}"
echo ""

# Backup erstellen
echo -e "${BLUE}Erstelle Backup...${NC}"
cp "${CSV_FILE}" "${BACKUP_FILE}"
echo -e "${GREEN}✓${NC} Backup erstellt: ${BACKUP_FILE}"
echo ""

# Bereinigung durchführen
echo -e "${BLUE}Bereinige CSV-Datei...${NC}"

# 1. Entferne BOM
# 2. Konvertiere Windows-Zeilenenden
# 3. Entferne Leerzeichen vor .com
# 4. Entferne führende/nachfolgende Leerzeichen in jedem Feld
sed -i.tmp \
    -e 's/^\xEF\xBB\xBF//' \
    -e 's/\r$//' \
    -e 's/ \.com/.com/g' \
    -e 's/; */;/g' \
    -e 's/ *;/;/g' \
    "${CSV_FILE}"

rm -f "${CSV_FILE}.tmp"

echo -e "${GREEN}✓${NC} BOM entfernt"
echo -e "${GREEN}✓${NC} Zeilenenden konvertiert"
echo -e "${GREEN}✓${NC} Leerzeichen in Hostnamen entfernt"
echo -e "${GREEN}✓${NC} Führende/nachfolgende Leerzeichen entfernt"
echo ""

echo -e "${GREEN}Bereinigung abgeschlossen!${NC}"
echo ""
echo "Original-Backup: ${BACKUP_FILE}"
echo "Bereinigte Datei: ${CSV_FILE}"
echo ""
echo "Führen Sie nun './validate-csv.sh' aus, um die Datei zu validieren."

# Made with Bob

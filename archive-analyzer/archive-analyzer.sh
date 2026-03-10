#!/bin/bash

#############################################################################
# Archive Analyzer - Rekursives Entpack- und Analyse-Tool
# Version: 1.0.0
# Plattform: Linux & macOS
# Beschreibung: Entpackt Archive rekursiv und erstellt detaillierte Reports
#############################################################################

VERSION="1.0.0"
MAX_RECURSION_DEPTH=10

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Globale Variablen für Statistiken
declare -A FILE_EXTENSIONS
declare -A SIZE_CATEGORIES
TOTAL_FILES=0
TOTAL_SIZE=0
TEXT_FILES=0
BINARY_FILES=0
SYMLINKS=0
ZERO_BYTE_FILES=0
TEN_BYTE_FILES=0
TWENTY_BYTE_FILES=0
TEMP_SIZE_FILE=""

#############################################################################
# Hilfsfunktionen
#############################################################################

print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Archive Analyzer v${VERSION}${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Prüft ob erforderliche Tools installiert sind
check_dependencies() {
    local missing_deps=()
    
    # Basis-Tools
    for cmd in unzip tar file stat; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    # bzip2 für .tar.bz2
    if ! command -v bzip2 &> /dev/null; then
        print_warning "bzip2 nicht gefunden - .tar.bz2 Archive können nicht entpackt werden"
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Fehlende Abhängigkeiten: ${missing_deps[*]}"
        echo "Bitte installieren Sie die fehlenden Tools:"
        echo "  macOS: brew install ${missing_deps[*]}"
        echo "  Linux: sudo apt-get install ${missing_deps[*]}"
        return 1
    fi
    
    return 0
}

# Erkennt den Archivtyp
detect_archive_type() {
    local file="$1"
    local mime_type
    
    # Verwende file command für MIME-Type Erkennung
    mime_type=$(file -b --mime-type "$file" 2>/dev/null)
    
    case "$mime_type" in
        application/zip|application/x-zip-compressed)
            echo "zip"
            ;;
        application/x-gzip|application/gzip)
            echo "tar.gz"
            ;;
        application/x-bzip2)
            echo "tar.bz2"
            ;;
        application/x-tar)
            echo "tar"
            ;;
        *)
            # Fallback auf Dateiendung
            case "${file,,}" in
                *.zip) echo "zip" ;;
                *.tar.gz|*.tgz) echo "tar.gz" ;;
                *.tar.bz2|*.tbz2) echo "tar.bz2" ;;
                *.tar) echo "tar" ;;
                *) echo "unknown" ;;
            esac
            ;;
    esac
}

# Entpackt ein Archiv
extract_archive() {
    local archive="$1"
    local target_dir="$2"
    local archive_type="$3"
    
    mkdir -p "$target_dir"
    
    case "$archive_type" in
        zip)
            if unzip -q -o "$archive" -d "$target_dir" 2>/dev/null; then
                return 0
            else
                print_error "Fehler beim Entpacken von $archive (ZIP)"
                return 1
            fi
            ;;
        tar.gz)
            if tar -xzf "$archive" -C "$target_dir" 2>/dev/null; then
                return 0
            else
                print_error "Fehler beim Entpacken von $archive (TAR.GZ)"
                return 1
            fi
            ;;
        tar.bz2)
            if tar -xjf "$archive" -C "$target_dir" 2>/dev/null; then
                return 0
            else
                print_error "Fehler beim Entpacken von $archive (TAR.BZ2)"
                return 1
            fi
            ;;
        tar)
            if tar -xf "$archive" -C "$target_dir" 2>/dev/null; then
                return 0
            else
                print_error "Fehler beim Entpacken von $archive (TAR)"
                return 1
            fi
            ;;
        *)
            print_warning "Unbekannter Archivtyp: $archive"
            return 1
            ;;
    esac
}

# Rekursives Entpacken
recursive_extract() {
    local dir="$1"
    local depth="$2"
    
    if [ "$depth" -gt "$MAX_RECURSION_DEPTH" ]; then
        print_warning "Maximale Rekursionstiefe ($MAX_RECURSION_DEPTH) erreicht in: $dir"
        return
    fi
    
    # Finde alle Archive im aktuellen Verzeichnis
    while IFS= read -r -d '' archive; do
        local archive_type
        archive_type=$(detect_archive_type "$archive")
        
        if [ "$archive_type" != "unknown" ]; then
            local archive_name
            archive_name=$(basename "$archive")
            local extract_dir="${archive%.*}_extracted"
            
            print_info "Entpacke (Tiefe $depth): $archive_name"
            
            if extract_archive "$archive" "$extract_dir" "$archive_type"; then
                # Rekursiv in das entpackte Verzeichnis gehen
                recursive_extract "$extract_dir" $((depth + 1))
            fi
        fi
    done < <(find "$dir" -maxdepth 1 -type f \( -iname "*.zip" -o -iname "*.tar.gz" -o -iname "*.tgz" -o -iname "*.tar.bz2" -o -iname "*.tbz2" -o -iname "*.tar" \) -print0 2>/dev/null)
}

# Analysiert eine einzelne Datei
analyze_file() {
    local file="$1"
    local size
    local extension
    local mime_type
    
    # Dateigröße ermitteln (plattformunabhängig)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        size=$(stat -f%z "$file" 2>/dev/null || echo 0)
    else
        size=$(stat -c%s "$file" 2>/dev/null || echo 0)
    fi
    
    TOTAL_FILES=$((TOTAL_FILES + 1))
    TOTAL_SIZE=$((TOTAL_SIZE + size))
    
    # Größenkategorien
    if [ "$size" -eq 0 ]; then
        ZERO_BYTE_FILES=$((ZERO_BYTE_FILES + 1))
    elif [ "$size" -le 10 ]; then
        TEN_BYTE_FILES=$((TEN_BYTE_FILES + 1))
    elif [ "$size" -le 20 ]; then
        TWENTY_BYTE_FILES=$((TWENTY_BYTE_FILES + 1))
    fi
    
    # Dateiendung
    extension="${file##*.}"
    if [ "$extension" = "$file" ]; then
        extension="(keine)"
    fi
    FILE_EXTENSIONS["$extension"]=$((${FILE_EXTENSIONS["$extension"]:-0} + 1))
    
    # Text vs. Binär
    mime_type=$(file -b --mime-type "$file" 2>/dev/null)
    if [[ "$mime_type" == text/* ]] || [[ "$mime_type" == application/json ]] || [[ "$mime_type" == application/xml ]]; then
        TEXT_FILES=$((TEXT_FILES + 1))
    else
        BINARY_FILES=$((BINARY_FILES + 1))
    fi
    
    # Für Top 20 größte Dateien
    echo "$size|$file" >> "$TEMP_SIZE_FILE"
}

# Analysiert Verzeichnis rekursiv
analyze_directory() {
    local dir="$1"
    
    print_info "Analysiere Verzeichnis: $dir"
    
    # Zähle Symlinks
    while IFS= read -r -d '' link; do
        SYMLINKS=$((SYMLINKS + 1))
    done < <(find "$dir" -type l -print0 2>/dev/null)
    
    # Analysiere alle regulären Dateien
    while IFS= read -r -d '' file; do
        analyze_file "$file"
    done < <(find "$dir" -type f -print0 2>/dev/null)
}

# Formatiert Bytes in lesbare Größe
format_size() {
    local size=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    local size_float=$size
    
    while (( $(echo "$size_float >= 1024" | bc -l) )) && [ $unit -lt 4 ]; do
        size_float=$(echo "scale=2; $size_float / 1024" | bc)
        unit=$((unit + 1))
    done
    
    printf "%.2f %s" "$size_float" "${units[$unit]}"
}

# Erstellt den Report
generate_report() {
    local output_dir="$1"
    local report_file="$output_dir/analysis_report.txt"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    print_info "Erstelle Report: $report_file"
    
    {
        echo "═══════════════════════════════════════════════════════════════════"
        echo "  ARCHIVE ANALYZER REPORT"
        echo "  Version: $VERSION"
        echo "  Datum: $timestamp"
        echo "═══════════════════════════════════════════════════════════════════"
        echo ""
        
        echo "ZUSAMMENFASSUNG"
        echo "───────────────────────────────────────────────────────────────────"
        echo "Gesamtanzahl Dateien:        $TOTAL_FILES"
        echo "Gesamtgröße:                 $(format_size $TOTAL_SIZE) ($TOTAL_SIZE Bytes)"
        echo ""
        
        echo "DATEIGRÖSSENVERTEILUNG"
        echo "───────────────────────────────────────────────────────────────────"
        echo "Dateien mit 0 Bytes:         $ZERO_BYTE_FILES"
        echo "Dateien mit ≤10 Bytes:       $TEN_BYTE_FILES"
        echo "Dateien mit ≤20 Bytes:       $TWENTY_BYTE_FILES"
        echo ""
        
        echo "TOP 20 GRÖSSTE DATEIEN"
        echo "───────────────────────────────────────────────────────────────────"
        if [ -f "$TEMP_SIZE_FILE" ]; then
            sort -t'|' -k1 -rn "$TEMP_SIZE_FILE" | head -20 | while IFS='|' read -r size file; do
                printf "%-15s %s\n" "$(format_size $size)" "$file"
            done
        else
            echo "Keine Daten verfügbar"
        fi
        echo ""
        
        echo "DATEIENDUNGEN"
        echo "───────────────────────────────────────────────────────────────────"
        for ext in "${!FILE_EXTENSIONS[@]}"; do
            printf "%-20s %d Datei(en)\n" "$ext" "${FILE_EXTENSIONS[$ext]}"
        done | sort -k2 -rn
        echo ""
        
        echo "DATEITYPEN"
        echo "───────────────────────────────────────────────────────────────────"
        echo "Text-Dateien:                $TEXT_FILES"
        echo "Binär-Dateien:               $BINARY_FILES"
        echo "Symbolische Links:           $SYMLINKS"
        echo ""
        
        echo "═══════════════════════════════════════════════════════════════════"
        echo "  Ende des Reports"
        echo "═══════════════════════════════════════════════════════════════════"
    } > "$report_file"
    
    print_success "Report erstellt: $report_file"
}

# Cleanup-Funktion
cleanup() {
    if [ -n "$TEMP_SIZE_FILE" ] && [ -f "$TEMP_SIZE_FILE" ]; then
        rm -f "$TEMP_SIZE_FILE"
    fi
}

# Zeigt Hilfe an
show_usage() {
    cat << EOF
Verwendung: $0 <archive-datei>

Archive Analyzer v${VERSION}
Entpackt Archive rekursiv und erstellt detaillierte Analyseberichte.

Argumente:
  <archive-datei>    Pfad zur zu analysierenden Archiv-Datei

Unterstützte Formate:
  - ZIP (.zip)
  - TAR.GZ (.tar.gz, .tgz)
  - TAR.BZ2 (.tar.bz2, .tbz2)
  - TAR (.tar)

Optionen:
  -h, --help         Zeigt diese Hilfe an
  -v, --version      Zeigt die Version an

Beispiele:
  $0 mein-archiv.zip
  $0 /pfad/zu/archiv.tar.gz

Der Report wird im Ausgabeverzeichnis als 'analysis_report.txt' erstellt.
EOF
}

#############################################################################
# Hauptprogramm
#############################################################################

main() {
    # Argument-Parsing
    if [ $# -eq 0 ]; then
        print_error "Keine Archiv-Datei angegeben"
        echo ""
        show_usage
        exit 1
    fi
    
    case "$1" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--version)
            echo "Archive Analyzer v${VERSION}"
            exit 0
            ;;
    esac
    
    local archive_file="$1"
    
    # Header anzeigen
    print_header
    echo ""
    
    # Prüfe Abhängigkeiten
    if ! check_dependencies; then
        exit 1
    fi
    
    # Prüfe ob Datei existiert
    if [ ! -f "$archive_file" ]; then
        print_error "Datei nicht gefunden: $archive_file"
        exit 1
    fi
    
    # Erkenne Archivtyp
    local archive_type
    archive_type=$(detect_archive_type "$archive_file")
    
    if [ "$archive_type" = "unknown" ]; then
        print_error "Unbekanntes oder nicht unterstütztes Archivformat"
        exit 1
    fi
    
    print_success "Archivtyp erkannt: $archive_type"
    
    # Erstelle Ausgabeverzeichnis
    local archive_basename
    archive_basename=$(basename "$archive_file")
    local output_dir="${archive_basename%.*}_analysis"
    
    if [ -d "$output_dir" ]; then
        print_warning "Ausgabeverzeichnis existiert bereits: $output_dir"
        read -p "Möchten Sie fortfahren und das Verzeichnis überschreiben? (j/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[JjYy]$ ]]; then
            print_info "Abgebrochen"
            exit 0
        fi
        rm -rf "$output_dir"
    fi
    
    mkdir -p "$output_dir"
    print_success "Ausgabeverzeichnis erstellt: $output_dir"
    echo ""
    
    # Temporäre Datei für Größensortierung
    TEMP_SIZE_FILE=$(mktemp)
    trap cleanup EXIT
    
    # Entpacke Hauptarchiv
    print_info "Starte Entpacken des Hauptarchivs..."
    if ! extract_archive "$archive_file" "$output_dir" "$archive_type"; then
        print_error "Fehler beim Entpacken des Hauptarchivs"
        exit 1
    fi
    echo ""
    
    # Rekursives Entpacken
    print_info "Suche nach verschachtelten Archiven..."
    recursive_extract "$output_dir" 1
    echo ""
    
    # Analysiere Inhalte
    print_info "Starte Analyse der entpackten Dateien..."
    analyze_directory "$output_dir"
    echo ""
    
    # Erstelle Report
    generate_report "$output_dir"
    echo ""
    
    # Zusammenfassung
    print_success "Analyse abgeschlossen!"
    echo ""
    echo "Statistiken:"
    echo "  - Dateien analysiert: $TOTAL_FILES"
    echo "  - Gesamtgröße: $(format_size $TOTAL_SIZE)"
    echo "  - Report: $output_dir/analysis_report.txt"
    echo ""
}

# Starte Hauptprogramm
main "$@"

# Made with Bob

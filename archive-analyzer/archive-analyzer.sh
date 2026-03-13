#!/bin/bash

#############################################################################
# Archive Analyzer - Rekursives Entpack- und Analyse-Tool
# Version: 2.0.1
# Plattform: Linux & macOS
# Beschreibung: Entpackt Archive rekursiv und erstellt detaillierte Reports
#
# Changelog v2.0.1:
# - FIX: Pfadlängen-Problem bei TAR-Archiven behoben (cd ins Zielverzeichnis)
# - FIX: Maximale Rekursionstiefe von 10 auf 50 erhöht
# - FIX: Bessere Fehlerausgaben für Debugging
# - Perfekte Rekursion: Archive werden nach Entpacken gelöscht
# - Array-basierte Verarbeitung für sichere Iteration
# - Binärdateien mit Größe und Pfad aufgelistet
# - Spezielle Unix-Dateien werden erkannt
# - Zentrale Reports-Sammlung
# - Verbesserte Report-Struktur
#############################################################################

VERSION="2.0.1"
MAX_RECURSION_DEPTH=50

# Globale Variable für übersprungene Dateien
SKIPPED_FILES_LOG=""
TOTAL_SKIPPED_FILES=0

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Globale Variablen für Statistiken
TOTAL_FILES=0
TOTAL_SIZE=0
TEXT_FILES=0
BINARY_FILES=0
BINARY_SIZE=0
SYMLINKS=0
HARDLINKS=0
PIPES=0
SOCKETS=0
BLOCK_DEVICES=0
CHAR_DEVICES=0
ZERO_BYTE_FILES=0
TEN_BYTE_FILES=0
TWENTY_BYTE_FILES=0
TEMP_SIZE_FILE=""
TEMP_EXT_FILE=""
TEMP_BINARY_FILE=""
TEMP_SYMLINK_FILE=""
TEMP_HARDLINK_FILE=""
TEMP_SPECIAL_FILE=""

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
        application/x-compress)
            echo "compress"
            ;;
        *)
            # Fallback auf Dateiendung (bash 3.x kompatibel)
            local file_lower
            file_lower=$(echo "$file" | tr '[:upper:]' '[:lower:]')
            case "$file_lower" in
                *.zip) echo "zip" ;;
                *.tar.gz|*.tgz) echo "tar.gz" ;;
                *.tar.bz2|*.tbz2) echo "tar.bz2" ;;
                *.tar) echo "tar" ;;
                *.z) echo "compress" ;;
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
            # FIX: Extrahiere in temporäres Verzeichnis mit kurzem Namen
            # um Pfadlängen-Probleme zu vermeiden
            local temp_extract_dir="/tmp/arc_$$_$RANDOM"
            mkdir -p "$temp_extract_dir"
            
            local abs_archive
            abs_archive="$(cd "$(dirname "$archive")" && pwd)/$(basename "$archive")"
            
            # Temporäre Datei für TAR-Fehlerausgabe
            local tar_errors=$(mktemp)
            
            # Versuche mit tar -xzf und erfasse Fehler
            if (cd "$temp_extract_dir" && tar -xzf "$abs_archive" 2>"$tar_errors"); then
                rm -f "$tar_errors"
                # Verschiebe Inhalt ins Zielverzeichnis
                mv "$temp_extract_dir"/* "$target_dir/" 2>/dev/null
                mv "$temp_extract_dir"/.[!.]* "$target_dir/" 2>/dev/null
                rmdir "$temp_extract_dir"
                return 0
            else
                local tar_exit=$?
                # Wenn tar teilweise erfolgreich war (Exit Code 1 = Warnungen), akzeptiere es
                if [ $tar_exit -eq 1 ]; then
                    # Parse Fehlerausgabe und zähle übersprungene Dateien
                    local skipped_count=$(grep -c "Can't create" "$tar_errors" 2>/dev/null || echo 0)
                    TOTAL_SKIPPED_FILES=$((TOTAL_SKIPPED_FILES + skipped_count))
                    
                    print_warning "Archiv teilweise entpackt: $(basename "$archive")"
                    print_info "$skipped_count Datei(en) wegen zu langer Pfade übersprungen"
                    
                    # Speichere Details der übersprungenen Dateien
                    if [ -n "$SKIPPED_FILES_LOG" ]; then
                        echo "" >> "$SKIPPED_FILES_LOG"
                        echo "=== Archiv: $(basename "$archive") ===" >> "$SKIPPED_FILES_LOG"
                        grep "Can't create" "$tar_errors" | sed "s/.*Can't create '//" | sed "s/': No such.*//" >> "$SKIPPED_FILES_LOG" 2>/dev/null
                    fi
                    
                    rm -f "$tar_errors"
                    mv "$temp_extract_dir"/* "$target_dir/" 2>/dev/null
                    mv "$temp_extract_dir"/.[!.]* "$target_dir/" 2>/dev/null
                    rmdir "$temp_extract_dir"
                    return 0
                fi
                
                # Fallback: Versuche gunzip + tar
                print_warning "Erster Versuch fehlgeschlagen, versuche gunzip + tar für $archive"
                if (cd "$temp_extract_dir" && gunzip -c "$abs_archive" 2>/dev/null | tar -xf - 2>"$tar_errors"); then
                    rm -f "$tar_errors"
                    mv "$temp_extract_dir"/* "$target_dir/" 2>/dev/null
                    mv "$temp_extract_dir"/.[!.]* "$target_dir/" 2>/dev/null
                    rmdir "$temp_extract_dir"
                    return 0
                else
                    tar_exit=$?
                    if [ $tar_exit -eq 1 ]; then
                        # Parse Fehlerausgabe
                        local skipped_count=$(grep -c "Can't create" "$tar_errors" 2>/dev/null || echo 0)
                        TOTAL_SKIPPED_FILES=$((TOTAL_SKIPPED_FILES + skipped_count))
                        
                        print_warning "Archiv teilweise entpackt (Fallback): $(basename "$archive")"
                        print_info "$skipped_count Datei(en) übersprungen"
                        
                        # Speichere Details
                        if [ -n "$SKIPPED_FILES_LOG" ]; then
                            echo "" >> "$SKIPPED_FILES_LOG"
                            echo "=== Archiv: $(basename "$archive") (Fallback) ===" >> "$SKIPPED_FILES_LOG"
                            grep "Can't create" "$tar_errors" | sed "s/.*Can't create '//" | sed "s/': No such.*//" >> "$SKIPPED_FILES_LOG" 2>/dev/null
                        fi
                        
                        rm -f "$tar_errors"
                        mv "$temp_extract_dir"/* "$target_dir/" 2>/dev/null
                        mv "$temp_extract_dir"/.[!.]* "$target_dir/" 2>/dev/null
                        rmdir "$temp_extract_dir"
                        return 0
                    fi
                    rm -rf "$temp_extract_dir"
                    rm -f "$tar_errors"
                    print_error "Fehler beim Entpacken von $archive (TAR.GZ) - Exit Code: $tar_exit"
                    return 1
                fi
            fi
            ;;
        tar.bz2)
            # FIX: Extrahiere in temporäres Verzeichnis mit kurzem Namen
            local temp_extract_dir="/tmp/arc_$$_$RANDOM"
            mkdir -p "$temp_extract_dir"
            
            local abs_archive
            abs_archive="$(cd "$(dirname "$archive")" && pwd)/$(basename "$archive")"
            
            if (cd "$temp_extract_dir" && tar -xjf "$abs_archive" 2>&1); then
                mv "$temp_extract_dir"/* "$target_dir/" 2>/dev/null
                mv "$temp_extract_dir"/.[!.]* "$target_dir/" 2>/dev/null
                rmdir "$temp_extract_dir"
                return 0
            else
                rm -rf "$temp_extract_dir"
                print_error "Fehler beim Entpacken von $archive (TAR.BZ2)"
                return 1
            fi
            ;;
        tar)
            # FIX: Extrahiere in temporäres Verzeichnis mit kurzem Namen
            local temp_extract_dir="/tmp/arc_$$_$RANDOM"
            mkdir -p "$temp_extract_dir"
            
            local abs_archive
            abs_archive="$(cd "$(dirname "$archive")" && pwd)/$(basename "$archive")"
            
            if (cd "$temp_extract_dir" && tar -xf "$abs_archive" 2>&1); then
                mv "$temp_extract_dir"/* "$target_dir/" 2>/dev/null
                mv "$temp_extract_dir"/.[!.]* "$target_dir/" 2>/dev/null
                rmdir "$temp_extract_dir"
                return 0
            else
                rm -rf "$temp_extract_dir"
                print_error "Fehler beim Entpacken von $archive (TAR)"
                return 1
            fi
            ;;
        compress)
            # Entpacke .Z Datei mit uncompress oder gunzip
            local basename_file
            basename_file=$(basename "$archive")
            if command -v uncompress &> /dev/null; then
                if uncompress -c "$archive" > "$target_dir/${basename_file%.Z}" 2>/dev/null; then
                    return 0
                fi
            elif command -v gunzip &> /dev/null; then
                if gunzip -c "$archive" > "$target_dir/${basename_file%.Z}" 2>/dev/null; then
                    return 0
                fi
            fi
            print_error "Fehler beim Entpacken von $archive (COMPRESS) - uncompress oder gunzip nicht gefunden"
            return 1
            ;;
        *)
            print_warning "Unbekannter Archivtyp: $archive"
            return 1
            ;;
    esac
}

# Rekursives Entpacken - PERFEKTE VERSION mit vollständiger Rekursion
recursive_extract() {
    local dir="$1"
    local depth="$2"
    
    if [ "$depth" -gt "$MAX_RECURSION_DEPTH" ]; then
        print_warning "Maximale Rekursionstiefe ($MAX_RECURSION_DEPTH) erreicht in: $dir"
        return
    fi
    
    # Wiederhole solange Archive gefunden werden
    local found_archives=1
    while [ $found_archives -eq 1 ]; do
        found_archives=0
        
        # Sammle ALLE Archive rekursiv im gesamten Verzeichnisbaum
        local archives=()
        while IFS= read -r -d '' archive; do
            archives+=("$archive")
            found_archives=1
        done < <(find "$dir" -type f \( -iname "*.zip" -o -iname "*.tar.gz" -o -iname "*.tgz" -o -iname "*.tar.bz2" -o -iname "*.tbz2" -o -iname "*.tar" -o -iname "*.z" \) -print0 2>/dev/null)
        
        # Wenn keine Archive gefunden wurden, sind wir fertig
        if [ $found_archives -eq 0 ]; then
            break
        fi
        
        # Verarbeite jedes gefundene Archiv
        for archive in "${archives[@]}"; do
            # Prüfe ob Datei noch existiert
            if [ ! -f "$archive" ]; then
                continue
            fi
            
            local archive_type
            archive_type=$(detect_archive_type "$archive")
            
            if [ "$archive_type" != "unknown" ]; then
                local archive_name
                archive_name=$(basename "$archive")
                local extract_dir="${archive%.*}_extracted"
                
                print_info "Entpacke (Tiefe $depth): $archive_name"
                
                if extract_archive "$archive" "$extract_dir" "$archive_type"; then
                    # WICHTIG: Lösche das Archiv nach erfolgreichem Entpacken
                    rm -f "$archive"
                    print_info "Archiv entfernt: $archive_name"
                fi
            fi
        done
        
        # Erhöhe Tiefe für nächste Iteration
        depth=$((depth + 1))
        if [ "$depth" -gt "$MAX_RECURSION_DEPTH" ]; then
            print_warning "Maximale Rekursionstiefe ($MAX_RECURSION_DEPTH) erreicht"
            break
        fi
    done
}

# Analysiert eine einzelne Datei
analyze_file() {
    local file="$1"
    local size
    local extension
    local mime_type
    
    # Überspringe Archive (werden separat entpackt)
    local file_lower
    file_lower=$(echo "$file" | tr '[:upper:]' '[:lower:]')
    if [[ "$file_lower" == *.zip ]] || [[ "$file_lower" == *.tar.gz ]] || [[ "$file_lower" == *.tgz ]] || [[ "$file_lower" == *.tar.bz2 ]] || [[ "$file_lower" == *.tbz2 ]] || [[ "$file_lower" == *.tar ]] || [[ "$file_lower" == *.z ]]; then
        return 0
    fi
    
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
    
    # Dateiendung extrahieren
    local basename_file
    basename_file=$(basename "$file")
    if [[ "$basename_file" == *.* ]]; then
        extension="${basename_file##*.}"
    else
        extension="(keine)"
    fi
    
    # Speichere Endung in temporärer Datei
    echo "$extension" >> "$TEMP_EXT_FILE"
    
    # Text vs. Binär (leere Dateien werden als Text behandelt)
    mime_type=$(file -b --mime-type "$file" 2>/dev/null)
    if [[ "$mime_type" == text/* ]] || [[ "$mime_type" == application/json ]] || [[ "$mime_type" == application/xml ]] || [[ "$mime_type" == "inode/x-empty" ]] || [ "$size" -eq 0 ]; then
        TEXT_FILES=$((TEXT_FILES + 1))
    else
        BINARY_FILES=$((BINARY_FILES + 1))
        BINARY_SIZE=$((BINARY_SIZE + size))
        # Speichere Binärdatei mit Größe und Pfad (nur wenn > 0 Bytes)
        if [ "$size" -gt 0 ]; then
            echo "$size|$file" >> "$TEMP_BINARY_FILE"
        fi
    fi
    
    # Prüfe auf Hardlinks (mehr als 1 Link)
    if [ -f "$file" ]; then
        local link_count
        link_count=$(stat -f "%l" "$file" 2>/dev/null || stat -c "%h" "$file" 2>/dev/null)
        if [ "$link_count" -gt 1 ]; then
            HARDLINKS=$((HARDLINKS + 1))
            echo "$file|Links: $link_count" >> "$TEMP_HARDLINK_FILE"
        fi
    fi
    
    # Für Top 20 größte Dateien
    echo "$size|$file" >> "$TEMP_SIZE_FILE"
}

# Analysiert Verzeichnis rekursiv
analyze_directory() {
    local dir="$1"
    
    print_info "Analysiere Verzeichnis: $dir"
    
    # Zähle und liste Symlinks
    while IFS= read -r -d '' link; do
        SYMLINKS=$((SYMLINKS + 1))
        local target
        target=$(readlink "$link" 2>/dev/null || echo "(unbekannt)")
        echo "$link -> $target" >> "$TEMP_SYMLINK_FILE"
    done < <(find "$dir" -type l -print0 2>/dev/null)
    
    # Suche nach Named Pipes (FIFOs)
    while IFS= read -r -d '' pipe; do
        PIPES=$((PIPES + 1))
        echo "$pipe" >> "$TEMP_SPECIAL_FILE"
    done < <(find "$dir" -type p -print0 2>/dev/null)
    
    # Suche nach Sockets
    while IFS= read -r -d '' socket; do
        SOCKETS=$((SOCKETS + 1))
        echo "$socket" >> "$TEMP_SPECIAL_FILE"
    done < <(find "$dir" -type s -print0 2>/dev/null)
    
    # Suche nach Block Devices
    while IFS= read -r -d '' bdev; do
        BLOCK_DEVICES=$((BLOCK_DEVICES + 1))
        echo "$bdev" >> "$TEMP_SPECIAL_FILE"
    done < <(find "$dir" -type b -print0 2>/dev/null)
    
    # Suche nach Character Devices
    while IFS= read -r -d '' cdev; do
        CHAR_DEVICES=$((CHAR_DEVICES + 1))
        echo "$cdev" >> "$TEMP_SPECIAL_FILE"
    done < <(find "$dir" -type c -print0 2>/dev/null)
    
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
    
    # Setze LC_NUMERIC=C für alle Berechnungen
    export LC_NUMERIC=C
    
    while (( $(echo "$size_float >= 1024" | bc -l) )) && [ $unit -lt 4 ]; do
        size_float=$(echo "scale=2; $size_float / 1024" | bc -l)
        unit=$((unit + 1))
    done
    
    # Ausgabe mit printf
    printf "%.2f %s" "$size_float" "${units[$unit]}"
}

# Erstellt den Report
generate_report() {
    local output_dir="$1"
    local source_archive="$2"
    local reports_dir="$3"
    local archive_counter="$4"
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
        
        # ===== ALLGEMEINE INFORMATIONEN =====
        
        echo "QUELLE UND ZIEL"
        echo "───────────────────────────────────────────────────────────────────"
        echo "Quell-Archiv:                $source_archive"
        echo "Ausgabeverzeichnis:          $output_dir"
        echo ""
        
        echo "ZUSAMMENFASSUNG"
        echo "───────────────────────────────────────────────────────────────────"
        echo "Gesamtanzahl Dateien:        $TOTAL_FILES"
        echo "Gesamtgröße:                 $(format_size $TOTAL_SIZE) ($TOTAL_SIZE Bytes)"
        echo ""
        
        echo "DATEITYPEN ÜBERSICHT"
        echo "───────────────────────────────────────────────────────────────────"
        echo "Text-Dateien:                $TEXT_FILES"
        echo "Binär-Dateien:               $BINARY_FILES"
        echo "Binär-Dateien Gesamtgröße:   $(format_size $BINARY_SIZE) ($BINARY_SIZE Bytes)"
        echo ""
        
        echo "DATEIGRÖSSENVERTEILUNG"
        echo "───────────────────────────────────────────────────────────────────"
        echo "Dateien mit 0 Bytes:         $ZERO_BYTE_FILES"
        echo "Dateien mit ≤10 Bytes:       $TEN_BYTE_FILES"
        echo "Dateien mit ≤20 Bytes:       $TWENTY_BYTE_FILES"
        echo ""
        
        echo "SPEZIELLE UNIX-DATEIEN ÜBERSICHT"
        echo "───────────────────────────────────────────────────────────────────"
        echo "Symbolische Links:           $SYMLINKS"
        echo "Hard Links:                  $HARDLINKS"
        echo "Named Pipes (FIFOs):         $PIPES"
        echo "Sockets:                     $SOCKETS"
        echo "Block Devices:               $BLOCK_DEVICES"
        echo "Character Devices:           $CHAR_DEVICES"
        echo ""
        
        echo "DATEIENDUNGEN ÜBERSICHT"
        echo "───────────────────────────────────────────────────────────────────"
        if [ -f "$TEMP_EXT_FILE" ]; then
            sort "$TEMP_EXT_FILE" | uniq -c | sort -rn | head -20 | while read -r count ext; do
                printf "%-20s %d Datei(en)\n" "$ext" "$count"
            done
        else
            echo "Keine Daten verfügbar"
        fi
        echo ""
        
        # ===== DETAILLIERTE INFORMATIONEN =====
        
        echo "═══════════════════════════════════════════════════════════════════"
        echo "  DETAILLIERTE INFORMATIONEN"
        echo "═══════════════════════════════════════════════════════════════════"
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
        
        echo "BINÄRDATEIEN DETAILS"
        echo "───────────────────────────────────────────────────────────────────"
        if [ -f "$TEMP_BINARY_FILE" ] && [ -s "$TEMP_BINARY_FILE" ]; then
            sort -t'|' -k1 -rn "$TEMP_BINARY_FILE" | while IFS='|' read -r size file; do
                printf "%-15s %s\n" "$(format_size $size)" "$file"
            done
        else
            echo "Keine Binärdateien gefunden"
        fi
        echo ""
        
        if [ "$SYMLINKS" -gt 0 ] && [ -f "$TEMP_SYMLINK_FILE" ]; then
            echo "SYMBOLISCHE LINKS DETAILS"
            echo "───────────────────────────────────────────────────────────────────"
            cat "$TEMP_SYMLINK_FILE"
            echo ""
        fi
        
        if [ "$HARDLINKS" -gt 0 ] && [ -f "$TEMP_HARDLINK_FILE" ]; then
            echo "HARD LINKS DETAILS"
            echo "───────────────────────────────────────────────────────────────────"
            while IFS='|' read -r file info; do
                echo "$file ($info)"
            done < "$TEMP_HARDLINK_FILE"
            echo ""
        fi
        
        if [ -f "$TEMP_SPECIAL_FILE" ] && [ -s "$TEMP_SPECIAL_FILE" ]; then
            echo "SPEZIELLE DATEIEN DETAILS"
            echo "───────────────────────────────────────────────────────────────────"
            cat "$TEMP_SPECIAL_FILE"
            echo ""
        fi
        
        echo "═══════════════════════════════════════════════════════════════════"
        echo "  Ende des Reports"
        echo "═══════════════════════════════════════════════════════════════════"
    } > "$report_file"
    
    print_success "Report erstellt: $report_file"
    
    # Kopiere Report auch ins zentrale Reports-Verzeichnis (falls angegeben)
    if [ -n "$reports_dir" ] && [ -n "$archive_counter" ]; then
        local archive_basename
        archive_basename=$(basename "$source_archive")
        local central_report_file="$reports_dir/report_$(printf "%03d" $archive_counter)_${archive_basename%.*}.txt"
        cp "$report_file" "$central_report_file"
        print_success "Report kopiert nach: $central_report_file"
    fi
}

# Cleanup-Funktion
cleanup() {
    if [ -n "$TEMP_SIZE_FILE" ] && [ -f "$TEMP_SIZE_FILE" ]; then
        rm -f "$TEMP_SIZE_FILE"
    fi
    if [ -n "$TEMP_EXT_FILE" ] && [ -f "$TEMP_EXT_FILE" ]; then
        rm -f "$TEMP_EXT_FILE"
    fi
    if [ -n "$TEMP_BINARY_FILE" ] && [ -f "$TEMP_BINARY_FILE" ]; then
        rm -f "$TEMP_BINARY_FILE"
    fi
    if [ -n "$TEMP_SYMLINK_FILE" ] && [ -f "$TEMP_SYMLINK_FILE" ]; then
        rm -f "$TEMP_SYMLINK_FILE"
    fi
    if [ -n "$TEMP_HARDLINK_FILE" ] && [ -f "$TEMP_HARDLINK_FILE" ]; then
        rm -f "$TEMP_HARDLINK_FILE"
    fi
    if [ -n "$TEMP_SPECIAL_FILE" ] && [ -f "$TEMP_SPECIAL_FILE" ]; then
        rm -f "$TEMP_SPECIAL_FILE"
    fi
}

# Zeigt Hilfe an
show_usage() {
    cat << EOF
Verwendung: $0 <archive-datei|verzeichnis>

Archive Analyzer v${VERSION}
Entpackt Archive rekursiv und erstellt detaillierte Analyseberichte.

Argumente:
  <archive-datei>    Pfad zur zu analysierenden Archiv-Datei
  <verzeichnis>      Pfad zum Verzeichnis (analysiert alle Archive rekursiv)

Unterstützte Formate:
  - ZIP (.zip)
  - TAR.GZ (.tar.gz, .tgz)
  - TAR.BZ2 (.tar.bz2, .tbz2)
  - TAR (.tar)
  - COMPRESS (.Z)

Optionen:
  -h, --help         Zeigt diese Hilfe an
  -v, --version      Zeigt die Version an

Beispiele:
  $0 mein-archiv.zip
  $0 /pfad/zu/archiv.tar.gz
  $0 /pfad/zum/verzeichnis

Bei Verzeichnissen werden alle Archive rekursiv gefunden und analysiert.
Der Report wird im Ausgabeverzeichnis als 'analysis_report.txt' erstellt.
EOF
}

# Findet alle Archive in einem Verzeichnis rekursiv
find_archives() {
    local search_dir="$1"
    
    print_info "Durchsuche Verzeichnis: $search_dir"
    
    # Suche nach allen unterstützten Archivformaten und gebe sie direkt aus
    find "$search_dir" -type f \( -name "*.zip" -o -name "*.tar.gz" -o -name "*.tgz" -o -name "*.tar.bz2" -o -name "*.tbz2" -o -name "*.tar" -o -name "*.z" \) 2>/dev/null | while IFS= read -r file; do
        local archive_type
        archive_type=$(detect_archive_type "$file")
        
        if [ "$archive_type" != "unknown" ]; then
            echo "$file"
        fi
    done
}

# Verarbeitet ein einzelnes Archiv
process_single_archive() {
    local archive_file="$1"
    local base_output_dir="$2"
    local archive_counter="$3"
    
    print_info "═══════════════════════════════════════════════════════════"
    print_info "Verarbeite Archiv #$archive_counter: $archive_file"
    print_info "═══════════════════════════════════════════════════════════"
    
    # Erkenne Archivtyp
    local archive_type
    archive_type=$(detect_archive_type "$archive_file")
    
    if [ "$archive_type" = "unknown" ]; then
        print_warning "Überspringe unbekanntes Format: $archive_file"
        return 1
    fi
    
    print_success "Archivtyp erkannt: $archive_type"
    
    # Erstelle Ausgabeverzeichnis mit Zähler für eindeutige Namen
    local archive_basename
    archive_basename=$(basename "$archive_file")
    local output_dir
    
    if [ -n "$base_output_dir" ]; then
        # Verwende Zähler im Namen für eindeutige Verzeichnisse
        output_dir="$base_output_dir/archive_$(printf "%03d" $archive_counter)_${archive_basename%.*}"
    else
        output_dir="${archive_basename%.*}_analysis"
    fi
    
    if [ -d "$output_dir" ]; then
        print_warning "Ausgabeverzeichnis existiert bereits: $output_dir"
        rm -rf "$output_dir"
    fi
    
    mkdir -p "$output_dir"
    print_success "Ausgabeverzeichnis erstellt: $output_dir"
    
    # Temporäre Dateien für dieses Archiv
    local temp_size_file=$(mktemp)
    local temp_ext_file=$(mktemp)
    local temp_binary_file=$(mktemp)
    local temp_symlink_file=$(mktemp)
    local temp_hardlink_file=$(mktemp)
    local temp_special_file=$(mktemp)
    
    TEMP_SIZE_FILE="$temp_size_file"
    TEMP_EXT_FILE="$temp_ext_file"
    TEMP_BINARY_FILE="$temp_binary_file"
    TEMP_SYMLINK_FILE="$temp_symlink_file"
    TEMP_HARDLINK_FILE="$temp_hardlink_file"
    TEMP_SPECIAL_FILE="$temp_special_file"
    
    # Erstelle Log-Datei für übersprungene Dateien
    SKIPPED_FILES_LOG="$output_dir/.skipped_files.log"
    TOTAL_SKIPPED_FILES=0
    touch "$SKIPPED_FILES_LOG"
    
    # Entpacke Hauptarchiv
    print_info "Starte Entpacken des Hauptarchivs..."
    if ! extract_archive "$archive_file" "$output_dir" "$archive_type"; then
        print_error "Fehler beim Entpacken: $archive_file"
        rm -f "$temp_size_file" "$temp_ext_file" "$temp_binary_file" "$temp_symlink_file" "$temp_hardlink_file" "$temp_special_file"
        return 1
    fi
    
    # Rekursives Entpacken
    print_info "Suche nach verschachtelten Archiven..."
    recursive_extract "$output_dir" 1
    
    # Analysiere Inhalte
    print_info "Starte Analyse der entpackten Dateien..."
    analyze_directory "$output_dir"
    
    # Erstelle Report mit Quelle und Ziel
    local absolute_archive_path
    absolute_archive_path=$(cd "$(dirname "$archive_file")" && pwd)/$(basename "$archive_file")
    generate_report "$output_dir" "$absolute_archive_path" "$base_output_dir/reports" "$archive_counter"
    
    # Cleanup temporäre Dateien
    rm -f "$temp_size_file" "$temp_ext_file" "$temp_binary_file" "$temp_symlink_file" "$temp_hardlink_file" "$temp_special_file"
    
    # Zeige Zusammenfassung übersprungener Dateien
    if [ $TOTAL_SKIPPED_FILES -gt 0 ]; then
        echo ""
        print_warning "Insgesamt $TOTAL_SKIPPED_FILES Datei(en) wegen zu langer Pfade übersprungen"
        print_info "Details siehe: $output_dir/.skipped_files.log"
    fi
    
    print_success "Archiv analysiert: $archive_file"
    print_success "Report: $output_dir/analysis_report.txt"
    echo ""
    
    return 0
}

#############################################################################
# Hauptprogramm
#############################################################################

main() {
    # Argument-Parsing
    if [ $# -eq 0 ]; then
        print_error "Keine Archiv-Datei oder Verzeichnis angegeben"
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
    
    local input_path="$1"
    
    # Header anzeigen
    print_header
    echo ""
    
    # Prüfe Abhängigkeiten
    if ! check_dependencies; then
        exit 1
    fi
    
    # Prüfe ob Pfad existiert
    if [ ! -e "$input_path" ]; then
        print_error "Pfad nicht gefunden: $input_path"
        exit 1
    fi
    
    trap cleanup EXIT
    
    # Prüfe ob es ein Verzeichnis oder eine Datei ist
    if [ -d "$input_path" ]; then
        # Verzeichnis-Modus: Finde alle Archive rekursiv
        print_info "Verzeichnis-Modus aktiviert"
        print_info "Durchsuche: $input_path"
        echo ""
        
        # Finde alle Archive und speichere in Array
        local archives_array=()
        while IFS= read -r archive; do
            archives_array+=("$archive")
        done < <(find_archives "$input_path")
        
        if [ ${#archives_array[@]} -eq 0 ]; then
            print_warning "Keine Archive im Verzeichnis gefunden"
            exit 0
        fi
        
        print_success "Gefundene Archive: ${#archives_array[@]}"
        echo ""
        
        # Erstelle Hauptausgabeverzeichnis und Reports-Verzeichnis
        local main_output_dir
        main_output_dir="$(basename "$input_path")_analysis_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$main_output_dir"
        mkdir -p "$main_output_dir/reports"
        print_success "Hauptausgabeverzeichnis: $main_output_dir"
        print_success "Reports-Verzeichnis: $main_output_dir/reports"
        echo ""
        
        # Verarbeite jedes Archiv
        local processed=0
        local failed=0
        local counter=1
        
        for archive in "${archives_array[@]}"; do
            # Setze Statistiken zurück für jedes Archiv
            TOTAL_FILES=0
            TOTAL_SIZE=0
            TEXT_FILES=0
            BINARY_FILES=0
            BINARY_SIZE=0
            SYMLINKS=0
            HARDLINKS=0
            PIPES=0
            SOCKETS=0
            BLOCK_DEVICES=0
            CHAR_DEVICES=0
            ZERO_BYTE_FILES=0
            TEN_BYTE_FILES=0
            TWENTY_BYTE_FILES=0
            
            if process_single_archive "$archive" "$main_output_dir" "$counter"; then
                ((processed++))
            else
                ((failed++))
            fi
            ((counter++))
        done
        
        # Gesamtzusammenfassung
        echo ""
        print_success "═══════════════════════════════════════════════════════════"
        print_success "Batch-Analyse abgeschlossen!"
        print_success "═══════════════════════════════════════════════════════════"
        echo ""
        echo "Zusammenfassung:"
        echo "  - Gefundene Archive: ${#archives_array[@]}"
        echo "  - Erfolgreich verarbeitet: $processed"
        echo "  - Fehlgeschlagen: $failed"
        echo "  - Ausgabeverzeichnis: $main_output_dir"
        echo ""
        
    else
        # Einzeldatei-Modus
        print_info "Einzeldatei-Modus"
        echo ""
        
        # Prüfe ob es eine Datei ist
        if [ ! -f "$input_path" ]; then
            print_error "Keine reguläre Datei: $input_path"
            exit 1
        fi
        
        # Temporäre Dateien
        TEMP_SIZE_FILE=$(mktemp)
        TEMP_EXT_FILE=$(mktemp)
        TEMP_BINARY_FILE=$(mktemp)
        TEMP_SYMLINK_FILE=$(mktemp)
        TEMP_HARDLINK_FILE=$(mktemp)
        TEMP_SPECIAL_FILE=$(mktemp)
        
        # Verarbeite einzelnes Archiv (Zähler 1 für Einzeldatei, kein zentrales Reports-Verzeichnis)
        if process_single_archive "$input_path" "" "1"; then
            print_success "Analyse abgeschlossen!"
        else
            print_error "Analyse fehlgeschlagen"
            exit 1
        fi
    fi
}

# Starte Hauptprogramm
main "$@"

# Made with Bob

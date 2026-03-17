#!/bin/bash
#==============================================================================
# SLES - Alte IP-Adresse aus Netzwerk-Konfiguration entfernen
#==============================================================================
# Dieses Script entfernt eine alte IP-Adresse aus der SLES Netzwerk-
# Konfiguration (Wicked).
#
# Kompatibel mit:
#   - SLES 15 SP5/SP4/SP3
#   - SLES 12 SP5
#
# Verwendung:
#   sudo ./remove-old-ip-sles.sh <ip-adresse>
#   sudo ./remove-old-ip-sles.sh --list
#   sudo ./remove-old-ip-sles.sh --help
#
# Beispiele:
#   sudo ./remove-old-ip-sles.sh 9.155.64.146
#   sudo ./remove-old-ip-sles.sh --list
#==============================================================================

set -euo pipefail

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Konstanten
NETWORK_CONFIG_DIR="/etc/sysconfig/network"
BACKUP_DIR="/tmp/sles_network_backup_$$"

# Logging-Funktionen
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

#==============================================================================
# Funktionen
#==============================================================================

show_usage() {
    cat << EOF
Verwendung: $0 <ip-adresse>
        $0 --list
        $0 --help

Optionen:
    <ip-adresse>    Die zu entfernende IP-Adresse (z.B. 9.155.64.146)
    --list          Zeigt alle aktuell konfigurierten IP-Adressen
    --help          Zeigt diese Hilfe

Beispiele:
    # Entferne spezifische IP
    sudo $0 9.155.64.146

    # Liste alle IPs
    sudo $0 --list

Hinweise:
    - Das Script erstellt automatisch ein Backup
    - Bei Fehlern wird das Backup automatisch wiederhergestellt
    - Verwendet 'wicked' für Netzwerk-Neustart
EOF
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Dieses Script muss als root ausgeführt werden!"
        exit 1
    fi
}

check_sles() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Kann OS nicht identifizieren - /etc/os-release fehlt"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "sles" ]]; then
        log_error "Dieses Script ist nur für SLES! Erkanntes System: $ID"
        exit 1
    fi
    
    log_info "SLES Version: $VERSION"
}

check_wicked() {
    if ! command -v wicked &> /dev/null; then
        log_error "Wicked ist nicht installiert!"
        exit 1
    fi
}

list_current_ips() {
    log_info "Aktuell konfigurierte IP-Adressen:"
    echo ""
    
    # Zeige IPs aus ip addr
    log_info "Aktive IP-Adressen (ip addr):"
    ip -o addr show | grep -E 'inet ' | grep -v '127.0.0.1' | awk '{print "  " $2 ": " $4}' | sort
    
    echo ""
    
    # Zeige IPs aus Konfigurationsdateien
    log_info "Konfigurierte IP-Adressen (ifcfg-Dateien):"
    for ifcfg in "$NETWORK_CONFIG_DIR"/ifcfg-*; do
        if [[ -f "$ifcfg" ]]; then
            local interface=$(basename "$ifcfg" | sed 's/ifcfg-//')
            echo "  Interface: $interface"
            
            # Primäre IP
            if grep -q "^IPADDR=" "$ifcfg"; then
                grep "^IPADDR=" "$ifcfg" | sed "s/IPADDR=/    Primär: /" | tr -d "'"
            fi
            
            # Sekundäre IPs (LABEL_0, LABEL_1, etc.)
            for i in {0..9}; do
                if grep -q "^IPADDR_${i}=" "$ifcfg"; then
                    grep "^IPADDR_${i}=" "$ifcfg" | sed "s/IPADDR_${i}=/    Sekundär ${i}: /" | tr -d "'"
                fi
            done
        fi
    done
    
    echo ""
}

find_ip_in_config() {
    local ip_to_find="$1"
    local found_files=()
    
    for ifcfg in "$NETWORK_CONFIG_DIR"/ifcfg-*; do
        if [[ -f "$ifcfg" ]] && grep -q "$ip_to_find" "$ifcfg"; then
            found_files+=("$ifcfg")
        fi
    done
    
    if [[ ${#found_files[@]} -eq 0 ]]; then
        return 1
    fi
    
    printf '%s\n' "${found_files[@]}"
    return 0
}

create_backup() {
    log_info "Erstelle Backup der Netzwerk-Konfiguration..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup aller ifcfg-Dateien
    cp -r "$NETWORK_CONFIG_DIR"/* "$BACKUP_DIR/" 2>/dev/null || true
    
    # Backup Hostname
    hostname > "$BACKUP_DIR/hostname.txt" 2>/dev/null || true
    
    log_success "Backup erstellt: $BACKUP_DIR"
}

restore_backup() {
    log_warning "Stelle Backup wieder her..."
    
    if [[ -d "$BACKUP_DIR" ]]; then
        cp -r "$BACKUP_DIR"/* "$NETWORK_CONFIG_DIR/"
        log_success "Backup wiederhergestellt"
        
        # Starte Netzwerk neu
        log_info "Starte Netzwerk neu..."
        wicked ifreload all
    else
        log_error "Backup-Verzeichnis nicht gefunden: $BACKUP_DIR"
    fi
}

remove_ip_from_file() {
    local file="$1"
    local ip_to_remove="$2"
    
    log_info "Entferne IP $ip_to_remove aus $(basename "$file")..."
    
    # Zeige aktuelle Konfiguration
    echo ""
    log_info "Aktuelle Konfiguration:"
    cat "$file"
    echo ""
    
    # Erstelle temporäre Datei
    local temp_file=$(mktemp)
    
    # Escape IP für regex (ersetze . mit \.)
    local escaped_ip="${ip_to_remove//./\\.}"
    
    # Prüfe ob es die primäre IP ist
    if grep -q "^IPADDR=['\"]\\?${escaped_ip}" "$file"; then
        log_info "IP ist die primäre IP-Adresse"
        
        # Entferne IPADDR-Zeile
        sed "/^IPADDR=['\"]\\?${escaped_ip}/d" "$file" > "$temp_file"
        
    # Prüfe ob es eine sekundäre IP ist (LABEL_X)
    elif grep -q "^IPADDR_[0-9]=['\"]\\?${escaped_ip}" "$file"; then
        log_info "IP ist eine sekundäre IP-Adresse"
        
        # Finde Label-Nummer
        local label_num=$(grep "^IPADDR_[0-9]=['\"]\\?${escaped_ip}" "$file" | sed 's/^IPADDR_\([0-9]\)=.*/\1/')
        
        # Entferne LABEL_X und IPADDR_X Zeilen
        sed -e "/^LABEL_${label_num}=/d" -e "/^IPADDR_${label_num}=/d" "$file" > "$temp_file"
        
    else
        # Versuche flexibleres Muster - jede Zeile die die IP enthält
        log_info "Verwende flexibles Suchmuster..."
        grep -v "$ip_to_remove" "$file" > "$temp_file"
    fi
    
    # Prüfe ob sich etwas geändert hat
    if diff -q "$file" "$temp_file" > /dev/null; then
        log_error "IP konnte nicht in der Datei gefunden werden"
        rm "$temp_file"
        return 1
    fi
    
    # Ersetze Original-Datei
    mv "$temp_file" "$file"
    
    log_success "IP $ip_to_remove wurde entfernt"
    
    # Zeige neue Konfiguration
    echo ""
    log_info "Neue Konfiguration:"
    cat "$file"
    echo ""
    
    return 0
}

validate_config() {
    log_info "Validiere Netzwerk-Konfiguration..."
    
    # Prüfe Syntax der ifcfg-Dateien
    for ifcfg in "$NETWORK_CONFIG_DIR"/ifcfg-*; do
        if [[ -f "$ifcfg" ]]; then
            # Prüfe ob BOOTPROTO gesetzt ist
            if ! grep -q "^BOOTPROTO=" "$ifcfg"; then
                log_error "BOOTPROTO fehlt in $(basename "$ifcfg")"
                return 1
            fi
            
            # Prüfe ob STARTMODE gesetzt ist
            if ! grep -q "^STARTMODE=" "$ifcfg"; then
                log_error "STARTMODE fehlt in $(basename "$ifcfg")"
                return 1
            fi
        fi
    done
    
    log_success "Konfiguration ist gültig"
    return 0
}

apply_config() {
    log_info "Wende neue Konfiguration an..."
    log_warning "ACHTUNG: Netzwerk wird neu gestartet!"
    echo ""
    
    # Bestätigung
    read -p "Möchten Sie fortfahren? (j/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[JjYy]$ ]]; then
        log_info "Abgebrochen"
        return 1
    fi
    
    # Starte Wicked neu
    if wicked ifreload all; then
        log_success "Netzwerk erfolgreich neu gestartet"
        return 0
    else
        log_error "Fehler beim Netzwerk-Neustart!"
        return 1
    fi
}

remove_ip() {
    local ip_to_remove="$1"
    
    log_info "Suche IP-Adresse: $ip_to_remove"
    echo ""
    
    # Prüfe ob IP aktuell konfiguriert ist
    if ip addr show | grep -q "$ip_to_remove"; then
        log_info "IP $ip_to_remove ist aktuell auf dem System konfiguriert"
    else
        log_warning "IP $ip_to_remove ist NICHT auf dem System konfiguriert"
    fi
    
    # Suche IP in Konfigurationsdateien
    local files=$(find_ip_in_config "$ip_to_remove")
    
    if [[ -z "$files" ]]; then
        log_error "IP $ip_to_remove wurde in keiner Konfigurationsdatei gefunden"
        echo ""
        log_info "Möchten Sie die IP trotzdem vom System entfernen? (j/N)"
        read -r response
        if [[ "$response" =~ ^[JjYy]$ ]]; then
            # Finde Interface mit dieser IP
            local interface=$(ip -o addr show | grep "$ip_to_remove" | awk '{print $2}')
            if [[ -n "$interface" ]]; then
                log_info "Entferne IP $ip_to_remove von Interface $interface..."
                ip addr del "$ip_to_remove/25" dev "$interface" 2>/dev/null || \
                ip addr del "$ip_to_remove/24" dev "$interface" 2>/dev/null || \
                log_error "Konnte IP nicht entfernen"
                log_success "IP temporär entfernt (bis zum Neustart)"
            fi
        fi
        exit 0
    fi
    
    log_info "IP gefunden in folgenden Dateien:"
    echo "$files" | while read -r file; do
        echo "  - $(basename "$file")"
    done
    echo ""
    
    # Bestätigung
    read -p "Möchten Sie die IP $ip_to_remove entfernen? (j/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[JjYy]$ ]]; then
        log_info "Abgebrochen"
        exit 0
    fi
    
    # Backup erstellen
    create_backup
    echo ""
    
    # IP aus allen Dateien entfernen
    local success=true
    echo "$files" | while read -r file; do
        if ! remove_ip_from_file "$file" "$ip_to_remove"; then
            success=false
        fi
    done
    
    if [[ "$success" == false ]]; then
        log_error "Fehler beim Entfernen der IP!"
        restore_backup
        exit 1
    fi
    
    # Validieren
    if ! validate_config; then
        log_error "Validierung fehlgeschlagen!"
        restore_backup
        exit 1
    fi
    
    # Anwenden
    if apply_config; then
        log_success "IP $ip_to_remove wurde erfolgreich entfernt!"
        echo ""
        log_info "Aktuelle IP-Adressen:"
        ip -o addr show | grep -E 'inet ' | grep -v '127.0.0.1' | awk '{print "  " $2 ": " $4}'
        echo ""
        log_info "Backup gespeichert in: $BACKUP_DIR"
    else
        log_error "Fehler beim Anwenden der Konfiguration"
        restore_backup
        exit 1
    fi
}

#==============================================================================
# Hauptprogramm
#==============================================================================

main() {
    # Prüfe Voraussetzungen
    check_root
    check_sles
    check_wicked
    
    echo ""
    
    # Prüfe Argumente
    if [[ $# -eq 0 ]]; then
        log_error "Keine IP-Adresse angegeben!"
        echo ""
        show_usage
        exit 1
    fi
    
    case "$1" in
        --help|-h)
            show_usage
            exit 0
            ;;
        --list|-l)
            list_current_ips
            exit 0
            ;;
        *)
            # Validiere IP-Format (einfache Prüfung)
            if [[ ! "$1" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                log_error "Ungültiges IP-Format: $1"
                exit 1
            fi
            
            remove_ip "$1"
            ;;
    esac
}

# Führe Hauptprogramm aus
main "$@"

# Made with Bob

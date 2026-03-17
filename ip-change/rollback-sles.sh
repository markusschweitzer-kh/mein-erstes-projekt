#!/bin/bash
#==============================================================================
# SLES Netzwerk-Konfiguration Rollback Script
#==============================================================================
# Dieses Script stellt die Netzwerkkonfiguration aus einem Backup wieder her.
#
# Kompatibel mit:
#   - SLES 15 SP5/SP4/SP3
#   - SLES 12 SP5
#
# Verwendet Wicked für Netzwerk-Management
#
# Verwendung:
#   sudo ./rollback-sles.sh [backup-verzeichnis]
#
# Beispiel:
#   sudo ./rollback-sles.sh backups/hostname_1234567890
#==============================================================================

set -euo pipefail

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Prüfe Root-Rechte
if [[ $EUID -ne 0 ]]; then
   log_error "Dieses Script muss als root ausgeführt werden!"
   exit 1
fi

# Prüfe ob SLES
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

# Prüfe ob Wicked installiert ist
if ! command -v wicked &> /dev/null; then
    log_error "Wicked ist nicht installiert!"
    exit 1
fi

# Konstanten
NETWORK_CONFIG_DIR="/etc/sysconfig/network"
BACKUP_BASE_DIR="./backups"

#==============================================================================
# Funktionen
#==============================================================================

show_usage() {
    cat << EOF
Verwendung: $0 [backup-verzeichnis]

Optionen:
    backup-verzeichnis    Pfad zum Backup-Verzeichnis (optional)
                         Wenn nicht angegeben, wird eine Liste angezeigt

Beispiele:
    # Liste verfügbare Backups
    $0

    # Stelle spezifisches Backup wieder her
    $0 backups/hostname_1234567890

    # Mit absolutem Pfad
    $0 /path/to/backups/hostname_1234567890
EOF
}

list_backups() {
    log_info "Verfügbare Backups:"
    echo ""
    
    if [[ ! -d "$BACKUP_BASE_DIR" ]]; then
        log_warning "Backup-Verzeichnis nicht gefunden: $BACKUP_BASE_DIR"
        return 1
    fi
    
    local count=0
    for backup_dir in "$BACKUP_BASE_DIR"/*; do
        if [[ -d "$backup_dir" ]] && [[ -f "$backup_dir/backup_info.txt" ]]; then
            count=$((count + 1))
            echo "[$count] $(basename "$backup_dir")"
            echo "    $(head -n 1 "$backup_dir/backup_info.txt")"
            if [[ -f "$backup_dir/backup_info.txt" ]]; then
                grep "Alter Hostname:" "$backup_dir/backup_info.txt" | sed 's/^/    /'
                grep "Neuer Hostname:" "$backup_dir/backup_info.txt" | sed 's/^/    /'
            fi
            echo ""
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        log_warning "Keine Backups gefunden in $BACKUP_BASE_DIR"
        return 1
    fi
    
    return 0
}

validate_backup() {
    local backup_dir="$1"
    
    if [[ ! -d "$backup_dir" ]]; then
        log_error "Backup-Verzeichnis nicht gefunden: $backup_dir"
        return 1
    fi
    
    if [[ ! -f "$backup_dir/backup_info.txt" ]]; then
        log_error "Backup-Info nicht gefunden: $backup_dir/backup_info.txt"
        return 1
    fi
    
    # Prüfe ob mindestens eine Konfigurationsdatei vorhanden ist
    local has_config=false
    for file in "$backup_dir"/ifcfg-* "$backup_dir/routes" "$backup_dir/config" "$backup_dir/hostname"; do
        if [[ -f "$file" ]]; then
            has_config=true
            break
        fi
    done
    
    if [[ "$has_config" == false ]]; then
        log_error "Keine Konfigurationsdateien im Backup gefunden"
        return 1
    fi
    
    return 0
}

show_backup_info() {
    local backup_dir="$1"
    
    log_info "Backup-Informationen:"
    echo ""
    cat "$backup_dir/backup_info.txt"
    echo ""
}

create_pre_rollback_backup() {
    local timestamp=$(date +%s)
    local backup_dir="./backups/pre_rollback_${timestamp}"
    
    log_info "Erstelle Backup vor Rollback: $backup_dir"
    
    mkdir -p "$backup_dir"
    
    # Backup Hostname
    hostname > "$backup_dir/hostname" 2>/dev/null || true
    cp /etc/hostname "$backup_dir/hostname_file" 2>/dev/null || true
    
    # Backup Netzwerk-Konfiguration
    if [[ -d "$NETWORK_CONFIG_DIR" ]]; then
        cp -r "$NETWORK_CONFIG_DIR"/* "$backup_dir/" 2>/dev/null || true
    fi
    
    # Backup Info
    cat > "$backup_dir/backup_info.txt" << EOF
Pre-Rollback Backup erstellt: $(date --iso-8601=seconds)
Aktueller Hostname: $(hostname)
Aktuelles System: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
EOF
    
    log_success "Pre-Rollback Backup erstellt: $backup_dir"
}

restore_hostname() {
    local backup_dir="$1"
    
    if [[ -f "$backup_dir/hostname_file" ]]; then
        log_info "Stelle Hostname wieder her..."
        
        local old_hostname=$(cat "$backup_dir/hostname_file")
        
        # Setze Hostname
        hostnamectl set-hostname "$old_hostname" 2>/dev/null || \
            hostname "$old_hostname"
        
        # Aktualisiere /etc/hostname
        echo "$old_hostname" > /etc/hostname
        
        log_success "Hostname wiederhergestellt: $old_hostname"
    else
        log_warning "Keine Hostname-Backup-Datei gefunden"
    fi
}

restore_network_config() {
    local backup_dir="$1"
    
    log_info "Stelle Netzwerk-Konfiguration wieder her..."
    
    # Stelle Interface-Konfigurationen wieder her
    for ifcfg_file in "$backup_dir"/ifcfg-*; do
        if [[ -f "$ifcfg_file" ]]; then
            local filename=$(basename "$ifcfg_file")
            log_info "Stelle $filename wieder her..."
            cp "$ifcfg_file" "$NETWORK_CONFIG_DIR/$filename"
            chmod 644 "$NETWORK_CONFIG_DIR/$filename"
        fi
    done
    
    # Stelle Routing-Konfiguration wieder her
    if [[ -f "$backup_dir/routes" ]]; then
        log_info "Stelle Routing-Konfiguration wieder her..."
        cp "$backup_dir/routes" "$NETWORK_CONFIG_DIR/routes"
        chmod 644 "$NETWORK_CONFIG_DIR/routes"
    fi
    
    # Stelle DNS-Konfiguration wieder her
    if [[ -f "$backup_dir/config" ]]; then
        log_info "Stelle DNS-Konfiguration wieder her..."
        cp "$backup_dir/config" "$NETWORK_CONFIG_DIR/config"
        chmod 644 "$NETWORK_CONFIG_DIR/config"
    fi
    
    log_success "Netzwerk-Konfiguration wiederhergestellt"
}

restart_network() {
    log_warning "Starte Netzwerk neu..."
    log_warning "ACHTUNG: SSH-Verbindung könnte kurzzeitig unterbrochen werden!"
    echo ""
    
    # Warte auf Bestätigung
    read -p "Netzwerk jetzt neu starten? (j/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[JjYy]$ ]]; then
        log_info "Netzwerk-Neustart abgebrochen"
        log_warning "Bitte manuell neu starten mit: wicked ifreload all"
        return 0
    fi
    
    # Starte Wicked neu
    if wicked ifreload all; then
        log_success "Netzwerk erfolgreich neu gestartet"
    else
        log_error "Fehler beim Netzwerk-Neustart!"
        log_info "Versuche alternative Methode..."
        
        # Alternative: Einzelne Interfaces neu starten
        for interface in $(ls "$NETWORK_CONFIG_DIR"/ifcfg-* | sed 's/.*ifcfg-//'); do
            log_info "Starte Interface $interface neu..."
            wicked ifdown "$interface" 2>/dev/null || true
            sleep 1
            wicked ifup "$interface" 2>/dev/null || true
        done
    fi
    
    # Warte kurz
    sleep 3
}

verify_network() {
    log_info "Überprüfe Netzwerk-Status..."
    echo ""
    
    # Zeige Hostname
    log_info "Aktueller Hostname: $(hostname)"
    
    # Zeige IP-Adressen
    log_info "Aktuelle IP-Adressen:"
    ip -o addr show | grep -E 'inet ' | grep -v '127.0.0.1' | awk '{print "  " $2 ": " $4}'
    
    # Zeige Routen
    echo ""
    log_info "Aktuelle Routen:"
    ip route show | head -n 5 | sed 's/^/  /'
    
    # Zeige Wicked-Status
    echo ""
    log_info "Wicked Interface-Status:"
    for interface in $(ls "$NETWORK_CONFIG_DIR"/ifcfg-* 2>/dev/null | sed 's/.*ifcfg-//'); do
        echo "  Interface: $interface"
        wicked ifstatus "$interface" 2>/dev/null | grep -E "link|addr" | sed 's/^/    /' || true
    done
}

#==============================================================================
# Hauptprogramm
#==============================================================================

main() {
    echo ""
    log_info "SLES Netzwerk-Konfiguration Rollback"
    echo "========================================"
    echo ""
    
    # Prüfe Argumente
    if [[ $# -eq 0 ]]; then
        list_backups
        echo ""
        log_info "Verwendung: $0 <backup-verzeichnis>"
        exit 0
    fi
    
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    local backup_dir="$1"
    
    # Validiere Backup
    if ! validate_backup "$backup_dir"; then
        exit 1
    fi
    
    # Zeige Backup-Info
    show_backup_info "$backup_dir"
    
    # Bestätigung
    log_warning "ACHTUNG: Diese Aktion wird die aktuelle Netzwerk-Konfiguration überschreiben!"
    echo ""
    read -p "Möchten Sie fortfahren? (j/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[JjYy]$ ]]; then
        log_info "Rollback abgebrochen"
        exit 0
    fi
    
    echo ""
    
    # Erstelle Pre-Rollback Backup
    create_pre_rollback_backup
    echo ""
    
    # Führe Rollback durch
    restore_hostname "$backup_dir"
    echo ""
    
    restore_network_config "$backup_dir"
    echo ""
    
    restart_network
    echo ""
    
    verify_network
    echo ""
    
    log_success "Rollback erfolgreich abgeschlossen!"
    echo ""
    log_info "WICHTIG: Bitte prüfen Sie die Netzwerk-Konfiguration!"
    log_info "Bei Problemen können Sie das Pre-Rollback Backup verwenden."
    echo ""
}

# Führe Hauptprogramm aus
main "$@"

# Made with Bob

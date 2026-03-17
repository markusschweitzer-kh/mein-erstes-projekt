#!/bin/bash

#==============================================================================
# Rollback Script für Ubuntu Netzwerkkonfiguration
#==============================================================================
# Stellt die Netzwerkkonfiguration aus einem Backup wieder her
#
# Verwendung:
#   ./rollback-ubuntu.sh [backup_verzeichnis]
#   ./rollback-ubuntu.sh hostname_20260313_083000
#
# Ohne Parameter wird das neueste Backup verwendet
#==============================================================================

set -euo pipefail

# Farben
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Konfiguration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BACKUP_BASE_DIR="${SCRIPT_DIR}/backups"

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

show_usage() {
    cat << EOF
Verwendung: $(basename "$0") [BACKUP_VERZEICHNIS]

Stellt die Ubuntu Netzwerkkonfiguration aus einem Backup wieder her.

OPTIONEN:
    -l, --list      Zeigt alle verfügbaren Backups an
    -h, --help      Diese Hilfe anzeigen

BEISPIELE:
    # Neuestes Backup verwenden
    $(basename "$0")

    # Spezifisches Backup verwenden
    $(basename "$0") hostname_20260313_083000

    # Alle Backups anzeigen
    $(basename "$0") --list

EOF
}

list_backups() {
    log_info "Verfügbare Backups:"
    echo ""
    
    if [[ ! -d "${BACKUP_BASE_DIR}" ]] || [[ -z "$(ls -A "${BACKUP_BASE_DIR}" 2>/dev/null)" ]]; then
        log_warning "Keine Backups gefunden in ${BACKUP_BASE_DIR}"
        return 1
    fi
    
    local count=1
    for backup_dir in "${BACKUP_BASE_DIR}"/*; do
        if [[ -d "${backup_dir}" ]]; then
            local backup_name=$(basename "${backup_dir}")
            local backup_date=$(echo "${backup_name}" | grep -oE '[0-9]{8}_[0-9]{6}' || echo "unbekannt")
            
            echo "${count}. ${backup_name}"
            
            if [[ -f "${backup_dir}/hostname" ]]; then
                echo "   Hostname: $(cat "${backup_dir}/hostname")"
            fi
            
            if [[ -f "${backup_dir}/01-netcfg.yaml" ]]; then
                echo "   Netplan-Konfiguration vorhanden"
            fi
            
            if [[ -f "${backup_dir}/netplan_backup.tar.gz" ]]; then
                echo "   Vollständiges Netplan-Backup vorhanden"
            fi
            
            echo ""
            ((count++))
        fi
    done
}

find_latest_backup() {
    local latest=$(ls -td "${BACKUP_BASE_DIR}"/*/ 2>/dev/null | head -1)
    if [[ -n "${latest}" ]]; then
        basename "${latest}"
    else
        return 1
    fi
}

restore_backup() {
    local backup_name="$1"
    local backup_dir="${BACKUP_BASE_DIR}/${backup_name}"
    
    if [[ ! -d "${backup_dir}" ]]; then
        log_error "Backup-Verzeichnis nicht gefunden: ${backup_dir}"
        return 1
    fi
    
    log_info "Stelle Backup wieder her: ${backup_name}"
    echo ""
    
    # Prüfe Root-Rechte
    if [[ $EUID -ne 0 ]]; then
        log_error "Dieses Script muss als root ausgeführt werden"
        log_info "Versuchen Sie: sudo $0 $*"
        return 1
    fi
    
    # Hostname wiederherstellen
    if [[ -f "${backup_dir}/hostname" ]]; then
        log_info "Stelle Hostname wieder her..."
        cp -v "${backup_dir}/hostname" /etc/hostname
        hostnamectl set-hostname "$(cat /etc/hostname)"
        log_success "Hostname wiederhergestellt"
    else
        log_warning "Keine Hostname-Backup-Datei gefunden"
    fi
    
    # Netplan-Konfiguration wiederherstellen
    if [[ -f "${backup_dir}/netplan_backup.tar.gz" ]]; then
        log_info "Stelle vollständige Netplan-Konfiguration wieder her..."
        
        # Backup der aktuellen Konfiguration (falls Rollback fehlschlägt)
        log_info "Erstelle Sicherheitskopie der aktuellen Konfiguration..."
        tar czf /tmp/netplan_current_$(date +%s).tar.gz /etc/netplan/ 2>/dev/null || true
        
        # Stelle Backup wieder her
        tar xzf "${backup_dir}/netplan_backup.tar.gz" -C / 2>/dev/null
        log_success "Netplan-Konfiguration wiederhergestellt"
        
    elif [[ -f "${backup_dir}/01-netcfg.yaml" ]]; then
        log_info "Stelle Netplan-Hauptkonfiguration wieder her..."
        cp -v "${backup_dir}/01-netcfg.yaml" /etc/netplan/01-netcfg.yaml
        log_success "Netplan-Konfiguration wiederhergestellt"
    else
        log_warning "Keine Netplan-Backup-Dateien gefunden"
    fi
    
    echo ""
    log_info "Validiere Netplan-Konfiguration..."
    
    if netplan generate 2>/dev/null; then
        log_success "Netplan-Konfiguration ist valide"
    else
        log_error "Netplan-Konfiguration ist ungültig!"
        log_warning "Bitte prüfen Sie /etc/netplan/ manuell"
        return 1
    fi
    
    echo ""
    log_info "Wende Netplan-Konfiguration an..."
    log_warning "Die Netzwerkverbindung wird kurz unterbrochen!"
    
    # Verwende netplan try für sicheren Rollback
    log_info "Verwende 'netplan try' mit 120 Sekunden Timeout..."
    log_info "Drücken Sie ENTER um die Änderungen zu bestätigen"
    log_info "oder warten Sie 120 Sekunden für automatischen Rollback"
    
    if netplan try --timeout 120; then
        log_success "Netplan-Konfiguration erfolgreich angewendet"
    else
        log_error "Fehler beim Anwenden der Netplan-Konfiguration"
        log_info "Die alte Konfiguration wurde automatisch wiederhergestellt"
        return 1
    fi
    
    echo ""
    log_success "Rollback abgeschlossen!"
    echo ""
    log_info "Aktuelle Konfiguration:"
    echo "Hostname: $(hostname -f)"
    echo ""
    echo "IP-Adressen:"
    ip -o addr show | grep -E 'inet ' | awk '{print "  " $2 ": " $4}'
    echo ""
    echo "Netplan Status:"
    netplan status 2>/dev/null || ip addr show
    echo ""
    log_warning "Bitte prüfen Sie die Netzwerkverbindung!"
}

# Hauptprogramm
main() {
    case "${1:-}" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -l|--list)
            list_backups
            exit 0
            ;;
        "")
            # Kein Parameter - verwende neuestes Backup
            log_info "Suche neuestes Backup..."
            local latest_backup=$(find_latest_backup)
            if [[ -z "${latest_backup}" ]]; then
                log_error "Keine Backups gefunden"
                exit 1
            fi
            log_info "Verwende neuestes Backup: ${latest_backup}"
            echo ""
            read -p "Möchten Sie fortfahren? (j/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[JjYy]$ ]]; then
                log_info "Abgebrochen"
                exit 0
            fi
            restore_backup "${latest_backup}"
            ;;
        *)
            # Parameter angegeben - verwende dieses Backup
            restore_backup "$1"
            ;;
    esac
}

main "$@"

# Made with Bob

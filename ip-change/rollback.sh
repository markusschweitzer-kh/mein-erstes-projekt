#!/bin/bash

#==============================================================================
# Rollback Script für Netzwerkkonfiguration
#==============================================================================
# Stellt die Netzwerkkonfiguration aus einem Backup wieder her
#
# Verwendung:
#   ./rollback.sh [backup_verzeichnis]
#   ./rollback.sh hostname_20260313_083000
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

Stellt die Netzwerkkonfiguration aus einem Backup wieder her.

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
            
            if [[ -f "${backup_dir}/backup_manifest.txt" ]]; then
                echo "   Dateien:"
                cat "${backup_dir}/backup_manifest.txt" | sed 's/^/   - /'
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
    
    # Netzwerk-Interfaces wiederherstellen
    local restored_interfaces=0
    for ifcfg_file in "${backup_dir}"/ifcfg-*; do
        if [[ -f "${ifcfg_file}" ]]; then
            local ifcfg_name=$(basename "${ifcfg_file}")
            log_info "Stelle ${ifcfg_name} wieder her..."
            cp -v "${ifcfg_file}" "/etc/sysconfig/network-scripts/${ifcfg_name}"
            log_success "${ifcfg_name} wiederhergestellt"
            ((restored_interfaces++))
        fi
    done
    
    if [[ ${restored_interfaces} -eq 0 ]]; then
        log_warning "Keine Netzwerk-Interface-Backups gefunden"
    fi
    
    echo ""
    log_info "Starte Netzwerk neu..."
    
    # Versuche NetworkManager
    if systemctl is-active --quiet NetworkManager; then
        log_info "Verwende NetworkManager..."
        nmcli connection reload
        
        # Starte alle Interfaces neu
        for ifcfg_file in "${backup_dir}"/ifcfg-*; do
            if [[ -f "${ifcfg_file}" ]]; then
                local ifcfg_name=$(basename "${ifcfg_file}")
                local interface_name="${ifcfg_name#ifcfg-}"
                log_info "Starte Interface ${interface_name} neu..."
                nmcli connection down "${interface_name}" 2>/dev/null || true
                nmcli connection up "${interface_name}" || log_warning "Konnte ${interface_name} nicht starten"
            fi
        done
    else
        # Fallback auf network service
        log_info "Verwende network service..."
        systemctl restart network || log_warning "Konnte network service nicht neu starten"
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

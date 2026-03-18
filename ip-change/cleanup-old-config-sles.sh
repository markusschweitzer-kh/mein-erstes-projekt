#!/bin/bash

################################################################################
# SLES Network Configuration Cleanup Script
# 
# Dieses Script entfernt die alte IP-Konfiguration und das alte Gateway
# nach erfolgreicher Migration zu neuen IP-Adressen.
#
# WICHTIG: Führen Sie dieses Script erst aus, nachdem Sie bestätigt haben,
#          dass die neue IP-Konfiguration funktioniert!
#
# Verwendung:
#   sudo ./cleanup-old-config-sles.sh [--dry-run] [--keep-gateway]
#
# Optionen:
#   --dry-run       Zeigt nur an, was gemacht würde (keine Änderungen)
#   --keep-gateway  Behält das alte Gateway als Backup
#
################################################################################

set -euo pipefail

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variablen
DRY_RUN=false
KEEP_GATEWAY=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/cleanup_$(date +%Y%m%d_%H%M%S).log"

# Erstelle Log-Verzeichnis
mkdir -p "${LOG_DIR}"

################################################################################
# Funktionen
################################################################################

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

info() {
    log "INFO" "${BLUE}$*${NC}"
}

success() {
    log "SUCCESS" "${GREEN}$*${NC}"
}

warning() {
    log "WARNING" "${YELLOW}$*${NC}"
}

error() {
    log "ERROR" "${RED}$*${NC}"
}

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Dieses Script muss als root ausgeführt werden"
        exit 1
    fi
}

backup_config() {
    local backup_dir="${SCRIPT_DIR}/backups/cleanup_$(date +%Y%m%d_%H%M%S)"
    
    info "Erstelle Backup in: ${backup_dir}"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        info "[DRY-RUN] Würde Backup erstellen"
        return 0
    fi
    
    mkdir -p "${backup_dir}"
    
    # Backup der Netzwerk-Konfiguration
    if [[ -d /etc/sysconfig/network ]]; then
        cp -r /etc/sysconfig/network "${backup_dir}/"
        success "Backup von /etc/sysconfig/network erstellt"
    fi
    
    # Backup von /etc/hosts
    if [[ -f /etc/hosts ]]; then
        cp /etc/hosts "${backup_dir}/"
        success "Backup von /etc/hosts erstellt"
    fi
    
    echo "${backup_dir}" > "${SCRIPT_DIR}/.last_cleanup_backup"
    success "Backup erfolgreich erstellt"
}

find_primary_interface() {
    local interface=$(ip route | grep default | head -n1 | awk '{print $5}')
    if [[ -z "${interface}" ]]; then
        error "Konnte primäres Interface nicht finden"
        exit 1
    fi
    echo "${interface}"
}

remove_old_ip() {
    local interface=$1
    local ifcfg_file="/etc/sysconfig/network/ifcfg-${interface}"
    
    print_header "Entferne alte IP-Konfiguration"
    
    if [[ ! -f "${ifcfg_file}" ]]; then
        warning "Interface-Konfiguration nicht gefunden: ${ifcfg_file}"
        return 1
    fi
    
    # Finde alte IP (LABEL_2 oder höher)
    local old_ip_labels=$(grep -E "^LABEL_[2-9]=" "${ifcfg_file}" | cut -d= -f1 || true)
    
    if [[ -z "${old_ip_labels}" ]]; then
        info "Keine alten IP-Adressen gefunden (LABEL_2+)"
        return 0
    fi
    
    info "Gefundene alte IP-Labels: ${old_ip_labels}"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        info "[DRY-RUN] Würde folgende Zeilen entfernen:"
        for label in ${old_ip_labels}; do
            local label_num=$(echo "${label}" | grep -oE '[0-9]+')
            grep -E "^(LABEL_${label_num}|IPADDR_${label_num}|NETMASK_${label_num})=" "${ifcfg_file}" || true
        done
        return 0
    fi
    
    # Erstelle temporäre Datei ohne alte IPs
    local temp_file=$(mktemp)
    
    # Kopiere alle Zeilen außer LABEL_2+ und zugehörige IPADDR/NETMASK
    while IFS= read -r line; do
        local skip=false
        for label in ${old_ip_labels}; do
            local label_num=$(echo "${label}" | grep -oE '[0-9]+')
            if echo "${line}" | grep -qE "^(LABEL_${label_num}|IPADDR_${label_num}|NETMASK_${label_num})="; then
                skip=true
                info "Entferne: ${line}"
                break
            fi
        done
        
        if [[ "${skip}" == "false" ]]; then
            echo "${line}" >> "${temp_file}"
        fi
    done < "${ifcfg_file}"
    
    # Ersetze Original-Datei
    mv "${temp_file}" "${ifcfg_file}"
    chmod 644 "${ifcfg_file}"
    
    success "Alte IP-Adressen aus ${ifcfg_file} entfernt"
}

remove_old_gateway() {
    local interface=$1
    local routes_file="/etc/sysconfig/network/routes"
    
    print_header "Entferne altes Gateway"
    
    if [[ ! -f "${routes_file}" ]]; then
        warning "Routes-Datei nicht gefunden: ${routes_file}"
        return 1
    fi
    
    # Finde Zeilen mit metric 200 (altes Gateway)
    local old_gateway_lines=$(grep -n "metric 200" "${routes_file}" | cut -d: -f1 || true)
    
    if [[ -z "${old_gateway_lines}" ]]; then
        info "Kein altes Gateway (metric 200) gefunden"
        return 0
    fi
    
    info "Gefundene alte Gateway-Zeilen: ${old_gateway_lines}"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        info "[DRY-RUN] Würde folgende Zeilen entfernen:"
        grep "metric 200" "${routes_file}" || true
        return 0
    fi
    
    # Erstelle temporäre Datei ohne alte Gateway-Zeilen
    local temp_file=$(mktemp)
    grep -v "metric 200" "${routes_file}" > "${temp_file}" || true
    
    # Ersetze Original-Datei
    mv "${temp_file}" "${routes_file}"
    chmod 644 "${routes_file}"
    
    success "Altes Gateway aus ${routes_file} entfernt"
}

cleanup_hosts_file() {
    print_header "Bereinige /etc/hosts"
    
    if [[ ! -f /etc/hosts ]]; then
        warning "/etc/hosts nicht gefunden"
        return 1
    fi
    
    # Finde Zeilen mit alten IPs (9.155.64.x)
    local old_ip_lines=$(grep -n "9\.155\.64\." /etc/hosts | cut -d: -f1 || true)
    
    if [[ -z "${old_ip_lines}" ]]; then
        info "Keine alten IP-Einträge in /etc/hosts gefunden"
        return 0
    fi
    
    info "Gefundene alte IP-Zeilen in /etc/hosts: ${old_ip_lines}"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        info "[DRY-RUN] Würde folgende Zeilen entfernen:"
        grep "9\.155\.64\." /etc/hosts || true
        return 0
    fi
    
    # Erstelle temporäre Datei ohne alte IP-Zeilen
    local temp_file=$(mktemp)
    grep -v "9\.155\.64\." /etc/hosts > "${temp_file}" || true
    
    # Ersetze Original-Datei
    mv "${temp_file}" /etc/hosts
    chmod 644 /etc/hosts
    
    success "Alte IP-Einträge aus /etc/hosts entfernt"
}

reload_network() {
    local interface=$1
    
    print_header "Lade Netzwerk-Konfiguration neu"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        info "[DRY-RUN] Würde Netzwerk neu laden: wicked ifreload ${interface}"
        return 0
    fi
    
    info "Lade Interface ${interface} neu..."
    if wicked ifreload "${interface}"; then
        success "Netzwerk-Konfiguration erfolgreich neu geladen"
    else
        error "Fehler beim Neuladen der Netzwerk-Konfiguration"
        return 1
    fi
    
    sleep 2
    
    # Zeige aktuelle Konfiguration
    info "Aktuelle IP-Konfiguration:"
    ip addr show "${interface}" | grep -E "inet " || true
    
    info "Aktuelle Routing-Tabelle:"
    ip route show | grep default || true
}

show_summary() {
    print_header "Zusammenfassung"
    
    local interface=$(find_primary_interface)
    
    echo -e "${GREEN}✓ Cleanup abgeschlossen${NC}\n"
    
    echo -e "${BLUE}Aktuelle Konfiguration:${NC}"
    echo -e "  Interface: ${interface}"
    echo -e "  IP-Adressen:"
    ip addr show "${interface}" | grep -E "inet " | awk '{print "    - " $2}' || true
    
    echo -e "\n  Default Gateways:"
    ip route show | grep default | awk '{print "    - " $3 " (metric " $7 ")"}' || true
    
    echo -e "\n${BLUE}Log-Datei:${NC} ${LOG_FILE}"
    
    if [[ -f "${SCRIPT_DIR}/.last_cleanup_backup" ]]; then
        local backup_dir=$(cat "${SCRIPT_DIR}/.last_cleanup_backup")
        echo -e "${BLUE}Backup:${NC} ${backup_dir}"
    fi
}

################################################################################
# Hauptprogramm
################################################################################

main() {
    # Parse Argumente
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --keep-gateway)
                KEEP_GATEWAY=true
                shift
                ;;
            -h|--help)
                echo "Verwendung: $0 [--dry-run] [--keep-gateway]"
                echo ""
                echo "Optionen:"
                echo "  --dry-run       Zeigt nur an, was gemacht würde"
                echo "  --keep-gateway  Behält das alte Gateway als Backup"
                echo "  -h, --help      Zeigt diese Hilfe an"
                exit 0
                ;;
            *)
                error "Unbekannte Option: $1"
                exit 1
                ;;
        esac
    done
    
    print_header "SLES Network Configuration Cleanup"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        warning "DRY-RUN Modus aktiviert - keine Änderungen werden vorgenommen"
    fi
    
    if [[ "${KEEP_GATEWAY}" == "true" ]]; then
        info "Altes Gateway wird beibehalten"
    fi
    
    # Root-Check
    check_root
    
    # Finde primäres Interface
    local interface=$(find_primary_interface)
    info "Primäres Interface: ${interface}"
    
    # Erstelle Backup
    backup_config
    
    # Entferne alte IP
    remove_old_ip "${interface}"
    
    # Entferne altes Gateway (optional)
    if [[ "${KEEP_GATEWAY}" == "false" ]]; then
        remove_old_gateway "${interface}"
    else
        info "Überspringe Gateway-Entfernung (--keep-gateway)"
    fi
    
    # Bereinige /etc/hosts
    cleanup_hosts_file
    
    # Lade Netzwerk neu
    reload_network "${interface}"
    
    # Zeige Zusammenfassung
    show_summary
    
    success "Cleanup erfolgreich abgeschlossen!"
}

# Führe Hauptprogramm aus
main "$@"

# Made with Bob

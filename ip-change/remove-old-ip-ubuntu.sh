#!/bin/bash

#==============================================================================
# Script zum Entfernen alter IP-Adressen aus Ubuntu Netplan-Konfiguration
#==============================================================================
# Dieses Script entfernt eine spezifische alte IP-Adresse aus der
# Netplan-Konfiguration und wendet die Änderungen sicher an.
#
# Verwendung:
#   ./remove-old-ip-ubuntu.sh <alte-ip>
#   ./remove-old-ip-ubuntu.sh 9.155.64.146
#
# Ohne Parameter werden alle gefundenen alten IPs angezeigt
#==============================================================================

set -euo pipefail

# Farben
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Konfiguration
readonly NETPLAN_DIR="/etc/netplan"
readonly BACKUP_DIR="/tmp/netplan_backup_$(date +%s)"

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
Verwendung: $(basename "$0") [OPTIONEN] <IP-ADRESSE>

Entfernt eine alte IP-Adresse aus der Ubuntu Netplan-Konfiguration.

OPTIONEN:
    -l, --list      Zeigt alle konfigurierten IP-Adressen an
    -a, --all       Zeigt alle Netplan-Konfigurationsdateien an
    -h, --help      Diese Hilfe anzeigen

BEISPIELE:
    # Alte IP entfernen
    $(basename "$0") 9.155.64.146

    # Alle IPs anzeigen
    $(basename "$0") --list

    # Alle Netplan-Dateien anzeigen
    $(basename "$0") --all

EOF
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Dieses Script muss als root ausgeführt werden"
        log_info "Versuchen Sie: sudo $0 $*"
        exit 1
    fi
}

list_current_ips() {
    log_info "Aktuell konfigurierte IP-Adressen:"
    echo ""
    
    ip -o addr show | grep -E 'inet ' | grep -v '127.0.0.1' | while read -r line; do
        interface=$(echo "$line" | awk '{print $2}')
        ip_addr=$(echo "$line" | awk '{print $4}')
        echo "  ${interface}: ${ip_addr}"
    done
    
    echo ""
    log_info "IP-Adressen in Netplan-Konfiguration:"
    echo ""
    
    if [[ -d "${NETPLAN_DIR}" ]]; then
        for file in "${NETPLAN_DIR}"/*.yaml; do
            if [[ -f "$file" ]]; then
                echo "Datei: $(basename "$file")"
                grep -E '^\s+- [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$file" | sed 's/^/  /' || echo "  Keine IPs gefunden"
                echo ""
            fi
        done
    fi
}

show_netplan_files() {
    log_info "Netplan-Konfigurationsdateien:"
    echo ""
    
    if [[ ! -d "${NETPLAN_DIR}" ]]; then
        log_error "Netplan-Verzeichnis nicht gefunden: ${NETPLAN_DIR}"
        exit 1
    fi
    
    for file in "${NETPLAN_DIR}"/*.yaml; do
        if [[ -f "$file" ]]; then
            echo "=========================================="
            echo "Datei: $file"
            echo "=========================================="
            cat "$file"
            echo ""
        fi
    done
}

create_backup() {
    log_info "Erstelle Backup der Netplan-Konfiguration..."
    
    mkdir -p "${BACKUP_DIR}"
    cp -r "${NETPLAN_DIR}"/* "${BACKUP_DIR}/" 2>/dev/null || true
    
    log_success "Backup erstellt: ${BACKUP_DIR}"
}

find_ip_in_netplan() {
    local ip_to_find="$1"
    local found=false
    
    for file in "${NETPLAN_DIR}"/*.yaml; do
        if [[ -f "$file" ]] && grep -q "$ip_to_find" "$file"; then
            echo "$file"
            found=true
        fi
    done
    
    if [[ "$found" == false ]]; then
        return 1
    fi
}

remove_ip_from_file() {
    local file="$1"
    local ip_to_remove="$2"
    
    log_info "Entferne IP ${ip_to_remove} aus $(basename "$file")..."
    
    # Zeige aktuelle Konfiguration
    echo ""
    log_info "Aktuelle Konfiguration:"
    cat "$file"
    echo ""
    
    # Erstelle temporäre Datei
    local temp_file=$(mktemp)
    
    # Escape IP für regex (ersetze . mit \.)
    local escaped_ip="${ip_to_remove//./\\.}"
    
    # Entferne die Zeile mit der IP
    sed -E "/[[:space:]]*-?[[:space:]]*['\"]?${escaped_ip}(\/[0-9]+)?['\"]?[[:space:]]*(#.*)?$/d" "$file" > "$temp_file"
    
    # Prüfe ob sich etwas geändert hat
    if diff -q "$file" "$temp_file" > /dev/null; then
        log_warning "IP ${ip_to_remove} wurde nicht in der Datei gefunden"
        log_info "Versuche alternative Suchmuster..."
        
        # Versuche flexibleres Muster
        grep -v "${ip_to_remove}" "$file" > "$temp_file"
        
        if diff -q "$file" "$temp_file" > /dev/null; then
            log_error "IP konnte mit keinem Muster gefunden werden"
            rm "$temp_file"
            return 1
        fi
    fi
    
    # Prüfe ob addresses: leer ist und bereinige YAML-Struktur
    local temp_file2=$(mktemp)
    awk '
    BEGIN { in_addresses = 0; addresses_line = 0 }
    /^[[:space:]]*addresses:[[:space:]]*$/ {
        in_addresses = 1
        addresses_line = NR
        addresses_content = $0
        next
    }
    in_addresses && /^[[:space:]]*-/ {
        # Es gibt noch IPs, behalte addresses-Zeile
        if (addresses_line > 0) {
            print addresses_content
            addresses_line = 0
        }
        in_addresses = 0
        print
        next
    }
    in_addresses && /^[[:space:]]*[a-zA-Z]/ {
        # Nächster Abschnitt, keine IPs gefunden - lösche addresses-Zeile
        in_addresses = 0
        addresses_line = 0
        print
        next
    }
    in_addresses {
        # Leere Zeile oder Kommentar in addresses
        next
    }
    { print }
    ' "$temp_file" > "$temp_file2"
    
    mv "$temp_file2" "$temp_file"
    
    # Ersetze Original-Datei
    mv "$temp_file" "$file"
    
    log_success "IP ${ip_to_remove} wurde entfernt"
    
    # Zeige Änderungen
    echo ""
    log_info "Neue Konfiguration:"
    cat "$file"
    echo ""
}

validate_netplan() {
    log_info "Validiere Netplan-Konfiguration..."
    
    if netplan generate 2>&1; then
        log_success "Netplan-Konfiguration ist valide"
        return 0
    else
        log_error "Netplan-Konfiguration ist ungültig!"
        return 1
    fi
}

apply_netplan() {
    log_warning "Die Netzwerkverbindung wird kurz unterbrochen!"
    echo ""
    log_info "Verwende 'netplan try' mit 120 Sekunden Timeout..."
    log_info "Drücken Sie ENTER um die Änderungen zu bestätigen"
    log_info "oder warten Sie 120 Sekunden für automatischen Rollback"
    echo ""
    
    if netplan try --timeout 120; then
        log_success "Netplan-Konfiguration erfolgreich angewendet"
        return 0
    else
        log_error "Fehler beim Anwenden der Netplan-Konfiguration"
        log_info "Die alte Konfiguration wurde automatisch wiederhergestellt"
        return 1
    fi
}

restore_backup() {
    log_warning "Stelle Backup wieder her..."
    
    if [[ -d "${BACKUP_DIR}" ]]; then
        cp -r "${BACKUP_DIR}"/* "${NETPLAN_DIR}/"
        log_success "Backup wiederhergestellt"
        netplan apply
    else
        log_error "Backup-Verzeichnis nicht gefunden: ${BACKUP_DIR}"
    fi
}

remove_ip() {
    local ip_to_remove="$1"
    
    log_info "Suche IP-Adresse: ${ip_to_remove}"
    echo ""
    
    # Prüfe ob IP aktuell konfiguriert ist
    if ip addr show | grep -q "${ip_to_remove}"; then
        log_info "IP ${ip_to_remove} ist aktuell auf dem System konfiguriert"
    else
        log_warning "IP ${ip_to_remove} ist NICHT auf dem System konfiguriert"
    fi
    
    # Suche IP in Netplan-Dateien
    local files=$(find_ip_in_netplan "$ip_to_remove")
    
    if [[ -z "$files" ]]; then
        log_error "IP ${ip_to_remove} wurde in keiner Netplan-Datei gefunden"
        echo ""
        log_info "Möchten Sie die IP trotzdem vom System entfernen? (j/N)"
        read -r response
        if [[ "$response" =~ ^[JjYy]$ ]]; then
            # Finde Interface mit dieser IP
            local interface=$(ip -o addr show | grep "${ip_to_remove}" | awk '{print $2}')
            if [[ -n "$interface" ]]; then
                log_info "Entferne IP ${ip_to_remove} von Interface ${interface}..."
                ip addr del "${ip_to_remove}/25" dev "${interface}" 2>/dev/null || \
                ip addr del "${ip_to_remove}/24" dev "${interface}" 2>/dev/null || \
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
    read -p "Möchten Sie die IP ${ip_to_remove} entfernen? (j/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[JjYy]$ ]]; then
        log_info "Abgebrochen"
        exit 0
    fi
    
    # Backup erstellen
    create_backup
    
    # IP aus allen Dateien entfernen
    echo "$files" | while read -r file; do
        remove_ip_from_file "$file" "$ip_to_remove"
    done
    
    # Validieren
    if ! validate_netplan; then
        log_error "Validierung fehlgeschlagen!"
        restore_backup
        exit 1
    fi
    
    # Anwenden
    if apply_netplan; then
        log_success "IP ${ip_to_remove} wurde erfolgreich entfernt!"
        echo ""
        log_info "Aktuelle IP-Adressen:"
        ip -o addr show | grep -E 'inet ' | grep -v '127.0.0.1' | awk '{print "  " $2 ": " $4}'
        echo ""
        log_info "Backup gespeichert in: ${BACKUP_DIR}"
    else
        log_error "Fehler beim Anwenden der Konfiguration"
        restore_backup
        exit 1
    fi
}

# Hauptprogramm
main() {
    case "${1:-}" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -l|--list)
            list_current_ips
            exit 0
            ;;
        -a|--all)
            show_netplan_files
            exit 0
            ;;
        "")
            log_error "Keine IP-Adresse angegeben"
            echo ""
            show_usage
            echo ""
            list_current_ips
            exit 1
            ;;
        *)
            check_root
            remove_ip "$1"
            ;;
    esac
}

main "$@"

# Made with Bob

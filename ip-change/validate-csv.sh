#!/bin/bash

#==============================================================================
# CSV Validierungs-Script
#==============================================================================
# Prüft die ip-change.csv Datei auf Fehler und Inkonsistenzen
#
# Verwendung:
#   ./validate-csv.sh [csv-datei]
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
readonly CSV_FILE="${1:-${SCRIPT_DIR}/ip-change.csv}"

ERRORS=0
WARNINGS=0

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
    ((WARNINGS++))
}

log_error() {
    echo -e "${RED}✗${NC} $*"
    ((ERRORS++))
}

echo "=============================================="
echo "CSV Validierung"
echo "=============================================="
echo ""

# Prüfe ob Datei existiert
if [[ ! -f "${CSV_FILE}" ]]; then
    log_error "CSV-Datei nicht gefunden: ${CSV_FILE}"
    exit 1
fi

log_info "Prüfe Datei: ${CSV_FILE}"
echo ""

# Prüfe Dateiformat
log_info "Prüfe Dateiformat..."

# Entferne BOM und Windows-Zeilenenden
CSV_CONTENT=$(sed 's/^\xEF\xBB\xBF//; s/\r$//' "${CSV_FILE}")

# Prüfe Header
HEADER=$(echo "${CSV_CONTENT}" | head -1)
EXPECTED_HEADER="Hostname-alt;Hostname-neu;Ip-alt;ip-neu;10-alt;10-neu"

if [[ "${HEADER}" != "${EXPECTED_HEADER}" ]]; then
    log_error "Ungültiger Header!"
    echo "  Erwartet: ${EXPECTED_HEADER}"
    echo "  Gefunden: ${HEADER}"
else
    log_success "Header korrekt"
fi

# Zähle Zeilen
TOTAL_LINES=$(echo "${CSV_CONTENT}" | wc -l | tr -d ' ')
DATA_LINES=$((TOTAL_LINES - 1))

log_info "Gefunden: ${DATA_LINES} Datenzeilen"
echo ""

# Prüfe jede Zeile
log_info "Prüfe Datenzeilen..."
echo ""

LINE_NUM=1
while IFS=';' read -r hostname_alt hostname_neu ip_alt ip_neu ip10_alt ip10_neu; do
    # Überspringe Header
    if [[ ${LINE_NUM} -eq 1 ]]; then
        ((LINE_NUM++))
        continue
    fi
    
    echo "Zeile ${LINE_NUM}: ${hostname_alt}"
    
    # Entferne Leerzeichen
    hostname_alt=$(echo "${hostname_alt}" | xargs)
    hostname_neu=$(echo "${hostname_neu}" | xargs)
    ip_alt=$(echo "${ip_alt}" | xargs)
    ip_neu=$(echo "${ip_neu}" | xargs)
    ip10_alt=$(echo "${ip10_alt}" | xargs)
    ip10_neu=$(echo "${ip10_neu}" | xargs)
    
    # Prüfe auf leere Felder
    if [[ -z "${hostname_alt}" ]] || [[ -z "${hostname_neu}" ]] || \
       [[ -z "${ip_alt}" ]] || [[ -z "${ip_neu}" ]] || \
       [[ -z "${ip10_alt}" ]] || [[ -z "${ip10_neu}" ]]; then
        log_error "  Leere Felder gefunden"
    fi
    
    # Prüfe Hostname-Format
    if [[ ! "${hostname_alt}" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        log_error "  Ungültiger Hostname-alt: ${hostname_alt}"
    fi
    
    if [[ ! "${hostname_neu}" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        log_error "  Ungültiger Hostname-neu: ${hostname_neu}"
    fi
    
    # Prüfe IP-Format (9.x)
    if [[ ! "${ip_alt}" =~ ^9\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        log_error "  Ungültige IP-alt (muss mit 9. beginnen): ${ip_alt}"
    fi
    
    if [[ ! "${ip_neu}" =~ ^9\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        log_error "  Ungültige ip-neu (muss mit 9. beginnen): ${ip_neu}"
    fi
    
    # Prüfe IP-Format (10.x)
    if [[ ! "${ip10_alt}" =~ ^10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        log_error "  Ungültige 10-alt (muss mit 10. beginnen): ${ip10_alt}"
    fi
    
    if [[ ! "${ip10_neu}" =~ ^10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        log_error "  Ungültige 10-neu (muss mit 10. beginnen): ${ip10_neu}"
    fi
    
    # Prüfe ob neue IP im richtigen Subnetz ist (9.125.190.x)
    if [[ ! "${ip_neu}" =~ ^9\.125\.190\.[0-9]{1,3}$ ]]; then
        log_warning "  ip-neu nicht im erwarteten Subnetz 9.125.190.x: ${ip_neu}"
    fi
    
    # Prüfe ob 10.x IPs im gleichen Subnetz bleiben
    ip10_alt_subnet=$(echo "${ip10_alt}" | cut -d. -f1-3)
    ip10_neu_subnet=$(echo "${ip10_neu}" | cut -d. -f1-3)
    
    if [[ "${ip10_alt_subnet}" != "${ip10_neu_subnet}" ]]; then
        log_warning "  10.x Subnetz ändert sich: ${ip10_alt_subnet} -> ${ip10_neu_subnet}"
    fi
    
    # Prüfe auf Duplikate (neue IPs)
    if grep -q "${ip_neu}" <<< "${SEEN_IPS_9X:-}"; then
        log_error "  Doppelte ip-neu gefunden: ${ip_neu}"
    fi
    SEEN_IPS_9X="${SEEN_IPS_9X:-}${ip_neu}\n"
    
    if grep -q "${ip10_neu}" <<< "${SEEN_IPS_10X:-}"; then
        log_error "  Doppelte 10-neu gefunden: ${ip10_neu}"
    fi
    SEEN_IPS_10X="${SEEN_IPS_10X:-}${ip10_neu}\n"
    
    if grep -q "${hostname_neu}" <<< "${SEEN_HOSTNAMES:-}"; then
        log_error "  Doppelter Hostname-neu gefunden: ${hostname_neu}"
    fi
    SEEN_HOSTNAMES="${SEEN_HOSTNAMES:-}${hostname_neu}\n"
    
    if [[ ${ERRORS} -eq 0 ]] && [[ ${WARNINGS} -eq 0 ]]; then
        log_success "  OK"
    fi
    
    echo ""
    ((LINE_NUM++))
done < <(echo "${CSV_CONTENT}")

# Zusammenfassung
echo "=============================================="
echo "Zusammenfassung"
echo "=============================================="
echo ""
echo "Geprüfte Zeilen: ${DATA_LINES}"
echo "Fehler: ${ERRORS}"
echo "Warnungen: ${WARNINGS}"
echo ""

if [[ ${ERRORS} -eq 0 ]] && [[ ${WARNINGS} -eq 0 ]]; then
    log_success "CSV-Datei ist valide!"
    exit 0
elif [[ ${ERRORS} -eq 0 ]]; then
    log_warning "CSV-Datei ist valide, aber es gibt Warnungen"
    exit 0
else
    log_error "CSV-Datei enthält Fehler!"
    exit 1
fi

# Made with Bob

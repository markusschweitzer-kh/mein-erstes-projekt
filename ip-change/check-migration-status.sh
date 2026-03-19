#!/bin/bash
#==============================================================================
# IP-Migrations-Status-Checker
#==============================================================================
# Beschreibung: Prüft alle Hosts aus CSV auf Migrations-Status
# Autor: System Administration
# Datum: 2026-03-19
#
# Verwendung: ./check-migration-status.sh [csv-datei]
# Beispiel: ./check-migration-status.sh ip-change.csv
#==============================================================================

set -eo pipefail

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# CSV-Datei
CSV_FILE="${1:-ip-change.csv}"

# Timeout für SSH/Ping
TIMEOUT=3

# Ergebnis-Arrays
declare -a HOSTS_OK
declare -a HOSTS_PARTIAL
declare -a HOSTS_FAILED
declare -a HOSTS_UNREACHABLE

#==============================================================================
# FUNKTIONEN
#==============================================================================

print_header() {
    echo ""
    echo "================================================================================"
    echo -e "${CYAN}$1${NC}"
    echo "================================================================================"
}

print_section() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

check_host() {
    local hostname_alt="$1"
    local hostname_neu="$2"
    local ip_alt="$3"
    local ip_neu="$4"
    local ip_10_alt="$5"
    local ip_10_neu="$6"
    
    local status_9x="UNKNOWN"
    local status_10x="UNKNOWN"
    local status_hostname="UNKNOWN"
    local reachable_ip=""
    
    # Prüfe welche IP erreichbar ist
    if ping -c 1 -W "$TIMEOUT" "$ip_alt" >/dev/null 2>&1; then
        reachable_ip="$ip_alt"
        status_9x="ALT"
    elif ping -c 1 -W "$TIMEOUT" "$ip_neu" >/dev/null 2>&1; then
        reachable_ip="$ip_neu"
        status_9x="NEU"
    fi
    
    # Wenn keine IP erreichbar, als UNREACHABLE markieren
    if [ -z "$reachable_ip" ]; then
        echo -e "${RED}✗${NC} ${hostname_alt} - NICHT ERREICHBAR (${ip_alt} / ${ip_neu})"
        HOSTS_UNREACHABLE+=("$hostname_alt|$ip_alt|$ip_neu|UNREACHABLE|UNREACHABLE|UNREACHABLE")
        return 0
    fi
    
    # Prüfe 10.x IP
    if ping -c 1 -W "$TIMEOUT" "$ip_10_alt" >/dev/null 2>&1; then
        status_10x="ALT"
    elif ping -c 1 -W "$TIMEOUT" "$ip_10_neu" >/dev/null 2>&1; then
        status_10x="NEU"
    else
        status_10x="KEINE"
    fi
    
    # Prüfe Hostname (wenn SSH verfügbar)
    if command -v ssh >/dev/null 2>&1; then
        current_hostname=$(ssh -o ConnectTimeout="$TIMEOUT" -o StrictHostKeyChecking=no "$reachable_ip" "hostname -f" 2>/dev/null || echo "")
        if [ -n "$current_hostname" ]; then
            if [ "$current_hostname" = "$hostname_neu" ]; then
                status_hostname="NEU"
            elif [ "$current_hostname" = "$hostname_alt" ]; then
                status_hostname="ALT"
            else
                status_hostname="UNKNOWN"
            fi
        fi
    fi
    
    # Bewerte Gesamt-Status
    local overall_status="UNKNOWN"
    local symbol=""
    local color=""
    
    if [ "$status_9x" = "NEU" ] && [ "$status_10x" = "NEU" ] && [ "$status_hostname" = "NEU" ]; then
        overall_status="OK"
        symbol="✓"
        color="$GREEN"
        HOSTS_OK+=("$hostname_neu|$ip_neu|$ip_10_neu|$status_9x|$status_10x|$status_hostname")
    elif [ "$status_9x" = "ALT" ] && [ "$status_10x" = "ALT" ] && [ "$status_hostname" = "ALT" ]; then
        overall_status="NICHT MIGRIERT"
        symbol="○"
        color="$YELLOW"
        HOSTS_FAILED+=("$hostname_alt|$ip_alt|$ip_10_alt|$status_9x|$status_10x|$status_hostname")
    else
        overall_status="TEILWEISE"
        symbol="◐"
        color="$MAGENTA"
        HOSTS_PARTIAL+=("$hostname_alt/$hostname_neu|$reachable_ip|$ip_10_alt/$ip_10_neu|$status_9x|$status_10x|$status_hostname")
    fi
    
    # Ausgabe
    echo -e "${color}${symbol}${NC} ${hostname_alt} → ${hostname_neu}"
    echo "    9.x IP: ${ip_alt} → ${ip_neu} [${status_9x}]"
    echo "    10.x IP: ${ip_10_alt} → ${ip_10_neu} [${status_10x}]"
    echo "    Hostname: [${status_hostname}]"
    echo "    Status: ${overall_status}"
}

#==============================================================================
# HAUPTPROGRAMM
#==============================================================================

print_header "IP-Migrations-Status-Checker"

# Prüfe ob CSV existiert
if [ ! -f "$CSV_FILE" ]; then
    echo -e "${RED}FEHLER:${NC} CSV-Datei nicht gefunden: $CSV_FILE"
    exit 1
fi

echo "CSV-Datei: $CSV_FILE"
echo "Timeout: ${TIMEOUT}s"
echo ""

# Lese CSV und prüfe jeden Host
print_section "Prüfe Hosts"

# Zähler für Fortschritt
host_counter=0

# Überspringe Header-Zeile und verwende process substitution statt pipe
while IFS=';' read -r hostname_alt hostname_neu ip_alt ip_neu ip_10_alt ip_10_neu; do
    # Entferne Whitespace
    hostname_alt=$(echo "$hostname_alt" | tr -d '[:space:]')
    hostname_neu=$(echo "$hostname_neu" | tr -d '[:space:]')
    ip_alt=$(echo "$ip_alt" | tr -d '[:space:]')
    ip_neu=$(echo "$ip_neu" | tr -d '[:space:]')
    ip_10_alt=$(echo "$ip_10_alt" | tr -d '[:space:]')
    ip_10_neu=$(echo "$ip_10_neu" | tr -d '[:space:]')
    
    # Überspringe leere Zeilen
    if [ -z "$hostname_alt" ]; then
        continue
    fi
    
    host_counter=$((host_counter + 1))
    echo -e "${CYAN}[$host_counter/16]${NC}"
    
    # Prüfe Host (mit error handling)
    if ! check_host "$hostname_alt" "$hostname_neu" "$ip_alt" "$ip_neu" "$ip_10_alt" "$ip_10_neu"; then
        echo -e "${RED}Fehler bei Host $hostname_alt${NC}"
    fi
    echo ""
done < <(tail -n +2 "$CSV_FILE")

#==============================================================================
# ZUSAMMENFASSUNG
#==============================================================================

print_header "ZUSAMMENFASSUNG"

total_hosts=$(tail -n +2 "$CSV_FILE" | grep -v '^[[:space:]]*$' | wc -l)
ok_count=${#HOSTS_OK[@]}
partial_count=${#HOSTS_PARTIAL[@]}
failed_count=${#HOSTS_FAILED[@]}
unreachable_count=${#HOSTS_UNREACHABLE[@]}

echo ""
echo "Gesamt: $total_hosts Hosts"
echo ""
echo -e "${GREEN}✓ Vollständig migriert:${NC} $ok_count"
echo -e "${MAGENTA}◐ Teilweise migriert:${NC} $partial_count"
echo -e "${YELLOW}○ Nicht migriert:${NC} $failed_count"
echo -e "${RED}✗ Nicht erreichbar:${NC} $unreachable_count"
echo ""

# Details für vollständig migrierte Hosts
if [ $ok_count -gt 0 ]; then
    print_section "Vollständig migrierte Hosts ($ok_count)"
    for host in "${HOSTS_OK[@]}"; do
        IFS='|' read -r hostname ip_9x ip_10x status_9x status_10x status_hostname <<< "$host"
        echo -e "${GREEN}✓${NC} $hostname"
        echo "    9.x: $ip_9x"
        echo "    10.x: $ip_10x"
    done
    echo ""
fi

# Details für teilweise migrierte Hosts
if [ $partial_count -gt 0 ]; then
    print_section "Teilweise migrierte Hosts ($partial_count) - AKTION ERFORDERLICH"
    for host in "${HOSTS_PARTIAL[@]}"; do
        IFS='|' read -r hostname ip_9x ip_10x status_9x status_10x status_hostname <<< "$host"
        echo -e "${MAGENTA}◐${NC} $hostname"
        echo "    9.x IP: $status_9x"
        echo "    10.x IP: $status_10x"
        echo "    Hostname: $status_hostname"
        echo "    → Bitte Migration vervollständigen!"
    done
    echo ""
fi

# Details für nicht migrierte Hosts
if [ $failed_count -gt 0 ]; then
    print_section "Nicht migrierte Hosts ($failed_count) - MIGRATION ERFORDERLICH"
    for host in "${HOSTS_FAILED[@]}"; do
        IFS='|' read -r hostname ip_9x ip_10x status_9x status_10x status_hostname <<< "$host"
        echo -e "${YELLOW}○${NC} $hostname"
        echo "    9.x: $ip_9x"
        echo "    10.x: $ip_10x"
        echo "    → Migration noch nicht gestartet"
    done
    echo ""
fi

# Details für nicht erreichbare Hosts
if [ $unreachable_count -gt 0 ]; then
    print_section "Nicht erreichbare Hosts ($unreachable_count) - PRÜFUNG ERFORDERLICH"
    for host in "${HOSTS_UNREACHABLE[@]}"; do
        IFS='|' read -r hostname ip_alt ip_neu status_9x status_10x status_hostname <<< "$host"
        echo -e "${RED}✗${NC} $hostname"
        echo "    Alte IP: $ip_alt"
        echo "    Neue IP: $ip_neu"
        echo "    → Host ist nicht erreichbar!"
    done
    echo ""
fi

#==============================================================================
# EMPFEHLUNGEN
#==============================================================================

if [ $partial_count -gt 0 ] || [ $failed_count -gt 0 ]; then
    print_section "EMPFOHLENE AKTIONEN"
    
    if [ $partial_count -gt 0 ]; then
        echo -e "${MAGENTA}Teilweise migrierte Hosts:${NC}"
        echo "  1. Prüfe welche Komponente fehlt (9.x IP, 10.x IP, oder Hostname)"
        echo "  2. Verwende fix-9x-ip-manual.sh für 9.x IP-Probleme"
        echo "  3. Verwende change-10x-ip.sh für 10.x IP-Probleme"
        echo "  4. Führe network-update-rhel-v3.yml erneut aus"
        echo ""
    fi
    
    if [ $failed_count -gt 0 ]; then
        echo -e "${YELLOW}Nicht migrierte Hosts:${NC}"
        echo "  1. Führe network-update-rhel-v3.yml aus"
        echo "  2. Oder verwende manuelle Scripts"
        echo ""
    fi
    
    if [ $unreachable_count -gt 0 ]; then
        echo -e "${RED}Nicht erreichbare Hosts:${NC}"
        echo "  1. Prüfe ob Hosts online sind"
        echo "  2. Prüfe Netzwerk-Konnektivität"
        echo "  3. Prüfe Firewall-Regeln"
        echo ""
    fi
fi

#==============================================================================
# ABSCHLUSS
#==============================================================================

print_header "PRÜFUNG ABGESCHLOSSEN"

if [ $ok_count -eq "$total_hosts" ]; then
    echo -e "${GREEN}✓ Alle Hosts erfolgreich migriert!${NC}"
    exit 0
elif [ $partial_count -gt 0 ] || [ $failed_count -gt 0 ]; then
    echo -e "${YELLOW}⚠ Migration unvollständig - Aktion erforderlich${NC}"
    exit 1
else
    echo -e "${RED}✗ Kritische Probleme gefunden${NC}"
    exit 2
fi

# Made with Bob

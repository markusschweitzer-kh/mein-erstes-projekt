#!/bin/bash
#==============================================================================
# SLES Pre-Migration Check Script
#==============================================================================
# Prüft die Netzwerk-Konfiguration VOR der IP-Migration
# und testet ob die neue IP funktionieren wird
#
# Verwendung:
#   sudo ./pre-migration-check-sles.sh <neue-ip> <neues-gateway>
#
# Beispiel:
#   sudo ./pre-migration-check-sles.sh 9.125.190.41 9.125.190.1
#==============================================================================

set -euo pipefail

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# Prüfe Root
if [[ $EUID -ne 0 ]]; then
   log_error "Dieses Script muss als root ausgeführt werden!"
   exit 1
fi

# Prüfe Argumente
if [[ $# -lt 2 ]]; then
    echo "Verwendung: $0 <neue-ip> <neues-gateway>"
    echo "Beispiel: $0 9.125.190.41 9.125.190.1"
    exit 1
fi

NEW_IP="$1"
NEW_GATEWAY="$2"
NEW_PREFIX="25"
INTERFACE="eth0"
TEST_FAILED=0

echo "========================================"
echo "SLES Pre-Migration Check"
echo "========================================"
echo ""
log_info "Neue IP: $NEW_IP/$NEW_PREFIX"
log_info "Neues Gateway: $NEW_GATEWAY"
log_info "Interface: $INTERFACE"
echo ""

#==============================================================================
# 1. Aktuelle Konfiguration dokumentieren
#==============================================================================

log_info "1. Dokumentiere aktuelle Konfiguration..."
echo ""

BACKUP_FILE="/tmp/pre-migration-backup-$(date +%s).txt"

cat > "$BACKUP_FILE" << EOF
=== Pre-Migration Backup $(date) ===

=== IP-Adressen ===
$(ip addr show $INTERFACE)

=== Routing ===
$(ip route show)

=== routes-Datei ===
$(cat /etc/sysconfig/network/routes 2>/dev/null || echo "Nicht vorhanden")

=== ifcfg-Datei ===
$(cat /etc/sysconfig/network/ifcfg-$INTERFACE 2>/dev/null || echo "Nicht vorhanden")

=== SSH-Listening ===
$(ss -tlnp | grep sshd)

=== Firewall ===
$(firewall-cmd --list-all 2>/dev/null || echo "Firewall nicht aktiv")

=== rp_filter ===
all: $(sysctl -n net.ipv4.conf.all.rp_filter)
$INTERFACE: $(sysctl -n net.ipv4.conf.$INTERFACE.rp_filter)
EOF

log_success "Backup erstellt: $BACKUP_FILE"
echo ""

#==============================================================================
# 2. Prüfe aktuelle Netzwerk-Konfiguration
#==============================================================================

log_info "2. Prüfe aktuelle Netzwerk-Konfiguration..."
echo ""

# Aktuelles Gateway
CURRENT_GATEWAY=$(ip route show | grep default | awk '{print $3}' | head -n 1)
log_info "Aktuelles Gateway: $CURRENT_GATEWAY"

# Gateway erreichbar?
if ping -c 3 -W 2 "$CURRENT_GATEWAY" &> /dev/null; then
    log_success "Aktuelles Gateway ist erreichbar"
else
    log_error "Aktuelles Gateway ist NICHT erreichbar!"
    TEST_FAILED=1
fi

# SSH läuft?
if systemctl is-active --quiet sshd; then
    log_success "SSH-Dienst läuft"
else
    log_error "SSH-Dienst läuft NICHT!"
    TEST_FAILED=1
fi

# SSH hört auf allen IPs?
if ss -tlnp | grep sshd | grep -q "0.0.0.0:22\|*:22"; then
    log_success "SSH hört auf allen Interfaces"
else
    log_warning "SSH hört möglicherweise nur auf spezifischen IPs"
fi

echo ""

#==============================================================================
# 3. Prüfe rp_filter
#==============================================================================

log_info "3. Prüfe Reverse Path Filtering (rp_filter)..."
echo ""

RP_FILTER_ALL=$(sysctl -n net.ipv4.conf.all.rp_filter)
RP_FILTER_IF=$(sysctl -n net.ipv4.conf.$INTERFACE.rp_filter)

log_info "rp_filter all: $RP_FILTER_ALL"
log_info "rp_filter $INTERFACE: $RP_FILTER_IF"

if [[ "$RP_FILTER_ALL" == "1" ]] || [[ "$RP_FILTER_IF" == "1" ]]; then
    log_warning "rp_filter ist auf 1 (strict) - kann Probleme mit mehreren IPs verursachen"
    log_info "Empfehlung: Setze auf 2 (loose)"
    
    read -p "Möchten Sie rp_filter auf 2 setzen? (j/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[JjYy]$ ]]; then
        sysctl -w net.ipv4.conf.all.rp_filter=2
        sysctl -w net.ipv4.conf.$INTERFACE.rp_filter=2
        log_success "rp_filter auf 2 gesetzt"
        
        # Permanent machen
        if ! grep -q "net.ipv4.conf.all.rp_filter" /etc/sysctl.conf; then
            echo "net.ipv4.conf.all.rp_filter = 2" >> /etc/sysctl.conf
            echo "net.ipv4.conf.$INTERFACE.rp_filter = 2" >> /etc/sysctl.conf
            log_success "rp_filter permanent gesetzt"
        fi
    fi
else
    log_success "rp_filter ist korrekt konfiguriert"
fi

echo ""

#==============================================================================
# 4. Teste neues Gateway
#==============================================================================

log_info "4. Teste neues Gateway..."
echo ""

if ping -c 5 -W 2 "$NEW_GATEWAY" &> /dev/null; then
    log_success "Neues Gateway $NEW_GATEWAY ist erreichbar"
else
    log_error "Neues Gateway $NEW_GATEWAY ist NICHT erreichbar!"
    log_warning "Migration wird wahrscheinlich fehlschlagen!"
    TEST_FAILED=1
fi

echo ""

#==============================================================================
# 5. Teste neue IP temporär
#==============================================================================

log_info "5. Teste neue IP temporär..."
echo ""

log_warning "Füge neue IP temporär hinzu (wird nach Test wieder entfernt)"
echo ""

# Füge neue IP hinzu
if ip addr add "$NEW_IP/$NEW_PREFIX" dev "$INTERFACE" 2>/dev/null; then
    log_success "Neue IP temporär hinzugefügt"
    
    # Zeige IPs
    log_info "Aktuelle IPs auf $INTERFACE:"
    ip addr show "$INTERFACE" | grep "inet " | sed 's/^/  /'
    echo ""
    
    # Teste neue IP lokal
    log_info "Teste neue IP lokal..."
    if ping -c 3 -W 2 "$NEW_IP" &> /dev/null; then
        log_success "Neue IP antwortet lokal"
    else
        log_error "Neue IP antwortet NICHT lokal!"
        TEST_FAILED=1
    fi
    
    # Teste Gateway mit neuer IP
    log_info "Teste Gateway mit neuer IP als Source..."
    if ping -c 3 -W 2 -I "$NEW_IP" "$NEW_GATEWAY" &> /dev/null; then
        log_success "Gateway ist mit neuer IP erreichbar"
    else
        log_error "Gateway ist mit neuer IP NICHT erreichbar!"
        log_warning "Mögliche Ursachen: VLAN, Port Security, MAC-Filtering"
        TEST_FAILED=1
    fi
    
    # Gratuitous ARP senden
    log_info "Sende Gratuitous ARP..."
    if command -v arping &> /dev/null; then
        arping -c 3 -I "$INTERFACE" -s "$NEW_IP" "$NEW_GATEWAY" &> /dev/null || true
        log_success "Gratuitous ARP gesendet"
    else
        log_warning "arping nicht installiert - überspringe"
    fi
    
    echo ""
    log_info "Warte 5 Sekunden für Netzwerk-Stabilisierung..."
    sleep 5
    
    # Test von außen
    echo ""
    log_warning "WICHTIG: Testen Sie JETZT von Ihrem PC aus:"
    echo "  ping $NEW_IP"
    echo "  ssh user@$NEW_IP"
    echo ""
    read -p "Drücken Sie Enter wenn Test abgeschlossen ist..."
    
    # Entferne neue IP wieder
    log_info "Entferne temporäre IP..."
    ip addr del "$NEW_IP/$NEW_PREFIX" dev "$INTERFACE" 2>/dev/null || true
    log_success "Temporäre IP entfernt"
    
else
    log_error "Konnte neue IP nicht hinzufügen!"
    TEST_FAILED=1
fi

echo ""

#==============================================================================
# 6. Prüfe Firewall
#==============================================================================

log_info "6. Prüfe Firewall-Konfiguration..."
echo ""

if systemctl is-active --quiet firewalld; then
    log_info "Firewall ist aktiv"
    
    # SSH erlaubt?
    if firewall-cmd --list-services | grep -q ssh; then
        log_success "SSH ist in Firewall erlaubt"
    else
        log_error "SSH ist NICHT in Firewall erlaubt!"
        TEST_FAILED=1
    fi
    
    # ICMP erlaubt?
    if firewall-cmd --list-protocols | grep -q icmp; then
        log_success "ICMP ist in Firewall erlaubt"
    else
        log_warning "ICMP ist nicht explizit erlaubt"
        log_info "Empfehlung: firewall-cmd --permanent --add-protocol=icmp"
    fi
else
    log_info "Firewall ist nicht aktiv"
fi

echo ""

#==============================================================================
# 7. Zusammenfassung
#==============================================================================

echo "========================================"
echo "ZUSAMMENFASSUNG"
echo "========================================"
echo ""

if [[ $TEST_FAILED -eq 0 ]]; then
    log_success "Alle Tests bestanden!"
    log_success "Migration kann durchgeführt werden"
    echo ""
    log_info "Nächste Schritte:"
    echo "  1. Backup erstellt: $BACKUP_FILE"
    echo "  2. Führen Sie Migration aus:"
    echo "     ansible-playbook -i localhost, -c local network-update-sles.yml"
else
    log_error "Einige Tests sind fehlgeschlagen!"
    log_warning "Migration wird wahrscheinlich Probleme verursachen"
    echo ""
    log_info "Beheben Sie folgende Probleme:"
    echo "  - Gateway-Erreichbarkeit prüfen"
    echo "  - ESX/vSwitch-Konfiguration prüfen"
    echo "  - VLAN-Konfiguration prüfen"
    echo "  - Firewall-Regeln prüfen"
fi

echo ""
log_info "Backup-Datei: $BACKUP_FILE"
echo ""

# Made with Bob

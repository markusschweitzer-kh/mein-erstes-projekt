#!/bin/bash
#==============================================================================
# SLES SSH-Diagnose und Fix Script
#==============================================================================
# Dieses Script diagnostiziert und behebt SSH-Probleme nach IP-Änderungen
#
# Verwendung:
#   sudo ./diagnose-ssh-sles.sh
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

echo "========================================"
echo "SLES SSH-Diagnose nach IP-Änderung"
echo "========================================"
echo ""

# 1. Prüfe IP-Adressen
log_info "1. Aktuelle IP-Adressen:"
ip -o addr show | grep -E 'inet ' | grep -v '127.0.0.1' | awk '{print "   " $2 ": " $4}'
echo ""

# 2. Prüfe SSH-Dienst
log_info "2. SSH-Dienst Status:"
if systemctl is-active --quiet sshd; then
    log_success "SSH-Dienst läuft"
else
    log_error "SSH-Dienst läuft NICHT!"
    log_info "Starte SSH-Dienst..."
    systemctl start sshd
fi
echo ""

# 3. Prüfe SSH-Konfiguration
log_info "3. SSH-Konfiguration:"
if grep -q "^ListenAddress" /etc/ssh/sshd_config; then
    log_warning "ListenAddress ist konfiguriert:"
    grep "^ListenAddress" /etc/ssh/sshd_config | sed 's/^/   /'
    echo ""
    log_warning "Dies könnte das Problem sein!"
    log_info "SSH hört nur auf spezifischen IPs. Möchten Sie dies ändern? (j/N)"
    read -r response
    if [[ "$response" =~ ^[JjYy]$ ]]; then
        log_info "Kommentiere ListenAddress aus..."
        sed -i 's/^ListenAddress/#ListenAddress/' /etc/ssh/sshd_config
        log_info "Starte SSH neu..."
        systemctl restart sshd
        log_success "SSH-Konfiguration aktualisiert"
    fi
else
    log_success "Keine spezifische ListenAddress konfiguriert (gut)"
fi
echo ""

# 4. Prüfe SSH-Port
log_info "4. SSH-Port:"
SSH_PORT=$(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}' || echo "22")
log_info "SSH läuft auf Port: $SSH_PORT"
echo ""

# 5. Prüfe ob SSH auf allen IPs hört
log_info "5. SSH Listening-Status:"
ss -tlnp | grep sshd | sed 's/^/   /'
echo ""

# 6. Prüfe Firewall
log_info "6. Firewall-Status:"
if command -v firewall-cmd &> /dev/null; then
    if systemctl is-active --quiet firewalld; then
        log_info "Firewalld ist aktiv"
        log_info "SSH-Service in Firewall:"
        firewall-cmd --list-services | grep -q ssh && log_success "SSH ist erlaubt" || log_error "SSH ist NICHT erlaubt!"
        
        log_info "Offene Ports:"
        firewall-cmd --list-ports | sed 's/^/   /'
        
        log_info "Möchten Sie SSH in der Firewall erlauben? (j/N)"
        read -r response
        if [[ "$response" =~ ^[JjYy]$ ]]; then
            firewall-cmd --permanent --add-service=ssh
            firewall-cmd --reload
            log_success "SSH in Firewall erlaubt"
        fi
    else
        log_info "Firewalld ist nicht aktiv"
    fi
elif command -v SuSEfirewall2 &> /dev/null; then
    log_info "SuSEfirewall2 erkannt"
    if systemctl is-active --quiet SuSEfirewall2; then
        log_warning "SuSEfirewall2 ist aktiv - prüfen Sie die Konfiguration"
    fi
else
    log_info "Keine Firewall erkannt"
fi
echo ""

# 7. Prüfe Routing
log_info "7. Routing-Tabelle:"
ip route show | head -n 5 | sed 's/^/   /'
echo ""

# 8. Prüfe Gateway
log_info "8. Gateway-Erreichbarkeit:"
GATEWAY=$(ip route show | grep default | awk '{print $3}' | head -n 1)
if [[ -n "$GATEWAY" ]]; then
    log_info "Gateway: $GATEWAY"
    if ping -c 2 -W 2 "$GATEWAY" &> /dev/null; then
        log_success "Gateway ist erreichbar"
    else
        log_error "Gateway ist NICHT erreichbar!"
    fi
else
    log_error "Kein Default-Gateway gefunden!"
fi
echo ""

# 9. Prüfe /etc/hosts
log_info "9. /etc/hosts Einträge:"
grep -v "^#" /etc/hosts | grep -v "^$" | sed 's/^/   /'
echo ""

# 10. Prüfe SSH-Logs
log_info "10. Letzte SSH-Log-Einträge:"
journalctl -u sshd -n 20 --no-pager | tail -n 10 | sed 's/^/   /'
echo ""

# 11. Test SSH-Verbindung lokal
log_info "11. Teste SSH-Verbindung lokal:"
if timeout 5 ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no localhost "echo 'SSH funktioniert'" 2>/dev/null; then
    log_success "Lokale SSH-Verbindung funktioniert"
else
    log_warning "Lokale SSH-Verbindung fehlgeschlagen"
fi
echo ""

# 12. Prüfe SELinux/AppArmor
log_info "12. Sicherheits-Module:"
if command -v aa-status &> /dev/null; then
    if systemctl is-active --quiet apparmor; then
        log_info "AppArmor ist aktiv"
        aa-status --enabled && log_info "AppArmor Status: Enabled"
    else
        log_info "AppArmor ist nicht aktiv"
    fi
else
    log_info "AppArmor nicht gefunden"
fi
echo ""

# Zusammenfassung und Empfehlungen
echo "========================================"
echo "ZUSAMMENFASSUNG UND EMPFEHLUNGEN"
echo "========================================"
echo ""

log_info "Mögliche Ursachen für SSH-Probleme:"
echo ""
echo "1. SSH hört nur auf alter IP (ListenAddress)"
echo "   → Lösung: ListenAddress auskommentieren oder anpassen"
echo ""
echo "2. Firewall blockiert neue IP"
echo "   → Lösung: SSH-Service in Firewall erlauben"
echo ""
echo "3. Routing-Problem"
echo "   → Lösung: Default-Gateway prüfen"
echo ""
echo "4. SSH-Dienst muss neu gestartet werden"
echo "   → Lösung: systemctl restart sshd"
echo ""
echo "5. SSH-Keys/authorized_keys Problem"
echo "   → Lösung: Berechtigungen prüfen"
echo ""

log_info "Empfohlene Aktionen:"
echo ""
echo "# SSH neu starten"
echo "sudo systemctl restart sshd"
echo ""
echo "# SSH-Status prüfen"
echo "sudo systemctl status sshd"
echo ""
echo "# Firewall prüfen"
echo "sudo firewall-cmd --list-all"
echo ""
echo "# Von anderem Server testen"
echo "ssh -v user@neue-ip"
echo ""

log_info "Möchten Sie SSH jetzt neu starten? (j/N)"
read -r response
if [[ "$response" =~ ^[JjYy]$ ]]; then
    log_info "Starte SSH neu..."
    systemctl restart sshd
    sleep 2
    if systemctl is-active --quiet sshd; then
        log_success "SSH erfolgreich neu gestartet"
        echo ""
        log_info "Versuchen Sie jetzt, sich von einem anderen Server anzumelden:"
        echo "   ssh user@$(ip -o addr show | grep -E 'inet ' | grep -v '127.0.0.1' | head -n 1 | awk '{print $4}' | cut -d/ -f1)"
    else
        log_error "SSH-Neustart fehlgeschlagen!"
        log_info "Prüfen Sie die Logs: journalctl -u sshd -n 50"
    fi
fi

echo ""
log_info "Diagnose abgeschlossen"

# Made with Bob

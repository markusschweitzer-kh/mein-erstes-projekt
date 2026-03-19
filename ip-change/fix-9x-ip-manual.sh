#!/bin/bash
#==============================================================================
# Manuelle 9.x IP-Änderung (RHEL/Oracle Linux)
#==============================================================================
# Beschreibung: Ändert die 9.x IP direkt auf der Konsole
# Verwendung: sudo ./fix-9x-ip-manual.sh <neue-ip> <interface>
# Beispiel: sudo ./fix-9x-ip-manual.sh 9.125.190.52 ens33
#==============================================================================

set -euo pipefail

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[FEHLER]${NC} $1" >&2; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNUNG]${NC} $1"; }

#==============================================================================
# PARAMETER
#==============================================================================

if [ $# -ne 2 ]; then
    error "Falsche Parameter!"
    echo ""
    echo "Verwendung: $0 <neue-9x-ip> <interface>"
    echo "Beispiel:   $0 9.125.190.52 ens33"
    exit 1
fi

NEW_IP="$1"
INTERFACE="$2"
NETMASK="255.255.255.128"
GATEWAY="9.125.190.1"

# Root-Check
if [ "$EUID" -ne 0 ]; then
    error "Muss als root ausgeführt werden!"
    echo "Bitte verwenden: sudo $0 $NEW_IP $INTERFACE"
    exit 1
fi

#==============================================================================
# AKTUELLE KONFIGURATION
#==============================================================================

log "Aktuelle Konfiguration von $INTERFACE:"
ip addr show "$INTERFACE" | grep -E "inet " || echo "  Keine IP konfiguriert"
echo ""

CURRENT_IP=$(ip -o addr show "$INTERFACE" | grep -E 'inet ' | awk '{print $4}' | cut -d'/' -f1 || echo "keine")
log "Aktuelle IP: $CURRENT_IP"
log "Neue IP: $NEW_IP"
echo ""

#==============================================================================
# BACKUP
#==============================================================================

BACKUP_DIR="/root/9x-ip-fix-$(date +%s)"
mkdir -p "$BACKUP_DIR"

log "Erstelle Backup in: $BACKUP_DIR"
cp -a /etc/sysconfig/network-scripts/ifcfg-"$INTERFACE" "$BACKUP_DIR/" 2>/dev/null || true
ip addr show > "$BACKUP_DIR/ip-addr-before.txt"
ip route show > "$BACKUP_DIR/ip-route-before.txt"
success "Backup erstellt"
echo ""

#==============================================================================
# METHODE 1: NetworkManager Connection löschen und neu erstellen
#==============================================================================

log "Methode 1: Lösche alte NetworkManager Connection..."

# Finde alle Connections für dieses Interface
CONNECTIONS=$(nmcli -t -f NAME,DEVICE connection show | grep ":$INTERFACE$" | cut -d: -f1)

if [ -n "$CONNECTIONS" ]; then
    while IFS= read -r conn; do
        log "  Lösche Connection: $conn"
        nmcli connection delete "$conn" 2>/dev/null || true
    done <<< "$CONNECTIONS"
    success "Alte Connections gelöscht"
else
    warning "Keine Connections gefunden"
fi

echo ""

#==============================================================================
# METHODE 2: Erstelle neue Connection
#==============================================================================

log "Methode 2: Erstelle neue NetworkManager Connection..."

nmcli connection add \
    type ethernet \
    con-name "$INTERFACE" \
    ifname "$INTERFACE" \
    ipv4.method manual \
    ipv4.addresses "$NEW_IP/25" \
    ipv4.gateway "$GATEWAY" \
    ipv4.dns "8.8.8.8 8.8.4.4" \
    connection.autoconnect yes

success "Neue Connection erstellt"
echo ""

#==============================================================================
# METHODE 3: Aktiviere Connection
#==============================================================================

log "Methode 3: Aktiviere neue Connection..."

nmcli connection up "$INTERFACE"

success "Connection aktiviert"
echo ""

#==============================================================================
# WARTE AUF NETZWERK
#==============================================================================

log "Warte 5 Sekunden auf Netzwerk-Stabilisierung..."
sleep 5
echo ""

#==============================================================================
# VALIDIERUNG
#==============================================================================

log "Validiere neue Konfiguration..."
echo ""

log "Neue IP-Konfiguration von $INTERFACE:"
ip addr show "$INTERFACE" | grep -E "inet "
echo ""

log "Neue Routing-Tabelle:"
ip route show | grep -E "default|$INTERFACE"
echo ""

# Prüfe ob neue IP gesetzt wurde
if ip addr show "$INTERFACE" | grep -q "$NEW_IP"; then
    success "Neue IP erfolgreich gesetzt: $NEW_IP"
else
    error "Neue IP wurde NICHT gesetzt!"
    warning "Versuche Neustart..."
    
    # Letzter Versuch: Interface down/up
    ip link set "$INTERFACE" down
    sleep 2
    ip link set "$INTERFACE" up
    sleep 5
    
    if ip addr show "$INTERFACE" | grep -q "$NEW_IP"; then
        success "Neue IP nach Interface-Neustart gesetzt: $NEW_IP"
    else
        error "IP-Änderung fehlgeschlagen!"
        echo ""
        echo "Bitte versuchen Sie:"
        echo "  1. System neu starten: reboot"
        echo "  2. Oder Rollback: bash $BACKUP_DIR/rollback.sh"
        exit 1
    fi
fi

echo ""

#==============================================================================
# TESTE GATEWAY
#==============================================================================

log "Teste Gateway-Erreichbarkeit..."

if ping -c 3 -W 2 "$GATEWAY" >/dev/null 2>&1; then
    success "Gateway $GATEWAY ist erreichbar"
else
    warning "Gateway $GATEWAY ist NICHT erreichbar!"
    echo "  Bitte prüfen Sie die Netzwerk-Konfiguration"
fi

echo ""

#==============================================================================
# ERSTELLE ROLLBACK-SCRIPT
#==============================================================================

cat > "$BACKUP_DIR/rollback.sh" <<'ROLLBACK_EOF'
#!/bin/bash
BACKUP_DIR="$(dirname "$0")"
INTERFACE="ens33"

echo "Starte Rollback..."

# Lösche neue Connection
nmcli connection delete "$INTERFACE" 2>/dev/null || true

# Stelle alte ifcfg-Datei wieder her
if [ -f "$BACKUP_DIR/ifcfg-$INTERFACE" ]; then
    cp -a "$BACKUP_DIR/ifcfg-$INTERFACE" /etc/sysconfig/network-scripts/
    echo "ifcfg-Datei wiederhergestellt"
fi

# Lade Connections neu
nmcli connection reload

# Starte Connection
nmcli connection up "$INTERFACE" || true

echo "Rollback abgeschlossen!"
echo "Falls Probleme bestehen: reboot"
ROLLBACK_EOF

chmod +x "$BACKUP_DIR/rollback.sh"

#==============================================================================
# ZUSAMMENFASSUNG
#==============================================================================

echo "================================================================================"
success "9.x IP-Änderung abgeschlossen!"
echo "================================================================================"
echo ""
echo "Zusammenfassung:"
echo "  Interface: $INTERFACE"
echo "  Alte IP: $CURRENT_IP"
echo "  Neue IP: $NEW_IP"
echo "  Gateway: $GATEWAY"
echo ""
echo "Backup:"
echo "  Verzeichnis: $BACKUP_DIR"
echo "  Rollback: $BACKUP_DIR/rollback.sh"
echo ""
echo "Nächste Schritte:"
echo "  1. Prüfe IP: ip addr show $INTERFACE"
echo "  2. Prüfe Gateway: ip route show"
echo "  3. Teste Konnektivität: ping -c 3 $GATEWAY"
echo "  4. Bei Problemen Rollback: bash $BACKUP_DIR/rollback.sh"
echo "  5. System neu starten (empfohlen): reboot"
echo ""
echo "================================================================================"

# Made with Bob

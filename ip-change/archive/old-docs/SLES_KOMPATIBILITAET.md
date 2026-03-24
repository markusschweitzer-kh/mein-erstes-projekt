# SLES Kompatibilität und technische Details

Detaillierte Informationen zur Kompatibilität und technischen Implementierung für SUSE Linux Enterprise Server (SLES).

## 📋 Inhaltsverzeichnis

- [SLES-Versionen](#sles-versionen)
- [Wicked Netzwerk-Management](#wicked-netzwerk-management)
- [Konfigurationsdateien](#konfigurationsdateien)
- [Unterschiede zu anderen Distributionen](#unterschiede-zu-anderen-distributionen)
- [Migration von anderen Systemen](#migration-von-anderen-systemen)
- [Best Practices](#best-practices)
- [Bekannte Probleme](#bekannte-probleme)

## 🔢 SLES-Versionen

### Unterstützte Versionen

| Version | Codename | Release | Kernel | Wicked | Support Ende | Status |
|---------|----------|---------|--------|--------|--------------|--------|
| **SLES 15 SP5** | - | Juni 2023 | 5.14.21 | 0.6.68 | Juli 2031 | ✅ Empfohlen |
| **SLES 15 SP4** | - | Juni 2022 | 5.14.21 | 0.6.66 | Dez 2027 | ✅ Unterstützt |
| **SLES 15 SP3** | - | Juni 2021 | 5.3.18 | 0.6.60 | Dez 2025 | ✅ Unterstützt |
| **SLES 15 SP2** | - | Juli 2020 | 5.3.18 | 0.6.60 | Dez 2024 | ⚠️ EOL bald |
| **SLES 12 SP5** | - | Dez 2019 | 4.12.14 | 0.6.60 | Okt 2024 | ⚠️ EOL bald |

### Version prüfen

```bash
# SLES Version
cat /etc/os-release

# Kernel Version
uname -r

# Wicked Version
wicked --version

# Service Pack
cat /etc/products.d/SLES.prod | grep -i version
```

### Upgrade-Pfade

```
SLES 12 SP5 → SLES 15 SP3 → SLES 15 SP4 → SLES 15 SP5
```

**Hinweis**: Direkte Upgrades zwischen Major-Versionen (12→15) erfordern sorgfältige Planung.

## 🔧 Wicked Netzwerk-Management

### Was ist Wicked?

Wicked ist das moderne Netzwerk-Management-Framework für SUSE Linux:

- **Entwickelt von**: SUSE
- **Ersetzt**: Traditionelles `ifup`/`ifdown`
- **Architektur**: Client-Server mit DBus
- **Konfiguration**: `/etc/sysconfig/network/`
- **Vorteile**:
  - Bessere Unterstützung für komplexe Netzwerke
  - Hotplug-Unterstützung
  - VLAN, Bonding, Bridging
  - IPv6-Unterstützung

### Wicked-Architektur

```
┌─────────────────────────────────────────┐
│         Wicked Client (CLI)             │
│         wicked ifup/ifdown              │
└──────────────┬──────────────────────────┘
               │ DBus
┌──────────────▼──────────────────────────┐
│         Wicked Server (wickedd)         │
│    - wickedd-dhcp4/6                    │
│    - wickedd-auto4                      │
│    - wickedd-nanny                      │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│         Kernel Network Stack            │
│    - Netlink                            │
│    - Network Interfaces                 │
└─────────────────────────────────────────┘
```

### Wicked-Dienste

```bash
# Hauptdienst
systemctl status wickedd

# DHCP-Dienste
systemctl status wickedd-dhcp4
systemctl status wickedd-dhcp6

# Auto-IPv4 (Link-Local)
systemctl status wickedd-auto4

# Nanny (Policy Manager)
systemctl status wickedd-nanny

# Alle Wicked-Dienste
systemctl list-units 'wicked*'
```

### Wicked-Befehle

#### Interface-Management

```bash
# Interface hochfahren
wicked ifup eth0
wicked ifup all

# Interface herunterfahren
wicked ifdown eth0
wicked ifdown all

# Interface neu laden (ohne Down)
wicked ifreload eth0
wicked ifreload all

# Interface-Status
wicked ifstatus eth0
wicked ifstatus --brief

# Alle Interfaces anzeigen
wicked show all
```

#### Konfiguration

```bash
# Konfiguration anzeigen
wicked show-config

# XML-Konfiguration anzeigen
wicked show-xml eth0

# Konfiguration validieren
wicked ifcheck eth0

# Konfiguration neu einlesen
wicked ifup --ifconfig compat:/etc/sysconfig/network eth0
```

#### Debugging

```bash
# Debug-Modus
wicked --debug all ifup eth0

# Nur bestimmte Debug-Kategorien
wicked --debug dhcp,interface ifup eth0

# Log-Level erhöhen
wicked --log-level debug ifup eth0

# Systemd-Journal
journalctl -u wickedd -f
```

## 📁 Konfigurationsdateien

### Verzeichnisstruktur

```
/etc/sysconfig/network/
├── ifcfg-eth0              # Interface-Konfiguration
├── ifcfg-eth0:0            # Alias-Interface (optional)
├── ifcfg-lo                # Loopback
├── routes                  # Routing-Tabelle
├── config                  # Globale Netzwerk-Einstellungen
├── dhcp                    # DHCP-Einstellungen
└── if-up.d/                # Post-Up Scripts
    └── custom-script
```

### ifcfg-Datei Format

#### Minimale Konfiguration

```bash
# /etc/sysconfig/network/ifcfg-eth0
BOOTPROTO='static'
STARTMODE='auto'
IPADDR='9.125.190.41/25'
```

#### Vollständige Konfiguration

```bash
# /etc/sysconfig/network/ifcfg-eth0
# Interface-Typ und Start
BOOTPROTO='static'          # static, dhcp, dhcp4, dhcp6, none
STARTMODE='auto'            # auto, manual, hotplug, nfsroot, off
NAME='Primary Network Interface'

# Primäre IP-Adresse
IPADDR='9.125.190.41/25'    # CIDR-Notation

# Sekundäre IP-Adressen
LABEL_0='secondary'
IPADDR_0='10.10.64.41/24'

LABEL_1='tertiary'
IPADDR_1='192.168.1.10/24'

# MTU
MTU='1500'

# VLAN (optional)
VLAN_ID='100'
ETHERDEVICE='eth0'

# Bonding (optional)
BONDING_MASTER='yes'
BONDING_MODULE_OPTS='mode=active-backup miimon=100'
BONDING_SLAVE_0='eth0'
BONDING_SLAVE_1='eth1'

# Bridge (optional)
BRIDGE='yes'
BRIDGE_PORTS='eth0 eth1'
BRIDGE_STP='off'

# Firewall-Zone
ZONE='public'
```

#### Parameter-Referenz

| Parameter | Werte | Beschreibung |
|-----------|-------|--------------|
| `BOOTPROTO` | `static`, `dhcp`, `dhcp4`, `dhcp6`, `none` | Boot-Protokoll |
| `STARTMODE` | `auto`, `manual`, `hotplug`, `off` | Wann Interface starten |
| `IPADDR` | IP/CIDR | IP-Adresse mit Prefix |
| `LABEL_X` | String | Label für sekundäre IP |
| `IPADDR_X` | IP/CIDR | Sekundäre IP-Adresse |
| `MTU` | 1-9000 | Maximum Transmission Unit |
| `NAME` | String | Interface-Beschreibung |
| `ZONE` | String | Firewall-Zone |

### routes-Datei Format

```bash
# /etc/sysconfig/network/routes
# Format: destination gateway netmask interface [type] [options]

# Default Gateway
default 9.125.190.1 - eth0

# Spezifische Route mit Netmask
10.10.64.0 0.0.0.0 255.255.255.0 eth0

# Spezifische Route mit CIDR
192.168.1.0/24 9.125.190.1 - eth0

# Route mit Metrik
172.16.0.0/16 9.125.190.1 - eth0 - metric 100

# Blackhole-Route
10.0.0.0/8 - - - blackhole

# Reject-Route
192.168.0.0/16 - - - reject
```

### config-Datei Format

```bash
# /etc/sysconfig/network/config
# Globale Netzwerk-Einstellungen

# DNS-Server
NETCONFIG_DNS_STATIC_SERVERS="9.0.0.1 9.0.0.2"

# DNS-Suchliste
NETCONFIG_DNS_STATIC_SEARCHLIST="example.com internal.example.com"

# DNS-Resolver
NETCONFIG_DNS_RESOLVER="netconfig"

# NTP-Server
NETCONFIG_NTP_STATIC_SERVERS="ntp1.example.com ntp2.example.com"

# Proxy-Einstellungen
PROXY_ENABLED="no"
HTTP_PROXY=""
HTTPS_PROXY=""
NO_PROXY="localhost,127.0.0.1"
```

## 🔄 Unterschiede zu anderen Distributionen

### SLES vs. RHEL/Oracle Linux

| Aspekt | SLES | RHEL/Oracle Linux |
|--------|------|-------------------|
| **Netzwerk-Manager** | Wicked | NetworkManager |
| **Konfigurationspfad** | `/etc/sysconfig/network/` | `/etc/sysconfig/network-scripts/` |
| **BOOTPROTO** | `static` | `none` |
| **IP-Format** | `IPADDR='9.125.190.41/25'` | `IPADDR=9.125.190.41`<br>`PREFIX=25` |
| **Gateway** | In `routes` Datei | `GATEWAY=` in ifcfg |
| **DNS** | In `config` Datei | `DNS1=` in ifcfg |
| **Sekundäre IP** | `LABEL_0=`<br>`IPADDR_0=` | Separate `ifcfg-eth0:0` |
| **Neustart** | `wicked ifreload all` | `nmcli con reload`<br>`systemctl restart network` |

### SLES vs. Ubuntu

| Aspekt | SLES | Ubuntu |
|--------|------|--------|
| **Netzwerk-Manager** | Wicked | Netplan |
| **Konfiguration** | `/etc/sysconfig/network/` | `/etc/netplan/*.yaml` |
| **Format** | Shell-Style | YAML |
| **IP-Notation** | CIDR in Anführungszeichen | CIDR ohne Anführungszeichen |
| **Routing** | Separate `routes` Datei | In YAML integriert |
| **DNS** | Separate `config` Datei | In YAML integriert |
| **Neustart** | `wicked ifreload all` | `netplan apply` |

### Migrations-Mapping

#### Von RHEL zu SLES

```bash
# RHEL ifcfg-eth0
DEVICE=eth0
BOOTPROTO=none
ONBOOT=yes
IPADDR=9.125.190.41
PREFIX=25
GATEWAY=9.125.190.1
DNS1=9.0.0.1

# Wird zu SLES ifcfg-eth0
BOOTPROTO='static'
STARTMODE='auto'
IPADDR='9.125.190.41/25'

# Plus routes
default 9.125.190.1 - eth0

# Plus config
NETCONFIG_DNS_STATIC_SERVERS="9.0.0.1"
```

#### Von Ubuntu zu SLES

```yaml
# Ubuntu /etc/netplan/01-netcfg.yaml
network:
  version: 2
  ethernets:
    eth0:
      addresses:
        - 9.125.190.41/25
      gateway4: 9.125.190.1
      nameservers:
        addresses:
          - 9.0.0.1
```

```bash
# Wird zu SLES ifcfg-eth0
BOOTPROTO='static'
STARTMODE='auto'
IPADDR='9.125.190.41/25'

# Plus routes
default 9.125.190.1 - eth0

# Plus config
NETCONFIG_DNS_STATIC_SERVERS="9.0.0.1"
```

## 🔄 Migration von anderen Systemen

### Von RHEL/CentOS zu SLES

#### Schritt 1: Backup erstellen

```bash
# Auf RHEL/CentOS
tar -czf rhel-network-backup.tar.gz /etc/sysconfig/network-scripts/
```

#### Schritt 2: Konfiguration konvertieren

```bash
# Konvertierungs-Script (Beispiel)
#!/bin/bash
RHEL_IFCFG="/etc/sysconfig/network-scripts/ifcfg-eth0"
SLES_IFCFG="/etc/sysconfig/network/ifcfg-eth0"

# Lese RHEL-Konfiguration
IPADDR=$(grep ^IPADDR= $RHEL_IFCFG | cut -d= -f2)
PREFIX=$(grep ^PREFIX= $RHEL_IFCFG | cut -d= -f2)
GATEWAY=$(grep ^GATEWAY= $RHEL_IFCFG | cut -d= -f2)

# Schreibe SLES-Konfiguration
cat > $SLES_IFCFG << EOF
BOOTPROTO='static'
STARTMODE='auto'
IPADDR='${IPADDR}/${PREFIX}'
EOF

# Schreibe Routes
echo "default $GATEWAY - eth0" > /etc/sysconfig/network/routes
```

#### Schritt 3: Wicked aktivieren

```bash
# Deaktiviere NetworkManager
systemctl stop NetworkManager
systemctl disable NetworkManager

# Aktiviere Wicked
systemctl enable wickedd
systemctl start wickedd

# Starte Interface
wicked ifup eth0
```

### Von Ubuntu zu SLES

#### Schritt 1: Netplan-Konfiguration exportieren

```bash
# Auf Ubuntu
netplan get > netplan-config.yaml
```

#### Schritt 2: Manuell konvertieren

Netplan YAML muss manuell in Wicked-Format konvertiert werden (siehe Mapping oben).

#### Schritt 3: Testen

```bash
# Auf SLES
wicked ifcheck eth0
wicked ifup eth0
```

## 📚 Best Practices

### 1. Konfigurationsverwaltung

```bash
# Immer Backups erstellen
cp /etc/sysconfig/network/ifcfg-eth0 /etc/sysconfig/network/ifcfg-eth0.backup

# Versionskontrolle verwenden
cd /etc/sysconfig/network
git init
git add .
git commit -m "Initial network configuration"
```

### 2. Änderungen testen

```bash
# Syntax prüfen
wicked ifcheck eth0

# Dry-Run
wicked --dry-run ifup eth0

# Mit Timeout (automatischer Rollback)
timeout 30 wicked ifup eth0 || wicked ifdown eth0
```

### 3. Monitoring

```bash
# Interface-Status überwachen
watch -n 1 'wicked ifstatus eth0'

# Logs überwachen
journalctl -u wickedd -f

# Netzwerk-Statistiken
watch -n 1 'ip -s link show eth0'
```

### 4. Dokumentation

```bash
# Konfiguration dokumentieren
cat > /etc/sysconfig/network/README << EOF
Network Configuration
=====================
Last modified: $(date)
Modified by: $(whoami)
Reason: IP address change for datacenter migration

Changes:
- Old IP: 9.155.64.41
- New IP: 9.125.190.41
- Gateway: 9.125.190.1
EOF
```

## ⚠️ Bekannte Probleme

### Problem 1: Wicked startet nicht nach Upgrade

**Symptom**: Nach SLES-Upgrade startet Wicked nicht

**Lösung**:
```bash
# Wicked-Konfiguration neu generieren
wicked convert --output /etc/wicked/ifconfig

# Dienste neu starten
systemctl restart wickedd
systemctl restart wickedd-nanny
```

### Problem 2: Interface kommt nicht automatisch hoch

**Symptom**: Interface muss manuell mit `wicked ifup` gestartet werden

**Lösung**:
```bash
# Prüfe STARTMODE
grep STARTMODE /etc/sysconfig/network/ifcfg-eth0

# Sollte 'auto' sein
sed -i "s/STARTMODE=.*/STARTMODE='auto'/" /etc/sysconfig/network/ifcfg-eth0

# Nanny neu starten
systemctl restart wickedd-nanny
```

### Problem 3: DNS funktioniert nicht

**Symptom**: `/etc/resolv.conf` wird nicht aktualisiert

**Lösung**:
```bash
# Prüfe netconfig
netconfig update -f

# Prüfe DNS-Konfiguration
cat /etc/sysconfig/network/config | grep DNS

# Manuell setzen
echo "NETCONFIG_DNS_STATIC_SERVERS=\"9.0.0.1 9.0.0.2\"" >> /etc/sysconfig/network/config
netconfig update -f
```

### Problem 4: Sekundäre IP wird nicht konfiguriert

**Symptom**: Nur primäre IP ist aktiv

**Lösung**:
```bash
# Prüfe Label-Syntax
grep LABEL /etc/sysconfig/network/ifcfg-eth0

# Korrekte Syntax:
# LABEL_0='secondary'
# IPADDR_0='10.10.64.41/24'

# Interface neu laden
wicked ifreload eth0
```

### Problem 5: Routing funktioniert nicht

**Symptom**: Keine Verbindung zu anderen Netzwerken

**Lösung**:
```bash
# Prüfe routes-Datei
cat /etc/sysconfig/network/routes

# Prüfe aktive Routen
ip route show

# Prüfe Gateway-Erreichbarkeit
ping -c 3 9.125.190.1

# Routes neu laden
wicked ifreload all
```

## 🔍 Debugging

### Debug-Level

```bash
# Alle Debug-Informationen
wicked --debug all ifup eth0

# Spezifische Kategorien
wicked --debug dhcp,interface,events ifup eth0

# Mit Log-File
wicked --debug all --log-target file:/tmp/wicked-debug.log ifup eth0
```

### Systemd-Journal

```bash
# Wicked-Logs
journalctl -u wickedd -n 100

# Alle Netzwerk-relevanten Logs
journalctl -u 'wicked*' -n 100

# Folge Logs in Echtzeit
journalctl -u wickedd -f

# Logs seit letztem Boot
journalctl -u wickedd -b
```

### DBus-Monitoring

```bash
# DBus-Monitor für Wicked
dbus-monitor --system "type='signal',sender='org.opensuse.Network'"

# Wicked-Status über DBus
busctl tree org.opensuse.Network
busctl introspect org.opensuse.Network /org/opensuse/Network
```

## 📖 Referenzen

- [SLES Dokumentation](https://documentation.suse.com/sles/)
- [Wicked GitHub](https://github.com/openSUSE/wicked)
- [Wicked Wiki](https://en.opensuse.org/Portal:Wicked)
- [SUSE Support](https://www.suse.com/support/)

---

**Letzte Aktualisierung**: 2024
**Version**: 1.0.0
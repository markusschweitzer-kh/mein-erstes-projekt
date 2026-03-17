# SLES (SUSE Linux Enterprise Server) Netzwerkkonfiguration - Analyse

## Zusammenfassung

**JA, wir benötigen eine eigene Version für SLES!**

SLES verwendet ein völlig anderes Netzwerkkonfigurationssystem als RHEL/Oracle Linux und Ubuntu.

## Netzwerkkonfigurationssysteme im Vergleich

| Distribution | Netzwerk-System | Konfigurationsdateien | Management-Tool |
|--------------|-----------------|----------------------|-----------------|
| **RHEL/Oracle Linux** | NetworkManager / network service | `/etc/sysconfig/network-scripts/ifcfg-*` | `nmcli` / `systemctl` |
| **Ubuntu** | Netplan | `/etc/netplan/*.yaml` | `netplan` |
| **SLES** | Wicked | `/etc/sysconfig/network/ifcfg-*` | `wicked` |

## SLES-Spezifische Details

### 1. Netzwerk-Management: Wicked

SLES verwendet **Wicked** als Netzwerk-Management-Framework:
- Entwickelt von SUSE speziell für Enterprise-Umgebungen
- Ersetzt das alte `ifup`/`ifdown` System
- Unterstützt komplexe Netzwerkkonfigurationen
- Verwendet XML-basierte Konfiguration intern

### 2. Konfigurationsdateien

**Hauptverzeichnis:** `/etc/sysconfig/network/`

**Wichtige Dateien:**
```bash
/etc/sysconfig/network/ifcfg-eth0          # Interface-Konfiguration
/etc/sysconfig/network/routes              # Routing-Tabelle
/etc/sysconfig/network/config              # Globale Netzwerk-Einstellungen
/etc/sysconfig/network/dhcp                # DHCP-Einstellungen
```

### 3. ifcfg-Datei Format (SLES)

**Beispiel:** `/etc/sysconfig/network/ifcfg-eth0`

```bash
# Primäre IP-Adresse
BOOTPROTO='static'
IPADDR='9.155.64.151/25'
STARTMODE='auto'
NAME='Primary Network Interface'

# Sekundäre IP-Adresse (Label-basiert)
LABEL_0='secondary'
IPADDR_0='10.10.64.151/24'

# Oder als separates Interface
# /etc/sysconfig/network/ifcfg-eth0:0
```

### 4. Wichtige Unterschiede zu RHEL

| Aspekt | RHEL/Oracle Linux | SLES |
|--------|-------------------|------|
| **BOOTPROTO** | `none` für statisch | `static` für statisch |
| **IP-Format** | `IPADDR=9.155.64.151`<br>`PREFIX=25` | `IPADDR='9.155.64.151/25'` (CIDR) |
| **Netmask** | `NETMASK=255.255.255.128` | Nicht verwendet (CIDR) |
| **Gateway** | `GATEWAY=9.125.190.1` | In `/etc/sysconfig/network/routes` |
| **DNS** | `DNS1=9.0.0.1` | In `/etc/sysconfig/network/config` |
| **Sekundäre IP** | Separates `ifcfg-eth0:0` | `LABEL_0` und `IPADDR_0` |
| **Aktivierung** | `nmcli` oder `systemctl restart network` | `wicked ifup eth0` |

### 5. Routing-Konfiguration

**Datei:** `/etc/sysconfig/network/routes`

```bash
# Format: destination gateway netmask interface
default 9.125.190.1 - eth0
10.10.64.0 0.0.0.0 255.255.255.0 eth0
```

### 6. DNS-Konfiguration

**Datei:** `/etc/sysconfig/network/config`

```bash
NETCONFIG_DNS_STATIC_SERVERS="9.0.0.1 9.0.0.2"
NETCONFIG_DNS_STATIC_SEARCHLIST=""
```

### 7. Wicked-Befehle

```bash
# Interface-Status anzeigen
wicked show eth0

# Interface neu starten
wicked ifdown eth0
wicked ifup eth0

# Alle Interfaces neu starten
wicked ifreload all

# Konfiguration validieren
wicked show-config

# XML-Konfiguration anzeigen
wicked show-xml eth0
```

## Benötigte Anpassungen für SLES

### 1. Neues Ansible Playbook

**Datei:** `network-update-sles.yml`

**Hauptunterschiede:**
- OS-Prüfung: `ansible_distribution == "SLES"`
- Konfigurationspfad: `/etc/sysconfig/network/`
- Template: `ifcfg-sles-template.j2`
- Netzwerk-Neustart: `wicked ifreload all`
- Routing-Datei: Separate Verwaltung von `/etc/sysconfig/network/routes`
- DNS-Konfiguration: In `/etc/sysconfig/network/config`

### 2. Neues Template

**Datei:** `ifcfg-sles-template.j2`

```jinja2
# {{ ansible_managed }}
# Interface: {{ interface_name }}
# Hostname: {{ new_hostname }}

BOOTPROTO='static'
STARTMODE='auto'
NAME='Primary Network Interface'

# Primäre IP-Adresse
IPADDR='{{ primary_ip }}/{{ prefix }}'

{% if secondary_ip %}
# Sekundäre IP-Adresse
LABEL_0='secondary'
IPADDR_0='{{ secondary_ip }}/24'
{% endif %}
```

### 3. Routing-Template

**Datei:** `routes-sles-template.j2`

```jinja2
# {{ ansible_managed }}
# Routing-Tabelle für {{ interface_name }}

# Default Gateway
default {{ gateway }} - {{ interface_name }}

# Lokales Netzwerk (sekundäre IP)
{% if secondary_ip %}
10.10.64.0 0.0.0.0 255.255.255.0 {{ interface_name }}
{% endif %}
```

### 4. Rollback-Script

**Datei:** `rollback-sles.sh`

**Unterschiede:**
- Verwendet `wicked` statt `nmcli`
- Backup von `/etc/sysconfig/network/`
- Wiederherstellung von `routes` und `config`

### 5. Remove-IP-Script

**Datei:** `remove-old-ip-sles.sh`

**Unterschiede:**
- Bearbeitet `/etc/sysconfig/network/ifcfg-*`
- Entfernt `LABEL_0` und `IPADDR_0` Einträge
- Verwendet `wicked` für Neustart

## SLES-Versionen

| Version | Release | Kernel | Wicked | Support bis |
|---------|---------|--------|--------|-------------|
| SLES 15 SP5 | 2023 | 5.14 | 0.6.x | 2031 |
| SLES 15 SP4 | 2022 | 5.14 | 0.6.x | 2027 |
| SLES 15 SP3 | 2021 | 5.3 | 0.6.x | 2025 |
| SLES 12 SP5 | 2019 | 4.12 | 0.6.x | 2024 |

**Empfehlung:** Unterstützung für SLES 15 SP3+ (aktuelle LTS-Versionen)

## Kompatibilitätsprüfung

### Ansible Facts für SLES

```yaml
ansible_distribution: "SLES"
ansible_distribution_version: "15.5"
ansible_distribution_major_version: "15"
ansible_os_family: "Suse"
```

### Prüfung im Playbook

```yaml
- name: Prüfe ob SLES
  fail:
    msg: "Dieses Playbook ist nur für SLES!"
  when: ansible_distribution != "SLES"

- name: Prüfe SLES Version
  fail:
    msg: "Dieses Playbook benötigt SLES 15 oder höher"
  when: ansible_distribution_major_version | int < 15
```

## Implementierungsplan

### Phase 1: Analyse und Vorbereitung
- [x] SLES-Netzwerkkonfiguration analysiert
- [ ] Test-SLES-VM aufsetzen
- [ ] Wicked-Befehle testen

### Phase 2: Entwicklung
- [ ] `network-update-sles.yml` erstellen
- [ ] `ifcfg-sles-template.j2` erstellen
- [ ] `routes-sles-template.j2` erstellen
- [ ] `rollback-sles.sh` erstellen
- [ ] `remove-old-ip-sles.sh` erstellen

### Phase 3: Dokumentation
- [ ] `README_SLES.md` erstellen
- [ ] `SLES_KOMPATIBILITAET.md` erstellen
- [ ] `SCHNELLSTART_SLES.md` erstellen

### Phase 4: Testing
- [ ] Lokale Tests auf SLES 15
- [ ] Remote-Tests
- [ ] Rollback-Tests
- [ ] Edge-Case-Tests

## Risiken und Herausforderungen

### 1. Wicked-Spezifika
- **Problem:** Wicked hat andere Timing-Anforderungen als NetworkManager
- **Lösung:** Asynchrone Ausführung mit längeren Timeouts

### 2. Routing-Konfiguration
- **Problem:** Separate `routes`-Datei muss synchron gehalten werden
- **Lösung:** Atomic Updates mit Backup/Rollback

### 3. DNS-Konfiguration
- **Problem:** DNS in separater `config`-Datei
- **Lösung:** Separate Task für DNS-Update

### 4. Interface-Naming
- **Problem:** SLES kann andere Interface-Namen verwenden (eth0, ens33, etc.)
- **Lösung:** Dynamische Interface-Erkennung wie bei RHEL

## Empfehlung

**JA, eine eigene SLES-Version ist notwendig!**

Die Unterschiede sind zu groß, um sie in einem gemeinsamen Playbook zu handhaben:

1. **Anderes Netzwerk-Management-System** (Wicked vs. NetworkManager)
2. **Anderes Konfigurationsformat** (CIDR vs. separate Netmask)
3. **Separate Routing-Datei** (nicht in ifcfg-Datei)
4. **Andere DNS-Konfiguration** (separate config-Datei)
5. **Andere Befehle** (wicked vs. nmcli)

**Nächster Schritt:** Soll ich die SLES-Version implementieren?
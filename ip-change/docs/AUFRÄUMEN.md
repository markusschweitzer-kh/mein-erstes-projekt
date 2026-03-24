# Projekt-Aufräumung und Vereinfachung

## Aktuelle Situation

Das Projekt enthält **46 Dateien** mit vielen Duplikaten und veralteten Versionen.

## Empfohlene Struktur

### 📁 Hauptverzeichnis behalten

#### ✅ Produktiv-Playbooks (BEHALTEN)
```
network-update-rhel-v3.yml      # RHEL/Oracle Linux IP-Migration (AKTUELL)
network-update-sles-v3.yml      # SLES IP-Migration (AKTUELL)
network-update-ubuntu.yml       # Ubuntu IP-Migration
update-dns-config.yml           # DNS-Server Update (NEU)
check-migration-status.yml      # Status-Check (NEU, Ansible)
```

#### ✅ Templates (BEHALTEN)
```
ifcfg-template.j2              # RHEL/Oracle Linux Template
ifcfg-sles-template.j2         # SLES Template
routes-sles-template.j2        # SLES Routes Template
netplan-template.j2            # Ubuntu Template
```

#### ✅ Daten (BEHALTEN)
```
ip-change.csv                  # Haupt-CSV mit allen IPs
inventory.ini                  # Ansible Inventory
```

#### ✅ Dokumentation (BEHALTEN & KONSOLIDIEREN)
```
README.md                      # Haupt-Dokumentation (AKTUALISIEREN)
README_DNS_UPDATE.md           # DNS-Update Anleitung
README_CHECK_STATUS.md         # Status-Check Anleitung
SCHNELLSTART.md               # Quick-Start Guide
```

### 🗑️ Zu löschen/archivieren

#### ❌ Veraltete Versionen (LÖSCHEN)
```
network-update-rhel-v2.yml     # Veraltet, v3 verwenden
network-update-sles-v2.yml     # Veraltet, v3 verwenden
network-update-sles.yml        # Veraltet, v3 verwenden
network-update.yml             # Veraltet, spezifische Versionen verwenden
```

#### ❌ Bash-Scripts (OPTIONAL LÖSCHEN - durch Ansible ersetzt)
```
check-migration-status.sh      # Ersetzt durch .yml Version
change-10x-ip.sh              # Kann durch Playbook ersetzt werden
fix-9x-ip-manual.sh           # Kann durch Playbook ersetzt werden
cleanup-old-config-sles.sh    # Selten benötigt
diagnose-ssh-sles.sh          # Selten benötigt
pre-migration-check-sles.sh   # Selten benötigt
remove-old-ip-sles.sh         # Selten benötigt
remove-old-ip-ubuntu.sh       # Selten benötigt
rollback-sles.sh              # Automatisch erstellt
rollback-ubuntu.sh            # Automatisch erstellt
rollback.sh                   # Automatisch erstellt
fix-csv.sh                    # Einmalig verwendet
validate-csv.sh               # Optional
```

#### ❌ Analyse-Dateien (ARCHIVIEREN)
```
analyze-network-rhel.yml       # Nur für Analyse
collect-network-status.yml     # Nur für Analyse
```

#### ❌ Redundante Dokumentation (KONSOLIDIEREN)
```
README_RHEL_V2.md             # In Haupt-README integrieren
README_SLES.md                # In Haupt-README integrieren
README_UBUNTU.md              # In Haupt-README integrieren
PROJEKT_UEBERSICHT.md         # In Haupt-README integrieren
ORACLE_LINUX_KOMPATIBILITAET.md  # In Haupt-README integrieren
SLES_ANALYSE.md               # Archivieren
SLES_KOMPATIBILITAET.md       # In Haupt-README integrieren
UBUNTU_KOMPATIBILITAET.md     # In Haupt-README integrieren
SSH-DIAGNOSE-BEFEHLE.md       # Archivieren
TEST_ANLEITUNG.md             # Archivieren
```

#### ❌ Backup-Dateien (LÖSCHEN)
```
ip-change.csv.backup          # Backup, kann gelöscht werden
```

## Vorgeschlagene Ordnerstruktur

```
ip-change/
├── playbooks/
│   ├── network-update-rhel-v3.yml
│   ├── network-update-sles-v3.yml
│   ├── network-update-ubuntu.yml
│   ├── update-dns-config.yml
│   └── check-migration-status.yml
│
├── templates/
│   ├── ifcfg-template.j2
│   ├── ifcfg-sles-template.j2
│   ├── routes-sles-template.j2
│   └── netplan-template.j2
│
├── data/
│   ├── ip-change.csv
│   └── inventory.ini
│
├── docs/
│   ├── README.md
│   ├── SCHNELLSTART.md
│   ├── DNS_UPDATE.md
│   └── STATUS_CHECK.md
│
└── archive/
    ├── old-versions/
    │   ├── network-update-rhel-v2.yml
    │   └── ...
    ├── scripts/
    │   ├── check-migration-status.sh
    │   └── ...
    └── old-docs/
        ├── SLES_ANALYSE.md
        └── ...
```

## Aufräum-Aktionen

### Schritt 1: Archiv-Ordner erstellen

```bash
cd ip-change
mkdir -p archive/{old-versions,scripts,old-docs}
```

### Schritt 2: Veraltete Versionen archivieren

```bash
# Veraltete Playbooks
mv network-update-rhel-v2.yml archive/old-versions/
mv network-update-sles-v2.yml archive/old-versions/
mv network-update-sles.yml archive/old-versions/
mv network-update.yml archive/old-versions/

# Bash-Scripts (optional)
mv check-migration-status.sh archive/scripts/
mv change-10x-ip.sh archive/scripts/
mv fix-9x-ip-manual.sh archive/scripts/
mv cleanup-old-config-sles.sh archive/scripts/
mv diagnose-ssh-sles.sh archive/scripts/
mv pre-migration-check-sles.sh archive/scripts/
mv remove-old-ip-sles.sh archive/scripts/
mv remove-old-ip-ubuntu.sh archive/scripts/
mv rollback-sles.sh archive/scripts/
mv rollback-ubuntu.sh archive/scripts/
mv rollback.sh archive/scripts/
mv fix-csv.sh archive/scripts/
mv validate-csv.sh archive/scripts/

# Analyse-Playbooks
mv analyze-network-rhel.yml archive/old-versions/
mv collect-network-status.yml archive/old-versions/
```

### Schritt 3: Dokumentation konsolidieren

```bash
# Alte Dokumentation archivieren
mv README_RHEL_V2.md archive/old-docs/
mv README_SLES.md archive/old-docs/
mv README_UBUNTU.md archive/old-docs/
mv PROJEKT_UEBERSICHT.md archive/old-docs/
mv ORACLE_LINUX_KOMPATIBILITAET.md archive/old-docs/
mv SLES_ANALYSE.md archive/old-docs/
mv SLES_KOMPATIBILITAET.md archive/old-docs/
mv UBUNTU_KOMPATIBILITAET.md archive/old-docs/
mv SSH-DIAGNOSE-BEFEHLE.md archive/old-docs/
mv TEST_ANLEITUNG.md archive/old-docs/
```

### Schritt 4: Backup-Dateien löschen

```bash
rm ip-change.csv.backup
```

### Schritt 5: Neue Ordnerstruktur erstellen (optional)

```bash
# Ordner erstellen
mkdir -p playbooks templates data docs

# Dateien verschieben
mv network-update-*.yml playbooks/
mv update-dns-config.yml playbooks/
mv check-migration-status.yml playbooks/

mv *.j2 templates/

mv ip-change.csv inventory.ini data/

mv README*.md SCHNELLSTART.md docs/
```

## Vereinfachte Haupt-README erstellen

Erstelle eine neue, konsolidierte `README.md` mit:

1. **Übersicht** - Was macht das Projekt?
2. **Schnellstart** - Wichtigste Befehle
3. **Playbooks** - Welches für welches OS?
4. **Workflow** - Typischer Ablauf
5. **Troubleshooting** - Häufige Probleme

## Ergebnis nach Aufräumung

### Vorher: 46 Dateien
### Nachher: ~15 aktive Dateien + Archiv

```
ip-change/
├── playbooks/ (5 Dateien)
├── templates/ (4 Dateien)
├── data/ (2 Dateien)
├── docs/ (4 Dateien)
└── archive/ (31 Dateien)
```

## Empfehlung

**Minimale Aufräumung (sicher):**
1. Archiviere veraltete v2-Playbooks
2. Archiviere alte Dokumentation
3. Lösche Backup-Dateien

**Vollständige Aufräumung (empfohlen):**
1. Alle oben genannten Schritte
2. Erstelle neue Ordnerstruktur
3. Konsolidiere Dokumentation in eine Haupt-README

**Behalte im Hauptverzeichnis:**
- Die 3 v3-Playbooks (RHEL, SLES, Ubuntu)
- update-dns-config.yml
- check-migration-status.yml
- Templates (*.j2)
- ip-change.csv
- inventory.ini
- Konsolidierte README.md

---

**Erstellt:** 2026-03-23  
**Zweck:** Projekt-Vereinfachung und bessere Übersicht
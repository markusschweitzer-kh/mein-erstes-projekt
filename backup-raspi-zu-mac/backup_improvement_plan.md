# 🔧 Verbesserungsplan für Raspberry Pi Backup-Script

## 📋 Übersicht

Dieses Dokument beschreibt alle notwendigen Verbesserungen für das Backup-Script `backup_to_mac-v5.sh` mit Prioritäten, konkreten Lösungen und Code-Beispielen.

---

## 🔴 Priorität 1: KRITISCH - Sofort beheben

### 1.1 Discord Webhook Sicherheit ⚠️ SICHERHEITSRISIKO

**Problem**: 
- Webhook-URL ist im Klartext im Script sichtbar (Zeile 12)
- Jeder mit Zugriff auf das Script kann Nachrichten senden
- Bei Veröffentlichung (z.B. GitHub) ist der Webhook kompromittiert

**Lösung**: Secrets in separate Datei auslagern

**Schritt 1**: Secrets-Datei erstellen
```bash
# Auf dem Raspberry Pi ausführen:
cat > /home/markus/.backup_secrets << 'EOF'
DISCORD_WEBHOOK="https://discord.com/api/webhooks/1478348422645022771/xpydTfLeO5WOzIHbg3dpP9Fbtq9zvT5zM6R_AEmT9FFg4SjkrU9mGPyP3WyLMwYRcdUU"
UPTIME_KUMA_URL="http://192.168.178.11:3001/api/push/0X2vNKiLrs"
EOF

# Berechtigungen setzen (nur Owner kann lesen/schreiben)
chmod 600 /home/markus/.backup_secrets
```

**Schritt 2**: Script anpassen
```bash
# Zeile 12 ersetzen durch:
# Secrets laden
if [ -f "/home/markus/.backup_secrets" ]; then
    source /home/markus/.backup_secrets
else
    log_msg "❌ FEHLER: Secrets-Datei /home/markus/.backup_secrets nicht gefunden!"
    exit 1
fi

# Zeile 133 ändern zu:
curl -fsS -m 10 --retry 5 "${UPTIME_KUMA_URL}?status=up&msg=OK&ping="
```

**Schritt 3**: .gitignore erstellen (falls Git verwendet wird)
```bash
echo ".backup_secrets" >> .gitignore
```

---

### 1.2 Container-Wiederherstellung robuster machen

**Problem**: 
- `$RUNNING_CONTAINERS` wird erst in Zeile 52 gesetzt
- Bei Fehlern vorher (z.B. Paperless Export) werden Container nicht wiederhergestellt
- Script könnte System in inkonsistentem Zustand hinterlassen

**Lösung**: Container-Status früher erfassen + Cleanup-Trap

**Code-Änderungen**:

```bash
# Nach Zeile 38 einfügen (direkt nach "START"):
# Container-Status SOFORT erfassen
RUNNING_CONTAINERS=$(docker ps -q)
CONTAINER_COUNT=$(echo $RUNNING_CONTAINERS | wc -w)
log_msg "➕ Laufende Container erfasst: $CONTAINER_COUNT"

# Cleanup-Funktion für unerwartete Abbrüche
cleanup() {
    local exit_code=$?
    if [ -n "$RUNNING_CONTAINERS" ] && [ "$CONTAINERS_STOPPED" = "true" ]; then
        log_msg "➕ Cleanup: Starte Container neu..."
        docker start $RUNNING_CONTAINERS > /dev/null 2>&1
        log_msg "✅ Container wiederhergestellt"
    fi
    exit $exit_code
}
trap cleanup EXIT INT TERM

# Zeile 52-56 ERSETZEN durch:
# Container stoppen (Status bereits erfasst)
CONTAINERS_STOPPED="false"
if [ -n "$RUNNING_CONTAINERS" ]; then
    log_msg "➕ Stoppe $CONTAINER_COUNT Container..."
    if docker stop $RUNNING_CONTAINERS > /dev/null; then
        CONTAINERS_STOPPED="true"
        log_msg "✅ Container gestoppt"
    else
        abort_with_error "Container konnten nicht gestoppt werden"
    fi
fi

# Zeile 97-100 ERSETZEN durch:
# Container wieder starten
if [ "$CONTAINERS_STOPPED" = "true" ]; then
    log_msg "➕ Starte Container neu..."
    if docker start $RUNNING_CONTAINERS > /dev/null; then
        CONTAINERS_STOPPED="false"
        log_msg "✅ Container gestartet"
    else
        log_msg "⚠️ WARNUNG: Container-Start fehlgeschlagen!"
    fi
fi
```

---

### 1.3 Uptime Kuma Status-Check korrigieren

**Problem**: 
- Zeile 130: `if [ $? -eq 0 ]` prüft Exit-Code von `send_discord`, nicht vom Backup
- Backup könnte fehlschlagen, aber "OK" wird trotzdem gemeldet

**Lösung**: Backup-Status explizit tracken

```bash
# Nach Zeile 36 einfügen:
BACKUP_SUCCESS="false"

# Zeile 78 ERSETZEN durch:
if [ $STATUS1 -ne 0 ] || [ $STATUS2 -ne 0 ] || [ $STATUS3 -ne 0 ]; then
    abort_with_error "Rsync fehlgeschlagen (S1:$STATUS1, S2:$STATUS2, S3:$STATUS3)"
else
    BACKUP_SUCCESS="true"
fi

# Zeile 129-137 ERSETZEN durch:
# Uptime Kuma Monitoring
if [ "$BACKUP_SUCCESS" = "true" ]; then
    log_msg "➕ Melde Erfolg an Uptime Kuma..."
    if curl -fsS -m 10 --retry 5 "${UPTIME_KUMA_URL}?status=up&msg=OK&ping=" > /dev/null 2>&1; then
        log_msg "✅ Uptime Kuma benachrichtigt"
    else
        log_msg "⚠️ Uptime Kuma konnte nicht erreicht werden"
    fi
else
    log_msg "❌ Backup fehlgeschlagen - kein Signal an Uptime Kuma"
    curl -fsS -m 10 --retry 5 "${UPTIME_KUMA_URL}?status=down&msg=Backup%20failed&ping=" > /dev/null 2>&1 || true
fi
```

---

## 🟡 Priorität 2: WICHTIG - Bald umsetzen

### 2.1 Pre-Flight Checks implementieren

**Problem**: Script startet ohne Validierung der Voraussetzungen

**Lösung**: Umfassende Checks vor Backup-Start

```bash
# Nach Zeile 38 einfügen (vor Container-Erfassung):

log_msg "➕ Führe Pre-Flight Checks durch..."

# Check 1: SSH-Key existiert
if [ ! -f "$SSH_KEY" ]; then
    log_msg "❌ SSH-Key nicht gefunden: $SSH_KEY"
    send_discord "{\"content\": \"❌ **Backup fehlgeschlagen!** SSH-Key fehlt.\"}"
    exit 1
fi

# Check 2: Quellverzeichnisse existieren
for dir in "$SOURCE_STACKS" "$SOURCE_PL_CONF" "$SOURCE_PL_DATA"; do
    if [ ! -d "$dir" ]; then
        log_msg "❌ Quellverzeichnis nicht gefunden: $dir"
        send_discord "{\"content\": \"❌ **Backup fehlgeschlagen!** Verzeichnis fehlt: $dir\"}"
        exit 1
    fi
done

# Check 3: Docker läuft
if ! docker ps > /dev/null 2>&1; then
    log_msg "❌ Docker ist nicht verfügbar"
    send_discord "{\"content\": \"❌ **Backup fehlgeschlagen!** Docker nicht verfügbar.\"}"
    exit 1
fi

# Check 4: Paperless Container existiert
if ! docker ps -a --format '{{.Names}}' | grep -q "paperless-webserver-1"; then
    log_msg "⚠️ WARNUNG: Paperless Container nicht gefunden"
fi

# Check 5: Speicherplatz auf Mac prüfen
MAC_FREE_SPACE=$(ssh -i "$SSH_KEY" "$USER_MAC@$IP_MAC" "df -k '$TARGET_DIR' | tail -1 | awk '{print \$4}'")
MAC_FREE_GB=$((MAC_FREE_SPACE / 1024 / 1024))
if [ $MAC_FREE_GB -lt 10 ]; then
    log_msg "⚠️ WARNUNG: Nur noch ${MAC_FREE_GB}GB frei auf Mac"
    send_discord "{\"content\": \"⚠️ **Backup-Warnung:** Nur noch ${MAC_FREE_GB}GB frei auf Mac!\"}"
fi

log_msg "✅ Pre-Flight Checks bestanden"
```

---

### 2.2 Backup-Rotation für Archive implementieren

**Problem**: 
- Archive werden nie gelöscht
- Speicherplatz läuft irgendwann voll

**Lösung**: Alte Archive automatisch löschen (z.B. älter als 8 Wochen)

```bash
# Zeile 90-94 ERSETZEN durch:
# Sonntags-Archiv mit Rotation
if [ "$(date +%u)" -eq 7 ]; then
    log_msg "➕ Sonntag: Erstelle Archiv..."
    ARCHIVE_NAME="backup_$(date +%F)"
    
    # Archiv erstellen (Hardlinks sparen Speicher)
    ssh -i "$SSH_KEY" "$USER_MAC@$IP_MAC" "mkdir -p $TARGET_DIR/archive && cp -al $TARGET_DIR/latest $TARGET_DIR/archive/$ARCHIVE_NAME"
    
    # Alte Archive löschen (älter als 8 Wochen = 56 Tage)
    log_msg "➕ Lösche Archive älter als 8 Wochen..."
    DELETED=$(ssh -i "$SSH_KEY" "$USER_MAC@$IP_MAC" "find $TARGET_DIR/archive -maxdepth 1 -type d -name 'backup_*' -mtime +56 -exec rm -rf {} \; -print | wc -l")
    
    if [ "$DELETED" -gt 0 ]; then
        log_msg "✅ $DELETED alte Archive gelöscht"
    else
        log_msg "➕ Keine alten Archive zum Löschen gefunden"
    fi
fi
```

---

### 2.3 Container-Management optimieren

**Problem**: 
- Alle Container werden gestoppt, auch wenn nur Paperless relevant ist
- Unnötige Downtime für andere Services

**Lösung**: Nur relevante Container stoppen

```bash
# Am Anfang der Konfiguration (nach Zeile 12) hinzufügen:
CONTAINERS_TO_STOP="paperless-webserver-1 paperless-redis-1 paperless-gotenberg-1 paperless-tika-1"

# Zeile 52-56 ERSETZEN durch:
# Nur relevante Container stoppen
STOPPED_CONTAINERS=""
log_msg "➕ Stoppe Paperless-Container..."
for container in $CONTAINERS_TO_STOP; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        if docker stop "$container" > /dev/null 2>&1; then
            STOPPED_CONTAINERS="$STOPPED_CONTAINERS $container"
            log_msg "  ✓ $container gestoppt"
        else
            log_msg "  ⚠️ $container konnte nicht gestoppt werden"
        fi
    fi
done

# Zeile 97-100 ERSETZEN durch:
# Gestoppte Container wieder starten
if [ -n "$STOPPED_CONTAINERS" ]; then
    log_msg "➕ Starte Container neu..."
    for container in $STOPPED_CONTAINERS; do
        if docker start "$container" > /dev/null 2>&1; then
            log_msg "  ✓ $container gestartet"
        else
            log_msg "  ⚠️ $container konnte nicht gestartet werden!"
        fi
    done
fi

# Cleanup-Funktion anpassen:
cleanup() {
    local exit_code=$?
    if [ -n "$STOPPED_CONTAINERS" ]; then
        log_msg "➕ Cleanup: Starte Container neu..."
        docker start $STOPPED_CONTAINERS > /dev/null 2>&1
    fi
    exit $exit_code
}
```

---

## 🟢 Priorität 3: OPTIONAL - Nice to have

### 3.1 Backup-Verifizierung hinzufügen

**Problem**: Keine Prüfung ob Daten korrekt übertragen wurden

**Lösung**: Checksummen-Vergleich nach Backup

```bash
# Nach Zeile 78 einfügen:
# Backup-Verifizierung (Stichproben)
log_msg "➕ Verifiziere Backup (Stichproben)..."
VERIFY_FILES=5  # Anzahl zufälliger Dateien zum Prüfen

# Zufällige Dateien aus Stacks auswählen und prüfen
SAMPLE_FILES=$(find "$SOURCE_STACKS" -type f | shuf -n $VERIFY_FILES)
VERIFY_FAILED=0

for file in $SAMPLE_FILES; do
    rel_path="${file#$SOURCE_STACKS/}"
    local_sum=$(md5sum "$file" | awk '{print $1}')
    remote_sum=$(ssh -i "$SSH_KEY" "$USER_MAC@$IP_MAC" "md5sum '$TARGET_DIR/latest/stacks/$rel_path' 2>/dev/null | awk '{print \$1}'")
    
    if [ "$local_sum" != "$remote_sum" ]; then
        log_msg "⚠️ Checksummen-Fehler: $rel_path"
        VERIFY_FAILED=$((VERIFY_FAILED + 1))
    fi
done

if [ $VERIFY_FAILED -gt 0 ]; then
    log_msg "⚠️ WARNUNG: $VERIFY_FAILED von $VERIFY_FILES Stichproben fehlgeschlagen"
    send_discord "{\"content\": \"⚠️ **Backup-Warnung:** Verifizierung teilweise fehlgeschlagen ($VERIFY_FAILED/$VERIFY_FILES)\"}"
else
    log_msg "✅ Verifizierung erfolgreich ($VERIFY_FILES Stichproben)"
fi
```

---

### 3.2 Konfiguration externalisieren

**Problem**: Alle Einstellungen sind im Script hardcoded

**Lösung**: Separate Konfigurationsdatei

**Neue Datei**: `/home/markus/.backup_config`
```bash
# Backup-Konfiguration
USER_MAC="markusschweitzer"
IP_MAC="192.168.178.116"
TARGET_DIR="/Users/markusschweitzer/Backups"
SOURCE_STACKS="/opt/stacks"
SOURCE_PL_CONF="/home/markus/paperless-ngx"
SOURCE_PL_DATA="/home/markus/paperless-data"
SSH_KEY="/home/markus/.ssh/id_ed25519"
LOGFILE="/home/markus/backup_log.txt"

# Container-Management
CONTAINERS_TO_STOP="paperless-webserver-1 paperless-redis-1 paperless-gotenberg-1 paperless-tika-1"
PAPERLESS_CONTAINER="paperless-webserver-1"

# Archiv-Rotation
ARCHIVE_RETENTION_DAYS=56  # 8 Wochen

# Verifizierung
VERIFY_SAMPLE_SIZE=5
```

**Im Script** (Zeile 3-12 ersetzen):
```bash
# Konfiguration laden
CONFIG_FILE="/home/markus/.backup_config"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "❌ Konfigurationsdatei nicht gefunden: $CONFIG_FILE"
    exit 1
fi

# Secrets laden
if [ -f "/home/markus/.backup_secrets" ]; then
    source /home/markus/.backup_secrets
else
    echo "❌ Secrets-Datei nicht gefunden!"
    exit 1
fi
```

---

### 3.3 Erweiterte Fehlerbehandlung

**Zusätzliche Verbesserungen**:

```bash
# Rsync mit besseren Optionen
# Zeile 65, 69, 73 erweitern:
sudo rsync -az --delete --stats \
    --timeout=300 \
    --partial \
    --partial-dir=.rsync-partial \
    -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=10" \
    "$SOURCE_STACKS/" "$USER_MAC@$IP_MAC:$TARGET_DIR/latest/stacks"

# Erklärung:
# --timeout=300: Abbruch nach 5 Min Inaktivität
# --partial: Teilweise übertragene Dateien behalten
# --partial-dir: Temporäre Dateien in separatem Verzeichnis
# ConnectTimeout: SSH-Verbindung nach 10s abbrechen
```

---

## 📊 Implementierungs-Reihenfolge

### Phase 1: Kritische Fixes (1-2 Stunden)
1. ✅ Discord Webhook auslagern
2. ✅ Container-Wiederherstellung verbessern
3. ✅ Uptime Kuma Fix

### Phase 2: Wichtige Verbesserungen (2-3 Stunden)
4. ✅ Pre-Flight Checks
5. ✅ Backup-Rotation
6. ✅ Container-Management optimieren

### Phase 3: Optionale Features (2-4 Stunden)
7. ✅ Backup-Verifizierung
8. ✅ Konfiguration externalisieren
9. ✅ Erweiterte Fehlerbehandlung

---

## 🧪 Testing-Checkliste

Nach jeder Änderung testen:

- [ ] Script läuft ohne Fehler durch
- [ ] Container werden korrekt gestoppt und gestartet
- [ ] Backup wird auf Mac erstellt
- [ ] Discord-Benachrichtigung funktioniert
- [ ] Uptime Kuma erhält korrekten Status
- [ ] Fehlerbehandlung funktioniert (Test mit absichtlichem Fehler)
- [ ] Logs sind aussagekräftig
- [ ] Archiv-Rotation funktioniert (Sonntag)

**Test-Befehl**:
```bash
# Dry-Run (ohne tatsächliches Backup)
bash -x backup_to_mac-v5.sh  # Debug-Modus

# Echter Test
sudo ./backup_to_mac-v5.sh
```

---

## 📝 Zusätzliche Empfehlungen

### Monitoring verbessern
- Backup-Größe über Zeit tracken (Trend-Analyse)
- Backup-Dauer überwachen (Performance-Degradation erkennen)
- Fehlerrate tracken

### Dokumentation
- README.md mit Setup-Anleitung erstellen
- Troubleshooting-Guide hinzufügen
- Restore-Prozedur dokumentieren

### Sicherheit
- SSH-Key mit Passphrase schützen (ssh-agent verwenden)
- Backup-Verschlüsselung erwägen (rsync + gpg)
- Regelmäßige Restore-Tests durchführen

---

## 🎯 Zusammenfassung

**Kritische Probleme** (sofort beheben):
1. 🔐 Discord Webhook Sicherheit
2. 🔄 Container-Wiederherstellung
3. ✅ Uptime Kuma Status

**Wichtige Verbesserungen**:
4. ✓ Pre-Flight Checks
5. 🗄️ Backup-Rotation
6. 🐳 Container-Management

**Optional**:
7. 🔍 Backup-Verifizierung
8. ⚙️ Konfiguration externalisieren

**Geschätzter Zeitaufwand**: 5-9 Stunden für vollständige Implementierung

---

*Erstellt am: 2026-03-05*
*Version: 1.0*
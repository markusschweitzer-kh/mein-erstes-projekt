#!/bin/bash

################################################################################
# Raspberry Pi Backup Script v6.0
# Sichert Docker-Stacks und Paperless-Daten auf einen Mac
# 
# Neue Features in v6:
# - Retry-Mechanismus für schlafenden Mac
# - Externalisierte Konfiguration und Secrets
# - Robuste Container-Wiederherstellung mit Cleanup-Trap
# - Pre-Flight Checks vor Backup-Start
# - Optimiertes Container-Management (nur relevante Container)
# - Automatische Archiv-Rotation (8 Wochen)
# - Korrekter Uptime Kuma Status
# - Backup-Verifizierung (Stichproben)
################################################################################

# --- KONFIGURATION LADEN ---
CONFIG_FILE="/home/markus/.backup_config"
SECRETS_FILE="/home/markus/.backup_secrets"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ FEHLER: Konfigurationsdatei nicht gefunden: $CONFIG_FILE"
    echo "Bitte erstelle die Datei mit den notwendigen Einstellungen."
    exit 1
fi

if [ ! -f "$SECRETS_FILE" ]; then
    echo "❌ FEHLER: Secrets-Datei nicht gefunden: $SECRETS_FILE"
    echo "Bitte erstelle die Datei mit Discord Webhook und Uptime Kuma URL."
    exit 1
fi

source "$CONFIG_FILE"
source "$SECRETS_FILE"

# --- LOGGING SETUP ---
exec > >(tee -a "$LOGFILE") 2>&1

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

send_discord() {
    curl -s -H "Content-Type: application/json" -X POST -d "$1" "$DISCORD_WEBHOOK" > /dev/null 2>&1
}

# --- FEHLERBEHANDLUNG ---
BACKUP_SUCCESS="false"
CONTAINERS_STOPPED="false"
STOPPED_CONTAINERS=""

cleanup() {
    local exit_code=$?
    if [ "$CONTAINERS_STOPPED" = "true" ] && [ -n "$STOPPED_CONTAINERS" ]; then
        log_msg "➕ Cleanup: Starte Container neu..."
        docker start $STOPPED_CONTAINERS > /dev/null 2>&1
        log_msg "✅ Container wiederhergestellt"
    fi
    exit $exit_code
}
trap cleanup EXIT INT TERM

abort_with_error() {
    log_msg "❌ KRITISCHER FEHLER: $1"
    BACKUP_SUCCESS="false"
    JSON="{\"content\": \"❌ **Backup abgebrochen!**\", \"embeds\": [{\"description\": \"Grund: $1\", \"color\": 16711680}]}"
    send_discord "$JSON"
    exit 1
}

# --- START ---
START_TIME=$(date +%s)
log_msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_msg "🚀 BACKUP START v6.0: Stacks, Paperless, Immich"
log_msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --- PRE-FLIGHT CHECKS ---
log_msg "➕ Führe Pre-Flight Checks durch..."

# Check 1: SSH-Key existiert
if [ ! -f "$SSH_KEY" ]; then
    abort_with_error "SSH-Key nicht gefunden: $SSH_KEY"
fi
log_msg "  ✓ SSH-Key vorhanden"

# Check 2: Quellverzeichnisse existieren
for dir in "$SOURCE_STACKS" "$SOURCE_PL_CONF" "$SOURCE_PL_DATA" "$SOURCE_IMMICH_BACKUPS"; do
    if [ ! -d "$dir" ]; then
        abort_with_error "Quellverzeichnis nicht gefunden: $dir"
    fi
done
log_msg "  ✓ Alle Quellverzeichnisse vorhanden"

# Check 3: Docker läuft
if ! docker ps > /dev/null 2>&1; then
    abort_with_error "Docker ist nicht verfügbar"
fi
log_msg "  ✓ Docker verfügbar"

# Check 4: Paperless Container existiert
if ! docker ps -a --format '{{.Names}}' | grep -q "$PAPERLESS_CONTAINER"; then
    log_msg "  ⚠️ WARNUNG: Paperless Container '$PAPERLESS_CONTAINER' nicht gefunden"
else
    log_msg "  ✓ Paperless Container gefunden"
fi

log_msg "✅ Pre-Flight Checks bestanden"

# --- MAC ERREICHBARKEIT MIT RETRY ---
log_msg "➕ Prüfe Mac-Erreichbarkeit (mit Retry-Mechanismus)..."

MAC_ONLINE="false"
for attempt in $(seq 1 $MAC_RETRY_ATTEMPTS); do
    log_msg "  Versuch $attempt/$MAC_RETRY_ATTEMPTS: Ping $IP_MAC..."
    
    if ping -c 2 -W 3 "$IP_MAC" > /dev/null 2>&1; then
        MAC_ONLINE="true"
        log_msg "  ✓ Mac ist online!"
        break
    fi
    
    if [ $attempt -lt $MAC_RETRY_ATTEMPTS ]; then
        log_msg "  ⏳ Mac antwortet nicht. Warte ${MAC_RETRY_DELAY}s..."
        sleep $MAC_RETRY_DELAY
    fi
done

if [ "$MAC_ONLINE" = "false" ]; then
    abort_with_error "Mac ($IP_MAC) ist nach $MAC_RETRY_ATTEMPTS Versuchen nicht erreichbar"
fi

# Check 5: Speicherplatz auf Mac prüfen
log_msg "➕ Prüfe Speicherplatz auf Mac..."
MAC_FREE_SPACE=$(ssh -i "$SSH_KEY" -o ConnectTimeout=10 "$USER_MAC@$IP_MAC" "df -k '$TARGET_DIR' | tail -1 | awk '{print \$4}'")
if [ -z "$MAC_FREE_SPACE" ]; then
    log_msg "  ⚠️ WARNUNG: Konnte Speicherplatz nicht prüfen"
else
    MAC_FREE_GB=$((MAC_FREE_SPACE / 1024 / 1024))
    log_msg "  ℹ️ Verfügbarer Speicher: ${MAC_FREE_GB}GB"
    
    if [ $MAC_FREE_GB -lt 10 ]; then
        log_msg "  ⚠️ WARNUNG: Nur noch ${MAC_FREE_GB}GB frei auf Mac!"
        send_discord "{\"content\": \"⚠️ **Backup-Warnung:** Nur noch ${MAC_FREE_GB}GB frei auf Mac!\"}"
    fi
fi

# --- CONTAINER-STATUS ERFASSEN ---
log_msg "➕ Erfasse laufende Container..."
ALL_RUNNING=$(docker ps -q)
CONTAINER_COUNT=$(echo $ALL_RUNNING | wc -w)
log_msg "  ℹ️ Aktuell laufen $CONTAINER_COUNT Container"

# --- PAPERLESS EXPORT ---
if docker ps --format '{{.Names}}' | grep -q "$PAPERLESS_CONTAINER"; then
    log_msg "➕ Paperless-ngx Export läuft..."
    if docker exec "$PAPERLESS_CONTAINER" document_exporter ../export > /dev/null 2>&1; then
        log_msg "  ✓ Paperless Export erfolgreich"
    else
        log_msg "  ⚠️ WARNUNG: Paperless Export fehlgeschlagen"
    fi
else
    log_msg "  ⚠️ Paperless Container nicht aktiv - Export übersprungen"
fi

# --- CONTAINER STOPPEN ---
log_msg "➕ Stoppe relevante Container..."
STOPPED_COUNT=0

for container in $CONTAINERS_TO_STOP; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        if docker stop "$container" > /dev/null 2>&1; then
            STOPPED_CONTAINERS="$STOPPED_CONTAINERS $container"
            STOPPED_COUNT=$((STOPPED_COUNT + 1))
            log_msg "  ✓ $container gestoppt"
        else
            log_msg "  ⚠️ $container konnte nicht gestoppt werden"
        fi
    fi
done

if [ $STOPPED_COUNT -gt 0 ]; then
    CONTAINERS_STOPPED="true"
    log_msg "✅ $STOPPED_COUNT Container gestoppt"
else
    log_msg "  ℹ️ Keine Container zum Stoppen gefunden"
fi

# --- ZIELSTRUKTUR VORBEREITEN ---
log_msg "➕ Bereite Zielstruktur auf Mac vor..."
if ssh -i "$SSH_KEY" -o ConnectTimeout=10 "$USER_MAC@$IP_MAC" \
    "mkdir -p $TARGET_DIR/latest/stacks $TARGET_DIR/latest/paperless-config $TARGET_DIR/latest/paperless-data $TARGET_DIR/latest/immich-backups" 2>/dev/null; then
    log_msg "  ✓ Zielverzeichnisse erstellt"
else
    abort_with_error "Konnte Zielverzeichnisse auf Mac nicht erstellen"
fi

# --- SYNCHRONISATION ---
log_msg "➕ Synchronisiere Daten zum Mac..."

# Sync 1: Stacks
log_msg "  → Stacks..."
OUT1=$(sudo rsync -az --delete --stats \
    --timeout=300 \
    --partial \
    --partial-dir=.rsync-partial \
    -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=10" \
    "$SOURCE_STACKS/" "$USER_MAC@$IP_MAC:$TARGET_DIR/latest/stacks" 2>&1)
STATUS1=$?

# Sync 2: Paperless Config
log_msg "  → Paperless Config..."
OUT2=$(sudo rsync -az --delete --stats \
    --timeout=300 \
    --partial \
    --partial-dir=.rsync-partial \
    -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=10" \
    "$SOURCE_PL_CONF/" "$USER_MAC@$IP_MAC:$TARGET_DIR/latest/paperless-config" 2>&1)
STATUS2=$?

# Sync 3: Paperless Data
log_msg "  → Paperless Data..."
OUT3=$(sudo rsync -az --delete --stats \
    --timeout=300 \
    --partial \
    --partial-dir=.rsync-partial \
    -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=10" \
    "$SOURCE_PL_DATA/" "$USER_MAC@$IP_MAC:$TARGET_DIR/latest/paperless-data" 2>&1)
STATUS3=$?

# Sync 4: Immich Backups
log_msg "  → Immich Backups..."
OUT4=$(sudo rsync -az --delete --stats \
    --timeout=300 \
    --partial \
    --partial-dir=.rsync-partial \
    -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=10" \
    "$SOURCE_IMMICH_BACKUPS/" "$USER_MAC@$IP_MAC:$TARGET_DIR/latest/immich-backups" 2>&1)
STATUS4=$?

# Rsync-Status prüfen
if [ $STATUS1 -ne 0 ] || [ $STATUS2 -ne 0 ] || [ $STATUS3 -ne 0 ] || [ $STATUS4 -ne 0 ]; then
    abort_with_error "Rsync fehlgeschlagen (Stacks:$STATUS1, Config:$STATUS2, Data:$STATUS3, Immich:$STATUS4)"
else
    BACKUP_SUCCESS="true"
    log_msg "✅ Alle Daten erfolgreich synchronisiert"
fi

# --- STATISTIKEN AUSWERTEN ---
extract_val() { echo -e "$1\n$2\n$3\n$4" | grep "$5" | awk '{sum+=$NF} END {print sum+0}'; }
extract_size() { echo -e "$1\n$2\n$3\n$4" | grep "$5" | awk '{sum+=$4} END {print sum+0}'; }

NEW_FILES=$(extract_val "$OUT1" "$OUT2" "$OUT3" "$OUT4" "Number of created files")
MOD_FILES=$(extract_val "$OUT1" "$OUT2" "$OUT3" "$OUT4" "Number of regular files transferred")
DEL_FILES=$(extract_val "$OUT1" "$OUT2" "$OUT3" "$OUT4" "Number of deleted files")
TOTAL_SIZE_BYTES=$(extract_size "$OUT1" "$OUT2" "$OUT3" "$OUT4" "Total file size")
TOTAL_SIZE_MB=$(echo "scale=2; $TOTAL_SIZE_BYTES / 1024 / 1024" | bc 2>/dev/null || echo "0")

log_msg "  ℹ️ Statistik: $NEW_FILES neu, $MOD_FILES geändert, $DEL_FILES gelöscht, ${TOTAL_SIZE_MB}MB gesamt"

# --- BACKUP-VERIFIZIERUNG (OPTIONAL) ---
if [ "$ENABLE_VERIFICATION" = "true" ]; then
    log_msg "➕ Verifiziere Backup (Stichproben: $VERIFY_SAMPLE_SIZE Dateien)..."
    
    VERIFY_FAILED=0
    SAMPLE_FILES=$(find "$SOURCE_STACKS" -type f 2>/dev/null | shuf -n $VERIFY_SAMPLE_SIZE 2>/dev/null)
    
    for file in $SAMPLE_FILES; do
        rel_path="${file#$SOURCE_STACKS/}"
        local_sum=$(md5sum "$file" 2>/dev/null | awk '{print $1}')
        remote_sum=$(ssh -i "$SSH_KEY" "$USER_MAC@$IP_MAC" "md5sum '$TARGET_DIR/latest/stacks/$rel_path' 2>/dev/null | awk '{print \$1}'")
        
        if [ "$local_sum" != "$remote_sum" ] || [ -z "$remote_sum" ]; then
            VERIFY_FAILED=$((VERIFY_FAILED + 1))
        fi
    done
    
    if [ $VERIFY_FAILED -gt 0 ]; then
        log_msg "  ⚠️ WARNUNG: $VERIFY_FAILED von $VERIFY_SAMPLE_SIZE Stichproben fehlgeschlagen"
    else
        log_msg "  ✓ Verifizierung erfolgreich"
    fi
fi

# --- SONNTAGS-ARCHIV MIT ROTATION ---
if [ "$(date +%u)" -eq 7 ]; then
    log_msg "➕ Sonntag: Erstelle Archiv..."
    ARCHIVE_NAME="backup_$(date +%F)"
    
    # Archiv erstellen (Hardlinks sparen Speicher)
    if ssh -i "$SSH_KEY" "$USER_MAC@$IP_MAC" \
        "mkdir -p $TARGET_DIR/archive && cp -al $TARGET_DIR/latest $TARGET_DIR/archive/$ARCHIVE_NAME" 2>/dev/null; then
        log_msg "  ✓ Archiv erstellt: $ARCHIVE_NAME"
    else
        log_msg "  ⚠️ WARNUNG: Archiv konnte nicht erstellt werden"
    fi
    
    # Alte Archive löschen (älter als ARCHIVE_RETENTION_DAYS)
    log_msg "  → Lösche Archive älter als $ARCHIVE_RETENTION_DAYS Tage..."
    DELETED=$(ssh -i "$SSH_KEY" "$USER_MAC@$IP_MAC" \
        "find $TARGET_DIR/archive -maxdepth 1 -type d -name 'backup_*' -mtime +$ARCHIVE_RETENTION_DAYS -exec rm -rf {} \; -print 2>/dev/null | wc -l")
    
    if [ "$DELETED" -gt 0 ]; then
        log_msg "  ✓ $DELETED alte Archive gelöscht"
    else
        log_msg "  ℹ️ Keine alten Archive zum Löschen gefunden"
    fi
fi

# --- CONTAINER WIEDER STARTEN ---
if [ "$CONTAINERS_STOPPED" = "true" ] && [ -n "$STOPPED_CONTAINERS" ]; then
    log_msg "➕ Starte Container neu..."
    STARTED_COUNT=0
    
    for container in $STOPPED_CONTAINERS; do
        if docker start "$container" > /dev/null 2>&1; then
            STARTED_COUNT=$((STARTED_COUNT + 1))
            log_msg "  ✓ $container gestartet"
        else
            log_msg "  ⚠️ $container konnte nicht gestartet werden!"
        fi
    done
    
    if [ $STARTED_COUNT -eq $STOPPED_COUNT ]; then
        CONTAINERS_STOPPED="false"
        log_msg "✅ Alle Container erfolgreich gestartet"
    else
        log_msg "⚠️ WARNUNG: Nur $STARTED_COUNT von $STOPPED_COUNT Containern gestartet"
    fi
fi

# --- ABSCHLUSS ---
DURATION=$(( $(date +%s) - START_TIME ))
DURATION_MIN=$(echo "scale=1; $DURATION / 60" | bc 2>/dev/null || echo "0")

log_msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_msg "✅ BACKUP ERFOLGREICH BEENDET (${DURATION}s / ${DURATION_MIN}min)"
log_msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --- DISCORD BENACHRICHTIGUNG ---
JSON_DATA="
{
  \"content\": \"✅ **Backup erfolgreich abgeschlossen!**\",
  \"embeds\": [{
    \"title\": \"Backup Statistiken (Pi 5 → Mac)\",
    \"color\": 3066993,
    \"fields\": [
      {\"name\": \"⏱️ Dauer\", \"value\": \"${DURATION}s (${DURATION_MIN}min)\", \"inline\": true},
      {\"name\": \"💾 Gesamtgröße\", \"value\": \"~${TOTAL_SIZE_MB} MB\", \"inline\": true},
      {\"name\": \"📁 Neue Dateien\", \"value\": \"$NEW_FILES\", \"inline\": true},
      {\"name\": \"✏️ Geändert\", \"value\": \"$MOD_FILES\", \"inline\": true},
      {\"name\": \"🗑️ Gelöscht\", \"value\": \"${DEL_FILES}\", \"inline\": true},
      {\"name\": \"🔄 Mac Versuche\", \"value\": \"$attempt von $MAC_RETRY_ATTEMPTS\", \"inline\": true}
    ],
    \"footer\": {\"text\": \"v6.0 | Quellen: stacks, paperless-config, paperless-data, immich-backups\"},
    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
  }]
}"

send_discord "$JSON_DATA"

# --- UPTIME KUMA MONITORING ---
if [ "$BACKUP_SUCCESS" = "true" ]; then
    log_msg "➕ Melde Erfolg an Uptime Kuma..."
    if curl -fsS -m 10 --retry 3 "${UPTIME_KUMA_URL}?status=up&msg=OK&ping=$DURATION" > /dev/null 2>&1; then
        log_msg "  ✓ Uptime Kuma benachrichtigt"
    else
        log_msg "  ⚠️ Uptime Kuma konnte nicht erreicht werden"
    fi
else
    log_msg "❌ Backup fehlgeschlagen - melde Fehler an Uptime Kuma"
    curl -fsS -m 10 --retry 3 "${UPTIME_KUMA_URL}?status=down&msg=Backup%20failed&ping=" > /dev/null 2>&1 || true
fi

log_msg "🏁 Script beendet"
exit 0

# Made with Bob

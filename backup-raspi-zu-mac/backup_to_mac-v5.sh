#!/bin/bash

# --- KONFIGURATION ---
USER_MAC="markusschweitzer"
IP_MAC="192.168.178.116"
TARGET_DIR="/Users/markusschweitzer/Backups"
SOURCE_STACKS="/opt/stacks"
SOURCE_PL_CONF="/home/markus/paperless-ngx"
SOURCE_PL_DATA="/home/markus/paperless-data"
SSH_KEY="/home/markus/.ssh/id_ed25519"
LOGFILE="/home/markus/backup_log.txt"
DISCORD_WEBHOOK="https://discord.com/api/webhooks/1478348422645022771/xpydTfLeO5WOzIHbg3dpP9Fbtq9zvT5zM6R_AEmT9FFg4SjkrU9mGPyP3WyLMwYRcdUU"

# --- LOGGING SETUP ---
exec > >(tee -a "$LOGFILE") 2>&1

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

send_discord() {
    curl -s -H "Content-Type: application/json" -X POST -d "$1" "$DISCORD_WEBHOOK" > /dev/null
}

abort_with_error() {
    log_msg "❌ KRITISCHER FEHLER: $1"
    if [ -n "$RUNNING_CONTAINERS" ]; then
        log_msg "➕ Versuche Container nach Fehler zu retten..."
        docker start $RUNNING_CONTAINERS > /dev/null 2>&1
    fi
    JSON="{\"content\": \"❌ **Backup abgebrochen!**\", \"embeds\": [{\"description\": \"Grund: $1\nContainer wurden neu gestartet.\", \"color\": 16711680}]}"
    send_discord "$JSON"
    exit 1
}

# --- START ---
START_TIME=$(date +%s)
log_msg "--- 🚀 BACKUP START: Stacks, Paperless-Config & Data ---"

# 1. Mac Erreichbarkeit
if ! ping -c 1 -W 2 "$IP_MAC" > /dev/null; then
    log_msg "❌ Mac ist offline. Abbruch."
    send_discord "{\"content\": \"❌ **Backup fehlgeschlagen!** Mac ($IP_MAC) ist offline.\"}"
    exit 1
fi

# 2. Paperless Export
log_msg "➕ Paperless-ngx Export läuft..."
docker exec paperless-webserver-1 document_exporter ../export > /dev/null 2>&1

# 3. Container stoppen
RUNNING_CONTAINERS=$(docker ps -q)
if [ -n "$RUNNING_CONTAINERS" ]; then
    log_msg "➕ Stoppe Container..."
    docker stop $RUNNING_CONTAINERS > /dev/null
fi

# 4. Synchronisation (Drei Durchgänge)
log_msg "➕ Synchronisiere Daten zum Mac..."

# Zielstruktur auf Mac vorbereiten
ssh -i "$SSH_KEY" "$USER_MAC@$IP_MAC" "mkdir -p $TARGET_DIR/latest/stacks $TARGET_DIR/latest/paperless-config $TARGET_DIR/latest/paperless-data"

# Sync 1: Stacks
OUT1=$(sudo rsync -az --delete --stats -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" "$SOURCE_STACKS/" "$USER_MAC@$IP_MAC:$TARGET_DIR/latest/stacks")
STATUS1=$?

# Sync 2: Paperless Config
OUT2=$(sudo rsync -az --delete --stats -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" "$SOURCE_PL_CONF/" "$USER_MAC@$IP_MAC:$TARGET_DIR/latest/paperless-config")
STATUS2=$?

# Sync 3: Paperless Data
OUT3=$(sudo rsync -az --delete --stats -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" "$SOURCE_PL_DATA/" "$USER_MAC@$IP_MAC:$TARGET_DIR/latest/paperless-data")
STATUS3=$?

if [ $STATUS1 -ne 0 ] || [ $STATUS2 -ne 0 ] || [ $STATUS3 -ne 0 ]; then
    abort_with_error "Rsync fehlgeschlagen (S1:$STATUS1, S2:$STATUS2, S3:$STATUS3)"
fi

# Statistiken kombinieren
extract_val() { echo -e "$1\n$2\n$3" | grep "$4" | awk '{sum+=$NF} END {print sum}'; }
extract_size() { echo -e "$1\n$2\n$3" | grep "$4" | awk '{sum+=$4} END {print sum}'; }

NEW_FILES=$(extract_val "$OUT1" "$OUT2" "$OUT3" "Number of created files")
MOD_FILES=$(extract_val "$OUT1" "$OUT2" "$OUT3" "Number of regular files transferred")
DEL_FILES=$(extract_val "$OUT1" "$OUT2" "$OUT3" "Number of deleted files")
TOTAL_SIZE_BYTES=$(extract_size "$OUT1" "$OUT2" "$OUT3" "Total file size")
TOTAL_SIZE_MB=$(echo "scale=2; $TOTAL_SIZE_BYTES / 1024 / 1024" | bc)

# 5. Sonntags-Archiv
if [ "$(date +%u)" -eq 7 ]; then
    log_msg "➕ Sonntag: Erstelle Archiv..."
    ssh -i "$SSH_KEY" "$USER_MAC@$IP_MAC" "mkdir -p $TARGET_DIR/archive && cp -al $TARGET_DIR/latest $TARGET_DIR/archive/backup_$(date +%F)"
fi

# 6. Container wieder starten
if [ -n "$RUNNING_CONTAINERS" ]; then
    log_msg "➕ Starte Container neu..."
    docker start $RUNNING_CONTAINERS > /dev/null
fi

# 7. Abschluss & Discord
DURATION=$(( $(date +%s) - START_TIME ))
log_msg "--- ✅ BACKUP BEENDET (${DURATION}s) ---"

JSON_DATA="
{
  \"content\": \"✅ **Backup erfolgreich abgeschlossen!**\",
  \"embeds\": [{
    \"title\": \"Backup Statistiken (Pi 5 -> Mac)\",
    \"color\": 3066993,
    \"fields\": [
      {\"name\": \"Dauer\", \"value\": \"${DURATION}s\", \"inline\": true},
      {\"name\": \"Gesamtgröße\", \"value\": \"~${TOTAL_SIZE_MB} MB\", \"inline\": true},
      {\"name\": \"Neue Dateien\", \"value\": \"$NEW_FILES\", \"inline\": true},
      {\"name\": \"Geändert\", \"value\": \"$MOD_FILES\", \"inline\": true},
      {\"name\": \"Gelöscht\", \"value\": \"${DEL_FILES:-0}\", \"inline\": true}
    ],
    \"footer\": {\"text\": \"Quellen: stacks, paperless-config, paperless-data\"},
    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
  }]
}"

send_discord "$JSON_DATA"




# PRÜFUNG: War der letzte Befehl (das Backup) erfolgreich?
if [ $? -eq 0 ]; then
    echo "Backup erfolgreich. Melde Status an Uptime Kuma..."
    # Die URL von Uptime Kuma hier einfügen:
    curl -fsS -m 10 --retry 5 "http://192.168.178.11:3001/api/push/0X2vNKiLrs?status=up&msg=OK&ping="
else
    echo "Backup fehlgeschlagen! Kein Signal an Uptime Kuma gesendet."
    # Optional: Hier könntest du eine Discord-Message für "Fehler" senden
fi

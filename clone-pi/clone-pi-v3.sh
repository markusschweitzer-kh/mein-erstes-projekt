#!/bin/bash

# ==========================================
# 1. KONFIGURATION
# ==========================================
SOURCE="sda"
TARGET="sdb"
TARGET_BOOT="sdb1"           # Boot-Partition der Backup-Platte
TARGET_ROOT="sdb2"           # Haupt-Partition der Backup-Platte
CHECK_PATH="/home/pi/docker"  # Dein wichtiger Docker-Ordner
LOGFILE="/var/log/pi-clone.log"
WEBHOOK_URL="https://discord.com/api/webhooks/1478348388335620198/2A7uY9Ujrk5OgxICiq0kxwAW9JsyhYKb-uk3cEfwKjLyEK4tjNDhpSaZiSxw_qkoL7C7" # Optional

export RSYNC_OPTIONS="--info=progress2 --human-readable"

# Hilfsfunktionen
log() { echo "$1" | tee -a "$LOGFILE"; }
notify() { [ ! -z "$WEBHOOK_URL" ] && curl -H "Content-Type: application/json" -d "{\"content\": \"$1\"}" "$WEBHOOK_URL" > /dev/null 2>&1; }

# ==========================================
# 2. VORBEREITUNG (Docker Stop)
# ==========================================
{
log "=========================================="
log "BACKUP START: $(date)"
START_TIME=$(date +%s)

log ">>> Stoppe Docker-Container..."
RUNNING_CONTAINERS=$(docker ps -q)
[ ! -z "$RUNNING_CONTAINERS" ] && docker stop $RUNNING_CONTAINERS

# ==========================================
# 3. KLONEN (rpi-clone)
# ==========================================
log ">>> Starte Klonvorgang (sda -> sdb)..."
sudo -E rpi-clone $TARGET -f -U -v

# ==========================================
# 4. REPARATUR (Boot-Fix)
# ==========================================
log ">>> Starte PARTUUID Auto-Korrektur..."
MOUNT_POINT="/mnt/backup_repair"
sudo mkdir -p $MOUNT_POINT

if sudo mount /dev/$TARGET_ROOT $MOUNT_POINT; then
    sudo mount /dev/$TARGET_BOOT $MOUNT_POINT/boot
    
    # Echte Hardware-IDs auslesen
    REAL_ID_BOOT=$(lsblk -dno PARTUUID /dev/$TARGET_BOOT)
    REAL_ID_ROOT=$(lsblk -dno PARTUUID /dev/$TARGET_ROOT)
    
    log "Fixing: Boot-ID=$REAL_ID_BOOT, Root-ID=$REAL_ID_ROOT"

    # cmdline.txt korrigieren
    sudo sed -i "s/PARTUUID=[^ ]*/PARTUUID=$REAL_ID_ROOT/" $MOUNT_POINT/boot/cmdline.txt
    
    # fstab korrigieren
    sudo sed -i "s|^PARTUUID=[^ ]*\( \+/boot\)|PARTUUID=$REAL_ID_BOOT\1|" $MOUNT_POINT/etc/fstab
    sudo sed -i "s|^PARTUUID=[^ ]*\( \+/ \)|PARTUUID=$REAL_ID_ROOT\1|" $MOUNT_POINT/etc/fstab
    
    # Verifikation des Ordners
    if [ -d "$MOUNT_POINT$CHECK_PATH" ]; then
        log "VERIFIKATION: OK ($CHECK_PATH gefunden)."
    else
        log "WARNUNG: $CHECK_PATH fehlt!"
        notify "⚠️ Backup unvollständig: $CHECK_PATH fehlt."
    fi

    sudo umount $MOUNT_POINT/boot
    sudo umount $MOUNT_POINT
    log ">>> Reparatur & Verifikation abgeschlossen."
else
    log "FEHLER: Konnte Backup nicht zur Reparatur mounten!"
    notify "🚨 Backup-Fehler: Mount fehlgeschlagen."
fi

# ==========================================
# 5. ABSCHLUSS (Docker Start)
# ==========================================
log ">>> Starte Docker-Container neu..."
[ ! -z "$RUNNING_CONTAINERS" ] && docker start $RUNNING_CONTAINERS

END_TIME=$(date +%s)
log "Dauer: $(( (END_TIME - START_TIME) / 60 )) Min."
log "=========================================="
} | tee -a $LOGFILE

# Log kürzen
tail -n 1000 "$LOGFILE" > "$LOGFILE.tmp" && mv "$LOGFILE.tmp" "$LOGFILE"

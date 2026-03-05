# 🚀 Quick Start Guide - Backup-Script Verbesserungen

## ⚡ Schnellstart für kritische Fixes (30 Minuten)

### 1️⃣ Discord Webhook sichern (10 Min)

```bash
# Auf dem Raspberry Pi ausführen:

# Schritt 1: Secrets-Datei erstellen
cat > /home/markus/.backup_secrets << 'EOF'
DISCORD_WEBHOOK="https://discord.com/api/webhooks/1478348422645022771/xpydTfLeO5WOzIHbg3dpP9Fbtq9zvT5zM6R_AEmT9FFg4SjkrU9mGPyP3WyLMwYRcdUU"
UPTIME_KUMA_URL="http://192.168.178.11:3001/api/push/0X2vNKiLrs"
EOF

# Schritt 2: Berechtigungen setzen
chmod 600 /home/markus/.backup_secrets

# Schritt 3: .gitignore erstellen (falls Git verwendet wird)
echo ".backup_secrets" >> .gitignore
```

**Im Script ändern:**
- Zeile 12 löschen
- Nach Zeile 13 einfügen:
```bash
# Secrets laden
if [ -f "/home/markus/.backup_secrets" ]; then
    source /home/markus/.backup_secrets
else
    log_msg "❌ FEHLER: Secrets-Datei nicht gefunden!"
    exit 1
fi
```

---

### 2️⃣ Container-Wiederherstellung fixen (10 Min)

**Nach Zeile 38 einfügen:**
```bash
# Container-Status SOFORT erfassen
RUNNING_CONTAINERS=$(docker ps -q)
CONTAINER_COUNT=$(echo $RUNNING_CONTAINERS | wc -w)
log_msg "➕ Laufende Container erfasst: $CONTAINER_COUNT"

# Cleanup-Funktion
CONTAINERS_STOPPED="false"
cleanup() {
    if [ "$CONTAINERS_STOPPED" = "true" ]; then
        log_msg "➕ Cleanup: Starte Container neu..."
        docker start $RUNNING_CONTAINERS > /dev/null 2>&1
    fi
}
trap cleanup EXIT INT TERM
```

**Zeile 52-56 ersetzen durch:**
```bash
# Container stoppen
if [ -n "$RUNNING_CONTAINERS" ]; then
    log_msg "➕ Stoppe $CONTAINER_COUNT Container..."
    docker stop $RUNNING_CONTAINERS > /dev/null && CONTAINERS_STOPPED="true"
fi
```

**Zeile 97-100 ersetzen durch:**
```bash
# Container wieder starten
if [ "$CONTAINERS_STOPPED" = "true" ]; then
    log_msg "➕ Starte Container neu..."
    docker start $RUNNING_CONTAINERS > /dev/null && CONTAINERS_STOPPED="false"
fi
```

---

### 3️⃣ Uptime Kuma Status fixen (10 Min)

**Nach Zeile 36 einfügen:**
```bash
BACKUP_SUCCESS="false"
```

**Zeile 78 ändern zu:**
```bash
if [ $STATUS1 -ne 0 ] || [ $STATUS2 -ne 0 ] || [ $STATUS3 -ne 0 ]; then
    abort_with_error "Rsync fehlgeschlagen (S1:$STATUS1, S2:$STATUS2, S3:$STATUS3)"
else
    BACKUP_SUCCESS="true"
fi
```

**Zeile 129-137 ersetzen durch:**
```bash
# Uptime Kuma Monitoring
if [ "$BACKUP_SUCCESS" = "true" ]; then
    log_msg "➕ Melde Erfolg an Uptime Kuma..."
    curl -fsS -m 10 --retry 5 "${UPTIME_KUMA_URL}?status=up&msg=OK&ping=" > /dev/null 2>&1
else
    log_msg "❌ Backup fehlgeschlagen"
    curl -fsS -m 10 --retry 5 "${UPTIME_KUMA_URL}?status=down&msg=Backup%20failed&ping=" > /dev/null 2>&1 || true
fi
```

---

## ✅ Test-Checkliste

Nach den Änderungen testen:

```bash
# 1. Syntax-Check
bash -n backup_to_mac-v5.sh

# 2. Dry-Run (mit Debug-Output)
bash -x backup_to_mac-v5.sh 2>&1 | head -50

# 3. Echter Test
sudo ./backup_to_mac-v5.sh
```

**Prüfen:**
- [ ] Script startet ohne Fehler
- [ ] Secrets werden geladen
- [ ] Container werden erfasst
- [ ] Backup läuft durch
- [ ] Discord-Nachricht kommt an
- [ ] Uptime Kuma zeigt "OK"
- [ ] Container laufen wieder

---

## 🔥 Notfall-Rollback

Falls etwas schiefgeht:

```bash
# Backup des Original-Scripts erstellen (VORHER!)
cp backup_to_mac-v5.sh backup_to_mac-v5.sh.backup

# Rollback bei Problemen
cp backup_to_mac-v5.sh.backup backup_to_mac-v5.sh

# Container manuell starten (falls nötig)
docker start $(docker ps -aq)
```

---

## 📋 Vollständige Implementierungs-Checkliste

### Phase 1: Kritisch (30 Min) ✅
- [ ] Discord Webhook sichern
- [ ] Container-Wiederherstellung fixen
- [ ] Uptime Kuma Status fixen
- [ ] Testen

### Phase 2: Wichtig (4 Std)
- [ ] Pre-Flight Checks implementieren
- [ ] Backup-Rotation hinzufügen
- [ ] Container-Management optimieren
- [ ] Testen

### Phase 3: Optional (4 Std)
- [ ] Backup-Verifizierung
- [ ] Config externalisieren
- [ ] Erweiterte Fehlerbehandlung
- [ ] Testen

---

## 🆘 Häufige Probleme

### Problem: "Secrets-Datei nicht gefunden"
```bash
# Lösung: Datei erstellen und Berechtigungen prüfen
ls -la /home/markus/.backup_secrets
chmod 600 /home/markus/.backup_secrets
```

### Problem: "Container starten nicht"
```bash
# Lösung: Manuell starten
docker ps -a  # Alle Container anzeigen
docker start CONTAINER_ID
```

### Problem: "Discord-Nachricht kommt nicht an"
```bash
# Lösung: Webhook testen
curl -H "Content-Type: application/json" \
  -X POST \
  -d '{"content": "Test"}' \
  "$DISCORD_WEBHOOK"
```

### Problem: "Rsync schlägt fehl"
```bash
# Lösung: SSH-Verbindung testen
ssh -i /home/markus/.ssh/id_ed25519 markusschweitzer@192.168.178.116 "echo OK"
```

---

## 📞 Support-Informationen

**Log-Datei prüfen:**
```bash
tail -f /home/markus/backup_log.txt
```

**Letzte 50 Zeilen:**
```bash
tail -50 /home/markus/backup_log.txt
```

**Nach Fehlern suchen:**
```bash
grep "❌" /home/markus/backup_log.txt
```

---

## 🎯 Nächste Schritte

Nach erfolgreicher Implementierung der kritischen Fixes:

1. **Monitoring einrichten**: Backup-Statistiken über Zeit tracken
2. **Dokumentation**: README.md mit Setup-Anleitung erstellen
3. **Restore-Test**: Backup-Wiederherstellung testen
4. **Automatisierung**: Cron-Job einrichten (falls noch nicht vorhanden)

**Empfohlener Cron-Job:**
```bash
# Täglich um 2:00 Uhr
0 2 * * * /home/markus/backup_to_mac-v5.sh >> /home/markus/backup_cron.log 2>&1
```

---

*Viel Erfolg bei der Implementierung! 🚀*
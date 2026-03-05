# 🎉 Release Notes v6.1 - Portabilität

**Release-Datum:** 2026-03-05  
**Version:** 6.1  
**Typ:** Feature-Update

---

## 🎯 Hauptfeature: Start aus jedem Verzeichnis

Das Backup-Script ist jetzt **vollständig portabel** und kann aus jedem beliebigen Verzeichnis gestartet werden!

### ✨ Was ist neu?

#### 1. Intelligente Konfigurationssuche

Das Script sucht automatisch nach `.backup_config` und `.backup_secrets` in:

```
1. Im gleichen Verzeichnis wie das Script
   → /pfad/zum/script/.backup_config
   
2. Im Home-Verzeichnis des ausführenden Benutzers
   → $HOME/.backup_config
   
3. In /home/markus/ (Fallback für Kompatibilität)
   → /home/markus/.backup_config
```

#### 2. Flexible Installation

Du kannst das Script jetzt überall ablegen:

```bash
# Option 1: Im Home-Verzeichnis (wie bisher)
/home/markus/backup_to_mac-v6.sh

# Option 2: In /usr/local/bin (systemweit)
/usr/local/bin/backup_to_mac-v6.sh

# Option 3: In /opt (für Anwendungen)
/opt/backup-scripts/backup_to_mac-v6.sh

# Option 4: Mit Symlink
ln -s /pfad/zum/backup_to_mac-v6.sh /usr/local/bin/backup
```

#### 3. Cron-Job mit absolutem Pfad

**Empfohlener Cron-Job für tägliches Backup um 2:00 Uhr:**

```bash
sudo crontab -e

# Füge diese Zeile hinzu:
0 2 * * * /home/markus/backup_to_mac-v6.sh >> /var/log/backup_cron.log 2>&1
```

**Alternative Varianten:**

```bash
# Mit Script in /usr/local/bin
0 2 * * * /usr/local/bin/backup_to_mac-v6.sh >> /var/log/backup_cron.log 2>&1

# Mit Script in /opt
0 2 * * * /opt/backup-scripts/backup_to_mac-v6.sh >> /var/log/backup_cron.log 2>&1

# Mit Symlink
0 2 * * * /usr/local/bin/backup >> /var/log/backup_cron.log 2>&1
```

**💡 Tipp:** Das Script findet die Konfigurationsdateien automatisch, egal wo es liegt!

---

## 🔧 Technische Änderungen

### Neue Funktionen im Script

```bash
# Automatische Erkennung des Script-Verzeichnisses
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# Intelligente Suche nach Konfigurationsdateien
find_config_file() {
    # Sucht in: Script-Dir → $HOME → /home/markus
}
```

### Neue Dateien

- **`.backup_secrets.template`** - Vorlage für Secrets-Datei
- **`.gitignore`** - Schutz vor versehentlichem Commit von Secrets
- **`CHANGELOG.md`** - Vollständige Versionshistorie
- **`RELEASE_NOTES_v6.1.md`** - Diese Datei

---

## 📦 Installation & Upgrade

### Neu-Installation

```bash
# 1. Script herunterladen
cd /home/markus
git clone <repo-url> backup-raspi-zu-mac
cd backup-raspi-zu-mac

# 2. Konfiguration erstellen
cp .backup_config ~/.backup_config
cp .backup_secrets.template ~/.backup_secrets
nano ~/.backup_secrets  # URLs eintragen

# 3. Berechtigungen setzen
chmod 644 ~/.backup_config
chmod 600 ~/.backup_secrets
chmod +x backup_to_mac-v6.sh

# 4. Testen
sudo ./backup_to_mac-v6.sh

# 5. Cron-Job einrichten
sudo crontab -e
# Zeile hinzufügen: 0 2 * * * /home/markus/backup-raspi-zu-mac/backup_to_mac-v6.sh >> /var/log/backup_cron.log 2>&1
```

### Upgrade von v6.0

```bash
# 1. Backup der alten Version
cp backup_to_mac-v6.sh backup_to_mac-v6.0.backup

# 2. Neue Version herunterladen
git pull

# 3. Konfiguration bleibt unverändert (bereits in /home/markus/)

# 4. Testen
sudo ./backup_to_mac-v6.sh

# 5. Cron-Job aktualisieren (optional - mit absolutem Pfad)
sudo crontab -e
```

**✅ Abwärtskompatibel:** Bestehende v6.0-Installationen funktionieren weiterhin!

---

## ✅ Vorteile

| Feature | v6.0 | v6.1 | Vorteil |
|---------|------|------|---------|
| **Start-Verzeichnis** | Nur aus Script-Dir | Von überall | ✅ Flexibilität |
| **Cron-Job** | Relativer Pfad | Absoluter Pfad | ✅ Zuverlässigkeit |
| **Installation** | Nur /home/markus | Beliebig | ✅ Portabilität |
| **Symlinks** | Nicht unterstützt | Funktionieren | ✅ Convenience |
| **Multi-User** | Eingeschränkt | Vollständig | ✅ Skalierbarkeit |

---

## 🧪 Testing

### Test 1: Start aus verschiedenen Verzeichnissen

```bash
# Test 1: Aus Home-Verzeichnis
cd ~
sudo /home/markus/backup-raspi-zu-mac/backup_to_mac-v6.sh

# Test 2: Aus /tmp
cd /tmp
sudo /home/markus/backup-raspi-zu-mac/backup_to_mac-v6.sh

# Test 3: Mit Symlink
sudo ln -s /home/markus/backup-raspi-zu-mac/backup_to_mac-v6.sh /usr/local/bin/backup
sudo /usr/local/bin/backup
```

### Test 2: Konfigurationssuche

```bash
# Script zeigt beim Start die verwendeten Pfade an:
ℹ️  Script-Verzeichnis: /home/markus/backup-raspi-zu-mac
ℹ️  Konfiguration: /home/markus/.backup_config
ℹ️  Secrets: /home/markus/.backup_secrets
```

---

## 🐛 Bekannte Probleme

Keine bekannten Probleme in v6.1.

---

## 📞 Support

Bei Fragen oder Problemen:

1. **Log-Datei prüfen:** `tail -50 /var/log/backup_cron.log`
2. **Debug-Modus:** `sudo bash -x backup_to_mac-v6.sh`
3. **Dokumentation:** Siehe `README_v6.md`
4. **Rollback:** Verwende `backup_to_mac-v6.0.backup`

---

## 🎯 Nächste Schritte

Nach dem Upgrade:

1. ✅ Cron-Job mit absolutem Pfad aktualisieren
2. ✅ Backup-Test durchführen
3. ✅ Log-Dateien überwachen
4. ✅ Optional: Script nach `/usr/local/bin` verschieben

---

**Happy Backing Up! 🚀**

*Version 6.1 - Portabilität für maximale Flexibilität*
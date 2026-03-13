# 🚀 Schnellstart-Anleitung

## Für eilige Administratoren

### 1️⃣ Lokal auf der VM ausführen (empfohlen für erste Tests)

```bash
# In das Verzeichnis wechseln
cd /path/to/ip-change

# Dry-Run (zeigt nur was passieren würde)
ansible-playbook -i localhost, -c local network-update.yml --check --diff

# Wenn alles gut aussieht, tatsächlich ausführen
ansible-playbook -i localhost, -c local network-update.yml
```

### 2️⃣ Remote auf einer VM ausführen

```bash
# Inventory anpassen
nano inventory.ini
# Trage deine VM ein, z.B.:
# itcoavp147.itc.ibm.com ansible_host=9.155.64.147 ansible_user=root

# SSH-Zugriff testen
ansible -i inventory.ini redhat_vms -m ping

# Dry-Run
ansible-playbook -i inventory.ini network-update.yml --check --diff

# Ausführen
ansible-playbook -i inventory.ini network-update.yml
```

### 3️⃣ Mehrere VMs gleichzeitig

```bash
# Alle VMs in inventory.ini eintragen
nano inventory.ini

# Alle auf einmal (vorsichtig!)
ansible-playbook -i inventory.ini network-update.yml

# Oder nacheinander
ansible-playbook -i inventory.ini network-update.yml --forks 1
```

## ⚠️ Wichtige Hinweise

1. **Immer zuerst Dry-Run:** `--check --diff`
2. **Backups werden automatisch erstellt** in `backups/`
3. **Logs werden gespeichert** in `logs/`
4. **CSV-Datei muss korrekt sein** - siehe [`ip-change.csv`](ip-change.csv:1)

## 🆘 Wenn etwas schief geht

```bash
# Rollback-Script verwenden
./rollback.sh hostname_20260313_083000

# Oder manuell
cd backups/hostname_20260313_083000
sudo cp hostname /etc/hostname
sudo cp ifcfg-* /etc/sysconfig/network-scripts/
sudo systemctl restart NetworkManager
```

## 📋 Checkliste vor der Ausführung

- [ ] CSV-Datei [`ip-change.csv`](ip-change.csv:1) ist aktuell
- [ ] Hostname der VM ist in CSV vorhanden
- [ ] Aktuelle IPs stimmen mit CSV überein
- [ ] Backup-Verzeichnis ist beschreibbar
- [ ] Dry-Run wurde durchgeführt
- [ ] Zugriff zur VM nach Änderung ist sichergestellt (Console/IPMI)

## 📞 Support

Bei Problemen siehe [`README.md`](README.md:1) Abschnitt "Troubleshooting"
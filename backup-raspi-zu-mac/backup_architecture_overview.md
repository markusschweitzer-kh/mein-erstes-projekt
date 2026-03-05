# 🏗️ Backup-System Architektur & Verbesserungen

## 📊 Aktuelle Architektur

```mermaid
flowchart TD
    Start([Backup Start]) --> Ping{Mac erreichbar?}
    Ping -->|Nein| Fail1[Abbruch + Discord]
    Ping -->|Ja| Export[Paperless Export]
    Export --> StopC[Alle Container stoppen]
    StopC --> Sync1[Rsync: Stacks]
    Sync1 --> Sync2[Rsync: Paperless Config]
    Sync2 --> Sync3[Rsync: Paperless Data]
    Sync3 --> Check{Rsync OK?}
    Check -->|Nein| Error[abort_with_error]
    Check -->|Ja| Sunday{Sonntag?}
    Sunday -->|Ja| Archive[Archiv erstellen]
    Sunday -->|Nein| StartC[Container starten]
    Archive --> StartC
    StartC --> Discord[Discord Benachrichtigung]
    Discord --> Uptime[Uptime Kuma]
    Uptime --> End([Ende])
    Error --> Restart[Container neu starten]
    Restart --> Fail2[Discord Fehler]
    Fail2 --> End
    
    style Start fill:#90EE90
    style End fill:#90EE90
    style Fail1 fill:#FFB6C1
    style Fail2 fill:#FFB6C1
    style Error fill:#FFB6C1
    style Check fill:#FFE4B5
    style Sunday fill:#FFE4B5
```

## 🎯 Verbesserungsplan - Prioritäten

```mermaid
graph LR
    subgraph P1[Priorität 1: KRITISCH]
        A1[Discord Webhook<br/>Sicherheit]
        A2[Container<br/>Wiederherstellung]
        A3[Uptime Kuma<br/>Fix]
    end
    
    subgraph P2[Priorität 2: WICHTIG]
        B1[Pre-Flight<br/>Checks]
        B2[Backup<br/>Rotation]
        B3[Container<br/>Management]
    end
    
    subgraph P3[Priorität 3: OPTIONAL]
        C1[Backup<br/>Verifizierung]
        C2[Config<br/>Externalisierung]
        C3[Erweiterte<br/>Fehlerbehandlung]
    end
    
    P1 --> P2
    P2 --> P3
    
    style P1 fill:#FFB6C1
    style P2 fill:#FFE4B5
    style P3 fill:#90EE90
```

## 🔄 Verbesserte Architektur

```mermaid
flowchart TD
    Start([Backup Start]) --> LoadConfig[Config & Secrets laden]
    LoadConfig --> PreFlight[Pre-Flight Checks]
    PreFlight --> CheckSSH{SSH-Key OK?}
    CheckSSH -->|Nein| Fail1[Abbruch]
    CheckSSH -->|Ja| CheckDirs{Verzeichnisse OK?}
    CheckDirs -->|Nein| Fail1
    CheckDirs -->|Ja| CheckDocker{Docker OK?}
    CheckDocker -->|Nein| Fail1
    CheckDocker -->|Ja| CheckSpace{Speicher OK?}
    CheckSpace -->|Nein| Warn1[Warnung senden]
    CheckSpace -->|Ja| Capture[Container-Status erfassen]
    Warn1 --> Capture
    
    Capture --> Trap[Cleanup-Trap setzen]
    Trap --> Ping{Mac erreichbar?}
    Ping -->|Nein| Fail2[Abbruch + Discord]
    Ping -->|Ja| Export[Paperless Export]
    Export --> StopC[Relevante Container stoppen]
    StopC --> Sync1[Rsync: Stacks]
    Sync1 --> Sync2[Rsync: Paperless Config]
    Sync2 --> Sync3[Rsync: Paperless Data]
    Sync3 --> Check{Rsync OK?}
    Check -->|Nein| Error[abort_with_error]
    Check -->|Ja| Verify[Backup verifizieren]
    Verify --> Sunday{Sonntag?}
    Sunday -->|Ja| Archive[Archiv erstellen]
    Archive --> Cleanup[Alte Archive löschen]
    Cleanup --> StartC[Container starten]
    Sunday -->|Nein| StartC
    StartC --> Discord[Discord Benachrichtigung]
    Discord --> Uptime[Uptime Kuma mit Status]
    Uptime --> End([Ende])
    Error --> Restart[Container via Trap]
    Restart --> Fail3[Discord Fehler]
    Fail3 --> End
    
    style Start fill:#90EE90
    style End fill:#90EE90
    style Fail1 fill:#FFB6C1
    style Fail2 fill:#FFB6C1
    style Fail3 fill:#FFB6C1
    style Error fill:#FFB6C1
    style PreFlight fill:#87CEEB
    style Verify fill:#87CEEB
    style Cleanup fill:#87CEEB
```

## 🔐 Sicherheitsverbesserungen

```mermaid
graph TD
    subgraph Before[Vorher]
        B1[Script enthält<br/>Webhook-URL]
        B2[Webhook öffentlich<br/>sichtbar]
        B3[Sicherheitsrisiko]
    end
    
    subgraph After[Nachher]
        A1[.backup_secrets<br/>Datei 600]
        A2[Webhook geschützt]
        A3[.gitignore Eintrag]
        A4[Sicher]
    end
    
    Before --> After
    
    style Before fill:#FFB6C1
    style After fill:#90EE90
```

## 📦 Container-Management

```mermaid
sequenceDiagram
    participant Script
    participant Docker
    participant Paperless
    participant Other
    
    Note over Script: Vorher: Alle Container
    Script->>Docker: docker ps -q
    Docker-->>Script: Alle Container IDs
    Script->>Docker: docker stop ALL
    Docker->>Paperless: Stop
    Docker->>Other: Stop (unnötig!)
    
    Note over Script: Nachher: Nur relevante
    Script->>Docker: Liste definierter Container
    Script->>Docker: docker stop paperless-*
    Docker->>Paperless: Stop
    Note over Other: Läuft weiter!
```

## 🗄️ Backup-Rotation

```mermaid
timeline
    title Archiv-Rotation (8 Wochen)
    Woche 1 : Archiv erstellt
    Woche 2 : Archiv behalten
    Woche 3 : Archiv behalten
    Woche 4 : Archiv behalten
    Woche 5 : Archiv behalten
    Woche 6 : Archiv behalten
    Woche 7 : Archiv behalten
    Woche 8 : Archiv behalten
    Woche 9 : Archiv GELÖSCHT
```

## 📈 Implementierungs-Roadmap

```mermaid
gantt
    title Backup-Script Verbesserungen
    dateFormat YYYY-MM-DD
    section Phase 1: Kritisch
    Discord Webhook Sicherheit    :crit, p1a, 2026-03-05, 1h
    Container-Wiederherstellung   :crit, p1b, after p1a, 1h
    Uptime Kuma Fix              :crit, p1c, after p1b, 30m
    
    section Phase 2: Wichtig
    Pre-Flight Checks            :p2a, after p1c, 2h
    Backup-Rotation              :p2b, after p2a, 1h
    Container-Management         :p2c, after p2b, 1h
    
    section Phase 3: Optional
    Backup-Verifizierung         :p3a, after p2c, 2h
    Config Externalisierung      :p3b, after p3a, 1h
    Erweiterte Fehlerbehandlung  :p3c, after p3b, 1h
```

## 🎯 Erfolgs-Metriken

Nach Implementierung sollten folgende Verbesserungen messbar sein:

| Metrik | Vorher | Nachher | Verbesserung |
|--------|--------|---------|--------------|
| Sicherheitsrisiken | 1 kritisch | 0 | ✅ 100% |
| Fehlerbehandlung | Teilweise | Vollständig | ✅ 100% |
| Container-Downtime | Alle Services | Nur Paperless | ✅ ~80% |
| Speicher-Management | Unbegrenzt | 8 Wochen | ✅ Kontrolliert |
| Monitoring-Genauigkeit | ~70% | ~95% | ✅ +25% |
| Backup-Verifizierung | Keine | Stichproben | ✅ Neu |

## 🔍 Fehlerszenarien & Lösungen

```mermaid
graph TD
    subgraph Fehler[Mögliche Fehler]
        E1[Mac offline]
        E2[Rsync fehlgeschlagen]
        E3[Container-Start fehlgeschlagen]
        E4[Speicher voll]
        E5[SSH-Verbindung timeout]
    end
    
    subgraph Lösung[Neue Fehlerbehandlung]
        L1[Frühe Erkennung + Abbruch]
        L2[Retry-Mechanismus]
        L3[Cleanup-Trap garantiert Neustart]
        L4[Pre-Flight Check warnt]
        L5[Timeout-Parameter in rsync]
    end
    
    E1 --> L1
    E2 --> L2
    E3 --> L3
    E4 --> L4
    E5 --> L5
    
    style Fehler fill:#FFB6C1
    style Lösung fill:#90EE90
```

---

*Dieses Dokument visualisiert die Architektur und geplanten Verbesserungen des Backup-Systems.*
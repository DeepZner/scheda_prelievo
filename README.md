# 🦇 Speleo Magazzino — Speleo Club Roma 1959

[![Flutter](https://img.shields.io/badge/Flutter-3.47.9-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13.7-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20Architecture-success)](#architettura-e-stack-tecnologico)
[![Database](https://img.shields.io/badge/Storage-Offline--First%20SQLite-003B57?logo=sqlite&logoColor=white)](#struttura-dati-sqlite)
[![Sync](https://img.shields.io/badge/Sync-Google%20Sheets%20API-34A853?logo=googlesheets&logoColor=white)](#sincronizzazione-e-google-sheets)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions%20Android-2088FF?logo=githubactions&logoColor=white)](#distribuzione-e-github-actions)

Applicazione mobile e desktop **Offline-First** sviluppata per lo **Speleo Club Roma** per la gestione rigorosa, tracciabile e immediata dei prelievi e dei rientri di attrezzature dal magazzino durante spedizioni ed uscite speleologiche.

L'app è progettata specificamente per l'uso in ambienti difficili (magazzino interrato freddo, privo di copertura cellulare o Wi-Fi) con **touch target ampi (minimo 48x48dp)** ottimizzati per l'uso rapido con una sola mano.

---

## 📑 Indice

1. [Funzionalità Principali](#-funzionalità-principali)
2. [Guida Operativa (Come si usa)](#-guida-operativa-come-si-usa)
   - [1. Creazione Scheda Prelievo](#1-creazione-scheda-prelievo-uscita-materiale)
   - [2. Condivisione Scheda (PDF, Web, WhatsApp)](#2-condivisione-scheda)
   - [3. Spunta Rientro Materiale](#3-spunta-rientro-materiale-riconsegna)
   - [4. Sincronizzazione con Google Sheets](#4-sincronizzazione-con-google-sheets)
3. [Architettura e Stack Tecnologico](#-architettura-e-stack-tecnologico)
4. [Schema del Database Locale (SQLite)](#-schema-del-database-locale-sqlite)
5. [Integrazione Google Sheets & Backup Drive](#-integrazione-google-sheets--backup-drive)
   - [Setup di Google Apps Script](#setup-di-google-apps-script)
   - [Sistema di Backup Automatico & Disaster Recovery](#sistema-di-backup-automatico--disaster-recovery)
6. [Distribuzione Android & GitHub Actions](#-distribuzione-android--github-actions)
7. [Sviluppo Locale e Test](#-sviluppo-locale-e-test)

---

## 🚀 Funzionalità Principali

- **Funzionamento 100% Offline**: il database locale SQLite è l'unica fonte di verità (*Single Source of Truth*). Non serve rete per creare schede, aggiungere materiali o spuntare i rientri.
- **Gestione Differenziata Unità di Misura**:
  - **Corde**: conteggiate sia in **metri lineari** (`m`) che come **matasse fisiche** nei totali.
  - **Cordini**: gestiti rigorosamente come **pezzi singoli** (`pz`).
  - **Armo, Trapano, Disostruzione, Attrezzature, Rilievo**: gestione granulare in pezzi (`pz`).
- **Condivisione Multipiattaforma per Telefoni Senza App**:
  - 📄 **Scheda PDF Ufficiale SCR**: generata offline, con logo del Pipistrello SCR 1959, logo corda e filigrana in sovraimpressione. Condivisibile e stampabile nativamente.
  - 🌐 **Web Viewer**: visualizzazione responsive via browser per consultare la scheda online da qualunque smartphone o PC senza installare nulla.
  - 📋 **Riepilogo WhatsApp**: messaggio formattato con icone pronto da copiare/incollare in chat.
- **Flusso Riconsegna Guidato**: schermata dedicata con switch grandi per marcare il rientro, controllo discrepanze (quantità tornate vs prelevate) e annotazione danni/smarrimenti.
- **Sincronizzazione Cloud Resiliente**: sincronizzazione batch verso Google Sheets con gestione automatica dei redirect e flag `is_synced` su ogni record.
- **Sistema di Backup Automatico**: snapshot giornaliero su Google Drive sia in formato foglio Google che esportazione Microsoft Excel (`.xlsx`), con rotazione a 30 giorni.

---

## 📱 Guida Operativa (Come si usa)

### 1. Creazione Scheda Prelievo (Uscita Materiale)
1. Dalla schermata iniziale tocca il pulsante **"NUOVO PRELIEVO"**.
2. Inserisci la **Grotta / Luogo** (es. *Grotta dei Cervi*), il nome del **Responsabile** ed eventuali note.
3. Seleziona i materiali dal catalogo organizzato per categorie (*Corde*, *Armo*, *Trapano*, *Disostr.*, *Attrezzature*, *Rilievo*):
   - Per le corde indica la lunghezza in metri (es. 60m).
   - Per moschettoni, piastrine, attrezzi e cordini usa i comodi tasti `+` e `-` (minimo 48dp).
4. Premi **"CONFERMA PRELIEVO"**: la scheda viene salvata immediatamente nel database offline.

### 2. Condivisione Scheda
Dalla vista di dettaglio di una scheda, tocca il pulsante **Condividi** in alto a destra:
- **📄 Condividi Scheda PDF**: genera il documento PDF ufficiale con grafica SCR e apre il menu di condivisione del sistema operativo (WhatsApp, Telegram, Stampa, Email, Salva su file).
- **🌐 Condividi Link Web (Senza app)**: copia negli appunti il link per visualizzare la scheda online via browser da qualsiasi telefono.
- **📋 Copia Messaggio Testuale**: copia il testo formattato completo per WhatsApp.
- **🖨️ Stampa Scheda PDF**: invia direttamente alla stampante Wi-Fi/Bluetooth o salva in PDF.

### 3. Spunta Rientro Materiale (Riconsegna)
Quando il materiale torna in magazzino:
1. Apri la vista **"SPUNTA RIENTRO"** (mostra solo le schede *"In attesa materiale"*).
2. Seleziona la scheda della grotta interessata.
3. Spunta ogni articolo restituito:
   - Se l'articolo è tornato completo, lo switch diventa verde.
   - Se manca del materiale (es. prelevati 10 moschettoni ma tornati 8), imposta la quantità effettiva e aggiungi una nota (es. *lasciati 2 moschettoni sul pozzo di partenza*).
4. Inserisci il nome dell'**Operatore di Magazzino** che riceve il materiale.
5. Conferma: lo stato passa automaticamente a **"Materiale rientrato"** oppure a **"Materiale mancante"** se sono state registrate differenze.

### 4. Sincronizzazione con Google Sheets
Tocca l'icona della **nuvoletta** nella barra superiore dell'app:
- Mostra il numero di record locali ancora da sincronizzare (`is_synced = 0`).
- Premi **"INVIA DATI A GOOGLE SHEETS"**: invia tutte le testate e i dettagli modificati al foglio cloud di Google Drive.
- Premi **"SCARICA PRELIEVI DA SHEETS"**: scarica sul dispositivo le schede create o aggiornate da altri magazzinieri.
- Tocca l'icona dell'ingranaggio per inserire o testare l'URL della Web App.

---

## 🏗 Architettura e Stack Tecnologico

Il progetto adotta una **Clean Architecture** rigorosa suddivisa in tre livelli:

```
lib/
├── domain/                  # Entità pure di business e logica di dominio
│   └── models/              # Prelievo, DettaglioPrelievo, Catalogo, StatoPrelievo
├── data/                    # Implementazioni concrete di storage e rete
│   ├── database/            # DatabaseHelper (SQLite, migrazioni, indici)
│   └── services/            # SyncService, GoogleSheetsClient, PdfService
└── presentation/            # Interfaccia grafica (Flutter + Riverpod)
    ├── screens/             # HomeScreen, NuovoPrelievo, Rientro, Storico, Dettaglio
    ├── widgets/             # Componenti riutilizzabili con touch target >= 48dp
    └── providers/           # StateNotifier e Riverpod code-generation
```

### Componenti Chiave
| Componente | Tecnologia | Scopo |
| :--- | :--- | :--- |
| **Framework** | Flutter 3.47+ (Dart 3) | Sviluppo multipiattaforma (Android, Windows, iOS, Linux) |
| **State Management** | `flutter_riverpod` + `riverpod_annotation` | Gestione dello stato dichiarativa e reattiva |
| **Database Locale** | `sqflite` / `sqflite_common_ffi` | Storage offline persistente e Single Source of Truth |
| **Routing** | `go_router` | Navigazione dichiarativa con parametri di percorso |
| **Generazione PDF** | `pdf` + `printing` | Rendering vettoriale offline di schede ufficiali |
| **Cloud Webhook** | Google Apps Script (`Code.gs`) | Backend serverless su Google Drive per sync e web viewer |

---

## 🗄 Struttura del Database Locale (SQLite)

### 1. Tabella `prelievi` (Testate)
| Colonna | Tipo | Descrizione |
| :--- | :--- | :--- |
| `id` | TEXT (PK, UUID) | Identificativo univoco globale del prelievo |
| `data_prelievo` | TEXT (ISO 8601) | Data e ora di uscita del materiale |
| `luogo_grotta` | TEXT | Nome della grotta o destinazione |
| `responsabile` | TEXT | Nominativo dello speleologo responsabile |
| `stato` | TEXT | Enum: *In attesa materiale*, *Materiale rientrato*, *Materiale mancante*, *Annullato* |
| `parere` | TEXT | Note generali di uscita |
| `data_rientro` | TEXT (ISO 8601) | Data e ora di avvenuta riconsegna |
| `operatore_rientro`| TEXT | Nominativo del magazziniere che ha verificato il rientro |
| `is_synced` | INTEGER (0 o 1) | Flag per la coda di sincronizzazione |

### 2. Tabella `dettagli_prelievo` (Righe Articoli)
| Colonna | Tipo | Descrizione |
| :--- | :--- | :--- |
| `id_dettaglio` | TEXT (PK, UUID) | Identificativo univoco della riga |
| `prelievo_id` | TEXT (FK) | Riferimento a `prelievi.id` |
| `materiale_id` | TEXT (FK) | Riferimento ad anagrafica catalogo |
| `quantita_prelevata`| INTEGER | Quantità in uscita (pezzi o metri) |
| `spunta_rientro` | INTEGER (0 o 1) | Esito spunta (0 = in attesa, 1 = verificato) |
| `qta_tornata` | INTEGER | Quantità effettivamente restituita |
| `note_rientro` | TEXT | Note su danni, usura o smarrimenti |
| `is_synced` | INTEGER (0 o 1) | Flag per la coda di sincronizzazione |

### 3. Tabella `catalogo` (Anagrafica Materiali)
| Colonna | Tipo | Descrizione |
| :--- | :--- | :--- |
| `id_materiale` | TEXT (PK) | Codice materiale (es. `C_001`, `A_001`, `T_001`) |
| `categoria` | TEXT | Corde, Armo, Trapano, Disostr., Attrezzature, Rilievo |
| `nome_oggetto` | TEXT | Descrizione del materiale (es. *Corda 10mm*, *Cordini*, *Spit*) |

---

## ☁️ Integrazione Google Sheets & Backup Drive

Tutti i dati possono essere sincronizzati con un comune foglio di calcolo ospitato su Google Drive senza costi di server o database cloud esterni.

### Setup di Google Apps Script (in 2 minuti)
1. Apri il tuo foglio Google Sheets su Google Drive.
2. Clicca su **Estensioni** $\to$ **Apps Script**.
3. Cancella il codice presente e incolla integralmente il contenuto del file:
   📄 [`google_apps_script/Code.gs`](google_apps_script/Code.gs)
4. Premi **Salva** (`Ctrl+S`).
5. Nel menu in alto seleziona ed esegui la funzione **`correggiEFormattaTuttiIFogli`**:
   - Creerà e formatterà automaticamente i 3 fogli con stile Speleo Club Roma: `Prelievi`, `Dettagli` e `Catalogo`.
6. In alto a destra clicca su **Distribuisci** $\to$ **Nuova distribuzione**:
   - Tipo: **Applicazione web**.
   - Esegui come: **Me stesso** (`iltuoaccount@gmail.com`).
   - Chi ha accesso: **Chiunque** (*Anyone*).
7. Copia l'**URL dell'applicazione web** (termina con `/exec`) e incollalo nelle impostazioni dell'app Flutter (icona nuvoletta).

### Sistema di Backup Automatico & Disaster Recovery
All'interno del foglio Google Sheets è integrato un sistema di protezione a 3 livelli:
- **💾 Backup Manuale 1-Click**: accessibile dal menu **Speleo Magazzino** $\to$ **Esegui Backup Adesso**.
- **⏰ Backup Notturno Schedulato**: crea automaticamente ogni notte alle 03:00 una copia del foglio e un'esportazione **Microsoft Excel (.xlsx)** nella cartella `Magazzino Speleo - Backup`.
- **🛡️ Safety Snapshot**: ogni volta che viene lanciata la formattazione o manutenzione, viene salvata una copia di sicurezza preventiva.
- **Rotazione a 30 giorni**: elimina automaticamente i backup più vecchi di 30 giorni, preservando gli archivi mensili per 1 anno.

---

## 📦 Distribuzione Android & GitHub Actions

Il repository include una pipeline CI/CD pronta in [`.github/workflows/android_distribution.yml`](.github/workflows/android_distribution.yml).

### Caratteristiche della Pipeline:
- **Analisi e Test Automatici**: ad ogni commit o pull request esegue `flutter analyze` e `flutter test`.
- **Compilazione APK Universale**: compila un unico file APK (`MagazzinoSpeleo-vX.X.X.apk`) compatibile con qualsiasi smartphone Android (Samsung, Xiaomi, Pixel, Motorola, Huawei, ecc.).
- **Pubblicazione Release in 1 Clic**:
  Creando un tag git (es. `v0.1.0`), GitHub Actions pubblica automaticamente una **GitHub Release** con l'APK allegato pronto per essere scaricato dai soci:
  ```bash
  git tag v0.1.0
  git push origin v0.1.0
  ```

---

## 💻 Sviluppo Locale e Test

### Prerequisiti
- Flutter SDK $\ge$ 3.24 (raccomandato 3.47.x)
- Dart SDK $\ge$ 3.5 (raccomandato 3.13.x)
- Android Studio / Android SDK (per build Android) o Visual Studio C++ (per build Windows)

### Comandi Utili

```bash
# Scarica le dipendenze
flutter pub get

# Genera il codice Riverpod (se modifichi i provider)
dart run build_runner build --delete-conflicting-outputs

# Esegui l'analisi statica
flutter analyze

# Esegui tutti i test unitari
flutter test

# Avvia l'app in locale su Windows
flutter run -d windows

# Avvia l'app su dispositivo Android
flutter run -d android

# Compila l'APK release locale
flutter build apk --release
```

---

## 🏛 Licenza e Crediti

Sviluppato per lo **Speleo Club Roma 1959**  
*Fondato nel 1959 — Esplorazione, Documentazione e Tutela del Mondo Sotterraneo.*  

Tutti i diritti riservati agli autori e allo Speleo Club Roma.

# Antigravity Protocol: App Magazzino Speleo Club Roma

## Ruolo
Sei un Software Architect esperto in Flutter e SQLite. Stai costruendo un'app "Offline-First" per la gestione dei prelievi di attrezzature dam magazzino per le esplorazioni di un gruppo speleologico. 

## Architettura e Stack Tecnologico
- **Architettura**: Clean Architecture rigorosa (`domain`, `data`, `presentation`).
- **State Management**: `flutter_riverpod` (usa `riverpod_annotation`).
- **Storage Locale**: `sqflite`. Il database è la singola fonte di verità (Single Source of Truth).
- **Sincronizzazione**: Integrazione futura con `googleapis` (Google Sheets API). Tutte le entità scritte dall'utente devono avere un campo `is_synced` (bool/int) per la coda di sincronizzazione in background.
- **Routing**: `go_router`.

## Schema del Database SQLite (Layer Data)
L'app utilizza tre tabelle relazionali principali:

1. **Table: prelievi (Testata)**
   - `id` (TEXT, Primary Key, UUID)
   - `data_prelievo` (TEXT, ISO 8601)
   - `luogo_grotta` (TEXT)
   - `responsabile` (TEXT)
   - `stato` (TEXT) // Enum: "In attesa materiale", "Materiale rientrato", "Materiale mancante"
   - `parere` (TEXT)
   - `is_synced` (INTEGER, 0 o 1)

2. **Table: catalogo (Anagrafica di sola lettura)**
   - `id_materiale` (TEXT, Primary Key)
   - `categoria` (TEXT) // Es: Corde, Armo, Trapano, Disostr., Attrezzature, Rilievo
   - `nome_oggetto` (TEXT)

3. **Table: dettagli_prelievo (Righe)**
   - `id_dettaglio` (TEXT, Primary Key, UUID)
   - `prelievo_id` (TEXT, Foreign Key -> prelievi.id)
   - `materiale_id` (TEXT, Foreign Key -> catalogo.id_materiale)
   - `quantita_prelevata` (INTEGER)
   - `spunta_rientro` (INTEGER, default 0) // Usato nella fase di riconsegna
   - `qta_tornata` (INTEGER, nullable)
   - `note_rientro` (TEXT, nullable)
   - `is_synced` (INTEGER, 0 o 1)

## Regole Operative UI
- Le viste devono essere ottimizzate per l'uso con una sola mano in condizioni precarie (magazzino senza rete, freddo). Usa touch target grandi (minimo 48x48dp).
- Separa nettamente la UI di "Creazione Prelievo" (dove si inseriscono le quantità in uscita) dalla UI di "Spunta Rientro" (dove si vedono solo i prelievi con stato "In attesa materiale" e si usano switch/checkbox per confermare il rientro).

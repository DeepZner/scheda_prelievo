import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../domain/models/catalogo.dart';

class DatabaseHelper {
  static const String _databaseName = 'speleo_magazzino.db';
  static const int _databaseVersion = 1;

  // Nomi Tabelle
  static const String tablePrelievi = 'prelievi';
  static const String tableCatalogo = 'catalogo';
  static const String tableDettagliPrelievo = 'dettagli_prelievo';
  static const String tableAppSettings = 'app_settings';

  static const String settingUltimoOperatoreEmail = 'ultimo_operatore_email';
  static const String settingEmailMagazzinieriCc = 'email_magazzinieri_cc';

  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _database;
  Future<Database>? _initFuture;

  /// Restituisce la factory appropriata per la piattaforma in uso
  DatabaseFactory get _dbFactory {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return databaseFactory;
  }

  /// Getter thread-safe con memorizzazione del Future per evitare race conditions
  /// e deadlock in chiamate concorrenti
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _initFuture ??= _initDatabase();
    try {
      _database = await _initFuture!;
      return _database!;
    } catch (e) {
      _initFuture = null;
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    final factory = _dbFactory;
    databaseFactory = factory;

    final dbPath = await factory.getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _databaseVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onOpen: _onOpen,
      ),
    );
  }

  Future<void> _onOpen(Database db) async {
    // Tabella impostazioni sempre presente
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableAppSettings (
        chiave TEXT PRIMARY KEY,
        valore TEXT NOT NULL
      )
    ''');

    // Autorigenerazione resiliente: se le tabelle mancano o il catalogo è vuoto
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableCatalogo'",
    );
    if (tables.isEmpty) {
      await _onCreate(db, _databaseVersion);
    } else {
      // Migrazione sicura per nuove colonne in tabella prelievi
      final columnsInfo = await db.rawQuery("PRAGMA table_info($tablePrelievi)");
      final colNames = columnsInfo.map((c) => c['name'] as String).toSet();
      if (!colNames.contains('data_rientro')) {
        await db.execute('ALTER TABLE $tablePrelievi ADD COLUMN data_rientro TEXT');
      }
      if (!colNames.contains('operatore_rientro')) {
        await db.execute('ALTER TABLE $tablePrelievi ADD COLUMN operatore_rientro TEXT');
      }
      if (!colNames.contains('email_magazzinieri')) {
        await db.execute('ALTER TABLE $tablePrelievi ADD COLUMN email_magazzinieri TEXT');
      }
      if (!colNames.contains('relazione_testo')) {
        await db.execute('ALTER TABLE $tablePrelievi ADD COLUMN relazione_testo TEXT');
      }
      if (!colNames.contains('relazione_autore')) {
        await db.execute('ALTER TABLE $tablePrelievi ADD COLUMN relazione_autore TEXT');
      }
      if (!colNames.contains('relazione_data')) {
        await db.execute('ALTER TABLE $tablePrelievi ADD COLUMN relazione_data TEXT');
      }
      if (!colNames.contains('allegato_path')) {
        await db.execute('ALTER TABLE $tablePrelievi ADD COLUMN allegato_path TEXT');
      }
      if (!colNames.contains('allegato_nome')) {
        await db.execute('ALTER TABLE $tablePrelievi ADD COLUMN allegato_nome TEXT');
      }
      if (!colNames.contains('allegato_drive_url')) {
        await db.execute('ALTER TABLE $tablePrelievi ADD COLUMN allegato_drive_url TEXT');
      }

      // Controlla se il catalogo contiene già il catalogo reale ufficiale (C_001)
      final res = await db.rawQuery(
        "SELECT id_materiale FROM $tableCatalogo WHERE id_materiale = 'C_001' LIMIT 1",
      );
      if (res.isEmpty) {
        // Se mancano i codici ufficiali C_001..R_005, popola con i 40 materiali reali
        await seedCatalogo(db);
      }
    }
  }

  Future<void> _onConfigure(Database db) async {
    // Abilita i vincoli di Foreign Key su SQLite
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Tabella Prelievi (Testata)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tablePrelievi (
        id TEXT PRIMARY KEY,
        data_prelievo TEXT NOT NULL,
        luogo_grotta TEXT NOT NULL,
        responsabile TEXT NOT NULL,
        stato TEXT NOT NULL,
        parere TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        data_rientro TEXT,
        operatore_rientro TEXT,
        email_magazzinieri TEXT,
        relazione_testo TEXT,
        relazione_autore TEXT,
        relazione_data TEXT,
        allegato_path TEXT,
        allegato_nome TEXT,
        allegato_drive_url TEXT
      )
    ''');

    // 2. Tabella Catalogo (Anagrafica di sola lettura)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCatalogo (
        id_materiale TEXT PRIMARY KEY,
        categoria TEXT NOT NULL,
        nome_oggetto TEXT NOT NULL
      )
    ''');

    // 3. Tabella Dettagli Prelievo (Righe)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableDettagliPrelievo (
        id_dettaglio TEXT PRIMARY KEY,
        prelievo_id TEXT NOT NULL,
        materiale_id TEXT NOT NULL,
        quantita_prelevata INTEGER NOT NULL,
        spunta_rientro INTEGER NOT NULL DEFAULT 0,
        qta_tornata INTEGER,
        note_rientro TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (prelievo_id) REFERENCES $tablePrelievi (id) ON DELETE CASCADE,
        FOREIGN KEY (materiale_id) REFERENCES $tableCatalogo (id_materiale) ON UPDATE CASCADE
      )
    ''');

    // Indici per velocizzare query frequenti
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dettagli_prelievo_id ON $tableDettagliPrelievo(prelievo_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_prelievi_stato ON $tablePrelievi(stato)',
    );

    // 4. Tabella Impostazioni
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableAppSettings (
        chiave TEXT PRIMARY KEY,
        valore TEXT NOT NULL
      )
    ''');

    // Esegui il seed iniziale del catalogo
    await seedCatalogo(db);
  }

  /// Recupera un'impostazione salvata in SQLite
  Future<String?> getSetting(String chiave) async {
    final db = await database;
    final res = await db.query(
      tableAppSettings,
      columns: ['valore'],
      where: 'chiave = ?',
      whereArgs: [chiave],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return res.first['valore'] as String?;
  }

  /// Salva o aggiorna un'impostazione in SQLite
  Future<void> setSetting(String chiave, String valore) async {
    final db = await database;
    await db.insert(
      tableAppSettings,
      {'chiave': chiave, 'valore': valore},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Popola la tabella catalogo con i 40 materiali ufficiali del Speleo Club Roma
  Future<void> seedCatalogo(Database db) async {
    // Rimuovi eventuali materiali provvisori di test precedenti
    await db.delete(
      tableCatalogo,
      where: "id_materiale LIKE '%corda-10mm%' OR id_materiale LIKE '%distox-2%' OR id_materiale LIKE '%trapano-hilti%' OR id_materiale LIKE '%moschettoni-ghiera%' OR id_materiale LIKE '%piastrine-inox%' OR id_materiale LIKE '%bidone-stagno%'",
    );

    final List<Catalogo> seedItems = [
      // Corde
      const Catalogo(idMateriale: 'C_001', categoria: 'Corde', nomeOggetto: 'Corde'),
      const Catalogo(idMateriale: 'C_002', categoria: 'Corde', nomeOggetto: 'Cordini'),
      const Catalogo(idMateriale: 'C_003', categoria: 'Corde', nomeOggetto: 'Sacchi'),
      const Catalogo(idMateriale: 'C_004', categoria: 'Corde', nomeOggetto: 'Guaine'),

      // Armo
      const Catalogo(idMateriale: 'A_001', categoria: 'Armo', nomeOggetto: 'Mosch. ghiera'),
      const Catalogo(idMateriale: 'A_002', categoria: 'Armo', nomeOggetto: 'Moschettoni'),
      const Catalogo(idMateriale: 'A_003', categoria: 'Armo', nomeOggetto: 'Maglie'),
      const Catalogo(idMateriale: 'A_004', categoria: 'Armo', nomeOggetto: 'Anelli'),
      const Catalogo(idMateriale: 'A_005', categoria: 'Armo', nomeOggetto: 'Piastrine'),
      const Catalogo(idMateriale: 'A_006', categoria: 'Armo', nomeOggetto: 'Sacca d\'armo'),
      const Catalogo(idMateriale: 'A_007', categoria: 'Armo', nomeOggetto: 'Mazzette'),
      const Catalogo(idMateriale: 'A_008', categoria: 'Armo', nomeOggetto: 'Scalpelli'),
      const Catalogo(idMateriale: 'A_009', categoria: 'Armo', nomeOggetto: 'Palanchini'),

      // Trapano
      const Catalogo(idMateriale: 'T_001', categoria: 'Trapano', nomeOggetto: 'Heinell'),
      const Catalogo(idMateriale: 'T_002', categoria: 'Trapano', nomeOggetto: 'Hilti'),
      const Catalogo(idMateriale: 'T_003', categoria: 'Trapano', nomeOggetto: 'Milwakee'),
      const Catalogo(idMateriale: 'T_004', categoria: 'Trapano', nomeOggetto: 'Bosh 12'),
      const Catalogo(idMateriale: 'T_005', categoria: 'Trapano', nomeOggetto: 'Bosh 24'),
      const Catalogo(idMateriale: 'T_006', categoria: 'Trapano', nomeOggetto: 'Batterie'),
      const Catalogo(idMateriale: 'T_007', categoria: 'Trapano', nomeOggetto: 'Caricabatterie'),

      // Disostruzione
      const Catalogo(idMateriale: 'D_001', categoria: 'Disostr.', nomeOggetto: 'Punte 6mm'),
      const Catalogo(idMateriale: 'D_002', categoria: 'Disostr.', nomeOggetto: 'Punte 8mm'),
      const Catalogo(idMateriale: 'D_003', categoria: 'Disostr.', nomeOggetto: 'Punte 12mm'),

      // Attrezzature
      const Catalogo(idMateriale: 'E_001', categoria: 'Attrezzature', nomeOggetto: 'Attrezzature complete'),
      const Catalogo(idMateriale: 'E_002', categoria: 'Attrezzature', nomeOggetto: 'Caschi'),
      const Catalogo(idMateriale: 'E_003', categoria: 'Attrezzature', nomeOggetto: 'Imbraghi'),
      const Catalogo(idMateriale: 'E_004', categoria: 'Attrezzature', nomeOggetto: 'Delta'),
      const Catalogo(idMateriale: 'E_005', categoria: 'Attrezzature', nomeOggetto: 'Croll'),
      const Catalogo(idMateriale: 'E_006', categoria: 'Attrezzature', nomeOggetto: 'Maniglie'),
      const Catalogo(idMateriale: 'E_007', categoria: 'Attrezzature', nomeOggetto: 'Discensori'),
      const Catalogo(idMateriale: 'E_008', categoria: 'Attrezzature', nomeOggetto: 'Pedali'),
      const Catalogo(idMateriale: 'E_009', categoria: 'Attrezzature', nomeOggetto: 'Longes'),
      const Catalogo(idMateriale: 'E_010', categoria: 'Attrezzature', nomeOggetto: 'Moschettoni (3)'),
      const Catalogo(idMateriale: 'E_011', categoria: 'Attrezzature', nomeOggetto: 'Mosch. ghiera (1)'),
      const Catalogo(idMateriale: 'E_012', categoria: 'Attrezzature', nomeOggetto: 'Maglie (1)'),

      // Rilievo
      const Catalogo(idMateriale: 'R_001', categoria: 'Rilievo', nomeOggetto: 'Bussole'),
      const Catalogo(idMateriale: 'R_002', categoria: 'Rilievo', nomeOggetto: 'Clisimetro'),
      const Catalogo(idMateriale: 'R_003', categoria: 'Rilievo', nomeOggetto: 'Fettucce'),
      const Catalogo(idMateriale: 'R_004', categoria: 'Rilievo', nomeOggetto: 'DistoX'),
      const Catalogo(idMateriale: 'R_005', categoria: 'Rilievo', nomeOggetto: 'Taccuini'),
    ];

    final batch = db.batch();
    for (final item in seedItems) {
      batch.insert(
        tableCatalogo,
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> resetAndSeed() async {
    final db = await database;
    await db.delete(tableDettagliPrelievo);
    await db.delete(tablePrelievi);
    await db.delete(tableCatalogo);
    await seedCatalogo(db);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}

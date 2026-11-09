import 'package:sqflite/sqflite.dart';
import '../../domain/models/dettaglio_prelievo.dart';
import '../../domain/models/prelievo.dart';
import '../../domain/models/stato_prelievo.dart';
import '../../domain/repositories/i_prelievo_repository.dart';
import '../database/database_helper.dart';

class SqlitePrelievoRepository implements IPrelievoRepository {
  final DatabaseHelper _dbHelper;

  SqlitePrelievoRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<List<Prelievo>> getAllPrelievi() async {
    final db = await _dbHelper.database;
    final prelieviMaps = await db.query(
      DatabaseHelper.tablePrelievi,
      orderBy: 'data_prelievo DESC',
    );

    final List<Prelievo> result = [];
    for (final pMap in prelieviMaps) {
      final id = pMap['id'] as String;
      final dettagli = await getDettagliByPrelievoId(id);
      result.add(Prelievo.fromMap(pMap, dettagli: dettagli));
    }
    return result;
  }

  @override
  Future<List<Prelievo>> getPrelieviByStato(StatoPrelievo stato) async {
    final db = await _dbHelper.database;
    final prelieviMaps = await db.query(
      DatabaseHelper.tablePrelievi,
      where: 'stato = ?',
      whereArgs: [stato.label],
      orderBy: 'data_prelievo DESC',
    );

    final List<Prelievo> result = [];
    for (final pMap in prelieviMaps) {
      final id = pMap['id'] as String;
      final dettagli = await getDettagliByPrelievoId(id);
      result.add(Prelievo.fromMap(pMap, dettagli: dettagli));
    }
    return result;
  }

  @override
  Future<List<Prelievo>> getPrelieviInAttesa() async {
    final list = await getPrelieviByStato(StatoPrelievo.inAttesa);
    // Ordinamento discendente per vista spunta rientro (dal più recente al più vecchio)
    list.sort((a, b) => b.dataPrelievo.compareTo(a.dataPrelievo));
    return list;
  }

  @override
  Future<Prelievo?> getPrelievoById(String id) async {
    final db = await _dbHelper.database;
    final prelieviMaps = await db.query(
      DatabaseHelper.tablePrelievi,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (prelieviMaps.isEmpty) return null;
    final dettagli = await getDettagliByPrelievoId(id);
    return Prelievo.fromMap(prelieviMaps.first, dettagli: dettagli);
  }

  @override
  Future<void> insertPrelievo(Prelievo prelievo) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      await txn.insert(
        DatabaseHelper.tablePrelievi,
        prelievo.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (final dettaglio in prelievo.dettagli) {
        await txn.insert(
          DatabaseHelper.tableDettagliPrelievo,
          dettaglio.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<void> updatePrelievo(Prelievo prelievo) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      await txn.update(
        DatabaseHelper.tablePrelievi,
        prelievo.toMap(),
        where: 'id = ?',
        whereArgs: [prelievo.id],
      );

      // Elimina e reinserisce i dettagli associati per gestire modifiche, aggiunte e rimozioni
      await txn.delete(
        DatabaseHelper.tableDettagliPrelievo,
        where: 'prelievo_id = ?',
        whereArgs: [prelievo.id],
      );

      for (final dettaglio in prelievo.dettagli) {
        await txn.insert(
          DatabaseHelper.tableDettagliPrelievo,
          dettaglio.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<void> updateStatoPrelievo(String prelievoId, StatoPrelievo nuovoStato) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tablePrelievi,
      {
        'stato': nuovoStato.label,
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [prelievoId],
    );
  }

  @override
  Future<void> deletePrelievo(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        DatabaseHelper.tablePrelievi,
        {
          'stato': StatoPrelievo.annullato.label,
          'is_synced': 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.update(
        DatabaseHelper.tableDettagliPrelievo,
        {
          'is_synced': 0,
        },
        where: 'prelievo_id = ?',
        whereArgs: [id],
      );
    });
  }

  @override
  Future<List<DettaglioPrelievo>> getDettagliByPrelievoId(String prelievoId) async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT d.*, c.nome_oggetto, c.categoria
      FROM ${DatabaseHelper.tableDettagliPrelievo} d
      LEFT JOIN ${DatabaseHelper.tableCatalogo} c ON d.materiale_id = c.id_materiale
      WHERE d.prelievo_id = ?
      ORDER BY c.categoria ASC, c.nome_oggetto ASC
    ''', [prelievoId]);

    return results.map((map) => DettaglioPrelievo.fromMap(map)).toList();
  }

  @override
  Future<void> updateDettaglioRientro({
    required String idDettaglio,
    required bool spuntaRientro,
    int? qtaTornata,
    String? noteRientro,
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableDettagliPrelievo,
      {
        'spunta_rientro': spuntaRientro ? 1 : 0,
        'qta_tornata': qtaTornata,
        'note_rientro': noteRientro,
        'is_synced': 0,
      },
      where: 'id_dettaglio = ?',
      whereArgs: [idDettaglio],
    );
  }

  @override
  Future<void> salvaBozzaSpunta({
    required String prelievoId,
    required List<DettaglioPrelievo> dettagli,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (final det in dettagli) {
        await txn.update(
          DatabaseHelper.tableDettagliPrelievo,
          {
            'spunta_rientro': det.spuntaRientro ? 1 : 0,
            'qta_tornata': det.qtaTornata,
            'note_rientro': det.noteRientro,
            'is_synced': 0,
          },
          where: 'id_dettaglio = ?',
          whereArgs: [det.idDettaglio],
        );
      }
      await txn.update(
        DatabaseHelper.tablePrelievi,
        {'is_synced': 0},
        where: 'id = ?',
        whereArgs: [prelievoId],
      );
    });
  }

  @override
  Future<void> confirmRientro({
    required String prelievoId,
    required List<DettaglioPrelievo> dettagli,
    required StatoPrelievo nuovoStato,
    String? noteRientroGenerali,
    DateTime? dataRientro,
    String? operatoreRientro,
    String? emailMagazzinieri,
  }) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      for (final det in dettagli) {
        await txn.update(
          DatabaseHelper.tableDettagliPrelievo,
          {
            'spunta_rientro': det.spuntaRientro ? 1 : 0,
            'qta_tornata': det.qtaTornata,
            'note_rientro': det.noteRientro,
            'is_synced': 0,
          },
          where: 'id_dettaglio = ?',
          whereArgs: [det.idDettaglio],
        );
      }

      final Map<String, dynamic> updateHeaderValues = {
        'stato': nuovoStato.label,
        'is_synced': 0,
      };
      if (noteRientroGenerali != null && noteRientroGenerali.isNotEmpty) {
        updateHeaderValues['parere'] = noteRientroGenerali;
      }
      if (dataRientro != null) {
        updateHeaderValues['data_rientro'] = dataRientro.toIso8601String();
      }
      if (operatoreRientro != null && operatoreRientro.isNotEmpty) {
        updateHeaderValues['operatore_rientro'] = operatoreRientro;
      }
      if (emailMagazzinieri != null && emailMagazzinieri.isNotEmpty) {
        updateHeaderValues['email_magazzinieri'] = emailMagazzinieri;
      }

      await txn.update(
        DatabaseHelper.tablePrelievi,
        updateHeaderValues,
        where: 'id = ?',
        whereArgs: [prelievoId],
      );
    });
  }

  @override
  Future<void> salvaRelazione({
    required String prelievoId,
    required String? relazioneTesto,
    required String? relazioneAutore,
    required DateTime? relazioneData,
    required String? allegatoPath,
    required String? allegatoNome,
    String? allegatoDriveUrl,
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tablePrelievi,
      {
        'relazione_testo': relazioneTesto,
        'relazione_autore': relazioneAutore,
        'relazione_data': relazioneData?.toIso8601String(),
        'allegato_path': allegatoPath,
        'allegato_nome': allegatoNome,
        'allegato_drive_url': allegatoDriveUrl,
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [prelievoId],
    );
  }

  @override
  Future<List<Prelievo>> getPrelieviDaSincronizzare() async {
    final db = await _dbHelper.database;
    final prelieviMaps = await db.query(
      DatabaseHelper.tablePrelievi,
      where: 'is_synced = 0',
      orderBy: 'data_prelievo ASC',
    );

    final List<Prelievo> result = [];
    for (final pMap in prelieviMaps) {
      final id = pMap['id'] as String;
      final dettagli = await getDettagliByPrelievoId(id);
      result.add(Prelievo.fromMap(pMap, dettagli: dettagli));
    }
    return result;
  }

  @override
  Future<void> markPrelievoAsSynced(String prelievoId) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tablePrelievi,
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [prelievoId],
    );
  }

  @override
  Future<void> markDettaglioAsSynced(String idDettaglio) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableDettagliPrelievo,
      {'is_synced': 1},
      where: 'id_dettaglio = ?',
      whereArgs: [idDettaglio],
    );
  }
}

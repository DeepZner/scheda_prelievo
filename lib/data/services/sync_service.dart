import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import '../../domain/models/dettaglio_prelievo.dart';
import '../../domain/models/prelievo.dart';
import '../database/database_helper.dart';
import 'google_sheets_client.dart';

class SyncPayload {
  final List<Prelievo> prelievi;
  final List<DettaglioPrelievo> dettagli;

  const SyncPayload({
    required this.prelievi,
    required this.dettagli,
  });

  bool get isEmpty => prelievi.isEmpty && dettagli.isEmpty;
  int get totalRecords => prelievi.length + dettagli.length;

  Map<String, dynamic> toMap() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'prelievi_count': prelievi.length,
      'dettagli_count': dettagli.length,
      'prelievi': prelievi.map((p) => {
        'id': p.id,
        'data_prelievo': p.dataPrelievo.toIso8601String(),
        'luogo_grotta': p.luogoGrotta,
        'responsabile': p.responsabile,
        'stato': p.stato.label,
        'parere': p.parere ?? '',
        'data_rientro': p.dataRientro?.toIso8601String() ?? '',
        'operatore_rientro': p.operatoreRientro ?? '',
        'email_magazzinieri': p.emailMagazzinieri ?? '',
        'relazione_testo': p.relazioneTesto ?? '',
        'relazione_autore': p.relazioneAutore ?? '',
        'relazione_data': p.relazioneData?.toIso8601String() ?? '',
        'allegato_nome': p.allegatoNome ?? '',
        'allegato_drive_url': p.allegatoDriveUrl ?? '',
      }).toList(),
      'dettagli_prelievo': dettagli.map((d) => {
        'id_dettaglio': d.idDettaglio,
        'prelievo_id': d.prelievoId,
        'materiale_id': d.materialeId,
        'nome_materiale': d.nomeMateriale ?? '',
        'categoria': d.categoriaMateriale ?? '',
        'quantita_prelevata': d.quantitaPrelevata,
        'spunta_rientro': d.spuntaRientro ? 1 : 0,
        'qta_tornata': d.qtaTornata ?? d.quantitaPrelevata,
        'note_rientro': d.noteRientro ?? '',
      }).toList(),
    };
  }

  String toJson({bool pretty = true}) {
    final map = toMap();
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(map);
    }
    return jsonEncode(map);
  }

  List<List<Object?>> toPrelieviSheetRows() {
    return prelievi.map((p) => [
      p.id,
      p.dataPrelievo.toIso8601String(),
      p.luogoGrotta,
      p.responsabile,
      p.stato.label,
      p.dataRientro?.toIso8601String() ?? '',
      p.operatoreRientro ?? '',
      p.emailMagazzinieri ?? '',
      p.parere ?? '',
    ]).toList();
  }

  List<List<Object?>> toDettagliSheetRows() {
    return dettagli.map((d) => [
      d.idDettaglio,
      d.prelievoId,
      d.materialeId,
      d.categoriaMateriale ?? '',
      d.nomeMateriale ?? '',
      d.quantitaPrelevata,
      d.spuntaRientro ? 'SI' : 'NO',
      d.qtaTornata ?? '',
      d.noteRientro ?? '',
    ]).toList();
  }
}

class SyncResult {
  final bool isSuccess;
  final int prelieviSyncedCount;
  final int dettagliSyncedCount;
  final String? errorMessage;

  const SyncResult({
    required this.isSuccess,
    required this.prelieviSyncedCount,
    required this.dettagliSyncedCount,
    this.errorMessage,
  });
}

class DownloadResult {
  final bool isSuccess;
  final int prelieviScaricati;
  final int dettagliScaricati;
  final String? errorMessage;

  const DownloadResult({
    required this.isSuccess,
    this.prelieviScaricati = 0,
    this.dettagliScaricati = 0,
    this.errorMessage,
  });
}

class SyncService {
  static const String settingGoogleSheetsUrl = 'google_sheets_web_app_url';

  final DatabaseHelper _dbHelper;
  final GoogleSheetsClient _sheetsClient;

  SyncService({
    DatabaseHelper? dbHelper,
    GoogleSheetsClient? sheetsClient,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _sheetsClient = sheetsClient ?? GoogleSheetsClient();

  /// Legge l'URL configurato della Web App di Google Sheets da SQLite
  Future<String?> getGoogleSheetsUrl() async {
    final url = await _dbHelper.getSetting(settingGoogleSheetsUrl);
    if (url != null &&
        (url.contains('DEV_TEST') ||
            url.contains('AKfycbz_TEST') ||
            url.contains('CLEAN_URL'))) {
      // Pulisce l'impostazione fittizia lasciata accidentalmente dal test unitario
      await _dbHelper.setSetting(settingGoogleSheetsUrl, '');
      return null;
    }
    return url;
  }

  /// Salva l'URL della Web App di Google Sheets in SQLite
  Future<void> setGoogleSheetsUrl(String url) async {
    await _dbHelper.setSetting(settingGoogleSheetsUrl, url.trim());
  }

  /// Formatta e pulisce un URL di base per la consultazione Web
  static String formatWebShareUrl(String rawBaseUrl, String prelievoId) {
    var cleanUrl = GoogleSheetsClient.sanitizeUrl(rawBaseUrl);
    if (cleanUrl.endsWith('/dev')) {
      cleanUrl = '${cleanUrl.substring(0, cleanUrl.length - 4)}/exec';
    }
    return '$cleanUrl?scheda=$prelievoId';
  }

  /// Restituisce l'URL di consultazione Web per una specifica scheda prelievo
  Future<String?> getWebShareUrl(String prelievoId) async {
    final rawUrl = await getGoogleSheetsUrl();
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    return formatWebShareUrl(rawUrl, prelievoId);
  }

  /// Esegue un ping di test sull'URL della Web App
  Future<GoogleSheetsPingResult> testGoogleSheetsConnection([String? urlOverride]) async {
    final url = urlOverride ?? await getGoogleSheetsUrl();
    if (url == null || url.trim().isEmpty) {
      return const GoogleSheetsPingResult(
        isSuccess: false,
        errorMessage: 'Nessun URL configurato. Inserisci l\'URL della Web App.',
      );
    }
    return _sheetsClient.testConnection(url);
  }

  /// Scarica tutti i prelievi e dettagli da Google Sheets e li salva nel database SQLite locale
  Future<DownloadResult> scaricaDaGoogleSheets([String? urlOverride]) async {
    try {
      final url = urlOverride ?? await getGoogleSheetsUrl();
      if (url == null || url.trim().isEmpty) {
        return const DownloadResult(
          isSuccess: false,
          errorMessage: 'Nessun URL configurato. Inserisci l\'URL della Web App.',
        );
      }

      final downloadRes = await _sheetsClient.fetchPrelieviEDettagli(url);
      if (!downloadRes.isSuccess) {
        return DownloadResult(
          isSuccess: false,
          errorMessage: downloadRes.errorMessage ?? 'Download fallito da Google Sheets.',
        );
      }

      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        // Inserisci o aggiorna le testate prelievi scaricate (is_synced = 1)
        for (final p in downloadRes.prelievi) {
          await txn.insert(
            DatabaseHelper.tablePrelievi,
            p.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // Inserisci o aggiorna le righe di dettaglio scaricate (is_synced = 1)
        for (final d in downloadRes.dettagli) {
          await txn.insert(
            DatabaseHelper.tableDettagliPrelievo,
            d.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });

      return DownloadResult(
        isSuccess: true,
        prelieviScaricati: downloadRes.prelievi.length,
        dettagliScaricati: downloadRes.dettagli.length,
      );
    } catch (e) {
      return DownloadResult(
        isSuccess: false,
        errorMessage: 'Errore salvataggio locale: $e',
      );
    }
  }

  /// Scarica il catalogo aggiornato dal foglio Google e lo sincronizza in SQLite locale
  Future<int> aggiornaCatalogoDaRemoto([String? urlOverride]) async {
    final url = urlOverride ?? await getGoogleSheetsUrl();
    if (url == null || url.trim().isEmpty) return 0;

    final materialiRemoti = await _sheetsClient.fetchCatalogo(url);
    if (materialiRemoti.isEmpty) return 0;

    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final mat in materialiRemoti) {
      batch.insert(
        DatabaseHelper.tableCatalogo,
        mat.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    return materialiRemoti.length;
  }

  Future<List<Prelievo>> getUnsyncedPrelievi() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DatabaseHelper.tablePrelievi,
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'data_prelievo ASC',
    );
    return results.map((map) => Prelievo.fromMap(map)).toList();
  }

  Future<List<DettaglioPrelievo>> getUnsyncedDettagli() async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT d.*, c.nome_oggetto, c.categoria
      FROM ${DatabaseHelper.tableDettagliPrelievo} d
      LEFT JOIN ${DatabaseHelper.tableCatalogo} c ON d.materiale_id = c.id_materiale
      WHERE d.is_synced = 0
    ''');
    return results.map((map) => DettaglioPrelievo.fromMap(map)).toList();
  }

  Future<int> getPendingSyncCount() async {
    final db = await _dbHelper.database;
    final countPrelievi = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseHelper.tablePrelievi} WHERE is_synced = 0',
    )) ?? 0;
    final countDettagli = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseHelper.tableDettagliPrelievo} WHERE is_synced = 0',
    )) ?? 0;
    return countPrelievi + countDettagli;
  }

  Future<SyncPayload> preparePendingSyncPayload() async {
    final prelievi = await getUnsyncedPrelievi();
    final dettagli = await getUnsyncedDettagli();
    return SyncPayload(prelievi: prelievi, dettagli: dettagli);
  }

  Future<SyncResult> sincronizzaConRemoto({
    Future<bool> Function(SyncPayload payload)? onUploadPayload,
    String? webAppUrlOverride,
  }) async {
    try {
      final payload = await preparePendingSyncPayload();
      if (payload.isEmpty) {
        return const SyncResult(
          isSuccess: true,
          prelieviSyncedCount: 0,
          dettagliSyncedCount: 0,
        );
      }

      if (onUploadPayload != null) {
        final ok = await onUploadPayload(payload);
        if (!ok) {
          return const SyncResult(
            isSuccess: false,
            prelieviSyncedCount: 0,
            dettagliSyncedCount: 0,
            errorMessage: 'Invio a Google Sheets non riuscito.',
          );
        }
      } else {
        // Connessione reale a Google Sheets Web App
        final url = webAppUrlOverride ?? await getGoogleSheetsUrl();
        if (url == null || url.trim().isEmpty) {
          return const SyncResult(
            isSuccess: false,
            prelieviSyncedCount: 0,
            dettagliSyncedCount: 0,
            errorMessage: 'URL Web App di Google Sheets non configurato.',
          );
        }

        final uploadResult = await _sheetsClient.uploadSyncPayload(url, payload);
        if (!uploadResult.isSuccess) {
          return SyncResult(
            isSuccess: false,
            prelieviSyncedCount: 0,
            dettagliSyncedCount: 0,
            errorMessage: uploadResult.errorMessage ?? 'Errore durante l\'invio a Google Sheets.',
          );
        }
      }

      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        if (payload.prelievi.isNotEmpty) {
          final pIds = payload.prelievi.map((p) => p.id).toList();
          final qMarks = List.filled(pIds.length, '?').join(',');
          await txn.rawUpdate(
            'UPDATE ${DatabaseHelper.tablePrelievi} SET is_synced = 1 WHERE id IN ($qMarks)',
            pIds,
          );
        }

        if (payload.dettagli.isNotEmpty) {
          final dIds = payload.dettagli.map((d) => d.idDettaglio).toList();
          final qMarks = List.filled(dIds.length, '?').join(',');
          await txn.rawUpdate(
            'UPDATE ${DatabaseHelper.tableDettagliPrelievo} SET is_synced = 1 WHERE id_dettaglio IN ($qMarks)',
            dIds,
          );
        }
      });

      return SyncResult(
        isSuccess: true,
        prelieviSyncedCount: payload.prelievi.length,
        dettagliSyncedCount: payload.dettagli.length,
      );
    } catch (e) {
      return SyncResult(
        isSuccess: false,
        prelieviSyncedCount: 0,
        dettagliSyncedCount: 0,
        errorMessage: e.toString(),
      );
    }
  }

  /// Invia il comando di eliminazione definitiva (purge) delle schede annullate al server Google Apps Script
  Future<bool> purgeSchedeAnnullateRemote({List<String>? prelievoIds}) async {
    final url = await getGoogleSheetsUrl();
    if (url == null || url.trim().isEmpty) return false;
    return _sheetsClient.purgeSchedeAnnullate(url, prelievoIds: prelievoIds);
  }
}

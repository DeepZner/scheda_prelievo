import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scheda_prelievo/data/database/database_helper.dart';
import 'package:scheda_prelievo/data/repositories/sqlite_prelievo_repository.dart';
import 'package:scheda_prelievo/data/services/google_sheets_client.dart';
import 'package:scheda_prelievo/domain/models/dettaglio_prelievo.dart';
import 'package:scheda_prelievo/domain/models/prelievo.dart';
import 'package:scheda_prelievo/domain/models/stato_prelievo.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('Purge Schede Annullate - SQLite Repository Tests', () {
    late Database db;
    late SqlitePrelievoRepository repository;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('''
            CREATE TABLE ${DatabaseHelper.tablePrelievi} (
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

          await db.execute('''
            CREATE TABLE ${DatabaseHelper.tableCatalogo} (
              id_materiale TEXT PRIMARY KEY,
              categoria TEXT NOT NULL,
              nome_oggetto TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE ${DatabaseHelper.tableDettagliPrelievo} (
              id_dettaglio TEXT PRIMARY KEY,
              prelievo_id TEXT NOT NULL,
              materiale_id TEXT NOT NULL,
              quantita_prelevata INTEGER NOT NULL,
              spunta_rientro INTEGER NOT NULL DEFAULT 0,
              qta_tornata INTEGER,
              note_rientro TEXT,
              is_synced INTEGER NOT NULL DEFAULT 0,
              FOREIGN KEY (prelievo_id) REFERENCES ${DatabaseHelper.tablePrelievi} (id) ON DELETE CASCADE
            )
          ''');
        },
      );

      repository = SqlitePrelievoRepository(
        dbHelper: DatabaseHelper.withDatabase(db),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('purgeSchedeAnnullate elimina solo le schede con stato Annullato e le loro righe', () async {
      // 1. Inserisci una scheda attiva
      final pAttiva = Prelievo(
        id: 'p-attiva-1',
        dataPrelievo: DateTime.now(),
        luogoGrotta: 'Pozzo della Neve',
        responsabile: 'Mario',
        stato: StatoPrelievo.inAttesa,
        isSynced: true,
      );
      await repository.insertPrelievo(pAttiva);
      await repository.aggiungiDettaglioPrelievo(
        const DettaglioPrelievo(
          idDettaglio: 'd-attiva-1',
          prelievoId: 'p-attiva-1',
          materialeId: 'C_001',
          quantitaPrelevata: 50,
          nomeMateriale: 'Corda 10mm',
          categoriaMateriale: 'Corde',
        ),
      );

      // 2. Inserisci una scheda annullata con 2 dettagli
      final pAnnullata = Prelievo(
        id: 'p-annullata-1',
        dataPrelievo: DateTime.now(),
        luogoGrotta: 'Grotta Errata',
        responsabile: 'Luigi',
        stato: StatoPrelievo.annullato,
        isSynced: true,
      );
      await repository.insertPrelievo(pAnnullata);
      await repository.aggiungiDettaglioPrelievo(
        const DettaglioPrelievo(
          idDettaglio: 'd-annullata-1',
          prelievoId: 'p-annullata-1',
          materialeId: 'C_002',
          quantitaPrelevata: 60,
          nomeMateriale: 'Corda 10.5mm',
          categoriaMateriale: 'Corde',
        ),
      );
      await repository.aggiungiDettaglioPrelievo(
        const DettaglioPrelievo(
          idDettaglio: 'd-annullata-2',
          prelievoId: 'p-annullata-1',
          materialeId: 'A_001',
          quantitaPrelevata: 10,
          nomeMateriale: 'Moschettoni',
          categoriaMateriale: 'Armo',
        ),
      );

      // Verifica pre-purge
      final annullatePre = await repository.getSchedeAnnullate();
      expect(annullatePre.length, 1);
      expect(annullatePre.first.id, 'p-annullata-1');

      // Esegui Purge
      final eliminati = await repository.purgeSchedeAnnullate();
      expect(eliminati, 1);

      // Verifica post-purge: scheda annullata e suoi dettagli completamente rimossi
      final annullatePost = await repository.getSchedeAnnullate();
      expect(annullatePost.isEmpty, isTrue);

      final pAnnullataCercata = await repository.getPrelievoById('p-annullata-1');
      expect(pAnnullataCercata, isNull);

      final dettagliAnnullata = await repository.getDettagliByPrelievoId('p-annullata-1');
      expect(dettagliAnnullata.isEmpty, isTrue);

      // La scheda attiva DEVE essere rimasta intatta
      final pAttivaPost = await repository.getPrelievoById('p-attiva-1');
      expect(pAttivaPost, isNotNull);
      expect(pAttivaPost!.id, 'p-attiva-1');
      expect(pAttivaPost.stato, StatoPrelievo.inAttesa);

      final dettagliAttiva = await repository.getDettagliByPrelievoId('p-attiva-1');
      expect(dettagliAttiva.length, 1);
      expect(dettagliAttiva.first.idDettaglio, 'd-attiva-1');
    });

    test('purgeSchedeAnnullate con specificIds elimina solo gli ID specificati', () async {
      // Inserisci due schede annullate
      final p1 = Prelievo(
        id: 'p-ann-1',
        dataPrelievo: DateTime.now(),
        luogoGrotta: 'Grotta 1',
        responsabile: 'User 1',
        stato: StatoPrelievo.annullato,
      );
      final p2 = Prelievo(
        id: 'p-ann-2',
        dataPrelievo: DateTime.now(),
        luogoGrotta: 'Grotta 2',
        responsabile: 'User 2',
        stato: StatoPrelievo.annullato,
      );

      await repository.insertPrelievo(p1);
      await repository.insertPrelievo(p2);

      // Elimina solo p1
      final eliminati = await repository.purgeSchedeAnnullate(prelievoIds: ['p-ann-1']);
      expect(eliminati, 1);

      expect(await repository.getPrelievoById('p-ann-1'), isNull);
      expect(await repository.getPrelievoById('p-ann-2'), isNotNull);

      final rimanenti = await repository.getSchedeAnnullate();
      expect(rimanenti.length, 1);
      expect(rimanenti.first.id, 'p-ann-2');
    });
  });

  group('GoogleSheetsClient Purge Tests', () {
    test('purgeSchedeAnnullate invia payload corretto con action: purge_annullati', () async {
      late Map<String, dynamic> capturedBody;

      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;

        return http.Response(
          jsonEncode({
            'status': 'success',
            'message': 'Purge completato',
            'prelievi_eliminati': 2,
            'dettagli_eliminati': 5,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final sheetsClient = GoogleSheetsClient(client: mockClient);
      final success = await sheetsClient.purgeSchedeAnnullate(
        'https://script.google.com/macros/s/TEST/exec',
        prelievoIds: ['uuid-1', 'uuid-2'],
      );

      expect(success, isTrue);
      expect(capturedBody['action'], 'purge_annullati');
      expect(capturedBody['ids'], ['uuid-1', 'uuid-2']);
      expect(capturedBody['timestamp'], isNotNull);
    });
  });
}

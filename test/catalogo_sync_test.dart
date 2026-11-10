import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scheda_prelievo/data/database/database_helper.dart';
import 'package:scheda_prelievo/data/repositories/sqlite_catalogo_repository.dart';
import 'package:scheda_prelievo/data/services/google_sheets_client.dart';
import 'package:scheda_prelievo/data/services/sync_service.dart';
import 'package:scheda_prelievo/domain/models/catalogo.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('Catalogo & Categorie Dinamiche Tests', () {
    late Database db;
    late DatabaseHelper dbHelper;
    late SqliteCatalogoRepository repository;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE ${DatabaseHelper.tableAppSettings} (
              chiave TEXT PRIMARY KEY,
              valore TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE ${DatabaseHelper.tableCatalogo} (
              id_materiale TEXT PRIMARY KEY,
              categoria TEXT NOT NULL,
              nome_oggetto TEXT NOT NULL
            )
          ''');
        },
      );

      dbHelper = DatabaseHelper.withDatabase(db);
      repository = SqliteCatalogoRepository(dbHelper: dbHelper);
    });

    tearDown(() async {
      await db.close();
    });

    test('getCategorie restituisce le categorie uniche ordinate alfabeticamente', () async {
      await repository.insertMateriale(
        const Catalogo(idMateriale: '1', categoria: 'Rilievo', nomeOggetto: 'DistoX'),
      );
      await repository.insertMateriale(
        const Catalogo(idMateriale: '2', categoria: 'Corde', nomeOggetto: 'Corda 10mm'),
      );
      await repository.insertMateriale(
        const Catalogo(idMateriale: '3', categoria: 'Armo', nomeOggetto: 'Moschettone'),
      );
      await repository.insertMateriale(
        const Catalogo(idMateriale: '4', categoria: 'Corde', nomeOggetto: 'Corda 9mm'),
      );

      final categorie = await repository.getCategorie();
      expect(categorie, ['Armo', 'Corde', 'Rilievo']);

      // Se aggiungo una nuova categoria dal foglio, appare subito
      await repository.insertMateriale(
        const Catalogo(idMateriale: '5', categoria: 'Subacquea', nomeOggetto: 'Bombola 7L'),
      );

      final categorieAggiornate = await repository.getCategorie();
      expect(categorieAggiornate, ['Armo', 'Corde', 'Rilievo', 'Subacquea']);
    });

    test('aggiornaCatalogoDaRemoto scarica e aggiorna correttamente il DB SQLite locale', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.queryParameters['action'], 'get_catalogo');

        return http.Response(
          jsonEncode({
            'status': 'success',
            'catalogo': [
              {
                'id_materiale': 'SUB_001',
                'categoria': 'Subacquea',
                'nome_oggetto': 'GAV Speleo',
              },
              {
                'id_materiale': 'BIO_001',
                'categoria': 'Biospeleologia',
                'nome_oggetto': 'Provetta Aspiratore',
              },
              {
                'id_materiale': 'C_001',
                'categoria': 'Corde',
                'nome_oggetto': 'Corda Semistatica 10mm EN 1891',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final sheetsClient = GoogleSheetsClient(client: mockClient);
      final syncService = SyncService(
        dbHelper: dbHelper,
        sheetsClient: sheetsClient,
      );

      // Inizialmente catalogo vuoto
      final prima = await repository.getCatalogo();
      expect(prima.isEmpty, isTrue);

      // Esegui sincronizzazione catalogo da remoto
      final scaricati = await syncService.aggiornaCatalogoDaRemoto(
        'https://script.google.com/macros/s/TEST/exec',
      );
      expect(scaricati, 3);

      // Verifica presenza e categorie nel DB SQLite locale
      final dopo = await repository.getCatalogo();
      expect(dopo.length, 3);

      final categorie = await repository.getCategorie();
      expect(categorie, containsAll(['Subacquea', 'Biospeleologia', 'Corde']));

      final subMateriale = await repository.getMaterialeById('SUB_001');
      expect(subMateriale, isNotNull);
      expect(subMateriale!.nomeOggetto, 'GAV Speleo');
      expect(subMateriale.categoria, 'Subacquea');
    });

    test('isMetri riconosce correttamente corde anche per nuove categorie tessili', () {
      const corda1 = Catalogo(
        idMateriale: 'X_01',
        categoria: 'Corde e Spezzoni',
        nomeOggetto: 'Spezzone 45m',
      );
      expect(corda1.isMetri, isTrue);
      expect(corda1.unitaMisura, 'm');

      const moschettone = Catalogo(
        idMateriale: 'X_02',
        categoria: 'Armo Speciale',
        nomeOggetto: 'Moschettone HMS',
      );
      expect(moschettone.isMetri, isFalse);
      expect(moschettone.unitaMisura, 'pz');
    });
  });
}

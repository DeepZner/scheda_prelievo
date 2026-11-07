import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scheda_prelievo/data/services/google_sheets_client.dart';
import 'package:scheda_prelievo/data/services/sync_service.dart';
import 'package:scheda_prelievo/domain/models/dettaglio_prelievo.dart';
import 'package:scheda_prelievo/domain/models/prelievo.dart';
import 'package:scheda_prelievo/domain/models/stato_prelievo.dart';

void main() {
  group('SyncPayload Tests', () {
    test('SyncPayload maps and sheets rows conversion', () {
      final prelievo = Prelievo(
        id: 'p-uuid-1',
        dataPrelievo: DateTime(2026, 11, 6, 10, 30),
        luogoGrotta: 'Grotta di Monte Cucco',
        responsabile: 'Marco Bianchi',
        stato: StatoPrelievo.inAttesa,
        parere: 'Esplorazione ramo nord',
        isSynced: false,
      );

      const dettaglio = DettaglioPrelievo(
        idDettaglio: 'd-uuid-1',
        prelievoId: 'p-uuid-1',
        materialeId: 'corda-10mm-100m',
        quantitaPrelevata: 2,
        spuntaRientro: false,
        qtaTornata: null,
        noteRientro: null,
        isSynced: false,
        nomeMateriale: 'Corda semistatica 10mm (Bobina 100m)',
        categoriaMateriale: 'Corde',
      );

      final payload = SyncPayload(
        prelievi: [prelievo],
        dettagli: [dettaglio],
      );

      expect(payload.isEmpty, isFalse);
      expect(payload.totalRecords, 2);

      final map = payload.toMap();
      expect(map['prelievi_count'], 1);
      expect(map['dettagli_count'], 1);

      final prelieviList = map['prelievi'] as List;
      expect(prelieviList.first['id'], 'p-uuid-1');
      expect(prelieviList.first['luogo_grotta'], 'Grotta di Monte Cucco');
      expect(prelieviList.first['stato'], 'In attesa materiale');

      final dettagliList = map['dettagli_prelievo'] as List;
      expect(dettagliList.first['id_dettaglio'], 'd-uuid-1');
      expect(dettagliList.first['nome_materiale'], 'Corda semistatica 10mm (Bobina 100m)');
      expect(dettagliList.first['quantita_prelevata'], 2);

      final jsonString = payload.toJson(pretty: false);
      final decoded = jsonDecode(jsonString);
      expect(decoded['prelievi_count'], 1);

      final prelieviRows = payload.toPrelieviSheetRows();
      expect(prelieviRows.length, 1);
      expect(prelieviRows.first, [
        'p-uuid-1',
        prelievo.dataPrelievo.toIso8601String(),
        'Grotta di Monte Cucco',
        'Marco Bianchi',
        'In attesa materiale',
        '',
        '',
        '',
        'Esplorazione ramo nord',
      ]);

      final dettagliRows = payload.toDettagliSheetRows();
      expect(dettagliRows.length, 1);
      expect(dettagliRows.first, [
        'd-uuid-1',
        'p-uuid-1',
        'corda-10mm-100m',
        'Corde',
        'Corda semistatica 10mm (Bobina 100m)',
        2,
        'NO',
        '',
        '',
      ]);
    });

    test('Empty SyncPayload returns empty rows and maps', () {
      const emptyPayload = SyncPayload(prelievi: [], dettagli: []);
      expect(emptyPayload.isEmpty, isTrue);
      expect(emptyPayload.totalRecords, 0);
      expect(emptyPayload.toPrelieviSheetRows(), isEmpty);
      expect(emptyPayload.toDettagliSheetRows(), isEmpty);
    });
  });

  group('GoogleSheetsClient Tests', () {
    test('testConnection success when status is ok', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['action'], 'ping');
        return http.Response(
          jsonEncode({
            'status': 'ok',
            'spreadsheet_name': 'Magazzino Speleo Test',
          }),
          200,
        );
      });

      final client = GoogleSheetsClient(client: mockClient);
      final result = await client.testConnection('https://script.google.com/macros/s/test/exec');

      expect(result.isSuccess, isTrue);
      expect(result.spreadsheetName, 'Magazzino Speleo Test');
      expect(result.errorMessage, isNull);
    });

    test('uploadSyncPayload success with 302 redirect handling', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            'Redirecting...',
            302,
            headers: {'location': 'https://script.googleusercontent.com/echo?key=123'},
          );
        } else if (request.method == 'GET' && request.url.host == 'script.googleusercontent.com') {
          return http.Response(
            jsonEncode({
              'status': 'success',
              'prelievi_synced': 1,
              'dettagli_synced': 2,
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = GoogleSheetsClient(client: mockClient);
      const payload = SyncPayload(prelievi: [], dettagli: []);
      final result = await client.uploadSyncPayload(
        'https://script.google.com/macros/s/test/exec',
        payload,
      );

      expect(result.isSuccess, isTrue);
      expect(result.prelieviSynced, 1);
      expect(result.dettagliSynced, 2);
    });

    test('fetchPrelieviEDettagli successfully parses prelievi and dettagli', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['action'], 'get_prelievi');
        return http.Response(
          jsonEncode({
            'status': 'success',
            'prelievi': [
              {
                'id': 'P_TEST_01',
                'data_prelievo': '2026-11-07T10:00:00.000Z',
                'luogo_grotta': 'Pozzo della Neve',
                'responsabile': 'Mario Rossi',
                'stato': 'In attesa materiale',
                'parere': 'Esplorazione fondo',
              }
            ],
            'dettagli_prelievo': [
              {
                'id_dettaglio': 'D_TEST_01',
                'prelievo_id': 'P_TEST_01',
                'materiale_id': 'C_001',
                'categoria': 'Corde',
                'nome_materiale': 'Corde',
                'quantita_prelevata': 3,
                'spunta_rientro': 0,
                'qta_tornata': null,
                'note_rientro': '',
              }
            ],
          }),
          200,
        );
      });

      final client = GoogleSheetsClient(client: mockClient);
      final result = await client.fetchPrelieviEDettagli('https://script.google.com/macros/s/test/exec');

      expect(result.isSuccess, isTrue);
      expect(result.prelievi.length, 1);
      expect(result.prelievi.first.id, 'P_TEST_01');
      expect(result.prelievi.first.luogoGrotta, 'Pozzo della Neve');
      expect(result.prelievi.first.isSynced, isTrue);
      expect(result.dettagli.length, 1);
      expect(result.dettagli.first.idDettaglio, 'D_TEST_01');
      expect(result.dettagli.first.quantitaPrelevata, 3);
    });

    test('sanitizeUrl cleanly strips whitespace, quotes and linebreaks', () {
      expect(
        GoogleSheetsClient.sanitizeUrl('  "https://script.google.com/macros/s/xyz/exec"  '),
        'https://script.google.com/macros/s/xyz/exec',
      );
      expect(
        GoogleSheetsClient.sanitizeUrl("  'https://script.google.com/macros/s/xyz/exec \n'  "),
        'https://script.google.com/macros/s/xyz/exec',
      );
      expect(
        GoogleSheetsClient.sanitizeUrl('https://script.google.com/ macros/s/xyz/exec\r\n'),
        'https://script.google.com/macros/s/xyz/exec',
      );
    });
  });
}

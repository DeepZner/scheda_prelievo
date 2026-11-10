import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scheda_prelievo/data/services/google_sheets_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoogleSheetsClient Salva Relazione Web & API Tests', () {
    test('salvaRelazioneRemota invia il payload corretto con action: salva_relazione', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://script.google.com/macros/s/TEST/exec');
        expect(request.method, 'POST');
        expect(request.headers['content-type'], contains('application/json'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['action'], 'salva_relazione');
        expect(body['scheda_id'], 'prel-uuid-123');
        expect(body['autore'], 'Mario Rossi');
        expect(body['testo'], 'Esplorato nuovo ramo a nord.');

        return http.Response(
          jsonEncode({
            'status': 'success',
            'message': 'Relazione salvata con successo!',
            'schedaId': 'prel-uuid-123',
            'autore': 'Mario Rossi',
            'testo': 'Esplorato nuovo ramo a nord.',
            'dataFormatted': '10/11/2026 19:15',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = GoogleSheetsClient(client: mockClient);
      final ok = await client.salvaRelazioneRemota(
        webAppUrl: 'https://script.google.com/macros/s/TEST/exec',
        schedaId: 'prel-uuid-123',
        autore: 'Mario Rossi',
        testo: 'Esplorato nuovo ramo a nord.',
      );

      expect(ok, isTrue);
    });

    test('salvaRelazioneRemota gestisce redirect 302 di Google Apps Script', () async {
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          expect(request.method, 'POST');
          return http.Response(
            '',
            302,
            headers: {'location': 'https://script.googleusercontent.com/macros/echo?redirected=1'},
          );
        } else {
          expect(request.url.toString(), 'https://script.googleusercontent.com/macros/echo?redirected=1');
          return http.Response(
            jsonEncode({'status': 'success'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
      });

      final client = GoogleSheetsClient(client: mockClient);
      final ok = await client.salvaRelazioneRemota(
        webAppUrl: 'https://script.google.com/macros/s/TEST/exec',
        schedaId: 'prel-uuid-456',
        autore: 'Laura Bianchi',
        testo: 'Completata la risalita del camino.',
      );

      expect(ok, isTrue);
      expect(callCount, 2);
    });

    test('salvaRelazioneRemota restituisce false in caso di errore o stato diverso da success', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'status': 'error', 'message': 'Scheda annullata'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = GoogleSheetsClient(client: mockClient);
      final ok = await client.salvaRelazioneRemota(
        webAppUrl: 'https://script.google.com/macros/s/TEST/exec',
        schedaId: 'prel-annullato',
        autore: 'Autore Test',
        testo: 'Test testo',
      );

      expect(ok, isFalse);
    });

    test('salvaRelazioneRemota gestisce URL vuoto senza crash', () async {
      final client = GoogleSheetsClient();
      final ok = await client.salvaRelazioneRemota(
        webAppUrl: '',
        schedaId: 'test',
        autore: 'test',
        testo: 'test',
      );
      expect(ok, isFalse);
    });
  });
}

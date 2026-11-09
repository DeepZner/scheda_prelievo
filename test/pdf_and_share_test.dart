import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:scheda_prelievo/data/services/pdf_service.dart';
import 'package:scheda_prelievo/data/services/sync_service.dart';
import 'package:scheda_prelievo/domain/models/dettaglio_prelievo.dart';
import 'package:scheda_prelievo/domain/models/prelievo.dart';
import 'package:scheda_prelievo/domain/models/stato_prelievo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfService Tests', () {
    test('generatePrelievoPdf produces valid non-empty PDF bytes', () async {
      final prelievo = Prelievo(
        id: 'test-prelievo-uuid-1234',
        dataPrelievo: DateTime(2026, 11, 9),
        luogoGrotta: 'Grotta del Fiume',
        responsabile: 'Mario Rossi',
        stato: StatoPrelievo.inAttesa,
        parere: 'Attrezzatura controllata prima della partenza',
        dettagli: [
          const DettaglioPrelievo(
            idDettaglio: 'd-1',
            prelievoId: 'test-prelievo-uuid-1234',
            materialeId: 'C_001',
            nomeMateriale: 'Corde 10mm',
            categoriaMateriale: 'Corde',
            quantitaPrelevata: 60,
          ),
          const DettaglioPrelievo(
            idDettaglio: 'd-2',
            prelievoId: 'test-prelievo-uuid-1234',
            materialeId: 'A_001',
            nomeMateriale: 'Moschettoni a ghiera',
            categoriaMateriale: 'Armo',
            quantitaPrelevata: 15,
          ),
          const DettaglioPrelievo(
            idDettaglio: 'd-3',
            prelievoId: 'test-prelievo-uuid-1234',
            materialeId: 'C_002',
            nomeMateriale: 'Cordini',
            categoriaMateriale: 'Corde',
            quantitaPrelevata: 4,
          ),
        ],
      );

      final Uint8List pdfBytes = await PdfService.generatePrelievoPdf(prelievo);

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(100));

      // PDF magic header '%PDF-'
      final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });
  });

  group('Web Share URL Generation Tests', () {
    test('formatWebShareUrl returns clean url with ?scheda=UUID', () {
      final url = SyncService.formatWebShareUrl(
        'https://script.google.com/macros/s/AKfycbz_TEST/exec',
        'test-uuid-4321',
      );
      expect(url, equals('https://script.google.com/macros/s/AKfycbz_TEST/exec?scheda=test-uuid-4321'));
    });

    test('formatWebShareUrl sanitizes raw url with quotes or trailing spaces', () {
      final url = SyncService.formatWebShareUrl(
        '  "https://script.google.com/macros/s/CLEAN_URL/exec" \n',
        'abc-123',
      );
      expect(url, equals('https://script.google.com/macros/s/CLEAN_URL/exec?scheda=abc-123'));
    });

    test('formatWebShareUrl removes trailing slash and replaces /dev with /exec', () {
      final url = SyncService.formatWebShareUrl(
        'https://script.google.com/macros/s/DEV_TEST/dev/',
        'dev-123',
      );
      expect(url, equals('https://script.google.com/macros/s/DEV_TEST/exec?scheda=dev-123'));
    });
  });
}

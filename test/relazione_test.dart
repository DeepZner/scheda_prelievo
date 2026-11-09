import 'package:flutter_test/flutter_test.dart';
import 'package:scheda_prelievo/data/services/allegati_service.dart';
import 'package:scheda_prelievo/data/services/pdf_service.dart';
import 'package:scheda_prelievo/domain/models/dettaglio_prelievo.dart';
import 'package:scheda_prelievo/domain/models/prelievo.dart';
import 'package:scheda_prelievo/domain/models/stato_prelievo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AllegatiService & Relazione Tests', () {
    test('AllegatiService limits and allowed extensions', () {
      expect(AllegatiService.maxFileSizeBytes, 20 * 1024 * 1024);
      expect(AllegatiService.defaultAllowedExtensions, containsAll([
        'pdf',
        'doc',
        'docx',
        'odt',
        'ods',
        'odp',
        'txt',
        'rtf',
        'jpg',
        'jpeg',
        'png',
      ]));
    });

    test('AllegatoInfo formatta correttamente le dimensioni dei file', () {
      const infoBytes = AllegatoInfo(path: '/a/b.txt', name: 'b.txt', sizeBytes: 500);
      expect(infoBytes.sizeFormatted, '500 B');

      const infoKb = AllegatoInfo(path: '/a/b.pdf', name: 'b.pdf', sizeBytes: 15360);
      expect(infoKb.sizeFormatted, '15.0 KB');

      const infoMb = AllegatoInfo(path: '/a/b.odt', name: 'b.odt', sizeBytes: 5 * 1024 * 1024);
      expect(infoMb.sizeFormatted, '5.0 MB');
    });

    test('Generazione PDF con Relazione e Documento Allegato', () async {
      final prelievoConRelazione = Prelievo(
        id: 'prel-pdf-rel-1',
        dataPrelievo: DateTime(2026, 11, 10, 8, 30),
        luogoGrotta: 'Grotta dei Cinque Laghi',
        responsabile: 'Giacomo Casanova',
        stato: StatoPrelievo.rientrato,
        dataRientro: DateTime(2026, 11, 10, 19, 0),
        operatoreRientro: 'Anna Magazzino',
        relazioneTesto: 'Superato il sifone terminale, rilevati ulteriori 120 metri di galleria attiva.',
        relazioneAutore: 'Giacomo Casanova',
        relazioneData: DateTime(2026, 11, 10),
        allegatoNome: 'rilievo_topografico.pdf',
        dettagli: const [
          DettaglioPrelievo(
            idDettaglio: 'det-1',
            prelievoId: 'prel-pdf-rel-1',
            materialeId: 'C_001',
            nomeMateriale: 'Corde 10.5mm',
            categoriaMateriale: 'Corde',
            quantitaPrelevata: 60,
            spuntaRientro: true,
            qtaTornata: 60,
          ),
        ],
      );

      final pdfBytes = await PdfService.generatePrelievoPdf(prelievoConRelazione);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
    });
  });
}

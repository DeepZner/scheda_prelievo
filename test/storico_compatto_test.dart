import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scheda_prelievo/domain/models/dettaglio_prelievo.dart';
import 'package:scheda_prelievo/domain/models/prelievo.dart';
import 'package:scheda_prelievo/domain/models/stato_prelievo.dart';
import 'package:scheda_prelievo/presentation/providers/prelievi_provider.dart';
import 'package:scheda_prelievo/presentation/widgets/prelievo_card.dart';
import 'package:scheda_prelievo/presentation/widgets/storico_raggruppato_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testPrelievo1 = Prelievo(
    id: 'prel-1',
    dataPrelievo: DateTime(2026, 11, 10),
    luogoGrotta: 'Grotta di Monte Cucco',
    responsabile: 'Marco Rossi',
    stato: StatoPrelievo.inAttesa,
    relazioneTesto: 'Relazione di prova',
    allegatoNome: 'foto_uscita.jpg',
    dettagli: const [
      DettaglioPrelievo(
        idDettaglio: 'det-1',
        prelievoId: 'prel-1',
        materialeId: 'C_001',
        nomeMateriale: 'Corda 10mm',
        categoriaMateriale: 'Corde',
        quantitaPrelevata: 60,
        spuntaRientro: false,
      ),
      DettaglioPrelievo(
        idDettaglio: 'det-2',
        prelievoId: 'prel-1',
        materialeId: 'M_001',
        nomeMateriale: 'Moschettoni',
        categoriaMateriale: 'Minuteria',
        quantitaPrelevata: 12,
        spuntaRientro: false,
      ),
    ],
  );

  final testPrelievoRientrato = Prelievo(
    id: 'prel-2',
    dataPrelievo: DateTime(2026, 11, 8),
    luogoGrotta: 'Pozzo della Cava',
    responsabile: 'Anna Neri',
    stato: StatoPrelievo.rientrato,
    dettagli: const [
      DettaglioPrelievo(
        idDettaglio: 'det-3',
        prelievoId: 'prel-2',
        materialeId: 'M_002',
        nomeMateriale: 'Casco',
        categoriaMateriale: 'Caschi',
        quantitaPrelevata: 2,
        spuntaRientro: true,
      ),
    ],
  );

  final testPrelievoAnnullato = Prelievo(
    id: 'prel-3',
    dataPrelievo: DateTime(2026, 11, 5),
    luogoGrotta: 'Grotta Annullata',
    responsabile: 'Luca Verdi',
    stato: StatoPrelievo.annullato,
    dettagli: const [],
  );

  group('PrelievoCard Compact Mode Tests', () {
    testWidgets('Rendering compatto e interazione tap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrelievoCard(
              prelievo: testPrelievo1,
              isCompact: true,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica testi chiave
      expect(find.text('Grotta di Monte Cucco'), findsOneWidget);
      expect(find.text('Marco Rossi'), findsOneWidget);
      expect(find.text('10/11/2026'), findsOneWidget);
      expect(find.text('60m (1) • 12pz'), findsOneWidget);

      // Verifica presenza icone relazione ed allegato
      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
      expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);

      // Verifica altezza compatta (< 90dp)
      final cardFinder = find.byType(Card);
      final cardSize = tester.getSize(cardFinder);
      expect(cardSize.height, lessThan(90));

      // Verifica interazione al tap
      await tester.tap(cardFinder);
      expect(tapped, isTrue);
    });
  });

  group('StoricoRaggruppatoView Accordion & Filtri Tests', () {
    testWidgets('Accordion apre e chiude sezioni con toggle e pulsanti', (tester) async {
      final groupedMap = {
        StatoPrelievo.inAttesa: [testPrelievo1],
        StatoPrelievo.rientrato: [testPrelievoRientrato],
        StatoPrelievo.annullato: [testPrelievoAnnullato],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storicoRaggruppatoProvider.overrideWith((ref) => groupedMap),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: StoricoRaggruppatoView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica che le schede inAttesa e rientrato siano visibili all'avvio
      expect(find.text('Grotta di Monte Cucco'), findsOneWidget);
      expect(find.text('Pozzo della Cava'), findsOneWidget);

      // Verifica presenza del pulsante rapido Comprimi tutti / Espandi tutti
      final toggleAllButton = find.text('Espandi tutti');
      final compressAllButton = find.text('Comprimi tutti');
      expect(find.byWidgetPredicate((w) => w is Text && (w.data == 'Espandi tutti' || w.data == 'Comprimi tutti')), findsOneWidget);

      // Tocca l'header della sezione IN ATTESA per richiuderla
      final headerInAttesa = find.textContaining('IN ATTESA');
      expect(headerInAttesa, findsOneWidget);
      await tester.tap(headerInAttesa);
      await tester.pumpAndSettle();

      // Ora la scheda 'Grotta di Monte Cucco' non è più visibile
      expect(find.text('Grotta di Monte Cucco'), findsNothing);

      // Tocca di nuovo l'header per riaprirla
      await tester.tap(headerInAttesa);
      await tester.pumpAndSettle();
      expect(find.text('Grotta di Monte Cucco'), findsOneWidget);

      // Tocca 'Comprimi tutti' se presente o 'Espandi tutti'
      if (compressAllButton.evaluate().isNotEmpty) {
        await tester.tap(compressAllButton);
        await tester.pumpAndSettle();
        expect(find.text('Grotta di Monte Cucco'), findsNothing);
        expect(find.text('Pozzo della Cava'), findsNothing);
      }
    });
  });
}

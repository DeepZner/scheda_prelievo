import 'package:flutter_test/flutter_test.dart';
import 'package:scheda_prelievo/domain/models/dettaglio_prelievo.dart';
import 'package:scheda_prelievo/domain/models/prelievo.dart';
import 'package:scheda_prelievo/domain/models/stato_prelievo.dart';

void main() {
  group('Rientro Materiali - Modifiche, Aggiunte ed Eccedenze', () {
    test('DettaglioPrelievo get isEccedenza and eccedenzaQta calculation', () {
      // Normale riconsegna esatta (5 prelevati, 5 tornati)
      const detEsatto = DettaglioPrelievo(
        idDettaglio: 'd1',
        prelievoId: 'p1',
        materialeId: 'M_001',
        quantitaPrelevata: 5,
        spuntaRientro: true,
        qtaTornata: 5,
      );
      expect(detEsatto.isEccedenza, isFalse);
      expect(detEsatto.eccedenzaQta, 0);
      expect(detEsatto.isCompletamenteRientrato, isTrue);
      expect(detEsatto.isParziale, isFalse);

      // Riconsegna in eccedenza (5 prelevati, 8 tornati - es. materiale ritrovato)
      const detEccedente = DettaglioPrelievo(
        idDettaglio: 'd2',
        prelievoId: 'p1',
        materialeId: 'M_002',
        quantitaPrelevata: 5,
        spuntaRientro: true,
        qtaTornata: 8,
      );
      expect(detEccedente.isEccedenza, isTrue);
      expect(detEccedente.eccedenzaQta, 3);
      expect(detEccedente.isCompletamenteRientrato, isTrue);
      expect(detEccedente.isParziale, isFalse);

      // Non ancora spuntato anche se qtaTornata è impostata a 10 non deve risultare eccedenza
      const detNonSpuntato = DettaglioPrelievo(
        idDettaglio: 'd3',
        prelievoId: 'p1',
        materialeId: 'M_003',
        quantitaPrelevata: 5,
        spuntaRientro: false,
        qtaTornata: 10,
      );
      expect(detNonSpuntato.isEccedenza, isFalse);
      expect(detNonSpuntato.eccedenzaQta, 0);
      expect(detNonSpuntato.isCompletamenteRientrato, isFalse);

      // Riconsegna parziale / ammanco (5 prelevati, 3 tornati)
      const detParziale = DettaglioPrelievo(
        idDettaglio: 'd4',
        prelievoId: 'p1',
        materialeId: 'M_004',
        quantitaPrelevata: 5,
        spuntaRientro: true,
        qtaTornata: 3,
      );
      expect(detParziale.isEccedenza, isFalse);
      expect(detParziale.isCompletamenteRientrato, isFalse);
      expect(detParziale.isParziale, isTrue);
    });

    test('Modifica della quantitaPrelevata originaria con o senza allineamento', () {
      final detIniziale = const DettaglioPrelievo(
        idDettaglio: 'd1',
        prelievoId: 'p1',
        materialeId: 'Corda-60m',
        nomeMateriale: 'Corda 10.5mm',
        categoriaMateriale: 'Corde',
        quantitaPrelevata: 60,
        spuntaRientro: true,
        qtaTornata: 60,
      );

      // Modifica: in realtà la corda presa era da 70m, e si allinea anche il rientro
      final detModificatoConAllineamento = detIniziale.copyWith(
        quantitaPrelevata: 70,
        qtaTornata: 70,
        isSynced: false,
      );

      expect(detModificatoConAllineamento.quantitaPrelevata, 70);
      expect(detModificatoConAllineamento.qtaTornata, 70);
      expect(detModificatoConAllineamento.isEccedenza, isFalse);
      expect(detModificatoConAllineamento.isCompletamenteRientrato, isTrue);
      expect(detModificatoConAllineamento.isSynced, isFalse);

      // Modifica: quantità corretta a 80m, ma sono tornati solo 60m (ammanco di 20m)
      final detModificatoSenzaAllineamento = detIniziale.copyWith(
        quantitaPrelevata: 80,
        qtaTornata: 60,
        isSynced: false,
      );

      expect(detModificatoSenzaAllineamento.quantitaPrelevata, 80);
      expect(detModificatoSenzaAllineamento.qtaTornata, 60);
      expect(detModificatoSenzaAllineamento.isParziale, isTrue);
      expect(detModificatoSenzaAllineamento.isCompletamenteRientrato, isFalse);
    });

    test('Aggiunta di un nuovo materiale direttamente durante la spunta', () {
      final prelievoIniziale = Prelievo(
        id: 'p-1',
        dataPrelievo: DateTime.now(),
        luogoGrotta: 'Grotta della Spipola',
        responsabile: 'Giacomo',
        stato: StatoPrelievo.inAttesa,
        dettagli: [
          const DettaglioPrelievo(
            idDettaglio: 'd1',
            prelievoId: 'p-1',
            materialeId: 'ARMO_01',
            nomeMateriale: 'Moschettoni con ghiera',
            quantitaPrelevata: 10,
            spuntaRientro: true,
            qtaTornata: 10,
          ),
        ],
      );

      // Nuovo materiale trovato nel sacco alla riconsegna (Trapano Hilti)
      const nuovoDettaglio = DettaglioPrelievo(
        idDettaglio: 'd-nuovo-trapano',
        prelievoId: 'p-1',
        materialeId: 'TRAP_01',
        nomeMateriale: 'Trapano Hilti TE 4-A22',
        categoriaMateriale: 'Trapano',
        quantitaPrelevata: 1,
        spuntaRientro: true,
        qtaTornata: 1,
        noteRientro: 'Aggiunto in fase di spunta',
        isSynced: false,
      );

      final prelievoAggiornato = prelievoIniziale.copyWith(
        dettagli: [...prelievoIniziale.dettagli, nuovoDettaglio],
        isSynced: false,
      );

      expect(prelievoAggiornato.dettagli.length, 2);
      expect(prelievoAggiornato.dettagli.any((d) => d.idDettaglio == 'd-nuovo-trapano'), isTrue);
      expect(prelievoAggiornato.dettagli.last.spuntaRientro, isTrue);
      expect(prelievoAggiornato.dettagli.last.qtaTornata, 1);
      expect(prelievoAggiornato.isSynced, isFalse);
    });

    test('Eliminazione di un materiale aggiunto per errore dalla scheda prelievo', () {
      final prelievo = Prelievo(
        id: 'p-1',
        dataPrelievo: DateTime.now(),
        luogoGrotta: 'Grotta dei Pipistrelli',
        responsabile: 'Anna',
        stato: StatoPrelievo.inAttesa,
        dettagli: [
          const DettaglioPrelievo(
            idDettaglio: 'd1',
            prelievoId: 'p-1',
            materialeId: 'CORDA_01',
            nomeMateriale: 'Corda 50m',
            quantitaPrelevata: 50,
          ),
          const DettaglioPrelievo(
            idDettaglio: 'd2',
            prelievoId: 'p-1',
            materialeId: 'DISTO_01',
            nomeMateriale: 'DistoX Laser',
            quantitaPrelevata: 1,
          ),
        ],
      );

      // Il DistoX era stato segnato per errore, non è mai uscito: viene eliminato
      final dettagliRimanenti = prelievo.dettagli.where((d) => d.idDettaglio != 'd2').toList();
      final prelievoSenzaDisto = prelievo.copyWith(
        dettagli: dettagliRimanenti,
        isSynced: false,
      );

      expect(prelievoSenzaDisto.dettagli.length, 1);
      expect(prelievoSenzaDisto.dettagli.first.idDettaglio, 'd1');
      expect(prelievoSenzaDisto.dettagli.any((d) => d.idDettaglio == 'd2'), isFalse);
      expect(prelievoSenzaDisto.isSynced, isFalse);
    });

    test('Calcolo stato conclusione riconsegna con materiali in eccedenza (stato rientrato)', () {
      final dettagli = [
        const DettaglioPrelievo(
          idDettaglio: 'd1',
          prelievoId: 'p1',
          materialeId: 'MOSCH_01',
          quantitaPrelevata: 5,
          spuntaRientro: true,
          qtaTornata: 7, // Eccedenza +2
        ),
        const DettaglioPrelievo(
          idDettaglio: 'd2',
          prelievoId: 'p1',
          materialeId: 'CORDA_01',
          quantitaPrelevata: 50,
          spuntaRientro: true,
          qtaTornata: 50, // Perfetto
        ),
      ];

      // Simulazione algoritmo di calcolo completamento in RientroMaterialeScreen
      bool tuttoRientrato = true;
      final List<String> mancanti = [];
      final List<String> eccedenze = [];

      for (final d in dettagli) {
        final qta = d.qtaTornata ?? 0;
        if (!d.spuntaRientro || qta < d.quantitaPrelevata) {
          tuttoRientrato = false;
          mancanti.add('${d.materialeId}: mancanti ${d.quantitaPrelevata - qta}');
        } else if (qta > d.quantitaPrelevata) {
          eccedenze.add('${d.materialeId}: eccedenza +${qta - d.quantitaPrelevata}');
        }
      }

      final nuovoStato = tuttoRientrato ? StatoPrelievo.rientrato : StatoPrelievo.mancante;

      expect(tuttoRientrato, isTrue);
      expect(nuovoStato, StatoPrelievo.rientrato);
      expect(mancanti.isEmpty, isTrue);
      expect(eccedenze.length, 1);
      expect(eccedenze.first, contains('+2'));
    });

    test('Aggiunta in sequenza di più matasse di corda della stessa categoria', () {
      // Simula aggiunta in sequenza di spezzoni da 60m, 40m, 30m per lo stesso tipo di corda
      final dettagliCorde = <DettaglioPrelievo>[];
      final matasseScelte = [60, 40, 30];

      for (final metri in matasseScelte) {
        dettagliCorde.add(
          DettaglioPrelievo(
            idDettaglio: 'dett_${dettagliCorde.length + 1}',
            prelievoId: 'p-corde',
            materialeId: 'CORDA_10',
            nomeMateriale: 'Corda Semistatica 10mm',
            categoriaMateriale: 'Corde',
            quantitaPrelevata: metri,
            spuntaRientro: false,
          ),
        );
      }

      expect(dettagliCorde.length, 3);
      // Ogni matassa è un pezzo distinto
      expect(dettagliCorde.fold<int>(0, (s, d) => s + d.numeroPezzi), 3);
      // Totale metri = 130m
      expect(dettagliCorde.fold<int>(0, (s, d) => s + d.quantitaPrelevata), 130);
      expect(dettagliCorde.every((d) => d.categoriaMateriale == 'Corde'), isTrue);
    });
  });
}

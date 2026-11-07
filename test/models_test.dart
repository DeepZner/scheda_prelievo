import 'package:flutter_test/flutter_test.dart';
import 'package:scheda_prelievo/domain/models/catalogo.dart';
import 'package:scheda_prelievo/domain/models/dettaglio_prelievo.dart';
import 'package:scheda_prelievo/domain/models/prelievo.dart';
import 'package:scheda_prelievo/domain/models/stato_prelievo.dart';

void main() {
  group('Domain Models Test Suite', () {
    test('Catalogo toMap and fromMap serialization', () {
      const cat = Catalogo(
        idMateriale: 'corda-10mm',
        categoria: 'Corde',
        nomeOggetto: 'Corda semistatica 10mm',
      );

      final map = cat.toMap();
      expect(map['id_materiale'], 'corda-10mm');
      expect(map['categoria'], 'Corde');
      expect(map['nome_oggetto'], 'Corda semistatica 10mm');

      final fromMap = Catalogo.fromMap(map);
      expect(fromMap, cat);
    });

    test('DettaglioPrelievo toMap and fromMap serialization with is_synced', () {
      const det = DettaglioPrelievo(
        idDettaglio: 'det-1',
        prelievoId: 'prel-1',
        materialeId: 'corda-10mm',
        quantitaPrelevata: 3,
        spuntaRientro: true,
        qtaTornata: 2,
        noteRientro: 'Una corda tagliata',
        isSynced: false,
      );

      final map = det.toMap();
      expect(map['id_dettaglio'], 'det-1');
      expect(map['quantita_prelevata'], 3);
      expect(map['spunta_rientro'], 1);
      expect(map['qta_tornata'], 2);
      expect(map['note_rientro'], 'Una corda tagliata');
      expect(map['is_synced'], 0);

      final fromMap = DettaglioPrelievo.fromMap(map);
      expect(fromMap.idDettaglio, det.idDettaglio);
      expect(fromMap.spuntaRientro, isTrue);
      expect(fromMap.isSynced, isFalse);
    });

    test('Prelievo serialization and stato enum handling with data_rientro and operatore', () {
      final now = DateTime.now();
      final dataRientro = now.add(const Duration(hours: 5));
      final prelievo = Prelievo(
        id: 'p-1',
        dataPrelievo: now,
        luogoGrotta: 'Grotta del Fiume',
        responsabile: 'Mario Rossi',
        stato: StatoPrelievo.rientrato,
        isSynced: false,
        dataRientro: dataRientro,
        operatoreRientro: 'operatore@speleoclubroma.org',
        emailMagazzinieri: 'magazzino@speleoclubroma.org',
      );

      final map = prelievo.toMap();
      expect(map['id'], 'p-1');
      expect(map['stato'], 'Materiale rientrato');
      expect(map['is_synced'], 0);
      expect(map['data_rientro'], dataRientro.toIso8601String());
      expect(map['operatore_rientro'], 'operatore@speleoclubroma.org');
      expect(map['email_magazzinieri'], 'magazzino@speleoclubroma.org');

      final fromMap = Prelievo.fromMap(map);
      expect(fromMap.id, prelievo.id);
      expect(fromMap.stato, StatoPrelievo.rientrato);
      expect(fromMap.isSynced, isFalse);
      expect(fromMap.dataRientro, dataRientro);
      expect(fromMap.operatoreRientro, 'operatore@speleoclubroma.org');
      expect(fromMap.emailMagazzinieri, 'magazzino@speleoclubroma.org');
    });

    test('Prelievo isModificabile logic tests', () {
      const detIniziale = DettaglioPrelievo(
        idDettaglio: 'd1',
        prelievoId: 'p1',
        materialeId: 'C_001',
        quantitaPrelevata: 5,
        spuntaRientro: false,
      );

      // 1. In attesa e spunta non iniziata -> Modificabile
      final prelModificabile = Prelievo(
        id: 'p1',
        dataPrelievo: DateTime.now(),
        luogoGrotta: 'Grotta Bianca',
        responsabile: 'Mario',
        stato: StatoPrelievo.inAttesa,
        dettagli: [detIniziale],
      );
      expect(prelModificabile.isModificabile, isTrue);
      expect(prelModificabile.haSpuntaInCorso, isFalse);
      expect(prelModificabile.articoliSpuntatiCount, 0);

      // 2. In attesa ma con spuntaRientro = true -> NON modificabile
      final prelSpuntaIniziata = prelModificabile.copyWith(
        dettagli: [detIniziale.copyWith(spuntaRientro: true)],
      );
      expect(prelSpuntaIniziata.isModificabile, isFalse);
      expect(prelSpuntaIniziata.haSpuntaInCorso, isTrue);
      expect(prelSpuntaIniziata.articoliSpuntatiCount, 1);

      // 3. In attesa ma con ammanco parziale registrato -> NON modificabile
      final prelQtaModificata = prelModificabile.copyWith(
        dettagli: [detIniziale.copyWith(qtaTornata: 4)],
      );
      expect(prelQtaModificata.isModificabile, isFalse);
      expect(prelQtaModificata.haSpuntaInCorso, isTrue);

      // 4. In attesa ma con nota rientro inserita -> NON modificabile
      final prelNotaInserita = prelModificabile.copyWith(
        dettagli: [detIniziale.copyWith(noteRientro: 'Spaccato')],
      );
      expect(prelNotaInserita.isModificabile, isFalse);
      expect(prelNotaInserita.haSpuntaInCorso, isTrue);

      // 5. Scheda già conclusa -> NON modificabile e NON in corso
      final prelChiuso = prelModificabile.copyWith(
        stato: StatoPrelievo.rientrato,
      );
      expect(prelChiuso.isModificabile, isFalse);
      expect(prelChiuso.haSpuntaInCorso, isFalse);

      // 6. Scheda annullata (cancellazione logica) -> NON modificabile e NON in corso
      final prelAnnullato = prelModificabile.copyWith(
        stato: StatoPrelievo.annullato,
      );
      expect(prelAnnullato.isModificabile, isFalse);
      expect(prelAnnullato.haSpuntaInCorso, isFalse);
    });

    test('StatoPrelievo enum conversion', () {
      expect(
        StatoPrelievo.fromString('In attesa materiale'),
        StatoPrelievo.inAttesa,
      );
      expect(
        StatoPrelievo.fromString('Materiale rientrato'),
        StatoPrelievo.rientrato,
      );
      expect(
        StatoPrelievo.fromString('Materiale mancante'),
        StatoPrelievo.mancante,
      );
      expect(
        StatoPrelievo.fromString('Annullato'),
        StatoPrelievo.annullato,
      );
      expect(
        StatoPrelievo.fromString('Cancellato'),
        StatoPrelievo.annullato,
      );
      expect(
        StatoPrelievo.fromString('Eliminato'),
        StatoPrelievo.annullato,
      );
    });

    test('Unit of measure (m vs pz) on Catalogo and DettaglioPrelievo', () {
      const corda = Catalogo(
        idMateriale: 'C_001',
        categoria: 'Corde',
        nomeOggetto: 'Corde',
      );
      expect(corda.isMetri, isTrue);
      expect(corda.unitaMisura, 'm');

      const cordino = Catalogo(
        idMateriale: 'C_002',
        categoria: 'Corde',
        nomeOggetto: 'Cordini',
      );
      expect(cordino.isMetri, isTrue);
      expect(cordino.unitaMisura, 'm');

      const sacco = Catalogo(
        idMateriale: 'C_003',
        categoria: 'Corde',
        nomeOggetto: 'Sacchi da armo',
      );
      expect(sacco.isMetri, isFalse);
      expect(sacco.unitaMisura, 'pz');

      const fettuccia = Catalogo(
        idMateriale: 'R_003',
        categoria: 'Rilievo',
        nomeOggetto: 'Rotella metrica e fettucce',
      );
      expect(fettuccia.isMetri, isTrue);
      expect(fettuccia.unitaMisura, 'm');

      const trapano = Catalogo(
        idMateriale: 'T_001',
        categoria: 'Trapano',
        nomeOggetto: 'Trapano Hilti TE 4-A22',
      );
      expect(trapano.isMetri, isFalse);
      expect(trapano.unitaMisura, 'pz');

      // Test on DettaglioPrelievo
      const detCorda = DettaglioPrelievo(
        idDettaglio: 'd-1',
        prelievoId: 'p-1',
        materialeId: 'C_001',
        nomeMateriale: 'Corde',
        categoriaMateriale: 'Corde',
        quantitaPrelevata: 50,
      );
      expect(detCorda.isMetri, isTrue);
      expect(detCorda.unitaMisura, 'm');

      const detMoschettone = DettaglioPrelievo(
        idDettaglio: 'd-2',
        prelievoId: 'p-1',
        materialeId: 'A_001',
        nomeMateriale: 'Moschettoni con ghiera',
        categoriaMateriale: 'Armo',
        quantitaPrelevata: 10,
      );
      expect(detMoschettone.isMetri, isFalse);
      expect(detMoschettone.unitaMisura, 'pz');
    });

    test('Sorting: Descending for spunta rientro vs Ascending grouped for storico', () {
      final p1 = Prelievo(
        id: 'p1',
        dataPrelievo: DateTime(2026, 10, 1),
        luogoGrotta: 'Grotta Vecchia',
        responsabile: 'Alice',
        stato: StatoPrelievo.inAttesa,
      );
      final p2 = Prelievo(
        id: 'p2',
        dataPrelievo: DateTime(2026, 11, 5),
        luogoGrotta: 'Grotta Nuova',
        responsabile: 'Bob',
        stato: StatoPrelievo.inAttesa,
      );
      final p3 = Prelievo(
        id: 'p3',
        dataPrelievo: DateTime(2026, 10, 15),
        luogoGrotta: 'Grotta Media',
        responsabile: 'Carlo',
        stato: StatoPrelievo.inAttesa,
      );

      final p4 = Prelievo(
        id: 'p4',
        dataPrelievo: DateTime(2026, 9, 20),
        luogoGrotta: 'Pozzo Uno',
        responsabile: 'Diana',
        stato: StatoPrelievo.rientrato,
      );
      final p5 = Prelievo(
        id: 'p5',
        dataPrelievo: DateTime(2026, 11, 1),
        luogoGrotta: 'Pozzo Due',
        responsabile: 'Elena',
        stato: StatoPrelievo.rientrato,
      );

      // 1. Spunta rientro: ORDINAMENTO DISCENDENTE (più recenti in alto: p2, p3, p1)
      final spuntaList = [p1, p2, p3];
      spuntaList.sort((a, b) => b.dataPrelievo.compareTo(a.dataPrelievo));
      expect(spuntaList.map((p) => p.id).toList(), ['p2', 'p3', 'p1']);
      expect(spuntaList.first.dataPrelievo.isAfter(spuntaList.last.dataPrelievo), isTrue);

      // 2. Storico: ORDINAMENTO ASCENDENTE RAGGRUPPATO PER STATI
      final tutti = [p2, p5, p1, p4, p3];
      final Map<StatoPrelievo, List<Prelievo>> grouped = {
        StatoPrelievo.inAttesa: [],
        StatoPrelievo.mancante: [],
        StatoPrelievo.rientrato: [],
        StatoPrelievo.annullato: [],
      };

      for (final p in tutti) {
        grouped[p.stato]?.add(p);
      }

      for (final list in grouped.values) {
        list.sort((a, b) => a.dataPrelievo.compareTo(b.dataPrelievo));
      }

      // Gruppo In Attesa ordinato ascendente (dal più vecchio al più recente: p1, p3, p2)
      final inAttesaIds = grouped[StatoPrelievo.inAttesa]!.map((p) => p.id).toList();
      expect(inAttesaIds, ['p1', 'p3', 'p2']);

      // Gruppo Rientrato ordinato ascendente (p4, p5)
      final rientratoIds = grouped[StatoPrelievo.rientrato]!.map((p) => p.id).toList();
      expect(rientratoIds, ['p4', 'p5']);
    });

    test('Piece count logic: rope in meters equals 1 physical piece (matassa di corda)', () {
      const corda50m = DettaglioPrelievo(
        idDettaglio: 'd1',
        prelievoId: 'p1',
        materialeId: 'C_001',
        nomeMateriale: 'Corde',
        categoriaMateriale: 'Corde',
        quantitaPrelevata: 50, // 50 metri di corda
      );
      expect(corda50m.isMetri, isTrue);
      expect(corda50m.numeroPezzi, 1); // 1 matassa

      const corda30m = DettaglioPrelievo(
        idDettaglio: 'd2',
        prelievoId: 'p1',
        materialeId: 'C_001',
        nomeMateriale: 'Corde',
        categoriaMateriale: 'Corde',
        quantitaPrelevata: 30, // 30 metri di corda
      );
      expect(corda30m.numeroPezzi, 1); // 1 matassa

      const moschettoni = DettaglioPrelievo(
        idDettaglio: 'd3',
        prelievoId: 'p1',
        materialeId: 'A_001',
        nomeMateriale: 'Moschettoni con ghiera',
        categoriaMateriale: 'Armo',
        quantitaPrelevata: 10, // 10 pezzi
      );
      expect(moschettoni.isMetri, isFalse);
      expect(moschettoni.numeroPezzi, 10);

      const sacchi = DettaglioPrelievo(
        idDettaglio: 'd4',
        prelievoId: 'p1',
        materialeId: 'C_003',
        nomeMateriale: 'Sacchi da armo',
        categoriaMateriale: 'Corde',
        quantitaPrelevata: 2, // 2 pezzi
      );
      expect(sacchi.isMetri, isFalse);
      expect(sacchi.numeroPezzi, 2);

      final prelievo = Prelievo(
        id: 'p1',
        dataPrelievo: DateTime.now(),
        luogoGrotta: 'Pozzo della Neve',
        responsabile: 'Speleo Master',
        dettagli: [corda50m, corda30m, moschettoni, sacchi],
      );

      // Totale pezzi: 1 (matassa 50m) + 1 (matassa 30m) + 10 (moschettoni) + 2 (sacchi) = 14 pezzi (NON 92!)
      expect(prelievo.totalePezzi, 14);
      expect(prelievo.totaleMatasse, 2);
      expect(prelievo.totaleMetri, 80);
    });
  });
}

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

      // 2. In attesa ma con spuntaRientro = true -> NON modificabile
      final prelSpuntaIniziata = prelModificabile.copyWith(
        dettagli: [detIniziale.copyWith(spuntaRientro: true)],
      );
      expect(prelSpuntaIniziata.isModificabile, isFalse);

      // 3. In attesa ma con ammanco parziale registrato -> NON modificabile
      final prelQtaModificata = prelModificabile.copyWith(
        dettagli: [detIniziale.copyWith(qtaTornata: 4)],
      );
      expect(prelQtaModificata.isModificabile, isFalse);

      // 4. In attesa ma con nota rientro inserita -> NON modificabile
      final prelNotaInserita = prelModificabile.copyWith(
        dettagli: [detIniziale.copyWith(noteRientro: 'Spaccato')],
      );
      expect(prelNotaInserita.isModificabile, isFalse);

      // 5. Scheda già conclusa -> NON modificabile
      final prelChiuso = prelModificabile.copyWith(
        stato: StatoPrelievo.rientrato,
      );
      expect(prelChiuso.isModificabile, isFalse);
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
    });
  });
}

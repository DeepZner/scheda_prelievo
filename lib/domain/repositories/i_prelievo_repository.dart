import '../models/dettaglio_prelievo.dart';
import '../models/prelievo.dart';
import '../models/stato_prelievo.dart';

abstract class IPrelievoRepository {
  Future<List<Prelievo>> getAllPrelievi();
  Future<List<Prelievo>> getPrelieviByStato(StatoPrelievo stato);
  Future<List<Prelievo>> getPrelieviInAttesa();
  Future<Prelievo?> getPrelievoById(String id);
  Future<void> insertPrelievo(Prelievo prelievo);
  Future<void> updatePrelievo(Prelievo prelievo);
  Future<void> updateStatoPrelievo(String prelievoId, StatoPrelievo nuovoStato);
  Future<void> deletePrelievo(String id);
  Future<List<DettaglioPrelievo>> getDettagliByPrelievoId(String prelievoId);
  Future<void> updateDettaglioRientro({
    required String idDettaglio,
    required bool spuntaRientro,
    int? qtaTornata,
    String? noteRientro,
  });
  Future<void> salvaBozzaSpunta({
    required String prelievoId,
    required List<DettaglioPrelievo> dettagli,
  });
  Future<void> confirmRientro({
    required String prelievoId,
    required List<DettaglioPrelievo> dettagli,
    required StatoPrelievo nuovoStato,
    String? noteRientroGenerali,
    DateTime? dataRientro,
    String? operatoreRientro,
    String? emailMagazzinieri,
  });
  Future<List<Prelievo>> getPrelieviDaSincronizzare();
  Future<void> markPrelievoAsSynced(String prelievoId);
  Future<void> markDettaglioAsSynced(String idDettaglio);
}

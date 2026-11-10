import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/dettaglio_prelievo.dart';
import '../../domain/models/prelievo.dart';
import '../../domain/models/stato_prelievo.dart';
import 'database_providers.dart';
import 'sync_provider.dart';

final prelieviListProvider = FutureProvider<List<Prelievo>>((ref) async {
  final repository = ref.watch(prelievoRepositoryProvider);
  return repository.getAllPrelievi();
});

final prelieviInAttesaProvider = FutureProvider<List<Prelievo>>((ref) async {
  final repository = ref.watch(prelievoRepositoryProvider);
  final list = await repository.getPrelieviInAttesa();
  // Ordinamento discendente per vista spunta rientro (più recenti in alto)
  final sorted = [...list]..sort((a, b) => b.dataPrelievo.compareTo(a.dataPrelievo));
  return sorted;
});

/// Provider per la vista Storico: prelievi raggruppati per stati con ordinamento ascendente (dal più vecchio al più recente)
final storicoRaggruppatoProvider =
    FutureProvider<Map<StatoPrelievo, List<Prelievo>>>((ref) async {
  final tutti = await ref.watch(prelieviListProvider.future);

  // Definisce l'ordine logico degli stati
  final Map<StatoPrelievo, List<Prelievo>> grouped = {
    StatoPrelievo.inAttesa: [],
    StatoPrelievo.mancante: [],
    StatoPrelievo.rientrato: [],
    StatoPrelievo.annullato: [],
  };

  for (final p in tutti) {
    if (grouped.containsKey(p.stato)) {
      grouped[p.stato]!.add(p);
    } else {
      grouped[p.stato] = [p];
    }
  }

  // Per ciascun raggruppamento di stato: ORDINAMENTO ASCENDENTE per data (dal meno recente al più recente)
  for (final list in grouped.values) {
    list.sort((a, b) => a.dataPrelievo.compareTo(b.dataPrelievo));
  }

  return grouped;
});

final prelievoDetailProvider =
    FutureProvider.family<Prelievo?, String>((ref, id) async {
  final repository = ref.watch(prelievoRepositoryProvider);
  return repository.getPrelievoById(id);
});

final schedeAnnullateProvider = FutureProvider<List<Prelievo>>((ref) async {
  final repository = ref.watch(prelievoRepositoryProvider);
  return repository.getSchedeAnnullate();
});

class PrelieviController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  PrelieviController(this._ref) : super(const AsyncValue.data(null));

  Future<void> salvaNuovoPrelievo(Prelievo prelievo) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = _ref.read(prelievoRepositoryProvider);
      await repository.insertPrelievo(prelievo);
      _invalidateLists();
    });
  }

  Future<void> aggiornaPrelievo(Prelievo prelievo) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = _ref.read(prelievoRepositoryProvider);
      await repository.updatePrelievo(prelievo);
      _invalidateLists();
    });
  }

  Future<void> aggiornaDettaglioRientro({
    required String idDettaglio,
    required bool spuntaRientro,
    int? qtaTornata,
    String? noteRientro,
    bool invalidate = false,
  }) async {
    final repository = _ref.read(prelievoRepositoryProvider);
    await repository.updateDettaglioRientro(
      idDettaglio: idDettaglio,
      spuntaRientro: spuntaRientro,
      qtaTornata: qtaTornata,
      noteRientro: noteRientro,
    );
    if (invalidate) {
      _invalidateLists();
    }
  }

  Future<void> aggiornaQuantitaPrelevata({
    required String idDettaglio,
    required int nuovaQuantitaPrelevata,
    required String prelievoId,
  }) async {
    final repository = _ref.read(prelievoRepositoryProvider);
    await repository.aggiornaQuantitaPrelevata(
      idDettaglio: idDettaglio,
      nuovaQuantitaPrelevata: nuovaQuantitaPrelevata,
      prelievoId: prelievoId,
    );
    _invalidateLists();
  }

  Future<void> aggiungiDettaglioPrelievo(DettaglioPrelievo dettaglio) async {
    final repository = _ref.read(prelievoRepositoryProvider);
    await repository.aggiungiDettaglioPrelievo(dettaglio);
    _invalidateLists();
  }

  Future<void> eliminaDettaglioPrelievo({
    required String idDettaglio,
    required String prelievoId,
  }) async {
    final repository = _ref.read(prelievoRepositoryProvider);
    await repository.eliminaDettaglioPrelievo(
      idDettaglio: idDettaglio,
      prelievoId: prelievoId,
    );
    _invalidateLists();
  }

  Future<void> salvaBozzaSpunta({
    required String prelievoId,
    required List<DettaglioPrelievo> dettagli,
  }) async {
    final repository = _ref.read(prelievoRepositoryProvider);
    await repository.salvaBozzaSpunta(
      prelievoId: prelievoId,
      dettagli: dettagli,
    );
    _invalidateLists();
  }

  Future<void> confermaRiconsegna({
    required String prelievoId,
    required List<DettaglioPrelievo> dettagli,
    required StatoPrelievo nuovoStato,
    String? noteRientroGenerali,
    DateTime? dataRientro,
    String? operatoreRientro,
    String? emailMagazzinieri,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = _ref.read(prelievoRepositoryProvider);
      await repository.confirmRientro(
        prelievoId: prelievoId,
        dettagli: dettagli,
        nuovoStato: nuovoStato,
        noteRientroGenerali: noteRientroGenerali,
        dataRientro: dataRientro,
        operatoreRientro: operatoreRientro,
        emailMagazzinieri: emailMagazzinieri,
      );
      _invalidateLists();
    });
  }

  Future<void> salvaRelazione({
    required String prelievoId,
    required String? relazioneTesto,
    required String? relazioneAutore,
    required DateTime? relazioneData,
    required String? allegatoPath,
    required String? allegatoNome,
    String? allegatoDriveUrl,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = _ref.read(prelievoRepositoryProvider);
      await repository.salvaRelazione(
        prelievoId: prelievoId,
        relazioneTesto: relazioneTesto,
        relazioneAutore: relazioneAutore,
        relazioneData: relazioneData,
        allegatoPath: allegatoPath,
        allegatoNome: allegatoNome,
        allegatoDriveUrl: allegatoDriveUrl,
      );
      _invalidateLists();
    });
  }

  Future<void> eliminaPrelievo(String prelievoId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = _ref.read(prelievoRepositoryProvider);
      await repository.deletePrelievo(prelievoId);
      _invalidateLists();
    });
  }

  /// Elimina definitivamente (purge) le schede annullate dal DB locale SQLite e facoltativamente da Google Sheets
  Future<int> purgeSchedeAnnullate({
    List<String>? prelievoIds,
    bool purgeRemote = true,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(prelievoRepositoryProvider);
      final count = await repository.purgeSchedeAnnullate(prelievoIds: prelievoIds);

      if (purgeRemote) {
        try {
          final syncService = _ref.read(syncServiceProvider);
          await syncService.purgeSchedeAnnullateRemote(prelievoIds: prelievoIds);
        } catch (_) {}
      }

      _invalidateLists();
      state = const AsyncValue.data(null);
      return count;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  void _invalidateLists() {
    _ref.invalidate(prelieviListProvider);
    _ref.invalidate(prelieviInAttesaProvider);
    _ref.invalidate(storicoRaggruppatoProvider);
    _ref.invalidate(schedeAnnullateProvider);
    _ref.invalidate(prelievoDetailProvider);
  }
}

final prelieviControllerProvider =
    StateNotifierProvider<PrelieviController, AsyncValue<void>>((ref) {
  return PrelieviController(ref);
});

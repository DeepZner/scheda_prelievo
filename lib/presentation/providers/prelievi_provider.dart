import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/dettaglio_prelievo.dart';
import '../../domain/models/prelievo.dart';
import '../../domain/models/stato_prelievo.dart';
import 'database_providers.dart';

final prelieviListProvider = FutureProvider<List<Prelievo>>((ref) async {
  final repository = ref.watch(prelievoRepositoryProvider);
  return repository.getAllPrelievi();
});

final prelieviInAttesaProvider = FutureProvider<List<Prelievo>>((ref) async {
  final repository = ref.watch(prelievoRepositoryProvider);
  return repository.getPrelieviInAttesa();
});

final prelievoDetailProvider =
    FutureProvider.family<Prelievo?, String>((ref, id) async {
  final repository = ref.watch(prelievoRepositoryProvider);
  return repository.getPrelievoById(id);
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

  Future<void> eliminaPrelievo(String prelievoId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = _ref.read(prelievoRepositoryProvider);
      await repository.deletePrelievo(prelievoId);
      _invalidateLists();
    });
  }

  void _invalidateLists() {
    _ref.invalidate(prelieviListProvider);
    _ref.invalidate(prelieviInAttesaProvider);
    _ref.invalidate(prelievoDetailProvider);
  }
}

final prelieviControllerProvider =
    StateNotifierProvider<PrelieviController, AsyncValue<void>>((ref) {
  return PrelieviController(ref);
});

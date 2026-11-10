import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/catalogo.dart';
import 'database_providers.dart';

final catalogoListProvider = FutureProvider<List<Catalogo>>((ref) async {
  final repository = ref.watch(catalogoRepositoryProvider);
  return repository.getCatalogo();
});

final catalogoCategorieProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.watch(catalogoRepositoryProvider);
  return repository.getCategorie();
});

/// Alias per compatibilità
final categorieListProvider = catalogoCategorieProvider;

/// Provider che restituisce l'elenco delle categorie con 'Tutti' come primo elemento
final categorieConTuttiProvider = FutureProvider<List<String>>((ref) async {
  final categorie = await ref.watch(catalogoCategorieProvider.future);
  return ['Tutti', ...categorie];
});

final catalogoByCategoriaProvider =
    FutureProvider.family<List<Catalogo>, String>((ref, categoria) async {
  final repository = ref.watch(catalogoRepositoryProvider);
  return repository.getCatalogoByCategoria(categoria);
});

class CatalogoController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  CatalogoController(this._ref) : super(const AsyncValue.data(null));

  Future<void> aggiungiMateriale({
    required String categoria,
    required String nomeOggetto,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = _ref.read(catalogoRepositoryProvider);
      final id = '${categoria.toLowerCase().replaceAll(' ', '-')}-${DateTime.now().millisecondsSinceEpoch}';
      final nuovo = Catalogo(
        idMateriale: id,
        categoria: categoria.trim(),
        nomeOggetto: nomeOggetto.trim(),
      );
      await repo.insertMateriale(nuovo);
      _ref.invalidate(catalogoListProvider);
      _ref.invalidate(catalogoCategorieProvider);
    });
  }
}

final catalogoControllerProvider =
    StateNotifierProvider<CatalogoController, AsyncValue<void>>((ref) {
  return CatalogoController(ref);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/google_sheets_client.dart';
import '../../data/services/sync_service.dart';
import 'catalogo_provider.dart';
import 'database_providers.dart';
import 'prelievi_provider.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return SyncService(dbHelper: dbHelper);
});

final googleSheetsUrlProvider = FutureProvider<String?>((ref) async {
  final service = ref.watch(syncServiceProvider);
  return service.getGoogleSheetsUrl();
});

final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  ref.watch(prelieviListProvider);
  final service = ref.watch(syncServiceProvider);
  return service.getPendingSyncCount();
});

final pendingPayloadProvider = FutureProvider<SyncPayload>((ref) async {
  ref.watch(prelieviListProvider);
  final service = ref.watch(syncServiceProvider);
  return service.preparePendingSyncPayload();
});

class SyncController extends StateNotifier<AsyncValue<SyncResult?>> {
  final Ref _ref;

  SyncController(this._ref) : super(const AsyncValue.data(null));

  Future<void> salvaUrlGoogleSheets(String url) async {
    final service = _ref.read(syncServiceProvider);
    await service.setGoogleSheetsUrl(url);
    _ref.invalidate(googleSheetsUrlProvider);
  }

  Future<GoogleSheetsPingResult> testConnessione([String? url]) async {
    final service = _ref.read(syncServiceProvider);
    return service.testGoogleSheetsConnection(url);
  }

  Future<int> sincronizzaCatalogoDaGoogleSheets([String? url]) async {
    final service = _ref.read(syncServiceProvider);
    final count = await service.aggiornaCatalogoDaRemoto(url);
    if (count > 0) {
      _ref.invalidate(catalogoListProvider);
      _ref.invalidate(catalogoCategorieProvider);
    }
    return count;
  }

  Future<DownloadResult> scaricaPrelieviDaGoogleSheets([String? url]) async {
    final service = _ref.read(syncServiceProvider);
    final result = await service.scaricaDaGoogleSheets(url);
    if (result.isSuccess) {
      _invalidateAllPrelieviProviders();
    }
    return result;
  }

  Future<SyncResult?> sincronizza({
    Future<bool> Function(SyncPayload payload)? onUploadPayload,
    String? webAppUrlOverride,
  }) async {
    state = const AsyncValue.loading();
    SyncResult? result;
    state = await AsyncValue.guard(() async {
      final service = _ref.read(syncServiceProvider);
      result = await service.sincronizzaConRemoto(
        onUploadPayload: onUploadPayload,
        webAppUrlOverride: webAppUrlOverride,
      );
      _invalidateAllPrelieviProviders();
      return result;
    });
    return result;
  }

  void _invalidateAllPrelieviProviders() {
    _ref.invalidate(pendingSyncCountProvider);
    _ref.invalidate(pendingPayloadProvider);
    _ref.invalidate(prelieviListProvider);
    _ref.invalidate(prelieviInAttesaProvider);
    _ref.invalidate(storicoRaggruppatoProvider);
    _ref.invalidate(prelievoDetailProvider);
  }
}

final syncControllerProvider =
    StateNotifierProvider<SyncController, AsyncValue<SyncResult?>>((ref) {
  return SyncController(ref);
});

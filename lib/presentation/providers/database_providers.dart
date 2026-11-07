import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/database_helper.dart';
import '../../data/repositories/sqlite_catalogo_repository.dart';
import '../../data/repositories/sqlite_prelievo_repository.dart';
import '../../domain/repositories/i_catalogo_repository.dart';
import '../../domain/repositories/i_prelievo_repository.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

final catalogoRepositoryProvider = Provider<ICatalogoRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return SqliteCatalogoRepository(dbHelper: dbHelper);
});

final prelievoRepositoryProvider = Provider<IPrelievoRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return SqlitePrelievoRepository(dbHelper: dbHelper);
});

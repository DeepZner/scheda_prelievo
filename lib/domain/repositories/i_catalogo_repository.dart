import '../models/catalogo.dart';

abstract class ICatalogoRepository {
  Future<List<Catalogo>> getCatalogo();
  Future<Catalogo?> getMaterialeById(String id);
  Future<List<Catalogo>> getCatalogoByCategoria(String categoria);
  Future<List<String>> getCategorie();
  Future<void> insertMateriale(Catalogo materiale);
  Future<void> deleteMateriale(String idMateriale);
  Future<void> seedCatalogo();
}

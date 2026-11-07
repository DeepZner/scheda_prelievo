import 'package:sqflite/sqflite.dart';
import '../../domain/models/catalogo.dart';
import '../../domain/repositories/i_catalogo_repository.dart';
import '../database/database_helper.dart';

class SqliteCatalogoRepository implements ICatalogoRepository {
  final DatabaseHelper _dbHelper;

  SqliteCatalogoRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<List<Catalogo>> getCatalogo() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableCatalogo,
      orderBy: 'categoria ASC, nome_oggetto ASC',
    );
    return maps.map((map) => Catalogo.fromMap(map)).toList();
  }

  @override
  Future<Catalogo?> getMaterialeById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableCatalogo,
      where: 'id_materiale = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Catalogo.fromMap(maps.first);
  }

  @override
  Future<List<Catalogo>> getCatalogoByCategoria(String categoria) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableCatalogo,
      where: 'categoria = ?',
      whereArgs: [categoria],
      orderBy: 'nome_oggetto ASC',
    );
    return maps.map((map) => Catalogo.fromMap(map)).toList();
  }

  @override
  Future<List<String>> getCategorie() async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery(
      'SELECT DISTINCT categoria FROM ${DatabaseHelper.tableCatalogo} ORDER BY categoria ASC',
    );
    return maps.map((row) => row['categoria'] as String).toList();
  }

  @override
  Future<void> insertMateriale(Catalogo materiale) async {
    final db = await _dbHelper.database;
    await db.insert(
      DatabaseHelper.tableCatalogo,
      materiale.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteMateriale(String idMateriale) async {
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseHelper.tableCatalogo,
      where: 'id_materiale = ?',
      whereArgs: [idMateriale],
    );
  }

  @override
  Future<void> seedCatalogo() async {
    final db = await _dbHelper.database;
    await _dbHelper.seedCatalogo(db);
  }
}

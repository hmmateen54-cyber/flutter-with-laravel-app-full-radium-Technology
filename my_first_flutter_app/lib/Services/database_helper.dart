import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static Database? _database;
  static Future<Database>? _databaseFuture;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;

    final opening = _databaseFuture ??= _initDatabase();
    try {
      final opened = await opening;
      _database = opened;
      return opened;
    } catch (_) {
      _databaseFuture = null;
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();

    final dbFilePath = join(dbPath, 'my_app.db');

    return await openDatabase(
      dbFilePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY,
            brand_id INTEGER,
            name TEXT,
            price REAL,
            quantity INTEGER,
            description TEXT
          )
        ''');
      },
    );
  }

  Future<void> insertProduct(Map<String, dynamic> product) async {
    final db = await database;

    await db.insert('products', {
      'id': product['id'],
      'brand_id': product['brand_id'],
      'name': product['name'],
      'price': product['price'],
      'quantity': product['quantity'],
      'description': product['description'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Replaces the cached snapshot for one brand in a single transaction.
  Future<void> replaceProductsForBrand(
    int brandId,
    List<Map<String, dynamic>> products,
  ) async {
    final db = await database;

    await db.transaction((transaction) async {
      await transaction.delete(
        'products',
        where: 'brand_id = ?',
        whereArgs: [brandId],
      );

      final batch = transaction.batch();
      for (final product in products) {
        batch.insert(
          'products',
          _productValues(product, fallbackBrandId: brandId),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Replaces the full marketplace cache with the latest successful response.
  Future<void> replaceAllProducts(List<Map<String, dynamic>> products) async {
    final db = await database;

    await db.transaction((transaction) async {
      await transaction.delete('products');
      final batch = transaction.batch();
      for (final product in products) {
        batch.insert(
          'products',
          _productValues(product),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Map<String, dynamic>>> fetchAllProductsFromLocal() async {
    final db = await database;
    return db.query('products', orderBy: 'id DESC');
  }

  Map<String, Object?> _productValues(
    Map<String, dynamic> product, {
    int? fallbackBrandId,
  }) {
    return {
      'id': product['id'],
      'brand_id': product['brand_id'] ?? fallbackBrandId,
      'name': product['name'],
      'price': product['price'],
      'quantity': product['quantity'],
      'description': product['description'],
    };
  }

  Future<List<Map<String, dynamic>>> fetchProductsFromLocal(int brandId) async {
    final db = await database;

    final result = await db.query(
      'products',
      where: 'brand_id = ?',
      whereArgs: [brandId],
      orderBy: 'id DESC',
    );

    return result;
  }
}

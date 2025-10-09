// File: lib/shared/services/local_database_service.dart
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/order_model.dart';
// Dart
/// SQLite service provides offline-first storage for orders.
/// Why: fast UI saves, retry/sync on connectivity restore.
abstract class LocalDatabaseService {
  Future<void> init();
  Future<OrderModel> createOrder(OrderModel order);
  Future<List<OrderModel>> getUnsyncedOrders();
  Future<void> markOrderAsSynced(int localId);
  Future<void> close();

  // New methods to update order after payment or failure
  Future<void> updateOrder(OrderModel order);
  Future<void> markOrderAsFailed(int localId, {String? failureReason});
}
// Dart
class WebLocalDatabaseService implements LocalDatabaseService {
  final Map<int, OrderModel> _inMemory = {};
  int _nextId = 1;

  @override
  Future<void> init() async {
    // no-op or simple in-memory init for web
  }

  @override
  Future<void> close() async {}

  @override
  Future<OrderModel> createOrder(OrderModel order) async {
    final id = _nextId++;
    final saved = order.copyWith(localId: id);
    _inMemory[id] = saved;
    return saved;
  }

  @override
  Future<List<OrderModel>> getUnsyncedOrders() async {
    return _inMemory.values.where((o) => !o.isSynced).toList();
  }

  @override
  Future<void> markOrderAsSynced(int localId) async {
    final existing = _inMemory[localId];
    if (existing != null) {
      _inMemory[localId] = existing.copyWith(isSynced: true);
    }
  }

  @override
  Future<void> updateOrder(OrderModel order) async {
    if (order.localId == null) return;
    _inMemory[order.localId!] = order;
  }

  @override
  Future<void> markOrderAsFailed(int localId, {String? failureReason}) async {
    final existing = _inMemory[localId];
    if (existing != null) {
      _inMemory[localId] = existing.copyWith(orderStatus: 'failed');
    }
  }

  // implement other LocalDatabaseService members as no-ops or in-memory versions
}
class SqfliteLocalDatabaseService implements LocalDatabaseService {
  static const _dbName = 'agapecares.db';
  static const _ordersTable = 'orders';
  Database? _db;

  @override
  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, _dbName),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_ordersTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            isSynced INTEGER NOT NULL,
            id_str TEXT,
            userId TEXT NOT NULL,
            itemsJson TEXT NOT NULL,
            subtotal REAL NOT NULL,
            discount REAL NOT NULL,
            total REAL NOT NULL,
            paymentMethod TEXT NOT NULL,
            paymentId TEXT,
            orderStatus TEXT NOT NULL,
            userName TEXT NOT NULL,
            userEmail TEXT NOT NULL,
            userPhone TEXT NOT NULL,
            userAddress TEXT NOT NULL,
            createdAt TEXT NOT NULL
          );
        ''');
      },
    );
  }

  Database _requireDb() {
    if (_db == null) throw Exception('Local DB not initialized. Call init() first.');
    return _db!;
  }

  @override
  Future<OrderModel> createOrder(OrderModel order) async {
    final db = _requireDb();
    final values = order.toSqliteMap();
    values.remove('id'); // let sqlite assign autoincrement id
    final id = await db.insert(_ordersTable, values);
    final maps = await db.query(_ordersTable, where: 'id = ?', whereArgs: [id]);
    return OrderModel.fromSqliteMap(maps.first);
  }

  @override
  Future<List<OrderModel>> getUnsyncedOrders() async {
    final db = _requireDb();
    final maps = await db.query(_ordersTable, where: 'isSynced = ?', whereArgs: [0]);
    return maps.map((m) => OrderModel.fromSqliteMap(m)).toList();
  }

  @override
  Future<void> markOrderAsSynced(int localId) async {
    final db = _requireDb();
    await db.update(_ordersTable, {'isSynced': 1}, where: 'id = ?', whereArgs: [localId]);
  }

  @override
  Future<void> updateOrder(OrderModel order) async {
    if (order.localId == null) return;
    final db = _requireDb();
    await db.update(_ordersTable, order.toSqliteMap(), where: 'id = ?', whereArgs: [order.localId]);
  }

  @override
  Future<void> markOrderAsFailed(int localId, {String? failureReason}) async {
    final db = _requireDb();
    await db.update(_ordersTable, {'orderStatus': 'failed'}, where: 'id = ?', whereArgs: [localId]);
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

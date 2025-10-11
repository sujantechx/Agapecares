// File: lib/shared/services/local_database_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../../features/user_app/cart/data/models/cart_item_model.dart';
// Dart
/// SQLite service provides offline-first storage for orders and cart items.
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

  // --- Cart related methods ---
  Future<List<CartItemModel>> getCartItems();
  Future<void> addCartItem(CartItemModel item);
  Future<void> removeCartItem(String cartItemId);
  Future<void> updateCartItemQuantity(String cartItemId, int newQuantity);
  Future<void> clearCart();
}
// Dart
class WebLocalDatabaseService implements LocalDatabaseService {
  final Map<int, OrderModel> _inMemory = {};
  int _nextId = 1;

  // In-memory cart storage
  final Map<String, CartItemModel> _cart = {};

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

  // Cart implementations for web
  @override
  Future<List<CartItemModel>> getCartItems() async {
    return _cart.values.toList();
  }

  @override
  Future<void> addCartItem(CartItemModel item) async {
    // Debug: ensure id is valid
    assert(item.id.isNotEmpty, 'CartItem id must not be empty');
    debugPrint('[WebLocalDB] addCartItem id=${item.id} qty=${item.quantity}');
    final existing = _cart[item.id];
    if (existing != null) {
      _cart[item.id] = existing.copyWith(quantity: existing.quantity + item.quantity);
      debugPrint('[WebLocalDB] updated existing item id=${item.id} newQty=${_cart[item.id]!.quantity}');
    } else {
      _cart[item.id] = item;
      debugPrint('[WebLocalDB] inserted item id=${item.id}');
    }
  }

  @override
  Future<void> removeCartItem(String cartItemId) async {
    debugPrint('[WebLocalDB] removeCartItem id=$cartItemId');
    _cart.remove(cartItemId);
  }

  @override
  Future<void> updateCartItemQuantity(String cartItemId, int newQuantity) async {
    debugPrint('[WebLocalDB] updateCartItemQuantity id=$cartItemId newQty=$newQuantity');
    final existing = _cart[cartItemId];
    if (existing == null) return;
    if (newQuantity > 0) {
      _cart[cartItemId] = existing.copyWith(quantity: newQuantity);
      debugPrint('[WebLocalDB] updated qty id=$cartItemId newQty=$newQuantity');
    } else {
      _cart.remove(cartItemId);
      debugPrint('[WebLocalDB] removed id=$cartItemId due to qty=0');
    }
  }

  @override
  Future<void> clearCart() async {
    debugPrint('[WebLocalDB] clearCart');
    _cart.clear();
  }
}
class SqfliteLocalDatabaseService implements LocalDatabaseService {
  static const _dbName = 'agapecares.db';
  static const _ordersTable = 'orders';
  static const _cartTable = 'cart';
  Database? _db;

  // Fallback in-memory cart when sqlite is unavailable (desktop/missing ffi)
  final Map<String, CartItemModel> _fallbackCart = {};

  @override
  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final fullPath = join(dbPath, _dbName);
    debugPrint('[LocalDB] opening DB at $fullPath');
    try {
      _db = await openDatabase(
        join(dbPath, _dbName),
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $_ordersTable (
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

          await db.execute('''
            CREATE TABLE IF NOT EXISTS $_cartTable (
              id TEXT PRIMARY KEY,
              itemJson TEXT NOT NULL
            );
          ''');
        },
      );

      // Ensure tables exist in case the DB file was created earlier without them
      try {
        await _db!.execute('''
          CREATE TABLE IF NOT EXISTS $_ordersTable (
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
        await _db!.execute('''
          CREATE TABLE IF NOT EXISTS $_cartTable (
            id TEXT PRIMARY KEY,
            itemJson TEXT NOT NULL
          );
        ''');
      } catch (e, s) {
        debugPrint('[LocalDB] table ensure failed: $e\n$s');
      }
    } catch (e, s) {
      debugPrint('[LocalDB] failed to open sqlite DB, falling back to in-memory cart: $e\n$s');
      // Leave _db as null; methods will use the in-memory fallback
      _db = null;
    }
  }

  Database _requireDb() {
    if (_db == null) throw Exception('Local DB not initialized. Call init() first.');
    return _db!;
  }

  @override
  Future<OrderModel> createOrder(OrderModel order) async {
    if (_db == null) throw Exception('Orders are not supported without sqlite in this build');
    final db = _requireDb();
    final values = order.toSqliteMap();
    values.remove('id'); // let sqlite assign autoincrement id
    final id = await db.insert(_ordersTable, values);
    final maps = await db.query(_ordersTable, where: 'id = ?', whereArgs: [id]);
    return OrderModel.fromSqliteMap(maps.first);
  }

  @override
  Future<List<OrderModel>> getUnsyncedOrders() async {
    if (_db == null) return [];
    final db = _requireDb();
    final maps = await db.query(_ordersTable, where: 'isSynced = ?', whereArgs: [0]);
    return maps.map((m) => OrderModel.fromSqliteMap(m)).toList();
  }

  @override
  Future<void> markOrderAsSynced(int localId) async {
    if (_db == null) return;
    final db = _requireDb();
    await db.update(_ordersTable, {'isSynced': 1}, where: 'id = ?', whereArgs: [localId]);
  }

  @override
  Future<void> updateOrder(OrderModel order) async {
    if (_db == null) return;
    if (order.localId == null) return;
    final db = _requireDb();
    await db.update(_ordersTable, order.toSqliteMap(), where: 'id = ?', whereArgs: [order.localId]);
  }

  @override
  Future<void> markOrderAsFailed(int localId, {String? failureReason}) async {
    if (_db == null) return;
    final db = _requireDb();
    await db.update(_ordersTable, {'orderStatus': 'failed'}, where: 'id = ?', whereArgs: [localId]);
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _fallbackCart.clear();
  }

  // --- Cart methods ---
  @override
  Future<List<CartItemModel>> getCartItems() async {
    if (_db == null) {
      debugPrint('[SqfliteDB-fallback] getCartItems count=${_fallbackCart.length}');
      return _fallbackCart.values.toList();
    }
    final db = _requireDb();
    final maps = await db.query(_cartTable);
    final items = <CartItemModel>[];
    for (final m in maps) {
      final raw = m['itemJson'];
      Map<String, dynamic> decoded = {};
      if (raw is String && raw.isNotEmpty) {
        try {
          final dyn = jsonDecode(raw);
          if (dyn is Map<String, dynamic>) {
            decoded = dyn;
          } else if (dyn is Map) {
            decoded = Map<String, dynamic>.from(dyn);
          } else {
            debugPrint('[SqfliteDB] unexpected itemJson type=${dyn.runtimeType}');
          }
        } catch (e, s) {
          debugPrint('[SqfliteDB] failed to jsonDecode itemJson: $e\n$s');
          decoded = {};
        }
      }
      try {
        items.add(CartItemModel.fromJson(decoded));
      } catch (e, s) {
        debugPrint('[SqfliteDB] failed to parse CartItemModel from decoded map: $e\n$s');
        items.add(CartItemModel.fromJson(<String, dynamic>{}));
      }
    }
    debugPrint('[SqfliteDB] getCartItems count=${items.length}');
    return items;
  }

  @override
  Future<void> addCartItem(CartItemModel item) async {
    // Debug: ensure id is valid
    assert(item.id.isNotEmpty, 'CartItem id must not be empty');
    if (_db == null) {
      debugPrint('[SqfliteDB-fallback] addCartItem id=${item.id} qty=${item.quantity}');
      final existing = _fallbackCart[item.id];
      if (existing != null) {
        _fallbackCart[item.id] = existing.copyWith(quantity: existing.quantity + item.quantity);
        debugPrint('[SqfliteDB-fallback] updated existing item id=${item.id} newQty=${_fallbackCart[item.id]!.quantity}');
      } else {
        _fallbackCart[item.id] = item;
        debugPrint('[SqfliteDB-fallback] inserted item id=${item.id}');
      }
      return;
    }
    final db = _requireDb();
    debugPrint('[SqfliteDB] addCartItem id=${item.id} qty=${item.quantity}');
    // If exists, update quantity
    final existing = await db.query(_cartTable, where: 'id = ?', whereArgs: [item.id]);
    if (existing.isNotEmpty) {
      Map<String, dynamic> currentMap = {};
      final raw = existing.first['itemJson'];
      if (raw is String && raw.isNotEmpty) {
        try {
          final dyn = jsonDecode(raw);
          if (dyn is Map<String, dynamic>) currentMap = dyn;
          else if (dyn is Map) currentMap = Map<String, dynamic>.from(dyn);
        } catch (e, s) {
          debugPrint('[SqfliteDB] failed to decode existing itemJson for id=${item.id}: $e\n$s');
          currentMap = {};
        }
      }
      try {
        final current = CartItemModel.fromJson(currentMap);
        final updated = current.copyWith(quantity: current.quantity + item.quantity);
        await db.update(_cartTable, {'itemJson': jsonEncode(updated.toJson())}, where: 'id = ?', whereArgs: [item.id]);
        debugPrint('[SqfliteDB] updated existing item id=${item.id} newQty=${updated.quantity}');
      } catch (e, s) {
        // If parsing existing failed for any reason, replace with the new item
        debugPrint('[SqfliteDB] failed to parse existing CartItemModel for id=${item.id}: $e\n$s — replacing');
        await db.update(_cartTable, {'itemJson': jsonEncode(item.toJson())}, where: 'id = ?', whereArgs: [item.id]);
      }
    } else {
      await db.insert(_cartTable, {'id': item.id, 'itemJson': jsonEncode(item.toJson())});
      debugPrint('[SqfliteDB] inserted item id=${item.id}');
    }
  }

  @override
  Future<void> removeCartItem(String cartItemId) async {
    if (_db == null) {
      debugPrint('[SqfliteDB-fallback] removeCartItem id=$cartItemId');
      _fallbackCart.remove(cartItemId);
      return;
    }
    final db = _requireDb();
    debugPrint('[SqfliteDB] removeCartItem id=$cartItemId');
    await db.delete(_cartTable, where: 'id = ?', whereArgs: [cartItemId]);
  }

  @override
  Future<void> updateCartItemQuantity(String cartItemId, int newQuantity) async {
    if (_db == null) {
      debugPrint('[SqfliteDB-fallback] updateCartItemQuantity id=$cartItemId newQty=$newQuantity');
      final existing = _fallbackCart[cartItemId];
      if (existing == null) return;
      if (newQuantity > 0) {
        _fallbackCart[cartItemId] = existing.copyWith(quantity: newQuantity);
        debugPrint('[SqfliteDB-fallback] updated qty id=$cartItemId newQty=$newQuantity');
      } else {
        _fallbackCart.remove(cartItemId);
        debugPrint('[SqfliteDB-fallback] removed id=$cartItemId due to qty=0');
      }
      return;
    }
    final db = _requireDb();
    debugPrint('[SqfliteDB] updateCartItemQuantity id=$cartItemId newQty=$newQuantity');
    final existing = await db.query(_cartTable, where: 'id = ?', whereArgs: [cartItemId]);
    if (existing.isEmpty) return;
    Map<String, dynamic> currentMap = {};
    final raw = existing.first['itemJson'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final dyn = jsonDecode(raw);
        if (dyn is Map<String, dynamic>) currentMap = dyn;
        else if (dyn is Map) currentMap = Map<String, dynamic>.from(dyn);
      } catch (e, s) {
        debugPrint('[SqfliteDB] failed to decode existing itemJson for id=$cartItemId: $e\n$s');
        currentMap = {};
      }
    }
    if (newQuantity > 0) {
      try {
        final current = CartItemModel.fromJson(currentMap);
        final updated = current.copyWith(quantity: newQuantity);
        await db.update(_cartTable, {'itemJson': jsonEncode(updated.toJson())}, where: 'id = ?', whereArgs: [cartItemId]);
        debugPrint('[SqfliteDB] updated qty id=$cartItemId newQty=$newQuantity');
      } catch (e, s) {
        debugPrint('[SqfliteDB] failed to update quantity for id=$cartItemId: $e\n$s');
      }
    } else {
      await removeCartItem(cartItemId);
      debugPrint('[SqfliteDB] removed id=$cartItemId due to qty=0');
    }
  }

  @override
  Future<void> clearCart() async {
    if (_db == null) {
      debugPrint('[SqfliteDB-fallback] clearCart');
      _fallbackCart.clear();
      return;
    }
    final db = _requireDb();
    debugPrint('[SqfliteDB] clearCart');
    await db.delete(_cartTable);
  }
}

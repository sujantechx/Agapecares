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
  // In-memory orders fallback when sqlite is unavailable or insert fails
  final Map<int, OrderModel> _inMemoryOrders = {};
  int _nextInMemoryOrderId = 1;

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
              orderNumber TEXT,
              paymentStatus TEXT NOT NULL,
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
              workerId TEXT,
              workerName TEXT,
              acceptedAt TEXT,
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
            orderNumber TEXT,
            paymentStatus TEXT NOT NULL,
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
            workerId TEXT,
            workerName TEXT,
            acceptedAt TEXT,
            createdAt TEXT NOT NULL
          );
        ''');
        await _db!.execute('''
          CREATE TABLE IF NOT EXISTS $_cartTable (
            id TEXT PRIMARY KEY,
            itemJson TEXT NOT NULL
          );
        ''');
        // Ensure any new columns are present in existing DB (migration for older installs)
        await _ensureOrdersTableColumns();
      } catch (e, s) {
        debugPrint('[LocalDB] table ensure failed: $e\n$s');
      }
    } catch (e, s) {
      debugPrint('[LocalDB] failed to open sqlite DB, falling back to in-memory cart: $e\n$s');
      // Leave _db as null; methods will use the in-memory fallback
      _db = null;
    }
  }

  // Ensure the orders table has the expected columns (migration step for existing DB files).
  Future<void> _ensureOrdersTableColumns() async {
    if (_db == null) return;
    try {
      final db = _requireDb();
      final info = await db.rawQuery("PRAGMA table_info($_ordersTable);");
      final existingCols = <String>{};
      for (final row in info) {
        final name = row['name'] as String? ?? (row['NAME'] as String? ?? '');
        if (name.isNotEmpty) existingCols.add(name);
      }
      // Add orderNumber column if missing
      if (!existingCols.contains('orderNumber')) {
        try {
          await db.execute('ALTER TABLE $_ordersTable ADD COLUMN orderNumber TEXT;');
          debugPrint('[LocalDB] migrated: added orderNumber column to $_ordersTable');
          // refresh cache
          _ordersTableColumnsCache = null;
        } catch (e) {
          debugPrint('[LocalDB] failed to add orderNumber column: $e');
        }
      }
      // Add paymentStatus column if missing
      if (!existingCols.contains('paymentStatus')) {
        try {
          await db.execute("ALTER TABLE $_ordersTable ADD COLUMN paymentStatus TEXT NOT NULL DEFAULT 'pending';");
          debugPrint('[LocalDB] migrated: added paymentStatus column to $_ordersTable');
          _ordersTableColumnsCache = null;
        } catch (e) {
          debugPrint('[LocalDB] failed to add paymentStatus column: $e');
        }
      }
      // Add worker-related columns if missing
      if (!existingCols.contains('workerId')) {
        try {
          await db.execute('ALTER TABLE $_ordersTable ADD COLUMN workerId TEXT;');
          debugPrint('[LocalDB] migrated: added workerId column to $_ordersTable');
          _ordersTableColumnsCache = null;
        } catch (e) {
          debugPrint('[LocalDB] failed to add workerId column: $e');
        }
      }
      if (!existingCols.contains('workerName')) {
        try {
          await db.execute('ALTER TABLE $_ordersTable ADD COLUMN workerName TEXT;');
          debugPrint('[LocalDB] migrated: added workerName column to $_ordersTable');
          _ordersTableColumnsCache = null;
        } catch (e) {
          debugPrint('[LocalDB] failed to add workerName column: $e');
        }
      }
      if (!existingCols.contains('acceptedAt')) {
        try {
          await db.execute('ALTER TABLE $_ordersTable ADD COLUMN acceptedAt TEXT;');
          debugPrint('[LocalDB] migrated: added acceptedAt column to $_ordersTable');
          _ordersTableColumnsCache = null;
        } catch (e) {
          debugPrint('[LocalDB] failed to add acceptedAt column: $e');
        }
      }
    } catch (e, s) {
      debugPrint('[LocalDB] _ensureOrdersTableColumns failed: $e\n$s');
    }
  }

  Database _requireDb() {
    if (_db == null) throw Exception('Local DB not initialized. Call init() first.');
    return _db!;
  }

  // Cache of existing columns for orders table to avoid repeated PRAGMA queries
  Set<String>? _ordersTableColumnsCache;

  Future<Set<String>> _getOrdersTableColumns() async {
    if (_ordersTableColumnsCache != null) return _ordersTableColumnsCache!;
    final db = _requireDb();
    try {
      final info = await db.rawQuery("PRAGMA table_info($_ordersTable);");
      final cols = <String>{};
      for (final row in info) {
        final name = row['name'] as String? ?? (row['NAME'] as String? ?? '');
        if (name.isNotEmpty) cols.add(name);
      }
      _ordersTableColumnsCache = cols;
      return cols;
    } catch (e) {
      debugPrint('[LocalDB] _getOrdersTableColumns error: $e');
      _ordersTableColumnsCache = <String>{};
      return _ordersTableColumnsCache!;
    }
  }

  // Remove any keys from the map that are not actual columns in the orders table.
  Future<Map<String, Object?>> _filterMapToExistingOrderColumns(Map<String, Object?> values) async {
    final cols = await _getOrdersTableColumns();
    final filtered = <String, Object?>{};
    values.forEach((k, v) {
      if (cols.contains(k)) filtered[k] = v;
    });
    return filtered;
  }

  @override
  Future<OrderModel> createOrder(OrderModel order) async {
    if (_db == null) {
      // fallback to in-memory orders store
      final id = _nextInMemoryOrderId++;
      final saved = order.copyWith(localId: id);
      _inMemoryOrders[id] = saved;
      return saved;
    }
    final db = _requireDb();
    // Always regenerate the values from the model here
    final values = Map<String, dynamic>.from(order.toSqliteMap());
    values.remove('id'); // let sqlite assign autoincrement id
    try {
      // Ensure we have the latest PRAGMA information and try to migrate missing columns
      await _ensureOrdersTableColumns();

      // Refresh cached columns
      _ordersTableColumnsCache = null;
      final cols = await _getOrdersTableColumns();

      // If the order lacks an orderNumber and the DB supports the column, generate one.
      if ((values['orderNumber'] == null || (values['orderNumber'] as String).isEmpty) && cols.contains('orderNumber')) {
        try {
          final generated = await _generateOrderNumber(db);
          values['orderNumber'] = generated;
          debugPrint('[LocalDB] generated orderNumber=$generated');
        } catch (e) {
          debugPrint('[LocalDB] failed to generate orderNumber: $e');
        }
      }

      // Defensive: filter to only existing columns (avoid SQLite 'no column named' errors)
      final filtered = await _filterMapToExistingOrderColumns(values);

      final id = await db.insert(_ordersTable, filtered);
      final maps = await db.query(_ordersTable, where: 'id = ?', whereArgs: [id]);
      return OrderModel.fromSqliteMap(maps.first);
    } catch (e, s) {
      debugPrint('[LocalDB] createOrder insert failed: $e — attempting targeted migration and retry\n$s');
      // If the insert failed due to missing columns, try to parse the error and remove offending keys then retry.
      try {
        // Refresh PRAGMA info to get any recent changes
        _ordersTableColumnsCache = null;
        final cols = await _getOrdersTableColumns();
        // Identify keys that are not in the table and drop them before retry
        final toRemove = <String>[];
        for (final k in values.keys) {
          if (!cols.contains(k)) toRemove.add(k);
        }
        if (toRemove.isNotEmpty) {
          debugPrint('[LocalDB] removing unknown order columns before retry: $toRemove');
          for (final k in toRemove) values.remove(k);
        }

        // If orderNumber still missing but DB now supports it, generate.
        if ((values['orderNumber'] == null || (values['orderNumber'] as String).isEmpty) && cols.contains('orderNumber')) {
          try {
            final generated = await _generateOrderNumber(db);
            values['orderNumber'] = generated;
            debugPrint('[LocalDB] generated orderNumber (retry)=$generated');
          } catch (e) {
            debugPrint('[LocalDB] failed to generate orderNumber on retry: $e');
          }
        }

        final filtered = await _filterMapToExistingOrderColumns(values);
        final id = await db.insert(_ordersTable, filtered);
        final maps = await db.query(_ordersTable, where: 'id = ?', whereArgs: [id]);
        return OrderModel.fromSqliteMap(maps.first);
      } catch (e2, s2) {
        debugPrint('[LocalDB] createOrder retry after targeted migration failed: $e2 — falling back to in-memory orders\n$s2');
        // Fall back to in-memory store so the app can continue
        final id = _nextInMemoryOrderId++;
        final saved = order.copyWith(localId: id);
        _inMemoryOrders[id] = saved;
        return saved;
      }
    }
  }

  // Generate a stable orderNumber in format YYYYMMDDxxxxx where xxxxx is a 5-digit increment per day.
  Future<String> _generateOrderNumber(Database db) async {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final prefix = '$y$m$d';

    // Ensure the orders table actually has orderNumber column before querying
    final cols = await _getOrdersTableColumns();
    if (!cols.contains('orderNumber')) {
      throw Exception('orders table missing orderNumber column');
    }

    // Query the last orderNumber for today
    try {
      // Use LIKE to find today's orders and order by orderNumber desc to get the highest suffix
      final res = await db.rawQuery(
        "SELECT orderNumber FROM $_ordersTable WHERE orderNumber LIKE ? ORDER BY orderNumber DESC LIMIT 1",
        ["$prefix%"],
      );
      if (res.isEmpty) {
        // Start suffix at 00100 as baseline
        return '$prefix${'100'.padLeft(5, '0')}';
      }
      final last = res.first['orderNumber'] as String? ?? '';
      if (last.length <= prefix.length) {
        // Start suffix at 00100 as baseline
        return '$prefix${'100'.padLeft(5, '0')}';
      }
      final suffix = last.substring(prefix.length);
      final parsed = int.tryParse(suffix);
      final lastNum = (parsed == null) ? 0 : parsed;
      // Ensure we never go below baseline 100
      final nextNum = (lastNum < 100) ? 100 : (lastNum + 1);
      return prefix + nextNum.toString().padLeft(5, '0');
    } catch (e) {
      debugPrint('[LocalDB] _generateOrderNumber failed: $e');
      // Fallback: use timestamp-based unique suffix
      final stamp = DateTime.now().millisecondsSinceEpoch.remainder(100000).toString().padLeft(5, '0');
      return prefix + stamp;
    }
  }

  @override
  Future<List<OrderModel>> getUnsyncedOrders() async {
    final results = <OrderModel>[];
    if (_db != null) {
      final db = _requireDb();
      final maps = await db.query(_ordersTable, where: 'isSynced = ?', whereArgs: [0]);
      results.addAll(maps.map((m) => OrderModel.fromSqliteMap(m)));
    }
    // Append any in-memory orders that are not synced
    results.addAll(_inMemoryOrders.values.where((o) => !o.isSynced));
    return results;
  }

  @override
  Future<void> markOrderAsSynced(int localId) async {
    if (_db == null) {
      final existing = _inMemoryOrders[localId];
      if (existing != null) _inMemoryOrders[localId] = existing.copyWith(isSynced: true);
      return;
    }
    final db = _requireDb();
    try {
      await db.update(_ordersTable, {'isSynced': 1}, where: 'id = ?', whereArgs: [localId]);
    } catch (e) {
      debugPrint('[LocalDB] markOrderAsSynced failed: $e');
    }
  }

  @override
  Future<void> updateOrder(OrderModel order) async {
    if (order.localId == null) return;
    if (_db == null) {
      final existing = _inMemoryOrders[order.localId!];
      if (existing != null) _inMemoryOrders[order.localId!] = order;
      return;
    }
    final db = _requireDb();
    try {
      final values = order.toSqliteMap();
      final filtered = await _filterMapToExistingOrderColumns(values);
      await db.update(_ordersTable, filtered, where: 'id = ?', whereArgs: [order.localId]);
    } catch (e) {
      debugPrint('[LocalDB] updateOrder failed: $e — updating in-memory fallback');
      _inMemoryOrders[order.localId!] = order;
    }
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
          // Offload JSON decoding to a background isolate to avoid jank on the UI thread.
          final dyn = await compute(_backgroundDecode, raw);
          if (dyn is Map<String, dynamic>) {
            decoded = dyn;
          } else if (dyn is Map) {
            decoded = Map<String, dynamic>.from(dyn);
          } else {
            debugPrint('[SqfliteDB] unexpected itemJson type=${dyn.runtimeType}');
          }
        } catch (e, s) {
          debugPrint('[SqfliteDB] failed to jsonDecode itemJson in isolate: $e\n$s');
          decoded = {};
        }
      }
      try {
        // Ensure we pass a non-null Map to fromJson; CartItemModel.fromJson handles empty maps.
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
          final dyn = await compute(_backgroundDecode, raw);
          if (dyn is Map<String, dynamic>) currentMap = dyn;
          else if (dyn is Map) currentMap = Map<String, dynamic>.from(dyn);
        } catch (e, s) {
          debugPrint('[SqfliteDB] failed to decode existing itemJson for id=${item.id} in isolate: $e\n$s');
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
        final dyn = await compute(_backgroundDecode, raw);
        if (dyn is Map<String, dynamic>) currentMap = dyn;
        else if (dyn is Map) currentMap = Map<String, dynamic>.from(dyn);
      } catch (e, s) {
        debugPrint('[SqfliteDB] failed to decode existing itemJson for id=$cartItemId in isolate: $e\n$s');
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

// Top-level function used by compute to decode JSON in a background isolate.
dynamic _backgroundDecode(String raw) {
  return jsonDecode(raw);
}

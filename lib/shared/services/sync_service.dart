// filepath: c:\FlutterDev\project\agapecares\lib\shared\services\sync_service.dart
// File: lib/shared/services/sync_service.dart
import 'dart:async';
import 'dart:io';

import '../../features/user_app/data/repositories/order_repository.dart';

/// A small background sync service that periodically checks connectivity
/// by attempting a DNS lookup and triggers `OrderRepository.syncUnsynced()` when online.
class SyncService {
  final OrderRepository _orderRepository;
  Timer? _timer;
  final Duration interval;
  bool _isRunning = false;

  SyncService({required OrderRepository orderRepository, this.interval = const Duration(seconds: 15)})
      : _orderRepository = orderRepository;

  /// Start periodic checks and immediate sync attempt.
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    // immediate try
    _trySyncIfOnline();
    _timer = Timer.periodic(interval, (_) => _trySyncIfOnline());
  }

  Future<void> _trySyncIfOnline() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
        try {
          await _orderRepository.syncUnsynced();
        } catch (_) {
          // ignore: will retry on next tick
        }
      }
    } catch (_) {
      // no internet; skip
    }
  }

  Future<void> triggerSync() async {
    await _orderRepository.syncUnsynced();
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }
}

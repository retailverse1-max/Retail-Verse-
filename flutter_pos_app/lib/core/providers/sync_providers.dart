import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_service.dart';
import '../../data/local/sync_queue_local_service.dart';
import '../../data/local/order_local_service.dart';
import '../../features/dashboard/providers/dashboard_providers.dart';
import '../../features/pos/providers/product_providers.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    syncQueueService: SyncQueueLocalService(),
    orderLocalService: OrderLocalService(),
    onSyncComplete: () {
      debugPrint('SyncService: A sync completed, invalidating providers to fetch fresh remote data...');
      ref.invalidate(dashboardProductsProvider);
      ref.invalidate(productsProvider);
      ref.invalidate(lowStockProductsProvider);
    },
  );

  service.initialize();

  final sub = Connectivity().onConnectivityChanged.listen((results) {
    final List<ConnectivityResult> connectivityResults = 
          results is List ? (results as List).cast<ConnectivityResult>() : [results as ConnectivityResult];
    final isOnline = !connectivityResults.contains(ConnectivityResult.none);
    if (isOnline) {
      debugPrint('Network is online, triggering background sync queue...');
      service.processSyncQueue();
    }
  });

  ref.onDispose(() => sub.cancel());
  return service;
});

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:retail_verse_pos/features/inventory/data/models/category_entity.dart';
import 'package:retail_verse_pos/features/inventory/providers/category_providers.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/providers/api_config_provider.dart';
import '../../../data/datasources/product_remote_datasource.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/product_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/local/product_local_service.dart';
import '../../../data/local/sync_queue_local_service.dart';

final posHttpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  ref.watch(apiConfigRefreshProvider);
  return ProductRepository(
    dataSource: ProductRemoteDataSource(
      client: ref.read(posHttpClientProvider),
      baseUrl: ApiEndpoints.baseUrl,
    ),
  );
});

/// Last POS catalog load error (network/API). Cleared on successful fetch.
final productCatalogErrorProvider = StateProvider<String?>((ref) => null);

/// POS product list: real backend via [ProductRemoteDataSource] (Bearer from session).
/// On failure returns an empty list (no red AsyncError) so the UI can show a fix-connection state.
final productsProvider = FutureProvider<List<Product>>((ref) async {
  final token = ref.watch(authProvider.select((s) => s.token));
  if (token == null || token.isEmpty) {
    Future.microtask(() {
      if (ref.exists(productCatalogErrorProvider)) {
        ref.read(productCatalogErrorProvider.notifier).state = null;
      }
    });
    return [];
  }
  final repository = ref.watch(productRepositoryProvider);
  
  Future.microtask(() {
    if (ref.exists(productCatalogErrorProvider)) {
      ref.read(productCatalogErrorProvider.notifier).state = null;
    }
  });

  try {
    final pendingCount = await SyncQueueLocalService().getPendingCount();
    if (pendingCount > 0) {
      if (kDebugMode) {
        debugPrint('productsProvider: Using local DB to prevent stale data since there are $pendingCount offline orders pending sync.');
      }
      final localProducts = await ProductLocalService().getAllProducts();
      if (localProducts.isNotEmpty) return localProducts;
    }
  } catch (_) {}

  try {
    return await repository.getAllProducts();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('productsProvider: catalog load failed → fallback to local. $e');
    }
    
    // Fallback to local DB
    try {
      final localService = ProductLocalService();
      final localProducts = await localService.getAllProducts();
      if (localProducts.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('productsProvider: recovered ${localProducts.length} from local DB');
        }
        return localProducts;
      }
    } catch (localErr) {
      if (kDebugMode) {
        debugPrint('productsProvider: local DB fallback failed: $localErr');
      }
    }

    Future.microtask(() {
      if (ref.exists(productCatalogErrorProvider)) {
        ref.read(productCatalogErrorProvider.notifier).state = e.toString();
      }
    });
    return [];
  }
});

final searchProductsProvider = FutureProvider.family<List<Product>, String>((
  ref,
  query,
) async {
  final repository = ref.watch(productRepositoryProvider);
  try {
    return await repository.searchProducts(query);
  } catch (e) {
    try {
      return await ProductLocalService().searchProducts(query);
    } catch (_) {
      return [];
    }
  }
});

final productsByCategoryProvider = FutureProvider.family<List<Product>, String>(
  (ref, category) async {
    final repository = ref.watch(productRepositoryProvider);
    try {
      return await repository.getProductsByCategory(category);
    } catch (e) {
      try {
        final all = await ProductLocalService().getAllProducts();
        return all.where((p) => p.category.toLowerCase() == category.toLowerCase()).toList();
      } catch (_) {
        return [];
      }
    }
  },
);

final lowStockProductsProvider = FutureProvider<List<Product>>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  try {
    return await repository.getLowStockProducts(10);
  } catch (e) {
    try {
      return await ProductLocalService().getLowStockProducts();
    } catch (_) {
      return [];
    }
  }
});

/// Products whose `category` matches [categoryName] (case-insensitive). Uses GET /products + filter.
final categoryProductsProvider =
    FutureProvider.autoDispose.family<List<Product>, String>((ref, categoryName) async {
  final repository = ref.watch(productRepositoryProvider);
  try {
    return await repository.getProductsByCategory(categoryName);
  } catch (e) {
    try {
      final all = await ProductLocalService().getAllProducts();
      return all.where((p) => p.category.toLowerCase() == categoryName.toLowerCase()).toList();
    } catch (_) {
      return [];
    }
  }
});

final posCategoriesProvider = FutureProvider<List<CategoryEntity>>((ref) async {
  return ref.watch(categoriesProvider.future);
});

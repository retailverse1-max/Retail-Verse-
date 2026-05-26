import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:retail_verse_pos/features/inventory/data/local/category_local_service.dart';
import 'package:retail_verse_pos/features/inventory/data/models/category_entity.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/providers/api_config_provider.dart';
import '../../../data/datasources/product_remote_datasource.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/product_repository.dart';
import '../../auth/providers/auth_provider.dart';

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
    ref.read(productCatalogErrorProvider.notifier).state = null;
    return [];
  }
  final repository = ref.watch(productRepositoryProvider);
  ref.read(productCatalogErrorProvider.notifier).state = null;
  try {
    return await repository.getAllProducts();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('productsProvider: catalog load failed → empty list. $e');
    }
    ref.read(productCatalogErrorProvider.notifier).state = e.toString();
    return [];
  }
});

final searchProductsProvider = FutureProvider.family<List<Product>, String>((
  ref,
  query,
) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.searchProducts(query);
});

final productsByCategoryProvider = FutureProvider.family<List<Product>, String>(
  (ref, category) async {
    final repository = ref.watch(productRepositoryProvider);
    return repository.getProductsByCategory(category);
  },
);

final lowStockProductsProvider = FutureProvider<List<Product>>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getLowStockProducts(10);
});

/// Products whose `category` matches [categoryName] (case-insensitive). Uses GET /products + filter.
final categoryProductsProvider =
    FutureProvider.autoDispose.family<List<Product>, String>((ref, categoryName) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getProductsByCategory(categoryName);
});

/// Fetches categories from the SQLite local categories table
final posCategoriesProvider = FutureProvider<List<CategoryEntity>>((ref) async {
  final service = CategoryLocalService();
  return service.getAllCategories();
});

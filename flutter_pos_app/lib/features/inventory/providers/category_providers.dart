import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../pos/providers/product_providers.dart';
import '../data/local/category_local_service.dart';
import '../data/remote/category_remote_datasource.dart';
import '../data/repositories/category_repository.dart';
import '../data/models/category_entity.dart';

import '../../../data/local/product_local_service.dart';
import '../../../data/models/product_model.dart';

final categoryLocalServiceProvider = Provider<CategoryLocalService>((ref) {
  return CategoryLocalService();
});

final categoryRemoteDataSourceProvider = Provider<CategoryRemoteDataSource>((ref) {
  return CategoryRemoteDataSource(
    client: ref.read(posHttpClientProvider),
    baseUrl: ApiEndpoints.baseUrl,
  );
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(
    localService: ref.read(categoryLocalServiceProvider),
    remoteDataSource: ref.read(categoryRemoteDataSourceProvider),
  );
});

final categoriesProvider = FutureProvider<List<CategoryEntity>>((ref) async {
  final repository = ref.watch(categoryRepositoryProvider);
  final dbCategories = await repository.getAllCategories();
  
  // Dynamically extract categories from all products to avoid "orphaned" categories
  List<Product> products = [];
  try {
    products = await ref.watch(productsProvider.future);
  } catch (_) {}
  if (products.isEmpty) {
    try {
      products = await ProductLocalService().getAllProducts();
    } catch (_) {}
  }
  
  // Compute product count for existing categories from local products
  final productCountMap = <String, int>{};
  for (final p in products) {
    final catName = p.category.trim().toLowerCase();
    if (catName.isNotEmpty) {
      productCountMap[catName] = (productCountMap[catName] ?? 0) + 1;
    }
  }
  
  final updatedDbCategories = dbCategories.map((c) {
    final count = productCountMap[c.name.trim().toLowerCase()] ?? c.productCount;
    return c.copyWith(productCount: count);
  }).toList();

  final dbCategoryNames = dbCategories.map((c) => c.name.trim().toLowerCase()).toSet();
  final virtualCategories = <String, CategoryEntity>{};
  
  for (final p in products) {
    final catName = p.category.trim();
    if (catName.isEmpty) continue;
    
    final lowerName = catName.toLowerCase();
    if (!dbCategoryNames.contains(lowerName)) {
      if (virtualCategories.containsKey(lowerName)) {
        final existing = virtualCategories[lowerName]!;
        virtualCategories[lowerName] = existing.copyWith(
          productCount: existing.productCount + 1,
        );
      } else {
        virtualCategories[lowerName] = CategoryEntity(
          id: 'virtual_$lowerName',
          name: catName,
          subtitle: 'Generated from products',
          imagePath: '',
          productCount: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
    }
  }
  
  final allCategories = [...updatedDbCategories, ...virtualCategories.values];
  allCategories.sort((a, b) => a.name.compareTo(b.name));
  
  return allCategories;
});

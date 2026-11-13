import 'package:flutter/foundation.dart';
import '../models/category_entity.dart';
import '../local/category_local_service.dart';
import '../remote/category_remote_datasource.dart';
import '../../../../data/local/product_local_service.dart';

class CategoryRepository {
  final CategoryLocalService localService;
  final CategoryRemoteDataSource remoteDataSource;

  CategoryRepository({
    required this.localService,
    required this.remoteDataSource,
  });

  Future<List<CategoryEntity>> getAllCategories() async {
    try {
      final remoteCategories = await remoteDataSource.getCategories();
      await localService.clearAllCategories();
      for (final cat in remoteCategories) {
        await localService.insertCategory(cat);
      }
      return remoteCategories;
    } catch (e) {
      debugPrint('Failed to fetch categories from remote, falling back to local: $e');
      return localService.getAllCategories();
    }
  }

  Future<void> syncCategories() async {
    try {
      final remoteCategories = await remoteDataSource.getCategories();
      await localService.clearAllCategories();
      for (final cat in remoteCategories) {
        await localService.insertCategory(cat);
      }
    } catch (e) {
      debugPrint('Category sync failed: $e');
    }
  }

  Future<CategoryEntity> addCategory(CategoryEntity category) async {
    try {
      final created = await remoteDataSource.createCategory(category);
      await localService.insertCategory(created);
      return created;
    } catch (e) {
      debugPrint('Failed to create category on remote: $e');
      // If remote fails, still add to local to allow offline support
      await localService.insertCategory(category);
      return category;
    }
  }

  Future<void> updateCategory(CategoryEntity category) async {
    try {
      final updated = await remoteDataSource.updateCategory(category);
      await localService.updateCategory(updated);
    } catch (e) {
      debugPrint('Failed to update category on remote: $e');
      await localService.updateCategory(category);
      rethrow;
    }
  }

  Future<void> deleteCategory(String id, {String? categoryName}) async {
    try {
      await remoteDataSource.deleteCategory(id);
    } catch (e) {
      debugPrint('Failed to delete category on remote: $e');
    }
    await localService.deleteCategory(id);
    if (categoryName != null && categoryName.trim().isNotEmpty) {
      try {
        await ProductLocalService().deleteProductsByCategory(categoryName.trim());
      } catch (e) {
        debugPrint('Failed to delete local products for category: $e');
      }
    }
  }
}

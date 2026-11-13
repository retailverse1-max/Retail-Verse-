import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/repositories/marketplace_repository.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../pos/providers/product_providers.dart';
import '../../../inventory/data/models/category_entity.dart' as inv;
import '../../../inventory/providers/category_providers.dart';

class CategoryMappingScreen extends ConsumerStatefulWidget {
  const CategoryMappingScreen({super.key});

  @override
  ConsumerState<CategoryMappingScreen> createState() => _CategoryMappingScreenState();
}

class _CategoryMappingScreenState extends ConsumerState<CategoryMappingScreen> {
  bool _isLoading = true;
  List<dynamic> _mappings = [];
  inv.CategoryEntity? _selectedLocalCategory;
  final _platformCategoryIdController = TextEditingController();
  final _platformCategoryNameController = TextEditingController();
  
  final MarketplaceRepository _repo = MarketplaceRepository();

  @override
  void initState() {
    super.initState();
    _fetchMappings();
  }

  Future<void> _fetchMappings() async {
    setState(() => _isLoading = true);
    try {
      final token = ref.read(authProvider).token;
      if (token != null) {
        final mappings = await _repo.fetchCategoryMappings(token);
        setState(() => _mappings = mappings);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(duration: const Duration(seconds: 2),content: Text(e.toString()), backgroundColor: AppColors.secondary));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMapping() async {
    if (_selectedLocalCategory == null || _platformCategoryIdController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final token = ref.read(authProvider).token;
      if (token != null) {
        await _repo.saveCategoryMapping(
          token: token,
          retailCategoryId: _selectedLocalCategory!.id,
          platformCategoryId: _platformCategoryIdController.text.trim(),
          platformCategoryName: _platformCategoryNameController.text.trim(),
        );
        await _fetchMappings(); // Refresh list
        
        // Clear form
        _selectedLocalCategory = null;
        _platformCategoryIdController.clear();
        _platformCategoryNameController.clear();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration: const Duration(seconds: 2),content: Text('Category mapping saved successfully!'), backgroundColor: AppColors.secondary));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(duration: const Duration(seconds: 2),content: Text(e.toString()), backgroundColor: AppColors.secondary));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Category Mapping', style: AppTypography.headlineSmall.copyWith(color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Add New Mapping', style: AppTypography.titleLarge),
                        const SizedBox(height: 16),
                        
                        categoriesAsync.when(
                          data: (categories) => DropdownButtonFormField<inv.CategoryEntity>(
                            decoration: InputDecoration(
                              labelText: 'Local Category',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            value: _selectedLocalCategory,
                            items: categories.map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat.name),
                            )).toList(),
                            onChanged: (val) => setState(() => _selectedLocalCategory = val),
                          ),
                          loading: () => const LinearProgressIndicator(),
                          error: (e, st) => Text('Failed to load categories: $e'),
                        ),
                        
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _platformCategoryIdController,
                          decoration: InputDecoration(
                            labelText: 'Flipkart Category ID (e.g., clothing_tshirt_mens)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _platformCategoryNameController,
                          decoration: InputDecoration(
                            labelText: 'Flipkart Category Name (Optional)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saveMapping,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Save Mapping'),
                          ),
                        )
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // List Section
                  Text('Existing Mappings', style: AppTypography.titleLarge),
                  const SizedBox(height: 16),
                  
                  if (_mappings.isEmpty)
                    const Text('No mappings found. Add your first mapping above.', style: TextStyle(color: Colors.grey))
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _mappings.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final mapping = _mappings[index];
                        final localCatName = mapping['retailVerseCategoryId'] != null 
                            ? mapping['retailVerseCategoryId']['name'] 
                            : 'Unknown Local Category';
                            
                        return ListTile(
                          tileColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          title: Text('$localCatName → ${mapping['platformCategoryId']}'),
                          subtitle: Text('Flipkart Category Name: ${mapping['platformCategoryName'] ?? 'N/A'}'),
                          leading: const Icon(Icons.link, color: AppColors.primary),
                        );
                      },
                    )
                ],
              ),
            ),
    );
  }
}

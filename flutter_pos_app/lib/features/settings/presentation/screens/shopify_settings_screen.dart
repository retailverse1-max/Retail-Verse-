import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/repositories/marketplace_repository.dart';
import '../../../auth/providers/auth_provider.dart';

class ShopifySettingsScreen extends ConsumerStatefulWidget {
  const ShopifySettingsScreen({super.key});

  @override
  ConsumerState<ShopifySettingsScreen> createState() => _ShopifySettingsScreenState();
}

class _ShopifySettingsScreenState extends ConsumerState<ShopifySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeUrlController = TextEditingController();
  final _accessTokenController = TextEditingController();
  bool _isLoading = false;

  final MarketplaceRepository _repo = MarketplaceRepository();

  Future<void> _connectShopify() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final token = ref.read(authProvider).token;
      if (token == null) throw Exception('Authentication token missing');

      final response = await _repo.connectShopify(
        storeUrl: _storeUrlController.text.trim(),
        accessToken: _accessTokenController.text.trim(),
        token: token,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(duration: const Duration(seconds: 2),
            content: Text(response['message'] ?? 'Successfully connected to Shopify!'),
            backgroundColor: AppColors.secondary,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(duration: const Duration(seconds: 2),
            content: Text(e.toString()),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Shopify Connection', style: AppTypography.headlineSmall.copyWith(color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.storefront_outlined, color: Colors.green),
                        ),
                        const SizedBox(width: 16),
                        Text('Shopify Integration', style: AppTypography.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _storeUrlController,
                      decoration: InputDecoration(
                        labelText: 'Store URL (e.g. mystore.myshopify.com)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _accessTokenController,
                      decoration: InputDecoration(
                        labelText: 'Admin API Access Token',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _connectShopify,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size(double.infinity, 50),
                              backgroundColor: Colors.green,
                            ),
                            child: const Text('Connect to Shopify'),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

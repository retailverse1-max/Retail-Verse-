import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../dashboard/providers/dashboard_providers.dart';
import '../../../../features/auth/providers/auth_provider.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  final String? initialName;
  final String? initialPhone;
  final String? initialAddress;

  const AddCustomerScreen({
    super.key,
    this.initialName,
    this.initialPhone,
    this.initialAddress,
  });

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _emailController = TextEditingController();
    _addressController = TextEditingController(text: widget.initialAddress);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final token = ref.read(authProvider).token!;
      final dataSource = ref.read(dashboardRemoteDataSourceProvider);

      final success = await dataSource.addCustomer(
        token: token,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      );

      setState(() => _isLoading = false);

      if (success) {
        ref.invalidate(customersProvider);
        ref.invalidate(dashboardStatsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(duration: const Duration(seconds: 2),
              content: Text(
                'Customer added successfully!',
                style: AppTypography.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          context.pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(duration: const Duration(seconds: 2),
              content: const Text('Failed to add customer. Please verify details.'),
              backgroundColor: AppColors.secondary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      final errorMsg = e.toString().replaceAll('Exception:', '').trim();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(duration: const Duration(seconds: 2),
            content: Text(errorMsg),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Add New Customer',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFieldTitle('Full Name *'),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('Enter customer name', Icons.person_outline_rounded),
                validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 20),
              _buildFieldTitle('Phone Number *'),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration('Enter phone number', Icons.phone_outlined),
                validator: (v) => v == null || v.isEmpty ? 'Phone is required' : null,
              ),
              const SizedBox(height: 20),
              _buildFieldTitle('Email Address'),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration('Enter email (optional)', Icons.email_outlined),
              ),
              const SizedBox(height: 20),
              _buildFieldTitle('Delivery Address'),
              TextFormField(
                controller: _addressController,
                maxLines: 3,
                decoration: _inputDecoration('Enter full address', Icons.location_on_outlined),
              ),
              const SizedBox(height: 40),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text('Save Customer', style: AppTypography.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.border.withOpacity(0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.border.withOpacity(0.5)),
      ),
    );
  }
}

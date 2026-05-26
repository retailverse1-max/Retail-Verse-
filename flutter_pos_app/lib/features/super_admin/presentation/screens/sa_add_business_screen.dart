import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/data/remote/super_admin_service.dart';

class SaAddBusinessScreen extends StatefulWidget {
  const SaAddBusinessScreen({super.key});

  @override
  State<SaAddBusinessScreen> createState() => _SaAddBusinessScreenState();
}

class _SaAddBusinessScreenState extends State<SaAddBusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _owner = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _type = TextEditingController();
  final _notes = TextEditingController();
  
  final _svc = SuperAdminService();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _owner.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _type.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _svc.createBusiness(
        businessName: _name.text,
        ownerName: _owner.text,
        ownerEmail: _email.text,
        phone: _phone.text,
        address: _address.text,
        businessType: _type.text,
        notes: _notes.text,
      );
      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _saving = false);
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
        title: Text('Register New Client', style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w900)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('Business Information'),
              const SizedBox(height: 16),
              _buildField(_name, 'Business Name *', Icons.business_rounded, required: true),
              const SizedBox(height: 16),
              _buildField(_type, 'Business Type (e.g. Retail, Cafe)', Icons.category_rounded),
              
              const SizedBox(height: 32),
              _buildSectionTitle('Owner Details'),
              const SizedBox(height: 16),
              _buildField(_owner, 'Full Name', Icons.person_rounded),
              const SizedBox(height: 16),
              _buildField(_email, 'Email Address', Icons.email_rounded),
              const SizedBox(height: 16),
              _buildField(_phone, 'Phone Number', Icons.phone_rounded),

              const SizedBox(height: 32),
              _buildSectionTitle('Additional Details'),
              const SizedBox(height: 16),
              _buildField(_address, 'Full Address', Icons.location_on_rounded, maxLines: 3),
              const SizedBox(height: 16),
              _buildField(_notes, 'Administrative Notes', Icons.note_rounded, maxLines: 3),
              
              const SizedBox(height: 48),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  backgroundColor: AppColors.primary,
                ),
                child: _saving 
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Confirm Registration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.w900, letterSpacing: 1.5),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {bool required = false, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.shadowSubtle,
        border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: required ? (v) => v!.isEmpty ? 'This field is required' : null : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/data/remote/support_service.dart';
import 'package:retail_verse_pos/features/auth/providers/auth_provider.dart';

class SupportDialog extends ConsumerStatefulWidget {
  const SupportDialog({super.key});

  @override
  ConsumerState<SupportDialog> createState() => _SupportDialogState();
}

class _SupportDialogState extends ConsumerState<SupportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = ref.read(authProvider).user ?? {};
      final supportSvc = SupportService();
      
      await supportSvc.createSupportTicket(
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
        userName: user['name']?.toString() ?? user['email']?.toString() ?? 'Retail Verse User',
        email: user['email']?.toString(),
        role: user['role']?.toString(),
        businessName: user['businessName']?.toString(),
        storeId: user['storeId']?.toString(),
      );

      if (!mounted) return;
      final router = GoRouter.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final subjectStr = _subjectController.text.trim();
      final messageStr = _messageController.text.trim();
      final userRole = user['role']?.toString();

      Navigator.pop(context);
      
      if (userRole == 'super_admin' || userRole == 'cashier') {
        // Navigate to chat screen
        router.push('/super-admin/support-chat', extra: {
          'subject': subjectStr,
          'message': messageStr,
        });
      } else {
        messenger.showSnackBar(
          const SnackBar(duration: const Duration(seconds: 2),
            content: Text('Support request submitted successfully! Our team will review it.'),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(duration: const Duration(seconds: 2),
          content: Text('Failed to create ticket: $e'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.support_agent_rounded, color: AppColors.warning, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Text('Submit Support Request', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  labelText: 'Subject',
                  hintText: 'What do you need help with?',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Please enter a subject' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Message',
                  hintText: 'Describe your issue in detail...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Please enter a message' : null,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Submit Ticket', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

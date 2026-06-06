import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:retail_verse_pos/routes/app_router.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:retail_verse_pos/data/remote/super_admin_service.dart';
import 'package:retail_verse_pos/features/auth/providers/auth_provider.dart';
import 'package:retail_verse_pos/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:retail_verse_pos/features/super_admin/presentation/screens/sa_shell.dart';

const String _privacyPolicyText = '''
Privacy Policy for Retail Verse POS

Effective Date: January 1, 2024

1. Introduction
Welcome to Retail Verse POS ("we", "our", or "us"). We are committed to protecting your personal information and your right to privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application (the "App"). By using the App, you agree to the collection and use of information in accordance with this policy.

2. Information We Collect
We may collect information about you in a variety of ways. The information we may collect via the App includes:
- Personal Data: Personally identifiable information, such as your name, shipping address, email address, and telephone number that you voluntarily give to us when you register with the App.
- Store & Inventory Data: Information related to your store, inventory, customers, and transactions entered into the Point of Sale system.
- Device Data: Information our servers automatically collect when you access the App, such as your native actions that are integral to the App, as well as device type, operating system, and device ID.

3. How We Use Your Information
Having accurate information about you permits us to provide you with a smooth, efficient, and customized experience. Specifically, we may use information collected about you via the App to:
- Create and manage your account.
- Process transactions, invoices, and send related information.
- Manage store inventory and customer databases on your behalf.
- Send you administrative information, such as updates, security alerts, and support messages.
- Improve our App's functionality and user experience.

4. Disclosure of Your Information
We do not sell, trade, or rent your personal identification information to others. We may share information we have collected about you in certain situations:
- By Law or to Protect Rights: If we believe the release of information about you is necessary to respond to legal process, to investigate or remedy potential violations of our policies, or to protect the rights, property, and safety of others.
- Third-Party Service Providers: We may share your information with third parties that perform services for us or on our behalf, such as data analysis, email delivery, hosting services, and customer service.

5. Data Security
We use administrative, technical, and physical security measures to help protect your personal information. While we have taken reasonable steps to secure the personal information you provide to us, please be aware that despite our efforts, no security measures are perfect or impenetrable, and no method of data transmission can be guaranteed against any interception or other type of misuse.

6. User Rights & Data Deletion
You have the right to request access to, correction of, or deletion of your personal data. If you wish to delete your account or any associated data, please contact our support team. We will process your request in accordance with applicable privacy laws.

7. Changes to This Privacy Policy
We may update this Privacy Policy from time to time. We will notify you of any changes by updating the "Effective Date" of this Privacy Policy. You are encouraged to periodically review this Privacy Policy to stay informed of updates.

8. Contact Us
If you have questions or comments about this Privacy Policy, please contact us at:
platform@retailverse.com
''';

const String _termsAndConditionsText = '''
Terms and Conditions for Retail Verse POS

Effective Date: January 1, 2024

1. Acceptance of Terms
By accessing or using the Retail Verse POS mobile application and platform (the "Service"), you agree to be bound by these Terms and Conditions. If you do not agree to all the terms and conditions, then you may not access the Service.

2. License to Use
We grant you a limited, non-exclusive, non-transferable, and revocable license to use our Service for your business operations, in accordance with your subscription plan. You may not copy, modify, distribute, sell, or lease any part of our Services or included software.

3. Account Responsibilities
You are responsible for safeguarding the password that you use to access the Service and for any activities or actions under your password. You agree not to disclose your password to any third party. You must notify us immediately upon becoming aware of any breach of security or unauthorized use of your account.

4. Acceptable Use
You agree not to use the Service to:
- Violate any local, state, national, or international laws.
- Process illegal or unauthorized transactions.
- Interfere with or disrupt the integrity or performance of the Service.
- Attempt to gain unauthorized access to the Service or its related systems.

5. Fees and Payment
Certain features of the Service are billed on a subscription basis. You will be billed in advance on a recurring and periodic basis depending on your subscription plan.

6. Termination
We may terminate or suspend your account and bar access to the Service immediately, without prior notice or liability, under our sole discretion, for any reason whatsoever, including a breach of these Terms.

7. Limitation of Liability
In no event shall Retail Verse, nor its directors, employees, partners, or agents, be liable for any indirect, incidental, special, consequential or punitive damages, including without limitation, loss of profits, data, use, goodwill, or other intangible losses, resulting from your access to or use of or inability to access or use the Service.

8. Changes to Terms
We reserve the right, at our sole discretion, to modify or replace these Terms at any time.

9. Contact Us
If you have any questions about these Terms, please contact us at:
platform@retailverse.com
''';

class SaSettingsScreen extends ConsumerWidget {
  const SaSettingsScreen({super.key});

  Future<void> _showBroadcastDialog(BuildContext context) async {
    final msgC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.notifications_active_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            const Text('Emergency Broadcast'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This message will be sent as a push notification to ALL active clients on the platform.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: msgC,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter your message...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.background,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Send Broadcast'),
          ),
        ],
      ),
    );

    if (ok == true && msgC.text.trim().isNotEmpty) {
      try {
        await SuperAdminService().broadcastEmergency(message: msgC.text.trim());
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Broadcast sent successfully!'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send broadcast: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out of the platform control panel?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: AppColors.error), child: const Text('Logout')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }
  }

  void _infoDialog(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(body),
              const SizedBox(height: 80),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _aboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Retail Verse Platform',
      applicationVersion: '2.4.0',
      applicationIcon: const Icon(Icons.storefront_rounded, size: 40, color: AppColors.primary),
      children: [
        const Text(
          'Professional SaaS administration center for Retail Verse POS ecosystems.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // ── PREMIUM INTEGRATED HEADER ──────────────────
          Container(
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 24, 24, 32),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: AppColors.shadowSubtle,
              border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (saScaffoldNavigationKey.currentState?.hasDrawer ?? false)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: IconButton(
                          onPressed: () => saScaffoldNavigationKey.currentState?.openDrawer(),
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.cardBorder.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.more_vert_rounded, color: AppColors.textPrimary, size: 20),
                          ),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: ResponsiveMenuButton(isSuperAdmin: true, color: AppColors.textPrimary),
                      ),
                    Expanded(
                      child: Text('Platform Settings', style: AppTypography.headlineSmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.settings_suggest_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Global Administration Center',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
              children: [
                _buildProfileCard(),
                const SizedBox(height: 32),
                _buildSectionTitle('Platform Redirection', Icons.navigation_rounded),
                _buildSettingsCard([
                  _SettingsTile(
                    icon: Icons.person_rounded,
                    title: 'Account & Profile',
                    subtitle: 'Manage your enterprise credentials',
                    onTap: () => context.push('/account'),
                  ),
                  _SettingsTile(
                    icon: Icons.tune_rounded,
                    title: 'System Preferences',
                    subtitle: 'Internal API & Theme overrides',
                    onTap: () => context.push('/super-admin/system-preferences'),
                  ),
                ]),
                const SizedBox(height: 40),
                _buildSectionTitle('Advanced Operations', Icons.bolt_rounded),
                _buildSettingsCard([
                  _SettingsTile(
                    icon: Icons.notifications_active_rounded,
                    title: 'Emergency Broadcast',
                    subtitle: 'Push notifications to all clients',
                    onTap: () => _showBroadcastDialog(context),
                  ),
                  _SettingsTile(
                    icon: Icons.security_rounded,
                    title: 'System Health Audit',
                    subtitle: 'Infrastructure & security logs',
                    onTap: () => context.push('/super-admin/logs'),
                  ),
                  _SettingsTile(
                    icon: Icons.build_circle_rounded,
                    title: 'Repair Database Indexes',
                    subtitle: 'Fix duplicate client ID collisions',
                    onTap: () async {
                      try {
                        final msg = await SuperAdminService().fixBusinessesData();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg), backgroundColor: AppColors.success),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString().contains('SocketException') || e.toString().contains('Failed host lookup') ? 'You are offline. Please check your internet connection.' : 'Error: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
                  ),
                ]),
                const SizedBox(height: 40),
                _buildSectionTitle('Help & Support', Icons.help_outline_rounded),
                _buildSettingsCard([
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy and Policies',
                    subtitle: 'Platform data handling',
                    onTap: () => _infoDialog(context, 'Privacy and Policies', _privacyPolicyText),
                  ),
                  _SettingsTile(
                    icon: Icons.gavel_rounded,
                    title: 'Terms and Conditions',
                    subtitle: 'SaaS usage agreement',
                    onTap: () => _infoDialog(context, 'Terms and Conditions', _termsAndConditionsText),
                  ),
                  _SettingsTile(
                    icon: Icons.support_agent_rounded,
                    title: 'Customer Support',
                    subtitle: 'Direct line to developers',
                    onTap: () => context.push('/super-admin/support'),
                  ),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About',
                    subtitle: 'Platform version & info',
                    onTap: () => _aboutDialog(context),
                  ),
                ]),
                const SizedBox(height: 48),
                _buildLogoutButton(context, ref),
                const SizedBox(height: 40),
                _buildPlatformMeta(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary,
            child: Text('SA', style: AppTypography.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Super Admin', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900)),
                Text('platform@retailverse.com', style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('VERIFIED', style: TextStyle(color: AppColors.success, fontSize: 8, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Text(title, style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w900, color: AppColors.textSecondary, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildPlatformMeta() {
    return Column(
      children: [
        Text('Retail Verse POS Platform', style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Version 2.4.0 • Production Build', style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary.withOpacity(0.5), fontSize: 9)),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return _Bounceable(
      onTap: () => _confirmLogout(context, ref),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
            const SizedBox(width: 12),
            const Text('Log Out From Super Admin', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  const _SettingsTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return _Bounceable(
      onTap: enabled ? onTap : () {},
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: (enabled ? AppColors.primary : Colors.grey).withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: enabled ? AppColors.primary : Colors.grey, size: 22),
        ),
        title: Text(title, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800, color: enabled ? AppColors.textPrimary : Colors.grey)),
        subtitle: Text(subtitle, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
      ),
    );
  }
}

class _Bounceable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Bounceable({required this.child, required this.onTap});

  @override
  State<_Bounceable> createState() => _BounceableState();
}

class _BounceableState extends State<_Bounceable> with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: widget.child,
      ),
    );
  }
}

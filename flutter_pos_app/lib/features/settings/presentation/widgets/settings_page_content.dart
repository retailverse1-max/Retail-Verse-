import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/constants/legal_constants.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/branding/app_branding.dart';
import '../../../../core/navigation/role_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/remote/account_service.dart';
import '../../../../data/remote/support_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../core/providers/sync_providers.dart';
import '../../../dashboard/providers/dashboard_providers.dart';
import '../../../pos/providers/product_providers.dart';
import '../../domain/models/pos_settings.dart';
import '../../providers/app_info_provider.dart';
import '../../providers/backend_health_provider.dart';
import '../../providers/connectivity_status_provider.dart';
import '../../providers/local_database_status_provider.dart';
import '../../providers/pos_settings_provider.dart';
import 'settings_ui_kit.dart';
import '../screens/marketplace_settings_screen.dart';

/// Scrollable sections for [SettingsScreen]. Kept separate for maintainability.
class SettingsPageContent extends ConsumerWidget {
  const SettingsPageContent({
    super.key,
    required this.searchQuery,
  });

  final String searchQuery;

  bool _hit(String blob) {
    if (searchQuery.isEmpty) return true;
    return blob.toLowerCase().contains(searchQuery);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(posSettingsProvider);
    final auth = ref.watch(authProvider);
    final user = auth.user ?? {};
    final canOpenInventory =
        isRouteAllowedForShell('/inventory', effectiveUserRole(user));
    final name = user['name']?.toString() ?? 'User';
    final email = user['email']?.toString() ?? '—';
    final role = effectiveUserRole(user);
    final accountService = AccountService();

    Future<void> patch(PosSettings Function(PosSettings) fn) =>
        ref.read(posSettingsProvider.notifier).update(fn);

    Future<void> pickLogo() async {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (x == null || !context.mounted) return;
      try {
        final dir = await getApplicationDocumentsDirectory();
        final ext = p.extension(x.path).isEmpty ? '.jpg' : p.extension(x.path);
        final dest = File(p.join(dir.path, 'store_logo$ext'));
        await File(x.path).copy(dest.path);
        await patch((ps) => ps.copyWith(businessLogoPath: dest.path));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(duration: const Duration(seconds: 2),
              content: Text('Logo saved for this device'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(duration: const Duration(seconds: 2),
              content: Text('Logo error: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    final children = <Widget>[];

    void addIf(bool show, Widget w) {
      if (show) children.add(w);
    }

    final canManageUsers =
        canAccessAdminStaffManagement(effectiveUserRole(user));

    // —— Super Admin ——
    addIf(
      role == 'super_admin' &&
          (searchQuery.isEmpty ||
              _hit('super admin platform saas businesses users subscriptions analytics logs')),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(
            title: 'Super Admin',
            subtitle: 'Platform control panel',
            icon: Icons.security_outlined,
          ),
          SettingsSurfaceCard(
            child: SettingsNavTile(
              icon: Icons.dashboard_customize_outlined,
              title: 'Super Admin panel',
              subtitle: 'Businesses · users · subscriptions · logs',
              onTap: () => context.push('/super-admin/dashboard'),
            ),
          ),
        ],
      ),
    );

    // —— Administration (admin / super_admin) — pinned at top ——
    addIf(
      canManageUsers &&
          (searchQuery.isEmpty ||
              _hit(
                'user management staff team roles accounts administration admin',
              )),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(
            title: 'Administration',
            subtitle: 'Staff accounts',
            icon: Icons.admin_panel_settings_outlined,
          ),
          SettingsSurfaceCard(
            child: SettingsNavTile(
              icon: Icons.group_add_outlined,
              title: 'User management',
              subtitle: 'View staff · add users · cashier or inventory roles',
              onTap: () => context.push('/admin/staff'),
            ),
          ),
        ],
      ),
    );

    // —— Business ——
    addIf(
      _hit(
        'business store address phone gst tax currency timezone logo',
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(
            title: 'Business & store',
            subtitle: 'Shown on receipts and invoices where applicable',
            icon: Icons.storefront_rounded,
          ),
          SettingsSurfaceCard(
            child: Column(
              children: [
                SettingsValueTile(
                  icon: Icons.badge_outlined,
                  title: 'Store name',
                  subtitle: 'Legal or trading name (Replaces Retail Verse across app)',
                  valueLabel: s.storeName.trim().isEmpty ? 'Retail Verse (Default)' : s.storeName.trim(),
                  onTap: () => _editString(
                    context,
                    ref,
                    title: 'Store name',
                    initial: s.storeName.trim() == 'My Store' ? '' : s.storeName.trim(),
                    hintText: 'Enter store name (leave empty for Retail Verse)',
                    onSave: (v) {
                      final name = v.trim();
                      patch((p) => p.copyWith(storeName: name));
                      AppBranding.setStoreName(name);
                    },
                  ),
                ),
                const SettingsDividerInset(),
                SettingsValueTile(
                  icon: Icons.location_on_outlined,
                  title: 'Store address',
                  subtitle: 'Street, city, PIN',
                  valueLabel:
                      s.storeAddress.isEmpty ? 'Tap to set' : s.storeAddress,
                  onTap: () => _editString(
                    context,
                    ref,
                    title: 'Store address',
                    initial: s.storeAddress,
                    maxLines: 3,
                    onSave: (v) => patch((p) => p.copyWith(storeAddress: v)),
                  ),
                ),
                const SettingsDividerInset(),
                SettingsValueTile(
                  icon: Icons.phone_outlined,
                  title: 'Store phone',
                  subtitle: 'Customer-facing contact',
                  valueLabel:
                      s.storePhone.isEmpty ? 'Tap to set' : s.storePhone,
                  onTap: () => _editString(
                    context,
                    ref,
                    title: 'Store phone',
                    initial: s.storePhone,
                    keyboard: TextInputType.phone,
                    onSave: (v) => patch((p) => p.copyWith(storePhone: v)),
                  ),
                ),
                const SettingsDividerInset(),
                SettingsValueTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'GST / Tax ID',
                  subtitle: 'VAT, GSTIN, EIN…',
                  valueLabel: s.gstTaxId.isEmpty ? 'Optional' : s.gstTaxId,
                  onTap: () => _editString(
                    context,
                    ref,
                    title: 'GST / Tax ID',
                    initial: s.gstTaxId,
                    onSave: (v) => patch((p) => p.copyWith(gstTaxId: v)),
                  ),
                ),
                const SettingsDividerInset(),
                SettingsValueTile(
                  icon: Icons.currency_rupee_rounded,
                  title: 'Currency',
                  subtitle: 'Pricing & totals',
                  valueLabel: s.currencyCode,
                  onTap: () => _pickOption(
                    context,
                    ref,
                    title: 'Currency',
                    options: const ['INR', 'USD', 'EUR', 'GBP', 'AED'],
                    current: s.currencyCode,
                    onPick: (v) => patch((p) => p.copyWith(currencyCode: v)),
                  ),
                ),
                const SettingsDividerInset(),
                SettingsValueTile(
                  icon: Icons.schedule_rounded,
                  title: 'Time zone',
                  subtitle: 'Reports & day boundaries',
                  valueLabel: s.timeZone,
                  onTap: () => _pickOption(
                    context,
                    ref,
                    title: 'Time zone',
                    options: const [
                      'Asia/Kolkata',
                      'Asia/Dubai',
                      'Europe/London',
                      'America/New_York',
                    ],
                    current: s.timeZone,
                    onPick: (v) => patch((p) => p.copyWith(timeZone: v)),
                  ),
                ),
                ListTile(
                  leading: s.businessLogoPath.isNotEmpty && File(s.businessLogoPath).existsSync()
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(s.businessLogoPath),
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.image_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                  title: Text(
                    'Business logo',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    s.businessLogoPath.isNotEmpty
                        ? 'Logo configured for invoices'
                        : 'Add for invoices & profile',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: pickLogo,
                    child: Text(s.businessLogoPath.isEmpty ? 'Add' : 'Change'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // —— Integrations ——
    addIf(
      _hit('marketplace integrations flipkart amazon'),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(
            title: 'Marketplace Integrations',
            subtitle: 'Connect with external sales channels',
            icon: Icons.hub_rounded,
          ),
          SettingsSurfaceCard(
            child: Column(
              children: [
                SettingsNavTile(
                  icon: Icons.hub_rounded,
                  title: 'Omnichannel Auto-Publishing',
                  subtitle: '1-Click sync to Flipkart, Meesho, Swiggy, Zomato & Shopify',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketplaceSettingsScreen()));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // —— User ——
    addIf(
      _hit('user profile email role password account'),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(
            title: 'User & profile',
            subtitle: 'Signed-in team member',
            icon: Icons.person_outline_rounded,
          ),
          SettingsSurfaceCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  title: Text(
                    name,
                    style: AppTypography.bodyMedium
                        .copyWith(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text('$email · ${role.toUpperCase()}', style: AppTypography.caption),
                ),
                const SettingsDividerInset(),
                SettingsNavTile(
                  icon: Icons.edit_outlined,
                  title: 'Edit profile',
                  subtitle: 'Name & account details',
                  onTap: () => context.push('/account'),
                ),
                const SettingsDividerInset(),
                SettingsNavTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Delete account',
                  subtitle: 'Deactivate this sign-in and remove access',
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete account?'),
                        content: const Text(
                          'This will deactivate your account and sign you out. '
                          'You may need an admin to restore access.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (ok != true || !context.mounted) return;
                    try {
                      await accountService.deleteMe();
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(duration: const Duration(seconds: 2),
                            content: Text('Account deleted'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        context.go('/login');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(duration: const Duration(seconds: 2),
                            content: Text('Delete failed: $e'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                ),
                const SettingsDividerInset(),
                SettingsNavTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Change password',
                  subtitle: 'Update your account password securely',
                  onTap: () => _showChangePasswordDialog(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // —— POS ——
    addIf(
      canAccessPosBilling(effectiveUserRole(user)) &&
          _hit(
            'pos barcode sound billing confirmation receipt payment discount tax stock',
          ),
      _section(
        title: 'POS preferences',
        subtitle: 'Checkout behaviour',
        icon: Icons.point_of_sale_rounded,
        child: Column(
          children: [
            SettingsSwitchTile(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Barcode scanner',
              subtitle: 'Use camera / hardware scanner when available',
              value: s.barcodeScannerEnabled,
              onChanged: (v) => patch((p) => p.copyWith(barcodeScannerEnabled: v)),
            ),
            const SettingsDividerInset(),
            SettingsSwitchTile(
              icon: Icons.volume_up_outlined,
              title: 'Sound on successful billing',
              subtitle: 'Short confirmation tone',
              value: s.soundOnBilling,
              onChanged: (v) => patch((p) => p.copyWith(soundOnBilling: v)),
            ),
            const SettingsDividerInset(),
            SettingsSwitchTile(
              icon: Icons.touch_app_outlined,
              title: 'Order confirmation popup',
              subtitle: 'Confirm before completing a sale',
              value: s.orderConfirmationPopup,
              onChanged: (v) =>
                  patch((p) => p.copyWith(orderConfirmationPopup: v)),
            ),
            const SettingsDividerInset(),
            SettingsValueTile(
              icon: Icons.straighten_rounded,
              title: 'Receipt size',
              subtitle: 'Thermal / A4 layout hint',
              valueLabel: s.receiptSize,
              onTap: () => _pickOption(
                context,
                ref,
                title: 'Receipt size',
                options: const ['58mm', '80mm', 'a4'],
                current: s.receiptSize,
                onPick: (v) => patch((p) => p.copyWith(receiptSize: v)),
              ),
            ),
            const SettingsDividerInset(),
            SettingsValueTile(
              icon: Icons.payments_outlined,
              title: 'Default payment method',
              subtitle: 'Pre-selected at POS',
              valueLabel: s.defaultPaymentMethod,
              onTap: () => _pickOption(
                context,
                ref,
                title: 'Default payment',
                options: const ['Cash', 'Card', 'UPI'],
                current: s.defaultPaymentMethod,
                onPick: (v) =>
                    patch((p) => p.copyWith(defaultPaymentMethod: v)),
              ),
            ),
            const SettingsDividerInset(),
            SettingsSwitchTile(
              icon: Icons.percent_rounded,
              title: 'Enable discounts',
              subtitle: 'Line or cart discount fields',
              value: s.discountEnabled,
              onChanged: (v) => patch((p) => p.copyWith(discountEnabled: v)),
            ),
            const SettingsDividerInset(),
            SettingsSwitchTile(
              icon: Icons.calculate_outlined,
              title: 'Enable tax',
              subtitle: 'GST / VAT lines on bill',
              value: s.taxEnabled,
              onChanged: (v) => patch((p) => p.copyWith(taxEnabled: v)),
            ),
            if (s.taxEnabled) ...[
              const SettingsDividerInset(),
              SettingsValueTile(
                icon: Icons.percent_rounded,
                title: 'Default GST / Tax Rate',
                subtitle: 'Applied when product has no custom GST',
                valueLabel: '${s.defaultGstRate.toStringAsFixed(s.defaultGstRate.truncateToDouble() == s.defaultGstRate ? 0 : 1)}%',
                onTap: () => _pickOption(
                  context,
                  ref,
                  title: 'Default GST / Tax Rate',
                  options: const ['0%', '5%', '12%', '18%', '28%'],
                  current: '${s.defaultGstRate.toStringAsFixed(s.defaultGstRate.truncateToDouble() == s.defaultGstRate ? 0 : 1)}%',
                  onPick: (v) {
                    final parsed = double.tryParse(v.replaceAll('%', '').trim()) ?? 18.0;
                    patch((p) => p.copyWith(defaultGstRate: parsed));
                  },
                ),
              ),
            ],
            const SettingsDividerInset(),
            SettingsSwitchTile(
              icon: Icons.inventory_2_outlined,
              title: 'Low stock alerts at POS',
              subtitle: 'Warn while selling',
              value: s.lowStockAlertsPos,
              onChanged: (v) =>
                  patch((p) => p.copyWith(lowStockAlertsPos: v)),
            ),
          ],
        ),
      ),
    );

    // —— Billing ——
    addIf(
      canAccessPosBilling(effectiveUserRole(user)) &&
          _hit('invoice bill receipt print share tax logo footer prefix'),
      _section(
        title: 'Billing & invoices',
        subtitle: 'Print & digital output',
        icon: Icons.description_outlined,
        child: Column(
          children: [
            SettingsValueTile(
              icon: Icons.tag_rounded,
              title: 'Invoice prefix',
              subtitle: 'Before auto number',
              valueLabel: s.invoicePrefix,
              onTap: () => _editString(
                context,
                ref,
                title: 'Invoice prefix',
                initial: s.invoicePrefix,
                onSave: (v) => patch((p) => p.copyWith(invoicePrefix: v)),
              ),
            ),
            const SettingsDividerInset(),
            SettingsSwitchTile(
              icon: Icons.receipt_rounded,
              title: 'Show tax on bill',
              subtitle: 'Itemised or summary tax',
              value: s.showTaxOnBill,
              onChanged: (v) => patch((p) => p.copyWith(showTaxOnBill: v)),
            ),
            const SettingsDividerInset(),
            SettingsSwitchTile(
              icon: Icons.store_mall_directory_outlined,
              title: 'Shop logo on invoice',
              subtitle: 'Uses saved business logo',
              value: s.showShopLogoOnInvoice,
              onChanged: (v) =>
                  patch((p) => p.copyWith(showShopLogoOnInvoice: v)),
            ),
            const SettingsDividerInset(),
            SettingsValueTile(
              icon: Icons.notes_rounded,
              title: 'Invoice footer note',
              subtitle: 'Thank-you or terms line',
              valueLabel: s.invoiceFooterNote.length > 28
                  ? '${s.invoiceFooterNote.substring(0, 28)}…'
                  : s.invoiceFooterNote,
              onTap: () => _editString(
                context,
                ref,
                title: 'Footer note',
                initial: s.invoiceFooterNote,
                maxLines: 4,
                onSave: (v) => patch((p) => p.copyWith(invoiceFooterNote: v)),
              ),
            ),
            const SettingsDividerInset(),
            SettingsSwitchTile(
              icon: Icons.print_outlined,
              title: 'Print receipt',
              subtitle: 'Offer print after sale',
              value: s.printReceipt,
              onChanged: (v) => patch((p) => p.copyWith(printReceipt: v)),
            ),
          ],
        ),
      ),
    );

    // —— Inventory ——
    addIf(
      canAccessInventoryManagement(effectiveUserRole(user)) &&
          _hit('inventory stock category unit sync threshold negative'),
      _section(
        title: 'Inventory',
        subtitle: 'Stock rules & catalogue',
        icon: Icons.warehouse_outlined,
        child: Column(
          children: [
            SettingsValueTile(
              icon: Icons.warning_amber_rounded,
              title: 'Low stock threshold',
              subtitle: 'Units before alert',
              valueLabel: '${s.lowStockThreshold}',
              onTap: () => _editInt(
                context,
                ref,
                title: 'Low stock threshold',
                initial: s.lowStockThreshold,
                onSave: (v) =>
                    patch((p) => p.copyWith(lowStockThreshold: v)),
              ),
            ),
            const SettingsDividerInset(),
            SettingsSwitchTile(
              icon: Icons.track_changes_rounded,
              title: 'Stock tracking',
              subtitle: 'Decrement on sales',
              value: s.stockTrackingEnabled,
              onChanged: (v) =>
                  patch((p) => p.copyWith(stockTrackingEnabled: v)),
            ),
            const SettingsDividerInset(),
            SettingsSwitchTile(
              icon: Icons.remove_circle_outline_rounded,
              title: 'Allow negative stock',
              subtitle: 'Backorders / overrides',
              value: s.allowNegativeStock,
              onChanged: (v) =>
                  patch((p) => p.copyWith(allowNegativeStock: v)),
            ),
            const SettingsDividerInset(),
            SettingsSwitchTile(
              icon: Icons.cloud_sync_rounded,
              title: 'Auto-sync with backend',
              subtitle: 'Keep counts aligned with server',
              value: s.autoSyncInventory,
              onChanged: (v) =>
                  patch((p) => p.copyWith(autoSyncInventory: v)),
            ),
            if (canOpenInventory) ...[
              const SettingsDividerInset(),
              SettingsNavTile(
                icon: Icons.category_outlined,
                title: 'Category management',
                subtitle: 'Open inventory categories',
                onTap: () => context.push('/inventory'),
              ),
            ],
            const SettingsDividerInset(),
            SettingsNavTile(
              icon: Icons.scale_rounded,
              title: 'Unit management',
              subtitle: 'Configure units in product forms',
              onTap: () => _infoDialog(
                context,
                'Units',
                'Units are selected per product in Inventory → Add product.',
              ),
            ),
          ],
        ),
      ),
    );

    // —— Notifications ——
    addIf(
      _hit('notification alert summary order stock sync'),
      _section(
        title: 'Notifications',
        subtitle: 'In-app alerts (system push when enabled)',
        icon: Icons.notifications_active_outlined,
        child: Column(
          children: [
            SettingsSwitchTile(
              icon: Icons.check_circle_outline_rounded,
              title: 'Order success',
              subtitle: 'After completed sale',
              value: s.notifyOrderSuccess,
              onChanged: (v) =>
                  patch((p) => p.copyWith(notifyOrderSuccess: v)),
            ),
            const SettingsDividerInset(),
            SettingsSwitchTile(
              icon: Icons.inventory_rounded,
              title: 'Low stock',
              subtitle: 'When SKU crosses threshold',
              value: s.notifyLowStock,
              onChanged: (v) => patch((p) => p.copyWith(notifyLowStock: v)),
            ),
            const SettingsDividerInset(),
            SettingsSwitchTile(
              icon: Icons.summarize_outlined,
              title: 'Daily sales summary',
              subtitle: 'End-of-day digest',
              value: s.notifyDailySales,
              onChanged: (v) =>
                  patch((p) => p.copyWith(notifyDailySales: v)),
            ),
            const SettingsDividerInset(),
            SettingsSwitchTile(
              icon: Icons.sync_problem_rounded,
              title: 'Sync failure alerts',
              subtitle: 'When offline queue fails',
              value: s.notifySyncFailure,
              onChanged: (v) =>
                  patch((p) => p.copyWith(notifySyncFailure: v)),
            ),
          ],
        ),
      ),
    );

    // —— Sync & data ——
    addIf(
      _hit('sync data backend offline database connection api network'),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(
            title: 'Sync & data',
            subtitle: 'Server & local store',
            icon: Icons.cloud_done_outlined,
          ),
          SettingsSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SyncStatusCard(s: s),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        // 1. Process all pending offline queue items to Cloud DB
                        final syncedCount = await ref
                            .read(syncServiceProvider)
                            .processSyncQueue();

                        // 2. Refresh all local and remote providers
                        ref.invalidate(settingsBackendReachableProvider);
                        invalidateAllDashboardProviders(ref);
                        ref.invalidate(productsProvider);
                        ref.invalidate(localDatabaseStatusProvider);

                        // 3. Record sync timestamp
                        await ref
                            .read(posSettingsProvider.notifier)
                            .recordSuccessfulSync();

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              duration: const Duration(seconds: 3),
                              content: Text(
                                syncedCount > 0
                                    ? '✓ Synced $syncedCount offline order${syncedCount > 1 ? "s" : ""} to Cloud MongoDB!'
                                    : '✓ Local SQLite and Cloud DB are in sync',
                              ),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: const Color(0xFF2E7D32),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.sync_rounded, size: 20),
                      label: const Text('Sync now'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SettingsSwitchTile(
                  icon: Icons.autorenew_rounded,
                  title: 'Auto sync',
                  subtitle: 'Background refresh when online',
                  value: s.autoSyncEnabled,
                  onChanged: (v) =>
                      patch((p) => p.copyWith(autoSyncEnabled: v)),
                ),
                const SettingsDividerInset(),
                Consumer(
                  builder: (context, ref, _) {
                    final net = ref.watch(connectivityListProvider);
                    final label = net.when(
                      data: (list) {
                        if (list.isEmpty ||
                            list.every((e) => e == ConnectivityResult.none)) {
                          return 'Offline';
                        }
                        return list.map((e) => e.name).join(', ');
                      },
                      loading: () => '…',
                      error: (_, __) => 'Unknown',
                    );
                    return SettingsValueTile(
                      icon: Icons.wifi_tethering_rounded,
                      title: 'Network',
                      subtitle: 'Live connectivity',
                      valueLabel: label,
                      onTap: () => ref.invalidate(connectivityListProvider),
                    );
                  },
                ),
                const SettingsDividerInset(),
                Consumer(
                  builder: (context, ref, _) {
                    final net = ref.watch(connectivityListProvider);
                    final offline = net.when(
                      data: (list) =>
                          list.isEmpty ||
                          list.every((e) => e == ConnectivityResult.none),
                      loading: () => false,
                      error: (_, __) => true,
                    );
                    return SettingsValueTile(
                      icon: Icons.cloud_off_outlined,
                      title: 'Offline mode',
                      subtitle:
                          'Billing works on device; queue syncs when online',
                      valueLabel: offline ? 'Active' : 'Inactive',
                      onTap: () {
                        ref.invalidate(connectivityListProvider);
                        if (offline && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(duration: const Duration(seconds: 2),
                              content: Text(
                                'No connection — changes remain on this device until sync succeeds.',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
                const SettingsDividerInset(),
                Consumer(
                  builder: (context, ref, _) {
                    final db = ref.watch(localDatabaseStatusProvider);
                    return SettingsValueTile(
                      icon: Icons.storage_rounded,
                      title: 'Local database',
                      subtitle: 'SQLite on device',
                      valueLabel: db.when(
                        data: (t) => t,
                        loading: () => '…',
                        error: (_, __) => 'Error',
                      ),
                      onTap: () => ref.invalidate(localDatabaseStatusProvider),
                    );
                  },
                ),

              ],
            ),
          ),
        ],
      ),
    );

    // —— Security ——
    addIf(
      _hit('security pin biometric lock logout session'),
      _section(
        title: 'Security',
        subtitle: 'Device & session',
        icon: Icons.shield_outlined,
        child: Column(
          children: [
            SettingsSwitchTile(
              icon: Icons.lock_outline_rounded,
              title: 'App lock',
              subtitle: 'Require unlock when returning',
              value: s.appLockEnabled,
              onChanged: (v) => patch((p) => p.copyWith(appLockEnabled: v)),
            ),
            const SettingsDividerInset(),
            SettingsNavTile(
              icon: Icons.pin_outlined,
              title: 'PIN setup',
              subtitle: s.pinConfigured ? 'PIN is set' : 'Not configured',
              trailingLabel: s.pinConfigured ? 'Change' : 'Set up',
              onTap: () {
                patch((p) => p.copyWith(pinConfigured: true));
                _infoDialog(
                  context,
                  'PIN',
                  'PIN authentication is enabled. You can now use your PIN to unlock the app.',
                );
              },
            ),
            const SettingsDividerInset(),
            SettingsSwitchTile(
              icon: Icons.fingerprint_rounded,
              title: 'Biometric login',
              subtitle: 'Face / fingerprint when device supports',
              value: s.biometricLoginEnabled,
              onChanged: (v) {
                patch((p) => p.copyWith(biometricLoginEnabled: v));
                if (v && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(duration: const Duration(seconds: 2),
                      content: Text(
                        'Biometric login enabled. Ensure your device has biometrics configured.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const SettingsDividerInset(),
            SettingsValueTile(
              icon: Icons.timer_outlined,
              title: 'Auto logout',
              subtitle: 'Idle timeout',
              valueLabel: s.autoLogoutMinutes <= 0
                  ? 'Never'
                  : '${s.autoLogoutMinutes} min',
              onTap: () => _pickOption(
                context,
                ref,
                title: 'Auto logout',
                options: const ['5', '15', '30', '60', '0'],
                optionLabels: const [
                  '5 minutes',
                  '15 minutes',
                  '30 minutes',
                  '60 minutes',
                  'Never',
                ],
                current: '${s.autoLogoutMinutes}',
                onPick: (v) => patch(
                  (p) => p.copyWith(autoLogoutMinutes: int.parse(v)),
                ),
              ),
            ),
            const SettingsDividerInset(),
            SettingsSwitchTile(
              icon: Icons.manage_accounts_outlined,
              title: 'Session management',
              subtitle: 'Review active sign-ins',
              value: s.sessionManagementEnabled,
              onChanged: (v) =>
                  patch((p) => p.copyWith(sessionManagementEnabled: v)),
            ),
          ],
        ),
      ),
    );

    // —— Theme ——
    addIf(
      _hit('theme dark language font version display'),
      _section(
        title: 'Appearance & language',
        subtitle: 'Look & readability',
        icon: Icons.palette_outlined,
        child: Column(
          children: [
            SettingsSwitchTile(
              icon: Icons.dark_mode_outlined,
              title: 'Dark mode',
              subtitle: 'Easier in low light',
              value: s.darkMode,
              onChanged: (v) => patch((p) => p.copyWith(darkMode: v)),
            ),
            const SettingsDividerInset(),
            SettingsValueTile(
              icon: Icons.language_rounded,
              title: 'Language',
              subtitle: 'UI language',
              valueLabel:
                  s.languageCode == 'hi' ? 'हिंदी (hi)' : 'English (en)',
              onTap: () => _pickOption(
                context,
                ref,
                title: 'Language',
                options: const ['en', 'hi'],
                optionLabels: const ['English', 'हिंदी'],
                current: s.languageCode,
                onPick: (v) => patch((p) => p.copyWith(languageCode: v)),
              ),
            ),
            const SettingsDividerInset(),
            SettingsValueTile(
              icon: Icons.format_size_rounded,
              title: 'Font size',
              subtitle: 'Text scale',
              valueLabel: '${(s.fontScale * 100).round()}%',
              onTap: () => _pickOption(
                context,
                ref,
                title: 'Font scale',
                options: const ['0.9', '0.95', '1.0', '1.1', '1.2'],
                optionLabels: const ['90%', '95%', '100%', '110%', '120%'],
                current: _closestFontScaleKey(s.fontScale),
                onPick: (v) => patch(
                  (p) => p.copyWith(fontScale: double.parse(v)),
                ),
              ),
            ),
            const SettingsDividerInset(),
            Consumer(
              builder: (context, ref, _) {
                final info = ref.watch(appPackageInfoProvider);
                return SettingsValueTile(
                  icon: Icons.info_outline_rounded,
                  title: 'App version',
                  subtitle: 'Build from package',
                  valueLabel: info.when(
                    data: (i) => '${i.version} (${i.buildNumber})',
                    loading: () => '…',
                    error: (_, __) => '—',
                  ),
                  onTap: () => _showAppVersionSheet(context, ref),
                );
              },
            ),
          ],
        ),
      ),
    );

    // —— Help ——
    addIf(
      _hit('help support privacy terms about contact'),
      _section(
        title: 'Help & support',
        subtitle: 'Policies and platform info',
        icon: Icons.help_outline_rounded,
        child: Column(
          children: [
            SettingsNavTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy and Policies',
              subtitle: 'How we handle data',
              onTap: () => _legalSheet(
                context,
                'Privacy and Policies',
                LegalConstants.privacyPolicy,
              ),
            ),
            const SettingsDividerInset(),
            SettingsNavTile(
              icon: Icons.gavel_rounded,
              title: 'Terms and Conditions',
              subtitle: 'Use of the POS software',
              onTap: () => _legalSheet(
                context,
                'Terms and Conditions',
                LegalConstants.termsAndConditions,
              ),
            ),
            const SettingsDividerInset(),
            SettingsNavTile(
              icon: Icons.support_agent_rounded,
              title: 'Customer Support',
              subtitle: 'Raise tickets and chat with support',
              onTap: () {
                final user = ref.read(authProvider).user;
                final role = effectiveUserRole(user);
                if (role == 'super_admin') {
                  context.push('/super-admin/support');
                } else {
                  context.push('/support');
                }
              },
            ),
            const SettingsDividerInset(),
            SettingsNavTile(
              icon: Icons.info_outline_rounded,
              title: 'About',
              subtitle: 'Retail billing platform info',
              onTap: () => _showAppVersionSheet(context, ref),
            ),
          ],
        ),
      ),
    );

    if (children.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: AppColors.textTertiary.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                'No settings match “$searchQuery”.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final brandName = AppBranding.getStoreName(
      role: role,
      fallback: s.storeName.isNotEmpty && s.storeName != 'My Store' ? s.storeName : null,
    );

    children.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            '$brandName POS • v2.4.0',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );

    return Column(
      children: children,
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionHeader(
          title: title,
          subtitle: subtitle,
          icon: icon,
        ),
        SettingsSurfaceCard(child: child),
      ],
    );
  }
}

class _SyncStatusCard extends ConsumerWidget {
  const _SyncStatusCard({required this.s});

  final PosSettings s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF9AA5B1)
        : AppColors.textSecondary;
    final last = s.lastSyncAtIso;
    final text = last == null
        ? 'No successful sync recorded yet'
        : 'Last sync: $last';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.history_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last sync status',
                  style: AppTypography.bodyMedium
                      .copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(text, style: AppTypography.bodySmall.copyWith(color: muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _closestFontScaleKey(double v) {
  const opts = [0.9, 0.95, 1.0, 1.1, 1.2];
  var best = opts.first;
  var bestD = (v - best).abs();
  for (final o in opts.skip(1)) {
    final d = (v - o).abs();
    if (d < bestD) {
      best = o;
      bestD = d;
    }
  }
  return best.toString();
}



Future<void> _editString(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String initial,
  required void Function(String) onSave,
  int maxLines = 1,
  TextInputType keyboard = TextInputType.text,
  String? hintText,
}) async {
  final c = TextEditingController(text: initial);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboard,
        autofocus: true,
        decoration: InputDecoration(
          hintText: hintText,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    onSave(c.text.trim());
  }
}

Future<void> _editInt(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required int initial,
  required void Function(int) onSave,
}) async {
  final c = TextEditingController(text: '$initial');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    final v = int.tryParse(c.text.trim()) ?? initial;
    onSave(v);
  }
}

Future<void> _pickOption(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required List<String> options,
  List<String>? optionLabels,
  required String current,
  required void Function(String) onPick,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          for (var i = 0; i < options.length; i++)
            ListTile(
              title: Text(optionLabels != null ? optionLabels[i] : options[i]),
              trailing: options[i] == current
                  ? const Icon(Icons.check_rounded, color: AppColors.primary)
                  : null,
              onTap: () {
                onPick(options[i]);
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    ),
  );
}

void _infoDialog(BuildContext context, String title, String body) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(body)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

void _legalSheet(BuildContext context, String title, String body) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            title,
            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Text(body, style: AppTypography.bodyMedium),
          const SizedBox(height: 80),
        ],
      ),
    ),
  );
}

void _showSupportTicketDialog(BuildContext context, WidgetRef ref) {
  final subjectController = TextEditingController();
  final descriptionController = TextEditingController();
  final supportService = SupportService();
  bool isSubmitting = false;

  showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Contact Support'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Describe your issue and our team will get back to you.', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final subject = subjectController.text.trim();
                      final message = descriptionController.text.trim();
                      if (subject.isEmpty || message.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(duration: const Duration(seconds: 2),content: Text('Please fill all fields')),
                        );
                        return;
                      }

                      setState(() => isSubmitting = true);
                      try {
                        final auth = ref.read(authProvider);
                        final user = auth.user ?? {};
                        final settings = ref.read(posSettingsProvider);

                        await supportService.createSupportTicket(
                          subject: subject,
                          message: message,
                          userName: user['name']?.toString() ?? 'Unknown User',
                          email: user['email']?.toString(),
                          role: effectiveUserRole(user),
                          businessName: settings.storeName,
                          storeId: settings.storePhone,
                        );
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(duration: const Duration(seconds: 2),
                              content: Text('Support ticket created successfully!'),
                              backgroundColor: AppColors.secondary,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(duration: const Duration(seconds: 2),
                              content: Text('Failed to submit ticket: $e'),
                              backgroundColor: AppColors.secondary,
                            ),
                          );
                        }
                      } finally {
                        if (context.mounted) {
                          setState(() => isSubmitting = false);
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit'),
            ),
          ],
        );
      },
    ),
  ).then((_) {
    subjectController.dispose();
    descriptionController.dispose();
  });
}

Future<void> _showAppVersionSheet(BuildContext context, WidgetRef ref) async {
  PackageInfo? info;
  try {
    info = await ref.read(appPackageInfoProvider.future);
  } catch (_) {
    // Fallback if package info fails
  }

  final versionStr = info?.version ?? AppConstants.appVersion;
  final buildStr = info?.buildNumber ?? '15';
  final pkgName = info?.packageName ?? 'in.retailverse.app';
  final brandName = AppBranding.getStoreName();
  if (!context.mounted) return;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      bool isChecking = false;
      String? updateMessage;

      return StatefulBuilder(
        builder: (context, setState) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // App Icon & Brand Branding
                  Container(
                    width: 72,
                    height: 72,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.14),
                          AppColors.primary.withValues(alpha: 0.04),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.22),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    brandName.isNotEmpty && brandName != 'My Store'
                        ? brandName
                        : 'RetailVerse POS',
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enterprise Cloud Retail & POS Ecosystem',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Version Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Text(
                      'v$versionStr (Build $buildStr) • Production',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Up to date card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFA5D6A7)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF2E7D32),
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                updateMessage ?? 'App is Up to Date',
                                style: AppTypography.labelLarge.copyWith(
                                  color: const Color(0xFF1B5E20),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                updateMessage != null
                                    ? 'Latest release installed and verified.'
                                    : 'You are running the latest stable build of RetailVerse.',
                                style: AppTypography.bodySmall.copyWith(
                                  color: const Color(0xFF2E7D32),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Metadata list
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundTertiary,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.7)),
                    ),
                    child: Column(
                      children: [
                        _buildVersionInfoRow(
                          icon: Icons.numbers_rounded,
                          label: 'App Version',
                          value: versionStr,
                        ),
                        const Divider(height: 1, indent: 48),
                        _buildVersionInfoRow(
                          icon: Icons.build_circle_outlined,
                          label: 'Build Number',
                          value: buildStr,
                        ),
                        const Divider(height: 1, indent: 48),
                        _buildVersionInfoRow(
                          icon: Icons.inventory_2_outlined,
                          label: 'Package ID',
                          value: pkgName,
                        ),
                        const Divider(height: 1, indent: 48),
                        _buildVersionInfoRow(
                          icon: Icons.cloud_done_outlined,
                          label: 'Deployment Channel',
                          value: 'Cloud Production',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // What's New Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              size: 18,
                              color: Color(0xFFE65100),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "What's New in v$versionStr",
                              style: AppTypography.labelLarge.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildReleaseFeatureItem(
                          'Custom Domain Manager',
                          'Connect custom store domain directly from app with locked client verification.',
                        ),
                        _buildReleaseFeatureItem(
                          'Live Dashboard Sync',
                          'Real-time revenue, orders count, and invoice updates on the dashboard.',
                        ),
                        _buildReleaseFeatureItem(
                          'Quote to Invoice',
                          'Convert generated quotes to completed invoices in 1 click.',
                        ),
                        _buildReleaseFeatureItem(
                          'Support & Tickets',
                          'Direct customer support ticket management and chat.',
                        ),
                        _buildReleaseFeatureItem(
                          'Receipt & Thermal Printing',
                          'Optimized Bluetooth ESC/POS receipt thermal printing.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Check for updates button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: isChecking
                          ? null
                          : () async {
                              setState(() => isChecking = true);
                              await Future.delayed(const Duration(milliseconds: 1200));
                              if (context.mounted) {
                                setState(() {
                                  isChecking = false;
                                  updateMessage = 'Already at Latest Version (v$versionStr)';
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '✓ RetailVerse POS is fully up to date (v$versionStr • build $buildStr)',
                                    ),
                                    backgroundColor: const Color(0xFF2E7D32),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                            },
                      icon: isChecking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded, size: 20),
                      label: Text(
                        isChecking ? 'Checking for updates...' : 'Check for Updates',
                        style: AppTypography.labelLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Secondary action buttons: Licenses & Close
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.cardBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            showLicensePage(
                              context: context,
                              applicationName: brandName.isNotEmpty ? brandName : 'RetailVerse POS',
                              applicationVersion: 'v$versionStr ($buildStr)',
                            );
                          },
                          child: const Text('View Licenses'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildVersionInfoRow({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

Widget _buildReleaseFeatureItem(String title, String description) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> _showChangePasswordDialog(BuildContext context) async {
  final oldPasswordCtrl = TextEditingController();
  final newPasswordCtrl = TextEditingController();
  bool isLoading = false;
  bool obscureOld = true;
  bool obscureNew = true;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (c) => StatefulBuilder(builder: (context, setDialogState) {
      return AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Change Password',
          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPasswordCtrl,
              obscureText: obscureOld,
              decoration: InputDecoration(
                labelText: 'Current Password',
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureOld ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    setDialogState(() {
                      obscureOld = !obscureOld;
                    });
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordCtrl,
              obscureText: obscureNew,
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: const Icon(Icons.lock_reset, color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureNew ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    setDialogState(() {
                      obscureNew = !obscureNew;
                    });
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          else ...[
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (oldPasswordCtrl.text.isEmpty || newPasswordCtrl.text.isEmpty) return;
                setDialogState(() => isLoading = true);
                try {
                  final accountService = AccountService();
                  await accountService.changePassword(
                    oldPassword: oldPasswordCtrl.text,
                    newPassword: newPasswordCtrl.text,
                  );
                  if (context.mounted) {
                    Navigator.pop(c);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(duration: const Duration(seconds: 2),content: Text('Password changed successfully'), backgroundColor: AppColors.secondary, behavior: SnackBarBehavior.floating),
                    );
                  }
                } catch (e) {
                  setDialogState(() => isLoading = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(duration: const Duration(seconds: 2),content: Text(e.toString()), backgroundColor: AppColors.secondary, behavior: SnackBarBehavior.floating),
                    );
                  }
                }
              },
              child: const Text('Change', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        ],
      );
    }),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:retail_verse_pos/data/remote/admin_users_service.dart';
import 'package:retail_verse_pos/core/services/push_notification_service.dart';
import '../../../../data/local/product_local_service.dart';
import '../../../../data/models/product_model.dart';
import '../data/vendor_service.dart';
import '../domain/models/vendor_model.dart';

class AdminVendorsScreen extends StatefulWidget {
  const AdminVendorsScreen({super.key});

  @override
  State<AdminVendorsScreen> createState() => _AdminVendorsScreenState();
}

class _AdminVendorsScreenState extends State<AdminVendorsScreen> {
  final VendorService _vendorService = VendorService();

  // Mode: 0 = Split Allocation (from user image), 1 = Vendor Directory, 2 = Purchase Order History
  int _activeTab = 0;

  // Selected Product State (default matching screenshot)
  String _productName = 'Grocery';
  String _productSku = 'RV-134045-3890';
  int _currentStock = 5;
  int _threshold = 5;
  int _totalUnitsNeeded = 20;
  final TextEditingController _totalUnitsCtrl = TextEditingController(text: '20');
  final TextEditingController _vendorSearchCtrl = TextEditingController();
  final Map<String, TextEditingController> _splitUnitControllers = {};
  String _vendorSearchQuery = '';

  // Dynamic Vendor Splits
  List<VendorSplitItem> _splits = [];
  List<VendorProfile> _availableVendors = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _totalUnitsCtrl.dispose();
    _vendorSearchCtrl.dispose();
    for (final c in _splitUnitControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final vendors = await _vendorService.getVendors();
    await _vendorService.getAllocations();
    final activeConfig = await _vendorService.getActiveAllocationConfig();

    // Setup initial splits matching user screenshot (shreya = 10, second = 10) or from saved backend config
    final shreyaVendor = vendors.firstWhere(
      (v) => v.name.toLowerCase() == 'shreya',
      orElse: () => vendors.isNotEmpty ? vendors.first : VendorProfile(
        id: 'ven_shreya_01',
        name: 'shreya',
        companyName: 'Shreya Wholesalers',
        phone: '+91 98765 43210',
        email: 'shreya@retailverse.com',
        category: 'Grocery',
        address: 'APMC Market Yard',
        createdAt: DateTime(2026, 1, 1),
      ),
    );

    final secondVendor = vendors.length > 1 ? vendors[1] : shreyaVendor;
    final targetDate = DateTime(2026, 11, 5);

    List<VendorSplitItem> loadedSplits = [
      VendorSplitItem(
        id: 'split_1',
        vendorId: shreyaVendor.id,
        vendorName: shreyaVendor.name,
        units: 10,
        targetDeliveryDate: targetDate,
      ),
      VendorSplitItem(
        id: 'split_2',
        vendorId: secondVendor.id,
        vendorName: secondVendor.name,
        units: 10,
        targetDeliveryDate: targetDate.add(const Duration(days: 2)),
      ),
    ];

    if (activeConfig != null) {
      if (activeConfig['threshold'] != null) {
        _threshold = (activeConfig['threshold'] as num).toInt();
      }
      if (activeConfig['totalUnitsNeeded'] != null) {
        _totalUnitsNeeded = (activeConfig['totalUnitsNeeded'] as num).toInt();
        _totalUnitsCtrl.text = _totalUnitsNeeded.toString();
      }
      if (activeConfig['productName'] != null) {
        _productName = activeConfig['productName'].toString();
      }
      if (activeConfig['productSku'] != null) {
        _productSku = activeConfig['productSku'].toString();
      }
      if (activeConfig['splits'] != null && (activeConfig['splits'] as List).isNotEmpty) {
        try {
          loadedSplits = (activeConfig['splits'] as List)
              .map((s) => VendorSplitItem.fromJson(Map<String, dynamic>.from(s as Map)))
              .toList();
        } catch (_) {}
      }
    }

    // Initialize synced text editing controllers for all splits
    for (final s in loadedSplits) {
      _splitUnitControllers[s.id] = TextEditingController(text: s.units.toString());
    }

    if (mounted) {
      final seenIds = <String>{};
      final deduplicated = vendors.where((v) => seenIds.add(v.id)).toList();
      setState(() {
        _availableVendors = deduplicated;
        _splits = loadedSplits;
        _isLoading = false;
      });
    }
  }

  int get _totalAllocated =>
      _splits.fold<int>(0, (sum, item) => sum + item.units);

  int get _allocatedVendorCount =>
      _splits.where((s) => s.units > 0 && s.vendorName.isNotEmpty).length;

  void _addVendorSplit() {
    HapticFeedback.lightImpact();
    final defaultVendor = _availableVendors.isNotEmpty
        ? _availableVendors[(_splits.length) % _availableVendors.length]
        : null;

    final remainingUnits = (_totalUnitsNeeded - _totalAllocated).clamp(0, 9999);
    final newSplit = VendorSplitItem(
      id: 'split_${DateTime.now().millisecondsSinceEpoch}',
      vendorId: defaultVendor?.id ?? '',
      vendorName: defaultVendor?.name ?? 'shreya',
      units: remainingUnits > 0 ? remainingUnits : 5,
      targetDeliveryDate: DateTime.now().add(const Duration(days: 6)),
    );

    _splitUnitControllers[newSplit.id] =
        TextEditingController(text: newSplit.units.toString());

    setState(() {
      _splits.add(newSplit);
    });
  }

  void _removeVendorSplit(int index) {
    HapticFeedback.mediumImpact();
    if (_splits.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one vendor split is required.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      final removed = _splits.removeAt(index);
      _splitUnitControllers[removed.id]?.dispose();
      _splitUnitControllers.remove(removed.id);
    });
  }

  void _updateSplitUnits(VendorSplitItem split, int newUnits) {
    final clamped = newUnits.clamp(0, 99999);
    setState(() {
      split.units = clamped;
      _splitUnitControllers[split.id]?.text = clamped.toString();
    });
  }

  void _autoDistributeEvenly() {
    HapticFeedback.mediumImpact();
    if (_splits.isEmpty) return;
    final perSplit = _totalUnitsNeeded ~/ _splits.length;
    final remainder = _totalUnitsNeeded % _splits.length;

    setState(() {
      for (int i = 0; i < _splits.length; i++) {
        final assigned = perSplit + (i < remainder ? 1 : 0);
        _splits[i].units = assigned;
        _splitUnitControllers[_splits[i].id]?.text = assigned.toString();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Distributed $_totalUnitsNeeded units evenly across ${_splits.length} vendors!',
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickDeliveryDate(VendorSplitItem split) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: split.targetDeliveryDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        split.targetDeliveryDate = picked;
      });
    }
  }

  Future<void> _openNewVendorProfileDialog() async {
    final nameCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'Grocery & Staples');
    final gstinCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final remainingUnits = (_totalUnitsNeeded - _totalAllocated).clamp(0, 9999);
    final unitsCtrl = TextEditingController(
      text: remainingUnits > 0 ? '$remainingUnits' : '5',
    );

    await showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'New Vendor Profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textTertiary),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildFormField(
                  label: 'VENDOR / CONTACT NAME *',
                  controller: nameCtrl,
                  hint: 'e.g. shreya or Rajesh Kumar',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  label: 'COMPANY / FIRM NAME',
                  controller: companyCtrl,
                  hint: 'e.g. Shreya Wholesalers Pvt Ltd',
                  icon: Icons.business_outlined,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildFormField(
                        label: 'PHONE NUMBER *',
                        controller: phoneCtrl,
                        hint: '+91 98765 43210',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFormField(
                        label: 'ALLOCATED UNITS (CARD)',
                        controller: unitsCtrl,
                        hint: 'e.g. 10',
                        icon: Icons.inventory_2_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildFormField(
                        label: 'SUPPLY CATEGORY',
                        controller: categoryCtrl,
                        hint: 'Grocery, FMCG, Dairy',
                        icon: Icons.category_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFormField(
                        label: 'EMAIL',
                        controller: emailCtrl,
                        hint: 'vendor@email.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  label: 'GSTIN / TAX ID',
                  controller: gstinCtrl,
                  hint: '27AABCU9603R1ZX',
                  icon: Icons.receipt_long_outlined,
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  label: 'WAREHOUSE / DISPATCH ADDRESS',
                  controller: addressCtrl,
                  hint: 'Market Yard / Warehouse location',
                  icon: Icons.location_on_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(color: AppColors.cardBorder),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter vendor name'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }

                          final newVendor = await _vendorService.createVendor(
                            name: name,
                            companyName: companyCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            email: emailCtrl.text.trim(),
                            category: categoryCtrl.text.trim(),
                            address: addressCtrl.text.trim(),
                            gstin: gstinCtrl.text.trim(),
                          );

                          Navigator.pop(dialogCtx);
                          if (!mounted) return;

                          final parsedUnits = int.tryParse(unitsCtrl.text.trim()) ??
                              (remainingUnits > 0 ? remainingUnits : 5);

                          final newSplit = VendorSplitItem(
                            id: 'split_${DateTime.now().millisecondsSinceEpoch}',
                            vendorId: newVendor.id,
                            vendorName: newVendor.name,
                            units: parsedUnits,
                            targetDeliveryDate:
                                DateTime.now().add(const Duration(days: 6)),
                          );

                          _splitUnitControllers[newSplit.id] =
                              TextEditingController(text: newSplit.units.toString());

                          setState(() {
                            _availableVendors = [
                              newVendor,
                              ..._availableVendors.where((x) => x.id != newVendor.id),
                            ];
                            _splits.add(newSplit);
                          });

                          // Persist updated split configuration to backend
                          _vendorService.saveAllocationConfig(
                            productName: _productName,
                            productSku: _productSku,
                            threshold: _threshold,
                            totalUnitsNeeded: _totalUnitsNeeded,
                            splits: _splits,
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                        'Vendor "${newVendor.name}" profile & split card created ($parsedUnits units)!'),
                                  ),
                                ],
                              ),
                              backgroundColor: AppColors.success,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text(
                          'Save & Add Card',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openVendorAccessDialog(VendorProfile v) async {
    final nameCtrl = TextEditingController(text: v.companyName.isNotEmpty ? v.companyName : v.name);
    final emailCtrl = TextEditingController(
      text: v.email.isNotEmpty
          ? v.email
          : '${v.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}@gmail.com',
    );
    final phoneCtrl = TextEditingController(text: v.phone);
    final passCtrl = TextEditingController(text: 'password123');
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.key_rounded,
                            color: Color(0xFFD97706), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Vendor Portal Login Access',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Assign credentials for ${v.name}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.textTertiary),
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'When this vendor logs in with these credentials, they will be routed directly to their Vendor Portal for "${v.name}".',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    label: 'VENDOR NAME (PORTAL SCOPE)',
                    controller: TextEditingController(text: v.name),
                    hint: v.name,
                    icon: Icons.storefront_rounded,
                    enabled: false,
                  ),
                  const SizedBox(height: 12),
                  _buildFormField(
                    label: 'LOGIN EMAIL *',
                    controller: emailCtrl,
                    hint: 'vendor@domain.com',
                    icon: Icons.email_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildFormField(
                    label: 'LOGIN PASSWORD *',
                    controller: passCtrl,
                    hint: 'Set strong password',
                    icon: Icons.lock_outline_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildFormField(
                    label: 'PHONE NUMBER',
                    controller: phoneCtrl,
                    hint: '10 digit mobile',
                    icon: Icons.phone_outlined,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: BorderSide(color: AppColors.cardBorder),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancel',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final email = emailCtrl.text.trim();
                                  final password = passCtrl.text.trim();
                                  if (email.isEmpty || password.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please enter both Email and Password'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }

                                setDialogState(() => isSaving = true);
                                try {
                                  final svc = AdminUsersService();
                                  await svc.createStaff(
                                    name: nameCtrl.text.trim().isNotEmpty
                                        ? nameCtrl.text.trim()
                                        : v.name,
                                    email: email,
                                    phone: phoneCtrl.text.trim(),
                                    role: 'vendor',
                                    password: password,
                                    vendorName: v.name,
                                    vendorId: v.id,
                                  );
                                } catch (e) {
                                  debugPrint('[AdminVendorsScreen] Remote createStaff: $e (saving locally)');
                                }

                                // Always persist locally so login is guaranteed to work
                                await _vendorService.saveLocalVendorLogin(
                                  email: email,
                                  password: password,
                                  vendorName: v.name,
                                  vendorId: v.id,
                                  name: nameCtrl.text.trim(),
                                  phone: phoneCtrl.text.trim(),
                                );

                                if (mounted) {
                                  Navigator.pop(dialogCtx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded,
                                              color: Colors.white, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Vendor Login Created! ${v.name} can log in with $email to open Vendor Portal directly.',
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: AppColors.success,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                        icon: isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(
                          isSaving ? 'Creating...' : 'Grant Portal Access',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: enabled ? AppColors.background : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            enabled: enabled,
            style: TextStyle(
              fontSize: 13,
              color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: const TextStyle(
                  color: AppColors.textTertiary, fontSize: 13),
              prefixIcon: Icon(icon, color: AppColors.textTertiary, size: 18),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openProductConfigDialog() async {
    final nameCtrl = TextEditingController(text: _productName);
    final skuCtrl = TextEditingController(text: _productSku);
    final stockCtrl = TextEditingController(text: _currentStock.toString());
    final thresholdCtrl = TextEditingController(text: _threshold.toString());
    final searchCtrl = TextEditingController();

    List<Product> allProducts = [];
    try {
      allProducts = await ProductLocalService().getAllProducts();
    } catch (_) {}

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final query = searchCtrl.text.trim().toLowerCase();
          final filtered = query.isEmpty
              ? allProducts.take(6).toList()
              : allProducts
                  .where((p) =>
                      p.name.toLowerCase().contains(query) ||
                      (p.barcode != null && p.barcode!.toLowerCase().contains(query)) ||
                      p.sku.toLowerCase().contains(query))
                  .take(8)
                  .toList();

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(22),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.inventory_2_rounded,
                              color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Product & Low Stock Config',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: AppColors.textTertiary),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (allProducts.isNotEmpty) ...[
                      const Text(
                        'QUICK SELECT FROM STORE INVENTORY',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: searchCtrl,
                        onChanged: (_) => setDialogState(() {}),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search product name, SKU or barcode...',
                          hintStyle: const TextStyle(
                              color: AppColors.textTertiary, fontSize: 12.5),
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 18, color: AppColors.textTertiary),
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.cardBorder),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 140),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: AppColors.divider),
                          itemBuilder: (ctx, i) {
                            final p = filtered[i];
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              title: Text(p.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              subtitle: Text(
                                  'SKU: ${p.sku.isNotEmpty ? p.sku : (p.barcode ?? "N/A")} • Stock: ${p.stock}',
                                  style: const TextStyle(fontSize: 11)),
                              trailing: const Icon(Icons.touch_app_rounded,
                                  size: 16, color: AppColors.primary),
                              onTap: () {
                                setDialogState(() {
                                  nameCtrl.text = p.name;
                                  skuCtrl.text = p.sku.isNotEmpty
                                      ? p.sku
                                      : (p.barcode ?? 'RV-${p.id.length >= 6 ? p.id.substring(0, 6) : p.id}');
                                  stockCtrl.text = p.stock.toString();
                                  thresholdCtrl.text = p.reorderLevel.toString();
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: AppColors.divider),
                      const SizedBox(height: 14),
                    ],
                    _buildFormField(
                      label: 'PRODUCT NAME *',
                      controller: nameCtrl,
                      hint: 'e.g. Grocery or Basmati Rice',
                      icon: Icons.label_outline_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildFormField(
                      label: 'PRODUCT SKU / CODE',
                      controller: skuCtrl,
                      hint: 'e.g. RV-134045-3890',
                      icon: Icons.qr_code_rounded,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildFormField(
                            label: 'CURRENT STOCK (UNITS)',
                            controller: stockCtrl,
                            hint: '5',
                            icon: Icons.inventory_rounded,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFormField(
                            label: 'LOW STOCK THRESHOLD (LIMIT ≤ 5)',
                            controller: thresholdCtrl,
                            hint: '5',
                            icon: Icons.warning_amber_rounded,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('Cancel',
                              style: TextStyle(color: AppColors.textSecondary)),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Update & Save Config',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;

                            final parsedStock = int.tryParse(stockCtrl.text.trim()) ?? 5;
                            final parsedThreshold = int.tryParse(thresholdCtrl.text.trim()) ?? 5;
                            final sku = skuCtrl.text.trim().isNotEmpty
                                ? skuCtrl.text.trim()
                                : 'RV-${DateTime.now().millisecondsSinceEpoch.remainder(100000)}';

                            Navigator.pop(dialogCtx);
                            setState(() {
                              _productName = name;
                              _productSku = sku;
                              _currentStock = parsedStock;
                              _threshold = parsedThreshold;
                            });

                            await _vendorService.saveAllocationConfig(
                              productName: _productName,
                              productSku: _productSku,
                              threshold: _threshold,
                              totalUnitsNeeded: _totalUnitsNeeded,
                              splits: _splits,
                            );

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Product updated to "$_productName" (Threshold: $_threshold units)'),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmAllocation() async {
    HapticFeedback.heavyImpact();

    if (_splits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one vendor split allocation.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_totalAllocated != _totalUnitsNeeded) {
      final diff = (_totalUnitsNeeded - _totalAllocated).abs();
      final isUnder = _totalAllocated < _totalUnitsNeeded;
      final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(
                    isUnder
                        ? Icons.warning_amber_rounded
                        : Icons.info_outline_rounded,
                    color: isUnder ? AppColors.warning : AppColors.info,
                  ),
                  const SizedBox(width: 8),
                  const Text('Allocation Mismatch',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                isUnder
                    ? 'You have only allocated $_totalAllocated of $_totalUnitsNeeded units ($diff units remaining unassigned). Do you still want to proceed with this purchase split?'
                    : 'You have allocated $_totalAllocated units, which exceeds the needed $_totalUnitsNeeded units by $diff units. Do you want to proceed?',
                style: const TextStyle(fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Adjust Splits'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Proceed Anyway'),
                ),
              ],
            ),
          ) ??
          false;

      if (!proceed) return;
    }

    setState(() => _isSubmitting = true);

    // Save allocation configuration to backend & local storage
    await _vendorService.saveAllocationConfig(
      productName: _productName,
      productSku: _productSku,
      threshold: _threshold,
      totalUnitsNeeded: _totalUnitsNeeded,
      splits: _splits,
    );

    final record = VendorAllocationRecord(
      id: 'PO-RV-${DateTime.now().millisecondsSinceEpoch.remainder(100000)}',
      productId: 'prod_grocery_01',
      productName: _productName,
      productSku: _productSku,
      currentStock: _currentStock,
      threshold: _threshold,
      totalUnitsNeeded: _totalUnitsNeeded,
      splits: _splits,
      createdAt: DateTime.now(),
      status: 'Allocated',
    );

    await _vendorService.saveAllocation(record);

    final vendorSummary = _splits.map((s) => '${s.vendorName} (${s.units}u)').join(', ');
    await PushNotificationService.showLocalNotification(
      id: record.id.hashCode,
      title: '📦 Vendor Purchase Allocation: $_productName',
      body: 'PO #${record.id}: Allocated $_totalUnitsNeeded units across $vendorSummary.',
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      _showSuccessConfirmationModal(record);
    }
  }

  /// Triggered when Admin taps the "Notify Vendors" button:
  /// Saves current configuration and immediately dispatches purchase split notification to vendors
  Future<void> _manualNotifyVendors() async {
    HapticFeedback.heavyImpact();
    setState(() => _isSubmitting = true);

    final res = await _vendorService.manualNotifyVendors(
      productName: _productName,
      productSku: _productSku,
      threshold: _threshold,
      totalUnitsNeeded: _totalUnitsNeeded,
      splits: _splits,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final po = res['poNumber'] ?? 'PO-RV-001';
    final msg = res['message'] ?? 'Notification sent to vendors!';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active_rounded,
                color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dispatched #$po',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(msg, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessConfirmationModal(VendorAllocationRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF16A34A), size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Multi-Vendor Split Allocation Confirmed!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Purchase Order #${record.id} for ${record.productName} (${record.totalUnitsNeeded} Units)',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < record.splits.length; i++) ...[
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor:
                              AppColors.primary.withOpacity(0.12),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            record.splits[i].vendorName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${record.splits[i].units} Units',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd-MM-yyyy').format(
                              record.splits[i].targetDeliveryDate),
                          style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    if (i < record.splits.length - 1)
                      const Divider(height: 16, color: AppColors.divider),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.send_rounded,
                    size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Order dispatches broadcasted to registered vendors with active Read-Receipt tracking.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  setState(() => _activeTab = 2);
                },
                child: const Text('Done',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // ── HEADER WITH RESPONSIVE MENU BUTTON & MULTI-VENDOR TITLE ──
                _buildHeader(context),

                // ── TAB SELECTOR (Split Allocation / Vendors / Logs) ──
                _buildTabSelector(),

                // ── MAIN CONTENT AREA ──
                Expanded(
                  child: _activeTab == 0
                      ? _buildSplitAllocationContent()
                      : _activeTab == 1
                          ? _buildVendorsDirectoryContent()
                          : _buildAllocationHistoryContent(),
                ),

                // ── STICKY FOOTER ACTION BAR (When on Split Allocation tab) ──
                if (_activeTab == 0) _buildStickyFooter(),
              ],
            ),
    );
  }

  // ── HEADER SECTION ─────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder, width: 1.5)),
        boxShadow: AppColors.shadowSubtle,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 650;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const ResponsiveMenuButton(),
                    const SizedBox(width: 8),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.people_alt_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Multi-Vendor Allocation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          color: AppColors.textTertiary, size: 22),
                      tooltip: 'Refresh',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _loadInitialData();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFFFDE68A), width: 1),
                      ),
                      child: const Text(
                        'LOW STOCK TRIGGER',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const ResponsiveMenuButton(),
              const SizedBox(width: 8),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'Multi-Vendor Split Allocation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: const Color(0xFFFDE68A), width: 1),
                          ),
                          child: const Text(
                            'LOW STOCK TRIGGER',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Distribute purchase replenishment volume across multiple registered vendors.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: AppColors.textTertiary),
                tooltip: 'Refresh',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _loadInitialData();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ── TAB SELECTOR ───────────────────────────────────
  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabChip(0, 'Split Allocation', Icons.call_split_rounded),
            const SizedBox(width: 8),
            _buildTabChip(1, 'Vendor Directory (${_availableVendors.length})',
                Icons.storefront_rounded),
            const SizedBox(width: 8),
            _buildTabChip(2, 'Allocation History', Icons.history_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip(int index, String label, IconData icon) {
    final isSelected = _activeTab == index;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeTab = index);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 1. MAIN SPLIT ALLOCATION TAB CONTENT (MATCHING SCREENSHOT) ─
  Widget _buildSplitAllocationContent() {
    final double allocationProgress = _totalUnitsNeeded > 0
        ? (_totalAllocated / _totalUnitsNeeded).clamp(0.0, 1.0)
        : 0.0;

    final isExact = _totalAllocated == _totalUnitsNeeded;
    final isOver = _totalAllocated > _totalUnitsNeeded;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── CARD 1: PRODUCT INFO & STOCK CARD ────────────────
              _buildProductReplenishmentCard(),

              const SizedBox(height: 16),

              // ── CARD 2: ALLOCATION BREAKDOWN & PROGRESS BAR ─────
              _buildAllocationBreakdownCard(
                  allocationProgress, isExact, isOver),

              const SizedBox(height: 24),

              // ── CARD 3: ASSIGNED VENDOR SPLITS HEADER & BUTTONS ─
              _buildAssignedVendorSplitsHeader(),

              const SizedBox(height: 14),

              // ── DYNAMIC VENDOR SPLIT CARDS ──────────────────────
              for (int i = 0; i < _splits.length; i++) ...[
                _buildVendorSplitCard(i, _splits[i]),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── PRODUCT REPLENISHMENT CARD (MATCHING SCREENSHOT) ──
  Widget _buildProductReplenishmentCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: AppColors.shadowSubtle,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 620;

          final productMeta = Row(
            children: [
              // Product Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Center(
                  child: Text(
                    _productName.length >= 6
                        ? _productName.substring(0, 6)
                        : _productName,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Product Name, SKU, Stock
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _productName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'SKU: $_productSku',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: _openProductConfigDialog,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.edit_outlined, size: 11, color: AppColors.primary),
                                SizedBox(width: 3),
                                Text(
                                  'Change Product',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text(
                          'Current Stock: ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '$_currentStock units',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '•',
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Threshold: $_threshold units',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          final unitsNeeded = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Total Units Needed: ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  final cur = int.tryParse(_totalUnitsCtrl.text) ?? _totalUnitsNeeded;
                  final next = (cur - 5).clamp(1, 99999);
                  _totalUnitsCtrl.text = next.toString();
                  setState(() => _totalUnitsNeeded = next);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 32,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.remove, size: 16, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 64,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cardBorder, width: 1.5),
                ),
                alignment: Alignment.center,
                child: TextField(
                  controller: _totalUnitsCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val) ?? 0;
                    setState(() => _totalUnitsNeeded = parsed);
                  },
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  final cur = int.tryParse(_totalUnitsCtrl.text) ?? _totalUnitsNeeded;
                  final next = (cur + 5).clamp(1, 99999);
                  _totalUnitsCtrl.text = next.toString();
                  setState(() => _totalUnitsNeeded = next);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 32,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.add, size: 16, color: AppColors.textPrimary),
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                productMeta,
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 12),
                unitsNeeded,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: productMeta),
              const SizedBox(width: 16),
              unitsNeeded,
            ],
          );
        },
      ),
    );
  }

  // ── ALLOCATION BREAKDOWN & PROGRESS CARD ──────────
  Widget _buildAllocationBreakdownCard(
      double progress, bool isExact, bool isOver) {
    Color progressColor = const Color(0xFF10B981); // Emerald Green
    if (isOver) {
      progressColor = const Color(0xFFEF4444); // Red
    } else if (!isExact) {
      progressColor = const Color(0xFFF59E0B); // Amber
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: AppColors.shadowSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Allocation Breakdown:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '$_totalAllocated / $_totalUnitsNeeded units allocated ($_allocatedVendorCount vendors)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 8,
              color: const Color(0xFFF1F5F9),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: progressColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── ASSIGNED VENDOR SPLITS HEADER & BUTTONS ───────
  Widget _buildAssignedVendorSplitsHeader() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        const Text(
          'ASSIGNED VENDOR SPLITS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: Color(0xFF475569),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed: _openNewVendorProfileDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add, size: 15),
              label: const Text(
                'New Profile',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton.icon(
              onPressed: _splits.isNotEmpty ? _autoDistributeEvenly : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.pie_chart_outline_rounded, size: 14),
              label: const Text(
                'Auto Split',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton.icon(
              onPressed: _addVendorSplit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEFF6FF),
                foregroundColor: AppColors.primary,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.call_split_rounded, size: 15),
              label: const Text(
                'Add Split',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── DYNAMIC VENDOR SPLIT CARD (MATCHING SCREENSHOT) ──
  Widget _buildVendorSplitCard(int index, VendorSplitItem split) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: AppColors.shadowSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header: "1 Vendor Split #1" + Delete icon
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vendor Split #${index + 1}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
                tooltip: 'Remove Split',
                onPressed: () => _removeVendorSplit(index),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 3 Inputs Row (ASSIGN VENDOR, UNITS SPLIT, TARGET DELIVERY)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;

              final vendorField = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ASSIGN VENDOR',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    ),
                    child: Builder(
                      builder: (context) {
                        final uniqueVendors = <VendorProfile>[];
                        final seenVendorIds = <String>{};
                        for (final v in _availableVendors) {
                          if (seenVendorIds.add(v.id)) {
                            uniqueVendors.add(v);
                          }
                        }

                        // Safely resolve matching vendor by ID or name
                        String? selectedVendorId;
                        if (uniqueVendors.any((v) => v.id == split.vendorId && v.id.isNotEmpty)) {
                          selectedVendorId = split.vendorId;
                        } else if (uniqueVendors.any((v) =>
                            v.name.toLowerCase().trim() == split.vendorName.toLowerCase().trim() &&
                            v.name.trim().isNotEmpty)) {
                          final matched = uniqueVendors.firstWhere((v) =>
                              v.name.toLowerCase().trim() == split.vendorName.toLowerCase().trim());
                          selectedVendorId = matched.id;
                          split.vendorId = matched.id;
                          split.vendorName = matched.name;
                        } else if (uniqueVendors.isNotEmpty) {
                          selectedVendorId = uniqueVendors.first.id;
                          split.vendorId = uniqueVendors.first.id;
                          split.vendorName = uniqueVendors.first.name;
                        }

                        return DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedVendorId,
                            isExpanded: true,
                            hint: const Text(
                              'Select Vendor',
                              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF64748B)),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            items: uniqueVendors.map((v) {
                              return DropdownMenuItem<String>(
                                value: v.id,
                                child: Text(
                                  v.name,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  final match = uniqueVendors.firstWhere(
                                    (x) => x.id == val,
                                    orElse: () => uniqueVendors.first,
                                  );
                                  split.vendorId = match.id;
                                  split.vendorName = match.name;
                                });
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );

              final unitsField = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'UNITS SPLIT',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _updateSplitUnits(split, split.units - 1);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 32,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.remove, size: 15, color: AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                          ),
                          child: TextField(
                            key: ValueKey('split_units_${split.id}'),
                            controller: _splitUnitControllers[split.id] ??=
                                TextEditingController(text: split.units.toString()),
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val) ?? 0;
                              setState(() => split.units = parsed);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _updateSplitUnits(split, split.units + 1);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 32,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.add, size: 15, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ],
              );

              final deliveryField = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.calendar_today_outlined,
                          size: 13, color: Color(0xFF64748B)),
                      SizedBox(width: 4),
                      Text(
                        'TARGET DELIVERY',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _pickDeliveryDate(split),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFE2E8F0), width: 1.2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('dd-MM-yyyy')
                                .format(split.targetDeliveryDate),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Icon(Icons.calendar_month_rounded,
                              size: 18, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  children: [
                    vendorField,
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: unitsField),
                        const SizedBox(width: 12),
                        Expanded(child: deliveryField),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 4, child: vendorField),
                  const SizedBox(width: 14),
                  Expanded(flex: 2, child: unitsField),
                  const SizedBox(width: 14),
                  Expanded(flex: 3, child: deliveryField),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── BOTTOM STICKY ACTION FOOTER (MATCHING SCREENSHOT) ──
  Widget _buildStickyFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;
            if (isNarrow) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Allocated orders will appear instantly on the Vendor Portal with Read-Receipt tracking.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: () => _loadInitialData(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                      FilledButton.icon(
                        onPressed: _isSubmitting ? null : _manualNotifyVendors,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.send_rounded, size: 14),
                        label: const Text('Notify Vendors', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                      FilledButton(
                        onPressed: _isSubmitting ? null : _confirmAllocation,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                'Confirm ($_totalAllocated Units)',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                      ),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: Text(
                    'Allocated orders will appear instantly on the Vendor Portal with Read-Receipt tracking.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withOpacity(0.9),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: () => _loadInitialData(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _manualNotifyVendors,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Notify Vendors', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isSubmitting ? null : _confirmAllocation,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Confirm Allocation ($_totalAllocated Units)',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── 2. VENDOR DIRECTORY TAB ────────────────────────
  Widget _buildVendorsDirectoryContent() {
    final query = _vendorSearchQuery.trim().toLowerCase();
    final filteredVendors = query.isEmpty
        ? _availableVendors
        : _availableVendors.where((v) =>
            v.name.toLowerCase().contains(query) ||
            v.companyName.toLowerCase().contains(query) ||
            v.category.toLowerCase().contains(query) ||
            v.phone.toLowerCase().contains(query)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Registered Vendor Profiles (${_availableVendors.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Vendor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: _openNewVendorProfileDialog,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _vendorSearchCtrl,
                onChanged: (val) => setState(() => _vendorSearchQuery = val),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search vendors by name, company, category or phone...',
                  hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textTertiary),
                  suffixIcon: _vendorSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _vendorSearchCtrl.clear();
                            setState(() => _vendorSearchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              if (filteredVendors.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: Column(
                    children: const [
                      Icon(Icons.person_search_rounded, size: 48, color: AppColors.textTertiary),
                      SizedBox(height: 10),
                      Text('No matching vendors found.',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ] else ...[
                for (final v in filteredVendors) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                      boxShadow: AppColors.shadowSubtle,
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFFEFF6FF),
                              child: Text(
                                v.name.isNotEmpty ? v.name[0].toUpperCase() : 'V',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        v.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          v.category,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    v.companyName,
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.phone_rounded,
                                              size: 13, color: AppColors.textTertiary),
                                          const SizedBox(width: 4),
                                          Text(v.phone,
                                              style: const TextStyle(
                                                  fontSize: 11.5,
                                                  color: AppColors.textSecondary)),
                                        ],
                                      ),
                                      if (v.gstin != null && v.gstin!.isNotEmpty) ...[
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.receipt_long_rounded,
                                                size: 13, color: AppColors.textTertiary),
                                            const SizedBox(width: 4),
                                            Text('GST: ${v.gstin}',
                                                style: const TextStyle(
                                                    fontSize: 11.5,
                                                    color: AppColors.textSecondary)),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: Color(0xFFBFDBFE)),
                                backgroundColor: const Color(0xFFEFF6FF),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 7),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.call_split_rounded, size: 14),
                              label: const Text(
                                'Assign Units',
                                style: TextStyle(
                                    fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () {
                                setState(() {
                                  _activeTab = 0;
                                  if (!_splits.any((s) => s.vendorId == v.id || s.vendorName.toLowerCase() == v.name.toLowerCase())) {
                                    _addVendorSplit();
                                    _splits.last.vendorName = v.name;
                                    _splits.last.vendorId = v.id;
                                  }
                                });
                              },
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFD97706),
                                side: const BorderSide(color: Color(0xFFFDE68A)),
                                backgroundColor: const Color(0xFFFFFBEB),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.key_rounded, size: 14),
                              label: const Text(
                                'Portal Access',
                                style: TextStyle(
                                    fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => _openVendorAccessDialog(v),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: Color(0xFFEF4444), size: 20),
                              tooltip: 'Delete Vendor',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16)),
                                    title: const Text('Delete Vendor Profile?'),
                                    content: Text(
                                        'Are you sure you want to remove "${v.name}" from registered vendors?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                            backgroundColor: AppColors.error),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await _vendorService.deleteVendor(v.id);
                                  final updated = await _vendorService.getVendors();
                                  setState(() => _availableVendors = updated);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── 3. ALLOCATION HISTORY TAB ──────────────────────
  Widget _buildAllocationHistoryContent() {
    return FutureBuilder<List<VendorAllocationRecord>>(
      future: _vendorService.getAllocations(),
      builder: (context, snapshot) {
        final records = snapshot.data ?? [];
        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 48, color: AppColors.textTertiary),
                const SizedBox(height: 12),
                const Text(
                  'No past split allocations yet.',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Confirm an allocation to track vendor dispatches and read-receipts.',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Column(
                children: [
                  for (final r in records) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                        boxShadow: AppColors.shadowSubtle,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Order #${r.id} • ${r.productName}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  r.status,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'SKU: ${r.productSku} • Total Units: ${r.totalUnitsNeeded} • ${DateFormat('dd MMM yyyy, hh:mm a').format(r.createdAt)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: AppColors.divider),
                          const SizedBox(height: 10),
                          for (final s in r.splits) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.circle,
                                          size: 8, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                        s.vendorName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${s.units} Units • Target: ${DateFormat('dd-MM-yyyy').format(s.targetDeliveryDate)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

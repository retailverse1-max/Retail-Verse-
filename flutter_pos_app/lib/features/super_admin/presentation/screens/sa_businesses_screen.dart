import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/data/remote/super_admin_service.dart';
import 'package:retail_verse_pos/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:retail_verse_pos/features/super_admin/presentation/screens/sa_shell.dart';

class SaBusinessesScreen extends StatefulWidget {
  const SaBusinessesScreen({super.key});

  @override
  State<SaBusinessesScreen> createState() => _SaBusinessesScreenState();
}

class _SaBusinessesScreenState extends State<SaBusinessesScreen> {
  final _svc = SuperAdminService();
  late Future<Map<String, dynamic>> _f;
  final _searchC = TextEditingController();
  String _searchQ = '';

  @override
  void initState() {
    super.initState();
    _f = _loadData();
  }

  Future<Map<String, dynamic>> _loadData() async {
    final res = await Future.wait([
      _svc.listBusinesses(),
      _svc.listCustomDomains(),
      _svc.getAnalyticsSummary(),
    ]);
    return {
      'businesses': res[0] as List<Map<String, dynamic>>,
      'domains': res[1] as List<Map<String, dynamic>>,
      'analytics': res[2] as Map<String, dynamic>,
    };
  }

  Future<void> _openAddBusiness() async {
    final saved = await context.push<bool>('/super-admin/businesses/add');
    if (!mounted) return;
    if (saved == true) {
      setState(() => _f = _loadData());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Success!', style: AppTypography.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('Business registered in ecosystem', style: AppTypography.bodySmall.copyWith(color: Colors.white.withOpacity(0.8))),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddBusiness,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_business_rounded, color: Colors.white),
        label: const Text('Add Client', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      body: Column(
        children: [
          // ── MINIMALIST SEARCH HEADER ──────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 24, 24, 24),
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
                        padding: const EdgeInsets.only(right: 12),
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
                      ),
                    Text('Clients', style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
                  ),
                  child: TextField(
                    controller: _searchC,
                    onChanged: (v) => setState(() => _searchQ = v.trim().toLowerCase()),
                    style: AppTypography.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Search client name or ID...',
                      hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      suffixIcon: _searchQ.isNotEmpty 
                        ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () { _searchC.clear(); setState(() => _searchQ = ''); }) 
                        : null,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _f,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }

                final data = snap.data ?? {};
                final businesses = (data['businesses'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                final domains = (data['domains'] as List?)?.cast<Map<String, dynamic>>() ?? [];

                final filtered = businesses.where((b) {
                  if (_searchQ.isEmpty) return true;
                  final name = b['businessName']?.toString().toLowerCase() ?? '';
                  final id = b['businessId']?.toString().toLowerCase() ?? '';
                  return name.contains(_searchQ) || id.contains(_searchQ);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), shape: BoxShape.circle),
                          child: Icon(Icons.business_rounded, size: 64, color: AppColors.primary.withOpacity(0.2)),
                        ),
                        const SizedBox(height: 24),
                        Text('No businesses found', style: AppTypography.titleLarge.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => setState(() => _f = _loadData()),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final b = filtered[index];
                      final bId = b['id']?.toString() ?? b['_id']?.toString() ?? '';
                      final domainObj = domains.cast<Map<String, dynamic>?>().firstWhere(
                        (d) => d?['businessId'] == bId,
                        orElse: () => null
                      );
                      return _BusinessModernCard(business: b, domain: domainObj);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessModernCard extends StatelessWidget {
  final Map<String, dynamic> business;
  final Map<String, dynamic>? domain;

  const _BusinessModernCard({required this.business, this.domain});

  @override
  Widget build(BuildContext context) {
    final name = business['businessName'] ?? 'Unnamed Business';
    final owner = business['ownerName'] ?? 'No owner';
    final email = business['ownerEmail'] ?? '';
    final status = business['status'] ?? 'active';
    final plan = business['subscriptionPlan'] ?? 'free';
    final id = business['id'] ?? business['_id'] ?? '';

    return InkWell(
      onTap: () => context.push('/super-admin/businesses/$id'),
      borderRadius: BorderRadius.circular(32),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: AppColors.shadowSubtle,
          border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.storefront_rounded, color: AppColors.primary, size: constraints.maxWidth > 300 ? 28 : 22),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(name, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.textTertiary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                'ID: RV-${id.toString().substring(id.toString().length - 6).toUpperCase()}',
                                style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(owner, style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'edit') _edit(context);
                      if (val == 'delete') _delete(context);
                    },
                    icon: const Icon(Icons.more_vert_rounded, color: AppColors.textTertiary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 12), Text('Edit')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 18, color: Colors.red), SizedBox(width: 12), Text('Delete', style: TextStyle(color: Colors.red))])),
                    ],
                  ),
                ],
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1, thickness: 1)),
              if (email.isNotEmpty)
                _buildInfoRow(Icons.alternate_email_rounded, email),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildTag(plan.toUpperCase(), AppColors.primary, Icons.workspace_premium_rounded),
                  if (domain != null)
                    _buildTag(domain!['domain'], AppColors.success, Icons.language_rounded),
                  _buildStatusBadge(status),
                ],
              ),
            ],
          );
          },
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Business?'),
        content: const Text('This will permanently remove the business and all its data. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        final id = business['id'] ?? business['_id'] ?? '';
        await SuperAdminService().deleteBusiness(id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Deleted', style: AppTypography.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('Business removed from database', style: AppTypography.bodySmall.copyWith(color: Colors.white.withOpacity(0.8))),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
          // Trigger refresh
          final state = context.findAncestorStateOfType<_SaBusinessesScreenState>();
          state?.setState(() => state._f = state._loadData());
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _edit(BuildContext context) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => _EditBusinessSheet(business: business),
    );

    if (updated == true) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.edit_note_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Updated', style: AppTypography.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text('Client details saved successfully', style: AppTypography.bodySmall.copyWith(color: Colors.white.withOpacity(0.8))),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        );
        final state = context.findAncestorStateOfType<_SaBusinessesScreenState>();
        state?.setState(() => state._f = state._loadData());
      }
    }
  }

  Widget _buildStatusBadge(String status) {
    final active = status.toLowerCase() == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: active ? AppColors.success : AppColors.error,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textTertiary),
        const SizedBox(width: 12),
        Text(text, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildTag(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(text, style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _AddBusinessSheet extends StatefulWidget {
  const _AddBusinessSheet();

  @override
  State<_AddBusinessSheet> createState() => _AddBusinessSheetState();
}

class _AddBusinessSheetState extends State<_AddBusinessSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _owner = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _svc = SuperAdminService();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _owner.dispose();
    _email.dispose();
    _phone.dispose();
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
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(context).viewInsets.bottom + MediaQuery.paddingOf(context).bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Register New Client', style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              _buildField(_name, 'Business Name', Icons.business_rounded, required: true),
              const SizedBox(height: 16),
              _buildField(_owner, 'Owner Name', Icons.person_outline_rounded),
              const SizedBox(height: 16),
              _buildField(_email, 'Owner Email', Icons.email_outlined),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _saving ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Business', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {bool required = false}) {
    return TextFormField(
      controller: controller,
      validator: required ? (v) => v!.isEmpty ? 'Required' : null : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: AppColors.backgroundSecondary.withOpacity(0.5),
      ),
    );
  }
}

class _EditBusinessSheet extends StatefulWidget {
  final Map<String, dynamic> business;
  const _EditBusinessSheet({required this.business});

  @override
  State<_EditBusinessSheet> createState() => _EditBusinessSheetState();
}

class _EditBusinessSheetState extends State<_EditBusinessSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _owner;
  late TextEditingController _email;
  late TextEditingController _phone;
  final _svc = SuperAdminService();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.business['businessName']);
    _owner = TextEditingController(text: widget.business['ownerName']);
    _email = TextEditingController(text: widget.business['ownerEmail']);
    _phone = TextEditingController(text: widget.business['phone']);
  }

  @override
  void dispose() {
    _name.dispose();
    _owner.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final id = widget.business['id'] ?? widget.business['_id'] ?? '';
      await _svc.updateBusiness(id, {
        'businessName': _name.text,
        'ownerName': _owner.text,
        'ownerEmail': _email.text,
        'phone': _phone.text,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(context).viewInsets.bottom + MediaQuery.paddingOf(context).bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Edit Client', style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              _buildField(_name, 'Business Name', Icons.business_rounded, required: true),
              const SizedBox(height: 16),
              _buildField(_owner, 'Owner Name', Icons.person_outline_rounded),
              const SizedBox(height: 16),
              _buildField(_email, 'Owner Email', Icons.email_outlined),
              const SizedBox(height: 16),
              _buildField(_phone, 'Phone Number', Icons.phone_outlined),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _saving ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Update Business', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {bool required = false}) {
    return TextFormField(
      controller: controller,
      validator: required ? (v) => v!.isEmpty ? 'Required' : null : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: AppColors.backgroundSecondary.withOpacity(0.5),
      ),
    );
  }
}

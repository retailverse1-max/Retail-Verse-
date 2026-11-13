import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/branding/app_branding.dart';
import '../../../../data/repositories/marketplace_repository.dart';
import '../../../auth/providers/auth_provider.dart';

class MeeshoSettingsScreen extends ConsumerStatefulWidget {
  const MeeshoSettingsScreen({super.key});

  @override
  ConsumerState<MeeshoSettingsScreen> createState() => _MeeshoSettingsScreenState();
}

class _MeeshoSettingsScreenState extends ConsumerState<MeeshoSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supplierIdController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isCheckingStatus = true;
  bool _isConnected = false;
  String? _connectedSupplierId;
  String? _connectedPhone;

  final MarketplaceRepository _repo = MarketplaceRepository();

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
  }

  @override
  void dispose() {
    _supplierIdController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectionStatus() async {
    setState(() => _isCheckingStatus = true);
    try {
      final token = ref.read(authProvider).token;
      if (token == null) return;

      final res = await _repo.getMeeshoStatus(token: token);
      final data = res['data'];
      if (data != null && data['connected'] == true) {
        setState(() {
          _isConnected = true;
          _connectedSupplierId = data['supplierId']?.toString();
          _connectedPhone = data['phoneNumber']?.toString();
          if (_connectedSupplierId != null) {
            _supplierIdController.text = _connectedSupplierId!;
          }
          if (_connectedPhone != null) {
            _phoneController.text = _connectedPhone!;
          }
        });
      } else {
        setState(() => _isConnected = false);
      }
    } catch (_) {
      // Keep defaults if failed to fetch status
    } finally {
      if (mounted) setState(() => _isCheckingStatus = false);
    }
  }

  Future<void> _oneClickConnectMeesho() async {
    setState(() => _isLoading = true);
    try {
      final token = ref.read(authProvider).token;
      if (token == null) throw Exception('Authentication token missing');

      final uri = Uri.parse('https://supplier.meesho.com/panel/login');
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}

      final response = await _repo.quickConnect(platform: 'meesho', token: token);

      if (mounted) {
        setState(() {
          _isConnected = true;
          _connectedSupplierId = 'MEESHO_ACTIVE';
          _connectedPhone = 'Active';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFF10B981),
            content: Text(response['message'] ?? 'Successfully connected to Meesho Seller Panel!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            content: Text(e.toString(), style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _connectMeesho() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final token = ref.read(authProvider).token;
      if (token == null) throw Exception('Authentication token missing');

      final response = await _repo.connectMeesho(
        supplierId: _supplierIdController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        token: token,
      );

      if (mounted) {
        setState(() {
          _isConnected = true;
          _connectedSupplierId = _supplierIdController.text.trim();
          _connectedPhone = _phoneController.text.trim();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text(response['message'] ?? 'Successfully connected to Meesho Seller Account!'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            content: Text(e.toString(), style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _disconnectMeesho() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Meesho?'),
        content: const Text('Are you sure you want to disconnect this Meesho seller account? Automated sync will be paused.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final token = ref.read(authProvider).token;
      if (token == null) throw Exception('Authentication token missing');

      await _repo.disconnectMeesho(token: token);

      if (mounted) {
        setState(() {
          _isConnected = false;
          _connectedSupplierId = null;
          _connectedPhone = null;
          _supplierIdController.clear();
          _phoneController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 2),
            content: Text('Meesho account disconnected successfully.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            content: Text(e.toString(), style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        title: Text('Meesho Seller Integration', style: AppTypography.headlineSmall.copyWith(color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _isCheckingStatus
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isConnected ? Colors.green.shade50 : Colors.pink.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _isConnected ? Colors.green.shade300 : Colors.pink.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isConnected ? Icons.check_circle_rounded : Icons.storefront_outlined,
                          color: _isConnected ? Colors.green.shade700 : Colors.pink,
                          size: 28,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isConnected ? 'Connected & Active' : 'Not Connected',
                                style: AppTypography.titleMedium.copyWith(
                                  color: _isConnected ? Colors.green.shade800 : Colors.pink.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isConnected
                                    ? 'Supplier ID: ${_connectedSupplierId ?? "Active"} | Auto-sync enabled'
                                    : 'Connect with Supplier ID & Mobile Number (Zero API key hassle)',
                                style: AppTypography.bodySmall.copyWith(
                                  color: _isConnected ? Colors.green.shade700 : Colors.pink.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Connection Form Card
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
                                decoration: BoxDecoration(
                                  color: Colors.pink.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.shopping_bag_outlined, color: Colors.pink, size: 26),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Meesho Seller Details', style: AppTypography.titleLarge),
                                    const SizedBox(height: 2),
                                    Text('Connect directly without developer API keys', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          if (!_isConnected) ...[
                            ElevatedButton.icon(
                              onPressed: _isLoading ? null : _oneClickConnectMeesho,
                              icon: const Icon(Icons.touch_app_rounded, color: Colors.white),
                              label: const Text('1-Click Connect to Meesho Panel', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE81B63),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Text('OR MANUAL DETAILS', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Supplier ID
                          TextFormField(
                            controller: _supplierIdController,
                            enabled: !_isConnected,
                            decoration: InputDecoration(
                              labelText: 'Meesho Supplier ID (Optional)',
                              hintText: 'e.g. SUP108294 or Seller ID',
                              prefixIcon: const Icon(Icons.badge_outlined, color: Colors.pink),
                              helperText: 'Found on your Meesho Supplier Panel dashboard or bills',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Registered Mobile Number
                          TextFormField(
                            controller: _phoneController,
                            enabled: !_isConnected,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Registered Mobile Number',
                              hintText: '10-digit mobile number',
                              prefixIcon: const Icon(Icons.phone_android_outlined, color: Colors.pink),
                              prefixText: '+91 ',
                              helperText: 'Mobile number linked to your Meesho Seller account',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter registered mobile number';
                              }
                              if (val.trim().length < 10) {
                                return 'Please enter a valid 10-digit mobile number';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 24),

                          // Buttons
                          if (_isLoading)
                            const Center(child: CircularProgressIndicator())
                          else if (_isConnected)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _disconnectMeesho,
                                icon: const Icon(Icons.link_off, color: Colors.red),
                                label: const Text('Disconnect Meesho Account', style: TextStyle(color: Colors.red)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _connectMeesho,
                                icon: const Icon(Icons.link_rounded),
                                label: const Text('Connect Meesho Account'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.pink,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Feature Guide Box
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bolt, color: Colors.amber, size: 22),
                            const SizedBox(width: 8),
                            Text('How Meesho Integration Works in POS', style: AppTypography.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureRow(
                          Icons.cloud_upload_outlined,
                          'Instant Catalog Publishing',
                          'When creating a product in ${AppBranding.getStoreName()} POS, enable "Publish to Meesho" to auto-list on your supplier catalog.',
                        ),
                        const SizedBox(height: 10),
                        _buildFeatureRow(
                          Icons.sync_alt_outlined,
                          'Real-Time Stock Sync',
                          'Stock deducted on offline billing counters will auto-update on Meesho to prevent out-of-stock orders.',
                        ),
                        const SizedBox(height: 10),
                        _buildFeatureRow(
                          Icons.verified_user_outlined,
                          'Zero Developer Key Setup',
                          'Simply use your existing Supplier ID and registered phone number to establish a verified multi-channel handshake.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.pink.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(description, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

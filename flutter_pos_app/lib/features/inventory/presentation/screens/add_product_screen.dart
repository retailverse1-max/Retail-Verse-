import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/navigation/role_nav.dart';
import '../../../../core/navigation/role_route_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/services/ai_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../pos/providers/product_providers.dart';
import '../../data/models/category_entity.dart';
import '../../data/models/category.dart' as inv;
import '../../providers/category_providers.dart';
import '../../data/models/product.dart';

/// Add Product Screen - Professional product creation form with AI integration
class AddProductScreen extends ConsumerStatefulWidget {
  final inv.Category? category;

  const AddProductScreen({super.key, this.category});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  // Controllers for form fields
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _brandController = TextEditingController();
  final _locationController = TextEditingController();
  final _reorderLevelController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Selected values
  String? _selectedCategoryId;
  String _selectedUnit = 'pcs';
  File? _productImage;
  bool _isScanning = false;
  String? _scanError;
  AIScanResult? _aiSuggestion;

  // Get selected category object from ID
  CategoryEntity? get _selectedCategory {
    if (_selectedCategoryId == null) return null;
    try {
      return _categories.firstWhere((c) => c.id == _selectedCategoryId);
    } catch (e) {
      return null; // Category not found in list
    }
  }

  // Available categories - loaded from database
  List<CategoryEntity> _categories = [];
  bool _isLoadingCategories = false;

  bool _isSaving = false;

  // Unit options
  final List<String> _unitOptions = [
    'pcs', // Pieces
    'kg', // Kilograms
    'g', // Grams
    'lb', // Pounds
    'oz', // Ounces
    'litre', // Liters
    'ml', // Milliliters
    'box', // Box
    'pack', // Pack
    'set', // Set
    'roll', // Roll
    'meter', // Meter
    'foot', // Foot
    'inch', // Inch
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();

    if (widget.category != null) {
      _selectedCategoryId = widget.category!.id;
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final categories = await ref.read(categoryRepositoryProvider).getAllCategories();

      setState(() {
        _categories = categories;
        _isLoadingCategories = false;

        if (widget.category != null) {
          try {
            final match = _categories.firstWhere(
              (c) =>
                  c.id == widget.category!.id ||
                  c.name.toLowerCase() ==
                      widget.category!.name.toLowerCase(),
            );
            _selectedCategoryId = match.id;
          } catch (_) {
            _selectedCategoryId = _categories.isNotEmpty
                ? _categories.first.id
                : widget.category!.id;
          }
        }

        debugPrint(
          '✅ Loaded ${_categories.length} categories for product form',
        );
      });
    } catch (e) {
      setState(() {
        _isLoadingCategories = false;
      });

      debugPrint('❌ Error loading categories: $e');

      // Fallback to empty list - user can still type category name
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
            content: Text('Failed to load categories: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _brandController.dispose();
    _locationController.dispose();
    _reorderLevelController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<bool> _ensureImagePickerPermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
      }
      if (status.isGranted) return true;
      if (!mounted) return false;
      final blocked = status.isPermanentlyDenied;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
          content: Text(
            blocked
                ? 'Camera is turned off for this app. Enable it in Settings to take photos.'
                : 'Camera permission is required to take a photo.',
          ),
          action: blocked
              ? SnackBarAction(
                  label: 'Settings',
                  onPressed: openAppSettings,
                )
              : null,
        ),
      );
      return false;
    }

    if (Platform.isAndroid) {
      final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
      if (sdk >= 33) {
        final r = await Permission.photos.request();
        if (r.isGranted || r.isLimited) return true;
      } else {
        final r = await Permission.storage.request();
        if (r.isGranted) return true;
      }
    } else {
      final r = await Permission.photos.request();
      if (r.isGranted || r.isLimited) return true;
    }

    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
        content: const Text(
          'Photo access is required to choose an image from the gallery.',
        ),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: openAppSettings,
        ),
      ),
    );
    return false;
  }

  /// After closing the bottom sheet, wait briefly so the route transition
  /// does not block launching the camera / photo picker on some devices.
  void _schedulePickImage(BuildContext sheetContext, ImageSource source) {
    Navigator.pop(sheetContext);
    Future<void>.delayed(const Duration(milliseconds: 220), () async {
      if (!mounted) return;
      await _pickImage(source);
    });
  }

  /// Pick image from camera or gallery
  Future<void> _pickImage(ImageSource source) async {
    try {
      final allowed = await _ensureImagePickerPermission(source);
      if (!allowed) return;

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (!mounted) return;
      if (image == null) return;

      CroppedFile? croppedFile;
      try {
        croppedFile = await ImageCropper().cropImage(
          sourcePath: image.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Product Image',
              toolbarColor: AppColors.primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: 'Crop Product Image',
              resetAspectRatioEnabled: true,
            ),
          ],
        );
      } catch (e, st) {
        debugPrint('Image crop failed (using original photo): $e\n$st');
      }

      if (!mounted) return;

      final path = croppedFile?.path ?? image.path;
      setState(() {
        _productImage = File(path);
        _scanError = null;
        _aiSuggestion = null; // Reset suggestion on new image
      });
    } catch (e, st) {
      debugPrint('Error picking image: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
          content: Text('Error picking image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Show image source selection dialog
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24.0), // Extra padding to avoid nav bar overlap
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text('Take Photo'),
                  onTap: () => _schedulePickImage(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text('Choose from Gallery'),
                  onTap: () => _schedulePickImage(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Scan image with AI to auto-fill product details
  Future<void> _scanWithAI() async {
    if (_productImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: 120, left: 16, right: 16),
          content: Text('Please select an image first'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _scanError = null;
    });

    try {
      // Call AI service to analyze image
      final result = await AIService.analyzeProductImage(
        imageFile: _productImage!,
        categoryContext: _selectedCategory?.name,
      );

      // Auto-fill form fields with AI results immediately
      setState(() {
        _aiSuggestion = result;
        _isScanning = false;

        if (_nameController.text.isEmpty || _nameController.text == 'New Product') {
          _nameController.text = result.productName;
        }
        if (_descriptionController.text.isEmpty) {
          _descriptionController.text = result.description;
        }
        if (_priceController.text.isEmpty && result.priceEstimate != null) {
          _priceController.text = result.priceEstimate!.toStringAsFixed(2);
        }
        if (result.suggestedCategory != null && result.suggestedCategory!.isNotEmpty) {
          try {
            final matchingCategory = _categories.firstWhere(
              (c) =>
                  c.name.toLowerCase() ==
                  result.suggestedCategory!.toLowerCase(),
              orElse: () => _selectedCategory ?? _categories.first,
            );
            _selectedCategoryId = matchingCategory.id;
          } catch (_) {}
        }
      });

      // Show success feedback
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'AI scan complete! (${(result.confidence * 100).toStringAsFixed(0)}% confidence)',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );

      debugPrint('✅ AI Scan Result: ${result.productName}');
      debugPrint('📝 Description: ${result.description}');
      debugPrint('📂 Category: ${result.suggestedCategory}');
      debugPrint(
        '🎯 Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%',
      );
    } catch (e) {
      setState(() {
        _isScanning = false;
        _scanError = 'Failed to analyze image. Please try again.';
      });

      // Parse exception into a clean, premium user-friendly message
      String userFriendlyError = e.toString();
      if (userFriendlyError.contains('Exception:')) {
        userFriendlyError = userFriendlyError.split('Exception:').last.trim();
      }
      
      if (userFriendlyError.contains('All Gemini models failed')) {
        userFriendlyError = 'AI is temporarily unable to process this image. Please ensure the photo is clear and try again.';
      } else if (userFriendlyError.contains('SocketException') || userFriendlyError.contains('internet connection')) {
        userFriendlyError = 'No internet connection. Please check your network and try again.';
      } else if (userFriendlyError.contains('timeout')) {
        userFriendlyError = 'AI scan timed out. The server is starting up, please try again in a few seconds.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
          content: Text(userFriendlyError),
          backgroundColor: AppColors.error,
        ),
      );

      debugPrint('❌ AI Scan Error: $e');
    }
  }

  /// Validate and save product (POST /api/products)
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    final sku = _skuController.text.trim().isEmpty
        ? 'AUTO-${DateTime.now().millisecondsSinceEpoch}'
        : _skuController.text.trim();
    final categoryLabel =
        _selectedCategory?.name ?? widget.category?.name ?? '';

    String? imageBase64;
    if (_productImage != null) {
      try {
        final bytes = await _productImage!.readAsBytes();
        final pathLower = _productImage!.path.toLowerCase();
        var mime = 'image/jpeg';
        if (pathLower.endsWith('.png')) {
          mime = 'image/png';
        } else if (pathLower.endsWith('.webp')) {
          mime = 'image/webp';
        }
        imageBase64 = 'data:$mime;base64,${base64Encode(bytes)}';
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
              content: Text('Could not read product image: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        setState(() => _isSaving = false);
        return;
      }
    }

    try {
      final desc = _descriptionController.text.trim();
      final created = await ref.read(productRepositoryProvider).createProduct(
            name: _nameController.text.trim(),
            sku: sku,
            price: double.parse(_priceController.text.trim()),
            cost: 0,
            stock: int.parse(_quantityController.text.trim()),
            barcode: _brandController.text.trim(),
            category: categoryLabel,
            imageBase64: imageBase64,
            description: desc.isEmpty ? null : desc,
          );

      final legacy = Product(
        id: created.id,
        name: created.name,
        sku: created.sku,
        imageUrl: created.imageUrl ?? '',
        quantity: created.stock,
        price: created.price,
        description: _descriptionController.text.trim(),
        categoryId: _selectedCategory?.id ?? widget.category?.id ?? '',
        categoryName: categoryLabel.isNotEmpty ? categoryLabel : created.category,
      );

      if (!mounted) return;
      ref.invalidate(productsProvider);
      if (categoryLabel.isNotEmpty) {
        ref.invalidate(categoryProductsProvider(categoryLabel));
        // Update local category product count if a category was selected
        final selectedCatId = _selectedCategory?.id ?? widget.category?.id;
        if (selectedCatId != null && selectedCatId.isNotEmpty) {
          ref.read(categoryRepositoryProvider).localService.incrementProductCount(selectedCatId);
        }
      }
      Navigator.of(context).pop(legacy);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: 120, left: 16, right: 16),
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Product saved successfully!',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
            content: Text('Save failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = effectiveUserRole(ref.watch(authProvider).user);
    if (role != 'admin' && role != 'super_admin' && role != 'inventory_manager') {
      return RoleAccessDeniedView(onGoHome: () => context.go('/dashboard'));
    }

    final isTablet = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.primary,
            size: 28,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Add New Product',
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.textSecondary,
            ),
            label: Text(
              'Cancel',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image Section
                _buildImageSection(),

                if (_aiSuggestion != null) ...[
                  const SizedBox(height: 24),
                  _buildAIPreviewCard(),
                ],

                const SizedBox(height: 24),

                // Basic Information Section
                Text(
                  'Basic Information',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Product Name
                _buildProductNameField(),

                const SizedBox(height: 16),

                // SKU
                _buildSKUField(),

                const SizedBox(height: 16),

                // Category & Unit Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildCategoryDropdown()),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: _buildUnitDropdown()),
                  ],
                ),

                const SizedBox(height: 24),

                // Pricing & Stock Section
                Text(
                  'Pricing & Stock',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Price & Quantity Row
                Row(
                  children: [
                    Expanded(child: _buildPriceField()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildQuantityField()),
                  ],
                ),

                const SizedBox(height: 24),

                // Description Section
                Text(
                  'Description',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                _buildDescriptionField(),

                const SizedBox(height: 24),

                // Additional Information Section
                Text(
                  'Additional Information',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Brand
                _buildBrandField(),

                const SizedBox(height: 16),

                // Location & Reorder Level Row
                Row(
                  children: [
                    Expanded(child: _buildLocationField()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildReorderLevelField()),
                  ],
                ),

                const SizedBox(height: 32),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_isScanning || _isSaving) ? null : _saveProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isScanning
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.save_rounded),
                              const SizedBox(width: 8),
                              Text(
                                'Save Product',
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Info Note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.info.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.info,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Upload a product image and use AI Scan to auto-fill details',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // BUILD WIDGETS - Form Sections
  // ============================================================================

  Widget _buildImageSection() {
    return Column(
      children: [
        // Image Preview / Upload Box
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showImageSourceDialog,
          child: Container(
            width: double.infinity,
            height: 250,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _productImage != null
                    ? AppColors.success
                    : AppColors.border,
                width: 2,
              ),
            ),
            child: _productImage == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tap to add product image',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Camera or Gallery',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  )
                : Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          _productImage!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _productImage = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ),
                      if (_isScanning)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Analyzing with AI...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 12),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isScanning ? null : _showImageSourceDialog,
                icon: const Icon(Icons.photo_camera_rounded, size: 20),
                label: const Text('Add Image'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isScanning || _productImage == null
                    ? null
                    : _scanWithAI,
                icon: _isScanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 20),
                label: Text(_isScanning ? 'Scanning...' : 'AI Scan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _productImage == null
                      ? AppColors.textTertiary
                      : AppColors.primary,
                  side: BorderSide(
                    color: _productImage == null
                        ? AppColors.border
                        : AppColors.primary,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),

        if (_scanError != null) ...[
          const SizedBox(height: 8),
          Text(
            _scanError!,
            style: AppTypography.bodySmall.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }

  void _applyAISuggestion() {
    if (_aiSuggestion == null) return;
    
    setState(() {
      _nameController.text = _aiSuggestion!.productName;
      _descriptionController.text = _aiSuggestion!.description;

      if (_aiSuggestion!.priceEstimate != null) {
        _priceController.text = _aiSuggestion!.priceEstimate.toString();
      }

      if (_aiSuggestion!.suggestedCategory != null) {
        try {
          final matchingCategory = _categories.firstWhere(
            (c) =>
                c.name.toLowerCase() ==
                _aiSuggestion!.suggestedCategory!.toLowerCase(),
            orElse: () => _selectedCategory ?? _categories.first,
          );
          _selectedCategoryId = matchingCategory.id;
        } catch (e) {
          // Category not found
        }
      }

      _aiSuggestion = null; // Clear suggestion after applying
    });
  }

  Widget _buildAIPreviewCard() {
    final ai = _aiSuggestion!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'AI Analysis Results',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(ai.confidence * 100).toInt()}% match',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPreviewRow('Name:', ai.productName),
          const SizedBox(height: 8),
          _buildPreviewRow('Category:', ai.suggestedCategory ?? 'N/A'),
          const SizedBox(height: 8),
          if (ai.priceEstimate != null) ...[
            _buildPreviewRow('Price Estimate:', '\$${ai.priceEstimate}'),
            const SizedBox(height: 8),
          ],
          if (ai.tags.isNotEmpty) ...[
            _buildPreviewRow('Tags:', ai.tags.join(', ')),
            const SizedBox(height: 8),
          ],
          const Text(
            'Description:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            ai.description,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _applyAISuggestion,
              icon: const Icon(Icons.check),
              label: const Text('Apply Suggestions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
          ),
        ),
      ],
    );
  }
  Widget _buildProductNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: 'Product Name *',
        hintText: 'Enter product name',
        prefixIcon: const Icon(Icons.inventory_2_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppColors.background,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Product name is required';
        }
        return null;
      },
    );
  }

  Widget _buildSKUField() {
    return TextFormField(
      controller: _skuController,
      decoration: InputDecoration(
        labelText: 'SKU (Optional)',
        hintText: 'Auto-generated if left empty',
        prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppColors.background,
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    // Remove duplicates by ID to prevent assertion errors
    final seenIds = <String>{};
    final uniqueCategories = <CategoryEntity>[];
    for (final category in _categories) {
      if (seenIds.add(category.id)) {
        uniqueCategories.add(category);
      }
    }

    if (_isLoadingCategories) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _selectedCategoryId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Category *',
              prefixIcon: const Icon(Icons.category_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.background,
            ),
            hint: Text(
              _categories.isEmpty
                  ? 'Add categories first'
                  : 'Select a category',
              overflow: TextOverflow.ellipsis,
            ),
            items: uniqueCategories.map((category) {
              return DropdownMenuItem<String>(
                value: category.id,
                child: Text(category.name, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: _isScanning || _categories.isEmpty
                ? null
                : (value) {
                    setState(() {
                      _selectedCategoryId = value;
                    });
                  },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _loadCategories,
          tooltip: 'Refresh Categories',
          icon: const Icon(Icons.refresh_rounded),
          color: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildUnitDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedUnit,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Unit',
        prefixIcon: const Icon(Icons.straighten_rounded),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppColors.background,
      ),
      items: _unitOptions.map((unit) {
        return DropdownMenuItem(
          value: unit, 
          child: Text(unit, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: _isScanning
          ? null
          : (value) {
              setState(() {
                _selectedUnit = value!;
              });
            },
    );
  }

  Widget _buildPriceField() {
    return TextFormField(
      controller: _priceController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Price *',
        hintText: '0.00',
        prefixIcon: const Icon(Icons.attach_money),
        prefixText: '\$ ',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppColors.background,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Required';
        }
        if (double.tryParse(value) == null) {
          return 'Invalid number';
        }
        return null;
      },
    );
  }

  Widget _buildQuantityField() {
    return TextFormField(
      controller: _quantityController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Quantity *',
        hintText: '0',
        prefixIcon: const Icon(Icons.inventory_2_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppColors.background,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Required';
        }
        if (int.tryParse(value) == null) {
          return 'Invalid number';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 5,
      minLines: 4,
      decoration: InputDecoration(
        labelText: 'Description',
        hintText: 'AI will auto-fill this after scanning, or enter manually...',
        alignLabelWithHint: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppColors.background,
      ),
    );
  }

  Widget _buildBrandField() {
    return TextFormField(
      controller: _brandController,
      decoration: InputDecoration(
        labelText: 'Brand (Optional)',
        hintText: 'e.g., Samsung, Apple, etc.',
        prefixIcon: const Icon(Icons.business_rounded),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppColors.background,
      ),
    );
  }

  Widget _buildLocationField() {
    return TextFormField(
      controller: _locationController,
      decoration: InputDecoration(
        labelText: 'Warehouse Location (Optional)',
        hintText: 'e.g., A-12-B',
        prefixIcon: const Icon(Icons.location_on_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppColors.background,
      ),
    );
  }

  Widget _buildReorderLevelField() {
    return TextFormField(
      controller: _reorderLevelController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Reorder Level (Optional)',
        hintText: '10',
        prefixIcon: const Icon(Icons.warning_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppColors.background,
      ),
    );
  }
}

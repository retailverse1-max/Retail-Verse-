import '../../core/utils/num_parse.dart';

/// Resolves `id` / `_id` from API or MongoDB-style `{ "\$oid": "..." }` JSON.
String _parseProductId(Map<String, dynamic> json) {
  final direct = json['id'];
  if (direct != null && direct is! Map) {
    final s = direct.toString().trim();
    if (s.isNotEmpty && s != 'null') return s;
  }
  if (direct is Map) {
    final oid = direct[r'$oid'];
    if (oid is String && oid.isNotEmpty) return oid;
  }
  final id = json['_id'];
  if (id != null && id is! Map) {
    final s = id.toString().trim();
    if (s.isNotEmpty && s != 'null') return s;
  }
  if (id is Map) {
    final oid = id[r'$oid'];
    if (oid is String && oid.isNotEmpty) return oid;
  }
  return '';
}

/// Handles ISO strings, millis, and Mongo extended JSON `{ "\$date": ... }`.
DateTime _coerceDateTime(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is DateTime) return v;
  if (v is int) {
    return DateTime.fromMillisecondsSinceEpoch(v);
  }
  if (v is String) {
    final t = v.trim();
    if (t.isEmpty) return DateTime.now();
    return DateTime.tryParse(t) ?? DateTime.now();
  }
  if (v is Map) {
    final m = Map<String, dynamic>.from(v);
    final d = m[r'$date'];
    if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
    if (d is int) return DateTime.fromMillisecondsSinceEpoch(d);
  }
  return DateTime.now();
}

/// Product model representing items in inventory
class Product {
  final String id;
  final String name;
  final String sku;
  final String category;
  final double price;
  final double cost;
  final int stock;
  final int reorderLevel;
  final String unit;
  final String? barcode;
  final String? imageUrl;
  /// Optional product physical dimensions (e.g., "10 x 5 x 2 cm").
  final String? dimensions;
  /// Optional long text from API (`description` / `desc`).
  final String? description;
  final bool isActive;
  final bool isFlipkartSynced;
  final List<String> marketplaces;
  final double taxRate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.price,
    required this.cost,
    required this.stock,
    required this.reorderLevel,
    required this.unit,
    this.barcode,
    this.imageUrl,
    this.dimensions,
    this.description,
    this.isActive = true,
    this.isFlipkartSynced = false,
    this.marketplaces = const [],
    this.taxRate = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Tax rate getters: percentage (e.g. 18.0) and decimal fraction (e.g. 0.18)
  double get taxRateDecimal => taxRate > 1.0 ? taxRate / 100.0 : taxRate;
  double get taxRatePercent => taxRate > 1.0 ? taxRate : taxRate * 100.0;

  /// Marketplace Active Getters
  bool get isFlipkartActive => marketplaces.contains('flipkart') || isFlipkartSynced;
  bool get isMeeshoActive => marketplaces.contains('meesho');
  bool get isShopifyActive => marketplaces.contains('shopify');
  bool get isZomatoActive => marketplaces.contains('zomato');
  bool get isSwiggyActive => marketplaces.contains('swiggy');
  bool get isEatClubActive => marketplaces.contains('eatclub') || marketplaces.contains('eat club');
  bool get isWooCommerceActive => marketplaces.contains('woocommerce') || marketplaces.contains('wpkart');
  bool get isAmazonActive => marketplaces.contains('amazon');

  /// Check if product is in stock
  bool get isInStock => stock > 0;

  /// Check if product has low stock
  bool get isLowStock => stock <= reorderLevel && stock > 0;

  /// Check if product is out of stock
  bool get isOutOfStock => stock == 0;

  /// Get stock status label
  String get stockStatus {
    if (isOutOfStock) return 'Out of Stock';
    if (isLowStock) return 'Low Stock';
    return 'In Stock';
  }

  /// Calculate total value
  double get totalValue => price * stock;

  /// Copy with method for immutability
  Product copyWith({
    String? id,
    String? name,
    String? sku,
    String? category,
    double? price,
    double? cost,
    int? stock,
    int? reorderLevel,
    String? unit,
    String? barcode,
    String? imageUrl,
    String? dimensions,
    String? description,
    bool? isActive,
    bool? isFlipkartSynced,
    List<String>? marketplaces,
    double? taxRate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stock: stock ?? this.stock,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      unit: unit ?? this.unit,
      barcode: barcode ?? this.barcode,
      imageUrl: imageUrl ?? this.imageUrl,
      dimensions: dimensions ?? this.dimensions,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      isFlipkartSynced: isFlipkartSynced ?? this.isFlipkartSynced,
      marketplaces: marketplaces ?? this.marketplaces,
      taxRate: taxRate ?? this.taxRate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to JSON (for API / MongoDB sync)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'category': category,
      'price': price,
      'cost': cost,
      'stock': stock,
      'reorderLevel': reorderLevel,
      'unit': unit,
      'barcode': barcode,
      'imageUrl': imageUrl,
      if (dimensions != null && dimensions!.isNotEmpty) 'dimensions': dimensions,
      'description': description,
      'isActive': isActive,
      'isFlipkartSynced': isFlipkartSynced,
      'marketplaces': marketplaces,
      'taxRate': taxRate,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON (for API / MongoDB sync)
  factory Product.fromJson(Map<String, dynamic> json) {
    final parsedMarketplaces = (json['marketplaces'] is List)
        ? (json['marketplaces'] as List).map((e) => e.toString().toLowerCase().trim()).toList()
        : <String>[
            if (json['isFlipkartSynced'] == true) 'flipkart',
          ];

    return Product(
      id: _parseProductId(json),
      name: json['name']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      price: parseMoney(json['price']),
      cost: parseMoney(json['cost']),
      stock: parseIntLoose(json['stock']),
      reorderLevel: parseIntLoose(
        json['reorderLevel'] ?? json['reorder_level'],
      ),
      unit: json['unit']?.toString() ?? 'pcs',
      barcode: json['barcode']?.toString(),
      imageUrl: _pickImageUrl(json),
      dimensions: json['dimensions']?.toString(),
      description: _pickDescription(json),
      isActive: json['isActive'] == null ? true : (json['isActive'] as bool? ?? true),
      isFlipkartSynced: json['isFlipkartSynced'] == true || parsedMarketplaces.contains('flipkart'),
      marketplaces: parsedMarketplaces,
      taxRate: (json['taxRate'] as num?)?.toDouble() ?? (json['gstRate'] as num?)?.toDouble() ?? 0.0,
      createdAt: _coerceDateTime(json['createdAt'] ?? json['created_at']),
      updatedAt: _coerceDateTime(json['updatedAt'] ?? json['updated_at']),
    );
  }

  static Product? tryFromJson(Map<String, dynamic> json) {
    try {
      return Product.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Skips invalid rows so one bad document does not empty the whole list.
  static List<Product> listFromJson(dynamic data) {
    if (data is! List) return [];
    final out = <Product>[];
    for (final e in data) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final p = tryFromJson(m);
      if (p != null) out.add(p);
    }
    return out;
  }

  /// Convert to Map (for SQLite local DB)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'category': category,
      'price': price,
      'cost': cost,
      'stock': stock,
      'reorder_level': reorderLevel,
      'unit': unit,
      'barcode': barcode,
      'image_url': imageUrl,
      'description': description,
      'tax_rate': taxRate,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': 0,
    };
  }

  /// Create from Map (for SQLite local DB)
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      sku: map['sku']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      price: parseMoney(map['price']),
      cost: parseMoney(map['cost']),
      stock: parseIntLoose(map['stock']),
      reorderLevel: parseIntLoose(map['reorder_level']),
      unit: map['unit']?.toString() ?? 'pcs',
      barcode: map['barcode']?.toString(),
      imageUrl: _pickImageUrlFromMap(map),
      description: () {
        final d = map['description']?.toString().trim();
        if (d == null || d.isEmpty || d == 'null') return null;
        return d;
      }(),
      taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0.0,
      isActive: map['is_active'] == null ? true : (map['is_active'] == 1),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : DateTime.now(),
    );
  }

  @override
  String toString() =>
      'Product(id: $id, name: $name, sku: $sku, price: $price, stock: $stock)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

String? _pickDescription(Map<String, dynamic> json) {
  for (final key in ['description', 'desc', 'details', 'long_description']) {
    final v = json[key];
    if (v is String) {
      final s = v.trim();
      if (s.isNotEmpty && s != 'null') return s;
    }
  }
  return null;
}

/// String, list (first usable entry), or nested `{ "url": "..." }` / WooCommerce-style objects.
String? _coerceImageUrlValue(dynamic v) {
  if (v == null) return null;
  if (v is String) {
    final s = v.trim();
    if (s.isNotEmpty && s != 'null') return s;
    return null;
  }
  if (v is List) {
    for (final el in v) {
      final s = _coerceImageUrlValue(el);
      if (s != null) return s;
    }
    return null;
  }
  if (v is Map) {
    final m = Map<String, dynamic>.from(v);
    for (final key in [
      'src',
      'url',
      'secure_url',
      'source_url',
      'path',
      'link',
      'large',
      'medium',
      'thumbnail',
    ]) {
      final inner = m[key];
      if (inner is String) {
        final s = inner.trim();
        if (s.isNotEmpty && s != 'null') return s;
      }
    }
  }
  return null;
}

bool _looksLikeImageReference(String s) {
  final t = s.trim();
  if (t.isEmpty || t == 'null') return false;
  if (t.startsWith('data:image')) return true;
  if (t.startsWith('http://') || t.startsWith('https://')) return true;
  if (t.contains('/uploads/')) return true;
  return RegExp(r'\.(png|jpe?g|webp|gif|bmp)(\?|#|$)', caseSensitive: false)
      .hasMatch(t);
}

String? _pickImageUrl(Map<String, dynamic> json) {
  for (final key in [
    'imageUrl',
    'image_url',
    'image',
    'images',
    'productImages',
    'media',
    'thumbnail',
    'thumbnailUrl',
    'thumbnail_url',
    'picture',
    'photo',
    'featuredImage',
    'featured_image',
    'coverImage',
    'cover_image',
    'img',
    'path',
    'filepath',
    'file_path',
    'productImage',
    'product_image',
    'attachment_url',
    'src',
    'mainImage',
    'main_image',
  ]) {
    final s = _coerceImageUrlValue(json[key]);
    if (s != null) return s;
  }
  // Legacy / odd exports: any string field that clearly holds a path or URL.
  for (final e in json.entries) {
    final v = e.value;
    if (v is! String) continue;
    if (_looksLikeImageReference(v)) return v.trim();
  }
  return null;
}

String? _pickImageUrlFromMap(Map<String, dynamic> map) {
  for (final key in [
    'image_url',
    'imageUrl',
    'image',
    'images',
    'thumbnail',
    'thumbnail_url',
    'picture',
    'photo',
  ]) {
    final s = _coerceImageUrlValue(map[key]);
    if (s != null) return s;
  }
  return null;
}
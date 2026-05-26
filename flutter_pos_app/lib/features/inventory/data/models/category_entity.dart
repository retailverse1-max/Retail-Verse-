import 'package:sqflite/sqflite.dart';

/// Category entity for SQLite database
class CategoryEntity {
  final String id;
  final String name;
  final String subtitle;
  final String imagePath;
  final int productCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  CategoryEntity({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.imagePath,
    required this.productCount,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  /// Convert to Map (for SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'subtitle': subtitle,
      'image_path': imagePath,
      'product_count': productCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  /// Create from Map (for SQLite)
  factory CategoryEntity.fromMap(Map<String, dynamic> map) {
    return CategoryEntity(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      subtitle: map['subtitle'] ?? '',
      imagePath: map['image_path'] ?? '',
      productCount: map['product_count'] ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : DateTime.now(),
      isDeleted: (map['is_deleted'] ?? 0) == 1,
    );
  }

  /// Copy with method for immutability
  CategoryEntity copyWith({
    String? id,
    String? name,
    String? subtitle,
    String? imagePath,
    int? productCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return CategoryEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      imagePath: imagePath ?? this.imagePath,
      productCount: productCount ?? this.productCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  String toString() =>
      'CategoryEntity(id: $id, name: $name, productCount: $productCount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

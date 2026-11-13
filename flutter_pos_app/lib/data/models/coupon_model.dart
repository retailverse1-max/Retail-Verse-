class CouponModel {
  final String? id;
  final String code;
  final String description;
  final String discountType; // 'flat' or 'percentage'
  final double discountValue;
  final double? maxDiscountAmount;
  final double minOrderAmount;
  final bool isActive;

  CouponModel({
    this.id,
    required this.code,
    this.description = '',
    this.discountType = 'flat',
    required this.discountValue,
    this.maxDiscountAmount,
    this.minOrderAmount = 0.0,
    this.isActive = true,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      code: (json['code'] ?? '').toString().toUpperCase(),
      description: (json['description'] ?? '').toString(),
      discountType: (json['discountType'] ?? 'flat').toString(),
      discountValue: (json['discountValue'] is num)
          ? (json['discountValue'] as num).toDouble()
          : double.tryParse(json['discountValue']?.toString() ?? '0') ?? 0.0,
      maxDiscountAmount: json['maxDiscountAmount'] != null
          ? ((json['maxDiscountAmount'] is num)
              ? (json['maxDiscountAmount'] as num).toDouble()
              : double.tryParse(json['maxDiscountAmount']?.toString() ?? ''))
          : null,
      minOrderAmount: (json['minOrderAmount'] is num)
          ? (json['minOrderAmount'] as num).toDouble()
          : double.tryParse(json['minOrderAmount']?.toString() ?? '0') ?? 0.0,
      isActive: json['isActive'] == null ? true : json['isActive'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'code': code,
      'description': description,
      'discountType': discountType,
      'discountValue': discountValue,
      'maxDiscountAmount': maxDiscountAmount,
      'minOrderAmount': minOrderAmount,
      'isActive': isActive,
    };
  }

  String get discountSummary {
    if (discountType == 'percentage') {
      final maxStr = maxDiscountAmount != null ? ' (Max ₹${maxDiscountAmount!.toStringAsFixed(0)})' : '';
      return '${discountValue.toStringAsFixed(0)}% OFF$maxStr';
    }
    return 'Flat ₹${discountValue.toStringAsFixed(0)} OFF';
  }
}

class CouponValidationResult {
  final bool isValid;
  final String message;
  final String? code;
  final double calculatedDiscount;
  final double minOrderAmount;
  final String? description;

  CouponValidationResult({
    required this.isValid,
    required this.message,
    this.code,
    this.calculatedDiscount = 0.0,
    this.minOrderAmount = 0.0,
    this.description,
  });

  factory CouponValidationResult.fromJson(Map<String, dynamic> json) {
    final coupon = json['coupon'] as Map<String, dynamic>?;
    return CouponValidationResult(
      isValid: json['valid'] == true || json['success'] == true,
      message: (json['message'] ?? '').toString(),
      code: coupon?['code']?.toString(),
      calculatedDiscount: coupon?['calculatedDiscount'] != null
          ? ((coupon!['calculatedDiscount'] is num)
              ? (coupon['calculatedDiscount'] as num).toDouble()
              : double.tryParse(coupon['calculatedDiscount']?.toString() ?? '0') ?? 0.0)
          : 0.0,
      minOrderAmount: coupon?['minOrderAmount'] != null
          ? ((coupon!['minOrderAmount'] is num)
              ? (coupon['minOrderAmount'] as num).toDouble()
              : double.tryParse(coupon['minOrderAmount']?.toString() ?? '0') ?? 0.0)
          : 0.0,
      description: coupon?['description']?.toString(),
    );
  }
}

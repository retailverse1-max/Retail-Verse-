import 'package:flutter/material.dart';

class RecentActivityModel {
  final String title;
  final String subtitle;
  final double amount;
  final String status;
  final String type;
  final DateTime? createdAt;

  RecentActivityModel({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.status,
    required this.type,
    this.createdAt,
  });

  factory RecentActivityModel.fromJson(Map<String, dynamic> json) {
    return RecentActivityModel(
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? 'Completed',
      type: json['type']?.toString() ?? 'sale',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }

  IconData get icon {
    switch (type) {
      case 'sale':
        return Icons.point_of_sale_rounded;
      case 'order':
        return Icons.receipt_long_rounded;
      case 'customer':
        return Icons.people_alt_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }
}

import 'package:intl/intl.dart';

class SupportTicket {
  final int id;
  final String subject;
  final String status;
  final String priority;
  final DateTime createdAt;
  final String? requesterName;
  final String? requesterEmail;
  final String? orderId;

  SupportTicket({
    required this.id,
    required this.subject,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.requesterName,
    this.requesterEmail,
    this.orderId,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    // Extract Order ID if present in subject or tags (Zendesk specific)
    String? orderId;
    if (json['subject'] != null && json['subject'].toString().contains('ORD-')) {
      final match = RegExp(r'ORD-\d+').firstMatch(json['subject']);
      orderId = match?.group(0);
    }

    return SupportTicket(
      id: json['id'],
      subject: json['subject'] ?? 'No Subject',
      status: json['status'] ?? 'open',
      priority: json['priority'] ?? 'normal',
      createdAt: DateTime.parse(json['created_at']),
      requesterName: json['requester_name'] ?? 'User',
      requesterEmail: json['requester_email'] ?? '',
      orderId: orderId,
    );
  }

  String get formattedDate => DateFormat('M/d/yyyy').format(createdAt);
}

class SupportStats {
  final int total;
  final int open;
  final int resolved;
  final int pending;

  SupportStats({
    required this.total,
    required this.open,
    required this.resolved,
    required this.pending,
  });

  factory SupportStats.fromJson(Map<String, dynamic> json) {
    return SupportStats(
      total: json['total'] ?? 0,
      open: json['open'] ?? 0,
      resolved: json['resolved'] ?? 0,
      pending: json['pending'] ?? 0,
    );
  }

  factory SupportStats.empty() => SupportStats(total: 0, open: 0, resolved: 0, pending: 0);
}

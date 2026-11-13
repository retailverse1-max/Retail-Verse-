import 'package:intl/intl.dart';

class SupportTicket {
  final int id;
  final String? ticketRef;
  final String subject;
  final String status;
  final String priority;
  final DateTime createdAt;
  final String? requesterName;
  final String? requesterEmail;
  final String? orderId;
  final String? issueType;
  final String? description;

  SupportTicket({
    required this.id,
    this.ticketRef,
    required this.subject,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.requesterName,
    this.requesterEmail,
    this.orderId,
    this.issueType,
    this.description,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    // Extract Order ID if present in json or subject
    String? orderId;
    if (json['orderRef'] != null && json['orderRef'].toString().isNotEmpty) {
      orderId = json['orderRef'].toString();
    } else if (json['subject'] != null && json['subject'].toString().contains('ORD-')) {
      final match = RegExp(r'ORD-\d+').firstMatch(json['subject'].toString());
      orderId = match?.group(0);
    }

    final rawId = json['id'] ?? json['zendeskTicketId'] ?? json['ticketId'];
    int parsedId;
    if (rawId is int) {
      parsedId = rawId;
    } else if (rawId != null && int.tryParse(rawId.toString()) != null) {
      parsedId = int.parse(rawId.toString());
    } else {
      final mongoId = (json['_id'] ?? '').toString();
      parsedId = mongoId.isNotEmpty
          ? (mongoId.hashCode.abs() % 100000)
          : (DateTime.now().millisecondsSinceEpoch % 100000);
    }

    DateTime parsedDate;
    try {
      final dateStr = (json['created_at'] ?? json['createdAt'] ?? '').toString();
      parsedDate = dateStr.isNotEmpty ? DateTime.parse(dateStr) : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return SupportTicket(
      id: parsedId,
      ticketRef: (json['zendeskTicketId'] ?? json['ticketId'] ?? json['_id'] ?? parsedId).toString(),
      subject: json['subject']?.toString() ?? 'No Subject',
      status: json['status']?.toString() ?? 'open',
      priority: json['priority']?.toString() ?? 'normal',
      createdAt: parsedDate,
      requesterName: json['requester_name']?.toString() ?? json['userName']?.toString() ?? 'User',
      requesterEmail: json['requester_email']?.toString() ?? json['userEmail']?.toString() ?? json['customerEmail']?.toString() ?? '',
      orderId: orderId,
      issueType: json['issueType']?.toString() ?? 'other',
      description: json['description']?.toString() ?? json['message']?.toString() ?? '',
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

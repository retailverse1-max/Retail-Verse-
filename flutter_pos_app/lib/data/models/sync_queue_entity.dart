import 'package:uuid/uuid.dart';

/// Sync Queue Entity - Tracks operations that need to be synced to backend
enum SyncStatus { pending, syncing, synced, failed }

class SyncQueueEntity {
  final String id;
  final String entityType; // 'order', 'product', 'inventory_movement'
  final String entityId;
  final String action; // 'create', 'update', 'delete'
  final String payload; // JSON string of the data
  final DateTime createdAt;
  final SyncStatus status;
  final int retryCount;

  SyncQueueEntity({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.payload,
    required this.createdAt,
    this.status = SyncStatus.pending,
    this.retryCount = 0,
  });

  /// Convert to Map for SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'payload': payload,
      'created_at': createdAt.toIso8601String(),
      'status': _statusToString(status),
      'retry_count': retryCount,
    };
  }

  /// Create from Map (SQLite)
  factory SyncQueueEntity.fromMap(Map<String, dynamic> map) {
    return SyncQueueEntity(
      id: map['id'] ?? '',
      entityType: map['entity_type'] ?? '',
      entityId: map['entity_id'] ?? '',
      action: map['action'] ?? '',
      payload: map['payload'] ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      status: _statusFromString(map['status'] ?? 'pending'),
      retryCount: map['retry_count'] ?? 0,
    );
  }

  /// Copy with method
  SyncQueueEntity copyWith({
    String? id,
    String? entityType,
    String? entityId,
    String? action,
    String? payload,
    DateTime? createdAt,
    SyncStatus? status,
    int? retryCount,
  }) {
    return SyncQueueEntity(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      action: action ?? this.action,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  /// Generate unique ID
  static String generateId() => const Uuid().v4();

  /// Convert SyncStatus to String
  static String _statusToString(SyncStatus status) {
    switch (status) {
      case SyncStatus.pending:
        return 'pending';
      case SyncStatus.syncing:
        return 'syncing';
      case SyncStatus.synced:
        return 'synced';
      case SyncStatus.failed:
        return 'failed';
    }
  }

  /// Convert String to SyncStatus
  static SyncStatus _statusFromString(String value) {
    switch (value) {
      case 'pending':
        return SyncStatus.pending;
      case 'syncing':
        return SyncStatus.syncing;
      case 'synced':
        return SyncStatus.synced;
      case 'failed':
        return SyncStatus.failed;
      default:
        return SyncStatus.pending;
    }
  }

  @override
  String toString() =>
      'SyncQueueEntity(id: $id, entityType: $entityType, entityId: $entityId, action: $action, status: $status, retryCount: $retryCount)';
}

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/sync_queue_entity.dart';
import '../local/app_database.dart';

/// Local service for managing sync queue in SQLite database
class SyncQueueLocalService {
  /// Add item to sync queue
  Future<int> addQueueItem({
    required String entityType,
    required String entityId,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final db = await AppDatabase.database;

    final entity = SyncQueueEntity(
      id: SyncQueueEntity.generateId(),
      entityType: entityType,
      entityId: entityId,
      action: action,
      payload: jsonEncode(payload),
      createdAt: DateTime.now(),
      status: SyncStatus.pending,
    );

    return await db.insert(
      'sync_queue',
      entity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get pending sync items
  Future<List<SyncQueueEntity>> getPendingItems({int limit = 100}) async {
    final db = await AppDatabase.database;

    final result = await db.query(
      'sync_queue',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
      limit: limit,
    );

    return result.map((e) => SyncQueueEntity.fromMap(e)).toList();
  }

  /// Get all sync queue items (for debugging)
  Future<List<SyncQueueEntity>> getAllItems() async {
    final db = await AppDatabase.database;

    final result = await db.query('sync_queue', orderBy: 'created_at DESC');

    return result.map((e) => SyncQueueEntity.fromMap(e)).toList();
  }

  /// Mark item as synced
  Future<int> markAsSynced(String id) async {
    final db = await AppDatabase.database;

    return await db.update(
      'sync_queue',
      {'status': 'synced'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark item as syncing (in progress)
  Future<int> markAsSyncing(String id) async {
    final db = await AppDatabase.database;

    return await db.update(
      'sync_queue',
      {'status': 'syncing'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Increment retry count and mark as failed
  Future<int> incrementRetry(String id) async {
    final db = await AppDatabase.database;

    // Get current retry count
    final result = await db.query(
      'sync_queue',
      columns: ['retry_count'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return 0;

    final currentRetry = (result.first['retry_count'] as int?) ?? 0;
    final newRetry = currentRetry + 1;

    return await db.update(
      'sync_queue',
      {'status': 'failed', 'retry_count': newRetry},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get failed items
  Future<List<SyncQueueEntity>> getFailedItems() async {
    final db = await AppDatabase.database;

    final result = await db.query(
      'sync_queue',
      where: 'status = ?',
      whereArgs: ['failed'],
      orderBy: 'created_at DESC',
    );

    return result.map((e) => SyncQueueEntity.fromMap(e)).toList();
  }

  /// Retry failed item
  Future<int> retryFailedItem(String id) async {
    final db = await AppDatabase.database;

    return await db.update(
      'sync_queue',
      {'status': 'pending'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Remove item from queue (after successful sync or manual cleanup)
  Future<int> removeItem(String id) async {
    final db = await AppDatabase.database;
    return await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  /// Clear all synced items (cleanup)
  Future<int> clearSyncedItems() async {
    final db = await AppDatabase.database;
    return await db.delete(
      'sync_queue',
      where: 'status = ?',
      whereArgs: ['synced'],
    );
  }

  /// Get pending sync count
  Future<int> getPendingCount() async {
    final db = await AppDatabase.database;

    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM sync_queue
      WHERE status = 'pending'
    ''');

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get total sync queue count
  Future<int> getTotalCount() async {
    final db = await AppDatabase.database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sync_queue',
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Clear entire sync queue (use with caution)
  Future<void> clearQueue() async {
    final db = await AppDatabase.database;
    await db.delete('sync_queue');
  }
}

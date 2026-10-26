import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static Database? _database;
  static const int _dbVersion = 6; // v6: added tax_rate column to products

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pos_app.db');
    return _database!;
  }

  static Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB, // Added for migrations
    );
  }

  /// Upgrade database schema
  static Future<void> _upgradeDB(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    debugPrint('🔄 Upgrading database from version $oldVersion to $newVersion');

    if (oldVersion < 2) {
      // Add categories table in version 2
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS categories(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            subtitle TEXT,
            image_path TEXT,
            product_count INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_deleted INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_categories_is_deleted ON categories(is_deleted)
        ''');

        debugPrint('✅ Categories table added successfully');
      } catch (e) {
        debugPrint('❌ Error adding categories table: $e');
        rethrow;
      }
    }

    if (oldVersion < 4) {
      // Add description and is_active columns to products table
      try {
        await db.execute('ALTER TABLE products ADD COLUMN description TEXT;');
        await db.execute('ALTER TABLE products ADD COLUMN is_active INTEGER DEFAULT 1;');
        debugPrint('✅ Products table columns added successfully');
      } catch (e) {
        debugPrint('❌ Error updating products table: $e');
        // ignore if columns already exist
      }
    }

    if (oldVersion < 5) {
      // Add discount and tax columns to orders table
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN discount REAL DEFAULT 0.0;');
        await db.execute('ALTER TABLE orders ADD COLUMN tax REAL DEFAULT 0.0;');
        debugPrint('✅ Orders table columns (discount, tax) added successfully');
      } catch (e) {
        debugPrint('❌ Error updating orders table: $e');
      }
    }

    if (oldVersion < 6) {
      // Add tax_rate column to products table
      try {
        await db.execute('ALTER TABLE products ADD COLUMN tax_rate REAL DEFAULT 0.0;');
        debugPrint('✅ Products table column (tax_rate) added successfully');
      } catch (e) {
        debugPrint('❌ Error adding tax_rate to products table: $e');
        // ignore if column already exists
      }
    }
  }

  /// Create database tables
  static Future<void> _createDB(Database db, int version) async {
    // PRODUCTS TABLE - matches Product model fields
    await db.execute('''
      CREATE TABLE products(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sku TEXT NOT NULL,
        category TEXT NOT NULL,
        price REAL NOT NULL,
        cost REAL NOT NULL,
        stock INTEGER NOT NULL,
        reorder_level INTEGER NOT NULL,
        unit TEXT NOT NULL,
        barcode TEXT,
        image_url TEXT,
        description TEXT,
        tax_rate REAL DEFAULT 0.0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    // CATEGORIES TABLE - New table for category persistence
    await db.execute('''
      CREATE TABLE categories(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        subtitle TEXT,
        image_path TEXT,
        product_count INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    // ORDERS TABLE - matches OrderEntity fields
    await db.execute('''
      CREATE TABLE orders(
        id TEXT PRIMARY KEY,
        customer_name TEXT,
        total_amount REAL NOT NULL,
        discount REAL DEFAULT 0.0,
        tax REAL DEFAULT 0.0,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    // ORDER ITEMS TABLE
    await db.execute('''
      CREATE TABLE order_items(
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL REFERENCES orders(id),
        product_id TEXT NOT NULL REFERENCES products(id),
        quantity INTEGER NOT NULL,
        price REAL NOT NULL
      )
    ''');

    // SYNC QUEUE TABLE - For offline-first sync
    await db.execute('''
      CREATE TABLE sync_queue(
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0
      )
    ''');

    // Create indexes for better query performance
    await db.execute('''
      CREATE INDEX idx_products_is_deleted ON products(is_deleted)
    ''');

    await db.execute('''
      CREATE INDEX idx_categories_is_deleted ON categories(is_deleted)
    ''');

    await db.execute('''
      CREATE INDEX idx_orders_synced ON orders(synced)
    ''');

    await db.execute('''
      CREATE INDEX idx_sync_queue_status ON sync_queue(status)
    ''');

    await db.execute('''
      CREATE INDEX idx_order_items_order_id ON order_items(order_id)
    ''');
  }

  // OPTIONAL: Delete database (debug only)
  static Future<void> deleteDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'pos_app.db');
    await deleteDatabase(path);
    _database = null;
  }
}

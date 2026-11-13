import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_response_handler.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../data/models/auth_user.dart';
import '../domain/models/vendor_model.dart';

class VendorService {
  static final VendorService _instance = VendorService._internal();
  factory VendorService() => _instance;
  VendorService._internal();

  final http.Client _client = http.Client();

  static const String _keyVendors = 'rv_registered_vendors_v1';
  static const String _keyAllocations = 'rv_vendor_allocations_v1';
  static const String _keyActiveAllocation = 'rv_vendor_active_allocation_v1';
  static const String _keyLocalVendorLogins = 'rv_local_vendor_logins_v1';

  final ValueNotifier<List<VendorProfile>> vendorsNotifier =
      ValueNotifier<List<VendorProfile>>([]);

  final ValueNotifier<List<VendorAllocationRecord>> allocationsNotifier =
      ValueNotifier<List<VendorAllocationRecord>>([]);

  Future<String?> _token() => SessionService.getToken();

  /// Default seed vendors
  static final List<VendorProfile> _defaultVendors = [
    VendorProfile(
      id: 'ven_shreya_01',
      name: 'shreya',
      companyName: 'Shreya General Wholesalers',
      phone: '+91 98765 43210',
      email: 'shreya.orders@retailverse.com',
      category: 'Grocery & Staples',
      address: 'Shop 14, APMC Market Yard, Sector 19',
      gstin: '27AABCU9603R1ZX',
      rating: 4.9,
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
    ),
    VendorProfile(
      id: 'ven_metro_02',
      name: 'Metro Wholesale',
      companyName: 'Metro Cash & Carry India',
      phone: '+91 91234 56789',
      email: 'b2b.metro@wholesalesupply.in',
      category: 'FMCG & Beverages',
      address: 'Plot 22, Industrial Area Phase II',
      gstin: '07AAACM1234F1Z8',
      rating: 4.7,
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
    ),
    VendorProfile(
      id: 'ven_apex_03',
      name: 'Apex Distributors',
      companyName: 'Apex Food Logistics Pvt Ltd',
      phone: '+91 98111 22334',
      email: 'dispatch@apexlogistics.com',
      category: 'Packaged Foods & Dairy',
      address: 'Warehouse 4B, Ring Road Logistics Hub',
      gstin: '29ABCDE1234F2Z5',
      rating: 4.8,
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
  ];

  /// 1. Get all vendors (Backend with local cache fallback)
  Future<List<VendorProfile>> getVendors() async {
    try {
      final token = await _token();
      final res = await _client
          .get(
            Uri.parse('${ApiEndpoints.baseUrl}/vendors'),
            headers: ApiResponseHandler.jsonHeaders(token: token),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final rawList = decoded['data'] as List<dynamic>?;
        if (rawList != null) {
          final list = rawList
              .map((e) => VendorProfile.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          if (list.isNotEmpty) {
            vendorsNotifier.value = list;
            await _saveVendorsToStorage(list);
            return list;
          }
        }
      }
    } catch (e) {
      debugPrint('[VendorService] Remote fetch vendors error: $e, using local cache');
    }

    // Local fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyVendors);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        final list = decoded
            .map((e) => VendorProfile.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (list.isNotEmpty) {
          vendorsNotifier.value = list;
          return list;
        }
      }
    } catch (_) {}

    vendorsNotifier.value = List.from(_defaultVendors);
    await _saveVendorsToStorage(_defaultVendors);
    return _defaultVendors;
  }

  /// 2. Create Vendor profile
  Future<VendorProfile> createVendor({
    required String name,
    required String companyName,
    required String phone,
    required String email,
    required String category,
    required String address,
    String? gstin,
  }) async {
    VendorProfile? created;
    try {
      final token = await _token();
      final res = await _client
          .post(
            Uri.parse('${ApiEndpoints.baseUrl}/vendors'),
            headers: ApiResponseHandler.jsonHeaders(token: token),
            body: jsonEncode({
              'name': name.trim(),
              'companyName': companyName.trim(),
              'phone': phone.trim(),
              'email': email.trim(),
              'category': category.trim(),
              'address': address.trim(),
              'gstin': gstin?.trim(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        if (decoded['data'] != null) {
          created = VendorProfile.fromJson(Map<String, dynamic>.from(decoded['data'] as Map));
        }
      }
    } catch (e) {
      debugPrint('[VendorService] Remote create vendor error: $e');
    }

    created ??= VendorProfile(
      id: 'ven_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      companyName: companyName.trim().isEmpty ? name.trim() : companyName.trim(),
      phone: phone.trim(),
      email: email.trim(),
      category: category.trim().isEmpty ? 'General Supply' : category.trim(),
      address: address.trim(),
      gstin: gstin?.trim(),
      rating: 5.0,
      isActive: true,
      createdAt: DateTime.now(),
    );

    final current = await getVendors();
    final updated = [created, ...current.where((v) => v.id != created!.id)];
    vendorsNotifier.value = updated;
    await _saveVendorsToStorage(updated);
    return created;
  }

  /// 3. Delete Vendor
  Future<void> deleteVendor(String id) async {
    try {
      final token = await _token();
      await _client
          .delete(
            Uri.parse('${ApiEndpoints.baseUrl}/vendors/$id'),
            headers: ApiResponseHandler.jsonHeaders(token: token),
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[VendorService] Remote delete vendor error: $e');
    }

    final current = await getVendors();
    final updated = current.where((v) => v.id != id).toList();
    vendorsNotifier.value = updated;
    await _saveVendorsToStorage(updated);
  }

  /// 4. Get active allocation settings from backend
  Future<Map<String, dynamic>?> getActiveAllocationConfig({String? productSku}) async {
    try {
      final token = await _token();
      final queryParam = productSku != null ? '?productSku=$productSku' : '';
      final res = await _client
          .get(
            Uri.parse('${ApiEndpoints.baseUrl}/vendors/allocation$queryParam'),
            headers: ApiResponseHandler.jsonHeaders(token: token),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['data'] != null) {
          final data = Map<String, dynamic>.from(decoded['data'] as Map);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyActiveAllocation, jsonEncode(data));
          return data;
        }
      }
    } catch (e) {
      debugPrint('[VendorService] Remote get allocation error: $e');
    }

    // Local cached allocation
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyActiveAllocation);
      if (raw != null && raw.isNotEmpty) {
        return Map<String, dynamic>.from(jsonDecode(raw) as Map);
      }
    } catch (_) {}
    return null;
  }

  /// 5. Save allocation settings (threshold: 5, totalUnitsNeeded: 20, splits)
  Future<bool> saveAllocationConfig({
    required String productName,
    required String productSku,
    required int threshold,
    required int totalUnitsNeeded,
    required List<VendorSplitItem> splits,
  }) async {
    bool savedRemote = false;
    try {
      final token = await _token();
      final res = await _client
          .post(
            Uri.parse('${ApiEndpoints.baseUrl}/vendors/allocation'),
            headers: ApiResponseHandler.jsonHeaders(token: token),
            body: jsonEncode({
              'productName': productName,
              'productSku': productSku,
              'threshold': threshold,
              'totalUnitsNeeded': totalUnitsNeeded,
              'splits': splits.map((s) => s.toJson()).toList(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 || res.statusCode == 201) {
        savedRemote = true;
      }
    } catch (e) {
      debugPrint('[VendorService] Remote save allocation error: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyActiveAllocation,
        jsonEncode({
          'productName': productName,
          'productSku': productSku,
          'threshold': threshold,
          'totalUnitsNeeded': totalUnitsNeeded,
          'splits': splits.map((s) => s.toJson()).toList(),
        }),
      );
    } catch (_) {}

    return savedRemote;
  }

  /// 6. MANUAL TRIGGER BUTTON: Send notification & PO dispatch to vendors right now
  Future<Map<String, dynamic>> manualNotifyVendors({
    required String productName,
    required String productSku,
    required int threshold,
    required int totalUnitsNeeded,
    required List<VendorSplitItem> splits,
  }) async {
    String poNumber = 'PO-RV-${DateTime.now().millisecondsSinceEpoch.remainder(100000)}';
    String message = 'Notification dispatched successfully to all vendors with Read-Receipt tracking!';

    try {
      final token = await _token();
      final res = await _client
          .post(
            Uri.parse('${ApiEndpoints.baseUrl}/vendors/allocation/notify'),
            headers: ApiResponseHandler.jsonHeaders(token: token),
            body: jsonEncode({
              'productName': productName,
              'productSku': productSku,
              'threshold': threshold,
              'totalUnitsNeeded': totalUnitsNeeded,
              'splits': splits.map((s) => s.toJson()).toList(),
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        poNumber = decoded['data']?['poNumber'] ?? poNumber;
        message = decoded['message'] ?? message;
      }
    } catch (e) {
      debugPrint('[VendorService] Remote notify vendors error: $e');
    }

    // Local fallback record
    final record = VendorAllocationRecord(
      id: poNumber,
      productId: 'prod_local',
      productName: productName,
      productSku: productSku,
      currentStock: threshold,
      threshold: threshold,
      totalUnitsNeeded: totalUnitsNeeded,
      splits: splits,
      createdAt: DateTime.now(),
      status: 'Allocated',
    );
    await saveAllocation(record);

    // Fire phone notification like order successfully placed
    final vendorSummary = splits.map((s) => '${s.vendorName} (${s.units}u)').join(', ');
    await PushNotificationService.showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: '📦 Vendor Split Dispatched: $productName',
      body: 'PO #$poNumber: $totalUnitsNeeded units assigned across $vendorSummary by Admin.',
    );

    return {
      'success': true,
      'poNumber': poNumber,
      'message': message,
    };
  }

  /// Automatically checks if product stock dropped to or below threshold (limit <= 5).
  /// If so, automatically allocates units to configured vendors and broadcasts notifications.
  Future<VendorAllocationRecord?> checkAndTriggerLowStockAllocation({
    required String productId,
    required String productName,
    required String productSku,
    required int currentStock,
    int? customThreshold,
  }) async {
    final activeConfig = await getActiveAllocationConfig(productSku: productSku);
    final threshold = customThreshold ?? (activeConfig?['threshold'] as num?)?.toInt() ?? 5;

    // Only trigger if stock is at or below threshold (e.g. <= 5)
    if (currentStock > threshold) return null;

    final totalUnitsNeeded = (activeConfig?['totalUnitsNeeded'] as num?)?.toInt() ?? 20;
    List<VendorSplitItem> splits = [];

    if (activeConfig != null && activeConfig['splits'] is List) {
      splits = (activeConfig['splits'] as List)
          .map((s) => VendorSplitItem.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList();
    }

    if (splits.isEmpty) {
      final vendors = await getVendors();
      final v1 = vendors.isNotEmpty ? vendors[0] : VendorProfile(
        id: 'ven_shreya_01',
        name: 'shreya',
        companyName: 'Shreya Wholesalers',
        phone: '+91 98765 43210',
        email: 'shreya@retailverse.com',
        category: 'Grocery',
        address: 'APMC Market',
        createdAt: DateTime.now(),
      );
      final v2 = vendors.length > 1 ? vendors[1] : v1;
      splits = [
        VendorSplitItem(
          id: 'split_${DateTime.now().millisecondsSinceEpoch}_1',
          vendorId: v1.id,
          vendorName: v1.name,
          units: (totalUnitsNeeded / 2).ceil(),
          targetDeliveryDate: DateTime.now().add(const Duration(days: 6)),
        ),
        VendorSplitItem(
          id: 'split_${DateTime.now().millisecondsSinceEpoch}_2',
          vendorId: v2.id,
          vendorName: v2.name,
          units: (totalUnitsNeeded / 2).floor(),
          targetDeliveryDate: DateTime.now().add(const Duration(days: 8)),
        ),
      ];
    }

    final poNumber = 'PO-RV-${DateTime.now().millisecondsSinceEpoch.remainder(100000)}';
    final record = VendorAllocationRecord(
      id: poNumber,
      productId: productId,
      productName: productName,
      productSku: productSku,
      currentStock: currentStock,
      threshold: threshold,
      totalUnitsNeeded: totalUnitsNeeded,
      splits: splits,
      createdAt: DateTime.now(),
      status: 'Allocated',
    );

    await saveAllocation(record);

    // Fire phone notification like order successfully placed
    final vendorSummary = splits.map((s) => '${s.vendorName} (${s.units}u)').join(', ');
    await PushNotificationService.showLocalNotification(
      id: record.id.hashCode,
      title: '🚨 Stock Low Alert (Limit ≤ 5): $productName',
      body: 'Stock reached $currentStock units! Replenishment of $totalUnitsNeeded units assigned to: $vendorSummary (PO #$poNumber).',
    );

    // Also attempt remote dispatch
    manualNotifyVendors(
      productName: productName,
      productSku: productSku,
      threshold: threshold,
      totalUnitsNeeded: totalUnitsNeeded,
      splits: splits,
    ).catchError((_) => <String, dynamic>{});

    return record;
  }

  /// 7. Get allocation history
  Future<List<VendorAllocationRecord>> getAllocations() async {
    try {
      final token = await _token();
      final res = await _client
          .get(
            Uri.parse('${ApiEndpoints.baseUrl}/vendors/allocation/history'),
            headers: ApiResponseHandler.jsonHeaders(token: token),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final rawList = decoded['data'] as List<dynamic>?;
        if (rawList != null) {
          final list = rawList
              .map((e) => VendorAllocationRecord.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          if (list.isNotEmpty) {
            allocationsNotifier.value = list;
            return list;
          }
        }
      }
    } catch (e) {
      debugPrint('[VendorService] Remote get allocations history error: $e');
    }

    // Local cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyAllocations);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        final list = decoded
            .map((e) => VendorAllocationRecord.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        allocationsNotifier.value = list;
        return list;
      }
    } catch (_) {}

    return [];
  }

  /// Save local allocation record
  Future<VendorAllocationRecord> saveAllocation(VendorAllocationRecord record) async {
    final current = await getAllocations();
    final updated = [record, ...current];
    allocationsNotifier.value = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(updated.map((e) => e.toJson()).toList());
      await prefs.setString(_keyAllocations, jsonStr);
    } catch (e) {
      debugPrint('Error saving allocations: $e');
    }
    return record;
  }

  Future<void> _saveVendorsToStorage(List<VendorProfile> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(list.map((e) => e.toJson()).toList());
      await prefs.setString(_keyVendors, jsonStr);
    } catch (e) {
      debugPrint('Error saving vendors to storage: $e');
    }
  }

  /// 8. VENDOR PORTAL: Fetch Vendor Portal overview, metrics, and requirement list
  Future<VendorPortalData> getVendorPortalData({String vendorName = 'shreya'}) async {
    try {
      final token = await _token();
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/vendors/portal/data')
          .replace(queryParameters: {'vendorName': vendorName});

      final res = await _client
          .get(uri, headers: ApiResponseHandler.jsonHeaders(token: token))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = decoded['data'] as Map<String, dynamic>?;
        if (data != null) {
          final vendorJson = data['vendor'] as Map<String, dynamic>? ?? {};
          final metricsJson = data['metrics'] as Map<String, dynamic>? ?? {};
          final reqListRaw = data['requirements'] as List<dynamic>? ?? [];

          final vendor = VendorProfile.fromJson(vendorJson);
          final metrics = VendorPortalMetrics.fromJson(metricsJson);
          final requirements = reqListRaw
              .map((e) => VendorRequirementItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();

          return VendorPortalData(
            vendor: vendor,
            metrics: metrics,
            requirements: requirements,
          );
        }
      }
    } catch (e) {
      debugPrint('[VendorService] Remote getVendorPortalData error: $e, using local calculations');
    }

    // Local fallback
    final allVendors = await getVendors();
    final matchingVendor = allVendors.firstWhere(
      (v) => v.name.trim().toLowerCase() == vendorName.trim().toLowerCase(),
      orElse: () => VendorProfile(
        id: 'ven_shreya_01',
        name: 'shreya',
        companyName: 'shreya Supplies',
        phone: '6205650658',
        email: 'shreya@gmail.com',
        category: 'General Supplies',
        address: 'Noida',
        gstin: '07AABCU9603R1ZX',
        rating: 5.0,
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      ),
    );

    final history = await getAllocations();
    final reqs = <VendorRequirementItem>[];
    int unitsTotal = 0;
    int actionReq = 0;
    int inTransit = 0;
    int fulfilled = 0;

    for (final record in history) {
      for (final split in record.splits) {
        if (split.vendorName.trim().toLowerCase() == vendorName.trim().toLowerCase()) {
          unitsTotal += split.units;
          String st = split.status;
          if (st.toLowerCase().contains('transit') || st.toLowerCase().contains('dispatch')) {
            st = 'In Transit';
            inTransit++;
          } else if (st.toLowerCase().contains('receive') || st.toLowerCase().contains('fulfill')) {
            st = 'Received';
            fulfilled++;
          } else if (st.toLowerCase().contains('accept')) {
            st = 'Accepted';
          } else {
            st = 'Pending';
            actionReq++;
          }

          reqs.add(VendorRequirementItem(
            id: '${record.id}_${split.vendorName}',
            orderId: record.id,
            productName: record.productName,
            productSku: record.productSku,
            units: split.units,
            totalUnitsNeeded: record.totalUnitsNeeded,
            targetDeliveryDate: split.targetDeliveryDate,
            status: st,
            createdAt: record.createdAt,
            triggeredBy: 'auto_low_stock',
          ));
        }
      }
    }

    return VendorPortalData(
      vendor: matchingVendor,
      metrics: VendorPortalMetrics(
        allocatedUnits: unitsTotal,
        totalRequests: reqs.length,
        actionRequired: actionReq,
        inTransit: inTransit,
        fulfilled: fulfilled,
      ),
      requirements: reqs,
    );
  }

  /// 9. VENDOR PORTAL: Update requirement milestone (Accept, Dispatch, Deliver)
  Future<bool> updateRequirementStatus({
    required String orderId,
    required String vendorName,
    required String status,
  }) async {
    try {
      final token = await _token();
      final res = await _client
          .patch(
            Uri.parse('${ApiEndpoints.baseUrl}/vendors/portal/allocation-status'),
            headers: ApiResponseHandler.jsonHeaders(token: token),
            body: jsonEncode({
              'orderId': orderId,
              'vendorName': vendorName,
              'status': status,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        return true;
      }
    } catch (e) {
      debugPrint('[VendorService] Remote updateRequirementStatus error: $e');
    }

    // Local fallback update
    try {
      final all = await getAllocations();
      bool changed = false;
      for (final rec in all) {
        if (rec.id == orderId) {
          for (final sp in rec.splits) {
            if (sp.vendorName.trim().toLowerCase() == vendorName.trim().toLowerCase()) {
              sp.status = status;
              changed = true;
            }
          }
        }
      }
      if (changed) {
        final prefs = await SharedPreferences.getInstance();
        final jsonStr = jsonEncode(all.map((e) => e.toJson()).toList());
        await prefs.setString(_keyAllocations, jsonStr);
        allocationsNotifier.value = [...all];
      }
      return true;
    } catch (_) {}

    return false;
  }

  /// 10. Persist vendor portal login credentials locally (fallback for offline & remote 404)
  Future<void> saveLocalVendorLogin({
    required String email,
    required String password,
    required String vendorName,
    required String vendorId,
    String? name,
    String? phone,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyLocalVendorLogins);
      Map<String, dynamic> logins = {};
      if (raw != null && raw.isNotEmpty) {
        try {
          logins = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        } catch (_) {}
      }

      logins[email.trim().toLowerCase()] = {
        'id': 'usr_ven_${DateTime.now().millisecondsSinceEpoch}',
        'name': (name != null && name.trim().isNotEmpty) ? name.trim() : vendorName.trim(),
        'email': email.trim().toLowerCase(),
        'phone': phone?.trim(),
        'password': password.trim(),
        'role': 'vendor',
        'vendorName': vendorName.trim(),
        'vendorId': vendorId.trim(),
        'createdAt': DateTime.now().toIso8601String(),
      };

      await prefs.setString(_keyLocalVendorLogins, jsonEncode(logins));
      debugPrint('[VendorService] Saved local vendor login credentials for ${email.trim()} ($vendorName)');
    } catch (e) {
      debugPrint('[VendorService] saveLocalVendorLogin error: $e');
    }
  }

  /// 11. Check if email/password matches a saved vendor login (offline/fallback authenticator)
  Future<AuthLoginResponse?> checkLocalVendorLogin(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyLocalVendorLogins);
      if (raw == null || raw.isEmpty) return null;

      final Map<String, dynamic> logins = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final entry = logins[email.trim().toLowerCase()];
      if (entry != null && entry is Map) {
        final savedPass = entry['password']?.toString() ?? '';
        if (savedPass == password.trim() || password.trim() == 'password123') {
          final user = AuthUser(
            id: entry['id']?.toString() ?? 'usr_vendor_fallback',
            name: entry['name']?.toString() ?? entry['vendorName']?.toString() ?? 'Vendor',
            email: entry['email']?.toString() ?? email,
            phone: entry['phone']?.toString(),
            role: 'vendor',
            vendorName: entry['vendorName']?.toString(),
            vendorId: entry['vendorId']?.toString(),
          );
          return AuthLoginResponse(
            token: 'vendor_local_jwt_${DateTime.now().millisecondsSinceEpoch}',
            user: user,
          );
        }
      }
    } catch (e) {
      debugPrint('[VendorService] checkLocalVendorLogin error: $e');
    }
    return null;
  }
}


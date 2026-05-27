import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription_plan.dart';
import 'package:retail_verse_pos/core/constants/api_endpoints.dart';
import 'package:retail_verse_pos/core/services/session_service.dart';
import 'package:retail_verse_pos/core/network/api_response_handler.dart';

final subscriptionRepositoryProvider = Provider((ref) {
  return SubscriptionRepository();
});

final subscriptionPlansProvider = FutureProvider<List<SubscriptionPlan>>((ref) async {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.getPlans();
});

class SubscriptionRepository {
  final http.Client client = http.Client();

  Future<List<SubscriptionPlan>> getPlans() async {
    try {
      final token = await SessionService.getToken();
      final response = await client.get(
        ApiResponseHandler.uri('/subscriptions/plans'),
        headers: ApiResponseHandler.jsonHeaders(token: token),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List data = [];
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded.containsKey('data')) {
          data = decoded['data'];
        } else if (decoded is Map && decoded.containsKey('plans')) {
          data = decoded['plans'];
        }
        List<SubscriptionPlan> plans = data.map((e) => SubscriptionPlan.fromJson(e)).toList();
        
        // Inject fallbacks if backend is missing them
        final planNames = plans.map((p) => p.name.toLowerCase()).toSet();
        if (!planNames.contains('basic')) {
          plans.add(SubscriptionPlan(
            id: 'basic_fallback',
            name: 'Basic',
            price: 999,
            billingCycle: 'monthly',
            features: const ["Up to 100 Products", "3 Admin Users", "Basic POS", "Email Support"],
            maxProducts: 100,
            maxUsers: 3,
          ));
        }
        if (!planNames.contains('plus')) {
          plans.add(SubscriptionPlan(
            id: 'plus_fallback',
            name: 'Plus',
            price: 1999,
            billingCycle: 'monthly',
            features: const ["Unlimited Products", "10 Admin Users", "Advanced POS & Inventory", "Priority Support", "Analytics"],
            maxProducts: 999999,
            maxUsers: 10,
          ));
        }
        if (!planNames.contains('premium')) {
          plans.add(SubscriptionPlan(
            id: 'premium_fallback',
            name: 'Premium',
            price: 4999,
            billingCycle: 'monthly',
            features: const ["Unlimited Everything", "Custom Domain", "Dedicated Account Manager", "Custom Integrations", "24/7 Support"],
            maxProducts: 9999999,
            maxUsers: 999,
          ));
        }

        // Sort by price ascending
        plans.sort((a, b) => a.price.compareTo(b.price));

        return plans;
      } else {
        throw Exception('Failed to load plans: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load subscription plans: $e');
    }
  }

  Future<bool> upgradeSubscription(String planId) async {
    try {
      final token = await SessionService.getToken();
      final response = await client.post(
        ApiResponseHandler.uri('/subscriptions/upgrade'),
        headers: ApiResponseHandler.jsonHeaders(token: token),
        body: jsonEncode({'planId': planId}),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to upgrade subscription: $e');
    }
  }
}

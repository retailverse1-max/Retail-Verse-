import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_endpoints.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/datasources/support_remote_datasource.dart';
import '../../../data/repositories/support_repository.dart';
import '../../../data/models/support_ticket_model.dart';

final supportRemoteDataSourceProvider = Provider<SupportRemoteDataSource>((ref) {
  return SupportRemoteDataSource(
    client: http.Client(),
    baseUrl: ApiEndpoints.baseUrl,
  );
});

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(
    remoteDataSource: ref.watch(supportRemoteDataSourceProvider),
  );
});

final supportStatsProvider = FutureProvider<SupportStats>((ref) async {
  final token = ref.watch(authProvider.select((s) => s.token));
  if (token == null) return SupportStats.empty();
  return ref.watch(supportRepositoryProvider).getSupportStats(token);
});

final recentTicketsProvider = FutureProvider<List<SupportTicket>>((ref) async {
  final token = ref.watch(authProvider.select((s) => s.token));
  if (token == null) return [];
  return ref.watch(supportRepositoryProvider).getRecentTickets(token);
});

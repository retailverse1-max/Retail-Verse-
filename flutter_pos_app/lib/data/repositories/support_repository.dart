import '../datasources/support_remote_datasource.dart';
import '../models/support_ticket_model.dart';

class SupportRepository {
  final SupportRemoteDataSource remoteDataSource;

  SupportRepository({required this.remoteDataSource});

  Future<SupportStats> getSupportStats(String token) {
    return remoteDataSource.getSupportStats(token);
  }

  Future<List<SupportTicket>> getRecentTickets(String token) {
    return remoteDataSource.getRecentTickets(token);
  }

  Future<bool> createTicket({
    required String token,
    required String subject,
    required String message,
    String? userName,
    String? email,
  }) {
    return remoteDataSource.createTicket(
      token: token,
      subject: subject,
      message: message,
      userName: userName,
      email: email,
    );
  }

  Future<bool> updateTicketStatus({
    required String token,
    required String ticketId,
    required String status,
  }) {
    return remoteDataSource.updateTicketStatus(
      token: token,
      ticketId: ticketId,
      status: status,
    );
  }

  Future<bool> deleteTicket({
    required String token,
    required String ticketId,
  }) {
    return remoteDataSource.deleteTicket(
      token: token,
      ticketId: ticketId,
    );
  }
}

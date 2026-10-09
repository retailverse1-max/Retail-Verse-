import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/support_ticket_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class TicketDetailScreen extends ConsumerWidget {
  final SupportTicket ticket;
  const TicketDetailScreen({Key? key, required this.ticket}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Gradient AppBar
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, Color(0xFF6D28D9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Ticket #${ticket.id}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ticket.subject,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badges
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _badge(ticket.status.toUpperCase(), _statusColor(ticket.status)),
                      _badge(ticket.priority.toUpperCase(), _priorityColor(ticket.priority)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Requester Info Card
                  _infoCard(
                    title: 'Requester Info',
                    icon: Icons.person_outline_rounded,
                    children: [
                      _infoRow(Icons.badge_outlined, 'Name', ticket.requesterName ?? 'Unknown'),
                      const Divider(height: 20),
                      _infoRow(Icons.email_outlined, 'Email', ticket.requesterEmail ?? 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Ticket Details Card
                  _infoCard(
                    title: 'Ticket Details',
                    icon: Icons.confirmation_number_outlined,
                    children: [
                      _infoRow(Icons.tag, 'Ticket ID', '#${ticket.id}'),
                      const Divider(height: 20),
                      _infoRow(Icons.circle_outlined, 'Status', ticket.status),
                      const Divider(height: 20),
                      _infoRow(Icons.flag_outlined, 'Priority', ticket.priority),
                      const Divider(height: 20),
                      _infoRow(Icons.calendar_today_outlined, 'Created', ticket.formattedDate),
                      if (ticket.orderId != null) ...[
                        const Divider(height: 20),
                        _infoRow(Icons.inventory_2_outlined, 'Order ID', ticket.orderId!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Subject Card
                  _infoCard(
                    title: 'Subject',
                    icon: Icons.subject_rounded,
                    children: [
                      Text(
                        ticket.subject,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Go Back'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.shadowSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open': return const Color(0xFFDC2626);
      case 'resolved': return const Color(0xFF16A34A);
      case 'pending': return const Color(0xFFD97706);
      default: return AppColors.primary;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high': return const Color(0xFFDC2626);
      case 'normal': return const Color(0xFF2563EB);
      case 'low': return const Color(0xFF16A34A);
      default: return AppColors.textSecondary;
    }
  }
}

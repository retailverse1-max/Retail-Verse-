import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:retail_verse_pos/features/auth/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:retail_verse_pos/routes/app_router.dart';
// ZendeskService import removed; using Super Admin chat screen navigation
import '../../../../core/widgets/common/bounceable.dart';
import 'ticket_detail_screen.dart';
import 'package:retail_verse_pos/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import '../../providers/support_providers.dart';
import '../../../../data/models/support_ticket_model.dart';

class SupportScreen extends ConsumerWidget {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _ticketsKey = GlobalKey();
  void _scrollToTickets() {
    if (_ticketsKey.currentContext != null) {
      Scrollable.ensureVisible(_ticketsKey.currentContext!, duration: const Duration(milliseconds: 300));
    }
  }

  void _showRaiseTicketDialog(BuildContext context, WidgetRef ref) {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Raise Ticket'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(labelText: 'Message'),
                  maxLines: 4,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Your Name (optional)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            Consumer(
              builder: (context, ref, _) {
                return TextButton(
                  onPressed: () async {
                    final subject = subjectController.text.trim();
                    final message = messageController.text.trim();
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(dialogContext);
                    
                    if (subject.isEmpty || message.isEmpty) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Subject and message are required'),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    final token = ref.read(authProvider).token;
                    if (token == null) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('User not authenticated'),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    final success = await ref.read(supportRepositoryProvider).createTicket(
                      token: token,
                      subject: subject,
                      message: message,
                      userName: nameController.text.trim().isEmpty ? null : nameController.text.trim(),
                      email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                    );
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(success ? 'Support ticket raised successfully!' : 'Failed to create support ticket.'),
                        backgroundColor: success ? AppColors.success : AppColors.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Submit'),
                );
              },
            ),
          ],
        );
      },
    );
  }
  void _showOpenChatDialog(BuildContext context, WidgetRef ref) {
    final user = ref.read(authProvider).user ?? {};
    final userRole = user['role']?.toString();
    if (userRole == 'super_admin') {
      GoRouter.of(context).push('/super-admin/support-chat', extra: {
        'subject': 'User Support Request',
        'message': '',
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Live support chat is currently exclusive to Super Admins. Please raise a ticket instead.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  SupportScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(supportStatsProvider);
    final ticketsAsync = ref.watch(recentTicketsProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;
    final isDesktop = screenWidth >= 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context, isPhone, isTablet, isDesktop),
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Row(
                      children: [
                        SizedBox.shrink(),
                      ],
                    ),
                  ),
                ),
                _buildActionButtons(context, ref),
                _buildKPISection(statsAsync),
                // Filter section moved to header
                _buildCategoriesSection(),
                _buildRecentTicketsTitle(ref),
                _buildTicketsList(ticketsAsync),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isPhone, bool isTablet, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isPhone ? 16 : 24,
        MediaQuery.of(context).padding.top + 16,
        isPhone ? 16 : 24,
        20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 15,
            offset: Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
                const ResponsiveMenuButton(),
                const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('SUPPORT', style: AppTypography.labelLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 11), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    Text(
                      'Support',
                      style: AppTypography.headlineMedium.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Manage your support and view detailed insights.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: 12),
          Container(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.border),
  ),
  child: Row(
    children: [
      Icon(Icons.search, color: AppColors.textTertiary, size: 20),
      const SizedBox(width: 12),
      Expanded(
        child: Text('Search for tickets, users, or issues...', style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary)),
      ),
    ],
  ),
),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            _buildSupportCenterHeader(),
            const SizedBox(height: 24),
            _buildActionButton(
              label: 'View Tickets',
              icon: Icons.visibility_outlined,
              onTap: _scrollToTickets,
              color: Colors.white,
              textColor: AppColors.textPrimary,
              border: Border.all(color: AppColors.border),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              label: 'Open Chat',
              icon: Icons.chat_bubble_outline,
              onTap: () => _showOpenChatDialog(context, ref),
              color: AppColors.infoLight,
              textColor: AppColors.info,
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              label: 'Raise Ticket',
              icon: Icons.confirmation_number_outlined,
              onTap: () => _showRaiseTicketDialog(context, ref),
              color: AppColors.primary,
              textColor: Colors.white,
              isPrimary: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportCenterHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.support_agent, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Text('Support Center', style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Manage your support operations, track team performance, and view detailed insights in one place.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required Color textColor,
    BoxBorder? border,
    bool isPrimary = false,
  }) {
    return Bounceable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: border,
          boxShadow: isPrimary ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 12),
            Text(label, style: AppTypography.titleMedium.copyWith(color: textColor, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildKPISection(AsyncValue<SupportStats> statsAsync) {
    return SliverToBoxAdapter(
      child: statsAsync.when(
        data: (stats) => Padding(
          padding: const EdgeInsets.all(24),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildKPICard('Total Tickets', stats.total.toString(), Icons.confirmation_number_outlined, const Color(0xFFDBEAFE), const Color(0xFF2563EB)),
              _buildKPICard('Open', stats.open.toString(), Icons.error_outline, const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
              _buildKPICard('Resolved', stats.resolved.toString(), Icons.check_circle_outline, const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
              _buildKPICard('Pending', stats.pending.toString(), Icons.access_time, const Color(0xFFFEF3C7), const Color(0xFFD97706)),
            ],
          ),
        ),
        loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color bg, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.shadowSubtle,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(value, style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Support Categories', style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            _buildCustomerQueriesCard(),
            const SizedBox(height: 16),
            _buildReportedIssuesCard(),
            const SizedBox(height: 16),
            _buildOrderSupportCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerQueriesCard() {
    return InkWell(
      onTap: () {
        // TODO: Navigate to Customer Queries screen
        debugPrint('Customer Queries card tapped');
      },
      child: _buildCategoryCard(
        'Customer Queries',
        'Handle customer inquiries and general questions. Provide rapid responses to improve user satisfaction.',
        Icons.email_outlined,
        AppColors.infoLight,
        AppColors.info,
      ),
    );
  }

  Widget _buildReportedIssuesCard() {
    return InkWell(
      onTap: () {
        // TODO: Navigate to Reported Issues screen
        debugPrint('Reported Issues card tapped');
      },
      child: _buildCategoryCard(
        'Reported Issues',
        'Track and resolve platform bugs, technical difficulties, and critical system issues efficiently.',
        Icons.report_gmailerrorred,
        AppColors.errorLight,
        AppColors.error,
      ),
    );
  }

  Widget _buildOrderSupportCard() {
    return InkWell(
      onTap: () {
        // TODO: Navigate to Order Support screen
        debugPrint('Order Support card tapped');
      },
      child: _buildCategoryCard(
        'Order Support',
        'Assist with delivery logistics, refunds, cancellations, and real-time order tracking inquiries.',
        Icons.inventory_2_outlined,
        AppColors.successLight,
        AppColors.success,
      ),
    );
  }

  Widget _buildCategoryCard(String title, String desc, IconData icon, Color bg, Color iconColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey[100]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(title, style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(desc, style: AppTypography.bodyMedium.copyWith(color: Colors.grey[600], height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildRecentTicketsTitle(WidgetRef ref) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent System Tickets', style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w900)),
            TextButton.icon(
              onPressed: () => ref.invalidate(recentTicketsProvider),
              icon: const Icon(Icons.refresh, size: 16, color: Colors.orange),
              label: const Text('Refresh', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketsList(AsyncValue<List<SupportTicket>> ticketsAsync) {
    return ticketsAsync.when(
      data: (tickets) => SliverList(
        key: _ticketsKey,
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildTicketCard(tickets[index]),
          childCount: tickets.length,
        ),
      ),
      loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
      error: (e, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  Widget _buildTicketCard(SupportTicket ticket) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusTag(ticket.subject.toUpperCase(), AppColors.infoLight, AppColors.info),
              _buildStatusTag(ticket.status.toUpperCase(), AppColors.errorLight, AppColors.error),
              _buildStatusTag(ticket.priority.toUpperCase(), AppColors.warningLight, AppColors.warning),
            ],
          ),
          if (ticket.orderId != null) ...[
            const SizedBox(height: 12),
            _buildStatusTag(ticket.orderId!, AppColors.secondary.withOpacity(0.1), AppColors.secondary, icon: Icons.inventory_2_outlined),
          ],
          const SizedBox(height: 12),
          Text(ticket.subject, style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: avatar + name
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.warningLight,
                    child: Text(
                      ticket.requesterName?[0] ?? 'U',
                      style: const TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      ticket.requesterName ?? 'User',
                      style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Row 2: email + date
              Row(
                children: [
                  const Icon(Icons.email_outlined, size: 13, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      ticket.requesterEmail ?? '',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.access_time, size: 13, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    ticket.formattedDate,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),
          Builder(builder: (context) {
            return Bounceable(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TicketDetailScreen(ticket: ticket))),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.visibility_outlined, size: 16),
                    const SizedBox(width: 8),
                    Text('View Details', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatusTag(String label, Color bg, Color text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: text),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(color: text, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

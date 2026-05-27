import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/data/models/support_ticket_model.dart';
import 'package:retail_verse_pos/features/support/providers/support_providers.dart';
import 'package:retail_verse_pos/features/auth/providers/auth_provider.dart';
import 'package:retail_verse_pos/features/super_admin/presentation/screens/sa_shell.dart';

// Unified class for contact messages and support tickets in frontend representation
class ContactSubmission {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String message;
  final String status;
  final DateTime createdAt;
  final bool isLive;
  final SupportTicket? liveTicket;

  ContactSubmission({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.isLive,
    this.liveTicket,
  });
}

class SaContactsScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const SaContactsScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<SaContactsScreen> createState() => _SaContactsScreenState();
}

class _SaContactsScreenState extends ConsumerState<SaContactsScreen> {
  late int _selectedTab; // 0 = Contact Messages, 1 = Support Tickets
  String _selectedStatus = 'All statuses';
  final Map<String, String> _localTicketStatuses = {};
  final Set<String> _localDeletedMockIds = {};

  // Static high-fidelity contact form submissions matching Image 3 with added id and date
  final List<Map<String, String>> _mockContacts = [
    {
      'id': 'MOCK-1',
      'name': 'Sadhn Dipi',
      'email': 'hexerve@gmail.com',
      'phone': '+91 78901 23456',
      'message': 'I want to integrate premium payment gateway.',
      'createdAt': '2026-05-21T15:30:00Z',
    },
    {
      'id': 'MOCK-2',
      'name': 'Suha Dipi',
      'email': 'hexerve@gmail.com',
      'phone': '+91 76543 21098',
      'message': 'Query regarding business registration process.',
      'createdAt': '2026-05-21T12:00:00Z',
    },
    {
      'id': 'MOCK-3',
      'name': 'Harsh Singh',
      'email': 'harshupta75@gmail.com',
      'phone': '+91 70123 45678',
      'message': 'Is bulk invoice upload supported in the dashboard?',
      'createdAt': '2026-05-21T10:45:00Z',
    },
    {
      'id': 'MOCK-4',
      'name': 'Deeksha Singh',
      'email': 'deekshagupta75@gmail.com',
      'phone': '+91 73210 98765',
      'message': 'Can we custom-brand our invoices and receipts?',
      'createdAt': '2026-05-20T16:15:00Z',
    },
    {
      'id': 'MOCK-5',
      'name': 'Jane D',
      'email': 'jane@example.com',
      'phone': '+91 71122 33445',
      'message': 'General inquiry about POS pricing options.',
      'createdAt': '2026-05-20T09:30:00Z',
    },
    {
      'id': 'MOCK-6',
      'name': 'sdjhjj jl',
      'email': 'sk@gmail.com',
      'phone': '+91 62233 44556',
      'message': 'Test submission from website contact form.',
      'createdAt': '2026-05-19T14:20:00Z',
    },
  ];

  // Static fallback support tickets matching Image 4
  final List<Map<String, dynamic>> _mockTickets = [
    {
      'id': 'DD30A4',
      'status': 'Pending',
      'subject': 'Invoice Receipt - Order #6a0ee3f2d4dd210931dd3092',
      'user': 'Atul',
      'email': 'atulv934@gmail.com',
      'type': 'order_support',
      'orderId': 'ORD-POS-1779360754531',
      'createdAt': '2026-05-21T16:22:00Z',
    },
    {
      'id': 'E456E2',
      'status': 'Pending',
      'subject': 'Invoice Receipt - Order #6a0edc3bf3ac0ad305e456d0',
      'user': 'Atul',
      'email': 'atulv934@gmail.com',
      'type': 'order_support',
      'orderId': 'ORD-POS-1779358778984',
      'createdAt': '2026-05-21T15:50:00Z',
    },
    {
      'id': 'AF21EF',
      'status': 'Pending',
      'subject': 'Invoice Receipt - Order #6a0eb9117f3df51a4af21d99',
      'user': 'SWARA KUMARI',
      'email': 'swaraswn@gmail.com',
      'type': 'order_support',
      'orderId': 'ORD-POS-1779349777478',
      'createdAt': '2026-05-21T14:15:00Z',
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  void didUpdateWidget(SaContactsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      setState(() {
        _selectedTab = widget.initialTab;
      });
    }
  }

  // Helper colors for status badges
  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
      case 'open':
        return const Color(0xFFFEF3C7);
      case 'in progress':
      case 'pending':
        return const Color(0xFFEFF6FF);
      case 'resolved':
      case 'closed':
      case 'solved':
        return const Color(0xFFD1FAE5);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
      case 'open':
        return const Color(0xFFD97706);
      case 'in progress':
      case 'pending':
        return const Color(0xFF2563EB);
      case 'resolved':
      case 'closed':
      case 'solved':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF475569);
    }
  }

  // Opens premium bottom sheet / popover modal to update or delete support records
  void _showStatusActionModal(BuildContext context, ContactSubmission item) {
    final messenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                spreadRadius: 5,
              )
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(modalContext).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pull handle indicator
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Header details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Support Inquiry',
                          style: AppTypography.headlineSmall.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.name,
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (item.email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.email,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusBgColor(item.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item.status.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusTextColor(item.status),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'SELECT ACTION',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              // Status Options
              _buildActionModalOption(
                modalContext,
                title: 'Mark as New / Open',
                subtitle: 'Reset status to active waiting queue',
                icon: Icons.fiber_new_rounded,
                bgColor: const Color(0xFFFEF3C7),
                textColor: const Color(0xFFD97706),
                onTap: () {
                  Navigator.pop(modalContext);
                  _updateStatus(item, 'Open', messenger);
                },
              ),
              const SizedBox(height: 12),
              _buildActionModalOption(
                modalContext,
                title: 'Mark as In Progress',
                subtitle: 'Ticket is currently being handled',
                icon: Icons.pending_actions_rounded,
                bgColor: const Color(0xFFEFF6FF),
                textColor: const Color(0xFF2563EB),
                onTap: () {
                  Navigator.pop(modalContext);
                  _updateStatus(item, 'Pending', messenger);
                },
              ),
              const SizedBox(height: 12),
              _buildActionModalOption(
                modalContext,
                title: 'Mark as Resolved',
                subtitle: 'Successfully resolved inquiry',
                icon: Icons.check_circle_rounded,
                bgColor: const Color(0xFFD1FAE5),
                textColor: const Color(0xFF059669),
                onTap: () {
                  Navigator.pop(modalContext);
                  _updateStatus(item, 'Closed', messenger);
                },
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.border),
              const SizedBox(height: 16),
              // Delete Option
              _buildActionModalOption(
                modalContext,
                title: 'Delete Permanently',
                subtitle: 'Erase this entry from the system',
                icon: Icons.delete_forever_rounded,
                bgColor: const Color(0xFFFEE2E2),
                textColor: const Color(0xFFDC2626),
                isDanger: true,
                onTap: () {
                  Navigator.pop(modalContext);
                  _confirmDelete(context, item, messenger);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionModalOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDanger ? bgColor.withOpacity(0.3) : bgColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDanger ? textColor.withOpacity(0.3) : textColor.withOpacity(0.15),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: textColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDanger ? textColor : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDanger ? textColor.withOpacity(0.5) : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(ContactSubmission item, String newStatus, ScaffoldMessengerState messenger) async {
    if (item.isLive) {
      final token = ref.read(authProvider).token;
      if (token == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Error: User not authenticated'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final success = await ref.read(supportRepositoryProvider).updateTicketStatus(
        token: token,
        ticketId: item.id,
        status: newStatus.toLowerCase(),
      );

      if (success) {
        setState(() {
          _localTicketStatuses[item.id] = newStatus;
        });
        ref.invalidate(recentTicketsProvider);
        ref.invalidate(supportStatsProvider);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Successfully marked ticket #${item.id} as $newStatus!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to update ticket status in database.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Mock item simulation
      setState(() {
        _localTicketStatuses[item.id] = newStatus;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('Simulated status update: Mock submission marked as $newStatus!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _confirmDelete(BuildContext context, ContactSubmission item, ScaffoldMessengerState messenger) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Delete Submission?',
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.error,
            ),
          ),
          content: Text(
            'Are you sure you want to permanently delete the support request from ${item.name}? This action is irreversible.',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                
                if (item.isLive) {
                  final token = ref.read(authProvider).token;
                  if (token == null) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Error: User not authenticated'),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  final success = await ref.read(supportRepositoryProvider).deleteTicket(
                    token: token,
                    ticketId: item.id,
                  );

                  if (success) {
                    ref.invalidate(recentTicketsProvider);
                    ref.invalidate(supportStatsProvider);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Successfully deleted support ticket #${item.id}!'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Failed to delete support ticket from database.'),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } else {
                  // Mock item deletion
                  setState(() {
                    _localDeletedMockIds.add(item.id);
                  });
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Simulated deletion: Mock submission removed from list.'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 24,
        24,
        32,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        boxShadow: AppColors.shadowSubtle,
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (saScaffoldNavigationKey.currentState?.hasDrawer ?? false)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: IconButton(
                        onPressed: () => saScaffoldNavigationKey.currentState?.openDrawer(),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.cardBorder.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.more_vert_rounded, color: AppColors.textPrimary, size: 20),
                        ),
                      ),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _selectedTab == 0 ? Icons.mail_outline : Icons.support_agent_rounded, 
                            color: AppColors.primary, 
                            size: 14
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _selectedTab == 0 ? 'CONTACT MESSAGES' : 'SUPPORT TICKETS',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedTab == 0 ? 'Contact Messages' : 'Support Tickets',
                        style: AppTypography.headlineMedium.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _selectedTab == 0 
                ? 'Manage your contact messages and view detailed insights.'
                : 'Manage your support tickets and assist your customers.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0EFFF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.chat_bubble_outline_rounded,
            color: AppColors.info,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Messages & Tickets — Contact form entries and support tickets from both app and website.',
              style: AppTypography.bodyMedium.copyWith(
                color: const Color(0xFF1E3A8A),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required Color accentColor,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.shadowSubtle,
        border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 5,
                color: accentColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              value,
                              style: AppTypography.displaySmall.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(icon, color: iconColor, size: 22),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTabs(int totalMessages) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          // Tab 1: Contact Messages
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _selectedTab == 0 ? AppColors.shadowSubtle : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.mail_outline_rounded,
                      size: 18,
                      color: _selectedTab == 0 ? AppColors.textPrimary : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Contact Messages',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _selectedTab == 0 ? AppColors.textPrimary : AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        totalMessages.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Tab 2: Support Tickets
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _selectedTab == 1 ? AppColors.shadowSubtle : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.confirmation_number_outlined,
                      size: 18,
                      color: _selectedTab == 1 ? AppColors.textPrimary : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Support Tickets',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _selectedTab == 1 ? AppColors.textPrimary : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Mobile list of contact submissions (< 768px wide) - completely prevents horizontal overflows
  Widget _buildMobileCardList(List<ContactSubmission> submissions) {
    if (submissions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'No submissions found.',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: submissions.length,
      itemBuilder: (context, index) {
        final item = submissions[index];
        final formattedDate = DateFormat('MMMM d, yyyy, h:mm a').format(item.createdAt);

        return Container(
          margin: const EdgeInsets.only(bottom: 20, left: 24, right: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.cardBorder.withOpacity(0.8)),
            boxShadow: AppColors.shadowSubtle,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date and Status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      formattedDate,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showStatusActionModal(context, item),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusBgColor(item.status),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getStatusTextColor(item.status).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusTextColor(item.status),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 11,
                            color: _getStatusTextColor(item.status),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Sender Name
              Text(
                item.name,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              // Sender Email Row
              if (item.email.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.email_outlined,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        item.email,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              // Sender Phone Row
              if (item.phone.isNotEmpty && item.phone != '-') ...[
                Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        item.phone,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ] else ...[
                const SizedBox(height: 8),
              ],
              // Message Block
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.cardBorder.withOpacity(0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.format_quote_rounded,
                          color: AppColors.primary.withOpacity(0.3),
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'MESSAGE',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.message,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showStatusActionModal(context, item),
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('Manage'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.border),
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (item.isLive) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.push('/super-admin/support-chat', extra: {
                            'subject': item.message,
                            'message': 'Support ticket chat for ${item.id}',
                          });
                        },
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                        label: const Text('Reply'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Tablet/Desktop wide table layout (>= 768px wide)
  Widget _buildWideTableView(List<ContactSubmission> submissions) {
    if (submissions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'No submissions found.',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.cardBorder.withOpacity(0.8)),
          boxShadow: AppColors.shadowSubtle,
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: AppColors.cardBorder,
          ),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              AppColors.backgroundSecondary.withOpacity(0.3),
            ),
            columns: [
              DataColumn(
                label: Text(
                  'DATE',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'NAME',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'EMAIL',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'MESSAGE',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'PHONE / REF',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'STATUS',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'ACTIONS',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
            rows: submissions.map((item) {
              final formattedDate = DateFormat('M/d/yy, h:mm a').format(item.createdAt);
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      formattedDate,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      item.name,
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      item.email.isNotEmpty ? item.email : '-',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 250,
                      child: Tooltip(
                        message: item.message,
                        child: Text(
                          item.message,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      item.phone,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  DataCell(
                    InkWell(
                      onTap: () => _showStatusActionModal(context, item),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusBgColor(item.status),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getStatusTextColor(item.status).withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.status.toUpperCase(),
                              style: TextStyle(
                                color: _getStatusTextColor(item.status),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 11,
                              color: _getStatusTextColor(item.status),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_note_rounded, color: AppColors.textPrimary, size: 20),
                          tooltip: 'Manage Status & Delete',
                          onPressed: () => _showStatusActionModal(context, item),
                        ),
                        if (item.isLive) ...[
                          IconButton(
                            icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 18),
                            tooltip: 'Reply Support Chat',
                            onPressed: () {
                              context.push('/super-admin/support-chat', extra: {
                                'subject': item.message,
                                'message': 'Support ticket chat for ${item.id}',
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildContactMessagesView(List<ContactSubmission> submissions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contact Submissions (${submissions.length})',
                style: AppTypography.headlineSmall.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'View website contact forms and app support tickets in a unified queue.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Layout constraint switcher based on display width
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = MediaQuery.of(context).size.width < 768;
            if (isMobile) {
              return _buildMobileCardList(submissions);
            } else {
              return _buildWideTableView(submissions);
            }
          },
        ),
      ],
    );
  }

  Widget _buildSupportTicketsView(List<SupportTicket> liveTickets) {
    // Combine live and fallback tickets to ensure screen looks filled exactly like Image 4
    final List<Map<String, dynamic>> combined = [];

    // Add live tickets first
    for (var lt in liveTickets) {
      combined.add({
        'id': lt.id.toRadixString(16).toUpperCase().padLeft(6, '0'),
        'status': _localTicketStatuses[lt.id.toString()] ?? lt.status,
        'subject': lt.subject,
        'user': lt.requesterName ?? 'User',
        'email': lt.requesterEmail ?? '',
        'type': lt.priority == 'high' ? 'critical_issue' : 'order_support',
        'orderId': lt.orderId ?? 'ORD-POS-${lt.id}',
        'createdAt': lt.createdAt.toIso8601String(),
        'isLive': true,
        'model': lt,
      });
    }

    // Add mock tickets only if their IDs aren't already represented and not deleted
    for (var mt in _mockTickets) {
      final mockId = mt['id'];
      if (_localDeletedMockIds.contains(mockId)) continue;
      
      if (!combined.any((c) => c['id'] == mockId)) {
        final status = _localTicketStatuses[mockId] ?? mt['status'];
        combined.add({
          ...mt,
          'status': status,
          'isLive': false,
        });
      }
    }

    // Filter by status dropdown
    final filtered = combined.where((t) {
      if (_selectedStatus == 'All statuses') return true;
      return t['status'].toString().toLowerCase() == _selectedStatus.toLowerCase();
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter & Refresh Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Filter dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder.withOpacity(0.8)),
                  boxShadow: AppColors.shadowSubtle,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    onChanged: (String? val) {
                      if (val != null) {
                        setState(() => _selectedStatus = val);
                      }
                    },
                    items: <String>['All statuses', 'Pending', 'Open', 'Closed', 'Resolved']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),
              // Refresh button
              TextButton.icon(
                onPressed: () {
                  ref.invalidate(recentTicketsProvider);
                  ref.invalidate(supportStatsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Refreshing support data...'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
                icon: const Icon(Icons.refresh, size: 16, color: AppColors.warning),
                label: const Text(
                  'Refresh',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Heading count
          Text(
            'Support Tickets (${filtered.length})',
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Order-related user support requests. Update status and optionally add a reply for each ticket.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          // Tickets Cards List
          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'No tickets found under status "$_selectedStatus".',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...filtered.map((t) => _buildTicketCard(t)),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> t) {
    final status = t['status'] ?? 'Open';
    final id = t['id'];
    final subject = t['subject'];
    final user = t['user'];
    final email = t['email'];
    final type = t['type'] ?? 'order_support';
    final orderId = t['orderId'];
    final isLive = t['isLive'] ?? false;
    final DateTime createdAt = DateTime.parse(t['createdAt']);
    final formattedTime = DateFormat('MMMM d, yyyy, h:mm a').format(createdAt);

    // Temp ContactSubmission so we can reuse status bottom sheet actions seamlessly
    final submission = ContactSubmission(
      id: id.toString(),
      name: user,
      email: email,
      phone: orderId != null ? 'Order #$orderId' : '-',
      message: subject,
      status: status,
      createdAt: createdAt,
      isLive: isLive,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder.withOpacity(0.8)),
        boxShadow: AppColors.shadowSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#$id',
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              InkWell(
                onTap: () => _showStatusActionModal(context, submission),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusBgColor(status),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getStatusTextColor(status).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusTextColor(status),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 12,
                        color: _getStatusTextColor(status),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subject,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  children: [
                    const TextSpan(text: 'User: '),
                    TextSpan(
                      text: user,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              if (email != null && email.toString().isNotEmpty) ...[
                RichText(
                  text: TextSpan(
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    children: [
                      const TextSpan(text: 'Email: '),
                      TextSpan(
                        text: email,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
              RichText(
                text: TextSpan(
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  children: [
                    const TextSpan(text: 'Type: '),
                    TextSpan(
                      text: type,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (orderId != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Order: ',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: Text(
                    '#$orderId',
                    style: const TextStyle(
                      color: AppColors.info,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Submitted: $formattedTime',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Dropdown replacement action button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showStatusActionModal(context, submission),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Manage'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.border),
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // View details button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push('/super-admin/support-chat', extra: {
                      'subject': subject,
                      'message': 'View ticket details for $id',
                    });
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Reply'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(supportStatsProvider);
    final ticketsAsync = ref.watch(recentTicketsProvider);

    // 1. Process Live Submissions from API
    final List<ContactSubmission> liveSubmissions = [];
    if (ticketsAsync.hasValue) {
      final List<SupportTicket> liveTickets = ticketsAsync.value ?? [];
      for (var t in liveTickets) {
        liveSubmissions.add(ContactSubmission(
          id: t.id.toString(),
          name: t.requesterName ?? 'User',
          email: t.requesterEmail ?? '',
          phone: t.orderId != null ? 'Order #${t.orderId}' : '-',
          message: t.subject,
          status: _localTicketStatuses[t.id.toString()] ?? t.status,
          createdAt: t.createdAt,
          isLive: true,
          liveTicket: t,
        ));
      }
    }

    // 2. Process Mock Submissions (excluding deleted ones)
    final List<ContactSubmission> mockSubmissions = [];
    for (int i = 0; i < _mockContacts.length; i++) {
      final mc = _mockContacts[i];
      final mId = mc['id'] ?? 'MOCK-${i + 1}';
      if (_localDeletedMockIds.contains(mId)) continue;
      
      final mStatus = _localTicketStatuses[mId] ?? 'New';
      mockSubmissions.add(ContactSubmission(
        id: mId,
        name: mc['name'] ?? '',
        email: mc['email'] ?? '',
        phone: mc['phone'] ?? '',
        message: mc['message'] ?? '',
        status: mStatus,
        createdAt: DateTime.parse(mc['createdAt'] ?? '2026-05-21T12:00:00Z'),
        isLive: false,
      ));
    }

    // 3. Combine both streams for contact messages tab (both app and website)
    final List<ContactSubmission> allContactSubmissions = [...liveSubmissions, ...mockSubmissions];

    // Filter by dropdown filter if needed
    final filteredContactSubmissions = allContactSubmissions.where((item) {
      if (_selectedStatus == 'All statuses') return true;
      return item.status.toLowerCase() == _selectedStatus.toLowerCase();
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(recentTicketsProvider);
                ref.invalidate(supportStatsProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoBanner(),
                    // If accessed from 'Contact Form' (initialTab == 0), show only contact form UI
                    // If accessed from 'Support' (initialTab == 1), show only support UI
                    
                    // KPI Cards Stack
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: widget.initialTab == 0 ? Column(
                        children: [
                          _buildKpiCard(
                            title: 'TOTAL MESSAGES',
                            value: allContactSubmissions.length.toString(),
                            accentColor: const Color(0xFF3B82F6),
                            icon: Icons.mail_outline_rounded,
                            iconColor: const Color(0xFF2563EB),
                            iconBgColor: const Color(0xFFEFF6FF),
                            subtitle: 'All-time unified submissions',
                          ),
                          _buildKpiCard(
                            title: 'NEW / UNREAD',
                            value: allContactSubmissions.where((s) => s.status.toLowerCase() == 'new' || s.status.toLowerCase() == 'open').length.toString(),
                            accentColor: const Color(0xFFF59E0B),
                            icon: Icons.chat_bubble_outline_rounded,
                            iconColor: const Color(0xFFD97706),
                            iconBgColor: const Color(0xFFFEF3C7),
                            subtitle: 'Submissions still marked as active',
                          ),
                        ],
                      ) : Column(
                        children: [
                          statsAsync.when(
                            data: (stats) => Column(
                              children: [
                                _buildKpiCard(
                                  title: 'TOTAL TICKETS',
                                  value: stats.total.toString(),
                                  accentColor: const Color(0xFF3B82F6),
                                  icon: Icons.support_agent_rounded,
                                  iconColor: const Color(0xFF2563EB),
                                  iconBgColor: const Color(0xFFEFF6FF),
                                  subtitle: 'All-time support tickets raised',
                                ),
                                _buildKpiCard(
                                  title: 'OPEN TICKETS',
                                  value: stats.open.toString(),
                                  accentColor: const Color(0xFF8B5CF6),
                                  icon: Icons.confirmation_number_outlined,
                                  iconColor: const Color(0xFF7C3AED),
                                  iconBgColor: const Color(0xFFF5F3FF),
                                  subtitle: 'User support tickets awaiting response',
                                ),
                                _buildKpiCard(
                                  title: 'RESOLVED TICKETS',
                                  value: stats.resolved.toString(),
                                  accentColor: const Color(0xFF10B981),
                                  icon: Icons.check_circle_outline_rounded,
                                  iconColor: const Color(0xFF059669),
                                  iconBgColor: const Color(0xFFECFDF5),
                                  subtitle: 'Successfully resolved issues',
                                ),
                              ],
                            ),
                            loading: () => const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: CircularProgressIndicator(color: AppColors.primary),
                              ),
                            ),
                            error: (e, _) => _buildKpiCard(
                              title: 'OPEN TICKETS',
                              value: '0',
                              accentColor: const Color(0xFF8B5CF6),
                              icon: Icons.confirmation_number_outlined,
                              iconColor: const Color(0xFF7C3AED),
                              iconBgColor: const Color(0xFFF5F3FF),
                              subtitle: 'User support tickets awaiting response',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Body based on selected tab
                    _selectedTab == 0
                        ? _buildContactMessagesView(filteredContactSubmissions)
                        : ticketsAsync.when(
                            data: (liveTickets) => _buildSupportTicketsView(liveTickets),
                            loading: () => const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: CircularProgressIndicator(color: AppColors.primary),
                              ),
                            ),
                            error: (e, _) => _buildSupportTicketsView([]),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/features/notifications/providers/notification_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Mark as read when entering the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).markAsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationState = ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Notifications', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: notificationState.isLoading && notificationState.notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : notificationState.notifications.isEmpty
              ? Center(
                  child: Text(
                    "No notifications yet.",
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(notificationProvider.notifier).fetchNotifications(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: notificationState.notifications.length,
                    itemBuilder: (context, index) {
                      final notif = notificationState.notifications[index];
                      final isLowStock = notif.type == 'low_stock';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppColors.shadowSubtle,
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isLowStock ? AppColors.error.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isLowStock ? Icons.inventory_2_rounded : Icons.notifications_active_rounded,
                                color: isLowStock ? AppColors.error : AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          notif.title,
                                          style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        "${notif.createdAt.hour}:${notif.createdAt.minute.toString().padLeft(2, '0')}",
                                        style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    notif.message,
                                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

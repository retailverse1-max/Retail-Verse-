import 'package:flutter/material.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:intl/intl.dart';
import 'package:retail_verse_pos/features/super_admin/presentation/screens/sa_shell.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:retail_verse_pos/features/support/providers/support_providers.dart';

class SaSupportChatScreen extends ConsumerStatefulWidget {
  final String ticketSubject;
  final String initialMessage;

  const SaSupportChatScreen({
    super.key, 
    required this.ticketSubject,
    required this.initialMessage,
  });

  @override
  ConsumerState<SaSupportChatScreen> createState() => _SaSupportChatScreenState();
}

class _SaSupportChatScreenState extends ConsumerState<SaSupportChatScreen> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _msgC = TextEditingController();
  final ScrollController _scrollC = ScrollController();
  late String _currentSubject;

  @override
  void initState() {
    super.initState();
    _currentSubject = widget.ticketSubject;
    // Add initial user message
    _messages.add(_ChatMessage(
      text: widget.initialMessage,
      isMe: true,
      time: DateTime.now(),
    ));

    // Simulate team response
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            text: "Hello! We've received your request regarding '${widget.ticketSubject}'. A support specialist will be with you shortly. How can we assist you further today?",
            isMe: false,
            time: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollC.hasClients) {
        _scrollC.animateTo(
          _scrollC.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    if (_msgC.text.trim().isEmpty) return;
    
    setState(() {
      _messages.add(_ChatMessage(
        text: _msgC.text.trim(),
        isMe: true,
        time: DateTime.now(),
      ));
      _msgC.clear();
    });
    _scrollToBottom();

    // Simulate auto-reply for better UX
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            text: "Thank you for the update. Our team is reviewing this information and will get back to you within 24 hours.",
            isMe: false,
            time: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: (saScaffoldNavigationKey.currentState?.hasDrawer ?? false)
            ? Padding(
                padding: const EdgeInsets.only(left: 12),
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
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: const Icon(Icons.support_agent_rounded, color: AppColors.primary),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Retail Verse Support', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Always Online', style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildTicketBanner(),
          Expanded(
            child: ListView.builder(
              controller: _scrollC,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, i) => _buildMessageBubble(_messages[i]),
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildTicketBanner() {
    return InkWell(
      onTap: _showTicketSelectionSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: Colors.blue.shade50,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                "Subject: $_currentSubject",
                style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.blue.shade900),
          ],
        ),
      ),
    );
  }

  void _showTicketSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        final ticketsAsync = ref.watch(recentTicketsProvider);
        
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Select Related Ticket', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ticketsAsync.when(
                data: (tickets) {
                  if (tickets.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No active tickets found.')),
                    );
                  }
                  return Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: tickets.length,
                      itemBuilder: (context, index) {
                        final ticket = tickets[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                          title: Text(ticket.subject, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('ID: ${ticket.id} • Status: ${ticket.status.toUpperCase()}'),
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              _currentSubject = ticket.subject;
                              _messages.add(_ChatMessage(
                                text: 'Linked to ticket: ${ticket.subject}',
                                isMe: true,
                                time: DateTime.now(),
                                isSystemMessage: true,
                              ));
                            });
                            _scrollToBottom();
                          },
                        );
                      },
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text('Failed to load tickets: $e')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    if (msg.isSystemMessage) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            msg.text,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: msg.isMe ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(msg.isMe ? 20 : 0),
            bottomRight: Radius.circular(msg.isMe ? 0 : 20),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: TextStyle(color: msg.isMe ? Colors.white : AppColors.textPrimary, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                DateFormat('hh:mm a').format(msg.time),
                style: TextStyle(color: msg.isMe ? Colors.white70 : AppColors.textTertiary, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _msgC,
                decoration: const InputDecoration(
                  hintText: 'Type your message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isMe;
  final DateTime time;
  final bool isSystemMessage;
  _ChatMessage({required this.text, required this.isMe, required this.time, this.isSystemMessage = false});
}

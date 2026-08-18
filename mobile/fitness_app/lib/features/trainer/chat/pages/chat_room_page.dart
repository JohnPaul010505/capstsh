import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/clay/clay_input.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/clay/clay_avatar.dart';

class ChatRoomPage extends ConsumerStatefulWidget {
  final String roomId;
  const ChatRoomPage({super.key, required this.roomId});

  @override
  ConsumerState<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends ConsumerState<ChatRoomPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  StreamSubscription? _subscription;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _otherMemberName;
  String? _otherMemberAvatarUrl;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribe();
  }

  Future<void> _loadMessages() async {
    try {
      final client = SupabaseClientService().client;
      final userId = client.auth.currentUser!.id;

      final roomResponse = await client
          .from('chat_rooms')
          .select('participant_one, participant_two')
          .eq('id', widget.roomId)
          .single();

      final otherId = (roomResponse['participant_one'] as String?) == userId
          ? roomResponse['participant_two'] as String?
          : roomResponse['participant_one'] as String?;

      if (otherId != null) {
        try {
          final profile = await client
              .from('profiles')
              .select('full_name, avatar_url')
              .eq('id', otherId)
              .single();
          if (mounted) {
            setState(() {
              _otherMemberName = profile['full_name'] as String? ?? 'Member';
              _otherMemberAvatarUrl = profile['avatar_url'] as String?;
            });
          }
        } catch (_) {}
      }

      final response = await client
          .from('chat_messages')
          .select()
          .eq('room_id', widget.roomId)
          .order('created_at', ascending: true);
      if (mounted) {
        setState(() {
          _messages = (response as List).cast<Map<String, dynamic>>();
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribe() {
    _subscription = SupabaseClientService()
        .client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', widget.roomId)
        .order('created_at', ascending: true)
        .limit(1)
        .listen((_) => _loadMessages());
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      final userId = SupabaseClientService().client.auth.currentUser!.id;
      await SupabaseClientService().client.from('chat_messages').insert({
        'room_id': widget.roomId,
        'sender_id': userId,
        'content': text,
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = SupabaseClientService().client.auth.currentUser!.id;

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: ClayTokens.clayDarkBorder, width: 0.5)),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(CupertinoIcons.back, color: ClayTokens.clayDarkTextPrimary, size: 24),
                    ),
                    const SizedBox(width: 10),
                    if (_otherMemberName != null)
                      Expanded(
                        child: Row(
                          children: [
                            ClayAvatar(
                              imageUrl: _otherMemberAvatarUrl,
                              initials: _otherMemberName!.split(' ').map((n) => n[0]).take(2).join(),
                              size: ClayAvatarSize.md,
                            ),
                            const SizedBox(width: 10),
                            Text(_otherMemberName!, style: ClayTokens.titleLarge.copyWith(
                              fontSize: 15, fontWeight: FontWeight.w500, color: ClayTokens.clayDarkTextPrimary, letterSpacing: -0.24)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? Center(child: CupertinoActivityIndicator(radius: 12, color: ClayTokens.clayPrimary))
                    : _messages.isEmpty
                        ? Center(
                            child: Text('Start a conversation', style: ClayTokens.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: ClayTokens.clayDarkTextTertiary, letterSpacing: -0.08)))
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(12),
                            itemCount: _messages.length,
                            itemBuilder: (_, i) {
                              final msg = _messages[i];
                              final isMe = msg['sender_id'] == userId;
                              final content = msg['content'] as String? ?? '';
                              final time = msg['created_at'] as String? ?? '';
                              final timeStr = time.length >= 16 ? time.substring(11, 16) : '';

                              return Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.75),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                    decoration: BoxDecoration(
                                      color: isMe ? ClayTokens.clayPrimary : ClayTokens.clayDarkSurfaceElevated,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(14),
                                        topRight: const Radius.circular(14),
                                        bottomLeft: isMe ? const Radius.circular(14) : const Radius.circular(3),
                                        bottomRight: isMe ? const Radius.circular(3) : const Radius.circular(14),
                                      ),
                                    ),
                                    child: Text(content, style: ClayTokens.bodySmall.copyWith(
                                      fontSize: 13, fontWeight: FontWeight.w400,
                                      color: isMe ? ClayTokens.clayDarkTextPrimary : ClayTokens.clayDarkTextPrimary,
                                      letterSpacing: -0.08,
                                    )),
                                  ),
                                  if (timeStr.isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(top: 2, left: isMe ? 0 : 2, right: isMe ? 2 : 0),
                                      child: Text(timeStr, style: ClayTokens.labelMedium.copyWith(fontSize: 11, fontWeight: FontWeight.w400, color: ClayTokens.clayDarkTextTertiary, letterSpacing: -0.08)),
                                    ),
                                  const SizedBox(height: 6),
                                ],
                              );
                            },
                          ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                decoration: BoxDecoration(
                  color: ClayTokens.clayDarkBase,
                  border: Border(top: BorderSide(color: ClayTokens.clayDarkBorder.withAlpha(100))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ClayInput(
                        controller: _controller,
                        label: 'Type a message',
                        maxLines: 3,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: ClayTokens.clayPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.send, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

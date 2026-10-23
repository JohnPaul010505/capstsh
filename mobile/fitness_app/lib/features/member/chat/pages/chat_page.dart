import '../../../../shared/utils/chat_time.dart';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';

import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/glass_card.dart';

/// Resolves chat state only for the trainer selected in the route.
final trainerChatProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, trainerId) async {
      final client = SupabaseClientService().client;
      final userId = client.auth.currentUser!.id;
      final assignments = await client
          .from('trainer_assignments')
          .select('assigned_at')
          .eq('member_id', userId)
          .eq('trainer_id', trainerId)
          .eq('status', 'active')
          .order('assigned_at', ascending: false)
          .limit(1);
      if ((assignments as List).isEmpty) return null;

      final results = await Future.wait<dynamic>([
        client
            .from('profiles')
            .select('id, full_name, avatar_url, specialty, available_days')
            .eq('id', trainerId)
            .single()
            .timeout(const Duration(seconds: 5)),
        client
            .from('chat_rooms')
            .select('id')
            .or(
              'and(participant_one.eq.$userId,participant_two.eq.$trainerId),'
              'and(participant_one.eq.$trainerId,participant_two.eq.$userId)',
            )
            .limit(1),
      ]);
      final rooms = results[1] as List;
      return {
        'trainer': results[0] as Map<String, dynamic>,
        'trainerId': trainerId,
        'roomId': rooms.isEmpty ? null : rooms.first['id'] as String?,
        'assignedAt': assignments.first['assigned_at'] as String?,
      };
    });

final liveTrainerProfileProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>(
      (ref, id) => SupabaseClientService().client
          .from('profiles')
          .stream(primaryKey: ['id'])
          .eq('id', id)
          .map((rows) => rows.isEmpty ? null : rows.first),
    );

class ChatPage extends ConsumerStatefulWidget {
  final String trainerId;

  const ChatPage({super.key, required this.trainerId});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _messageController = TextEditingController();
  StreamSubscription? _subscription;
  List<Map<String, dynamic>> _messages = [];
  bool _loadingMessages = true;
  String? _roomId;
  DateTime? _assignedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initChat());
  }

  Future<void> _initChat() async {
    final data = await ref.read(trainerChatProvider(widget.trainerId).future);
    if (data == null || !mounted) return;
    _roomId = data['roomId'] as String?;
    final assignedRaw = data['assignedAt'] as String?;
    _assignedAt = assignedRaw == null ? null : DateTime.tryParse(assignedRaw);
    if (_roomId != null) {
      await _loadMessages();
      _subscribe();
    } else if (mounted) {
      setState(() => _loadingMessages = false);
    }
  }

  Future<void> _loadMessages() async {
    final roomId = _roomId;
    if (roomId == null) return;
    try {
      final response = await SupabaseClientService().client
          .from('chat_messages')
          .select()
          .eq('room_id', roomId)
          .order('created_at', ascending: true);
      if (!mounted) return;
      setState(() {
        final all = (response as List).cast<Map<String, dynamic>>();
        final cutoff = _assignedAt;
        _messages = cutoff == null
            ? all
            : all.where((message) {
                final sentAt = DateTime.tryParse(
                  message['created_at']?.toString() ?? '',
                );
                return sentAt == null || !sentAt.isBefore(cutoff);
              }).toList();
        _loadingMessages = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMessages = false);
    }
  }

  void _subscribe() {
    final roomId = _roomId;
    if (roomId == null || _subscription != null) return;
    _subscription = SupabaseClientService().client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .limit(1)
        .listen((_) => _loadMessages());
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final userId = SupabaseClientService().client.auth.currentUser!.id;
    _messageController.clear();
    try {
      _roomId ??= await _createRoom();
      await SupabaseClientService().client.from('chat_messages').insert({
        'room_id': _roomId,
        'sender_id': userId,
        'content': text,
      });
      await _loadMessages();
    } catch (_) {
      if (!mounted) return;
      _messageController.text = text;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Failed to send message. Please try again.'),
        ),
      );
    }
  }

  Future<String> _createRoom() async {
    final userId = SupabaseClientService().client.auth.currentUser!.id;
    final response = await SupabaseClientService().client
        .from('chat_rooms')
        .insert({
          'participant_one': userId,
          'participant_two': widget.trainerId,
        })
        .select('id')
        .single();
    final roomId = response['id'] as String;
    _subscribe();
    return roomId;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(trainerChatProvider(widget.trainerId));
    return Scaffold(
      backgroundColor: ClayColors.isLightMode
          ? ClayTokens.claySurfaceLight
          : ClayTokens.clayDarkSurface,
      body: AppGlowBackground(
        child: SafeArea(
          child: chatAsync.when(
            data: (data) => data == null ? _unavailable() : _conversation(data),
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFFD6A5FF)),
            ),
            error: (_, __) => _errorState(),
          ),
        ),
      ),
    );
  }

  Widget _unavailable() => Column(
    children: [
      _chatHeader(name: 'Chat', initials: null),
      Expanded(
        child: _emptyState(
          icon: CupertinoIcons.person,
          title: 'Trainer unavailable',
          detail: 'This trainer is no longer assigned to you.',
        ),
      ),
    ],
  );

  Widget _errorState() => Column(
    children: [
      _chatHeader(name: 'Chat', initials: null),
      Expanded(
        child: _emptyState(
          icon: CupertinoIcons.exclamationmark_triangle,
          title: 'Could not load chat',
          detail: 'Please try again in a moment.',
        ),
      ),
    ],
  );

  Widget _conversation(Map<String, dynamic> data) {
    final trainer =
        ref.watch(liveTrainerProfileProvider(widget.trainerId)).valueOrNull ??
        data['trainer'] as Map<String, dynamic>;
    final name = trainer['full_name'] as String? ?? 'Your Trainer';
    return Column(
      children: [
        Stack(
          children: [
            _chatHeader(name: name, initials: _initials(name)),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                tooltip: 'Trainer information',
                style: IconButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                ),
                icon: const Icon(Icons.info_outline, color: Color(0xFF7C3AED)),
                onPressed: () => _showTrainerInfo(trainer),
              ),
            ),
          ],
        ),
        Expanded(
          child: _loadingMessages
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD6A5FF)),
                )
              : _messages.isEmpty
              ? _emptyState(
                  icon: CupertinoIcons.chat_bubble,
                  title: 'Start chatting with your trainer!',
                  detail: 'Send a message below.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (_, index) =>
                      _messageBubble(_messages[index], index),
                ),
        ),
        _composer(),
      ],
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String detail,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: ClayTokens.clayDarkTextTertiary, size: 40),
          const SizedBox(height: 12),
          Text(
            title,
            style: ClayTokens.titleMedium.copyWith(
              color: ClayTokens.clayDarkTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: ClayTokens.bodySmall.copyWith(
              color: ClayTokens.clayDarkTextTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _messageBubble(Map<String, dynamic> message, int index) {
    final isMe =
        message['sender_id'] ==
        SupabaseClientService().client.auth.currentUser!.id;
    final content = message['content'] as String? ?? '';
    final time = message['created_at'] as String? ?? '';
    final timeStr = formatChatTime(time);
    return StaggeredFadeIn(
      index: index,
      offset: const Offset(0, 8),
      delay: const Duration(milliseconds: 20),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isMe
                  ? const Color(0xFF7C3AED)
                  : ClayTokens.clayDarkSurfaceElevated,
              border: !isMe
                  ? Border.all(color: ClayTokens.clayDarkBorder.withAlpha(110))
                  : null,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: isMe
                    ? const Radius.circular(18)
                    : const Radius.circular(4),
                bottomRight: isMe
                    ? const Radius.circular(4)
                    : const Radius.circular(18),
              ),
            ),
            child: Text(
              content,
              style: ClayTokens.bodySmall.copyWith(
                color: isMe ? Colors.white : ClayTokens.clayDarkTextPrimary,
              ),
            ),
          ),
          if (timeStr.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                top: 2,
                left: isMe ? 0 : 2,
                right: isMe ? 2 : 0,
              ),
              child: Text(
                timeStr,
                style: ClayTokens.labelSmall.copyWith(
                  color: ClayTokens.clayDarkTextTertiary,
                ),
              ),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _composer() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
    child: Row(
      children: [
        Expanded(
          child: GlassSurface(
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(14),
            child: TextField(
              controller: _messageController,
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              style: ClayTokens.bodyMedium.copyWith(
                color: ClayTokens.clayDarkTextPrimary,
              ),
              cursorColor: ClayTokens.clayPrimary,
              decoration: InputDecoration(
                hintText: 'Message your trainer',
                hintStyle: ClayTokens.bodyMedium.copyWith(
                  color: ClayTokens.clayDarkTextTertiary,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _sendMessage,
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFF7C3AED),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send, color: Colors.white, size: 16),
          ),
        ),
      ],
    ),
  );

  Widget _chatHeader({required String name, required String? initials}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: ClayTokens.clayDarkBorder)),
        ),
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _goBack,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Icon(
                  CupertinoIcons.back,
                  color: ClayTokens.clayDarkTextPrimary,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF7C3AED)],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initials ?? '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: ClayTokens.titleMedium.copyWith(
                      color: ClayTokens.clayDarkTextPrimary,
                    ),
                  ),
                  if (initials != null)
                    Text(
                      'Your Trainer',
                      style: ClayTokens.labelSmall.copyWith(
                        color: ClayTokens.clayDarkTextTertiary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );

  Future<void> _showTrainerInfo(Map<String, dynamic> trainer) async {
    final client = SupabaseClientService().client;
    final profiles = client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', widget.trainerId);
    final ratings = await client
        .from('trainer_feedback')
        .select('rating')
        .eq('trainer_id', widget.trainerId);
    if (!mounted) return;
    final values = (ratings as List)
        .map((row) => row['rating'])
        .whereType<num>()
        .toList();
    final rating = values.isEmpty
        ? 'No ratings yet'
        : '${(values.reduce((a, b) => a + b) / values.length).toStringAsFixed(1)} / 5 · ${values.length} ratings';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: profiles,
          builder: (context, snapshot) {
            final profile = snapshot.data?.firstOrNull ?? trainer;
            return MemberGlassCard(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      profile['full_name']?.toString() ?? 'Trainer',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: ClayTokens.clayDarkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Icon(
                      Icons.star_rounded,
                      color: const Color(0xFF7C3AED),
                      size: 32,
                    ),
                    Text(
                      rating,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ClayTokens.clayDarkTextPrimary),
                    ),
                    const Divider(height: 28),
                    Text(
                      'Specialty',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: ClayTokens.clayDarkTextSecondary,
                      ),
                    ),
                    Text(
                      profile['specialty']?.toString() ?? 'Not specified',
                      style: TextStyle(color: ClayTokens.clayDarkTextPrimary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Availability',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: ClayTokens.clayDarkTextSecondary,
                      ),
                    ),
                    for (final day
                        in (profile['available_days']?.toString() ??
                                'Schedule not provided')
                            .split(','))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              size: 18,
                              color: Color(0xFF7C3AED),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                day.trim(),
                                style: TextStyle(
                                  color: ClayTokens.clayDarkTextPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _initials(String name) => name
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0])
      .take(2)
      .join();

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/member/chat');
    }
  }
}

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/clay/clay_input.dart';
import '../../../../app/design_tokens.dart';

final trainerChatProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser!.id;
  final client = SupabaseClientService().client;

  final assignment = await client
      .from('trainer_assignments')
      .select('trainer_id')
      .eq('member_id', userId)
      .eq('status', 'active')
      .limit(1);

  if ((assignment as List).isEmpty) return null;

  final trainerId = assignment[0]['trainer_id'] as String;

  final trainerResp = await client
      .from('profiles')
      .select('id, full_name')
      .eq('id', trainerId)
      .single()
      .timeout(const Duration(seconds: 5));

  final trainer = trainerResp;

  final existingRoom = await client
      .from('chat_rooms')
      .select('id')
      .or('participant_one.eq.$userId,participant_two.eq.$userId')
      .or('participant_one.eq.$trainerId,participant_two.eq.$trainerId')

      .limit(1);

  String? roomId;
  if ((existingRoom as List).isNotEmpty) {
    roomId = existingRoom[0]['id'] as String;
  }

  return {
    'trainer': trainer,
    'trainerId': trainerId,
    'roomId': roomId,
  };
});

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _messageController = TextEditingController();
  StreamSubscription? _subscription;
  List<Map<String, dynamic>> _messages = [];
  bool _loadingMessages = true;
  String? _roomId;
  String? _trainerId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initChat());
  }

  Future<void> _initChat() async {
    final data = await ref.read(trainerChatProvider.future);
    if (data == null || !mounted) return;

    _trainerId = data['trainerId'] as String?;
    _roomId = data['roomId'] as String?;

    if (_roomId != null) {
      await _loadMessages();
      _subscribe();
    } else {
      setState(() => _loadingMessages = false);
    }
  }

  Future<void> _loadMessages() async {
    final roomId = _roomId;
    if (roomId == null) return;
    try {
      final response = await SupabaseClientService()
          .client
          .from('chat_messages')
          .select()
          .eq('room_id', roomId)
          .order('created_at', ascending: true);
      if (mounted) {
        setState(() {
          _messages = (response as List).cast<Map<String, dynamic>>();
          _loadingMessages = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMessages = false);
    }
  }

  void _subscribe() {
    final roomId = _roomId;
    if (roomId == null) return;
    _subscription = SupabaseClientService()
        .client
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
      if (_roomId == null) {
        _roomId = await _createRoom();
      }

      await SupabaseClientService().client.from('chat_messages').insert({
        'room_id': _roomId,
        'sender_id': userId,
        'content': text,
      });

      await _loadMessages();
    } catch (_) {}
  }

  Future<String> _createRoom() async {
    final userId = SupabaseClientService().client.auth.currentUser!.id;
    final response = await SupabaseClientService().client.from('chat_rooms').insert({
      'participant_one': userId,
      'participant_two': _trainerId,
    }).select('id').single();

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
    final chatAsync = ref.watch(trainerChatProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: chatAsync.when(
          data: (data) {
            if (data == null) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF636366).withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(CupertinoIcons.person, color: Color(0xFF8E8E93), size: 32),
                    ),
                    const SizedBox(height: 16),
                    const Text('No trainer assigned', style: TextStyle(color: Color(0xFF636366), fontSize: 14)),
                    const SizedBox(height: 4),
                    const Text('Contact the gym to get paired with a trainer',
                      style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final trainer = data['trainer'] as Map<String, dynamic>;
            final name = trainer['full_name'] as String? ?? 'Your Trainer';
            final initials = name.split(' ').map((n) => n[0]).take(2).join();

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFF38383A))),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFFBF5AF2), Color(0xFFD6A5FF)],
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(initials, style: const TextStyle(
                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700,
                            )),
                          ),
                          Positioned(
                            right: 0, bottom: 0,
                            child: Container(
                              width: 10, height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFF30D158),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFFFFFFF),
                          )),
                          const Text('Your Trainer', style: TextStyle(
                            fontSize: 10, color: Color(0xFF8E8E93),
                          )),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loadingMessages
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFD6A5FF)))
                      : _messages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(CupertinoIcons.chat_bubble, color: Color(0xFF8E8E93), size: 40),
                                  const SizedBox(height: 12),
                                  const Text('Start chatting with your trainer!', style: TextStyle(color: Color(0xFF636366), fontSize: 12)),
                                  const SizedBox(height: 4),
                                  const Text('Send a message below', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 10)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _messages.length,
                              itemBuilder: (_, i) {
                                final msg = _messages[i];
                                final isMe = msg['sender_id'] == SupabaseClientService().client.auth.currentUser!.id;
                                final content = msg['content'] as String? ?? '';
                                final time = msg['created_at'] as String? ?? '';
                                final timeStr = time.length >= 16 ? time.substring(11, 16) : '';

                                return StaggeredFadeIn(
                                  index: i,
                                  offset: const Offset(0, 8),
                                  delay: const Duration(milliseconds: 20),
                                  child: Column(
                                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                      decoration: BoxDecoration(
                                        color: isMe ? const Color(0xFF0A84FF) : const Color(0xFF2C2C2E),
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(18),
                                          topRight: const Radius.circular(18),
                                          bottomLeft: isMe ? const Radius.circular(18) : Radius.circular(4),
                                          bottomRight: isMe ? Radius.circular(4) : const Radius.circular(18),
                                        ),
                                      ),
                                      child: Text(content, style: const TextStyle(
                                        fontSize: 12, height: 1.4,
                                        color: Color(0xFFFFFFFF),
                                      )),
                                    ),
                                    if (timeStr.isNotEmpty)
                                      Padding(
                                        padding: EdgeInsets.only(top: 2, left: isMe ? 0 : 2, right: isMe ? 2 : 0),
                                        child: Text(timeStr, style: const TextStyle(
                                          fontSize: 9, color: Color(0xFF8E8E93),
                                        )),
                                      ),
                                    const SizedBox(height: 6),
                                  ],
                                ),
                              );
                            },
                          ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                  child: Row(
                    children: [
                      Expanded(
                    child: ClayInput(
                      controller: _messageController,
                      label: 'Message your trainer',
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
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFD6A5FF)),
          ),
          error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Color(0xFF636366)))),
        ),
      ),
    );
  }
}

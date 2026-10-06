import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared/services/feedback_service.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/clay/clay_card.dart';

/// Feedback the trainer has written for this member (Figure 20), newest first.
/// The trainer's name is embedded through the trainer_id foreign key.
final trainerFeedbackProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser!.id;
  final response = await SupabaseClientService()
      .client
      .from('trainer_feedback')
      .select('*, trainer:profiles!trainer_feedback_trainer_id_fkey(full_name)')
      .eq('member_id', userId)
      .order('created_at', ascending: false);
  return (response as List).cast<Map<String, dynamic>>();
});

class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({super.key});

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage> {
  String? _ratingInProgress;
  // The feedback id whose comment box is open (one editor at a time).
  String? _editingId;
  // The feedback id with a save in flight.
  String? _commentSaving;

  /// The member's single comment on a piece of the trainer's feedback.
  ///
  /// [text] comes from the open card's own editor (a draft owned by the
  /// card, not the page), so typing is never lost and a blank draft can never
  /// reach the network.
  Future<void> _saveComment(Map<String, dynamic> feedback, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final id = feedback['id'] as String;
    setState(() => _commentSaving = id);
    try {
      await FeedbackService().addMemberComment(
        feedbackId: id,
        comment: trimmed,
      );
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _editingId = null);
      ref.invalidate(trainerFeedbackProvider);
    } catch (e) {
      // Surface the backend message (missing 0038 columns vs RLS deny).
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _commentSaving = null);
    }
  }

  /// Figure 20: "If the Member provides a star rating from one to five, the
  /// system saves the rating." RLS + the guard trigger restrict the update to
  /// the rating/rated_at columns of the member's own rows.
  Future<void> _rate(Map<String, dynamic> feedback, int stars) async {
    final id = feedback['id'] as String;
    setState(() => _ratingInProgress = id);
    try {
      await FeedbackService().rateTrainer(feedbackId: id, rating: stars);
      HapticFeedback.mediumImpact();
      ref.invalidate(trainerFeedbackProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Could not save your rating. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _ratingInProgress = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedbackAsync = ref.watch(trainerFeedbackProvider);

    return CupertinoPageScaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      child: AppGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader('Feedback'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'Feedback from your trainer',
                        style: ClayTokens.headlineMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: ClayTokens.clayDarkTextPrimary,
                          letterSpacing: -0.36,
                        ),
                      ),
                    ),
                    feedbackAsync.when(
                      data: (feedback) => feedback.isEmpty
                          ? ClayCard(
                              variant: ClayCardVariant.outlined,
                              backgroundColor: ClayTokens.clayPrimaryLight.withAlpha(25),
                              customPadding: const EdgeInsets.all(20),
                              padding: ClayCardPadding.none,
                              borderRadius: BorderRadius.circular(16),
                              child: const Column(
                                children: [
                                  Icon(Icons.rate_review_outlined, color: Color(0xFF7070A0), size: 28),
                                  SizedBox(height: 8),
                                  Text(
                                    'No feedback from your trainer yet.\nIt will appear here after your next session.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: Color(0xFF7070A0), height: 1.5),
                                  ),
                                ],
                              ),
                            )
                          : ClayCard(
                              variant: ClayCardVariant.outlined,
                              backgroundColor: ClayTokens.clayPrimaryLight.withAlpha(25),
                              customPadding: const EdgeInsets.all(16),
                              padding: ClayCardPadding.none,
                              borderRadius: BorderRadius.circular(16),
                              child: Column(
                                children: feedback.asMap().entries.map((entry) {
                                  final isLast = entry.key == feedback.length - 1;
                                  return Column(
                                    children: [
                                      _FeedbackEntry(
                                        feedback: entry.value,
                                        busy: _ratingInProgress == entry.value['id'],
                                        onRate: (stars) => _rate(entry.value, stars),
                                        editing: _editingId == entry.value['id'],
                                        commentSaving: _commentSaving == entry.value['id'],
                                        onEditComment: () => setState(() => _editingId = entry.value['id'] as String),
                                        onCancelComment: () => setState(() => _editingId = null),
                                        onSaveComment: (text) => _saveComment(entry.value, text),
                                      ),
                                      if (!isLast) const Divider(color: Color(0xFF38383A), height: 1),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CupertinoActivityIndicator(),
                        ),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Error: $e',
                          style: ClayTokens.bodyMedium.copyWith(color: ClayTokens.clayError),
                        ),
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

  Widget _buildHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => context.pop(),
            child: const Icon(CupertinoIcons.back, color: Colors.white),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: ClayTokens.titleLarge.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: ClayTokens.clayDarkTextPrimary,
                letterSpacing: -0.41,
              ),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }
}

class _FeedbackEntry extends StatelessWidget {
  final Map<String, dynamic> feedback;
  final bool busy;
  final ValueChanged<int> onRate;
  final bool editing;
  final bool commentSaving;
  final VoidCallback onEditComment;
  final VoidCallback onCancelComment;
  final ValueChanged<String> onSaveComment;

  const _FeedbackEntry({
    required this.feedback,
    required this.busy,
    required this.onRate,
    required this.editing,
    required this.commentSaving,
    required this.onEditComment,
    required this.onCancelComment,
    required this.onSaveComment,
  });

  @override
  Widget build(BuildContext context) {
    final trainer = (feedback['trainer'] as Map<String, dynamic>?)?['full_name'] as String? ?? 'Trainer';
    final content = feedback['content'] as String? ?? '';
    final createdAt = DateTime.tryParse(feedback['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now();
    final rating = feedback['rating'] as int?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: ClayTokens.clayPrimary.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fitness_center, color: Color(0xFFA78BFA), size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trainer,
                  style: ClayTokens.titleLarge.copyWith(
                    fontSize: 14, fontWeight: FontWeight.w600, color: ClayTokens.clayDarkTextPrimary,
                  ),
                ),
              ),
              Text(
                DateFormat('MMM d, yyyy').format(createdAt),
                style: ClayTokens.titleMedium.copyWith(fontSize: 11, color: ClayTokens.clayDarkTextTertiary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: ClayTokens.titleLarge.copyWith(
              fontSize: 13, color: ClayTokens.clayDarkTextPrimary, height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          _StarSelector(current: rating, busy: busy, onRate: onRate),
          const SizedBox(height: 12),
          _MemberComment(
            feedback: feedback,
            editing: editing,
            saving: commentSaving,
            onEdit: onEditComment,
            onCancel: onCancelComment,
            onSave: onSaveComment,
          ),
        ],
      ),
    );
  }
}

class _MemberComment extends StatefulWidget {
  final Map<String, dynamic> feedback;
  final bool editing;
  final bool saving;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final ValueChanged<String> onSave;

  const _MemberComment({
    required this.feedback,
    required this.editing,
    required this.saving,
    required this.onEdit,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_MemberComment> createState() => _MemberCommentState();
}

class _MemberCommentState extends State<_MemberComment> {
  late final TextEditingController _controller;

  /// The draft lives in the card, not the page, so typing survives parent
  /// rebuilds (rating taps, provider refreshes) while the box stays open.
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: (widget.feedback['member_comment'] as String?) ?? '',
    );
  }

  /// A freshly saved comment arrives as a new map after the refresh — adopt
  /// it so a reopened editor shows saved text, never clobbering a draft.
  @override
  void didUpdateWidget(covariant _MemberComment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.editing &&
        widget.feedback['member_comment'] !=
            oldWidget.feedback['member_comment']) {
      _controller.text = (widget.feedback['member_comment'] as String?) ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saved = (widget.feedback['member_comment'] as String?)?.trim() ?? '';
    if (widget.editing) return _buildEditor();
    if (saved.isNotEmpty) return _buildSaved(saved);
    return _buildEmpty();
  }

  /// The saved comment reads as the member's own bubble.
  Widget _buildSaved(String saved) {
    final commentedAt = DateTime.tryParse(
      widget.feedback['member_commented_at']?.toString() ?? '',
    )?.toLocal();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: ClayTokens.clayPrimary.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _buildSavedBody(saved, commentedAt),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            onPressed: widget.onEdit,
            child: _editLabel(),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedBody(String saved, DateTime? commentedAt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your comment',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFFA78BFA),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          saved,
          style: ClayTokens.titleLarge.copyWith(
            fontSize: 13,
            color: ClayTokens.clayDarkTextPrimary,
            height: 1.5,
          ),
        ),
        if (commentedAt != null) ...[
          const SizedBox(height: 4),
          Text(
            DateFormat('MMM d, yyyy').format(commentedAt),
            style: ClayTokens.titleMedium.copyWith(
              fontSize: 11,
              color: ClayTokens.clayDarkTextTertiary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _editLabel() {
    return const Text(
      'Edit',
      style: TextStyle(fontSize: 12, color: Color(0xFFA78BFA)),
    );
  }

  Widget _buildEmpty() {
    return Align(
      alignment: Alignment.centerLeft,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        onPressed: widget.onEdit,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.chat_bubble,
              size: 14,
              color: Color(0xFFA78BFA),
            ),
            SizedBox(width: 6),
            Text(
              'Write a comment',
              style: TextStyle(fontSize: 12, color: Color(0xFFA78BFA)),
            ),
          ],
        ),
      ),
    );
  }

  /// Save stays disabled on a blank draft so whitespace never reaches the
  /// network; the service maps missing 0038 columns vs RLS deny and the
  /// page surfaces that message.
  Widget _buildEditor() {
    final canSave = _controller.text.trim().isNotEmpty && !widget.saving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CupertinoTextField(
          controller: _controller,
          autofocus: true,
          maxLines: 3,
          minLines: 2,
          placeholder: 'Share your thoughts with your trainer...',
          onChanged: (_) => setState(() {}),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF38383A)),
          ),
          style: const TextStyle(fontSize: 13, color: Colors.white),
          placeholderStyle: const TextStyle(
            fontSize: 13,
            color: Color(0xFF8E8E93),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              onPressed: widget.saving ? null : widget.onCancel,
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
              ),
            ),
            const SizedBox(width: 4),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: const Color(0xFFA78BFA),
              borderRadius: BorderRadius.circular(10),
              onPressed:
                  canSave ? () => widget.onSave(_controller.text) : null,
              child: widget.saving
                  ? const CupertinoActivityIndicator(
                      radius: 7,
                      color: Colors.white,
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StarSelector extends StatelessWidget {
  final int? current;
  final bool busy;
  final ValueChanged<int> onRate;

  const _StarSelector({required this.current, required this.busy, required this.onRate});

  @override
  Widget build(BuildContext context) {
    final rated = current != null;
    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            onTap: busy ? null : () => onRate(i),
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                (current ?? 0) >= i ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 26,
                color: (current ?? 0) >= i ? const Color(0xFFFFC107) : const Color(0xFF5A5A78),
              ),
            ),
          ),
        const SizedBox(width: 6),
        Text(
          rated ? 'You rated $current\u2605' : 'Tap a star to rate your trainer',
          style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
        ),
        if (busy) ...[
          const SizedBox(width: 8),
          const CupertinoActivityIndicator(radius: 6),
        ],
      ],
    );
  }
}

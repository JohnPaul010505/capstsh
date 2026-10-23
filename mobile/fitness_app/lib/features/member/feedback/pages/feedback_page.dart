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
import '../../../shared/widgets/glass_card.dart';

/// Every active trainer assigned to the signed-in member.
final feedbackTrainersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final client = SupabaseClientService().client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return [];
      final rows = await client
          .from('trainer_assignments')
          .select(
            'trainer_id, profiles!trainer_assignments_trainer_id_fkey(full_name)',
          )
          .eq('member_id', userId)
          .eq('status', 'active')
          .order('assigned_at', ascending: false);
      return (rows as List).cast<Map<String, dynamic>>();
    });

/// Feedback from all active assigned trainers, newest first.
final trainerFeedbackProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final trainers = await ref.watch(feedbackTrainersProvider.future);
      final userId = SupabaseClientService().client.auth.currentUser?.id;
      if (userId == null || trainers.isEmpty) return [];
      final trainerIds = trainers.map((row) => row['trainer_id']).toSet();
      final rows = await FeedbackService().getFeedbackWithTrainer(userId);
      return rows
          .where((row) => trainerIds.contains(row['trainer_id']))
          .toList();
    });

class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({super.key});

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage> {
  String? _selectedTrainerId;
  static const _pageSize = 5;
  int _page = 0;
  final _scrollController = ScrollController();

  void _changePage(int page) {
    setState(() {
      _page = page;
      _editingId = null;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  String? _ratingInProgress;
  // The feedback id whose comment box is open (one editor at a time).
  String? _editingId;
  // The feedback id with a save in flight.
  String? _commentSaving;
  // Refresh-on-return: the shell keeps this page alive, so a router listener
  // refetches when coming back (e.g. after tapping a new-feedback
  // notification) while cached rows render instantly.
  GoRouter? _router;
  bool _wasFeedback = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_router == null) {
      _router = GoRouter.of(context);
      _router!.routerDelegate.addListener(_onRouteChanged);
    }
  }

  void _onRouteChanged() {
    final isFeedback =
        _router!.routerDelegate.currentConfiguration.uri.path ==
        '/member/feedback';
    if (isFeedback && !_wasFeedback && mounted) {
      ref.invalidate(feedbackTrainersProvider);
    }
    _wasFeedback = isFeedback;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _router?.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

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
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text('$e')));
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
          const SnackBar(
            content: Text('Could not save your rating. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _ratingInProgress = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trainersAsync = ref.watch(feedbackTrainersProvider);
    final trainers = trainersAsync.valueOrNull ?? [];
    final selectedTrainerId =
        trainers.any((row) => row['trainer_id'] == _selectedTrainerId)
        ? _selectedTrainerId
        : null;
    final feedbackAsync = ref
        .watch(trainerFeedbackProvider)
        .whenData(
          (rows) => selectedTrainerId == null
              ? rows
              : rows
                    .where((row) => row['trainer_id'] == selectedTrainerId)
                    .toList(),
        );

    final total = feedbackAsync.valueOrNull?.length ?? 0;
    final pageCount = (total / _pageSize).ceil().clamp(1, 1 << 30);
    final currentPage = _page.clamp(0, pageCount - 1);
    final pageFeedback = feedbackAsync.whenData(
      (rows) => rows.skip(currentPage * _pageSize).take(_pageSize).toList(),
    );

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: AppGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader('Feedback'),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(feedbackTrainersProvider);
                    await ref.read(trainerFeedbackProvider.future);
                  },
                  child: ListView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
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
                      if (trainers.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: MemberGlassCard(
                            padding: EdgeInsets.zero,
                            child: Material(
                              type: MaterialType.transparency,
                              child: LayoutBuilder(
                                builder: (context, bounds) => PopupMenuButton<String>(
                                  key: const ValueKey(
                                    'feedback-trainer-filter',
                                  ),
                                  tooltip: 'Filter by trainer',
                                  position: PopupMenuPosition.under,
                                  offset: const Offset(0, 8),
                                  constraints: BoxConstraints(
                                    minWidth: bounds.maxWidth,
                                    maxWidth: bounds.maxWidth,
                                    maxHeight: 320,
                                  ),
                                  color: Theme.of(context).colorScheme.surface,
                                  surfaceTintColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  itemBuilder: (_) => [
                                    for (final option in [
                                      {'id': '', 'name': 'All trainers'},
                                      ...trainers.map(
                                        (row) => {
                                          'id': row['trainer_id'] as String,
                                          'name':
                                              (row['profiles']
                                                      as Map?)?['full_name']
                                                  as String? ??
                                              'Trainer',
                                        },
                                      ),
                                    ])
                                      PopupMenuItem<String>(
                                        value: option['id'],
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                option['name']!,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (option['id'] ==
                                                (selectedTrainerId ?? ''))
                                              Icon(
                                                Icons.check_rounded,
                                                size: 20,
                                                color: ClayTokens.clayPrimary,
                                              ),
                                          ],
                                        ),
                                      ),
                                  ],
                                  onSelected: (value) {
                                    setState(() {
                                      _selectedTrainerId = value.isEmpty
                                          ? null
                                          : value;
                                    });
                                    _changePage(0);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.people_outline,
                                          size: 20,
                                          color: ClayTokens.clayPrimary,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            selectedTrainerId == null
                                                ? 'All trainers'
                                                : (trainers.firstWhere(
                                                                (row) =>
                                                                    row['trainer_id'] ==
                                                                    selectedTrainerId,
                                                              )['profiles']
                                                              as Map?)?['full_name']
                                                          as String? ??
                                                      'Trainer',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: ClayTokens
                                                  .clayDarkTextPrimary,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color:
                                              ClayTokens.clayDarkTextSecondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      pageFeedback.when(
                        data: (feedback) => feedback.isEmpty
                            ? MemberGlassCard(
                                padding: const EdgeInsets.all(20),
                                borderRadius: BorderRadius.circular(16),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.rate_review_outlined,
                                      color: ClayTokens.clayDarkTextTertiary,
                                      size: 28,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      trainers.isEmpty
                                          ? 'No trainers assigned yet.'
                                          : selectedTrainerId == null
                                          ? 'No feedback from your trainers yet.'
                                          : 'No feedback from this trainer yet.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: ClayTokens.clayDarkTextTertiary,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : MemberGlassCard(
                                padding: const EdgeInsets.all(16),
                                borderRadius: BorderRadius.circular(16),
                                child: Column(
                                  children: feedback.asMap().entries.map((
                                    entry,
                                  ) {
                                    final isLast =
                                        entry.key == feedback.length - 1;
                                    return Column(
                                      children: [
                                        _FeedbackEntry(
                                          feedback: entry.value,
                                          busy:
                                              _ratingInProgress ==
                                              entry.value['id'],
                                          onRate: (stars) =>
                                              _rate(entry.value, stars),
                                          editing:
                                              _editingId == entry.value['id'],
                                          commentSaving:
                                              _commentSaving ==
                                              entry.value['id'],
                                          onEditComment: () => setState(
                                            () => _editingId =
                                                entry.value['id'] as String,
                                          ),
                                          onCancelComment: () =>
                                              setState(() => _editingId = null),
                                          onSaveComment: (text) =>
                                              _saveComment(entry.value, text),
                                        ),
                                        if (!isLast)
                                          Divider(
                                            color: glassLine(
                                              const Color(0xFF38383A),
                                            ),
                                            height: 1,
                                          ),
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
                            style: ClayTokens.bodyMedium.copyWith(
                              color: ClayTokens.clayError,
                            ),
                          ),
                        ),
                      ),
                      if (total > _pageSize)
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 12),
                          child: MemberGlassCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${currentPage * _pageSize + 1}\u2013${((currentPage + 1) * _pageSize).clamp(0, total)} of $total',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ClayTokens.clayDarkTextSecondary,
                                    ),
                                  ),
                                ),
                                CupertinoButton(
                                  padding: const EdgeInsets.all(10),
                                  onPressed: currentPage > 0
                                      ? () => _changePage(currentPage - 1)
                                      : null,
                                  child: const Icon(
                                    CupertinoIcons.chevron_left,
                                    semanticLabel: 'Previous feedback page',
                                    size: 18,
                                  ),
                                ),
                                Text(
                                  '${currentPage + 1} / $pageCount',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ClayTokens.clayDarkTextPrimary,
                                  ),
                                ),
                                CupertinoButton(
                                  padding: const EdgeInsets.all(10),
                                  onPressed: currentPage + 1 < pageCount
                                      ? () => _changePage(currentPage + 1)
                                      : null,
                                  child: const Icon(
                                    CupertinoIcons.chevron_right,
                                    semanticLabel: 'Next feedback page',
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  Widget _buildHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => context.pop(),
            child: Icon(
              CupertinoIcons.back,
              color: ClayTokens.clayDarkTextPrimary,
            ),
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
    final trainer =
        (feedback['trainer'] as Map<String, dynamic>?)?['full_name']
            as String? ??
        'Trainer';
    final content = feedback['content'] as String? ?? '';
    final createdAt =
        DateTime.tryParse(
          feedback['created_at']?.toString() ?? '',
        )?.toLocal() ??
        DateTime.now();
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
                child: const Icon(
                  Icons.fitness_center,
                  color: Color(0xFFA78BFA),
                  size: 15,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trainer,
                  style: ClayTokens.titleLarge.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ClayTokens.clayDarkTextPrimary,
                  ),
                ),
              ),
              Text(
                DateFormat('MMM d, yyyy').format(createdAt),
                style: ClayTokens.titleMedium.copyWith(
                  fontSize: 11,
                  color: ClayTokens.clayDarkTextTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: ClayTokens.titleLarge.copyWith(
              fontSize: 13,
              color: ClayTokens.clayDarkTextPrimary,
              height: 1.5,
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
            color: ClayColors.isLightMode
                ? Colors.white
                : const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: glassLine(const Color(0xFF38383A))),
          ),
          style: TextStyle(fontSize: 13, color: ClayTokens.clayDarkTextPrimary),
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
              onPressed: canSave ? () => widget.onSave(_controller.text) : null,
              child: widget.saving
                  ? CupertinoActivityIndicator(
                      radius: 7,
                      color: ClayTokens.clayDarkTextPrimary,
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ClayTokens.clayDarkTextPrimary,
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

  const _StarSelector({
    required this.current,
    required this.busy,
    required this.onRate,
  });

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
                (current ?? 0) >= i
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 26,
                color: (current ?? 0) >= i
                    ? const Color(0xFFFFC107)
                    : const Color(0xFF5A5A78),
              ),
            ),
          ),
        const SizedBox(width: 6),
        Text(
          rated
              ? 'You rated $current\u2605'
              : 'Tap a star to rate your trainer',
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

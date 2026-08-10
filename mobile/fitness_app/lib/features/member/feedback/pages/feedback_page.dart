import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';

final feedbackListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser!.id;
  final response = await SupabaseClientService()
      .client
      .from('trainer_feedback')
      .select()
      .eq('member_id', userId)
      .order('created_at', ascending: false);
  return response;
});

class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({super.key});

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage> {
  final _contentController = TextEditingController();
  bool _saving = false;

  Future<void> _submit() async {
    if (_contentController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final userId = SupabaseClientService().client.auth.currentUser!.id;
    await SupabaseClientService().client.from('trainer_feedback').insert({
      'member_id': userId,
      'content': _contentController.text.trim(),
    });
    _contentController.clear();
    ref.invalidate(feedbackListProvider);
    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedbackAsync = ref.watch(feedbackListProvider);

    return CupertinoPageScaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader('Feedback'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  _buildSubmitCard(),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'History',
                      style: ClayTokens.headlineMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: ClayTokens.clayDarkTextPrimary,
                        letterSpacing: -0.36,
                      ),
                    ),
                  ),
                  feedbackAsync.when(
                    data: (feedback) => feedback.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: ClayTokens.clayDarkSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: ClayTokens.clayDarkBorder),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.feedback_outlined, color: Color(0xFF7070A0), size: 28),
                                SizedBox(height: 8),
                                Text(
                                  'No feedback yet.\nYour submitted feedback will appear here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF7070A0),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: ClayTokens.clayDarkSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: ClayTokens.clayDarkBorder),
                            ),
                            child: Column(
                              children: feedback.asMap().entries.map((entry) {
                                final f = entry.value;
                                final isLast = entry.key == feedback.length - 1;
                                return Column(
                                  children: [
                                    _feedbackRow(f),
                                    if (!isLast)
                                      const SizedBox(height: 0.5),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                    loading: () => const Center(child: CupertinoActivityIndicator()),
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
    );
  }

  Widget _buildSubmitCard() {
    return Container(
      decoration: BoxDecoration(
        color: ClayTokens.clayDarkSurface,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: ClayTokens.clayDarkBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: ClayTokens.clayPrimary.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.feedback_outlined,
                    color: Color(0xFF7C3AED),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Submit Feedback',
                  style: ClayTokens.titleLarge.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: ClayTokens.clayDarkTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: _contentController,
              placeholder: 'Share your thoughts about your workouts...',
              placeholderStyle: ClayTokens.bodyMedium.copyWith(color: ClayTokens.clayDarkTextTertiary),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: ClayTokens.clayDarkSurfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              maxLines: 4,
              cursorColor: ClayTokens.clayPrimary,
              style: ClayTokens.bodyMedium.copyWith(color: ClayTokens.clayDarkTextPrimary),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF5E3AEE), Color(0xFFC56BF0)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                borderRadius: BorderRadius.circular(12),
                onPressed: (_saving || _contentController.text.trim().isEmpty) ? null : _submit,
                child: _saving
                    ? const Center(child: CupertinoActivityIndicator(color: Colors.white))
                    : const Center(
                        child: Text(
                          'Submit',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedbackRow(Map<String, dynamic> f) {
    final createdAt =
        DateTime.tryParse(f['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 14),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: ClayTokens.clayPrimary.withAlpha(20),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.subject,
              color: Color(0xFFA78BFA),
              size: 16,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 12, right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f['content'] ?? '',
                  style: ClayTokens.titleLarge.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: ClayTokens.clayDarkTextPrimary,
                    letterSpacing: -0.41,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d, yyyy · h:mm a').format(createdAt),
                  style: ClayTokens.titleMedium.copyWith(
                    fontSize: 12,
                    color: ClayTokens.clayDarkTextTertiary,
                    letterSpacing: -0.24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
              color: ClayTokens.clayPrimary,
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
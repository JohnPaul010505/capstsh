import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    setState(() => _saving = false);
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
                  Container(
                    decoration: BoxDecoration(
                      color: ClayTokens.clayDarkSurface,
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Submit Feedback',
                            style: ClayTokens.titleLarge.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: ClayTokens.clayDarkTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          CupertinoTextField(
                            controller: _contentController,
                            placeholder: 'Your feedback...',
                            placeholderStyle: ClayTokens.bodyMedium.copyWith(color: ClayTokens.clayDarkTextTertiary),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: ClayTokens.clayDarkSurfaceElevated,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            maxLines: 4,
                            cursorColor: ClayTokens.clayPrimary,
                            style: ClayTokens.bodyMedium.copyWith(color: ClayTokens.clayDarkTextPrimary),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: CupertinoButton(
                              color: ClayTokens.clayPrimary,
                              borderRadius: BorderRadius.circular(12),
                              onPressed: _saving ? null : _submit,
                              child: _saving
                                  ? CupertinoActivityIndicator(color: ClayTokens.clayDarkTextPrimary)
                                  : Text(
                                      'Submit',
                                      style: ClayTokens.titleLarge.copyWith(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: ClayTokens.clayDarkTextPrimary,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                    data: (feedback) => Container(
                      decoration: BoxDecoration(
                        color: ClayTokens.clayDarkSurface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: feedback.asMap().entries.map((entry) {
                          final f = entry.value;
                          final isLast = entry.key == feedback.length - 1;
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            f['content'] ?? '',
                                            style: ClayTokens.titleLarge.copyWith(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w500,
                                              color: ClayTokens.clayDarkTextPrimary,
                                              letterSpacing: -0.41,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            f['created_at']?.toString().substring(0, 10) ?? '',
                                            style: ClayTokens.titleMedium.copyWith(
                                              fontSize: 15,
                                              color: ClayTokens.clayDarkTextTertiary,
                                              letterSpacing: -0.24,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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

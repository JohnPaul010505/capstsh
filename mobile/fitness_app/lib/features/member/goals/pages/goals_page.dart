import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';

final goalsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser!.id;
  final response = await SupabaseClientService()
      .client
      .from('goals')
      .select()
      .eq('member_id', userId)
      .order('created_at', ascending: false);
  return response;
});

class GoalsPage extends ConsumerStatefulWidget {
  const GoalsPage({super.key});

  @override
  ConsumerState<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends ConsumerState<GoalsPage> {
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final userId = SupabaseClientService().client.auth.currentUser!.id;
    await SupabaseClientService().client.from('goals').insert({
      'member_id': userId,
      'title': _titleController.text.trim(),
      'target_value': double.tryParse(_targetController.text),
      'status': 'active',
    });
    _titleController.clear();
    _targetController.clear();
    ref.invalidate(goalsProvider);
    setState(() => _saving = false);
  }

  Future<void> _toggleStatus(String id, String currentStatus) async {
    final newStatus = currentStatus == 'active' ? 'completed' : 'active';
    await SupabaseClientService().client.from('goals').update({'status': newStatus}).eq('id', id);
    ref.invalidate(goalsProvider);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsProvider);

    return CupertinoPageScaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader('Goals'),
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
                            'New Goal',
                            style: ClayTokens.titleLarge.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: ClayTokens.clayDarkTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildField(_titleController, 'Goal Title *'),
                          const SizedBox(height: 8),
                          _buildField(_targetController, 'Target Value', TextInputType.number),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: CupertinoButton(
                              color: ClayTokens.clayPrimary,
                              borderRadius: BorderRadius.circular(12),
                              onPressed: _saving ? null : _save,
                              child: _saving
                                  ? CupertinoActivityIndicator(color: ClayTokens.clayDarkTextPrimary)
                                  : Text(
                                      'Add Goal',
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
                      'My Goals',
                      style: ClayTokens.headlineMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: ClayTokens.clayDarkTextPrimary,
                        letterSpacing: -0.36,
                      ),
                    ),
                  ),
                  goalsAsync.when(
                    data: (goals) => Container(
                      decoration: BoxDecoration(
                        color: ClayTokens.clayDarkSurface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: goals.asMap().entries.map((entry) {
                          final g = entry.value;
                          final isLast = entry.key == goals.length - 1;
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
                                            g['title'] ?? '',
                                            style: ClayTokens.titleLarge.copyWith(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w500,
                                              color: ClayTokens.clayDarkTextPrimary,
                                              letterSpacing: -0.41,
                                            ),
                                          ),
                                          if (g['target_value'] != null)
                                            Text(
                                              'Target: ${g['target_value']}',
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
                                  CupertinoButton(
                                    padding: const EdgeInsets.all(16),
                                    onPressed: () => _toggleStatus(g['id'], g['status']),
                                    child: Icon(
                                      g['status'] == 'completed'
                                          ? CupertinoIcons.checkmark_circle_fill
                                          : CupertinoIcons.circle,
                                      color: g['status'] == 'completed'
                                           ? ClayTokens.clayAccent
                                           : ClayTokens.clayPrimary,
                                      size: 24,
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

  Widget _buildField(TextEditingController controller, String label, [TextInputType? keyboardType]) {
    return CupertinoTextField(
      controller: controller,
      placeholder: label,
      placeholderStyle: ClayTokens.bodyMedium.copyWith(color: ClayTokens.clayDarkTextTertiary),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: ClayTokens.clayDarkSurfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      keyboardType: keyboardType ?? TextInputType.text,
      cursorColor: ClayTokens.clayPrimary,
      style: ClayTokens.bodyMedium.copyWith(color: ClayTokens.clayDarkTextPrimary),
    );
  }
}

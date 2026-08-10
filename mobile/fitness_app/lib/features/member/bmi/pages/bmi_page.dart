import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/animations.dart';
import '../data/bmi_info.dart';
import '../providers/bmi_history_provider.dart';

/// BMI page: shows the member's current BMI with an inline "Update" flow
/// (live height/weight calculator) plus a full measurement history.
class BmiPage extends ConsumerStatefulWidget {
  const BmiPage({super.key});

  @override
  ConsumerState<BmiPage> createState() => _BmiPageState();
}

class _BmiPageState extends ConsumerState<BmiPage> {
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  bool _editing = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _error = null;
      _heightController.clear();
      _weightController.clear();
    });
  }

  void _cancelEditing() {
    setState(() {
      _editing = false;
      _saving = false;
      _error = null;
      _heightController.clear();
      _weightController.clear();
    });
  }

  BmiInfo? _liveBmi() {
    final heightCm = double.tryParse(_heightController.text);
    final weightKg = double.tryParse(_weightController.text);
    if (heightCm == null || weightKg == null) return null;
    return bmiFromMeasurement(
      heightCm: heightCm,
      weightKg: weightKg,
      measuredAt: DateTime.now(),
    );
  }

  String? _validate() {
    final heightCm = double.tryParse(_heightController.text);
    final weightKg = double.tryParse(_weightController.text);
    if (heightCm == null || heightCm <= 0) return 'Enter a valid height (cm).';
    if (weightKg == null || weightKg <= 0) return 'Enter a valid weight (kg).';
    return null;
  }

  Future<void> _save() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final heightCm = double.tryParse(_heightController.text);
    final weightKg = double.tryParse(_weightController.text);
    final userId = SupabaseClientService().client.auth.currentUser!.id;
    try {
      await SupabaseClientService().client.from('body_measurements').insert({
        'member_id': userId,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'measured_at': DateTime.now().toIso8601String(),
      });
      ref.invalidate(bmiHistoryProvider);
      ref.invalidate(bmiRawRowsProvider);
      ref.invalidate(latestBmiProvider);
      if (mounted) {
        setState(() {
          _editing = false;
          _saving = false;
          _heightController.clear();
          _weightController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(bmiHistoryProvider);
    final rowsAsync = ref.watch(bmiRawRowsProvider);

    return CupertinoPageScaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Expanded(
              child: historyAsync.when(
                data: (history) => ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    if (history.isNotEmpty) ...[
                      _buildHeroCard(history.last),
                      const SizedBox(height: 16),
                    ],
                    if (_editing)
                      _buildUpdateEditor()
                    else
                      _buildUpdateButton(),
                    const SizedBox(height: 24),
                    _buildHistoryHeader(),
                    const SizedBox(height: 8),
                    _buildHistoryList(rowsAsync),
                    const SizedBox(height: 24),
                  ],
                ),
                loading: () => const Center(child: CupertinoActivityIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error: $e',
                      style: ClayTokens.bodyMedium.copyWith(color: ClayTokens.clayError),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => context.pop(),
            child: const Icon(CupertinoIcons.back, color: Color(0xFF7C3AED)),
          ),
          Expanded(
            child: Text(
              'BMI',
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

  Widget _buildHeroCard(BmiInfo latest) {
    final color = bmiCategoryColor(latest.bmi);
    return StaggeredFadeIn(
      index: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ClayTokens.clayDarkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ClayTokens.clayDarkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('CURRENT BMI', style: ClayTokens.darkLabelSmall.copyWith(color: ClayTokens.clayDarkTextTertiary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withAlpha(60)),
                  ),
                  child: Text(
                    latest.label,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: ClayTokens.normal,
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: Text(
                latest.bmi.toStringAsFixed(1),
                key: ValueKey(latest.bmi.toStringAsFixed(1)),
                style: ClayTokens.darkDisplayMedium.copyWith(fontSize: 44, color: color),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Updated ${DateFormat('MMM d, yyyy').format(latest.measuredAt)}',
              style: ClayTokens.darkBodySmall.copyWith(color: ClayTokens.clayDarkTextTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateButton() {
    return StaggeredFadeIn(
      index: 1,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF5E3AEE), Color(0xFFC56BF0)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC56BF0).withAlpha(60),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextButton(
          onPressed: _startEditing,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 6),
              Text(
                'Update',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateEditor() {
    final live = _liveBmi();
    return StaggeredFadeIn(
      index: 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ClayTokens.clayDarkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ClayTokens.clayDarkBorder),
        ),do it
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Update your body details',
              style: ClayTokens.darkTitleLarge.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _buildField(_heightController, 'Height (cm)', TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 8),
            _buildField(_weightController, 'Weight (kg)', TextInputType.numberWithOptions(decimal: true)),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(CupertinoIcons.exclamationmark_circle, color: Color(0xFFEF4444), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _error!,
                      style: ClayTokens.darkBodySmall.copyWith(color: ClayTokens.clayError),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _buildLiveCalculator(live),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: CupertinoButton(
                      color: ClayTokens.clayDarkSurfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      onPressed: _saving ? null : _cancelEditing,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFFB4B4D0),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF5E3AEE), Color(0xFFC56BF0)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      borderRadius: BorderRadius.circular(12),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const Center(
                              child: CupertinoActivityIndicator(color: Colors.white),
                            )
                          : const Center(
                              child: Text(
                                'Save',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveCalculator(BmiInfo? live) {
    if (live == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ClayTokens.clayDarkSurfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ClayTokens.clayDarkBorder),
        ),
        child: const Text(
          'Enter your height and weight to see your BMI.',
          style: TextStyle(fontSize: 12, color: Color(0xFF7070A0)),
        ),
      );
    }
    final color = bmiCategoryColor(live.bmi);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BMI',
                  style: ClayTokens.darkLabelSmall.copyWith(color: ClayTokens.clayDarkTextTertiary),
                ),
                const SizedBox(height: 2),
                Text(
                  live.bmi.toStringAsFixed(1),
                  style: ClayTokens.darkDisplayMedium.copyWith(fontSize: 28, color: color),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withAlpha(60)),
            ),
            child: Text(
              live.label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryHeader() {
    return StaggeredFadeIn(
      index: 2,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          'History',
          style: ClayTokens.headlineMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: ClayTokens.clayDarkTextPrimary,
            letterSpacing: -0.36,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList(AsyncValue<List<Map<String, dynamic>>> rowsAsync) {
    return StaggeredFadeIn(
      index: 3,
      child: rowsAsync.when(
        data: (rows) {
          if (rows.isEmpty) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ClayTokens.clayDarkSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ClayTokens.clayDarkBorder),
              ),
              child: const Column(
                children: [
                  Icon(Icons.history, color: Color(0xFF7070A0), size: 28),
                  SizedBox(height: 8),
                  Text(
                    'No measurements yet.\nTap Update to record your first one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF7070A0), height: 1.5),
                  ),
                ],
              ),
            );
          }
          return Container(
            decoration: BoxDecoration(
              color: ClayTokens.clayDarkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ClayTokens.clayDarkBorder),
            ),
            child: Column(
              children: rows.asMap().entries.map((entry) {
                final m = entry.value;
                final isLast = entry.key == rows.length - 1;
                return Column(
                  children: [
                    _historyRow(m),
                    if (!isLast)
                      const SizedBox(height: 0.5),
                  ],
                );
              }).toList(),
            ),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CupertinoActivityIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Error: $e',
            style: ClayTokens.bodyMedium.copyWith(color: ClayTokens.clayError),
          ),
        ),
      ),
    );
  }

  Widget _historyRow(Map<String, dynamic> m) {
    final measuredAt =
        DateTime.tryParse(m['measured_at']?.toString() ?? '')?.toLocal() ?? DateTime.now();
    final heightCm = m['height_cm'] as num?;
    final weightKg = m['weight_kg'] as num?;
    final info = bmiFromMeasurement(
      heightCm: heightCm,
      weightKg: weightKg,
      measuredAt: measuredAt,
    );
    final color = info == null ? ClayTokens.clayDarkTextTertiary : bmiCategoryColor(info.bmi);
    final detail = [
      if (heightCm != null) '${heightCm.toStringAsFixed(0)} cm',
      if (weightKg != null) '${weightKg.toStringAsFixed(1)} kg',
      if (info != null) 'BMI ${info.bmi.toStringAsFixed(1)}',
    ].join(' · ');

    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat('MMM d, yyyy').format(measuredAt),
                      style: ClayTokens.titleLarge.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: ClayTokens.clayDarkTextPrimary,
                        letterSpacing: -0.41,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (info != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withAlpha(25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withAlpha(60)),
                        ),
                        child: Text(
                          info.label,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: ClayTokens.titleMedium.copyWith(
                    fontSize: 13,
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
          onPressed: () async {
            await SupabaseClientService().client
                .from('body_measurements')
                .delete()
                .eq('id', m['id']);
            ref.invalidate(bmiHistoryProvider);
            ref.invalidate(bmiRawRowsProvider);
            ref.invalidate(latestBmiProvider);
          },
          child: Icon(CupertinoIcons.trash, color: ClayTokens.clayError, size: 20),
        ),
      ],
    );
  }

  Widget _buildField(TextEditingController controller, String label, TextInputType keyboardType, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: ClayTokens.darkLabelMedium.copyWith(color: ClayTokens.clayDarkTextSecondary),
          ),
        ),
        CupertinoTextField(
          controller: controller,
          placeholder: label,
          placeholderStyle: ClayTokens.bodyMedium.copyWith(color: ClayTokens.clayDarkTextTertiary),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: ClayTokens.clayDarkSurfaceElevated,
            borderRadius: BorderRadius.circular(10),
          ),
          keyboardType: keyboardType,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
          ],
          maxLines: maxLines,
          cursorColor: ClayTokens.clayPrimary,
          style: ClayTokens.bodyMedium.copyWith(color: ClayTokens.clayDarkTextPrimary),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
            setState(() {});
          },
        ),
      ],
    );
  }
}
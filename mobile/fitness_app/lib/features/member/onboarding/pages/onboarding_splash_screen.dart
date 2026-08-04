import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:shared/providers/auth_provider.dart';
import '../../../shared/widgets/clay/clay_card.dart';
import '../../../shared/widgets/clay/clay_button.dart';
import '../../../shared/widgets/clay/clay_input.dart';
import '../../../shared/widgets/animations.dart';
import '../../../../app/design_tokens.dart';
import '../providers/onboarding_provider.dart';

/// First-run onboarding for new members: pick gender, set height/weight, and
/// watch the live BMI before the dashboard unlocks.
class OnboardingSplashScreen extends ConsumerStatefulWidget {
  const OnboardingSplashScreen({super.key});

  @override
  ConsumerState<OnboardingSplashScreen> createState() => _OnboardingSplashScreenState();
}

class _OnboardingSplashScreenState extends ConsumerState<OnboardingSplashScreen> {
  final _heightController = TextEditingController(text: '170');
  final _weightController = TextEditingController(text: '65');

  String? _gender;
  double _heightCm = 170;
  double _weightKg = 65;
  bool _saving = false;
  String? _error;

  double get _bmi => _weightKg / ((_heightCm / 100) * (_heightCm / 100));

  (_BmiCategory, Color) get _bmiCategory {
    final bmi = _bmi;
    if (bmi < 18.5) return (_BmiCategory.underweight, const Color(0xFF64D2FF));
    if (bmi < 25) return (_BmiCategory.normal, ClayTokens.clayAccent);
    if (bmi < 30) return (_BmiCategory.overweight, ClayTokens.clayWarning);
    return (_BmiCategory.obese, ClayTokens.clayError);
  }

  bool get _heightValid => _heightCm >= 140 && _heightCm <= 210;
  bool get _weightValid => _weightKg >= 35 && _weightKg <= 150;

  bool get _canContinue => _gender != null && !_saving && _heightValid && _weightValid;

  Future<void> _continue() async {
    if (!_canContinue) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await OnboardingService.complete(
        gender: _gender!,
        heightCm: _heightCm,
        weightKg: _weightKg,
      );
      await ref.read(authProvider.notifier).refreshProfile();
      ref.invalidate(needsOnboardingProvider);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save your profile. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _selectGender(String? gender) {
    if (gender == null || _saving) return;
    Haptics.vibrate(HapticsType.light);
    setState(() => _gender = gender);
  }

  void _onHeightChanged(String value) {
    final parsed = double.tryParse(value);
    setState(() => _heightCm = parsed == null ? 0 : parsed.clamp(140, 210));
  }

  void _onWeightChanged(String value) {
    final parsed = double.tryParse(value);
    setState(() => _weightKg = parsed == null ? 0 : parsed.clamp(35, 150));
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (bmiCategory, bmiColor) = _bmiCategory;

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: Stack(
        children: [
          // ---- Aurora backdrop for depth ----
          const Positioned(top: -80, right: -60, child: _GlowBlob(size: 220, colors: [Color(0x337C3AED), Color(0x007C3AED)])),
          const Positioned(top: 40, left: -70, child: _GlowBlob(size: 200, colors: [Color(0x33DB2777), Color(0x00DB2777)])),
          const Positioned(top: 260, right: -90, child: _GlowBlob(size: 260, colors: [Color(0x2210B981), Color(0x0010B981)])),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
              physics: const ClampingScrollPhysics(),
              children: [
                const SizedBox(height: 4),
                _buildLogoHero(),
                const SizedBox(height: 14),
                StaggeredFadeIn(
                  index: 1,
                  child: Text('Welcome to Capshi', style: ClayTokens.darkDisplaySmall, textAlign: TextAlign.center),
                ),
                const SizedBox(height: 6),
                StaggeredFadeIn(
                  index: 2,
                  child: Text(
                    "Let's set up your profile — just 3 quick questions.",
                    textAlign: TextAlign.center,
                    style: ClayTokens.darkBodyMedium.copyWith(color: ClayTokens.clayDarkTextTertiary),
                  ),
                ),
                const SizedBox(height: 28),

                // ---- Step 1: Gender ----
                StaggeredFadeIn(
                  index: 3,
                  child: Text('ABOUT YOU', style: ClayTokens.darkLabelSmall.copyWith(color: ClayTokens.clayDarkTextTertiary)),
                ),
                const SizedBox(height: 10),
                StaggeredFadeIn(
                  index: 3,
                  child: Row(
                    children: [
                      Expanded(child: _genderCard('female', Icons.woman_2, 'Female', ClayTokens.claySecondary, _gender == 'female')),
                      const SizedBox(width: 12),
                      Expanded(child: _genderCard('male', Icons.man_2, 'Male', ClayTokens.clayPrimary, _gender == 'male')),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ---- Step 2: Height ----
                StaggeredFadeIn(
                  index: 4,
                  child: Text('YOUR STATS', style: ClayTokens.darkLabelSmall.copyWith(color: ClayTokens.clayDarkTextTertiary)),
                ),
                const SizedBox(height: 10),
                StaggeredFadeIn(
                  index: 4,
                  child: ClayInput(
                    controller: _heightController,
                    label: 'Height',
                    helperText: '140 – 210 cm',
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                    prefixIcon: const Icon(Icons.height),
                    suffixIcon: _unitLabel('cm'),
                    onChanged: _onHeightChanged,
                    errorText: (!_heightValid && _heightController.text.isNotEmpty) ? 'Enter a height between 140 and 210 cm' : null,
                  ),
                ),
                const SizedBox(height: 10),
                StaggeredFadeIn(
                  index: 4,
                  child: ClayInput(
                    controller: _weightController,
                    label: 'Weight',
                    helperText: '35 – 150 kg',
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                    prefixIcon: const Icon(Icons.monitor_weight_outlined),
                    suffixIcon: _unitLabel('kg'),
                    onChanged: _onWeightChanged,
                    errorText: (!_weightValid && _weightController.text.isNotEmpty) ? 'Enter a weight between 35 and 150 kg' : null,
                  ),
                ),
                const SizedBox(height: 10),

                // ---- Live BMI ----
                StaggeredFadeIn(
                  index: 5,
                  child: ClayCard(
                    variant: ClayCardVariant.outlined,
                    padding: ClayCardPadding.medium,
                    backgroundColor: ClayTokens.clayDarkSurfaceElevated,
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: bmiColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(ClayTokens.radiusButton),
                          ),
                          child: Icon(Icons.calculate_outlined, color: bmiColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('BMI', style: ClayTokens.darkTitleMedium),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: bmiColor.withAlpha(25),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: bmiColor.withAlpha(60)),
                                    ),
                                    child: Text(
                                      bmiCategory.label,
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: bmiColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text('Updates live as you type', style: ClayTokens.darkBodySmall.copyWith(color: ClayTokens.clayDarkTextTertiary)),
                            ],
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: ClayTokens.normal,
                          switchInCurve: ClayTokens.easeOut,
                          switchOutCurve: ClayTokens.easeOut,
                          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                          child: Text(
                            _bmi.toStringAsFixed(1),
                            key: ValueKey(_bmi.toStringAsFixed(1)),
                            style: ClayTokens.darkDisplaySmall.copyWith(color: bmiColor, fontSize: 32),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: ClayTokens.darkBodySmall.copyWith(color: ClayTokens.clayError), textAlign: TextAlign.center),
                ],

                const SizedBox(height: 24),
                StaggeredFadeIn(
                  index: 6,
                  child: ClayButton(
                    label: _saving ? 'Setting up…' : 'Continue',
                    onPressed: _canContinue ? _continue : null,
                    enabled: _canContinue,
                    loading: _saving,
                    fullWidth: true,
                    size: ClayButtonSize.large,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your answers power your workout calories and progress tracking.',
                  textAlign: TextAlign.center,
                  style: ClayTokens.darkBodySmall.copyWith(color: ClayTokens.clayDarkTextTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoHero() {
    return StaggeredFadeIn(
      index: 0,
      child: Column(
        children: [
          Container(
            width: 132,
            height: 132,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  Color(0xFF7C3AED),
                  Color(0xFFDB2777),
                  Color(0xFFA78BFA),
                  Color(0xFF7C3AED),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: ClayTokens.clayPrimary.withAlpha(90),
                  blurRadius: 34,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: ClayTokens.clayDarkShadowDark,
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: ClayTokens.clayDarkShadowLight,
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Container(
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0D0D1A)),
              child: ClipOval(
                child: Image.asset(
                  'assets/logo.png',
                  width: 118,
                  height: 118,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFA78BFA), Color(0xFFF0ABFC)],
            ).createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: Text('CAPSHI', style: ClayTokens.darkHeadlineLarge.copyWith(letterSpacing: 6, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _unitLabel(String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        unit,
        style: ClayTokens.darkLabelMedium.copyWith(color: ClayTokens.clayDarkTextTertiary, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _genderCard(String value, IconData icon, String label, Color accent, bool selected) {
    return GestureDetector(
      onTap: () => _selectGender(value),
      child: AnimatedContainer(
        duration: ClayTokens.fast,
        curve: ClayTokens.easeOut,
        height: 132,
        decoration: BoxDecoration(
          color: ClayTokens.clayDarkSurface,
          borderRadius: BorderRadius.circular(ClayTokens.radiusXl),
          border: Border.all(
            color: selected ? accent : ClayTokens.clayDarkBorder,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? ClayTokens.darkLevel2 : ClayTokens.darkLevel0,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accent.withAlpha(selected ? 45 : 22),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: selected ? accent : ClayTokens.clayDarkTextSecondary, size: 30),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: ClayTokens.darkTitleMedium.copyWith(
                color: selected ? accent : ClayTokens.clayDarkTextPrimary,
              ),
            ),
            if (selected) ...[
              const SizedBox(height: 6),
              Icon(Icons.check_circle, color: accent, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}

/// Soft, non-interactive gradient glow used behind the hero for depth.
class _GlowBlob extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _GlowBlob({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}

enum _BmiCategory {
  underweight('Underweight'),
  normal('Normal'),
  overweight('Overweight'),
  obese('Obese');

  final String label;
  const _BmiCategory(this.label);
}

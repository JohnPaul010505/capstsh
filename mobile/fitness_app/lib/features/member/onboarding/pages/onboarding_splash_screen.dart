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
import '../../../shared/widgets/step_indicator.dart';

class OnboardingSplashScreen extends ConsumerStatefulWidget {
  const OnboardingSplashScreen({super.key});

  @override
  ConsumerState<OnboardingSplashScreen> createState() => _OnboardingSplashScreenState();
}

class _OnboardingSplashScreenState extends ConsumerState<OnboardingSplashScreen> {
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  String? _gender;
  double _heightCm = 170;
  double _weightKg = 65;
  bool _saving = false;
  String? _error;
  int _step = 0;
  String? _selectedProfile;

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

  Future<void> _handleSave() async {
    if (_gender == null || _selectedProfile == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).completeOnboarding(
            gender: _gender!,
            heightCm: _heightCm,
            weightKg: _weightKg,
            profileAsset: _selectedProfile,
          );
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
          const Positioned(top: -80, right: -60, child: _GlowBlob(size: 220, colors: [Color(0x337C3AED), Color(0x007C3AED)])),
          const Positioned(top: 40, left: -70, child: _GlowBlob(size: 200, colors: [Color(0x33A78BFA), Color(0x00A78BFA)])),
          const Positioned(top: 260, right: -90, child: _GlowBlob(size: 260, colors: [Color(0x33A78BFA), Color(0x00A78BFA)])),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 32),
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLogoHero(),
                    const SizedBox(height: 24),
                    ClayCard(
                      variant: ClayCardVariant.outlined,
                      padding: ClayCardPadding.large,
                      backgroundColor: ClayTokens.clayDarkSurface,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (_step == 0) ...[
                            _buildWelcomeStep()
                          ] else if (_step == 1) ...[
                            _buildStatsStep(bmiCategory, bmiColor)
                          ] else if (_step == 2) ...[
                            _buildGenderStep()
                          ] else if (_step == 3) ...[
                            _buildProfileStep()
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    StepIndicator(currentStep: _step, totalSteps: 4),
                  ],
                ),
              ),
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
            child: Text('Triple J', style: ClayTokens.darkHeadlineLarge.copyWith(letterSpacing: 6, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Welcome to FitSight', style: ClayTokens.darkDisplaySmall, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          "Let's set up your profile — just 4 quick steps.",
          style: ClayTokens.darkBodyMedium.copyWith(color: ClayTokens.clayDarkTextTertiary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ClayButton(
            label: 'Start',
            onPressed: () => setState(() => _step = 1),
            fullWidth: true,
            size: ClayButtonSize.large,
            style: ClayButtonStyle.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsStep(_BmiCategory bmiCategory, Color bmiColor) {
    final bool showBmi = _heightValid && _weightValid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Your Stats', style: ClayTokens.darkTitleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Height', style: ClayTokens.darkTitleMedium),
              const SizedBox(height: 6),
              ClayInput(
                controller: _heightController,
                hint: 'e.g. 170',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                prefixIcon: const Icon(Icons.height),
                suffixIcon: _unitLabel('cm'),
                onChanged: _onHeightChanged,
                errorText: (!_heightValid && _heightController.text.isNotEmpty) ? 'Enter a height between 140 and 210 cm' : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Weight', style: ClayTokens.darkTitleMedium),
              const SizedBox(height: 6),
              ClayInput(
                controller: _weightController,
                hint: 'e.g. 65',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                prefixIcon: const Icon(Icons.monitor_weight_outlined),
                suffixIcon: _unitLabel('kg'),
                onChanged: _onWeightChanged,
                errorText: (!_weightValid && _weightController.text.isNotEmpty) ? 'Enter a weight between 35 and 150 kg' : null,
              ),
            ],
          ),
        ),
        if (showBmi) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ClayTokens.clayDarkSurfaceElevated,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: bmiColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.calculate_outlined, color: bmiColor, size: 20),
                ),
                const SizedBox(width: 12),
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
                    ],
                  ),
                ),
                Text(
                  _bmi.toStringAsFixed(1),
                  style: ClayTokens.darkDisplaySmall.copyWith(color: bmiColor, fontSize: 24),
                ),
              ],
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: ClayTokens.darkBodySmall.copyWith(color: ClayTokens.clayError), textAlign: TextAlign.center),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ClayButton(
                label: 'Back',
                onPressed: () => setState(() => _step = 0),
                style: ClayButtonStyle.secondary,
                fullWidth: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClayButton(
                label: 'Next',
                onPressed: _heightValid && _weightValid ? () => setState(() => _step = 2) : null,
                fullWidth: true,
                style: ClayButtonStyle.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('About You', style: ClayTokens.darkTitleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _genderCard('male', 'Male', ClayTokens.clayPrimary, 'L2.gif', _gender == 'male'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _genderCard('female', 'Female', ClayTokens.claySecondary, 'W3.gif', _gender == 'female'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ClayButton(
                label: 'Back',
                onPressed: () => setState(() => _step = 1),
                style: ClayButtonStyle.secondary,
                fullWidth: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClayButton(
                label: 'Next',
                onPressed: _gender != null ? () => setState(() => _step = 3) : null,
                fullWidth: true,
                style: ClayButtonStyle.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileStep() {
    final profiles = _gender == 'male'
        ? ['L1.gif', 'L2.gif', 'L3.gif']
        : ['W1.gif', 'W2.gif', 'W3.gif'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Choose Your Profile', style: ClayTokens.darkTitleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Row(
          children: List.generate(profiles.length, (index) {
            final asset = 'assets/profiles/${profiles[index]}';
            final isSelected = _selectedProfile == asset;
            final selectionColor = _gender == 'female'
                ? ClayTokens.claySecondary
                : ClayTokens.clayPrimary;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedProfile = asset),
                child: AnimatedContainer(
                  duration: ClayTokens.fast,
                  curve: ClayTokens.easeOut,
                  margin: EdgeInsets.only(right: index < profiles.length - 1 ? 8 : 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? selectionColor : ClayTokens.clayDarkBorder,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      asset,
                      fit: BoxFit.cover,
                      height: 120,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => Container(
                        height: 120,
                        color: ClayTokens.clayDarkSurfaceElevated,
                        child: Icon(Icons.person, color: ClayTokens.clayDarkTextSecondary, size: 40),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ClayButton(
            label: _saving ? 'Saving...' : 'Save',
            onPressed: _selectedProfile != null && !_saving ? _handleSave : null,
            fullWidth: true,
            size: ClayButtonSize.large,
            loading: _saving,
            style: ClayButtonStyle.primary,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: ClayTokens.darkBodySmall.copyWith(color: ClayTokens.clayError), textAlign: TextAlign.center),
        ],
      ],
    );
  }

  Widget _genderCard(String value, String label, Color accent, String gifAsset, bool isSelected) {
    return GestureDetector(
      onTap: () => _selectGender(value),
      child: AnimatedContainer(
        duration: ClayTokens.fast,
        curve: ClayTokens.easeOut,
        height: 140,
        decoration: BoxDecoration(
          color: ClayTokens.clayDarkSurface,
          borderRadius: BorderRadius.circular(ClayTokens.radiusXl),
          border: isSelected
              ? Border.all(color: accent, width: 3)
              : Border.all(color: ClayTokens.clayDarkBorder, width: 1),
          boxShadow: ClayTokens.darkLevel0,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/profiles/$gifAsset',
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 100,
                color: ClayTokens.clayDarkSurfaceElevated,
                child: Icon(Icons.person, color: ClayTokens.clayDarkTextSecondary, size: 32),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: ClayTokens.darkTitleMedium.copyWith(
                color: ClayTokens.clayDarkTextPrimary,
              ),
            ),
          ],
        ),
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
}

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

import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared/models/nutrition_food.dart';
import 'package:shared/services/nutrition_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared/services/supabase_client.dart';

import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/app_glow_background.dart';

/// Add-food wizard (see docs/superpowers/specs/2026-09-25-food-intake-philfct-wizard-design.md).
///
/// photo (optional) -> meal type -> search PhilFCT -> grams -> review -> save.
/// There is no AI step: the photo is stored as a record only, and every number
/// comes from the DOST-FNRI per-100 g reference row.
enum _WizardStep { photo, mealType, search, quantity, review }

const _mealTypeOptions = <String, (String, String, IconData, Color)>{
  'breakfast': (
    'Breakfast',
    'Meals eaten in the morning to start your day.',
    CupertinoIcons.sun_max,
    Color(0xFFFF9500),
  ),
  'lunch': (
    'Lunch',
    'Meals eaten around midday.',
    CupertinoIcons.sun_max_fill,
    Color(0xFF0A84FF),
  ),
  'dinner': (
    'Dinner',
    'Meals eaten in the evening.',
    CupertinoIcons.moon_stars,
    Color(0xFF7C3AED),
  ),
  'snack': (
    'Snack',
    'A light meal or small bite between main meals.',
    CupertinoIcons.circle,
    Color(0xFF30D158),
  ),
};

/// Labels under the step circles, matching the reference design.
const _stepLabels = <String>[
  'Photo',
  'Meal Type',
  'Portion',
  'Quantity',
  'Confirm',
];

/// App glass recipe (same as the login card / glass widgets): a translucent
/// white fill with a soft white border instead of an opaque clay surface, so
/// the glow background shows through the cards.
const _glassFill = Color(0x12FFFFFF); // white @ 7%
const _glassFillStrong = Color(0x1FFFFFFF); // white @ 12%
const _glassBorder = Color(0x2EFFFFFF); // white @ 18%

BoxDecoration _glassDecoration({
  BorderRadius? borderRadius,
  Color? fill,
  Color? border,
  double borderWidth = 1,
  bool shadow = true,
}) {
  return BoxDecoration(
    color: fill ?? _glassFill,
    borderRadius: borderRadius ?? BorderRadius.circular(18),
    border: Border.all(color: border ?? _glassBorder, width: borderWidth),
    boxShadow: shadow
        ? const [
            BoxShadow(
              color: Color(0x59000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ]
        : null,
  );
}

class AddFoodWizard extends ConsumerStatefulWidget {
  const AddFoodWizard({super.key});

  @override
  ConsumerState<AddFoodWizard> createState() => _AddFoodWizardState();
}

class _AddFoodWizardState extends ConsumerState<AddFoodWizard> {
  _WizardStep _step = _WizardStep.photo;

  Uint8List? _image;
  String? _mealType;
  NutritionFood? _selectedFood;
  final _gramsController = TextEditingController(text: '100');
  final _searchController = TextEditingController();

  List<NutritionFood> _results = [];
  bool _searching = false;
  String? _searchError;

  bool _saving = false;
  bool _uploading = false;
  String? _saveError;

  @override
  void dispose() {
    _gramsController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- quantity

  double get _grams {
    final g = double.tryParse(_gramsController.text.trim());
    if (g == null || g <= 0) return 0;
    return g.clamp(0, 5000);
  }

  /// FNRI rows are per 100 g, so the entered weight scales the reference values.
  double get _factor => _grams / 100;

  double get _calories => (_selectedFood?.caloriesKcal ?? 0) * _factor;
  double get _protein => (_selectedFood?.proteinG ?? 0) * _factor;
  double get _carbs => (_selectedFood?.carbsG ?? 0) * _factor;
  double get _fat => (_selectedFood?.fatG ?? 0) * _factor;

  bool get _canContinue {
    switch (_step) {
      case _WizardStep.photo:
        return !_uploading;
      case _WizardStep.mealType:
        return _mealType != null;
      case _WizardStep.search:
        return _selectedFood != null;
      case _WizardStep.quantity:
        return _grams > 0;
      case _WizardStep.review:
        return !_saving;
    }
  }

  void _next() {
    if (!_canContinue) return;
    if (_step == _WizardStep.review) {
      _save();
      return;
    }
    setState(() {
      _step = _WizardStep.values[_step.index + 1];
      _saveError = null;
    });
  }

  void _back() {
    if (_step == _WizardStep.photo) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _step = _WizardStep.values[_step.index - 1];
      _saveError = null;
    });
  }
  // ------------------------------------------------------------------- photo

  Future<void> _capture(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _image = bytes;
        _saveError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveError = 'Could not open the camera/gallery: $e');
    }
  }

  // ------------------------------------------------------------------ search

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      setState(() {
        _results = [];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final found = await NutritionService().searchFoods(q);
      if (!mounted) return;
      setState(() => _results = found);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _searchError = 'Could not search the FNRI database';
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  // -------------------------------------------------------------------- save

  Future<void> _save() async {
    final food = _selectedFood;
    final mealType = _mealType;
    if (food == null || mealType == null || _grams <= 0) return;

    setState(() {
      _saving = true;
      _uploading = _image != null;
      _saveError = null;
    });

    try {
      final client = SupabaseClientService().client;
      final userId = client.auth.currentUser!.id;

      String? photoUrl;
      final image = _image;
      if (image != null) {
        final path =
            'meals/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await client.storage
            .from('proofs')
            .uploadBinary(
              path,
              image,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        photoUrl = client.storage.from('proofs').getPublicUrl(path);
      }

      await client.from('meal_logs').insert({
        'member_id': userId,
        'meal_type': mealType,
        'food_name': food.foodName,
        'calories': _calories.round(),
        'protein_g': double.parse(_protein.toStringAsFixed(1)),
        'carbs_g': double.parse(_carbs.toStringAsFixed(1)),
        'fat_g': double.parse(_fat.toStringAsFixed(1)),
        'photo_url': photoUrl,
        'meal_time': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _uploading = false;
        _saveError = 'Could not save the meal: $e';
      });
    }
  }

  // -------------------------------------------------------------------- view

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClayColors.clayDarkBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            CupertinoIcons.chevron_left,
            color: Color(0xFFFFFFFF),
          ),
          onPressed: _back,
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add Food',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              'Step ${_step.index + 1} of 5',
              style: const TextStyle(
                color: Color(0xFFB4B4D0),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              CupertinoIcons.xmark,
              color: Color(0xFFB4B4D0),
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              _StepIndicator(current: _step.index),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                  child: _buildStep(),
                ),
              ),
              _BottomBar(
                busy: _saving,
                uploading: _uploading,
                label: _step == _WizardStep.review ? 'Save Meal' : 'Continue',
                enabled: _canContinue,
                onPressed: _next,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _WizardStep.photo:
        return _photoStep();
      case _WizardStep.mealType:
        return _mealTypeStep();
      case _WizardStep.search:
        return _searchStep();
      case _WizardStep.quantity:
        return _quantityStep();
      case _WizardStep.review:
        return _reviewStep();
    }
  }

  Widget _photoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeading(
          title: 'Add a photo',
          subtitle:
              'Snap your meal so you can remember it later. '
              'The photo is only a record - nutrition is never estimated from it.',
        ),
        const SizedBox(height: 18),
        if (_image != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.memory(
                  _image!,
                  height: 260,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => setState(() => _image = null),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(150),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          _PhotoPlaceholder(
            onCamera: () => _capture(ImageSource.camera),
            onGallery: () => _capture(ImageSource.gallery),
          ),
        if (_image != null) ...[
          const SizedBox(height: 12),
          _GhostButton(
            label: 'Retake photo',
            icon: CupertinoIcons.camera,
            onTap: () => _capture(ImageSource.camera),
          ),
        ],
        const SizedBox(height: 18),
        Center(
          child: TextButton(
            onPressed: () {
              setState(() => _image = null);
              _next();
            },
            child: const Text(
              'Skip photo',
              style: TextStyle(color: Color(0xFFB4B4D0), fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mealTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeading(
          title: 'Select meal type',
          subtitle: 'Which meal is this? Breakfast, lunch, dinner or a snack.',
        ),
        const SizedBox(height: 18),
        ..._mealTypeOptions.entries.map((entry) {
          final (label, description, icon, color) = entry.value;
          final selected = _mealType == entry.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => setState(() => _mealType = entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: selected ? color.withAlpha(28) : _glassFill,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected ? color : _glassBorder,
                    width: selected ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: color.withAlpha(28),
                        border: Border.all(color: color.withAlpha(90)),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              color: Color(0xFFECECFC),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            description,
                            style: const TextStyle(
                              color: Color(0xFFB4B4D0),
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? color : Colors.transparent,
                        border: Border.all(
                          color: selected ? color : _glassBorder,
                          width: 1.6,
                        ),
                      ),
                      child: selected
                          ? const Icon(
                              CupertinoIcons.check_mark,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _searchStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeading(
          title: 'Search & select food',
          subtitle:
              'Search the DOST-FNRI Philippine Food Composition Table '
              '(1,542 foods, with Filipino names).',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: _search,
          style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: _glassFill,
            hintText: 'e.g. rice, adobo, Mais, tilapia',
            hintStyle: const TextStyle(color: Color(0xFF7070A0), fontSize: 14),
            prefixIcon: const Icon(
              CupertinoIcons.search,
              size: 18,
              color: Color(0xFFB4B4D0),
            ),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(
                      CupertinoIcons.clear_circled_solid,
                      size: 16,
                      color: Color(0xFFB4B4D0),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _search('');
                      setState(() {});
                    },
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _glassBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _glassBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF7C3AED),
                width: 1.6,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_searching)
          const LinearProgressIndicator(
            color: Color(0xFF7C3AED),
            minHeight: 2,
            backgroundColor: Color(0xFF1C1C35),
          ),
        if (_searchError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _searchError!,
              style: const TextStyle(color: Color(0xFFFF453A), fontSize: 12),
            ),
          ),
        if (_searchController.text.trim().length >= 2 &&
            !_searching &&
            _results.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              'No FNRI food matches "${_searchController.text.trim()}". '
              'Try a shorter word (e.g. "rice" instead of "fried rice with egg").',
              style: const TextStyle(
                color: Color(0xFFB4B4D0),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        const SizedBox(height: 8),
        ..._results.map(
          (food) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FoodResultTile(
              food: food,
              selected: _selectedFood?.id == food.id,
              onTap: () => setState(() {
                _selectedFood = food;
                _gramsController.text = '100';
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _quantityStep() {
    final food = _selectedFood;
    if (food == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeading(
          title: 'Enter quantity',
          subtitle:
              'FNRI values are per 100 g. Enter how much you ate and the '
              'nutrition updates automatically.',
        ),
        const SizedBox(height: 16),
        _SelectedFoodCard(food: food),
        const SizedBox(height: 18),
        const Text(
          'Quantity (grams)',
          style: TextStyle(
            color: Color(0xFFB4B4D0),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _gramsController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFECECFC),
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: _glassFill,
            hintText: '100',
            hintStyle: const TextStyle(
              color: Color(0xFF7070A0),
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
            suffixText: 'g',
            suffixStyle: const TextStyle(
              color: Color(0xFFB4B4D0),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF7C3AED),
                width: 1.4,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF7C3AED),
                width: 1.4,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [50, 100, 150, 200, 250]
              .map(
                (g) => _GramChip(
                  grams: g,
                  selected: _grams == g.toDouble(),
                  onTap: () => setState(() => _gramsController.text = '$g'),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        _MacroPreview(
          calories: _calories,
          protein: _protein,
          carbs: _carbs,
          fat: _fat,
        ),
      ],
    );
  }

  Widget _reviewStep() {
    final food = _selectedFood!;
    final (mealLabel, _, mealIcon, mealColor) = _mealTypeOptions[_mealType]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeading(
          title: 'Review & confirm',
          subtitle:
              'Check the details before saving. Tap any row to change it.',
        ),
        const SizedBox(height: 16),
        if (_image != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                _image!,
                height: 170,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        _ReviewRow(
          icon: mealIcon,
          color: mealColor,
          label: 'Meal type',
          value: mealLabel,
          onEdit: () => setState(() => _step = _WizardStep.mealType),
        ),
        _ReviewRow(
          icon: CupertinoIcons.leaf_arrow_circlepath,
          color: const Color(0xFF30D158),
          label: 'Food',
          value: food.foodName,
          subtitle: food.aliases.isNotEmpty
              ? 'aka ${food.aliases.join(', ')}'
              : food.category,
          onEdit: () => setState(() => _step = _WizardStep.search),
        ),
        _ReviewRow(
          icon: CupertinoIcons.gauge,
          color: const Color(0xFF0A84FF),
          label: 'Quantity',
          value: '${_grams.toStringAsFixed(0)} g',
          subtitle:
              '${food.caloriesKcal.toStringAsFixed(0)} kcal per 100 g · '
              '${food.source.isEmpty ? 'FNRI' : food.source}',
          onEdit: () => setState(() => _step = _WizardStep.quantity),
        ),
        _ReviewRow(
          icon: CupertinoIcons.photo,
          color: const Color(0xFF7C3AED),
          label: 'Photo',
          value: _image != null ? 'Attached' : 'Skipped',
          onEdit: () => setState(() => _step = _WizardStep.photo),
        ),
        const SizedBox(height: 16),
        _MacroPreview(
          calories: _calories,
          protein: _protein,
          carbs: _carbs,
          fat: _fat,
        ),
        if (_saveError != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF453A).withAlpha(22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF453A).withAlpha(70)),
            ),
            child: Text(
              _saveError!,
              style: const TextStyle(
                color: Color(0xFFFF453A),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  static const _purple = Color(0xFF7C3AED);
  static const _pending = Color(0xFF353555);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Five equal cells centre each circle at the same relative
          // position, so the 1 -> 2 -> 3 -> 4 -> 5 spacing is always even.
          final cellW = constraints.maxWidth / 5;
          return Stack(
            children: [
              // Connector segments drawn between neighbouring circle edges
              // (2px clear of each circle) with an identical gap on every
              // hop -- the old layout doubled the gap before step 5.
              for (int i = 0; i < 4; i++)
                Positioned(
                  left: (i + 0.5) * cellW + 17,
                  top: 13,
                  width: cellW - 34,
                  height: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: i <= current ? _purple : _pending,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(5, (i) {
                  final done = i < current;
                  final active = i == current;
                  return Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: done || active
                                  ? _purple
                                  : Colors.transparent,
                              border: Border.all(
                                color: done || active ? _purple : _pending,
                                width: 1.6,
                              ),
                              boxShadow: active
                                  ? [
                                      BoxShadow(
                                        color: _purple.withAlpha(90),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: done
                                ? const Icon(
                                    CupertinoIcons.check_mark,
                                    size: 15,
                                    color: Color(0xFFFFFFFF),
                                  )
                                : Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      color: active
                                          ? const Color(0xFFFFFFFF)
                                          : const Color(0xFF7070A0),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _stepLabels[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: active
                                  ? const Color(0xFFECECFC)
                                  : const Color(0xFF7070A0),
                              fontSize: 10,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StepHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  const _StepHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFECECFC),
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFFB4B4D0),
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _PhotoPlaceholder({required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
      decoration: _glassDecoration(
        borderRadius: BorderRadius.circular(20),
        fill: _glassFillStrong,
        borderWidth: 1.2,
      ),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  ClayColors.clayPrimary.withAlpha(70),
                  ClayColors.clayPrimary.withAlpha(20),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              CupertinoIcons.camera_viewfinder,
              color: Color(0xFFD6A5FF),
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No photo yet',
            style: TextStyle(
              color: Color(0xFFECECFC),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Take a photo of your meal or choose one from your gallery.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFB4B4D0),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onCamera,
                  icon: const Icon(CupertinoIcons.camera, size: 18),
                  label: const Text('Take photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGallery,
                  icon: const Icon(CupertinoIcons.photo, size: 18),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD6A5FF),
                    side: const BorderSide(color: Color(0xFF7C3AED)),
                    minimumSize: const Size.fromHeight(50),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GhostButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFD6A5FF),
          side: const BorderSide(color: Color(0xFF7C3AED)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _FoodResultTile extends StatelessWidget {
  final NutritionFood food;
  final bool selected;
  final VoidCallback onTap;

  const _FoodResultTile({
    required this.food,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7C3AED).withAlpha(26) : _glassFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF7C3AED) : _glassBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.foodName,
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (food.aliases.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      food.aliases.join(', '),
                      style: const TextStyle(
                        color: Color(0xFFB4B4D0),
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    '${food.category} · ${food.caloriesKcal.toStringAsFixed(0)} kcal / 100 g',
                    style: const TextStyle(
                      color: Color(0xFF7070A0),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                CupertinoIcons.check_mark_circled_solid,
                color: Color(0xFF7C3AED),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectedFoodCard extends StatelessWidget {
  final NutritionFood food;
  const _SelectedFoodCard({required this.food});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _glassDecoration(borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            food.foodName,
            style: const TextStyle(
              color: Color(0xFFECECFC),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (food.aliases.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              food.aliases.join(', '),
              style: const TextStyle(color: Color(0xFFB4B4D0), fontSize: 11),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _Per100(
                label: 'kcal',
                value: food.caloriesKcal.toStringAsFixed(0),
                color: const Color(0xFF7C3AED),
              ),
              _Per100(
                label: 'protein',
                value: '${food.proteinG.toStringAsFixed(1)}g',
                color: const Color(0xFF0A84FF),
              ),
              _Per100(
                label: 'carbs',
                value: '${food.carbsG.toStringAsFixed(1)}g',
                color: const Color(0xFFFF9500),
              ),
              _Per100(
                label: 'fat',
                value: '${food.fatG.toStringAsFixed(1)}g',
                color: const Color(0xFF30D158),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Per100 extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Per100({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF7070A0), fontSize: 10),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GramChip extends StatelessWidget {
  final int grams;
  final bool selected;
  final VoidCallback onTap;

  const _GramChip({
    required this.grams,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7C3AED).withAlpha(30) : _glassFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF7C3AED) : _glassBorder,
          ),
        ),
        child: Text(
          '$grams g',
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFFB4B4D0),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MacroPreview extends StatelessWidget {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const _MacroPreview({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1C35), Color(0xFF2A1F4D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AUTO-CALCULATED NUTRITION',
            style: TextStyle(
              color: Color(0xFFB4B4D0),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${calories.toStringAsFixed(0)} kcal',
            style: const TextStyle(
              color: Color(0xFFECECFC),
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: _glassBorder),
          const SizedBox(height: 12),
          Row(
            children: [
              _MacroPill(
                label: 'Protein',
                value: protein,
                color: const Color(0xFF0A84FF),
              ),
              _MacroPill(
                label: 'Carbs',
                value: carbs,
                color: const Color(0xFFFF9500),
              ),
              _MacroPill(
                label: 'Fat',
                value: fat,
                color: const Color(0xFF30D158),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MacroPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFFB4B4D0), fontSize: 10.5),
          ),
          const SizedBox(height: 2),
          Text(
            '${value.toStringAsFixed(1)} g',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback onEdit;

  const _ReviewRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.subtitle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: _glassDecoration(borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF7070A0),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFFECECFC),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: Color(0xFFB4B4D0),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Text(
              'Edit',
              style: TextStyle(
                color: Color(0xFF7C3AED),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              CupertinoIcons.chevron_right,
              color: Color(0xFF7070A0),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final bool busy;
  final bool uploading;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  const _BottomBar({
    required this.busy,
    required this.uploading,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (uploading) ...[
            const Text(
              'Uploading photo…',
              style: TextStyle(color: Color(0xFFB4B4D0), fontSize: 11),
            ),
            const SizedBox(height: 6),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: enabled ? onPressed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF1C1C35),
                disabledForegroundColor: const Color(0xFF7070A0),
                minimumSize: const Size.fromHeight(54),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: enabled ? 6 : 0,
                shadowColor: const Color(0xFF7C3AED),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: busy
                  ? const CupertinoActivityIndicator(
                      color: Colors.white,
                      radius: 10,
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(CupertinoIcons.arrow_right, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../../app/design_tokens.dart';

final todayMealsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser!.id;
  final today = DateTime.now().toIso8601String().split('T')[0];
  final response = await SupabaseClientService()
      .client
      .from('meal_logs')
      .select()
      .eq('member_id', userId)
      .gte('meal_time', '${today}T00:00:00')
      .lt('meal_time', '${today}T23:59:59')
      .order('meal_time', ascending: false);
  return (response as List).cast<Map<String, dynamic>>();
});

final mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
const mealIcons = {
  'breakfast': CupertinoIcons.sun_max,
  'lunch': CupertinoIcons.sun_max,
  'dinner': CupertinoIcons.moon,
  'snack': CupertinoIcons.info,
};
const mealIconColors = {
  'breakfast': Color(0xFFFF9500),
  'lunch': Color(0xFF0A84FF),
  'dinner': Color(0xFFBF5AF2),
  'snack': Color(0xFF30D158),
};

class MealLogPage extends ConsumerStatefulWidget {
  const MealLogPage({super.key});

  @override
  ConsumerState<MealLogPage> createState() => _MealLogPageState();
}

class _MealLogPageState extends ConsumerState<MealLogPage> {
  bool _showForm = false;
  bool _saving = false;

  final _foodController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  String _mealType = 'breakfast';
  File? _image;

  Future<void> _takePhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<void> _save() async {
    if (_foodController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final client = SupabaseClientService().client;
      final userId = client.auth.currentUser!.id;
      String? imageUrl;
      if (_image != null) {
        final bytes = await _image!.readAsBytes();
        final path = 'meals/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await client.storage.from('proofs').uploadBinary(
          path, bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
        imageUrl = client.storage.from('proofs').getPublicUrl(path);
      }
      await client.from('meal_logs').insert({
        'member_id': userId,
        'meal_type': _mealType,
        'food_name': _foodController.text.trim(),
        'calories': int.tryParse(_caloriesController.text),
        'protein_g': double.tryParse(_proteinController.text),
        'carbs_g': double.tryParse(_carbsController.text),
        'fat_g': double.tryParse(_fatController.text),
        'photo_url': imageUrl,
        'meal_time': DateTime.now().toIso8601String(),
      });
      _foodController.clear();
      _caloriesController.clear();
      _proteinController.clear();
      _carbsController.clear();
      _fatController.clear();
      setState(() {
        _image = null;
        _showForm = false;
      });
      ref.invalidate(todayMealsProvider);
    } catch (_) {} finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _foodController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mealsAsync = ref.watch(todayMealsProvider);

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          physics: const ClampingScrollPhysics(),
          children: [
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('FOOD INTAKE', style: TextStyle(
                  fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFFFFFFFF),
                )),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF636366).withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF636366).withAlpha(50)),
                      ),
                      child: Text(
                        DateFormat('MMM d').format(DateTime.now()),
                        style: const TextStyle(fontSize: 10, color: Color(0xFF636366)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBF5AF2).withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBF5AF2).withAlpha(40)),
                      ),
                      child: mealsAsync.when(
                        data: (meals) => Text('${meals.length} meals',
                          style: const TextStyle(fontSize: 10, color: Color(0xFFD6A5FF))),
                        loading: () => const Text('...',
                          style: TextStyle(fontSize: 10, color: Color(0xFFD6A5FF))),
                        error: (_, __) => const Text('0 meals',
                          style: TextStyle(fontSize: 10, color: Color(0xFFD6A5FF))),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            mealsAsync.when(
              data: (meals) {
                final totalCal = meals.fold(0, (sum, m) => sum + (m['calories'] as int? ?? 0));
                final totalProtein = meals.fold(0.0, (sum, m) => sum + (m['protein_g'] as double? ?? 0.0));
                final totalCarbs = meals.fold(0.0, (sum, m) => sum + (m['carbs_g'] as double? ?? 0.0));
                return _NutritionRow(calories: totalCal, protein: totalProtein, carbs: totalCarbs);
              },
              loading: () => const _NutritionRow(calories: 0, protein: 0, carbs: 0),
              error: (_, __) => const _NutritionRow(calories: 0, protein: 0, carbs: 0),
            ),
            const SizedBox(height: 16),
            Text('MEALS TODAY', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: const Color(0xFF8E8E93), letterSpacing: 0)),
            const SizedBox(height: 9),
            mealsAsync.when(
              data: (meals) => Column(
                children: [
                  ...meals.asMap().entries.map((entry) => StaggeredFadeIn(
                    index: entry.key,
                    child: _MealCard(meal: entry.value),
                  )),
                  if (meals.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No meals logged today', style: TextStyle(color: Color(0xFF636366), fontSize: 12)),
                    ),
                ],
              ),
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Color(0xFFD6A5FF)),
              )),
              error: (e, _) => Text('Error: $e', style: const TextStyle(color: Color(0xFF636366))),
            ),
            if (_showForm) _buildAddForm(),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: () => setState(() => _showForm = !_showForm),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A84FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_showForm ? CupertinoIcons.xmark : CupertinoIcons.add, color: Colors.white, size: 17),
                      const SizedBox(width: 6),
                      Text(
                        _showForm ? 'Cancel' : 'Add Food',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildAddForm() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38383A).withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Log Meal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFFFFFFF))),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _mealType,
            items: mealTypes.map((t) => DropdownMenuItem(
              value: t,
              child: Text(t[0].toUpperCase() + t.substring(1), style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 13)),
            )).toList(),
            onChanged: (v) => setState(() => _mealType = v!),
            decoration: const InputDecoration(labelText: 'Meal Type', filled: true),
            dropdownColor: const Color(0xFF2C2C2E),
            style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _foodController,
            decoration: const InputDecoration(labelText: 'Food name *', filled: true),
            style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextField(
                controller: _caloriesController,
                decoration: const InputDecoration(labelText: 'Calories', filled: true),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 13),
              )),
              const SizedBox(width: 8),
              Expanded(child: TextField(
                controller: _proteinController,
                decoration: const InputDecoration(labelText: 'Protein (g)', filled: true),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 13),
              )),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextField(
                controller: _carbsController,
                decoration: const InputDecoration(labelText: 'Carbs (g)', filled: true),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 13),
              )),
              const SizedBox(width: 8),
              Expanded(child: TextField(
                controller: _fatController,
                decoration: const InputDecoration(labelText: 'Fat (g)', filled: true),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 13),
              )),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(CupertinoIcons.camera, size: 16),
                label: const Text('Take Photo', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD6A5FF),
                  side: const BorderSide(color: Color(0xFFD6A5FF)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(CupertinoIcons.photo, size: 16),
                label: const Text('Gallery', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD6A5FF),
                  side: const BorderSide(color: Color(0xFFD6A5FF)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          if (_image != null) ...[
            const SizedBox(height: 10),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_image!, height: 140, width: double.infinity, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 6, right: 6,
                  child: GestureDetector(
                    onTap: () => setState(() => _image = null),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(CupertinoIcons.xmark, size: 13, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A84FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _saving
                ? const CupertinoActivityIndicator(color: Colors.white, radius: 10)
                : const Text('Log Meal'),
          ),
        ],
      ),
    );
  }
}

class _NutritionRow extends StatelessWidget {
  final int calories;
  final double protein;
  final double carbs;

  const _NutritionRow({required this.calories, required this.protein, required this.carbs});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _NutCard(value: '$calories', label: 'kcal', color: const Color(0xFFFF453A)),
        const SizedBox(width: 8),
        _NutCard(value: '${protein.toStringAsFixed(0)} g', label: 'protein', color: const Color(0xFF0A84FF)),
        const SizedBox(width: 8),
        _NutCard(value: '${carbs.toStringAsFixed(0)} g', label: 'carbs', color: const Color(0xFFFF9500)),
      ],
    );
  }
}

class _NutCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _NutCard({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PressableCard(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Text(value, style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: color,
            )),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF8E8E93))),
          ],
        ),
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final Map<String, dynamic> meal;

  const _MealCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    final type = meal['meal_type'] as String? ?? 'snack';
    final name = meal['food_name'] as String? ?? '';
    final calories = meal['calories'] as int?;
    final icon = mealIcons[type] ?? CupertinoIcons.info;
    final iconColor = mealIconColors[type] ?? const Color(0xFF30D158);

    return Semantics(
      label: '$name, $type${calories != null ? ', $calories calories' : ''}',
      child: PressableCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        margin: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF),
                  )),
                  Text(
                    type[0].toUpperCase() + type.substring(1),
                    style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93)),
                  ),
                ],
              ),
            ),
            if (calories != null)
              Text('$calories kcal', style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD6A5FF),
              )),
          ],
        ),
      ),
    );
  }
}

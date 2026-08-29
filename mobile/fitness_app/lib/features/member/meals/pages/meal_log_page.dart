import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:shared/services/supabase_client.dart';
import 'package:shared/services/nutrition_service.dart';
import 'package:shared/models/nutrition_food.dart';
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

enum AddFoodMode { manual, capture, gallery }

enum _AiStep { idle, uploading, identifying, loadingNutrition, done, error }

class MealLogPage extends ConsumerStatefulWidget {
  const MealLogPage({super.key});

  @override
  ConsumerState<MealLogPage> createState() => _MealLogPageState();
}

class _MealLogPageState extends ConsumerState<MealLogPage> {
  bool _showForm = false;
  AddFoodMode? _addFoodMode;
  bool _saving = false;
  _AiStep _aiStep = _AiStep.idle;
  double _aiProgress = 0.0;
  String? _identificationError;

  final _foodController = TextEditingController();
  final _searchController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  String _mealType = 'breakfast';
  File? _image;
  String? _imagePublicUrl;

  List<Map<String, dynamic>> _candidates = [];
  Map<String, dynamic>? _selectedCandidate;
  double _portionMultiplier = 1.0;
  bool _autoFilled = false;
  String? _autoFillSource;

  final _portionOptions = [0.5, 1.0, 1.5];
  bool _showCustomPortion = false;
  bool _mealTypeSelected = false;
  final _customPortionController = TextEditingController();
  double? _baseServingSizeG;

  List<NutritionFood> _searchResults = [];
  bool _showSearch = false;
  bool _searching = false;
  String? _searchError;

  @override
  void dispose() {
    _foodController.dispose();
    _searchController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _customPortionController.dispose();
    super.dispose();
  }

  void _openForm(AddFoodMode mode) {
    setState(() {
      _addFoodMode = mode;
      _showForm = true;
      _image = null;
      _imagePublicUrl = null;
      _candidates = [];
      _selectedCandidate = null;
      _autoFilled = false;
      _autoFillSource = null;
      _identificationError = null;
      _aiStep = _AiStep.idle;
      _aiProgress = 0.0;
      _portionMultiplier = 1.0;
      _showCustomPortion = false;
      _customPortionController.clear();
      _baseServingSizeG = null;
      _mealTypeSelected = false;
      _searchResults = [];
      _showSearch = false;
      _searching = false;
      _searchError = null;
      _foodController.clear();
      _searchController.clear();
    });
  }

  void _closeForm() {
    setState(() {
      _showForm = false;
      _addFoodMode = null;
      _image = null;
      _imagePublicUrl = null;
      _candidates = [];
      _selectedCandidate = null;
      _autoFilled = false;
      _autoFillSource = null;
      _identificationError = null;
      _aiStep = _AiStep.idle;
      _aiProgress = 0.0;
      _portionMultiplier = 1.0;
      _showCustomPortion = false;
      _customPortionController.clear();
      _baseServingSizeG = null;
      _mealTypeSelected = false;
      _searchResults = [];
      _showSearch = false;
      _searching = false;
      _searchError = null;
      _foodController.clear();
      _searchController.clear();
    });
  }

  Future<void> _takePhoto() async {
    if (_addFoodMode != AddFoodMode.capture) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _image = File(picked.path);
        _imagePublicUrl = null;
        _candidates = [];
        _selectedCandidate = null;
        _autoFilled = false;
        _autoFillSource = null;
        _identificationError = null;
        _aiStep = _AiStep.idle;
        _aiProgress = 0.0;
      });
      await _uploadAndIdentify();
    } else {
      _closeForm();
    }
  }

  Future<void> _pickFromGallery() async {
    if (_addFoodMode != AddFoodMode.gallery) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
    if (picked != null) {
      final mime = picked.mimeType ?? '';
      final ext = picked.path.split('.').last.toLowerCase();
      final isVideo = mime.startsWith('video/') || ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext);
      if (isVideo) {
        if (mounted) {
          setState(() => _identificationError = 'Please select an image, not a video');
        }
        return;
      }
      setState(() {
        _image = File(picked.path);
        _imagePublicUrl = null;
        _candidates = [];
        _selectedCandidate = null;
        _autoFilled = false;
        _autoFillSource = null;
        _identificationError = null;
        _aiStep = _AiStep.idle;
        _aiProgress = 0.0;
      });
      await _uploadAndIdentify();
    } else {
      _closeForm();
    }
  }

  void _removeImage() {
    setState(() {
      _image = null;
      _imagePublicUrl = null;
      _candidates = [];
      _selectedCandidate = null;
      _aiStep = _AiStep.idle;
      _aiProgress = 0.0;
      _identificationError = null;
      _mealTypeSelected = false;
    });
  }

  Future<void> _retryIdentification() async {
    if (_image == null) {
      setState(() {
        _identificationError = null;
        _aiStep = _AiStep.idle;
        _aiProgress = 0.0;
        _mealTypeSelected = false;
      });
      return;
    }
    setState(() {
      _identificationError = null;
      _aiStep = _AiStep.uploading;
      _aiProgress = 0.0;
      _candidates = [];
      _selectedCandidate = null;
    });
    await _uploadAndIdentify();
  }

  Future<void> _uploadAndIdentify() async {
    if (_image == null) return;

    setState(() {
      _aiStep = _AiStep.uploading;
      _aiProgress = 0.0;
      _identificationError = null;
    });

    try {
      final client = SupabaseClientService().client;
      final userId = client.auth.currentUser!.id;
      final bytes = await _image!.readAsBytes();
      final path = 'meals/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';

      setState(() => _aiProgress = 0.15);
      await client.storage.from('proofs').uploadBinary(
        path, bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );
      final publicUrl = client.storage.from('proofs').getPublicUrl(path);
      setState(() => _imagePublicUrl = publicUrl);

      setState(() {
        _aiStep = _AiStep.identifying;
        _aiProgress = 0.35;
      });

      final apiBase = _getApiBaseUrl();
      debugPrint('IDENTIFY FOOD url=$apiBase/api/ai/identify-food image=$publicUrl');
      final resp = await http.post(
        Uri.parse('$apiBase/api/ai/identify-food'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_url': publicUrl, 'top_k': 3}),
      ).timeout(const Duration(seconds: 30));

      setState(() => _aiProgress = 0.75);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final candidates = (data['candidates'] as List<dynamic>).cast<Map<String, dynamic>>();
        setState(() {
          _candidates = candidates;
          _aiStep = _AiStep.loadingNutrition;
          _aiProgress = 0.9;
        });
        if (_candidates.isNotEmpty) {
          _selectCandidate(_candidates.first);
        }
        setState(() {
          _aiStep = _AiStep.done;
          _aiProgress = 1.0;
        });
      } else {
        final err = jsonDecode(resp.body) as Map<String, dynamic>?;
        setState(() {
          _identificationError = err?['detail'] ?? err?['error'] ?? 'Identification failed';
          _aiStep = _AiStep.error;
          _aiProgress = 0.0;
        });
      }
    } catch (e) {
      debugPrint('IDENTIFY ERROR: $e');
      final base = _getApiBaseUrl();
      setState(() {
        _identificationError = 'Could not reach identification service ($base/api/ai/identify-food): $e';
        _aiStep = _AiStep.error;
        _aiProgress = 0.0;
      });
    }
  }

  Future<void> _searchFood(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearch = false;
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
      _showSearch = true;
    });
    try {
      final results = await NutritionService().searchFoods(q);
      setState(() => _searchResults = results);
    } catch (e) {
      setState(() {
        _searchError = 'Could not search nutrition database';
        _searchResults = [];
      });
    } finally {
      setState(() => _searching = false);
    }
  }

  void _applyNutritionFood(NutritionFood food) {
    setState(() {
      _selectedCandidate = null;
      _candidates = [];
      _autoFilled = true;
      _autoFillSource = food.source.isEmpty ? 'Nutrition database' : food.source;
      _portionMultiplier = 1.0;
      _showCustomPortion = false;
      _customPortionController.clear();
      _baseServingSizeG = food.servingSizeG;
      _showSearch = false;
      _searchResults = [];
      _searchController.clear();
    });
    _foodController.text = food.foodName;
    _caloriesController.text = food.caloriesKcal.toStringAsFixed(0);
    _proteinController.text = food.proteinG.toStringAsFixed(1);
    _carbsController.text = food.carbsG.toStringAsFixed(1);
    _fatController.text = food.fatG.toStringAsFixed(1);
  }

  void _selectCandidate(Map<String, dynamic> candidate) {
    setState(() {
      _selectedCandidate = candidate;
      _autoFilled = candidate['matched'] == true;
      _autoFillSource = candidate['source'] ?? 'AI guess';
      _portionMultiplier = 1.0;
      _showCustomPortion = false;
      _customPortionController.clear();
      _baseServingSizeG = _toDouble(candidate['serving_size_g']);
    });
    _applyCandidateToFields(candidate);
  }

  void _applyCandidateToFields(Map<String, dynamic> candidate) {
    final cal = candidate['calories_kcal']?.toDouble();
    final prot = candidate['protein_g']?.toDouble();
    final carb = candidate['carbs_g']?.toDouble();
    final fat = candidate['fat_g']?.toDouble();
    _foodController.text = candidate['name'] ?? '';
    _caloriesController.text = cal != null ? cal.toStringAsFixed(0) : '';
    _proteinController.text = prot != null ? prot.toStringAsFixed(1) : '';
    _carbsController.text = carb != null ? carb.toStringAsFixed(1) : '';
    _fatController.text = fat != null ? fat.toStringAsFixed(1) : '';
  }

  void _applyPortion(double multiplier) {
    setState(() {
      _portionMultiplier = multiplier;
      _showCustomPortion = false;
    });
    if (_selectedCandidate == null) return;
    final baseCal = _selectedCandidate!['calories_kcal']?.toDouble() ?? 0.0;
    final baseProt = _selectedCandidate!['protein_g']?.toDouble() ?? 0.0;
    final baseCarb = _selectedCandidate!['carbs_g']?.toDouble() ?? 0.0;
    final baseFat = _selectedCandidate!['fat_g']?.toDouble() ?? 0.0;
    _caloriesController.text = (baseCal * multiplier).toStringAsFixed(0);
    _proteinController.text = (baseProt * multiplier).toStringAsFixed(1);
    _carbsController.text = (baseCarb * multiplier).toStringAsFixed(1);
    _fatController.text = (baseFat * multiplier).toStringAsFixed(1);
  }

  void _applyCustomPortion(String gramsText) {
    final grams = double.tryParse(gramsText.trim());
    if (grams == null || grams <= 0 || _baseServingSizeG == null || _selectedCandidate == null) {
      setState(() => _showCustomPortion = false);
      return;
    }
    final ratio = grams / _baseServingSizeG!;
    final baseCal = _selectedCandidate!['calories_kcal']?.toDouble() ?? 0.0;
    final baseProt = _selectedCandidate!['protein_g']?.toDouble() ?? 0.0;
    final baseCarb = _selectedCandidate!['carbs_g']?.toDouble() ?? 0.0;
    final baseFat = _selectedCandidate!['fat_g']?.toDouble() ?? 0.0;
    setState(() {
      _portionMultiplier = ratio;
      _showCustomPortion = true;
      _caloriesController.text = (baseCal * ratio).toStringAsFixed(0);
      _proteinController.text = (baseProt * ratio).toStringAsFixed(1);
      _carbsController.text = (baseCarb * ratio).toStringAsFixed(1);
      _fatController.text = (baseFat * ratio).toStringAsFixed(1);
    });
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _getApiBaseUrl() {
    final envUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3001';
    if (kIsWeb) return envUrl;
    if (Platform.isAndroid && envUrl.contains('localhost')) {
      return envUrl.replaceFirst('localhost', '10.0.2.2');
    }
    return envUrl;
  }

  bool get _canSave {
    if (_saving) return false;
    if (_addFoodMode == AddFoodMode.manual) {
      return _foodController.text.trim().isNotEmpty &&
             _caloriesController.text.trim().isNotEmpty;
    }
    if (_addFoodMode == AddFoodMode.capture || _addFoodMode == AddFoodMode.gallery) {
      return _imagePublicUrl != null && _selectedCandidate != null;
    }
    return false;
  }

  Future<void> _save() async {
    if (_foodController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final client = SupabaseClientService().client;
      final userId = client.auth.currentUser!.id;
      String? imageUrl = _imagePublicUrl;
      if (imageUrl == null && _image != null) {
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
      _closeForm();
      ref.invalidate(todayMealsProvider);
    } catch (_) {} finally {
      if (mounted) setState(() => _saving = false);
    }
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
                data: (meals) => _TodayMacroRing(meals: meals),
                loading: () => const _TodayMacroRing(meals: []),
                error: (_, __) => const _TodayMacroRing(meals: []),
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
                  onTap: () {
                    if (_showForm) {
                      _closeForm();
                    } else {
                      setState(() => _showForm = true);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFBF5AF2),
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
    final showImageActions = _addFoodMode == AddFoodMode.capture || _addFoodMode == AddFoodMode.gallery;
    final hasImage = _imagePublicUrl != null;
    final isManual = _addFoodMode == AddFoodMode.manual;
    final isAiBusy = _aiStep == _AiStep.uploading ||
        _aiStep == _AiStep.identifying ||
        _aiStep == _AiStep.loadingNutrition;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38383A).withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_addFoodMode == null) ...[
            const Text('How would you like to add food?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFFFFFFF))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ModeButton(
                    icon: CupertinoIcons.pencil,
                    label: 'Manual',
                    onTap: () => _openForm(AddFoodMode.manual),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeButton(
                    icon: CupertinoIcons.camera,
                    label: 'Capture',
                    onTap: () => _openForm(AddFoodMode.capture),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeButton(
                    icon: CupertinoIcons.photo,
                    label: 'Gallery',
                    onTap: () => _openForm(AddFoodMode.gallery),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              isManual ? 'Manual Entry' : _addFoodMode == AddFoodMode.capture ? 'Capture Food' : 'Gallery',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFFFFFFF)),
            ),
            const SizedBox(height: 10),
            if (isManual) ...[
              _buildSearchField(),
              ..._buildSearchResults(),
              const SizedBox(height: 8),
            ],
            DropdownButtonFormField<String>(
              initialValue: _mealType,
              items: mealTypes.map((t) => DropdownMenuItem(
                value: t,
                child: Text(t[0].toUpperCase() + t.substring(1), style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 13)),
              )).toList(),
              onChanged: (v) {
                setState(() {
                  _mealType = v!;
                  if (!isManual) {
                    _mealTypeSelected = true;
                  }
                });
              },
              decoration: const InputDecoration(labelText: 'Meal Type', filled: true),
              dropdownColor: const Color(0xFF2C2C2E),
              style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 13),
            ),
            const SizedBox(height: 8),
            if (showImageActions && !hasImage && _mealTypeSelected) ...[
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _addFoodMode == AddFoodMode.capture ? _takePhoto : _pickFromGallery,
                    icon: Icon(_addFoodMode == AddFoodMode.capture ? CupertinoIcons.camera : CupertinoIcons.photo, size: 16),
                    label: Text(_addFoodMode == AddFoodMode.capture ? 'Take Photo' : 'Choose from Gallery', style: const TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD6A5FF),
                      side: const BorderSide(color: Color(0xFFD6A5FF)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (hasImage) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _imagePublicUrl!,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 140,
                        color: const Color(0xFF2C2C2E),
                        child: const Icon(CupertinoIcons.photo, color: Color(0xFF8E8E93)),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: isAiBusy ? null : _removeImage,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(120),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (!isManual && isAiBusy) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(
                          value: _aiProgress,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                          backgroundColor: const Color(0xFF2C2C2E),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0A84FF)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${(_aiProgress * 100).toInt()}%',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (isManual) ...[
              TextField(
                controller: _foodController,
                decoration: const InputDecoration(labelText: 'Food name *', filled: true),
                style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 13),
              ),
              const SizedBox(height: 8),
              if (_autoFilled && _autoFillSource != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Auto-filled from $_autoFillSource · edit if needed',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93), fontStyle: FontStyle.italic),
                  ),
                ),
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
            ],
            if (!isManual && _selectedCandidate != null) ...[
              const Text('Portion', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93))),
              const SizedBox(height: 6),
              Row(
                children: [
                  ..._portionOptions.map((m) {
                    final isSelected = _portionMultiplier == m && !_showCustomPortion;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${m}x', style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        onSelected: isAiBusy ? null : (_) => _applyPortion(m),
                        selectedColor: const Color(0xFF0A84FF),
                        backgroundColor: const Color(0xFF2C2C2E),
                        labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF8E8E93)),
                      ),
                    );
                  }),
                  ChoiceChip(
                    label: const Text('Custom', style: TextStyle(fontSize: 12)),
                    selected: _showCustomPortion,
                    onSelected: isAiBusy ? null : (_) {
                      setState(() {
                        _showCustomPortion = !_showCustomPortion;
                        if (!_showCustomPortion) {
                          _customPortionController.clear();
                        }
                      });
                    },
                    selectedColor: const Color(0xFF0A84FF),
                    backgroundColor: const Color(0xFF2C2C2E),
                    labelStyle: TextStyle(color: _showCustomPortion ? Colors.white : const Color(0xFF8E8E93)),
                  ),
                ],
              ),
              if (_showCustomPortion) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customPortionController,
                        decoration: const InputDecoration(
                          labelText: 'Portion (g)',
                          filled: true,
                          hintText: 'e.g. 150',
                        ),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 13),
                        onChanged: _applyCustomPortion,
                      ),
                    ),
                    if (_baseServingSizeG != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          'base: ${_baseServingSizeG!.toStringAsFixed(0)}g',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ],
            if (!isManual && _candidates.isNotEmpty) ...[
              const Text('Did we get this right?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: _candidates.map((c) {
                  final isSelected = _selectedCandidate == c;
                  return ChoiceChip(
                    label: Text(c['name'] ?? 'Unknown', style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    onSelected: isAiBusy ? null : (_) => _selectCandidate(c),
                    selectedColor: const Color(0xFF30D158),
                    backgroundColor: const Color(0xFF2C2C2E),
                    labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF8E8E93)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
            if (_identificationError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_identificationError!, style: const TextStyle(fontSize: 12, color: Color(0xFFFF453A))),
                    if (_aiStep == _AiStep.error && _image != null) ...[
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _retryIdentification,
                        icon: const Icon(CupertinoIcons.refresh, size: 16),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2C2C2E),
                          foregroundColor: const Color(0xFFD6A5FF),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            Center(
              child: ElevatedButton(
                onPressed: (_canSave && !_saving) ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBF5AF2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const CupertinoActivityIndicator(color: Colors.white, radius: 10)
                    : const Text('Save'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Row(
      children: [
        Expanded(child: TextField(
          controller: _searchController,
          onChanged: (v) {
            if (v.length >= 2) {
              _searchFood(v);
            } else {
              setState(() {
                _searchResults = [];
                _showSearch = false;
              });
            }
          },
          decoration: const InputDecoration(
            labelText: 'Search FNRI database',
            filled: true,
            prefixIcon: Icon(CupertinoIcons.search, size: 16, color: Color(0xFF8E8E93)),
          ),
          style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 13),
        )),
      ],
    );
  }

  List<Widget> _buildSearchResults() {
    final query = _searchController.text.trim();
    return [
      if (_searching)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(color: Color(0xFF0A84FF), minHeight: 2),
        ),
      if (_searchError != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(_searchError!, style: const TextStyle(fontSize: 12, color: Color(0xFFFF453A))),
        ),
      if (_showSearch && _searchResults.isNotEmpty)
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF38383A).withAlpha(100)),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final food = _searchResults[index];
              return ListTile(
                dense: true,
                title: Text(
                  food.foodName,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFFFFFFF)),
                ),
                subtitle: Text(
                  '${food.servingLabel} · ${food.caloriesKcal.toStringAsFixed(0)} kcal',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                ),
                onTap: () => _applyNutritionFood(food),
              );
            },
          ),
        ),
      if (_showSearch && !_searching && _searchResults.isEmpty && query.length >= 2)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No foods found for "$query"',
            style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
          ),
        ),
    ];
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ModeButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF38383A).withAlpha(100)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFD6A5FF), size: 22),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF))),
          ],
        ),
      ),
    );
  }
}

class _TodayMacroRing extends ConsumerWidget {
  final List<Map<String, dynamic>> meals;

  const _TodayMacroRing({required this.meals});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalCal = meals.fold(0, (sum, m) => sum + (m['calories'] as int? ?? 0));
    final totalProt = meals.fold(0.0, (sum, m) => sum + (m['protein_g'] as double? ?? 0.0));
    final totalCarb = meals.fold(0.0, (sum, m) => sum + (m['carbs_g'] as double? ?? 0.0));
    final totalFat = meals.fold(0.0, (sum, m) => sum + (m['fat_g'] as double? ?? 0.0));

    final protCal = totalProt * 4;
    final carbCal = totalCarb * 4;
    final fatCal = totalFat * 9;
    final macroTotal = protCal + carbCal + fatCal;

    final protPct = macroTotal > 0 ? protCal / macroTotal : 0.0;
    final carbPct = macroTotal > 0 ? carbCal / macroTotal : 0.0;
    final fatPct = macroTotal > 0 ? fatCal / macroTotal : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: macroTotal > 0
              ? PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 28,
                    startDegreeOffset: -90,
                    sections: [
                      PieChartSectionData(
                        value: protPct,
                        color: const Color(0xFF0A84FF),
                        radius: 20,
                      ),
                      PieChartSectionData(
                        value: carbPct,
                        color: const Color(0xFFFF9500),
                        radius: 20,
                      ),
                      PieChartSectionData(
                        value: fatPct,
                        color: const Color(0xFF30D158),
                        radius: 20,
                      ),
                    ],
                  ),
                )
              : PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 28,
                    startDegreeOffset: -90,
                    sections: [
                      PieChartSectionData(
                        value: 1,
                        color: const Color(0xFF2C2C2E),
                        radius: 20,
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$totalCal kcal', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFFFFFFF))),
              const SizedBox(height: 8),
              _MacroMiniCard(label: 'Protein', grams: totalProt, pct: protPct, color: const Color(0xFF0A84FF)),
              const SizedBox(height: 4),
              _MacroMiniCard(label: 'Carbs', grams: totalCarb, pct: carbPct, color: const Color(0xFFFF9500)),
              const SizedBox(height: 4),
              _MacroMiniCard(label: 'Fat', grams: totalFat, pct: fatPct, color: const Color(0xFF30D158)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MacroMiniCard extends StatelessWidget {
  final String label;
  final double grams;
  final double pct;
  final Color color;

  const _MacroMiniCard({required this.label, required this.grams, required this.pct, required this.color});

  @override
  Widget build(BuildContext context) {
    final pctStr = pct > 0 ? '${(pct * 100).toStringAsFixed(0)}%' : '0%';
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: pct.clamp(0.0, 1.0),
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text('${grams.toStringAsFixed(0)}g · $pctStr', style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93))),
        ),
      ],
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
    final protein = meal['protein_g'] as double?;
    final carbs = meal['carbs_g'] as double?;
    final fat = meal['fat_g'] as double?;
    final photoUrl = meal['photo_url'] as String?;
    final icon = mealIcons[type] ?? CupertinoIcons.info;
    final iconColor = mealIconColors[type] ?? const Color(0xFF30D158);

    return Semantics(
      label: '$name, $type${calories != null ? ', $calories calories' : ''}',
      child: PressableCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        margin: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: photoUrl != null
                  ? Image.network(photoUrl, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholderIcon(icon, iconColor))
                  : _placeholderIcon(icon, iconColor),
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
            const SizedBox(width: 8),
            Wrap(
              spacing: 4,
              children: [
                if (protein != null) _MacroPill(label: 'P', value: protein, color: const Color(0xFF0A84FF)),
                if (carbs != null) _MacroPill(label: 'C', value: carbs, color: const Color(0xFFFF9500)),
                if (fat != null) _MacroPill(label: 'F', value: fat, color: const Color(0xFF30D158)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderIcon(IconData icon, Color color) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MacroPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label ${value.toStringAsFixed(0)}g', style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

import '../data/plan_repository.dart';
// analyzer-workaround-20260907
import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/models/nutrition_food.dart';
import 'package:shared/services/nutrition_service.dart';
import 'package:shared/services/supabase_client.dart';
import 'package:shared/services/notification_service.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../../features/member/workout/data/met_exercise_repository.dart';

/// Lilac accent tuned for the dark glass panel; on the light body it flips
/// to the brand purple so spinners and add-icons stay readable.
Color get _accent =>
    ClayColors.isLightMode ? ClayTokens.clayPrimary : const Color(0xFFD6A5FF);

class CreatePlanScreen extends ConsumerStatefulWidget {
  const CreatePlanScreen({super.key});

  @override
  ConsumerState<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends ConsumerState<CreatePlanScreen> {
  String? selectedClient;
  String? selectedClientName;
  String? selectedWorkoutType;
  final Map<int, TextEditingController> _notesByDay = {};
  final TextEditingController foodSearchController = TextEditingController();
  final TextEditingController foodNameController = TextEditingController();
  final TextEditingController exerciseNameController = TextEditingController();
  final TextEditingController setsController = TextEditingController();
  final TextEditingController repsController = TextEditingController();
  final TextEditingController weightController = TextEditingController();

  int _currentDay = 1;
  String? _selectedMealType;
  final Map<int, List<Map<String, dynamic>>> foodsByDay =
      <int, List<Map<String, dynamic>>>{};
  final Map<int, List<Map<String, dynamic>>> exercisesByDay =
      <int, List<Map<String, dynamic>>>{};

  bool isSaving = false;
  List<Map<String, dynamic>>? members;
  Map<String, bool> memberHasActivePlan = <String, bool>{};

  DateTime _startDate = DateTime.now();

  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _fmtDate(DateTime d) =>
      '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';

  bool _isDayComplete(int day) {
    final foods = foodsByDay[day] ?? [];
    final exercises = exercisesByDay[day] ?? [];
    return foods.length == 3 && exercises.isNotEmpty;
  }

  TextEditingController _notesControllerForDay(int day) =>
      _notesByDay.putIfAbsent(day, TextEditingController.new);

  void _goToNextDay() {
    if (!_isDayComplete(_currentDay)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Complete Day $_currentDay nutrition and training first.',
          ),
        ),
      );
      return;
    }
    if (_currentDay < 7) setState(() => _currentDay++);
  }

  int get _completedDayCount {
    var count = 0;
    for (var day = 1; day <= 7; day++) {
      if (!_isDayComplete(day)) break;
      count = day;
    }
    return count;
  }

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final client = SupabaseClientService().client;
    final trainerId = client.auth.currentUser?.id;
    if (trainerId == null) return;

    // 1. Fetch active assignments for this trainer
    final assignments = await client
        .from('trainer_assignments')
        .select('member_id')
        .eq('trainer_id', trainerId)
        .eq('status', 'active');

    final memberIds = (assignments as List)
        .map((a) => a['member_id'] as String)
        .toSet()
        .toList();

    List<Map<String, dynamic>> membersList = [];
    final planChecks = <String, bool>{};

    if (memberIds.isNotEmpty) {
      // 2. Fetch member names for assigned members
      final profilesResp = await client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', memberIds)
          .order('full_name', ascending: true);

      membersList = (profilesResp as List).cast<Map<String, dynamic>>();

      final activeMemberIds = await PlanRepository()
          .getMembersWithUnfinishedPlans(trainerId);

      for (final member in membersList) {
        final id = member['id'] as String? ?? '';
        planChecks[id] = activeMemberIds.contains(id);
      }
    }

    if (!mounted) return;

    setState(() {
      members = membersList;
      memberHasActivePlan = planChecks;
      if (members != null && members!.isNotEmpty) {
        selectedClient = members!.first['id'] as String?;
        selectedClientName = members!.first['full_name'] as String?;
      }
    });
  }

  Future<void> _assignPlan() async {
    if (selectedClient == null || memberHasActivePlan[selectedClient] == true) {
      return;
    }
    final dayCount = _completedDayCount;
    if (dayCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete Day 1 nutrition and training before assigning.',
          ),
        ),
      );
      return;
    }
    setState(() => isSaving = true);
    try {
      final client = SupabaseClientService().client;
      final blocked = await PlanRepository().getMembersWithUnfinishedPlans(
        client.auth.currentUser!.id,
      );
      if (blocked.contains(selectedClient)) {
        if (mounted) {
          setState(() => memberHasActivePlan[selectedClient!] = true);
        }
        throw StateError(
          'This member already has an active plan. Finish or cancel it first.',
        );
      }

      final foodPlan = List.generate(dayCount, (day) {
        final dayNum = day + 1;
        return {
          'day': dayNum,
          'foods': foodsByDay[dayNum] ?? [],
          'notes': _notesControllerForDay(dayNum).text.trim(),
        };
      });

      final exercisePlan = List.generate(dayCount, (day) {
        final dayNum = day + 1;
        return {
          'day': dayNum,
          'exercises': exercisesByDay[dayNum] ?? [],
          'notes': _notesControllerForDay(dayNum).text.trim(),
        };
      });

      final planJson = <String, dynamic>{
        'member_id': selectedClient,
        'food_plan': foodPlan,
        'exercise_plan': exercisePlan,
        'start_date': _startDate.toIso8601String().split('T').first,
        'end_date': _startDate
            .add(Duration(days: dayCount - 1))
            .toIso8601String()
            .split('T')
            .first,
        'timeframe': '${dayCount}_days',
        'status': 'active',
        'trainer_id': client.auth.currentUser!.id,
      };
      // An existing plan must finish or be cancelled before creating another.
      planJson['created_at'] = DateTime.now().toIso8601String();
      await client.from('member_goal_plans').insert(planJson);

      if (!mounted) return;
      if (selectedClient != null) {
        final trainerName = await _trainerDisplayName(client);
        final notes = _notesControllerForDay(1).text.trim();
        final body = StringBuffer(
          'Your $dayCount-day plan starts ${_fmtDate(_startDate)}.',
        );
        if (notes.isNotEmpty) body.write(' $notes');
        await NotificationService().createNotification(
          userId: selectedClient!,
          title: 'Trainer Set a Plan',
          body: body.toString(),
          senderName: trainerName,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan assigned successfully')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to assign plan: $e')));
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  /// Signed name for plan notifications: the trainer's full_name, or the
  /// literal "trainer" when the profile lookup fails (never blocks assigning).
  Future<String> _trainerDisplayName(dynamic client) async {
    try {
      final id = client.auth.currentUser?.id;
      if (id == null) return 'trainer';
      final row = await client
          .from('profiles')
          .select('full_name')
          .eq('id', id)
          .maybeSingle();
      final name = row == null ? null : row['full_name'] as String?;
      if (name != null && name.trim().isNotEmpty) return name.trim();
    } catch (_) {
      // fall through to the generic signature
    }
    return 'trainer';
  }

  void _addFood() {
    if (_selectedMealType == null) return;
    if (foodNameController.text.trim().isEmpty) return;
    final currentFoods = foodsByDay[_currentDay] ?? [];
    final addedTypes = currentFoods
        .map((f) => f['meal_type'] as String? ?? '')
        .toSet();
    if (addedTypes.contains(_selectedMealType)) return;
    if (currentFoods.length >= 3) return;

    setState(() {
      foodsByDay.putIfAbsent(_currentDay, () => []).add({
        'name': foodNameController.text.trim(),
        'meal_type': _selectedMealType,
        'amount': '',
        'unit': '',
        'calories': '',
        'protein': '',
        'carbs': '',
        'fat': '',
      });
      foodSearchController.clear();
      foodNameController.clear();
    });
  }

  void _removeFood(int index) {
    setState(() {
      final list = foodsByDay[_currentDay];
      if (list != null && index < list.length) {
        list.removeAt(index);
        _selectedMealType = null;
      }
    });
  }

  void _addExercise() {
    final name = exerciseNameController.text.trim();
    final sets = setsController.text.trim();
    final reps = repsController.text.trim();
    final weight = weightController.text.trim();
    if (name.isEmpty || sets.isEmpty || reps.isEmpty) return;
    // Numbers only — letters never reach the plan (the training section also
    // surfaces a visible error before calling this).
    if (int.tryParse(sets) == null || int.tryParse(reps) == null) return;
    if (weight.isNotEmpty && double.tryParse(weight) == null) return;

    setState(() {
      exercisesByDay.putIfAbsent(_currentDay, () => []).add({
        'name': name,
        'sets': sets,
        'reps': reps,
        'weight': weight,
      });
      exerciseNameController.clear();
      setsController.clear();
      repsController.clear();
      weightController.clear();
    });
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate.isAfter(today) ? _startDate : today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _startDate = picked);
    }
  }

  void _removeExercise(int index) {
    setState(() {
      final list = exercisesByDay[_currentDay];
      if (list != null && index < list.length) {
        list.removeAt(index);
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _notesByDay.values) {
      controller.dispose();
    }
    foodSearchController.dispose();
    foodNameController.dispose();
    exerciseNameController.dispose();
    setsController.dispose();
    repsController.dispose();
    weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersList =
        members ??
        const [
          {'id': '', 'full_name': 'Loading members...'},
        ];

    final currentFoods = foodsByDay[_currentDay] ?? <Map<String, dynamic>>[];
    final currentExercises =
        exercisesByDay[_currentDay] ?? <Map<String, dynamic>>[];
    final hasActivePlan =
        selectedClient != null && memberHasActivePlan[selectedClient!] == true;

    return Scaffold(
      backgroundColor: ClayColors.isLightMode
          ? ClayTokens.claySurfaceLight.withAlpha(250)
          : ClayTokens.clayDarkSurface,
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  children: [
                    _NotificationGlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ClientSection(
                            members: membersList,
                            selectedClient: selectedClient,
                            onChanged: (value) {
                              setState(() {
                                selectedClient = value;
                              });
                            },
                          ),
                          if (hasActivePlan) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9500).withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFF9500).withAlpha(60),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Color(0xFFFF9500),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'This member already has an active plan. You can create another after it is completed or cancelled.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        // Yellow vanishes on the light glass;
                                        // light mode uses a dark amber instead.
                                        color: ClayColors.isLightMode
                                            ? const Color(0xFF9A6700)
                                            : const Color(0xFFFFCC02),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ] else ...[
                            SizedBox(height: 10),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ClayTokens.hairline.withAlpha(10),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: ClayTokens.hairline.withAlpha(28),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: ClayColors.isLightMode
                                        ? ClayTokens.clayPrimary
                                        : ClayTokens.clayPrimaryLight,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'This member does not have an active plan yet.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: glassInk(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          if (selectedClient != null &&
                              memberHasActivePlan[selectedClient] != true) ...[
                            _DaySelector(
                              currentDay: _currentDay,
                              isDayComplete: _isDayComplete,
                              onDayChanged: (day) {
                                if (day > 1 && !_isDayComplete(day - 1)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Finish Day ${day - 1} nutrition and training first.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setState(() => _currentDay = day);
                              },
                            ),
                            SizedBox(height: 16),
                            Text(
                              'START DATE',
                              style: ClayTokens.displaySmall.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: ClayTokens.clayDarkTextPrimary,
                              ),
                            ),
                            SizedBox(height: 8),
                            GestureDetector(
                              onTap: _pickStartDate,
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: ClayTokens.hairline.withAlpha(14),
                                  borderRadius: BorderRadius.circular(
                                    ClayTokens.radiusMd,
                                  ),
                                  border: Border.all(
                                    color: ClayTokens.hairline.withAlpha(30),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      CupertinoIcons.calendar,
                                      size: 16,
                                      color: Color(0xFF8E8E93),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _fmtDate(_startDate),
                                        style: ClayTokens.darkBodyMedium
                                            .copyWith(
                                              color: ClayTokens
                                                  .clayDarkTextPrimary,
                                            ),
                                      ),
                                    ),
                                    Icon(
                                      CupertinoIcons.chevron_down,
                                      size: 16,
                                      color: ClayTokens.clayDarkTextTertiary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _NutritionSection(
                              foods: currentFoods,
                              searchController: foodSearchController,
                              foodNameController: foodNameController,
                              onAddFood: _addFood,
                              onRemoveFood: _removeFood,
                              selectedMealType: _selectedMealType,
                              onMealTypeChanged: (type) {
                                setState(() => _selectedMealType = type);
                              },
                            ),
                            const SizedBox(height: 16),
                            _TrainingSection(
                              day: _currentDay,
                              exercises: currentExercises,
                              workoutType: selectedWorkoutType,
                              workoutTypes: const [
                                'Strength Training',
                                'Cardio',
                                'HIIT',
                                'Full Body',
                                'Upper Body',
                                'Lower Body',
                                'Push',
                                'Pull',
                                'Legs',
                                'Mobility',
                              ],
                              nameController: exerciseNameController,
                              setsController: setsController,
                              repsController: repsController,
                              weightController: weightController,
                              onWorkoutTypeChanged: (value) {
                                setState(() => selectedWorkoutType = value);
                              },
                              onAddExercise: _addExercise,
                              onRemoveExercise: _removeExercise,
                            ),
                            const SizedBox(height: 16),
                            _NotesSection(
                              controller: _notesControllerForDay(_currentDay),
                            ),
                            const SizedBox(height: 20),
                            if (_currentDay < 7) ...[
                              _AssignPlanButton(
                                label: 'Next',
                                onPressed: isSaving ? null : _goToNextDay,
                                isLoading: false,
                              ),
                              const SizedBox(height: 12),
                            ],
                            _AssignPlanButton(
                              onPressed: isSaving ? null : _assignPlan,
                              isLoading: isSaving,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => context.go('/trainer/profile'),
            child: Icon(
              CupertinoIcons.back,
              color: ClayTokens.clayDarkTextPrimary,
            ),
          ),
          Expanded(
            child: Text(
              'CREATE PLAN',
              textAlign: TextAlign.center,
              style: ClayTokens.displaySmall.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: ClayTokens.clayDarkTextPrimary,
              ),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }
}

/// The notification-popup glass surface (the "No notifications" panel):
/// live backdrop blur + navy→indigo vertical gradient, white rim, and the
/// dual glow (black drop + purple bloom). Wraps the Create Plan card so it
/// sits in the same liquid-glass system as the popups instead of the lighter
/// nav-bar `GlassPanel`.
class _NotificationGlassPanel extends StatelessWidget {
  final Widget child;

  const _NotificationGlassPanel({required this.child});

  static const _radius = BorderRadius.all(Radius.circular(16));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: _radius,
        boxShadow: [
          BoxShadow(
            color: ClayColors.isLightMode
                ? const Color(0x2E000000)
                : const Color(0x69000000), // black@105
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: ClayTokens.clayPrimary.withAlpha(36),
            blurRadius: 44,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                // Dark keeps the navy→indigo recipe; light mode uses the
                // near-white → lilac glass so every section on this card is
                // readable.
                colors: ClayColors.isLightMode
                    ? const [
                        Color(0xF7FFFFFF),
                        Color(0xE9F0E6FF),
                        Color(0xF2FFFFFF),
                      ]
                    : [
                        const Color(0xFF14142A).withAlpha(150),
                        const Color(0xFF221A4A).withAlpha(120),
                        const Color(0xFF14142A).withAlpha(160),
                      ],
                stops: const [0.0, 0.55, 1.0],
              ),
              borderRadius: _radius,
              border: Border.all(
                color: ClayColors.isLightMode
                    ? ClayTokens.clayPrimary.withAlpha(70)
                    : ClayTokens.hairline.withAlpha(38),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  final int currentDay;
  final ValueChanged<int> onDayChanged;
  final bool Function(int) isDayComplete;

  const _DaySelector({
    required this.currentDay,
    required this.onDayChanged,
    required this.isDayComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DAY',
          style: ClayTokens.displaySmall.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: ClayTokens.clayDarkTextPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(7, (index) {
            final day = index + 1;
            final isSelected = day == currentDay;
            final complete = isDayComplete(day);
            Color backgroundColor;
            Color borderColor;
            Color textColor;

            if (complete && isSelected) {
              backgroundColor = const Color(0xFF7C3AED);
              borderColor = const Color(0xFF7C3AED);
              textColor = purpleLabel;
            } else if (complete) {
              backgroundColor = const Color(0xFF7C3AED);
              borderColor = const Color(0xFF7C3AED);
              textColor = purpleLabel;
            } else if (isSelected) {
              backgroundColor = ClayTokens.hairline.withAlpha(14);
              borderColor = ClayTokens.clayPrimary;
              textColor = ClayTokens.clayPrimary;
            } else {
              backgroundColor = ClayTokens.hairline.withAlpha(14);
              borderColor = ClayTokens.hairline.withAlpha(30);
              textColor = ClayTokens.clayDarkTextSecondary;
            }

            return Expanded(
              child: GestureDetector(
                onTap: () => onDayChanged(day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 36,
                  margin: EdgeInsets.only(right: index < 6 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ClientSection extends StatelessWidget {
  final List<Map<String, dynamic>> members;
  final String? selectedClient;
  final ValueChanged<String?> onChanged;

  const _ClientSection({
    required this.members,
    required this.selectedClient,
    required this.onChanged,
  });

  String? get _selectedName {
    for (final member in members) {
      if (member['id'] == selectedClient) {
        return member['full_name'] as String?;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final name = _selectedName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CLIENT',
          style: ClayTokens.displaySmall.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: ClayTokens.clayDarkTextPrimary,
          ),
        ),
        SizedBox(height: 10),
        GestureDetector(
          onTap: () => _openMemberPicker(context),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: ClayTokens.hairline.withAlpha(14),
              borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
              border: Border.all(color: ClayTokens.hairline.withAlpha(30)),
            ),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.search,
                  size: 16,
                  color: Color(0xFF8E8E93),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name ?? 'Search & select a member',
                    style: ClayTokens.darkBodyMedium.copyWith(
                      color: name != null
                          ? ClayTokens.clayDarkTextPrimary
                          : ClayTokens.clayDarkTextTertiary,
                    ),
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_down,
                  size: 16,
                  color: ClayTokens.clayDarkTextTertiary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openMemberPicker(BuildContext context) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) =>
          _MemberPickerDialog(members: members, selected: selectedClient),
    );
    if (picked != null) onChanged(picked);
  }
}

/// Searchable member picker: type-ahead over the trainer's assigned members,
/// rendered as a glass dialog — tap a row to select it.
class _MemberPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final String? selected;

  const _MemberPickerDialog({required this.members, this.selected});

  @override
  State<_MemberPickerDialog> createState() => _MemberPickerDialogState();
}

class _MemberPickerDialogState extends State<_MemberPickerDialog> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.members
        : widget.members.where((m) {
            final name = (m['full_name'] as String? ?? '').toLowerCase();
            return name.contains(q);
          }).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: GlassPanel(
        padding: EdgeInsets.all(14),
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select member',
              style: ClayTokens.darkBodyMedium.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ClayTokens.clayDarkTextPrimary,
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search members…',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7070A0),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: Color(0xFF7070A0),
                ),
                filled: true,
                fillColor: ClayTokens.hairline.withAlpha(14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: ClayTokens.hairline.withAlpha(30),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFA78BFA)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              style: TextStyle(
                fontSize: 13,
                color: ClayTokens.clayDarkTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No members match "$_query"',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final member = filtered[i];
                    final id = member['id'] as String? ?? '';
                    final name = member['full_name'] as String? ?? 'Unknown';
                    final isSelected = id == widget.selected;
                    return InkWell(
                      onTap: () => Navigator.pop(context, id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? ClayTokens.clayPrimary.withAlpha(35)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: ClayTokens.darkBodyMedium.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? glassInk()
                                      : ClayTokens.clayDarkTextSecondary,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                CupertinoIcons.checkmark_circle_fill,
                                size: 18,
                                color: Color(0xFFA78BFA),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionSection extends StatefulWidget {
  final List<Map<String, dynamic>> foods;
  final TextEditingController searchController;
  final TextEditingController foodNameController;
  final VoidCallback onAddFood;
  final ValueChanged<int> onRemoveFood;
  final String? selectedMealType;
  final ValueChanged<String?> onMealTypeChanged;

  const _NutritionSection({
    required this.foods,
    required this.searchController,
    required this.foodNameController,
    required this.onAddFood,
    required this.onRemoveFood,
    required this.selectedMealType,
    required this.onMealTypeChanged,
  });

  @override
  State<_NutritionSection> createState() => _NutritionSectionState();
}

class _NutritionSectionState extends State<_NutritionSection> {
  static const _mealTypes = ['breakfast', 'lunch', 'dinner'];

  // FNRI / PhilFCT food search (same `search_nutrition_foods` RPC the
  // member food wizard uses) so the trainer can pick real database foods.
  Timer? _foodDebounce;
  List<NutritionFood> _foodResults = [];
  bool _searchingFoods = false;
  bool _hasFoodQuery = false;

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onControllerChanged);
    _foodDebounce?.cancel();
    super.dispose();
  }

  /// Clear stale suggestions when the field is emptied (e.g. after the
  /// parent's onAddFood clears the controller programmatically).
  void _onControllerChanged() {
    if (widget.searchController.text.isEmpty &&
        (_foodResults.isNotEmpty || _hasFoodQuery || _searchingFoods)) {
      _foodDebounce?.cancel();
      setState(() {
        _foodResults = [];
        _hasFoodQuery = false;
        _searchingFoods = false;
      });
    }
  }

  void _onFoodQueryChanged(String value) {
    final q = value.trim();
    _foodDebounce?.cancel();
    if (q.isEmpty) {
      setState(() {
        _foodResults = [];
        _hasFoodQuery = false;
        _searchingFoods = false;
      });
      return;
    }
    setState(() {
      _hasFoodQuery = true;
      _searchingFoods = true;
    });
    _foodDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await NutritionService().searchFoods(q);
        if (mounted) {
          setState(() {
            _foodResults = results;
            _searchingFoods = false;
          });
        }
      } catch (_) {
        // Search is a convenience — a failed lookup falls back to the
        // free-text entry the trainer can still type by hand.
        if (mounted) {
          setState(() {
            _foodResults = [];
            _searchingFoods = false;
          });
        }
      }
    });
  }

  /// Put the picked FNRI food in the editable name field for review.
  void _pickFood(NutritionFood food) {
    widget.foodNameController.text = food.foodName;
    widget.searchController.clear();
    setState(() {
      _foodResults = [];
      _hasFoodQuery = false;
      _searchingFoods = false;
    });
  }

  String _mealTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final addedTypes = widget.foods
        .map((f) => f['meal_type'] as String? ?? '')
        .toSet();
    final isFull = widget.foods.length >= 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NUTRITION PLAN',
          style: ClayTokens.displaySmall.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: ClayTokens.clayDarkTextPrimary,
          ),
        ),
        SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: ClayTokens.hairline.withAlpha(10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ClayTokens.hairline.withAlpha(28)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: _mealTypes.map((type) {
                  final isSelected = widget.selectedMealType == type;
                  final isAdded = addedTypes.contains(type);
                  return Expanded(
                    child: GestureDetector(
                      onTap: isAdded
                          ? null
                          : () => widget.onMealTypeChanged(type),
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        height: 36,
                        margin: EdgeInsets.only(
                          right: type != _mealTypes.last ? 6 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? ClayTokens.clayPrimary
                              : isAdded
                              ? ClayTokens.clayPrimary.withAlpha(40)
                              : ClayTokens.hairline.withAlpha(14),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? ClayTokens.clayPrimary
                                : isAdded
                                ? ClayTokens.clayPrimary.withAlpha(120)
                                : ClayTokens.hairline.withAlpha(30),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _mealTypeLabel(type),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected || isAdded
                                  ? (ClayColors.isLightMode
                                        ? (isSelected
                                              ? const Color(0xFFFFFFFF)
                                              : ClayTokens.clayPrimary)
                                        : Colors.white)
                                  : ClayTokens.clayDarkTextSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                widget.selectedMealType != null
                    ? 'Add ${_mealTypeLabel(widget.selectedMealType!)}'
                    : 'Select a meal type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: widget.selectedMealType != null
                      ? glassInk()
                      : const Color(0xFF8E8E93),
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: widget.searchController,
                      placeholder: 'Search FNRI foods',
                      placeholderStyle: ClayTokens.darkBodyMedium.copyWith(
                        color: ClayTokens.clayDarkTextTertiary,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: ClayTokens.hairline.withAlpha(14),
                        borderRadius: BorderRadius.circular(
                          ClayTokens.radiusMd,
                        ),
                        border: Border.all(
                          color: ClayTokens.hairline.withAlpha(30),
                        ),
                      ),
                      style: ClayTokens.darkBodyMedium,
                      cursorColor: ClayTokens.clayPrimary,
                      enabled: widget.selectedMealType != null && !isFull,
                      onChanged: _onFoodQueryChanged,
                      onSubmitted: _onFoodQueryChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Food name',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: glassInk(),
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: widget.foodNameController,
                      placeholder: 'Enter food or select a search result',
                      placeholderStyle: ClayTokens.darkBodyMedium.copyWith(
                        color: ClayTokens.clayDarkTextTertiary,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: ClayTokens.hairline.withAlpha(14),
                        borderRadius: BorderRadius.circular(
                          ClayTokens.radiusMd,
                        ),
                        border: Border.all(
                          color: ClayTokens.hairline.withAlpha(30),
                        ),
                      ),
                      style: ClayTokens.darkBodyMedium,
                      cursorColor: ClayTokens.clayPrimary,
                      enabled: widget.selectedMealType != null && !isFull,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) {
                        if (widget.selectedMealType != null && !isFull) {
                          widget.onAddFood();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    color: ClayTokens.clayPrimary,
                    borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
                    onPressed:
                        (widget.selectedMealType != null &&
                            !isFull &&
                            widget.foodNameController.text.trim().isNotEmpty)
                        ? widget.onAddFood
                        : null,
                    child: Text(
                      'Add',
                      style: ClayTokens.darkBodyMedium.copyWith(
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                  ),
                ],
              ),
              if (_searchingFoods) ...[
                const SizedBox(height: 10),
                Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _accent,
                    ),
                  ),
                ),
              ],
              if (!_searchingFoods &&
                  _hasFoodQuery &&
                  _foodResults.isEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  'No FNRI foods found. You can still type the food name.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                ),
              ],
              if (_foodResults.isNotEmpty) ...[
                SizedBox(height: 10),
                // Glass suggestion list — frosted panel matching the
                // create-plan section cards.
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 220),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              ClayTokens.hairline.withAlpha(24),
                              ClayTokens.clayPrimary.withAlpha(22),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: ClayTokens.hairline.withAlpha(38),
                          ),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _foodResults.length,
                          itemBuilder: (context, index) {
                            final food = _foodResults[index];
                            return InkWell(
                              onTap: () => _pickFood(food),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: ClayTokens.clayPrimary.withAlpha(
                                          35,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        CupertinoIcons.add,
                                        color: _accent,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            food.foodName,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: ClayTokens
                                                  .clayDarkTextPrimary,
                                            ),
                                          ),
                                          Text(
                                            '${food.category} · ${food.caloriesKcal.round()} kcal',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF8E8E93),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (isFull) ...[
                const SizedBox(height: 8),
                const Text(
                  'All meals added',
                  style: TextStyle(fontSize: 11, color: Color(0xFF30D158)),
                ),
              ],
              const SizedBox(height: 12),
              if (widget.foods.isEmpty)
                Container(
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: ClayTokens.hairline.withAlpha(14),
                    borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.add_circled,
                        color: ClayTokens.clayPrimaryLight,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'No foods added yet',
                        style: ClayTokens.darkBodyMedium.copyWith(
                          color: ClayTokens.clayDarkTextTertiary,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Text(
                  'Added Foods',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: glassInk(),
                  ),
                ),
                const SizedBox(height: 8),
                ...widget.foods.asMap().entries.map((entry) {
                  final index = entry.key;
                  final food = entry.value;
                  final mealType = food['meal_type'] as String? ?? '';
                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ClayTokens.hairline.withAlpha(10),
                      borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
                      border: Border.all(
                        color: ClayTokens.hairline.withAlpha(28),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ClayTokens.clayPrimary,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ClayTokens.clayPrimary),
                          ),
                          child: Text(
                            _mealTypeLabel(mealType),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            food['name'] ?? '',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: ClayTokens.clayDarkTextPrimary,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.all(4),
                          onPressed: () => widget.onRemoveFood(index),
                          child: Icon(
                            CupertinoIcons.delete,
                            color: ClayTokens.clayError,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TrainingSection extends StatefulWidget {
  final int day;
  final List<Map<String, dynamic>> exercises;
  final String? workoutType;
  final List<String> workoutTypes;
  final TextEditingController nameController;
  final TextEditingController setsController;
  final TextEditingController repsController;
  final TextEditingController weightController;
  final ValueChanged<String?> onWorkoutTypeChanged;
  final VoidCallback onAddExercise;
  final ValueChanged<int> onRemoveExercise;

  const _TrainingSection({
    required this.day,
    required this.exercises,
    required this.workoutType,
    required this.workoutTypes,
    required this.nameController,
    required this.setsController,
    required this.repsController,
    required this.weightController,
    required this.onWorkoutTypeChanged,
    required this.onAddExercise,
    required this.onRemoveExercise,
  });

  @override
  State<_TrainingSection> createState() => _TrainingSectionState();
}

class _TrainingSectionState extends State<_TrainingSection> {
  final TextEditingController _searchController = TextEditingController();
  final MetExerciseRepository _repository = MetExerciseRepository();
  Timer? _debounceTimer;
  List<MetExercise> _searchResults = [];
  bool _isSearching = false;
  String _query = '';
  bool _showAddButton = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.nameController.addListener(_updateAddButtonVisibility);
    widget.setsController.addListener(_clearNumericError);
    widget.repsController.addListener(_clearNumericError);
    widget.weightController.addListener(_clearNumericError);
    _updateAddButtonVisibility();
  }

  void _clearNumericError() {
    if (_error != null && mounted) setState(() => _error = null);
  }

  @override
  void didUpdateWidget(covariant _TrainingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workoutType != widget.workoutType) {
      _updateAddButtonVisibility();
    }
  }

  void _updateAddButtonVisibility() {
    final show =
        widget.workoutType != null &&
        widget.nameController.text.trim().isNotEmpty;
    if (_showAddButton != show) {
      setState(() => _showAddButton = show);
    }
  }

  @override
  void dispose() {
    widget.nameController.removeListener(_updateAddButtonVisibility);
    widget.setsController.removeListener(_clearNumericError);
    widget.repsController.removeListener(_clearNumericError);
    widget.weightController.removeListener(_clearNumericError);
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Sets / reps must be positive whole numbers. The fields are digits-only,
  /// so the only realistic failure is an empty or zero value — the hint stays
  /// neutral ("Enter sets & reps") instead of accusing the user of letters.
  String? _validateNumeric() {
    final sets = widget.setsController.text.trim();
    final reps = widget.repsController.text.trim();
    final setsValue = int.tryParse(sets);
    final repsValue = int.tryParse(reps);
    if (setsValue == null ||
        setsValue <= 0 ||
        repsValue == null ||
        repsValue <= 0) {
      return 'Enter sets & reps';
    }
    return null;
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(value);
    });
  }

  Future<void> _performSearch(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _isSearching = true);

    try {
      final response = await _repository.search(q);
      if (mounted) {
        setState(() {
          _searchResults = response.matches;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  void _addExerciseFromSearch(MetExercise exercise) {
    widget.nameController.text = exercise.name;
    _searchController.clear();
    setState(() {
      _query = '';
      _searchResults = [];
    });
    FocusScope.of(context).unfocus();
  }

  List<Widget> _buildExerciseItems() {
    if (widget.exercises.isEmpty) {
      return [
        Container(
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: ClayTokens.hairline.withAlpha(14),
            borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
          ),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.add_circled,
                color: ClayTokens.clayPrimaryLight,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'No exercises added yet',
                style: ClayTokens.darkBodyMedium.copyWith(
                  color: ClayTokens.clayDarkTextTertiary,
                ),
              ),
            ],
          ),
        ),
      ];
    }
    return widget.exercises.asMap().entries.map((entry) {
      final index = entry.key;
      final exercise = entry.value;
      return Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ClayTokens.hairline.withAlpha(10),
          borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
          border: Border.all(color: ClayTokens.hairline.withAlpha(28)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise['name'] ?? '',
                    style: ClayTokens.darkBodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: ClayTokens.clayDarkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${exercise['sets'] ?? 0} sets × ${exercise['reps'] ?? 0} reps${exercise['weight'] != null && exercise['weight'].toString().isNotEmpty ? ' • ${exercise['weight']} kg' : ''}',
                    style: ClayTokens.darkBodySmall.copyWith(
                      color: ClayTokens.clayDarkTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.all(4),
              onPressed: () => widget.onRemoveExercise(index),
              child: Icon(
                CupertinoIcons.delete,
                color: ClayTokens.clayError,
                size: 18,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRAINING PLAN',
          style: ClayTokens.displaySmall.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: ClayTokens.clayDarkTextPrimary,
          ),
        ),
        SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: ClayTokens.hairline.withAlpha(10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ClayTokens.hairline.withAlpha(28)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workout Type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: glassInk(),
                ),
              ),
              SizedBox(height: 8),
              DropdownField<String>(
                value: widget.workoutType,
                fillColor: ClayTokens.hairline.withAlpha(14),
                items: widget.workoutTypes.map((type) {
                  return DropdownItem<String>(label: type, value: type);
                }).toList(),
                onChanged: widget.onWorkoutTypeChanged,
                placeholder: 'Select workout type',
              ),
              SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: 'Search exercises…',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7070A0),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Color(0xFF7070A0),
                    size: 18,
                  ),
                  filled: true,
                  fillColor: ClayTokens.hairline.withAlpha(14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: ClayTokens.hairline.withAlpha(30),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFA78BFA)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                style: TextStyle(fontSize: 13, color: glassInk()),
              ),
              if (_isSearching) ...[
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _accent,
                    ),
                  ),
                ),
              ],
              if (_searchResults.isEmpty &&
                  _query.isNotEmpty &&
                  !_isSearching) ...[
                const SizedBox(height: 8),
                const Text(
                  'No exercises found. Try a different search term.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                ),
              ],
              if (_searchResults.isNotEmpty) ...[
                const SizedBox(height: 8),
                Column(
                  children: _searchResults.map((e) {
                    // Glass result row — frosted panel like the create-plan
                    // section cards instead of a solid dark tile.
                    return Container(
                      margin: EdgeInsets.only(bottom: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: PressableCard(
                            onTap: () => _addExerciseFromSearch(e),
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  ClayTokens.hairline.withAlpha(24),
                                  ClayTokens.clayPrimary.withAlpha(20),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ClayTokens.hairline.withAlpha(38),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFBF5AF2,
                                    ).withAlpha(20),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    color: _accent,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.name,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: glassInk(),
                                        ),
                                      ),
                                      Text(
                                        '${e.category} · MET ${e.metValue.toStringAsFixed(1)}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF8E8E93),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              SizedBox(height: 12),
              TextField(
                controller: widget.nameController,
                decoration: InputDecoration(
                  hintText: 'Exercise name',
                  hintStyle: TextStyle(fontSize: 13, color: Color(0xFF7070A0)),
                  filled: true,
                  fillColor: ClayTokens.hairline.withAlpha(14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: ClayTokens.hairline.withAlpha(30),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFA78BFA)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                style: TextStyle(fontSize: 13, color: glassInk()),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.setsController,
                      decoration: InputDecoration(
                        hintText: 'Sets',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7070A0),
                        ),
                        filled: true,
                        fillColor: ClayTokens.hairline.withAlpha(14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: ClayTokens.hairline.withAlpha(30),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFA78BFA),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      style: TextStyle(fontSize: 13, color: glassInk()),
                      keyboardType: TextInputType.number,
                      // Numbers only, max 2 digits (up to 99).
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}$')),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: widget.repsController,
                      decoration: InputDecoration(
                        hintText: 'Reps',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7070A0),
                        ),
                        filled: true,
                        fillColor: ClayTokens.hairline.withAlpha(14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: ClayTokens.hairline.withAlpha(30),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFA78BFA),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      style: TextStyle(fontSize: 13, color: glassInk()),
                      keyboardType: TextInputType.number,
                      // Numbers only, max 2 digits (up to 99).
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}$')),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: widget.weightController,
                      decoration: InputDecoration(
                        hintText: 'Weight (kg)',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7070A0),
                        ),
                        filled: true,
                        fillColor: ClayTokens.hairline.withAlpha(14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: ClayTokens.hairline.withAlpha(30),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFA78BFA),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      style: TextStyle(fontSize: 13, color: glassInk()),
                      keyboardType: TextInputType.number,
                      // Numbers only, max 3 digits (up to 999).
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}$')),
                      ],
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              if (_showAddButton)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: ClayTokens.clayPrimary,
                  borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
                  onPressed: () {
                    final error = _validateNumeric();
                    if (error != null) {
                      setState(() => _error = error);
                      return;
                    }
                    widget.onAddExercise();
                    setState(() {
                      _error = null;
                      _showAddButton = false;
                    });
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        CupertinoIcons.plus,
                        color: Color(0xFFFFFFFF),
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text('Add', style: TextStyle(color: Color(0xFFFFFFFF))),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Exercises',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: glassInk(),
                ),
              ),
              const SizedBox(height: 8),
              ..._buildExerciseItems(),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotesSection extends StatelessWidget {
  final TextEditingController controller;

  const _NotesSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOTES',
          style: ClayTokens.displaySmall.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: ClayTokens.clayDarkTextPrimary,
          ),
        ),
        SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: ClayTokens.hairline.withAlpha(10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ClayTokens.hairline.withAlpha(28)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '(Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: glassInk(),
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 5,
                style: ClayTokens.darkBodyMedium,
                decoration: InputDecoration(
                  hintText:
                      'Add instructions, rest days, intensity, or trainer notes...',
                  hintStyle: ClayTokens.darkBodyMedium.copyWith(
                    color: ClayTokens.clayDarkTextTertiary,
                  ),
                  filled: true,
                  fillColor: ClayTokens.hairline.withAlpha(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssignPlanButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  const _AssignPlanButton({
    required this.onPressed,
    required this.isLoading,
    this.label = 'Assign Plan',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
        ),
        borderRadius: BorderRadius.circular(ClayTokens.radiusButton),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(ClayTokens.radiusButton),
        onPressed: onPressed,
        child: isLoading
            ? const CupertinoActivityIndicator(color: Color(0xFFFFFFFF))
            : Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFFFFFF),
                ),
              ),
      ),
    );
  }
}

class DropdownItem<T> {
  final String label;
  final T value;
  const DropdownItem({required this.label, required this.value});
}

class DropdownField<T> extends StatefulWidget {
  final String? placeholder;
  final T? value;
  final List<DropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final Color? fillColor;

  const DropdownField({
    super.key,
    this.placeholder,
    required this.value,
    required this.items,
    required this.onChanged,
    this.fillColor,
  });

  @override
  State<DropdownField<T>> createState() => _DropdownFieldState<T>();
}

class _DropdownFieldState<T> extends State<DropdownField<T>> {
  bool _open = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  void _openMenu() {
    if (_overlayEntry != null) return;
    setState(() => _open = true);
    _overlayEntry = _buildOverlay();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _close() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (_open) setState(() => _open = false);
  }

  OverlayEntry _buildOverlay() {
    final box = context.findRenderObject() as RenderBox;

    return OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _close,
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            offset: Offset.zero,
            showWhenUnlinked: false,
            child: _DropdownMenu<T>(
              value: widget.value,
              items: widget.items,
              onChanged: (value) {
                widget.onChanged(value);
                _close();
              },
              width: box.size.width,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? selectedLabel;
    if (widget.value != null) {
      for (final item in widget.items) {
        if (item.value == widget.value) {
          selectedLabel = item.label;
          break;
        }
      }
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _openMenu,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: widget.fillColor ?? ClayTokens.clayDarkBase,
            borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
            border: Border.all(
              color: _open
                  ? ClayTokens.clayPrimary.withAlpha(128)
                  : ClayTokens.hairline.withAlpha(30),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedLabel ?? widget.placeholder ?? 'Select...',
                  style: ClayTokens.darkBodyMedium.copyWith(
                    color: widget.value != null
                        ? ClayTokens.clayDarkTextPrimary
                        : ClayTokens.clayDarkTextTertiary,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  CupertinoIcons.chevron_down,
                  color: ClayTokens.clayDarkTextTertiary,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownMenu<T> extends StatelessWidget {
  final T? value;
  final List<DropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final double width;

  const _DropdownMenu({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: width,
        child: GlassPanel(
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: items
                .map(
                  (item) => _MenuItem<T>(
                    item: item,
                    isSelected: item.value == value,
                    onTap: () => onChanged(item.value),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _MenuItem<T> extends StatelessWidget {
  final DropdownItem<T> item;
  final bool isSelected;
  final VoidCallback onTap;

  const _MenuItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? ClayTokens.clayPrimary.withAlpha(25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.label,
                style: ClayTokens.darkBodyMedium.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? ClayTokens.clayDarkTextPrimary
                      : ClayTokens.clayDarkTextSecondary,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                CupertinoIcons.checkmark_circle_fill,
                color: ClayTokens.clayPrimaryLight,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

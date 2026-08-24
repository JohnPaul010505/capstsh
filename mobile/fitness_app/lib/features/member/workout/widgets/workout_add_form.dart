import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_app/app/design_tokens.dart';
import '../providers/workout_session_provider.dart';
import '../data/met_exercise_catalog.dart';
import '../../../shared/widgets/pressable.dart';
import '../workout_constants.dart';

class WorkoutAddForm extends ConsumerStatefulWidget {
  final WorkoutSessionNotifier notifier;

  const WorkoutAddForm({super.key, required this.notifier});

  @override
  ConsumerState<WorkoutAddForm> createState() => _WorkoutAddFormState();
}

class _WorkoutAddFormState extends ConsumerState<WorkoutAddForm> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MetExercise> get _matches {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final result = <MetExercise>[];
    for (final category in metExerciseCatalog.values) {
      for (final e in category) {
        if (e.name.toLowerCase().startsWith(q)) result.add(e);
      }
    }
    return result.take(WorkoutConstants.maxCatalogSuggestions).toList();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ClayTokens.clayDarkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38383A).withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ADD EXERCISE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8E8E93),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search 140 exercises…',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF7070A0)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF7070A0), size: 18),
              filled: true,
              fillColor: ClayTokens.clayDarkSurfaceElevated,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2A2A45)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFA78BFA)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: const TextStyle(fontSize: 13, color: Color(0xFFFFFFFF)),
          ),
          if (_query.isNotEmpty && matches.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'No catalog match — pick one of the suggestions below.',
              style: TextStyle(fontSize: 11, color: Color(0xFFFF6B61)),
            ),
          ],
          if (matches.isNotEmpty) ...[
            const SizedBox(height: 8),
            Column(
              children: matches.map((e) {
                return PressableCard(
                  onTap: () {
                    widget.notifier.addExercise(e.name);
                    _searchController.clear();
                    setState(() => _query = '');
                    FocusScope.of(context).unfocus();
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 6),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFBF5AF2).withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add, color: Color(0xFFD6A5FF), size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.name,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF)),
                            ),
                            Text(
                              '${e.category} · MET ${e.met}',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
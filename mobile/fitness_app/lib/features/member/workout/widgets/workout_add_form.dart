import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_app/app/design_tokens.dart';
import '../providers/workout_session_provider.dart';
import '../data/met_exercise_repository.dart';
import '../../../shared/widgets/pressable.dart';

class WorkoutAddForm extends ConsumerStatefulWidget {
  final WorkoutSessionNotifier notifier;

  const WorkoutAddForm({super.key, required this.notifier});

  @override
  ConsumerState<WorkoutAddForm> createState() => _WorkoutAddFormState();
}

class _WorkoutAddFormState extends ConsumerState<WorkoutAddForm> {
  final _searchController = TextEditingController();
  final _repository = MetExerciseRepository();
  Timer? _debounceTimer;

  String _query = '';
  List<MetExercise> _searchResults = [];
  bool _isSearching = false;
  DateTime? _searchStartTime;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
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

    _searchStartTime = DateTime.now();
    if (mounted) setState(() => _isSearching = true);

    try {
      final response = await _repository.search(q);
      if (mounted) {
        final elapsed = DateTime.now().difference(_searchStartTime!);
        final remaining = const Duration(seconds: 1) - elapsed;
        if (remaining > Duration.zero) {
          await Future.delayed(remaining);
        }
        setState(() {
          _searchResults = response.matches;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        final elapsed = DateTime.now().difference(_searchStartTime!);
        final remaining = const Duration(seconds: 1) - elapsed;
        if (remaining > Duration.zero) {
          await Future.delayed(remaining);
        }
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  void _addExercise(MetExercise exercise) {
    widget.notifier.addExerciseFromRepository(exercise);
    _searchController.clear();
    setState(() {
      _query = '';
      _searchResults = [];
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
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
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Search exercises…',
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
          if (_isSearching) ...[
            const SizedBox(height: 8),
            const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD6A5FF)),
              ),
            ),
          ],
          if (_searchResults.isEmpty && _query.isNotEmpty && !_isSearching) ...[
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
                return PressableCard(
                  onTap: () => _addExercise(e),
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
                        child: const Icon(
                          Icons.add,
                          color: Color(0xFFD6A5FF),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  e.name,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF)),
                                ),
                              ],
                            ),
                            Text(
                              '${e.category} · MET ${e.metValue.toStringAsFixed(1)}',
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
String _normalizeMealText(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Meal slots are part of identity: breakfast eggs never complete dinner eggs.
String planMealKey(String name, String? mealType) =>
    '${_normalizeMealText(mealType ?? 'snack')}::${_normalizeMealText(name)}';

bool planMealLogged(Map food, Set<String> logged) {
  final name = _normalizeMealText(food['name']?.toString() ?? '');
  if (name.isEmpty) return false;
  final prefix =
      '${_normalizeMealText(food['meal_type']?.toString() ?? 'snack')}::';
  return logged.any((entry) {
    if (!entry.startsWith(prefix)) return false;
    final loggedName = entry.substring(prefix.length);
    return loggedName == name ||
        (loggedName.length >= 4 &&
            name.length >= 4 &&
            (loggedName.contains(name) || name.contains(loggedName)));
  });
}

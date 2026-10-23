String formatTrainerAvailability(String? value) {
  if (value == null || value.trim().isEmpty) return 'Schedule not provided';
  return value
      .replaceAllMapped(RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)\b'), (match) {
        final hour = int.parse(match[1]!);
        return '${hour % 12 == 0 ? 12 : hour % 12}:${match[2]} ${hour < 12 ? 'AM' : 'PM'}';
      })
      .replaceAll('AM-', 'AM–')
      .replaceAll('PM-', 'PM–');
}

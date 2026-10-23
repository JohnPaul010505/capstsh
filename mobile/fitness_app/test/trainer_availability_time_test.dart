import 'package:fitness_app/shared/utils/trainer_availability_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trainer availability uses 12-hour time in member chat', () {
    expect(
      formatTrainerAvailability('Mon 09:00-17:00'),
      'Mon 9:00 AM–5:00 PM',
    );
    expect(
      formatTrainerAvailability('Wed 01:00-17:00'),
      'Wed 1:00 AM–5:00 PM',
    );
    expect(
      formatTrainerAvailability('Fri 12:30-15:00'),
      'Fri 12:30 PM–3:00 PM',
    );
  });
}

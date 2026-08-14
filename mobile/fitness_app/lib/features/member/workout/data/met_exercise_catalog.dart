/// MET (Metabolic Equivalent of Task) exercise catalog for FitSight.
///
/// Values are sourced/approximated from the Compendium of Physical Activities
/// (Ainsworth et al., 2024 update) and standard exercise-science references.
/// Used for calorie calculation: calories = MET * weight(kg) * duration(hours)
library;

/// A single exercise entry with its MET value.
class MetExercise {
  final String name;
  final double met;
  final String category;

  const MetExercise(this.name, this.met, this.category);
}

/// Full catalog grouped by category name.
const Map<String, List<MetExercise>> metExerciseCatalog = {
  'Chest': [
    MetExercise('Bench Press', 6.0, 'Chest'),
    MetExercise('Incline Bench Press', 6.0, 'Chest'),
    MetExercise('Decline Bench Press', 6.0, 'Chest'),
    MetExercise('Dumbbell Bench Press', 6.0, 'Chest'),
    MetExercise('Incline Dumbbell Press', 6.0, 'Chest'),
    MetExercise('Chest Fly Machine', 5.0, 'Chest'),
    MetExercise('Dumbbell Fly', 5.0, 'Chest'),
    MetExercise('Cable Fly', 5.0, 'Chest'),
    MetExercise('Pec Deck', 5.0, 'Chest'),
    MetExercise('Push-up', 8.0, 'Chest'),
    MetExercise('Weighted Push-up', 8.5, 'Chest'),
    MetExercise('Chest Dips', 8.0, 'Chest'),
  ],
  'Back': [
    MetExercise('Lat Pulldown', 5.0, 'Back'),
    MetExercise('Pull-up', 8.0, 'Back'),
    MetExercise('Chin-up', 8.0, 'Back'),
    MetExercise('Assisted Pull-up', 5.5, 'Back'),
    MetExercise('Barbell Row', 6.0, 'Back'),
    MetExercise('Dumbbell Row', 6.0, 'Back'),
    MetExercise('Seated Cable Row', 5.5, 'Back'),
    MetExercise('T-Bar Row', 6.0, 'Back'),
    MetExercise('Machine Row', 5.5, 'Back'),
    MetExercise('Deadlift', 6.5, 'Back'),
    MetExercise('Rack Pull', 6.0, 'Back'),
    MetExercise('Straight Arm Pulldown', 5.0, 'Back'),
  ],
  'Shoulders': [
    MetExercise('Overhead Press', 6.0, 'Shoulders'),
    MetExercise('Dumbbell Shoulder Press', 6.0, 'Shoulders'),
    MetExercise('Arnold Press', 6.0, 'Shoulders'),
    MetExercise('Lateral Raise', 5.0, 'Shoulders'),
    MetExercise('Front Raise', 5.0, 'Shoulders'),
    MetExercise('Rear Delt Fly', 5.0, 'Shoulders'),
    MetExercise('Face Pull', 5.0, 'Shoulders'),
    MetExercise('Upright Row', 5.5, 'Shoulders'),
    MetExercise('Shrugs', 5.0, 'Shoulders'),
    MetExercise('Machine Shoulder Press', 5.5, 'Shoulders'),
  ],
  'Biceps': [
    MetExercise('Barbell Curl', 5.0, 'Biceps'),
    MetExercise('Dumbbell Curl', 5.0, 'Biceps'),
    MetExercise('Hammer Curl', 5.0, 'Biceps'),
    MetExercise('Concentration Curl', 4.5, 'Biceps'),
    MetExercise('Preacher Curl', 5.0, 'Biceps'),
    MetExercise('Cable Curl', 5.0, 'Biceps'),
    MetExercise('EZ Bar Curl', 5.0, 'Biceps'),
    MetExercise('Incline Curl', 5.0, 'Biceps'),
  ],
  'Triceps': [
    MetExercise('Tricep Pushdown', 5.0, 'Triceps'),
    MetExercise('Skull Crusher', 5.5, 'Triceps'),
    MetExercise('Close Grip Bench Press', 6.0, 'Triceps'),
    MetExercise('Tricep Dips', 7.5, 'Triceps'),
    MetExercise('Overhead Extension', 5.0, 'Triceps'),
    MetExercise('Rope Pushdown', 5.0, 'Triceps'),
    MetExercise('Kickback', 4.5, 'Triceps'),
    MetExercise('Bench Dip', 6.5, 'Triceps'),
  ],
  'Legs': [
    MetExercise('Squat', 6.5, 'Legs'),
    MetExercise('Front Squat', 6.5, 'Legs'),
    MetExercise('Hack Squat', 6.0, 'Legs'),
    MetExercise('Goblet Squat', 6.0, 'Legs'),
    MetExercise('Bulgarian Split Squat', 6.5, 'Legs'),
    MetExercise('Leg Press', 6.0, 'Legs'),
    MetExercise('Walking Lunge', 6.5, 'Legs'),
    MetExercise('Reverse Lunge', 6.0, 'Legs'),
    MetExercise('Step-up', 6.5, 'Legs'),
    MetExercise('Leg Extension', 5.0, 'Legs'),
    MetExercise('Leg Curl', 5.0, 'Legs'),
    MetExercise('Romanian Deadlift', 6.5, 'Legs'),
    MetExercise('Stiff Leg Deadlift', 6.5, 'Legs'),
    MetExercise('Hip Thrust', 6.0, 'Legs'),
    MetExercise('Glute Bridge', 5.0, 'Legs'),
    MetExercise('Standing Calf Raise', 4.5, 'Legs'),
    MetExercise('Seated Calf Raise', 4.5, 'Legs'),
    MetExercise('Sumo Squat', 6.5, 'Legs'),
  ],
  'Core': [
    MetExercise('Plank', 3.8, 'Core'),
    MetExercise('Side Plank', 3.8, 'Core'),
    MetExercise('Sit-up', 4.5, 'Core'),
    MetExercise('Crunch', 4.0, 'Core'),
    MetExercise('Bicycle Crunch', 6.0, 'Core'),
    MetExercise('Russian Twist', 5.0, 'Core'),
    MetExercise('Mountain Climber', 8.0, 'Core'),
    MetExercise('Hanging Leg Raise', 6.0, 'Core'),
    MetExercise('Reverse Crunch', 5.0, 'Core'),
    MetExercise('Cable Crunch', 5.5, 'Core'),
    MetExercise('Ab Wheel Rollout', 6.0, 'Core'),
    MetExercise('V-up', 6.0, 'Core'),
  ],
  'Cardio Machines': [
    MetExercise('Walking 3 km/h', 2.8, 'Cardio Machines'),
    MetExercise('Walking 5 km/h', 3.5, 'Cardio Machines'),
    MetExercise('Walking 6 km/h', 4.8, 'Cardio Machines'),
    MetExercise('Incline Walking', 6.0, 'Cardio Machines'),
    MetExercise('Jogging 8 km/h', 8.3, 'Cardio Machines'),
    MetExercise('Running 10 km/h', 9.8, 'Cardio Machines'),
    MetExercise('Running 12 km/h', 11.5, 'Cardio Machines'),
    MetExercise('Sprinting', 16.0, 'Cardio Machines'),
    MetExercise('Elliptical', 5.5, 'Cardio Machines'),
    MetExercise('Rowing Machine Moderate', 7.0, 'Cardio Machines'),
    MetExercise('Rowing Machine Vigorous', 8.5, 'Cardio Machines'),
    MetExercise('Stair Climber', 8.8, 'Cardio Machines'),
    MetExercise('Cycling Light', 4.0, 'Cardio Machines'),
    MetExercise('Cycling Moderate', 6.8, 'Cardio Machines'),
    MetExercise('Cycling Vigorous', 8.8, 'Cardio Machines'),
    MetExercise('Air Bike', 9.0, 'Cardio Machines'),
  ],
  'Functional Training': [
    MetExercise('Battle Rope', 8.5, 'Functional Training'),
    MetExercise('Burpee', 10.0, 'Functional Training'),
    MetExercise('Box Jump', 9.0, 'Functional Training'),
    MetExercise('Kettlebell Swing', 9.5, 'Functional Training'),
    MetExercise('Farmer Carry', 7.0, 'Functional Training'),
    MetExercise('Tire Flip', 9.0, 'Functional Training'),
    MetExercise('Sled Push', 8.5, 'Functional Training'),
    MetExercise('Sled Pull', 8.5, 'Functional Training'),
    MetExercise('Medicine Ball Slam', 8.0, 'Functional Training'),
    MetExercise('Jump Rope Moderate', 11.0, 'Functional Training'),
    MetExercise('Jump Rope Fast', 12.3, 'Functional Training'),
    MetExercise('Bear Crawl', 8.0, 'Functional Training'),
  ],
  'CrossFit / HIIT': [
    MetExercise('Thruster', 9.0, 'CrossFit / HIIT'),
    MetExercise('Wall Ball', 8.5, 'CrossFit / HIIT'),
    MetExercise('Clean and Press', 8.5, 'CrossFit / HIIT'),
    MetExercise('Snatch', 8.5, 'CrossFit / HIIT'),
    MetExercise('Power Clean', 8.5, 'CrossFit / HIIT'),
    MetExercise('Push Press', 8.0, 'CrossFit / HIIT'),
    MetExercise('Push Jerk', 8.5, 'CrossFit / HIIT'),
    MetExercise('Turkish Get-Up', 7.5, 'CrossFit / HIIT'),
    MetExercise('EMOM Workout', 10.0, 'CrossFit / HIIT'),
    MetExercise('AMRAP Workout', 10.5, 'CrossFit / HIIT'),
    MetExercise('Tabata Workout', 11.0, 'CrossFit / HIIT'),
    MetExercise('HIIT Circuit', 10.0, 'CrossFit / HIIT'),
  ],
  'Bodyweight': [
    MetExercise('Air Squat', 5.5, 'Bodyweight'),
    MetExercise('Jump Squat', 8.0, 'Bodyweight'),
    MetExercise('Walking Push-up', 8.0, 'Bodyweight'),
    MetExercise('Pike Push-up', 8.0, 'Bodyweight'),
    MetExercise('Superman', 3.5, 'Bodyweight'),
    MetExercise('Bird Dog', 3.5, 'Bodyweight'),
    MetExercise('Glute Kickback', 4.0, 'Bodyweight'),
    MetExercise('Donkey Kick', 4.0, 'Bodyweight'),
    MetExercise('High Knees', 9.0, 'Bodyweight'),
    MetExercise('Jumping Jack', 8.0, 'Bodyweight'),
    MetExercise('Lunges', 6.0, 'Bodyweight'),
    MetExercise('Wall Sit', 4.5, 'Bodyweight'),
  ],
  'Mobility & Recovery': [
    MetExercise('Stretching', 2.3, 'Mobility & Recovery'),
    MetExercise('Dynamic Stretching', 3.0, 'Mobility & Recovery'),
    MetExercise('Foam Rolling', 2.0, 'Mobility & Recovery'),
    MetExercise('Yoga (Hatha)', 2.5, 'Mobility & Recovery'),
    MetExercise('Power Yoga', 4.0, 'Mobility & Recovery'),
    MetExercise('Pilates', 3.0, 'Mobility & Recovery'),
    MetExercise('Cool Down Walking', 2.8, 'Mobility & Recovery'),
    MetExercise('Mobility Drills', 3.0, 'Mobility & Recovery'),
  ],
};

/// Flat lookup map: exercise name -> MET value.
/// Use this for quick lookups when a member types/selects an exercise name.
final Map<String, double> metLookup = {
  for (final category in metExerciseCatalog.values)
    for (final exercise in category) exercise.name: exercise.met,
};

final Map<String, String> categoryLookup = {
  for (final entries in metExerciseCatalog.values)
    for (final e in entries) e.name: e.category,
};

/// Returns the MET value for a given exercise name, or a fallback
/// (moderate resistance training, 5.0) if the exercise isn't in the catalog.
double getMetValue(String exerciseName, {double fallback = 5.0}) {
  return metLookup[exerciseName] ?? fallback;
}

/// Returns the category name for a given exercise name, or 'General' if
/// the exercise isn't in the catalog.
String getCategoryFor(String exerciseName) {
  return categoryLookup[exerciseName] ?? 'General';
}

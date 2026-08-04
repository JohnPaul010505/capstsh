# Mobile Apps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build shared Dart package + Trainer Flutter app + Member Flutter app for the fitness system.

**Architecture:** Monorepo with `mobile/shared/` Dart package containing models, services, and Riverpod providers. Two Flutter app shells (`trainer_app/`, `member_app/`) consume the shared package.

**Tech Stack:** Flutter 3.44, Dart 3.12, Riverpod, GoRouter, fl_chart, supabase_flutter, intl

---

## Phase 1: Shared Package

### Task 1: Project Scaffolding

**Files:**
- Create: `mobile/shared/pubspec.yaml`
- Create: `mobile/shared/lib/models/profile.dart`
- Create: `mobile/shared/lib/models/workout_log.dart`
- Create: `mobile/shared/lib/models/body_measurement.dart`
- Create: `mobile/shared/lib/models/goal.dart`
- Create: `mobile/shared/lib/models/trainer_feedback.dart`
- Create: `mobile/shared/lib/models/meal_record.dart`
- Create: `mobile/shared/lib/models/chat.dart`
- Create: `mobile/shared/lib/models/membership.dart`
- Create: `mobile/shared/lib/models/notification_model.dart`
- Create: `mobile/shared/lib/models/trainer_assignment.dart`
- Create: `mobile/shared/lib/models/prediction.dart`
- Create: `mobile/shared/lib/services/supabase_client.dart`
- Create: `mobile/shared/lib/services/auth_service.dart`
- Create: `mobile/shared/lib/providers/auth_provider.dart`
- Create: `mobile/shared/lib/shared.dart` (barrel export)

- [ ] **Step 1: Create shared package directory and pubspec**

```bash
New-Item -ItemType Directory -Path "mobile/shared/lib/models" -Force
New-Item -ItemType Directory -Path "mobile/shared/lib/services" -Force
New-Item -ItemType Directory -Path "mobile/shared/lib/providers" -Force
```

```yaml
# mobile/shared/pubspec.yaml
name: shared
version: 0.0.1
publish_to: none

environment:
  sdk: ^3.12.0

dependencies:
  supabase_flutter: ^2.8.0
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1
  intl: ^0.20.2
  json_annotation: ^4.9.0

dev_dependencies:
  build_runner: ^2.4.0
  json_serializable: ^6.9.0
  riverpod_generator: ^2.6.3
```

- [ ] **Step 2: Create Profile model**

```dart
// mobile/shared/lib/models/profile.dart
class Profile {
  final String id;
  final String role;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String? dateOfBirth;
  final String? gender;
  final DateTime createdAt;
  final DateTime updatedAt;

  Profile({
    required this.id,
    required this.role,
    required this.fullName,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.dateOfBirth,
    this.gender,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    role: json['role'] as String,
    fullName: json['full_name'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    dateOfBirth: json['date_of_birth'] as String?,
    gender: json['gender'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'full_name': fullName,
    'email': email,
    'phone': phone,
    'avatar_url': avatarUrl,
    'date_of_birth': dateOfBirth,
    'gender': gender,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
```

- [ ] **Step 3: Create WorkoutLog model**

```dart
// mobile/shared/lib/models/workout_log.dart
class WorkoutLog {
  final String id;
  final String memberId;
  final String exerciseName;
  final int? sets;
  final int? reps;
  final double? weight;
  final int? durationMinutes;
  final String? notes;
  final DateTime loggedAt;

  WorkoutLog({
    required this.id,
    required this.memberId,
    required this.exerciseName,
    this.sets,
    this.reps,
    this.weight,
    this.durationMinutes,
    this.notes,
    required this.loggedAt,
  });

  factory WorkoutLog.fromJson(Map<String, dynamic> json) => WorkoutLog(
    id: json['id'] as String,
    memberId: json['member_id'] as String,
    exerciseName: json['exercise_name'] as String,
    sets: json['sets'] as int?,
    reps: json['reps'] as int?,
    weight: (json['weight'] as num?)?.toDouble(),
    durationMinutes: json['duration_minutes'] as int?,
    notes: json['notes'] as String?,
    loggedAt: DateTime.parse(json['logged_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'member_id': memberId,
    'exercise_name': exerciseName,
    'sets': sets,
    'reps': reps,
    'weight': weight,
    'duration_minutes': durationMinutes,
    'notes': notes,
    'logged_at': loggedAt.toIso8601String(),
  };
}
```

- [ ] **Step 4: Create remaining models**

```dart
// mobile/shared/lib/models/body_measurement.dart
class BodyMeasurement {
  final String id;
  final String memberId;
  final double? weightKg;
  final double? heightCm;
  final double? bodyFatPct;
  final double? chestCm;
  final double? waistCm;
  final double? hipsCm;
  final double? armCm;
  final double? thighCm;
  final DateTime measuredAt;

  BodyMeasurement({
    required this.id,
    required this.memberId,
    this.weightKg,
    this.heightCm,
    this.bodyFatPct,
    this.chestCm,
    this.waistCm,
    this.hipsCm,
    this.armCm,
    this.thighCm,
    required this.measuredAt,
  });

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) => BodyMeasurement(
    id: json['id'] as String,
    memberId: json['member_id'] as String,
    weightKg: (json['weight_kg'] as num?)?.toDouble(),
    heightCm: (json['height_cm'] as num?)?.toDouble(),
    bodyFatPct: (json['body_fat_pct'] as num?)?.toDouble(),
    chestCm: (json['chest_cm'] as num?)?.toDouble(),
    waistCm: (json['waist_cm'] as num?)?.toDouble(),
    hipsCm: (json['hips_cm'] as num?)?.toDouble(),
    armCm: (json['arm_cm'] as num?)?.toDouble(),
    thighCm: (json['thigh_cm'] as num?)?.toDouble(),
    measuredAt: DateTime.parse(json['measured_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'member_id': memberId,
    'weight_kg': weightKg,
    'height_cm': heightCm,
    'body_fat_pct': bodyFatPct,
    'chest_cm': chestCm,
    'waist_cm': waistCm,
    'hips_cm': hipsCm,
    'arm_cm': armCm,
    'thigh_cm': thighCm,
    'measured_at': measuredAt.toIso8601String(),
  };
}
```

```dart
// mobile/shared/lib/models/goal.dart
class Goal {
  final String id;
  final String memberId;
  final String title;
  final String? description;
  final double? targetValue;
  final double? currentValue;
  final String? unit;
  final String? deadline;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Goal({
    required this.id,
    required this.memberId,
    required this.title,
    this.description,
    this.targetValue,
    this.currentValue,
    this.unit,
    this.deadline,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
    id: json['id'] as String,
    memberId: json['member_id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    targetValue: (json['target_value'] as num?)?.toDouble(),
    currentValue: (json['current_value'] as num?)?.toDouble(),
    unit: json['unit'] as String?,
    deadline: json['deadline'] as String?,
    status: json['status'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'member_id': memberId,
    'title': title,
    'description': description,
    'target_value': targetValue,
    'current_value': currentValue,
    'unit': unit,
    'deadline': deadline,
    'status': status,
  };
}
```

```dart
// mobile/shared/lib/models/trainer_feedback.dart
class TrainerFeedback {
  final String id;
  final String trainerId;
  final String memberId;
  final String content;
  final DateTime createdAt;

  TrainerFeedback({
    required this.id,
    required this.trainerId,
    required this.memberId,
    required this.content,
    required this.createdAt,
  });

  factory TrainerFeedback.fromJson(Map<String, dynamic> json) => TrainerFeedback(
    id: json['id'] as String,
    trainerId: json['trainer_id'] as String,
    memberId: json['member_id'] as String,
    content: json['content'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'trainer_id': trainerId,
    'member_id': memberId,
    'content': content,
  };
}
```

```dart
// mobile/shared/lib/models/meal_record.dart
class MealRecord {
  final String id;
  final String memberId;
  final String mealType;
  final String foodItems;
  final int? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final DateTime recordedAt;

  MealRecord({
    required this.id,
    required this.memberId,
    required this.mealType,
    required this.foodItems,
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    required this.recordedAt,
  });

  factory MealRecord.fromJson(Map<String, dynamic> json) => MealRecord(
    id: json['id'] as String,
    memberId: json['member_id'] as String,
    mealType: json['meal_type'] as String,
    foodItems: json['food_items'] as String,
    calories: json['calories'] as int?,
    proteinG: (json['protein_g'] as num?)?.toDouble(),
    carbsG: (json['carbs_g'] as num?)?.toDouble(),
    fatG: (json['fat_g'] as num?)?.toDouble(),
    recordedAt: DateTime.parse(json['recorded_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'member_id': memberId,
    'meal_type': mealType,
    'food_items': foodItems,
    'calories': calories,
    'protein_g': proteinG,
    'carbs_g': carbsG,
    'fat_g': fatG,
  };
}
```

```dart
// mobile/shared/lib/models/chat.dart
class ChatRoom {
  final String id;
  final String participantOne;
  final String participantTwo;
  final DateTime createdAt;

  ChatRoom({
    required this.id,
    required this.participantOne,
    required this.participantTwo,
    required this.createdAt,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) => ChatRoom(
    id: json['id'] as String,
    participantOne: json['participant_one'] as String,
    participantTwo: json['participant_two'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    roomId: json['room_id'] as String,
    senderId: json['sender_id'] as String,
    content: json['content'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'room_id': roomId,
    'sender_id': senderId,
    'content': content,
  };
}
```

```dart
// mobile/shared/lib/models/membership.dart
class Membership {
  final String id;
  final String memberId;
  final String planName;
  final double price;
  final String startDate;
  final String endDate;
  final String status;
  final DateTime createdAt;

  Membership({
    required this.id,
    required this.memberId,
    required this.planName,
    required this.price,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdAt,
  });

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
    id: json['id'] as String,
    memberId: json['member_id'] as String,
    planName: json['plan_name'] as String,
    price: (json['price'] as num).toDouble(),
    startDate: json['start_date'] as String,
    endDate: json['end_date'] as String,
    status: json['status'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
```

```dart
// mobile/shared/lib/models/notification_model.dart
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String? body;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    this.body,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    title: json['title'] as String,
    body: json['body'] as String?,
    read: json['read'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'title': title,
    'body': body,
    'read': read,
  };
}
```

```dart
// mobile/shared/lib/models/trainer_assignment.dart
class TrainerAssignment {
  final String id;
  final String trainerId;
  final String memberId;
  final DateTime assignedAt;
  final String status;

  TrainerAssignment({
    required this.id,
    required this.trainerId,
    required this.memberId,
    required this.assignedAt,
    required this.status,
  });

  factory TrainerAssignment.fromJson(Map<String, dynamic> json) => TrainerAssignment(
    id: json['id'] as String,
    trainerId: json['trainer_id'] as String,
    memberId: json['member_id'] as String,
    assignedAt: DateTime.parse(json['assigned_at'] as String),
    status: json['status'] as String,
  );
}
```

```dart
// mobile/shared/lib/models/prediction.dart
class Prediction {
  final String id;
  final String memberId;
  final String metricName;
  final double? predictedValue;
  final String? predictedDate;
  final double? confidence;
  final DateTime createdAt;

  Prediction({
    required this.id,
    required this.memberId,
    required this.metricName,
    this.predictedValue,
    this.predictedDate,
    this.confidence,
    required this.createdAt,
  });

  factory Prediction.fromJson(Map<String, dynamic> json) => Prediction(
    id: json['id'] as String,
    memberId: json['member_id'] as String,
    metricName: json['metric_name'] as String,
    predictedValue: (json['predicted_value'] as num?)?.toDouble(),
    predictedDate: json['predicted_date'] as String?,
    confidence: (json['confidence'] as num?)?.toDouble(),
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
```

- [ ] **Step 5: Create Supabase client service**

```dart
// mobile/shared/lib/services/supabase_client.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClientService {
  static final SupabaseClientService _instance = SupabaseClientService._();
  factory SupabaseClientService() => _instance;
  SupabaseClientService._();

  SupabaseClient get client => Supabase.instance.client;

  Future<void> initialize({
    required String supabaseUrl,
    required String anonKey,
  }) async {
    await Supabase.initialize(url: supabaseUrl, anonKey: anonKey);
  }
}
```

- [ ] **Step 6: Create Auth service**

```dart
// mobile/shared/lib/services/auth_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import 'supabase_client.dart';

class AuthService {
  final SupabaseClient _client;

  AuthService() : _client = SupabaseClientService().client;

  Future<Profile?> signIn({required String email, required String password}) async {
    final response = await _client.auth.signInWithPassword(email: email, password: password);
    if (response.user == null) return null;
    return _fetchProfile(response.user!.id);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<Profile?> _fetchProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return Profile.fromJson(response);
  }

  Session? get currentSession => _client.auth.currentSession;
  Profile? get currentProfile => null; // Managed by provider
}
```

- [ ] **Step 7: Create Auth provider (Riverpod)**

```dart
// mobile/shared/lib/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<Profile?>>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<Profile?>> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AsyncValue.data(null));

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final profile = await _authService.signIn(email: email, password: password);
      state = AsyncValue.data(profile);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = const AsyncValue.data(null);
  }
}
```

- [ ] **Step 8: Create barrel export**

```dart
// mobile/shared/lib/shared.dart
export 'models/profile.dart';
export 'models/workout_log.dart';
export 'models/body_measurement.dart';
export 'models/goal.dart';
export 'models/trainer_feedback.dart';
export 'models/meal_record.dart';
export 'models/chat.dart';
export 'models/membership.dart';
export 'models/notification_model.dart';
export 'models/trainer_assignment.dart';
export 'models/prediction.dart';
export 'services/supabase_client.dart';
export 'services/auth_service.dart';
export 'providers/auth_provider.dart';
```

- [ ] **Step 9: Verify shared package**

Run: `cd mobile/shared && dart pub get`
Expected: Packages resolve successfully.

---

### Task 2: Shared Services + Providers

**Files:**
- Create: `mobile/shared/lib/services/workout_service.dart`
- Create: `mobile/shared/lib/services/measurement_service.dart`
- Create: `mobile/shared/lib/services/goal_service.dart`
- Create: `mobile/shared/lib/services/chat_service.dart`
- Create: `mobile/shared/lib/services/meal_service.dart`
- Create: `mobile/shared/lib/services/feedback_service.dart`
- Modify: `mobile/shared/lib/shared.dart` (add exports)

- [ ] **Step 1: Create WorkoutService**

```dart
// mobile/shared/lib/services/workout_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout_log.dart';
import 'supabase_client.dart';

class WorkoutService {
  final SupabaseClient _client;

  WorkoutService() : _client = SupabaseClientService().client;

  Future<List<WorkoutLog>> getWorkouts(String memberId) async {
    final response = await _client
        .from('workout_logs')
        .select()
        .eq('member_id', memberId)
        .order('logged_at', ascending: false);
    return (response as List).map((e) => WorkoutLog.fromJson(e)).toList();
  }

  Future<WorkoutLog> createWorkout(WorkoutLog log) async {
    final response = await _client
        .from('workout_logs')
        .insert(log.toJson())
        .select()
        .single();
    return WorkoutLog.fromJson(response);
  }
}
```

- [ ] **Step 2: Create MeasurementService**

```dart
// mobile/shared/lib/services/measurement_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/body_measurement.dart';
import 'supabase_client.dart';

class MeasurementService {
  final SupabaseClient _client;

  MeasurementService() : _client = SupabaseClientService().client;

  Future<List<BodyMeasurement>> getMeasurements(String memberId) async {
    final response = await _client
        .from('body_measurements')
        .select()
        .eq('member_id', memberId)
        .order('measured_at', ascending: true);
    return (response as List).map((e) => BodyMeasurement.fromJson(e)).toList();
  }

  Future<BodyMeasurement> createMeasurement(BodyMeasurement m) async {
    final response = await _client
        .from('body_measurements')
        .insert(m.toJson())
        .select()
        .single();
    return BodyMeasurement.fromJson(response);
  }
}
```

- [ ] **Step 3: Create GoalService**

```dart
// mobile/shared/lib/services/goal_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/goal.dart';
import 'supabase_client.dart';

class GoalService {
  final SupabaseClient _client;

  GoalService() : _client = SupabaseClientService().client;

  Future<List<Goal>> getGoals(String memberId) async {
    final response = await _client
        .from('goals')
        .select()
        .eq('member_id', memberId)
        .order('created_at', ascending: false);
    return (response as List).map((e) => Goal.fromJson(e)).toList();
  }

  Future<Goal> createGoal(Goal goal) async {
    final response = await _client
        .from('goals')
        .insert(goal.toJson())
        .select()
        .single();
    return Goal.fromJson(response);
  }

  Future<Goal> updateGoal(String id, Map<String, dynamic> updates) async {
    final response = await _client
        .from('goals')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return Goal.fromJson(response);
  }
}
```

- [ ] **Step 4: Create ChatService**

```dart
// mobile/shared/lib/services/chat_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat.dart';
import 'supabase_client.dart';

class ChatService {
  final SupabaseClient _client;

  ChatService() : _client = SupabaseClientService().client;

  Future<List<ChatRoom>> getRooms(String userId) async {
    final response = await _client
        .from('chat_rooms')
        .select()
        .or('participant_one.eq.$userId,participant_two.eq.$userId')
        .order('created_at', ascending: false);
    return (response as List).map((e) => ChatRoom.fromJson(e)).toList();
  }

  Future<List<ChatMessage>> getMessages(String roomId) async {
    final response = await _client
        .from('chat_messages')
        .select()
        .eq('room_id', roomId)
        .order('created_at', ascending: true);
    return (response as List).map((e) => ChatMessage.fromJson(e)).toList();
  }

  Future<ChatMessage> sendMessage(ChatMessage message) async {
    final response = await _client
        .from('chat_messages')
        .insert(message.toJson())
        .select()
        .single();
    return ChatMessage.fromJson(response);
  }

  RealtimeChannel subscribeToRoom(String roomId, Function(Map<String, dynamic>) onMessage) {
    return _client
        .channel('room-$roomId')
        .on(
          RealtimeListenTypes.postgresChanges,
          ChannelFilter(event: 'INSERT', schema: 'public', table: 'chat_messages', filter: 'room_id=eq.$roomId'),
          (payload) => onMessage(payload.newRecord!),
        )
        .subscribe();
  }
}
```

- [ ] **Step 5: Create MealService**

```dart
// mobile/shared/lib/services/meal_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meal_record.dart';
import 'supabase_client.dart';

class MealService {
  final SupabaseClient _client;

  MealService() : _client = SupabaseClientService().client;

  Future<List<MealRecord>> getMeals(String memberId, {DateTime? date}) async {
    var query = _client
        .from('meal_records')
        .select()
        .eq('member_id', memberId);

    if (date != null) {
      final dateStr = date.toIso8601String().split('T')[0];
      query = query.gte('recorded_at', '${dateStr}T00:00:00')
          .lte('recorded_at', '${dateStr}T23:59:59');
    }

    final response = await query.order('recorded_at', ascending: false);
    return (response as List).map((e) => MealRecord.fromJson(e)).toList();
  }

  Future<MealRecord> createMeal(MealRecord meal) async {
    final response = await _client
        .from('meal_records')
        .insert(meal.toJson())
        .select()
        .single();
    return MealRecord.fromJson(response);
  }
}
```

- [ ] **Step 6: Create FeedbackService**

```dart
// mobile/shared/lib/services/feedback_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trainer_feedback.dart';
import 'supabase_client.dart';

class FeedbackService {
  final SupabaseClient _client;

  FeedbackService() : _client = SupabaseClientService().client;

  Future<List<TrainerFeedback>> getFeedbackForMember(String memberId) async {
    final response = await _client
        .from('trainer_feedback')
        .select()
        .eq('member_id', memberId)
        .order('created_at', ascending: false);
    return (response as List).map((e) => TrainerFeedback.fromJson(e)).toList();
  }

  Future<TrainerFeedback> submitFeedback(TrainerFeedback feedback) async {
    final response = await _client
        .from('trainer_feedback')
        .insert(feedback.toJson())
        .select()
        .single();
    return TrainerFeedback.fromJson(response);
  }
}
```

- [ ] **Step 7: Update barrel export**

```dart
// Update mobile/shared/lib/shared.dart — append:
export 'services/workout_service.dart';
export 'services/measurement_service.dart';
export 'services/goal_service.dart';
export 'services/chat_service.dart';
export 'services/meal_service.dart';
export 'services/feedback_service.dart';
```

- [ ] **Step 8: Verify**

Run: `cd mobile/shared && dart pub get`
Expected: No errors.

---

## Phase 2: Trainer App

### Task 3: Scaffold Trainer App

**Files:**
- Create: `mobile/trainer_app/pubspec.yaml`
- Create: `mobile/trainer_app/lib/main.dart`
- Create: `mobile/trainer_app/lib/app/app.dart`
- Create: `mobile/trainer_app/lib/app/router.dart`
- Create: `mobile/trainer_app/lib/features/auth/pages/login_page.dart`
- Create: `mobile/trainer_app/lib/features/dashboard/pages/dashboard_page.dart`
- Create: `mobile/trainer_app/lib/features/members/pages/members_list_page.dart`
- Create: `mobile/trainer_app/lib/features/members/pages/member_detail_page.dart`
- Create: `mobile/trainer_app/lib/features/chat/pages/chat_list_page.dart`
- Create: `mobile/trainer_app/lib/features/chat/pages/chat_room_page.dart`
- Create: `mobile/trainer_app/lib/features/profile/pages/profile_page.dart`

- [ ] **Step 1: Create pubspec.yaml**

```yaml
# mobile/trainer_app/pubspec.yaml
name: trainer_app
version: 1.0.0
publish_to: none

environment:
  sdk: ^3.12.0

dependencies:
  flutter:
    sdk: flutter
  shared:
    path: ../shared
  go_router: ^14.8.0
  flutter_riverpod: ^2.6.1
  fl_chart: ^0.70.0
  intl: ^0.20.2

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
```

- [ ] **Step 2: Create main.dart**

```dart
// mobile/trainer_app/lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/supabase_client.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseClientService().initialize(
    supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  runApp(const ProviderScope(child: TrainerApp()));
}
```

- [ ] **Step 3: Create app.dart**

```dart
// mobile/trainer_app/lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';

class TrainerApp extends ConsumerWidget {
  const TrainerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Trainer App',
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      routerConfig: router,
    );
  }
}
```

- [ ] **Step 4: Create router.dart**

```dart
// mobile/trainer_app/lib/app/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/providers/auth_provider.dart';
import '../features/auth/pages/login_page.dart';
import '../features/dashboard/pages/dashboard_page.dart';
import '../features/members/pages/members_list_page.dart';
import '../features/members/pages/member_detail_page.dart';
import '../features/chat/pages/chat_list_page.dart';
import '../features/chat/pages/chat_room_page.dart';
import '../features/profile/pages/profile_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardPage()),
          GoRoute(
            path: '/members',
            builder: (_, __) => const MembersListPage(),
            routes: [
              GoRoute(path: ':id', builder: (_, state) => MemberDetailPage(id: state.pathParameters['id']!)),
            ],
          ),
          GoRoute(path: '/chat', builder: (_, __) => const ChatListPage()),
          GoRoute(path: '/chat/:roomId', builder: (_, state) => ChatRoomPage(roomId: state.pathParameters['roomId']!)),
          GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
        ],
      ),
    ],
  );
});

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(context),
        onDestinationSelected: (i) => _onTap(context, i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Members'),
          NavigationDestination(icon: Icon(Icons.chat), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/members')) return 1;
    if (location.startsWith('/chat')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/dashboard');
      case 1: context.go('/members');
      case 2: context.go('/chat');
      case 3: context.go('/profile');
    }
  }
}
```

- [ ] **Step 5: Create LoginPage**

```dart
// mobile/trainer_app/lib/features/auth/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _error = null);
    await ref.read(authProvider.notifier).signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Trainer Login', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: authState.isLoading ? null : _login,
                child: authState.isLoading ? const CircularProgressIndicator() : const Text('Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Create placeholder pages for remaining routes**

```dart
// mobile/trainer_app/lib/features/dashboard/pages/dashboard_page.dart
import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Dashboard'));
  }
}
```

```dart
// mobile/trainer_app/lib/features/members/pages/members_list_page.dart
import 'package:flutter/material.dart';

class MembersListPage extends StatelessWidget {
  const MembersListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Members'));
  }
}
```

```dart
// mobile/trainer_app/lib/features/members/pages/member_detail_page.dart
import 'package:flutter/material.dart';

class MemberDetailPage extends StatelessWidget {
  final String id;
  const MemberDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Member $id'));
  }
}
```

```dart
// mobile/trainer_app/lib/features/chat/pages/chat_list_page.dart
import 'package:flutter/material.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Chat'));
  }
}
```

```dart
// mobile/trainer_app/lib/features/chat/pages/chat_room_page.dart
import 'package:flutter/material.dart';

class ChatRoomPage extends StatelessWidget {
  final String roomId;
  const ChatRoomPage({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Room $roomId'));
  }
}
```

```dart
// mobile/trainer_app/lib/features/profile/pages/profile_page.dart
import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Profile'));
  }
}
```

- [ ] **Step 7: Verify**

Run: `cd mobile/trainer_app && flutter pub get`
Expected: Packages resolve, shared package is linked.

---

### Task 4: Trainer Dashboard + Members List

**Files:**
- Modify: `mobile/trainer_app/lib/features/dashboard/pages/dashboard_page.dart`
- Modify: `mobile/trainer_app/lib/features/members/pages/members_list_page.dart`
- Modify: `mobile/trainer_app/lib/features/members/pages/member_detail_page.dart`

- [ ] **Step 1: Implement DashboardPage**

```dart
// mobile/trainer_app/lib/features/dashboard/pages/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/supabase_client.dart';

final dashboardStatsProvider = FutureProvider((ref) async {
  final client = SupabaseClientService().client;
  final members = await client.from('trainer_assignments').select('id', count: CountOption.exact).eq('trainer_id', client.auth.currentUser!.id).eq('status', 'active');
  final feedback = await client.from('trainer_feedback').select('id', count: CountOption.exact).eq('trainer_id', client.auth.currentUser!.id);
  return {
    'members': members.count ?? 0,
    'feedback': feedback.count ?? 0,
  };
});

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: statsAsync.when(
        data: (stats) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.people, color: Colors.green),
                  title: Text('${stats['members']} Assigned Members'),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.feedback, color: Colors.blue),
                  title: Text('${stats['feedback']} Feedback Submitted'),
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
```

- [ ] **Step 2: Implement MembersListPage**

```dart
// mobile/trainer_app/lib/features/members/pages/members_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/models/profile.dart';
import 'package:shared/services/supabase_client.dart';

final assignedMembersProvider = FutureProvider<List<Profile>>((ref) async {
  final client = SupabaseClientService().client;
  final userId = client.auth.currentUser!.id;
  final response = await client
      .from('trainer_assignments')
      .select('profiles!trainer_assignments_member_id_fkey(*)')
      .eq('trainer_id', userId)
      .eq('status', 'active');
  return (response as List).map((e) => Profile.fromJson(e['profiles'] as Map<String, dynamic>)).toList();
});

class MembersListPage extends ConsumerWidget {
  const MembersListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(assignedMembersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Members')),
      body: membersAsync.when(
        data: (members) => ListView.builder(
          itemCount: members.length,
          itemBuilder: (_, i) => ListTile(
            leading: CircleAvatar(child: Text(members[i].fullName[0])),
            title: Text(members[i].fullName),
            subtitle: Text(members[i].email),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/members/${members[i].id}'),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
```

- [ ] **Step 3: Implement MemberDetailPage**

```dart
// mobile/trainer_app/lib/features/members/pages/member_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/models/profile.dart';
import 'package:shared/services/supabase_client.dart';

final memberDetailProvider = FutureProvider.family<Profile?, String>((ref, id) async {
  final client = SupabaseClientService().client;
  final response = await client.from('profiles').select().eq('id', id).single();
  return Profile.fromJson(response);
});

class MemberDetailPage extends ConsumerWidget {
  final String id;
  const MemberDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberAsync = ref.watch(memberDetailProvider(id));

    return Scaffold(
      appBar: AppBar(title: const Text('Member Profile')),
      body: memberAsync.when(
        data: (member) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(member!.fullName[0]), radius: 30),
                title: Text(member.fullName, style: Theme.of(context).textTheme.titleLarge),
                subtitle: Text(member.email),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(leading: const Icon(Icons.fitness_center), title: const Text('View Workouts'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
                  ListTile(leading: const Icon(Icons.show_chart), title: const Text('View Progress'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
                  ListTile(leading: const Icon(Icons.feedback), title: const Text('Submit Feedback'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
                  ListTile(leading: const Icon(Icons.flag), title: const Text('Goals'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
                ],
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
```

---

### Task 5: Trainer Chat

**Files:**
- Modify: `mobile/trainer_app/lib/features/chat/pages/chat_list_page.dart`
- Modify: `mobile/trainer_app/lib/features/chat/pages/chat_room_page.dart`

- [ ] **Step 1: Implement ChatListPage with Realtime**

```dart
// mobile/trainer_app/lib/features/chat/pages/chat_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import 'package:shared/models/chat.dart';

final chatRoomsProvider = FutureProvider<List<ChatRoom>>((ref) async {
  final client = SupabaseClientService().client;
  final userId = client.auth.currentUser!.id;
  final response = await client
      .from('chat_rooms')
      .select('*, participant_one_profile:profiles!chat_rooms_participant_one_fkey(full_name), participant_two_profile:profiles!chat_rooms_participant_two_fkey(full_name)')
      .or('participant_one.eq.$userId,participant_two.eq.$userId')
      .order('created_at', ascending: false);
  return (response as List).map((e) => ChatRoom.fromJson(e)).toList();
});

class ChatListPage extends ConsumerWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(chatRoomsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: roomsAsync.when(
        data: (rooms) => ListView.builder(
          itemCount: rooms.length,
          itemBuilder: (_, i) => ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text('Chat ${i + 1}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/chat/${rooms[i].id}'),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
```

- [ ] **Step 2: Implement ChatRoomPage with Realtime messages**

```dart
// mobile/trainer_app/lib/features/chat/pages/chat_room_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/models/chat.dart';
import 'package:shared/services/chat_service.dart';

final messagesProvider = FutureProvider.family<List<ChatMessage>, String>((ref, roomId) async {
  return ChatService().getMessages(roomId);
});

class ChatRoomPage extends ConsumerStatefulWidget {
  final String roomId;
  const ChatRoomPage({super.key, required this.roomId});

  @override
  ConsumerState<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends ConsumerState<ChatRoomPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    _chatService.subscribeToRoom(widget.roomId, (_) {
      ref.invalidate(messagesProvider(widget.roomId));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty) return;
    final client = SupabaseClientService().client;
    await _chatService.sendMessage(ChatMessage(
      id: '',
      roomId: widget.roomId,
      senderId: client.auth.currentUser!.id,
      content: _controller.text.trim(),
      createdAt: DateTime.now(),
    ));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.roomId));

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) => ListView.builder(
                controller: _scrollController,
                itemCount: messages.length,
                itemBuilder: (_, i) => ListTile(title: Text(messages[i].content), subtitle: Text(messages[i].createdAt.toIso8601String())),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(hintText: 'Type a message...'))),
                IconButton(onPressed: _send, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Phase 3: Member App

### Task 6: Scaffold Member App

**Files:**
- Create: `mobile/member_app/pubspec.yaml`
- Create: `mobile/member_app/lib/main.dart`
- Create: `mobile/member_app/lib/app/app.dart`
- Create: `mobile/member_app/lib/app/router.dart`
- Create: `mobile/member_app/lib/features/auth/pages/login_page.dart`
- Create: `mobile/member_app/lib/features/dashboard/pages/dashboard_page.dart`
- Create: `mobile/member_app/lib/features/workouts/pages/workout_list_page.dart`
- Create: `mobile/member_app/lib/features/workouts/pages/log_workout_page.dart`
- Create: `mobile/member_app/lib/features/measurements/pages/measurement_page.dart`
- Create: `mobile/member_app/lib/features/goals/pages/goals_page.dart`
- Create: `mobile/member_app/lib/features/goals/pages/create_goal_page.dart`
- Create: `mobile/member_app/lib/features/meals/pages/meal_list_page.dart`
- Create: `mobile/member_app/lib/features/meals/pages/log_meal_page.dart`
- Create: `mobile/member_app/lib/features/meals/pages/recommendations_page.dart`
- Create: `mobile/member_app/lib/features/feedback/pages/feedback_page.dart`
- Create: `mobile/member_app/lib/features/chat/pages/chat_list_page.dart`
- Create: `mobile/member_app/lib/features/chat/pages/chat_room_page.dart`
- Create: `mobile/member_app/lib/features/notifications/pages/notifications_page.dart`
- Create: `mobile/member_app/lib/features/profile/pages/profile_page.dart`

- [ ] **Step 1: Create pubspec.yaml**

```yaml
# mobile/member_app/pubspec.yaml
name: member_app
version: 1.0.0
publish_to: none

environment:
  sdk: ^3.12.0

dependencies:
  flutter:
    sdk: flutter
  shared:
    path: ../shared
  go_router: ^14.8.0
  flutter_riverpod: ^2.6.1
  fl_chart: ^0.70.0
  intl: ^0.20.2
  image_picker: ^1.1.2

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
```

- [ ] **Step 2: Create main.dart**

```dart
// mobile/member_app/lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/supabase_client.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseClientService().initialize(
    supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  runApp(const ProviderScope(child: MemberApp()));
}
```

- [ ] **Step 3: Create app.dart**

```dart
// mobile/member_app/lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';

class MemberApp extends ConsumerWidget {
  const MemberApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Member App',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      routerConfig: router,
    );
  }
}
```

- [ ] **Step 4: Create router.dart (same pattern as trainer app — shell with bottom nav)**

```dart
// mobile/member_app/lib/app/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/providers/auth_provider.dart';
import '../features/auth/pages/login_page.dart';
import '../features/dashboard/pages/dashboard_page.dart';
import '../features/workouts/pages/workout_list_page.dart';
import '../features/workouts/pages/log_workout_page.dart';
import '../features/measurements/pages/measurement_page.dart';
import '../features/goals/pages/goals_page.dart';
import '../features/goals/pages/create_goal_page.dart';
import '../features/meals/pages/meal_list_page.dart';
import '../features/meals/pages/log_meal_page.dart';
import '../features/meals/pages/recommendations_page.dart';
import '../features/feedback/pages/feedback_page.dart';
import '../features/chat/pages/chat_list_page.dart';
import '../features/chat/pages/chat_room_page.dart';
import '../features/notifications/pages/notifications_page.dart';
import '../features/profile/pages/profile_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  redirect: (context, state) {
    final authState = ProviderScope.containerOf(context).read(authProvider);
    final isLoggedIn = authState.valueOrNull != null;
    final isLoginRoute = state.matchedLocation == '/login';
    if (!isLoggedIn && !isLoginRoute) return '/login';
    if (isLoggedIn && isLoginRoute) return '/dashboard';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (_, __, child) => MemberShell(child: child),
      routes: [
        GoRoute(path: '/dashboard', builder: (_, __) => const DashboardPage()),
        GoRoute(path: '/workouts', builder: (_, __) => const WorkoutListPage()),
        GoRoute(path: '/workouts/log', builder: (_, __) => const LogWorkoutPage()),
        GoRoute(path: '/measurements', builder: (_, __) => const MeasurementPage()),
        GoRoute(path: '/goals', builder: (_, __) => const GoalsPage()),
        GoRoute(path: '/goals/create', builder: (_, __) => const CreateGoalPage()),
        GoRoute(path: '/meals', builder: (_, __) => const MealListPage()),
        GoRoute(path: '/meals/log', builder: (_, __) => const LogMealPage()),
        GoRoute(path: '/meals/recommendations', builder: (_, __) => const RecommendationsPage()),
        GoRoute(path: '/feedback', builder: (_, __) => const FeedbackPage()),
        GoRoute(path: '/chat', builder: (_, __) => const ChatListPage()),
        GoRoute(path: '/chat/:roomId', builder: (_, state) => ChatRoomPage(roomId: state.pathParameters['roomId']!)),
        GoRoute(path: '/notifications', builder: (_, __) => const NotificationsPage()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      ],
    ),
  ],
);

class MemberShell extends StatelessWidget {
  final Widget child;
  const MemberShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(context),
        onDestinationSelected: (i) => _onTap(context, i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Workouts'),
          NavigationDestination(icon: Icon(Icons.trending_up), label: 'Progress'),
          NavigationDestination(icon: Icon(Icons.chat), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/workouts')) return 1;
    if (location.startsWith('/measurements') || location.startsWith('/goals') || location.startsWith('/meals')) return 2;
    if (location.startsWith('/chat')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/dashboard');
      case 1: context.go('/workouts');
      case 2: context.go('/measurements');
      case 3: context.go('/chat');
      case 4: context.go('/profile');
    }
  }
}
```

- [ ] **Step 5: Create LoginPage (same as trainer app)**

```dart
// mobile/member_app/lib/features/auth/pages/login_page.dart
// Same content as trainer app's login page (just change title to "Member Login")
```

- [ ] **Step 6: Create all placeholder pages (same pattern as trainer app)**

Create each page file with a simple `Center(child: Text('Page Name'))` placeholder.

- [ ] **Step 7: Verify**

Run: `cd mobile/member_app && flutter pub get`
Expected: Packages resolve.

---

### Task 7: Member Dashboard + Workout Logging

**Files:**
- Modify: `mobile/member_app/lib/features/dashboard/pages/dashboard_page.dart`
- Modify: `mobile/member_app/lib/features/workouts/pages/workout_list_page.dart`
- Modify: `mobile/member_app/lib/features/workouts/pages/log_workout_page.dart`

- [ ] **Step 1: Implement DashboardPage with stats + AI tip**

```dart
// mobile/member_app/lib/features/dashboard/pages/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/workout_service.dart';
import 'package:shared/services/measurement_service.dart';
import 'package:shared/services/goal_service.dart';
import 'package:shared/services/supabase_client.dart';

final memberDashboardProvider = FutureProvider((ref) async {
  final client = SupabaseClientService().client;
  final userId = client.auth.currentUser!.id;
  final workouts = await WorkoutService().getWorkouts(userId);
  final measurements = await MeasurementService().getMeasurements(userId);
  final goals = await GoalService().getGoals(userId);
  return {
    'workoutCount': workouts.length,
    'latestWeight': measurements.isNotEmpty ? measurements.last.weightKg : null,
    'goalCount': goals.length,
    'completedGoals': goals.where((g) => g.status == 'completed').length,
  };
});

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(memberDashboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Progress')),
      body: dataAsync.when(
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              _StatCard('Workouts', '${data['workoutCount']}', Icons.fitness_center, Colors.blue),
              const SizedBox(width: 8),
              _StatCard('Weight', data['latestWeight'] != null ? '${data['latestWeight']}kg' : '—', Icons.monitor_weight, Colors.green),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _StatCard('Goals', '${data['goalCount']}', Icons.flag, Colors.orange),
              const SizedBox(width: 8),
              _StatCard('Completed', '${data['completedGoals']}', Icons.check_circle, Colors.purple),
            ]),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.lightbulb, color: Colors.amber),
                title: const Text('AI Tip'),
                subtitle: const Text('Try increasing your protein intake to support muscle growth.'),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Implement WorkoutListPage**

```dart
// mobile/member_app/lib/features/workouts/pages/workout_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/models/workout_log.dart';
import 'package:shared/services/workout_service.dart';
import 'package:shared/services/supabase_client.dart';

final workoutsProvider = FutureProvider<List<WorkoutLog>>((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser!.id;
  return WorkoutService().getWorkouts(userId);
});

class WorkoutListPage extends ConsumerWidget {
  const WorkoutListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(workoutsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/workouts/log'),
        child: const Icon(Icons.add),
      ),
      body: workoutsAsync.when(
        data: (workouts) => ListView.builder(
          itemCount: workouts.length,
          itemBuilder: (_, i) => ListTile(
            title: Text(workouts[i].exerciseName),
            subtitle: Text('${workouts[i].sets} sets x ${workouts[i].reps} reps'),
            trailing: Text(workouts[i].weight != null ? '${workouts[i].weight}kg' : ''),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
```

- [ ] **Step 3: Implement LogWorkoutPage**

```dart
// mobile/member_app/lib/features/workouts/pages/log_workout_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/models/workout_log.dart';
import 'package:shared/services/workout_service.dart';
import 'package:shared/services/supabase_client.dart';

class LogWorkoutPage extends ConsumerStatefulWidget {
  const LogWorkoutPage({super.key});

  @override
  ConsumerState<LogWorkoutPage> createState() => _LogWorkoutPageState();
}

class _LogWorkoutPageState extends ConsumerState<LogWorkoutPage> {
  final _exerciseController = TextEditingController();
  final _setsController = TextEditingController();
  final _repsController = TextEditingController();
  final _weightController = TextEditingController();
  final _durationController = TextEditingController();

  @override
  void dispose() {
    _exerciseController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final userId = SupabaseClientService().client.auth.currentUser!.id;
    await WorkoutService().createWorkout(WorkoutLog(
      id: '',
      memberId: userId,
      exerciseName: _exerciseController.text,
      sets: int.tryParse(_setsController.text),
      reps: int.tryParse(_repsController.text),
      weight: double.tryParse(_weightController.text),
      durationMinutes: int.tryParse(_durationController.text),
      loggedAt: DateTime.now(),
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Workout')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: _exerciseController, decoration: const InputDecoration(labelText: 'Exercise Name')),
          TextField(controller: _setsController, decoration: const InputDecoration(labelText: 'Sets'), keyboardType: TextInputType.number),
          TextField(controller: _repsController, decoration: const InputDecoration(labelText: 'Reps'), keyboardType: TextInputType.number),
          TextField(controller: _weightController, decoration: const InputDecoration(labelText: 'Weight (kg)'), keyboardType: TextInputType.number),
          TextField(controller: _durationController, decoration: const InputDecoration(labelText: 'Duration (min)'), keyboardType: TextInputType.number),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save Workout')),
        ]),
      ),
    );
  }
}
```

---

### Task 8: Member Measurements + Goals

**Files:**
- Modify: `mobile/member_app/lib/features/measurements/pages/measurement_page.dart`
- Modify: `mobile/member_app/lib/features/goals/pages/goals_page.dart`
- Modify: `mobile/member_app/lib/features/goals/pages/create_goal_page.dart`

- [ ] **Step 1: Implement MeasurementPage with fl_chart**

```dart
// mobile/member_app/lib/features/measurements/pages/measurement_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared/models/body_measurement.dart';
import 'package:shared/services/measurement_service.dart';
import 'package:shared/services/supabase_client.dart';

final measurementsProvider = FutureProvider<List<BodyMeasurement>>((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser!.id;
  return MeasurementService().getMeasurements(userId);
});

class MeasurementPage extends ConsumerWidget {
  const MeasurementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measurementsAsync = ref.watch(measurementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Body Measurements')),
      body: measurementsAsync.when(
        data: (measurements) {
          final weightPoints = measurements.where((m) => m.weightKg != null).map((m) => FlSpot(
            m.measuredAt.millisecondsSinceEpoch.toDouble(),
            m.weightKg!,
          )).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (weightPoints.length >= 2)
                SizedBox(
                  height: 200,
                  child: LineChart(LineChartData(
                    lineBarsData: [LineChartBarData(spots: weightPoints, isCurved: true)],
                    titlesData: const FlTitlesData(show: false),
                    gridData: const FlGridData(show: true),
                  )),
                ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    const Text('Log New Measurement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _addMeasurementButton(context),
                  ]),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _addMeasurementButton(BuildContext context) {
    return FilledButton(onPressed: () => _showAddDialog(context), child: const Text('Add Measurement'));
  }

  void _showAddDialog(BuildContext context) {
    final weightCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Measurement'),
        content: TextField(controller: weightCtrl, decoration: const InputDecoration(labelText: 'Weight (kg)'), keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            final userId = SupabaseClientService().client.auth.currentUser!.id;
            await MeasurementService().createMeasurement(BodyMeasurement(
              id: '',
              memberId: userId,
              weightKg: double.tryParse(weightCtrl.text),
              measuredAt: DateTime.now(),
            ));
            if (ctx.mounted) Navigator.pop(ctx);
          }, child: const Text('Save')),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Implement GoalsPage**

```dart
// mobile/member_app/lib/features/goals/pages/goals_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/models/goal.dart';
import 'package:shared/services/goal_service.dart';
import 'package:shared/services/supabase_client.dart';

final goalsProvider = FutureProvider<List<Goal>>((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser!.id;
  return GoalService().getGoals(userId);
});

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Goals')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/goals/create'),
        child: const Icon(Icons.add),
      ),
      body: goalsAsync.when(
        data: (goals) => ListView.builder(
          itemCount: goals.length,
          itemBuilder: (_, i) {
            final goal = goals[i];
            final progress = goal.targetValue != null && goal.targetValue! > 0
                ? (goal.currentValue ?? 0) / goal.targetValue!
                : 0.0;
            return Card(
              child: ListTile(
                title: Text(goal.title),
                subtitle: LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
                trailing: Text('${(progress * 100).toStringAsFixed(0)}%'),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
```

- [ ] **Step 3: Implement CreateGoalPage**

```dart
// mobile/member_app/lib/features/goals/pages/create_goal_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/models/goal.dart';
import 'package:shared/services/goal_service.dart';
import 'package:shared/services/supabase_client.dart';

class CreateGoalPage extends ConsumerStatefulWidget {
  const CreateGoalPage({super.key});

  @override
  ConsumerState<CreateGoalPage> createState() => _CreateGoalPageState();
}

class _CreateGoalPageState extends ConsumerState<CreateGoalPage> {
  final _titleCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _targetCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final userId = SupabaseClientService().client.auth.currentUser!.id;
    await GoalService().createGoal(Goal(
      id: '',
      memberId: userId,
      title: _titleCtrl.text,
      targetValue: double.tryParse(_targetCtrl.text),
      unit: _unitCtrl.text,
      status: 'in_progress',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Goal')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Goal Title')),
          TextField(controller: _targetCtrl, decoration: const InputDecoration(labelText: 'Target Value'), keyboardType: TextInputType.number),
          TextField(controller: _unitCtrl, decoration: const InputDecoration(labelText: 'Unit (kg, reps, min, etc.)')),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Create Goal')),
        ]),
      ),
    );
  }
}
```

---

### Task 9: Member Meals + Feedback + Notifications

**Files:**
- Modify: `mobile/member_app/lib/features/meals/pages/meal_list_page.dart`
- Modify: `mobile/member_app/lib/features/meals/pages/log_meal_page.dart`
- Modify: `mobile/member_app/lib/features/meals/pages/recommendations_page.dart`
- Modify: `mobile/member_app/lib/features/feedback/pages/feedback_page.dart`
- Modify: `mobile/member_app/lib/features/notifications/pages/notifications_page.dart`
- Modify: `mobile/member_app/lib/features/chat/pages/chat_list_page.dart`
- Modify: `mobile/member_app/lib/features/chat/pages/chat_room_page.dart`
- Modify: `mobile/member_app/lib/features/profile/pages/profile_page.dart`

- [ ] **Step 1: Implement MealListPage**

```dart
// mobile/member_app/lib/features/meals/pages/meal_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/models/meal_record.dart';
import 'package:shared/services/meal_service.dart';
import 'package:shared/services/supabase_client.dart';

final mealsProvider = FutureProvider<List<MealRecord>>((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser!.id;
  return MealService().getMeals(userId, date: DateTime.now());
});

class MealListPage extends ConsumerWidget {
  const MealListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(mealsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Today\'s Meals')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/meals/log'),
        child: const Icon(Icons.add),
      ),
      body: mealsAsync.when(
        data: (meals) {
          final totalCals = meals.fold(0, (sum, m) => sum + (m.calories ?? 0));
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Total Calories: $totalCals', style: Theme.of(context).textTheme.titleLarge),
              ),
              ...meals.map((m) => ListTile(
                title: Text(m.mealType),
                subtitle: Text(m.foodItems),
                trailing: Text('${m.calories ?? 0} cal'),
              )),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
```

- [ ] **Step 2: Implement LogMealPage**

```dart
// mobile/member_app/lib/features/meals/pages/log_meal_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/models/meal_record.dart';
import 'package:shared/services/meal_service.dart';
import 'package:shared/services/supabase_client.dart';

class LogMealPage extends ConsumerStatefulWidget {
  const LogMealPage({super.key});

  @override
  ConsumerState<LogMealPage> createState() => _LogMealPageState();
}

class _LogMealPageState extends ConsumerState<LogMealPage> {
  final _foodCtrl = TextEditingController();
  final _calCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  String _mealType = 'breakfast';

  @override
  void dispose() {
    _foodCtrl.dispose();
    _calCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final userId = SupabaseClientService().client.auth.currentUser!.id;
    await MealService().createMeal(MealRecord(
      id: '',
      memberId: userId,
      mealType: _mealType,
      foodItems: _foodCtrl.text,
      calories: int.tryParse(_calCtrl.text),
      proteinG: double.tryParse(_proteinCtrl.text),
      carbsG: double.tryParse(_carbsCtrl.text),
      fatG: double.tryParse(_fatCtrl.text),
      recordedAt: DateTime.now(),
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Meal')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(children: [
          DropdownButtonFormField(
            value: _mealType,
            items: ['breakfast', 'lunch', 'dinner', 'snack'].map((t) => DropdownMenuItem(value: t, child: Text(t.capitalize()))).toList(),
            onChanged: (v) => setState(() => _mealType = v!),
            decoration: const InputDecoration(labelText: 'Meal Type'),
          ),
          TextField(controller: _foodCtrl, decoration: const InputDecoration(labelText: 'Food Items')),
          TextField(controller: _calCtrl, decoration: const InputDecoration(labelText: 'Calories'), keyboardType: TextInputType.number),
          TextField(controller: _proteinCtrl, decoration: const InputDecoration(labelText: 'Protein (g)'), keyboardType: TextInputType.number),
          TextField(controller: _carbsCtrl, decoration: const InputDecoration(labelText: 'Carbs (g)'), keyboardType: TextInputType.number),
          TextField(controller: _fatCtrl, decoration: const InputDecoration(labelText: 'Fat (g)'), keyboardType: TextInputType.number),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save Meal')),
        ]),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() => '${this[0].toUpperCase()}${substring(1)}';
}
```

- [ ] **Step 3: Implement RecommendationsPage (placeholder for AI)**

```dart
// mobile/member_app/lib/features/meals/pages/recommendations_page.dart
import 'package:flutter/material.dart';

class RecommendationsPage extends StatelessWidget {
  const RecommendationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Recommendations')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          Card(child: ListTile(title: Text('Grilled Chicken Salad'), subtitle: Text('High protein, low carb — great for fat loss'))),
          Card(child: ListTile(title: Text('Greek Yogurt with Berries'), subtitle: Text('Post-workout recovery meal'))),
          Card(child: ListTile(title: Text('Oatmeal with Banana'), subtitle: Text('Pre-workout energy boost'))),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 4: Implement FeedbackPage**

```dart
// mobile/member_app/lib/features/feedback/pages/feedback_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/models/trainer_feedback.dart';
import 'package:shared/services/feedback_service.dart';
import 'package:shared/services/supabase_client.dart';

final feedbackProvider = FutureProvider<List<TrainerFeedback>>((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser!.id;
  return FeedbackService().getFeedbackForMember(userId);
});

class FeedbackPage extends ConsumerWidget {
  const FeedbackPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedbackAsync = ref.watch(feedbackProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trainer Feedback')),
      body: feedbackAsync.when(
        data: (feedback) => ListView.builder(
          itemCount: feedback.length,
          itemBuilder: (_, i) => Card(
            child: ListTile(
              title: Text(feedback[i].content),
              subtitle: Text(feedback[i].createdAt.toIso8601String()),
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
```

- [ ] **Step 5: Implement NotificationsPage**

```dart
// mobile/member_app/lib/features/notifications/pages/notifications_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/models/notification_model.dart';
import 'package:shared/services/supabase_client.dart';

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  final client = SupabaseClientService().client;
  final userId = client.auth.currentUser!.id;
  final response = await client.from('notifications').select().eq('user_id', userId).order('created_at', ascending: false);
  return (response as List).map((e) => AppNotification.fromJson(e)).toList();
});

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notifsAsync.when(
        data: (notifs) => ListView.builder(
          itemCount: notifs.length,
          itemBuilder: (_, i) => ListTile(
            leading: Icon(notifs[i].read ? Icons.notifications_none : Icons.notifications_active, color: notifs[i].read ? Colors.grey : Colors.blue),
            title: Text(notifs[i].title),
            subtitle: Text(notifs[i].body ?? ''),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
```

- [ ] **Step 6: Implement Chat pages for member app (same pattern as trainer app)**

Copy the chat list and chat room pages from the trainer app into the member app.

- [ ] **Step 7: Implement ProfilePage for member app**

```dart
// mobile/member_app/lib/features/profile/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/providers/auth_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: authState.when(
        data: (profile) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            CircleAvatar(child: Text(profile?.fullName[0] ?? '?'), radius: 40),
            const SizedBox(height: 16),
            Text(profile?.fullName ?? '', style: Theme.of(context).textTheme.titleLarge),
            Text(profile?.email ?? ''),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: () => ref.read(authProvider.notifier).signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
            ),
          ]),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
```

---

### Final Step: Verify Build

- [ ] **Step 1: Build trainer app**

Run: `cd mobile/trainer_app && flutter build apk --debug`
Expected: Build succeeds.

- [ ] **Step 2: Build member app**

Run: `cd mobile/member_app && flutter build apk --debug`
Expected: Build succeeds.

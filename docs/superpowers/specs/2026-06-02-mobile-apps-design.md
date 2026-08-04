# Mobile Apps — Design Spec

## Overview

Two Flutter mobile apps (Trainer + Member) sharing a common Dart package for models, services, and providers.

## Architecture

```
mobile/
├── shared/                    # Pure Dart package (no Flutter dependency)
│   ├── lib/
│   │   ├── models/            # Profile, WorkoutLog, BodyMeasurement, etc.
│   │   ├── services/          # Supabase client, Auth, Chat, Workout services
│   │   ├── providers/         # Riverpod providers
│   │   └── utils/
│   └── pubspec.yaml
├── trainer_app/               # Flutter app for trainers
│   ├── lib/
│   │   ├── app/               # GoRouter, theme, app config
│   │   ├── features/          # Per-feature folders
│   │   └── main.dart
│   └── pubspec.yaml
└── member_app/                # Flutter app for members
    ├── lib/
    │   ├── app/
    │   ├── features/
    │   └── main.dart
    └── pubspec.yaml
```

## Tech Stack

- Flutter 3.44+
- Riverpod (state management)
- GoRouter (routing)
- fl_chart (charts)
- supabase_flutter (auth + realtime + data)
- intl (date formatting)
- image_picker (avatar uploads)

## Shared Package

### Models
Profile, WorkoutLog, BodyMeasurement, Goal, TrainerFeedback, MealRecord, ChatRoom, ChatMessage, Membership, Notification, TrainerAssignment

### Services
SupabaseClient, AuthService, ProfileService, WorkoutService, MeasurementService, GoalService, ChatService, MealService

### Providers (Riverpod)
authProvider, currentUserProvider, chatProvider

## Trainer App

### Routes
/login, /dashboard, /members, /members/:id, /members/:id/workouts, /members/:id/progress, /members/:id/feedback, /members/:id/goals, /chat, /chat/:roomId

### Bottom Nav: Dashboard | Members | Chat | Profile

### Key Features
- Dashboard with stats cards
- Assigned members list with search
- Member profile view (read-only)
- Workout review with feedback
- Progress charts (weight trends)
- Feedback submission form
- Goal adjustment suggestions
- Real-time chat with members

## Member App

### Routes
/login, /dashboard, /workouts, /workouts/history, /measurements, /measurements/history, /goals, /goals/:id, /meals, /meals/recommendations, /feedback, /chat, /chat/:roomId, /notifications

### Bottom Nav: Dashboard | Workouts | Progress | Chat | Profile

### Key Features
- Dashboard with streak, goal rings, AI tips
- Workout logging form + history
- Body measurements input + trend charts
- Goal creation + progress tracking
- Meal logging with macro breakdown
- AI food recommendations
- Trainer feedback history
- Real-time chat with trainer
- Notification list

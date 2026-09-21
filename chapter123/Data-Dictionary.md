# 3.9 Data Dictionary (Analysis)

The following tables document the field-level structure of each database table in the Intelligent Fitness Progress Monitoring Application, listing field name, description, PostgreSQL field type, field size, and key type.

## Table 3: Enrollments

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| id | Primary key uniquely identifying each row in the Enrollments table. | uuid | -- | PK |
| full_name | Full name of the enrolling prospect or member. | text | -- |  |
| email | Email address used for communication and account identification. | text | -- |  |
| phone | Phone number for SMS or voice contact. | text | -- |  |
| date_of_birth | Date of birth used for age-appropriate program recommendations. | date | -- |  |
| gender | Text indicating the enrollee's gender. | text | -- |  |
| address | Text field capturing the enrollee's home address. | text | -- |  |
| emergency_contact_name | Name of the designated emergency contact person. | text | -- |  |
| emergency_contact_phone | Phone number of the designated emergency contact. | text | -- |  |
| emergency_contact_relation | Text describing the relationship to the emergency contact. | text | -- |  |
| status | Text indicating the enrollment's current processing status. | text | -- |  |
| confirmed_at | Timestamp when the enrollment was confirmed. | timestamptz | -- |  |
| confirmed_by | Foreign key referencing the profile of the user who confirmed the enrollment in the Enrollments table. | uuid | -- | FK |
| created_at | Timestamp recording when the record was created in the Enrollments table. | timestamptz | -- |  |
| state_updated_at | Timestamp with time zone stored in the Enrollments table. | timestamptz | -- |  |

The Enrollments table captures prospect and member registration details, including contact information, demographics, and membership confirmation tracking.

## Table 4: Profiles

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| id | Primary key uniquely identifying each row in the Profiles table. | uuid | -- | PK |
| role | Enumeration value (admin, trainer, or member) defining the profile's access role. | user_role | -- |  |
| full_name | Text field stored in the Profiles table. | text | -- |  |
| email | Text field stored in the Profiles table. | text | -- |  |
| phone | Text field stored in the Profiles table. | text | -- |  |
| avatar_url | URL pointing to the profile's avatar image. | text | -- |  |
| date_of_birth | Date value stored in the Profiles table. | date | -- |  |
| gender | Text field stored in the Profiles table. | text | -- |  |
| created_at | Timestamp recording when the record was created in the Profiles table. | timestamptz | -- |  |
| updated_at | Timestamp recording the last update to the record in the Profiles table. | timestamptz | -- |  |
| fitness_goal | Text describing the member's overall fitness goal or focus area. | text | -- |  |
| code | Text identifier or referral code associated with the profile. | text | -- |  |
| emergency_contact_name | Text field stored in the Profiles table. | text | -- |  |
| emergency_contact_phone | Text field stored in the Profiles table. | text | -- |  |
| specialty | Text describing the trainer's area of specialization. | text | -- |  |
| available_days | Text listing the days the trainer is available for sessions. | text | -- |  |
| is_active | Boolean flag indicating whether the profile is currently active. | boolean | -- |  |

The Profiles table stores authenticated user accounts for members, trainers, and administrators, recording role assignment, profile attributes, and account status.

## Table 5: Memberships

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| id | Primary key uniquely identifying each row in the Memberships table. | uuid | -- | PK |
| member_id | Foreign key referencing the member's profile. | uuid | -- | FK |
| plan_name | Text name of the membership plan purchased. | text | -- |  |
| price | Decimal price of the membership plan. | decimal | 10,2 |  |
| start_date | Date the membership period began. | date | -- |  |
| end_date | Date the membership period ends. | date | -- |  |
| status | Enumeration value (active, expired, or cancelled) indicating membership state. | membership_status | -- |  |
| created_at | Timestamp recording when the record was created in the Memberships table. | timestamptz | -- |  |
| updated_at | Timestamp recording the last update to the record in the Memberships table. | timestamptz | -- |  |

The Memberships table tracks each member's active or historical membership plans, including pricing, billing period, and current membership status.

## Table 6: Trainer Assignments

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| id | Primary key uniquely identifying each row in the Trainer Assignments table. | uuid | -- | PK |
| trainer_id | Foreign key referencing the assigned trainer's profile. | uuid | -- | FK |
| member_id | Foreign key referencing the assigned member's profile. | uuid | -- | FK |
| assigned_at | Timestamp when the trainer-member assignment was created. | timestamptz | -- |  |
| status | Enumeration value (active or ended) indicating assignment state. | assignment_status | -- |  |

The Trainer Assignments table records the association between a trainer and a member, including the assignment date and current assignment status.

## Table 7: Attendance

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| id | Primary key uniquely identifying each row in the Attendance table. | uuid | -- | PK |
| member_id | Foreign key referencing the member's profile in the Attendance table. | uuid | -- | FK |
| check_in_time | Timestamp when the member checked in for the session. | timestamptz | -- |  |
| check_in_date | Date of the attended session. | date | -- |  |
| check_out_time | Timestamp when the member checked out of the session. | timestamptz | -- |  |
| expires_at | Timestamp after which the attendance record is considered stale. | timestamptz | -- |  |

The Attendance table logs each member's gym visit sessions by recording check-in and check-out times, the visit date, and session expiry.

## Table 8: Check-Ins

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| id | Primary key uniquely identifying each row in the Check-Ins table. | uuid | -- | PK |
| member_id | Foreign key referencing the member's profile in the Check-Ins table. | uuid | -- | FK |
| check_in_time | Timestamp recording when the member entered the gym. | timestamptz | -- |  |

The Check-Ins table records the timestamp of each member's gym entry event for quick presence tracking.

## Table 9: Addresses

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| member_id | Primary key and foreign key referencing the member's profile; each member has one address row. | uuid | -- | PK |
| line1 | First line of the street address. | text | -- |  |
| line2 | Optional second line of the street address. | text | -- |  |
| city | City name of the address. | text | -- |  |
| state | State or province of the address. | text | -- |  |
| postal_code | Postal or ZIP code of the address. | text | -- |  |
| country | Country of the address. | text | -- |  |
| created_at | Timestamp recording when the record was created in the Addresses table. | timestamptz | -- |  |
| updated_at | Timestamp recording the last update to the record in the Addresses table. | timestamptz | -- |  |

The Addresses table stores the physical mailing address associated with each member, keyed directly to the member's profile.

## Table 10: Workout Logs

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| id | Primary key uniquely identifying each row in the Workout Logs table. | uuid | -- | PK |
| member_id | Foreign key referencing the member who performed the exercise. | uuid | -- | FK |
| exercise_name | Text name of the exercise performed. | text | -- |  |
| sets | Integer value stored in the Workout Logs table. | int | -- |  |
| reps | Integer count of repetitions performed. | int | -- |  |
| weight | Decimal weight value in the legacy field (superseded by weight_kg). | decimal | 10,2 |  |
| duration_minutes | Decimal duration in minutes in the legacy field (superseded by duration_seconds). | int | -- |  |
| notes | Text notes about the exercise set. | text | -- |  |
| logged_at | Timestamp when the workout log entry was recorded. | timestamptz | -- |  |
| proof_url | Text field stored in the Workout Logs table. | text | -- |  |
| proof_type | Text field stored in the Workout Logs table. | text | -- |  |
| weight_kg | Decimal weight in kilograms used for the set. | decimal | 10,2 |  |
| duration_seconds | Decimal duration in seconds for the exercise set. | int | -- |  |
| workout_name | Text field stored in the Workout Logs table. | text | -- |  |
| total_calories | Integer value stored in the Workout Logs table. | integer | -- |  |

The Workout Logs table records individual exercise sessions performed by a member, capturing exercise type, sets, repetitions, and load in both metric and legacy fields.

## Table 11: Body Measurements

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| id | Primary key uniquely identifying each row in the Body Measurements table. | uuid | -- | PK |
| member_id | Foreign key referencing the member whose measurements were taken. | uuid | -- | FK |
| weight_kg | Decimal body weight in kilograms. | decimal | 5,2 |  |
| height_cm | Decimal standing height in centimeters. | decimal | 5,2 |  |
| body_fat_pct | Decimal body fat percentage. | decimal | 4,1 |  |
| chest_cm | Decimal chest circumference in centimeters. | decimal | 5,2 |  |
| waist_cm | Decimal waist circumference in centimeters. | decimal | 5,2 |  |
| hips_cm | Decimal hip circumference in centimeters. | decimal | 5,2 |  |
| arm_cm | Decimal arm circumference in centimeters. | decimal | 5,2 |  |
| thigh_cm | Decimal thigh circumference in centimeters. | decimal | 5,2 |  |
| measured_at | Timestamp when the measurements were recorded. | timestamptz | -- |  |

The Body Measurements table stores periodic anthropometric readings for a member, including weight, height, body fat percentage, and circumferences.

## Table 12: Goals

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| id | Primary key uniquely identifying each row in the Goals table. | uuid | -- | PK |
| member_id | Foreign key referencing the member who owns the goal. | uuid | -- | FK |
| title | Short text title of the fitness goal. | text | -- |  |
| description | Text describing the goal in detail. | text | -- |  |
| target_value | Decimal target value the member aims to reach. | decimal | 10,2 |  |
| current_value | Decimal current progress value toward the target. | decimal | 10,2 |  |
| unit | Text unit of measure for the target and current values. | text | -- |  |
| deadline | Date by which the goal is targeted to be achieved. | date | -- |  |
| status | Text indicating the goal's current state (for example, active or achieved). | text | -- |  |
| created_at | Timestamp recording when the record was created in the Goals table. | timestamptz | -- |  |
| updated_at | Timestamp recording the last update to the record in the Goals table. | timestamptz | -- |  |

The Goals table defines a member's fitness objectives with a target value, current progress, unit of measure, deadline, and status.

## Table 13: Member Goal Plans

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| id | Primary key uniquely identifying each row in the Member Goal Plans table. | uuid | -- | PK |
| member_id | Foreign key referencing the member assigned to the plan. | uuid | -- | FK |
| trainer_id | Foreign key referencing the trainer who created the plan. | uuid | -- | FK |
| start_date | Date the goal plan period begins. | date | -- |  |
| end_date | Date the goal plan period ends. | date | -- |  |
| timeframe | Text describing the plan's timeframe category. | text | -- |  |
| notes | Text notes from the trainer about the plan. | text | -- |  |
| food_plan | JSON object containing the prescribed food plan. | jsonb | -- |  |
| exercise_plan | JSON object containing the prescribed exercise plan. | jsonb | -- |  |
| created_at | Timestamp recording when the record was created in the Member Goal Plans table. | timestamptz | -- |  |
| updated_at | Timestamp recording the last update to the record in the Member Goal Plans table. | timestamptz | -- |  |

The Member Goal Plans table links a member and trainer to a structured plan window, storing timeframe, notes, and JSON-formatted food and exercise plans.

## Table 14: Plan Day Completions

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| id | Primary key uniquely identifying each row in the Plan Day Completions table. | uuid | -- | PK |
| plan_id | Foreign key referencing the member goal plan being completed. | uuid | -- | FK |
| member_id | Foreign key referencing the member completing the day. | uuid | -- | FK |
| day_number | Integer day number within the goal plan. | int | -- |  |
| date | Date the completion entry corresponds to. | date | -- |  |
| completed_exercises | JSON object listing the exercises completed that day. | jsonb | -- |  |
| completed_foods | JSON object listing the foods completed that day. | jsonb | -- |  |
| is_complete | Boolean indicating whether the day's plan was fully completed. | boolean | -- |  |
| notified_member | Boolean indicating whether the member was notified. | boolean | -- |  |
| notified_trainer | Boolean indicating whether the trainer was notified. | boolean | -- |  |
| created_at | Timestamp recording when the record was created in the Plan Day Completions table. | timestamptz | -- |  |
| updated_at | Timestamp recording the last update to the record in the Plan Day Completions table. | timestamptz | -- |  |

The Plan Day Completions table records a member's daily progress against a goal plan, including completed exercises, completed foods, and notification state.

## Table 15: Trainer Feedback

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| id | Primary key uniquely identifying each row in the Trainer Feedback table. | uuid | -- | PK |
| trainer_id | Foreign key referencing the trainer who authored the feedback. | uuid | -- | FK |
| member_id | Foreign key referencing the member receiving the feedback. | uuid | -- | FK |
| content | Text body of the trainer's feedback to the member. | text | -- |  |
| created_at | Timestamp recording when the record was created in the Trainer Feedback table. | timestamptz | -- |  |

The Trainer Feedback table stores written feedback entries submitted by a trainer to a member.

## Table 16: Meal Records

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| id | Primary key uniquely identifying each row in the Meal Records table. | uuid | -- | PK |
| member_id | Foreign key referencing the member who logged the meal. | uuid | -- | FK |
| meal_type | Text categorizing the meal (for example, breakfast or lunch). | text | -- |  |
| food_items | Text listing the food items in the meal. | text | -- |  |
| calories | Integer total calorie count for the meal. | int | -- |  |
| protein_g | Decimal protein amount in grams. | decimal | 6,2 |  |
| carbs_g | Decimal carbohydrate amount in grams. | decimal | 6,2 |  |
| fat_g | Decimal fat amount in grams. | decimal | 6,2 |  |
| recorded_at | Timestamp when the meal record was logged. | timestamptz | -- |  |

The Meal Records table logs a member's self-reported meals with aggregated macronutrient totals and calorie count.

## Table 17: Meal Logs

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| id | Primary key uniquely identifying each row in the Meal Logs table. | uuid | -- | PK |
| member_id | Foreign key referencing the member who logged the meal. | uuid | -- | FK |
| meal_type | Text categorizing the meal (for example, breakfast or lunch). | text | -- |  |
| food_name | Text name of the recognized food item. | text | -- |  |
| calories | Integer calorie count for the food item. | int | -- |  |
| protein_g | Decimal protein amount in grams. | decimal | 6,2 |  |
| carbs_g | Decimal carbohydrate amount in grams. | decimal | 6,2 |  |
| fat_g | Decimal fat amount in grams. | decimal | 6,2 |  |
| photo_url | URL of the photo used to recognize the meal. | text | -- |  |
| meal_time | Timestamp when the meal was consumed. | timestamptz | -- |  |

The Meal Logs table logs an individual recognized meal entry with food name, macronutrients, optional photo, and meal timestamp.

## Table 18: Food Recommendations

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| id | Primary key uniquely identifying each row in the Food Recommendations table. | uuid | -- | PK |
| member_id | Foreign key referencing the member receiving the recommendation. | uuid | -- | FK |
| meal_type | Text categorizing the recommended meal type. | text | -- |  |
| food_name | Text name of the recommended food. | text | -- |  |
| portion_size | Text describing the recommended portion size. | text | -- |  |
| reason | Text explaining why the food was recommended. | text | -- |  |
| created_at | Timestamp recording when the record was created in the Food Recommendations table. | timestamptz | -- |  |

The Food Recommendations table stores AI-generated food suggestions delivered to a member, including meal type, portion, and reasoning.

## Table 19: Food Identification Logs

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| id | Primary key uniquely identifying each row in the Food Identification Logs table. | uuid | -- | PK |
| member_id | Foreign key referencing the member who submitted the photo. | uuid | -- | FK |
| photo_url | URL of the uploaded food photo. | text | -- |  |
| ai_candidates | JSON array of AI-generated food candidate objects. | jsonb | -- |  |
| selected_food | Text name of the food ultimately selected. | text | -- |  |
| member_edited | Boolean indicating whether the member edited the AI suggestion. | boolean | -- |  |
| created_at | Timestamp recording when the record was created in the Food Identification Logs table. | timestamptz | -- |  |

The Food Identification Logs table records each AI food-recognition attempt from a member's photo, including candidate list, selected food, and whether the member edited the result.

## Table 20: Nutrition Foods

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| id | Primary key uniquely identifying each row in the Nutrition Foods table. | uuid | -- | PK |
| food_name | Text name of the food in the reference catalog. | text | -- |  |
| aliases | Array of text synonyms or alternate names for the food. | text[] | -- |  |
| category | Text category classifying the food (for example, protein or grain). | text | -- |  |
| serving_label | Text label describing the standard serving (for example, 1 cup). | text | -- |  |
| serving_size_g | Numeric serving size in grams. | numeric | -- |  |
| calories_kcal | Numeric calorie count per serving in kilocalories. | numeric | -- |  |
| protein_g | Numeric protein amount per serving in grams. | numeric | -- |  |
| carbs_g | Numeric carbohydrate amount per serving in grams. | numeric | -- |  |
| fat_g | Numeric fat amount per serving in grams. | numeric | -- |  |
| source | Text citing the data source for the nutritional values. | text | -- |  |
| created_at | Timestamp recording when the record was created in the Nutrition Foods table. | timestamptz | -- |  |

The Nutrition Foods table is a reference catalog of foods with serving size, caloric and macronutrient values, category, aliases, and sourcing metadata.

## Table 21: MET Exercises

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| id | Primary key uniquely identifying each row in the MET Exercises table. | uuid | -- | PK |
| name | Text name of the exercise in the reference catalog. | text | -- |  |
| category | Text category classifying the exercise. | text | -- |  |
| met_value | Numeric metabolic equivalent value for the exercise. | numeric | -- |  |
| is_ai_estimated | Boolean indicating whether the MET value was AI-estimated. | boolean | -- |  |
| is_verified | Boolean indicating whether the MET value has been verified. | boolean | -- |  |
| confidence | Numeric confidence score for the MET value. | numeric | -- |  |
| created_at | Timestamp recording when the record was created in the MET Exercises table. | timestamptz | -- |  |
| verified_by | Foreign key referencing the profile that verified the exercise value. | uuid | -- | FK |
| verified_at | Timestamp when the exercise value was verified. | timestamptz | -- |  |

The MET Exercises table is a reference catalog of exercises with their metabolic equivalent (MET) value, verification state, confidence, and verifier.

## Table 22: Chat Rooms

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| id | Primary key uniquely identifying each row in the Chat Rooms table. | uuid | -- | PK |
| participant_one | Primary key component and foreign key referencing the first participant's profile. | uuid | -- | FK |
| participant_two | Primary key component and foreign key referencing the second participant's profile. | uuid | -- | FK |
| created_at | Timestamp recording when the record was created in the Chat Rooms table. | timestamptz | -- |  |

The Chat Rooms table represents a one-to-one conversation between two profiles, identified by the two participants and creation timestamp.

## Table 23: Chat Messages

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| id | Primary key uniquely identifying each row in the Chat Messages table. | uuid | -- | PK |
| room_id | Foreign key referencing the chat room containing the message. | uuid | -- | FK |
| sender_id | Foreign key referencing the profile that sent the message. | uuid | -- | FK |
| content | Text body of the chat message. | text | -- |  |
| created_at | Timestamp recording when the record was created in the Chat Messages table. | timestamptz | -- |  |

The Chat Messages table stores individual messages within a chat room, including sender, content, and creation timestamp.

## Table 24: Notifications

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| id | Primary key uniquely identifying each row in the Notifications table. | uuid | -- | PK |
| user_id | Foreign key referencing the profile receiving the notification. | uuid | -- | FK |
| title | Short text title of the notification. | text | -- |  |
| body | Text body content of the notification. | text | -- |  |
| read | Boolean indicating whether the notification has been read. | boolean | -- |  |
| created_at | Timestamp recording when the record was created in the Notifications table. | timestamptz | -- |  |

The Notifications table stores push or in-app notifications delivered to a user, including title, body, read state, and creation timestamp.

## Table 25: Predictions

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| id | Primary key uniquely identifying each row in the Predictions table. | uuid | -- | PK |
| member_id | Foreign key referencing the member the prediction concerns. | uuid | -- | FK |
| metric_name | Text name of the predicted fitness metric. | text | -- |  |
| predicted_value | Decimal value predicted by the analytics model. | decimal | 10,2 |  |
| predicted_date | Date the prediction is made for. | date | -- |  |
| confidence | Decimal confidence score of the prediction, between 0 and 1. | decimal | 4,3 |  |
| created_at | Timestamp recording when the record was created in the Predictions table. | timestamptz | -- |  |

The Predictions table stores predictive analytics outputs for a member, including the metric, predicted value, prediction date, and model confidence.

## Table 26: Admin Logs

| Field Name | Description | Field Type | Field Size | Type of Key |
|------------|-------------|------------|------------|-------------|
| id | Primary key uniquely identifying each row in the Admin Logs table. | uuid | -- | PK |
| admin_id | Foreign key referencing the administrator who performed the action. | uuid | -- | FK |
| action | Text describing the administrative action taken. | text | -- |  |
| target_type | Text categorizing the type of target entity. | text | -- |  |
| target_id | UUID identifier of the target entity. | uuid | -- |  |
| details | JSON object containing structured details about the action. | jsonb | -- |  |
| created_at | Timestamp recording when the record was created in the Admin Logs table. | timestamptz | -- |  |

The Admin Logs table records administrative actions performed in the system, including the acting admin, action type, target, and structured details.

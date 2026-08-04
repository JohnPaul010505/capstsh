export type UserRole = 'admin' | 'trainer' | 'member'


export interface Profile {
  id: string
  role: UserRole
  full_name: string
  email: string
  code: string | null
  phone: string | null
  avatar_url: string | null
  date_of_birth: string | null
  gender: string | null
  address: string | null
  fitness_goal: string | null
  specialty: string | null
  available_days: string | null
  emergency_contact_name: string | null
  emergency_contact_phone: string | null
  created_at: string
  updated_at: string
}

export interface Membership {
  id: string
  member_id: string
  plan_name: string
  price: number
  start_date: string
  end_date: string
  status: string
  created_at: string
  updated_at: string
  profiles?: {
    full_name: string
    email: string
    code: string | null
  }
}

export interface TrainerAssignment {
  id: string
  trainer_id: string
  member_id: string
  assigned_at: string
  status: 'active' | 'ended'
}

export interface Attendance {
  id: string
  member_id: string
  check_in_time: string
  check_in_date: string
}

export interface WorkoutLog {
  id: string
  member_id: string
  exercise_name: string
  sets: number | null
  reps: number | null
  weight: number | null
  duration_minutes: number | null
  notes: string | null
  logged_at: string
}

export interface BodyMeasurement {
  id: string
  member_id: string
  weight_kg: number | null
  height_cm: number | null
  body_fat_pct: number | null
  chest_cm: number | null
  waist_cm: number | null
  hips_cm: number | null
  arm_cm: number | null
  thigh_cm: number | null
  measured_at: string
}

export interface Goal {
  id: string
  member_id: string
  title: string
  description: string | null
  target_value: number | null
  current_value: number | null
  unit: string | null
  deadline: string | null
  status: string
  created_at: string
  updated_at: string
}

export interface TrainerFeedback {
  id: string
  trainer_id: string
  member_id: string
  content: string
  created_at: string
}

export interface MealRecord {
  id: string
  member_id: string
  meal_type: string
  food_items: string
  calories: number | null
  protein_g: number | null
  carbs_g: number | null
  fat_g: number | null
  recorded_at: string
}

export interface AdminLog {
  id: string
  admin_id: string
  action: string
  target_type: string | null
  target_id: string | null
  details: Record<string, unknown> | null
  created_at: string
}

export interface Address {
  member_id: string
  line1: string
  line2: string | null
  city: string
  state: string
  postal_code: string
  country: string
  created_at: string
  updated_at: string
}

export interface Enrollment {
  id: string
  full_name: string
  email: string
  phone: string | null
  date_of_birth: string | null
  gender: string | null
  address: string | null
  emergency_contact_name: string | null
  emergency_contact_phone: string | null
  status: string
  confirmed_at: string | null
  confirmed_by: string | null
  created_at: string
  state_updated_at: string | null
}

export interface CheckIn {
  id: string
  member_id: string
  check_in_time: string
}

export interface MealLog {
  id: string
  member_id: string
  meal_type: string
  food_name: string
  calories: number | null
  protein_g: number | null
  carbs_g: number | null
  fat_g: number | null
  photo_url: string | null
  meal_time: string
}

export interface Prediction {
  id: string
  member_id: string
  metric_name: string
  predicted_value: string | null
  predicted_date: string | null
  confidence: number | null
  created_at: string
}

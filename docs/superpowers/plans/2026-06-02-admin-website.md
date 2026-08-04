# Admin Website Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the admin website (React + Vite) with Supabase backend for the Intelligent Fitness Progress Monitoring System.

**Architecture:** Vite SPA with direct Supabase JS SDK calls, TanStack Query for server state, and Shadcn/UI component library. React Router for page routing with auth guard.

**Tech Stack:** React 18, TypeScript, Vite, Tailwind CSS, Shadcn/UI, TanStack Query, React Router v6, Recharts, Supabase JS SDK

---

### Task 1: Project Scaffolding

**Files:**
- Create: `admin/package.json`
- Create: `admin/tsconfig.json`
- Create: `admin/tsconfig.node.json`
- Create: `admin/vite.config.ts`
- Create: `admin/tailwind.config.ts`
- Create: `admin/postcss.config.js`
- Create: `admin/index.html`
- Create: `admin/src/main.tsx`
- Create: `admin/src/App.tsx`
- Create: `admin/src/index.css`
- Create: `admin/src/vite-env.d.ts`
- Create: `.env.example`

- [ ] **Step 1: Create project directory and package.json**

```bash
New-Item -ItemType Directory -Path "admin" -Force
```

```json
{
  "name": "fitness-admin",
  "private": true,
  "version": "0.0.1",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-router-dom": "^6.26.0",
    "@tanstack/react-query": "^5.51.0",
    "@supabase/supabase-js": "^2.45.0",
    "recharts": "^2.12.0",
    "lucide-react": "^0.424.0",
    "class-variance-authority": "^0.7.0",
    "clsx": "^2.1.1",
    "tailwind-merge": "^2.4.0",
    "@radix-ui/react-avatar": "^1.1.0",
    "@radix-ui/react-dialog": "^1.1.0",
    "@radix-ui/react-dropdown-menu": "^2.1.0",
    "@radix-ui/react-select": "^2.1.0",
    "@radix-ui/react-slot": "^1.1.0",
    "@radix-ui/react-toast": "^1.2.0"
  },
  "devDependencies": {
    "@types/react": "^18.3.3",
    "@types/react-dom": "^18.3.0",
    "@vitejs/plugin-react": "^4.3.1",
    "autoprefixer": "^10.4.19",
    "postcss": "^8.4.39",
    "tailwindcss": "^3.4.6",
    "typescript": "^5.5.3",
    "vite": "^5.3.4"
  }
}
```

- [ ] **Step 2: Create tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "isolatedModules": true,
    "moduleDetection": "force",
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src"]
}
```

- [ ] **Step 3: Create tsconfig.node.json**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2023"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "isolatedModules": true,
    "moduleDetection": "force",
    "noEmit": true,
    "strict": true
  },
  "include": ["vite.config.ts"]
}
```

- [ ] **Step 4: Create vite.config.ts**

```ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
})
```

- [ ] **Step 5: Create tailwind.config.ts**

```ts
import type { Config } from 'tailwindcss'

export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
} satisfies Config
```

- [ ] **Step 6: Create postcss.config.js**

```js
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
```

- [ ] **Step 7: Create index.html**

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Fitness Admin</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

- [ ] **Step 8: Create src/vite-env.d.ts**

```ts
/// <reference types="vite/client" />
```

- [ ] **Step 9: Create src/index.css**

```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

- [ ] **Step 10: Create src/main.tsx**

```tsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter } from 'react-router-dom'
import App from './App'
import './index.css'

const queryClient = new QueryClient()

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </QueryClientProvider>
  </React.StrictMode>,
)
```

- [ ] **Step 11: Create src/App.tsx**

```tsx
export default function App() {
  return (
    <div className="min-h-screen bg-background">
      <h1 className="text-2xl font-bold p-4">Fitness Admin</h1>
    </div>
  )
}
```

- [ ] **Step 12: Create .env.example**

```
VITE_SUPABASE_URL=your_supabase_url
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
```

- [ ] **Step 13: Install dependencies**

Run: `cd admin && npm install`
Expected: All dependencies installed without errors.

---

### Task 2: Supabase Migration — Schema + RLS

**Files:**
- Create: `supabase/migrations/00001_initial_schema.sql`
- Create: `supabase/seed.sql`
- Create: `supabase/config.toml`

- [ ] **Step 1: Create migration with all tables**

```sql
-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- Custom types
create type user_role as enum ('admin', 'trainer', 'member');
create type membership_status as enum ('active', 'expired', 'cancelled');
create type assignment_status as enum ('active', 'ended');

-- Profiles (extends auth.users)
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role user_role not null default 'member',
  full_name text not null,
  email text not null,
  phone text,
  avatar_url text,
  date_of_birth date,
  gender text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Memberships
create table memberships (
  id uuid primary key default uuid_generate_v4(),
  member_id uuid not null references profiles(id) on delete cascade,
  plan_name text not null,
  price decimal(10,2) not null,
  start_date date not null,
  end_date date not null,
  status membership_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Trainer assignments
create table trainer_assignments (
  id uuid primary key default uuid_generate_v4(),
  trainer_id uuid not null references profiles(id) on delete cascade,
  member_id uuid not null references profiles(id) on delete cascade,
  assigned_at timestamptz not null default now(),
  status assignment_status not null default 'active',
  unique(member_id, trainer_id, status)
);

-- Attendance
create table attendance (
  id uuid primary key default uuid_generate_v4(),
  member_id uuid not null references profiles(id) on delete cascade,
  check_in_time timestamptz not null default now(),
  check_in_date date not null default current_date
);

-- Workout logs
create table workout_logs (
  id uuid primary key default uuid_generate_v4(),
  member_id uuid not null references profiles(id) on delete cascade,
  exercise_name text not null,
  sets int,
  reps int,
  weight decimal(10,2),
  duration_minutes int,
  notes text,
  logged_at timestamptz not null default now()
);

-- Body measurements
create table body_measurements (
  id uuid primary key default uuid_generate_v4(),
  member_id uuid not null references profiles(id) on delete cascade,
  weight_kg decimal(5,2),
  height_cm decimal(5,2),
  body_fat_pct decimal(4,1),
  chest_cm decimal(5,2),
  waist_cm decimal(5,2),
  hips_cm decimal(5,2),
  arm_cm decimal(5,2),
  thigh_cm decimal(5,2),
  measured_at timestamptz not null default now()
);

-- Goals
create table goals (
  id uuid primary key default uuid_generate_v4(),
  member_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  description text,
  target_value decimal(10,2),
  current_value decimal(10,2) default 0,
  unit text,
  deadline date,
  status text not null default 'in_progress',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Trainer feedback
create table trainer_feedback (
  id uuid primary key default uuid_generate_v4(),
  trainer_id uuid not null references profiles(id) on delete cascade,
  member_id uuid not null references profiles(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

-- Meal records
create table meal_records (
  id uuid primary key default uuid_generate_v4(),
  member_id uuid not null references profiles(id) on delete cascade,
  meal_type text not null,
  food_items text not null,
  calories int,
  protein_g decimal(6,2),
  carbs_g decimal(6,2),
  fat_g decimal(6,2),
  recorded_at timestamptz not null default now()
);

-- Food recommendations
create table food_recommendations (
  id uuid primary key default uuid_generate_v4(),
  member_id uuid not null references profiles(id) on delete cascade,
  meal_type text,
  food_name text not null,
  portion_size text,
  reason text,
  created_at timestamptz not null default now()
);

-- Chat rooms
create table chat_rooms (
  id uuid primary key default uuid_generate_v4(),
  participant_one uuid not null references profiles(id) on delete cascade,
  participant_two uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(participant_one, participant_two)
);

-- Chat messages
create table chat_messages (
  id uuid primary key default uuid_generate_v4(),
  room_id uuid not null references chat_rooms(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

-- Notifications
create table notifications (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  body text,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

-- Predictions
create table predictions (
  id uuid primary key default uuid_generate_v4(),
  member_id uuid not null references profiles(id) on delete cascade,
  metric_name text not null,
  predicted_value decimal(10,2),
  predicted_date date,
  confidence decimal(4,3),
  created_at timestamptz not null default now()
);

-- Admin logs
create table admin_logs (
  id uuid primary key default uuid_generate_v4(),
  admin_id uuid not null references profiles(id) on delete cascade,
  action text not null,
  target_type text,
  target_id uuid,
  details jsonb,
  created_at timestamptz not null default now()
);

-- Indexes
create index idx_profiles_role on profiles(role);
create index idx_attendance_date on attendance(check_in_date);
create index idx_workout_logs_member on workout_logs(member_id);
create index idx_goals_member on goals(member_id);
create index idx_memberships_member on memberships(member_id);
create index idx_trainer_assignments_trainer on trainer_assignments(trainer_id);
create index idx_trainer_assignments_member on trainer_assignments(member_id);
create index idx_chat_messages_room on chat_messages(room_id);
create index idx_notifications_user on notifications(user_id);
create index idx_predictions_member on predictions(member_id);

-- RLS: Enable on all tables
alter table profiles enable row level security;
alter table memberships enable row level security;
alter table trainer_assignments enable row level security;
alter table attendance enable row level security;
alter table workout_logs enable row level security;
alter table body_measurements enable row level security;
alter table goals enable row level security;
alter table trainer_feedback enable row level security;
alter table meal_records enable row level security;
alter table food_recommendations enable row level security;
alter table chat_rooms enable row level security;
alter table chat_messages enable row level security;
alter table notifications enable row level security;
alter table predictions enable row level security;
alter table admin_logs enable row level security;

-- RLS Policies: Admin sees all
create policy "Admins can read all profiles"
  on profiles for select
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins can insert profiles"
  on profiles for insert
  with check (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins can update all profiles"
  on profiles for update
  using (auth.uid() in (select id from profiles where role = 'admin'));

-- RLS: Admins can read/insert/update on all data tables
create policy "Admins all access"
  on memberships for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on trainer_assignments for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on attendance for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on workout_logs for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on body_measurements for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on goals for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on trainer_feedback for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on meal_records for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on food_recommendations for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on chat_rooms for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on chat_messages for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on notifications for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on predictions for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on admin_logs for all
  using (auth.uid() in (select id from profiles where role = 'admin'));
```

- [ ] **Step 2: Create seed data**

```sql
-- Create admin user (password: admin123)
-- Note: Run this after creating the user in Supabase Auth dashboard
-- Get the UUID from Auth > Users

insert into profiles (id, role, full_name, email)
values ('REPLACE_WITH_ADMIN_UUID', 'admin', 'System Admin', 'admin@fitness.com');

-- Sample trainers
insert into profiles (id, role, full_name, email) values
  ('00000000-0000-0000-0000-000000000001', 'trainer', 'John Smith', 'john@fitness.com'),
  ('00000000-0000-0000-0000-000000000002', 'trainer', 'Sarah Johnson', 'sarah@fitness.com');

-- Sample members
insert into profiles (id, role, full_name, email) values
  ('00000000-0000-0000-0000-000000000010', 'member', 'Mike Wilson', 'mike@email.com'),
  ('00000000-0000-0000-0000-000000000011', 'member', 'Emma Davis', 'emma@email.com'),
  ('00000000-0000-0000-0000-000000000012', 'member', 'Alex Brown', 'alex@email.com');

-- Trainer assignments
insert into trainer_assignments (trainer_id, member_id) values
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000010'),
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000011'),
  ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000012');
```

- [ ] **Step 3: Create supabase/config.toml**

```toml
[api]
enabled = true
port = 54321

[db]
migrations_dir = "supabase/migrations"

[auth]
enabled = true
```

- [ ] **Step 4: Apply migration to Supabase project**

Run: Open Supabase Dashboard → SQL Editor → paste migration SQL → Run
Verify: Tables appear in Table Editor.

---

### Task 3: Supabase Client + Shared Types

**Files:**
- Modify: `.env.example` (already created)
- Create: `admin/src/lib/supabase.ts`
- Create: `admin/src/types/index.ts`

- [ ] **Step 1: Create Supabase client**

```ts
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY env vars')
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
```

- [ ] **Step 2: Create shared types**

```ts
export type UserRole = 'admin' | 'trainer' | 'member'
export type MembershipStatus = 'active' | 'expired' | 'cancelled'

export interface Profile {
  id: string
  role: UserRole
  full_name: string
  email: string
  phone: string | null
  avatar_url: string | null
  date_of_birth: string | null
  gender: string | null
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
  status: MembershipStatus
  created_at: string
  updated_at: string
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
```

- [ ] **Step 3: Create .env file from .env.example and add actual values**

The user needs to provide their Supabase URL and anon key from the Supabase Dashboard → Settings → API.

---

### Task 4: Authentication

**Files:**
- Create: `admin/src/features/auth/hooks/useAuth.ts`
- Create: `admin/src/features/auth/pages/LoginPage.tsx`
- Modify: `admin/src/App.tsx`

- [ ] **Step 1: Create useAuth hook**

```ts
import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import { supabase } from '@/lib/supabase'
import type { Profile } from '@/types'

interface AuthContextType {
  profile: Profile | null
  loading: boolean
  signIn: (email: string, password: string) => Promise<string | null>
  signOut: () => Promise<void>
}

const AuthContext = createContext<AuthContextType>({
  profile: null,
  loading: true,
  signIn: async () => null,
  signOut: async () => {},
})

export function AuthProvider({ children }: { children: ReactNode }) {
  const [profile, setProfile] = useState<Profile | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session?.user) fetchProfile(session.user.id)
      else setLoading(false)
    })

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session?.user) fetchProfile(session.user.id)
      else { setProfile(null); setLoading(false) }
    })

    return () => subscription.unsubscribe()
  }, [])

  async function fetchProfile(userId: string) {
    const { data } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .single()

    if (data && data.role === 'admin') {
      setProfile(data as Profile)
    }
    setLoading(false)
  }

  async function signIn(email: string, password: string): Promise<string | null> {
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) return error.message

    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return 'Login failed'

    const { data } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single()

    if (data?.role !== 'admin') {
      await supabase.auth.signOut()
      return 'Access denied. Admin account required.'
    }

    return null
  }

  async function signOut() {
    await supabase.auth.signOut()
    setProfile(null)
  }

  return (
    <AuthContext.Provider value={{ profile, loading, signIn, signOut }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  return useContext(AuthContext)
}
```

- [ ] **Step 2: Create LoginPage**

```tsx
import { useState } from 'react'
import { useAuth } from '../hooks/useAuth'

export default function LoginPage() {
  const { signIn } = useAuth()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    setLoading(true)
    const err = await signIn(email, password)
    if (err) setError(err)
    setLoading(false)
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="w-full max-w-md space-y-8 p-8 bg-white rounded-xl shadow-lg">
        <div className="text-center">
          <h1 className="text-3xl font-bold">Fitness Admin</h1>
          <p className="text-gray-500 mt-2">Sign in to your account</p>
        </div>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1">Email</label>
            <input
              type="email"
              value={email}
              onChange={e => setEmail(e.target.value)}
              className="w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              required
            />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">Password</label>
            <input
              type="password"
              value={password}
              onChange={e => setPassword(e.target.value)}
              className="w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              required
            />
          </div>
          {error && <p className="text-red-500 text-sm">{error}</p>}
          <button
            type="submit"
            disabled={loading}
            className="w-full py-2 px-4 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
          >
            {loading ? 'Signing in...' : 'Sign in'}
          </button>
        </form>
      </div>
    </div>
  )
}
```

- [ ] **Step 3: Update App.tsx with auth routing**

```tsx
import { Routes, Route, Navigate } from 'react-router-dom'
import { AuthProvider, useAuth } from '@/features/auth/hooks/useAuth'
import LoginPage from '@/features/auth/pages/LoginPage'
import AdminLayout from '@/layouts/AdminLayout'
import DashboardPage from '@/features/dashboard/pages/DashboardPage'

function AuthGuard({ children }: { children: React.ReactNode }) {
  const { profile, loading } = useAuth()

  if (loading) return <div className="flex items-center justify-center min-h-screen">Loading...</div>
  if (!profile) return <Navigate to="/login" replace />

  return <>{children}</>
}

function AppRoutes() {
  const { profile } = useAuth()

  if (!profile) return <LoginPage />

  return (
    <AdminLayout>
      <Routes>
        <Route path="/" element={<Navigate to="/dashboard" replace />} />
        <Route path="/dashboard" element={<DashboardPage />} />
      </Routes>
    </AdminLayout>
  )
}

export default function App() {
  return (
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>
  )
}
```

---

### Task 5: Layout — Sidebar + Header

**Files:**
- Create: `admin/src/layouts/AdminLayout.tsx`
- Create: `admin/src/layouts/Sidebar.tsx`
- Create: `admin/src/layouts/Header.tsx`
- Create: `admin/src/lib/utils.ts`

- [ ] **Step 1: Create cn utility**

```ts
import { type ClassValue, clsx } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
```

- [ ] **Step 2: Create Sidebar**

```tsx
import { NavLink } from 'react-router-dom'
import { cn } from '@/lib/utils'
import {
  LayoutDashboard, Users, Dumbbell, CreditCard,
  CalendarCheck, ClipboardList, BarChart3, TrendingUp, Settings,
} from 'lucide-react'

const navItems = [
  { to: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { to: '/members', label: 'Members', icon: Users },
  { to: '/trainers', label: 'Trainers', icon: Dumbbell },
  { to: '/memberships', label: 'Memberships', icon: CreditCard },
  { to: '/attendance', label: 'Attendance', icon: CalendarCheck },
  { to: '/workouts', label: 'Workouts', icon: ClipboardList },
  { to: '/reports', label: 'Reports', icon: BarChart3 },
  { to: '/predictions', label: 'Predictions', icon: TrendingUp },
  { to: '/settings', label: 'Settings', icon: Settings },
]

export default function Sidebar({ collapsed, onToggle }: { collapsed: boolean; onToggle: () => void }) {
  return (
    <aside className={cn(
      "bg-white border-r border-gray-200 flex flex-col transition-all duration-300",
      collapsed ? "w-16" : "w-60"
    )}>
      <div className="h-14 flex items-center px-4 border-b">
        {!collapsed && <span className="font-bold text-lg">Fitness Admin</span>}
      </div>
      <nav className="flex-1 py-2">
        {navItems.map(item => (
          <NavLink
            key={item.to}
            to={item.to}
            className={({ isActive }) => cn(
              "flex items-center gap-3 px-4 py-2.5 text-sm transition-colors",
              isActive
                ? "bg-blue-50 text-blue-700 font-medium"
                : "text-gray-600 hover:bg-gray-50 hover:text-gray-900"
            )}
          >
            <item.icon className="w-5 h-5 shrink-0" />
            {!collapsed && <span>{item.label}</span>}
          </NavLink>
        ))}
      </nav>
    </aside>
  )
}
```

- [ ] **Step 3: Create Header**

```tsx
import { useAuth } from '@/features/auth/hooks/useAuth'
import { Bell, Search, ChevronDown } from 'lucide-react'

export default function Header({ onToggleSidebar }: { onToggleSidebar: () => void }) {
  const { profile, signOut } = useAuth()

  return (
    <header className="h-14 bg-white border-b border-gray-200 flex items-center justify-between px-4">
      <div className="flex items-center gap-4">
        <button onClick={onToggleSidebar} className="text-gray-500 hover:text-gray-700">
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
          </svg>
        </button>
        <div className="relative hidden sm:block">
          <Search className="w-4 h-4 absolute left-3 top-2.5 text-gray-400" />
          <input
            placeholder="Search..."
            className="pl-9 pr-4 py-2 text-sm border rounded-lg w-64 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
      </div>
      <div className="flex items-center gap-3">
        <button className="relative p-2 text-gray-500 hover:text-gray-700">
          <Bell className="w-5 h-5" />
          <span className="absolute top-1 right-1 w-2 h-2 bg-red-500 rounded-full" />
        </button>
        <div className="flex items-center gap-2 text-sm">
          <span className="text-gray-700">{profile?.full_name}</span>
          <ChevronDown className="w-4 h-4 text-gray-400" />
        </div>
      </div>
    </header>
  )
}
```

- [ ] **Step 4: Create AdminLayout**

```tsx
import { useState, type ReactNode } from 'react'
import Sidebar from './Sidebar'
import Header from './Header'

export default function AdminLayout({ children }: { children: ReactNode }) {
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)

  return (
    <div className="flex h-screen overflow-hidden bg-gray-50">
      <Sidebar collapsed={sidebarCollapsed} onToggle={() => setSidebarCollapsed(v => !v)} />
      <div className="flex-1 flex flex-col overflow-hidden">
        <Header onToggleSidebar={() => setSidebarCollapsed(v => !v)} />
        <main className="flex-1 overflow-y-auto p-6">
          {children}
        </main>
      </div>
    </div>
  )
}
```

---

### Task 6: Dashboard Page

**Files:**
- Create: `admin/src/features/dashboard/pages/DashboardPage.tsx`
- Create: `admin/src/features/dashboard/components/DashboardStats.tsx`

- [ ] **Step 1: Create Dashboard page with stats + charts**

```tsx
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { Users, Dumbbell, CreditCard, TrendingUp } from 'lucide-react'
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'
import StatsCard from '@/components/StatsCard'

function useDashboardStats() {
  return useQuery({
    queryKey: ['dashboard-stats'],
    queryFn: async () => {
      const [members, trainers, memberships, attendanceToday] = await Promise.all([
        supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('role', 'member'),
        supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('role', 'trainer'),
        supabase.from('memberships').select('id', { count: 'exact', head: true }).eq('status', 'active'),
        supabase.from('attendance').select('id', { count: 'exact', head: true }).eq('check_in_date', new Date().toISOString().split('T')[0]),
      ])
      return {
        totalMembers: members.count ?? 0,
        totalTrainers: trainers.count ?? 0,
        activeMemberships: memberships.count ?? 0,
        attendanceToday: attendanceToday.count ?? 0,
      }
    },
  })
}

function useAttendanceChart() {
  return useQuery({
    queryKey: ['attendance-chart'],
    queryFn: async () => {
      const sevenDaysAgo = new Date()
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 6)
      const { data } = await supabase
        .from('attendance')
        .select('check_in_date')
        .gte('check_in_date', sevenDaysAgo.toISOString().split('T')[0])

      const counts: Record<string, number> = {}
      if (data) {
        data.forEach(a => {
          counts[a.check_in_date] = (counts[a.check_in_date] || 0) + 1
        })
      }
      const days = []
      for (let i = 6; i >= 0; i--) {
        const d = new Date()
        d.setDate(d.getDate() - i)
        const key = d.toISOString().split('T')[0]
        days.push({ date: key, count: counts[key] || 0 })
      }
      return days
    },
  })
}

export default function DashboardPage() {
  const { data: stats, isLoading } = useDashboardStats()
  const { data: chartData } = useAttendanceChart()

  if (isLoading) return <div>Loading...</div>

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Dashboard</h1>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatsCard title="Total Members" value={stats?.totalMembers ?? 0} icon={Users} />
        <StatsCard title="Total Trainers" value={stats?.totalTrainers ?? 0} icon={Dumbbell} />
        <StatsCard title="Active Memberships" value={stats?.activeMemberships ?? 0} icon={CreditCard} />
        <StatsCard title="Today's Attendance" value={stats?.attendanceToday ?? 0} icon={TrendingUp} />
      </div>

      <div className="bg-white p-6 rounded-xl border shadow-sm">
        <h2 className="text-lg font-semibold mb-4">Attendance (Last 7 Days)</h2>
        <div className="h-72">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="date" tick={{ fontSize: 12 }} />
              <YAxis />
              <Tooltip />
              <Bar dataKey="count" fill="#3b82f6" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Create StatsCard component**

```tsx
import { type LucideIcon } from 'lucide-react'

interface StatsCardProps {
  title: string
  value: number
  icon: LucideIcon
}

export default function StatsCard({ title, value, icon: Icon }: StatsCardProps) {
  return (
    <div className="bg-white p-6 rounded-xl border shadow-sm">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-gray-500">{title}</p>
          <p className="text-2xl font-bold mt-1">{value.toLocaleString()}</p>
        </div>
        <div className="w-10 h-10 bg-blue-50 rounded-lg flex items-center justify-center">
          <Icon className="w-5 h-5 text-blue-600" />
        </div>
      </div>
    </div>
  )
}
```

---

### Task 7: Members Feature

**Files:**
- Create: `admin/src/features/members/hooks/useMembers.ts`
- Create: `admin/src/features/members/pages/MembersListPage.tsx`
- Create: `admin/src/features/members/pages/MemberDetailPage.tsx`
- Create: `admin/src/features/members/components/MemberTable.tsx`
- Create: `admin/src/features/members/components/MemberForm.tsx`
- Create: `admin/src/features/members/components/MemberStats.tsx`
- Modify: `admin/src/App.tsx`

- [ ] **Step 1: Create useMembers hook**

```ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import type { Profile } from '@/types'

export function useMembers(search?: string) {
  return useQuery({
    queryKey: ['members', search],
    queryFn: async () => {
      let query = supabase
        .from('profiles')
        .select('*')
        .eq('role', 'member')
        .order('created_at', { ascending: false })

      if (search) {
        query = query.ilike('full_name', `%${search}%`)
      }

      const { data } = await query
      return (data ?? []) as Profile[]
    },
  })
}

export function useMember(id: string) {
  return useQuery({
    queryKey: ['member', id],
    queryFn: async () => {
      const { data } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', id)
        .single()
      return data as Profile | null
    },
  })
}

export function useCreateMember() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (member: { full_name: string; email: string; phone?: string }) => {
      // Create auth user first (admin only — requires service_role key)
      // For now, insert profile directly (user must be created via Supabase dashboard)
      const { data, error } = await supabase
        .from('profiles')
        .insert({ ...member, role: 'member' })
        .select()
        .single()
      if (error) throw error
      return data as Profile
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['members'] })
    },
  })
}

export function useUpdateMember() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ id, ...updates }: Partial<Profile> & { id: string }) => {
      const { data, error } = await supabase
        .from('profiles')
        .update(updates)
        .eq('id', id)
        .select()
        .single()
      if (error) throw error
      return data as Profile
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['members'] })
    },
  })
}
```

- [ ] **Step 2: Create MemberTable component**

```tsx
import { useNavigate } from 'react-router-dom'
import type { Profile } from '@/types'

interface MemberTableProps {
  members: Profile[]
  onEdit: (member: Profile) => void
}

export default function MemberTable({ members, onEdit }: MemberTableProps) {
  const navigate = useNavigate()

  return (
    <div className="bg-white rounded-xl border shadow-sm overflow-hidden">
      <table className="w-full">
        <thead>
          <tr className="border-b bg-gray-50">
            <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Name</th>
            <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Email</th>
            <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Phone</th>
            <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Joined</th>
            <th className="text-right px-4 py-3 text-sm font-medium text-gray-500">Actions</th>
          </tr>
        </thead>
        <tbody>
          {members.map(member => (
            <tr
              key={member.id}
              className="border-b last:border-0 hover:bg-gray-50 cursor-pointer"
              onClick={() => navigate(`/members/${member.id}`)}
            >
              <td className="px-4 py-3 text-sm font-medium">{member.full_name}</td>
              <td className="px-4 py-3 text-sm text-gray-500">{member.email}</td>
              <td className="px-4 py-3 text-sm text-gray-500">{member.phone || '—'}</td>
              <td className="px-4 py-3 text-sm text-gray-500">
                {new Date(member.created_at).toLocaleDateString()}
              </td>
              <td className="px-4 py-3 text-right">
                <button
                  onClick={e => { e.stopPropagation(); onEdit(member) }}
                  className="text-sm text-blue-600 hover:text-blue-800"
                >
                  Edit
                </button>
              </td>
            </tr>
          ))}
          {members.length === 0 && (
            <tr>
              <td colSpan={5} className="px-4 py-8 text-center text-gray-400">No members found</td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  )
}
```

- [ ] **Step 3: Create MembersListPage**

```tsx
import { useState } from 'react'
import { useMembers } from '../hooks/useMembers'
import MemberTable from '../components/MemberTable'
import MemberForm from '../components/MemberForm'
import type { Profile } from '@/types'

export default function MembersListPage() {
  const [search, setSearch] = useState('')
  const [editingMember, setEditingMember] = useState<Profile | null>(null)
  const [showForm, setShowForm] = useState(false)
  const { data: members, isLoading } = useMembers(search)

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Members</h1>
        <button
          onClick={() => setShowForm(true)}
          className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 text-sm"
        >
          Add Member
        </button>
      </div>

      <input
        placeholder="Search members..."
        value={search}
        onChange={e => setSearch(e.target.value)}
        className="w-full max-w-xs px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
      />

      {isLoading ? (
        <div className="text-center py-8 text-gray-500">Loading...</div>
      ) : (
        <MemberTable
          members={members ?? []}
          onEdit={member => { setEditingMember(member); setShowForm(true) }}
        />
      )}

      {(showForm) && (
        <MemberForm
          member={editingMember}
          onClose={() => { setShowForm(false); setEditingMember(null) }}
        />
      )}
    </div>
  )
}
```

- [ ] **Step 4: Create MemberForm component**

```tsx
import { useState, useEffect } from 'react'
import { useCreateMember, useUpdateMember } from '../hooks/useMembers'
import type { Profile } from '@/types'

interface MemberFormProps {
  member: Profile | null
  onClose: () => void
}

export default function MemberForm({ member, onClose }: MemberFormProps) {
  const [fullName, setFullName] = useState('')
  const [email, setEmail] = useState('')
  const [phone, setPhone] = useState('')
  const createMember = useCreateMember()
  const updateMember = useUpdateMember()

  useEffect(() => {
    if (member) {
      setFullName(member.full_name)
      setEmail(member.email)
      setPhone(member.phone ?? '')
    }
  }, [member])

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (member) {
      await updateMember.mutateAsync({ id: member.id, full_name: fullName, email, phone: phone || null })
    } else {
      await createMember.mutateAsync({ full_name: fullName, email, phone: phone || undefined })
    }
    onClose()
  }

  return (
    <div className="fixed inset-0 bg-black/30 flex items-center justify-center z-50">
      <div className="bg-white rounded-xl p-6 w-full max-w-md">
        <h2 className="text-lg font-bold mb-4">{member ? 'Edit Member' : 'Add Member'}</h2>
        <form onSubmit={handleSubmit} className="space-y-3">
          <div>
            <label className="block text-sm font-medium mb-1">Full Name</label>
            <input value={fullName} onChange={e => setFullName(e.target.value)} className="w-full px-3 py-2 border rounded-lg text-sm" required />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">Email</label>
            <input type="email" value={email} onChange={e => setEmail(e.target.value)} className="w-full px-3 py-2 border rounded-lg text-sm" required />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">Phone</label>
            <input value={phone} onChange={e => setPhone(e.target.value)} className="w-full px-3 py-2 border rounded-lg text-sm" />
          </div>
          <div className="flex justify-end gap-2 pt-2">
            <button type="button" onClick={onClose} className="px-4 py-2 text-sm border rounded-lg hover:bg-gray-50">Cancel</button>
            <button type="submit" className="px-4 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700">
              {member ? 'Update' : 'Create'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
```

- [ ] **Step 5: Create MemberDetailPage**

```tsx
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { useMember } from '../hooks/useMember'
import { ArrowLeft, Calendar, Dumbbell, Target, Scale } from 'lucide-react'
import StatsCard from '@/components/StatsCard'
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, LineChart, Line,
} from 'recharts'

export default function MemberDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { data: member, isLoading } = useMember(id!)

  const { data: workouts } = useQuery({
    queryKey: ['member-workouts', id],
    queryFn: async () => {
      const { data } = await supabase
        .from('workout_logs')
        .select('*')
        .eq('member_id', id)
        .order('logged_at', { ascending: false })
        .limit(10)
      return data ?? []
    },
  })

  const { data: measurements } = useQuery({
    queryKey: ['member-measurements', id],
    queryFn: async () => {
      const { data } = await supabase
        .from('body_measurements')
        .select('*')
        .eq('member_id', id)
        .order('measured_at', { ascending: true })
      return data ?? []
    },
  })

  if (isLoading) return <div className="text-center py-8">Loading...</div>
  if (!member) return <div className="text-center py-8">Member not found</div>

  return (
    <div className="space-y-6">
      <button onClick={() => navigate('/members')} className="flex items-center gap-1 text-sm text-gray-500 hover:text-gray-700">
        <ArrowLeft className="w-4 h-4" /> Back to Members
      </button>

      <div className="bg-white p-6 rounded-xl border shadow-sm">
        <div className="flex items-center gap-4">
          <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center">
            <span className="text-2xl font-bold text-blue-600">
              {member.full_name.charAt(0)}
            </span>
          </div>
          <div>
            <h1 className="text-xl font-bold">{member.full_name}</h1>
            <p className="text-sm text-gray-500">{member.email}</p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <StatsCard title="Workouts" value={workouts?.length ?? 0} icon={Dumbbell} />
        <StatsCard title="Goals" value={0} icon={Target} />
        <StatsCard title="Measurements" value={measurements?.length ?? 0} icon={Scale} />
      </div>

      {measurements && measurements.length > 0 && (
        <div className="bg-white p-6 rounded-xl border shadow-sm">
          <h2 className="text-lg font-semibold mb-4">Weight Progress</h2>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={measurements}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis
                  dataKey="measured_at"
                  tickFormatter={v => new Date(v).toLocaleDateString()}
                  tick={{ fontSize: 12 }}
                />
                <YAxis />
                <Tooltip />
                <Line type="monotone" dataKey="weight_kg" stroke="#3b82f6" strokeWidth={2} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}
    </div>
  )
}
```

- [ ] **Step 6: Update App.tsx to add member routes**

Inside `<Routes>` within `AppRoutes`:
```tsx
<Route path="/members" element={<MembersListPage />} />
<Route path="/members/:id" element={<MemberDetailPage />} />
```

Also update the import:
```tsx
import MembersListPage from '@/features/members/pages/MembersListPage'
import MemberDetailPage from '@/features/members/pages/MemberDetailPage'
```

---

### Task 8: Trainers Feature

**Files:**
- Create: `admin/src/features/trainers/hooks/useTrainers.ts`
- Create: `admin/src/features/trainers/pages/TrainersListPage.tsx`
- Create: `admin/src/features/trainers/pages/TrainerDetailPage.tsx`
- Create: `admin/src/features/trainers/components/TrainerTable.tsx`
- Create: `admin/src/features/trainers/components/TrainerForm.tsx`
- Modify: `admin/src/App.tsx`

- [ ] **Step 1: Create useTrainers hook**

```ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import type { Profile, TrainerAssignment } from '@/types'

export function useTrainers() {
  return useQuery({
    queryKey: ['trainers'],
    queryFn: async () => {
      const { data } = await supabase
        .from('profiles')
        .select('*')
        .eq('role', 'trainer')
        .order('created_at', { ascending: false })
      return (data ?? []) as Profile[]
    },
  })
}

export function useTrainer(id: string) {
  return useQuery({
    queryKey: ['trainer', id],
    queryFn: async () => {
      const { data: profile } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', id)
        .single()

      const { data: assignments } = await supabase
        .from('trainer_assignments')
        .select('*, profiles!trainer_assignments_member_id_fkey(*)')
        .eq('trainer_id', id)
        .eq('status', 'active')

      return { profile: profile as Profile | null, members: (assignments ?? []) as any[] }
    },
  })
}

export function useAssignTrainer() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ trainer_id, member_id }: { trainer_id: string; member_id: string }) => {
      const { error } = await supabase
        .from('trainer_assignments')
        .insert({ trainer_id, member_id })
      if (error) throw error
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['trainer'] }),
  })
}
```

- [ ] **Step 2: Create TrainersListPage**

```tsx
import { useNavigate } from 'react-router-dom'
import { useTrainers } from '../hooks/useTrainers'

export default function TrainersListPage() {
  const navigate = useNavigate()
  const { data: trainers, isLoading } = useTrainers()

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">Trainers</h1>

      {isLoading ? (
        <div className="text-center py-8 text-gray-500">Loading...</div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {trainers?.map(trainer => (
            <div
              key={trainer.id}
              onClick={() => navigate(`/trainers/${trainer.id}`)}
              className="bg-white p-6 rounded-xl border shadow-sm hover:shadow-md cursor-pointer transition-shadow"
            >
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center">
                  <span className="text-lg font-bold text-green-600">{trainer.full_name.charAt(0)}</span>
                </div>
                <div>
                  <p className="font-semibold">{trainer.full_name}</p>
                  <p className="text-sm text-gray-500">{trainer.email}</p>
                </div>
              </div>
            </div>
          ))}
          {trainers?.length === 0 && (
            <p className="text-gray-400 col-span-full text-center py-8">No trainers found</p>
          )}
        </div>
      )}
    </div>
  )
}
```

- [ ] **Step 3: Add trainer routes to App.tsx**

```tsx
import TrainersListPage from '@/features/trainers/pages/TrainersListPage'
import TrainerDetailPage from '@/features/trainers/pages/TrainerDetailPage'

<Route path="/trainers" element={<TrainersListPage />} />
<Route path="/trainers/:id" element={<TrainerDetailPage />} />
```

- [ ] **Step 4: Create TrainerDetailPage**

```tsx
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { useTrainer } from '../hooks/useTrainers'
import { ArrowLeft, Users } from 'lucide-react'
import StatsCard from '@/components/StatsCard'

export default function TrainerDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { data, isLoading } = useTrainer(id!)

  if (isLoading) return <div className="text-center py-8">Loading...</div>
  if (!data?.profile) return <div className="text-center py-8">Trainer not found</div>

  return (
    <div className="space-y-6">
      <button onClick={() => navigate('/trainers')} className="flex items-center gap-1 text-sm text-gray-500 hover:text-gray-700">
        <ArrowLeft className="w-4 h-4" /> Back to Trainers
      </button>

      <div className="bg-white p-6 rounded-xl border shadow-sm">
        <div className="flex items-center gap-4">
          <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center">
            <span className="text-2xl font-bold text-green-600">
              {data.profile.full_name.charAt(0)}
            </span>
          </div>
          <div>
            <h1 className="text-xl font-bold">{data.profile.full_name}</h1>
            <p className="text-sm text-gray-500">{data.profile.email}</p>
          </div>
        </div>
      </div>

      <StatsCard title="Assigned Members" value={data.members?.length ?? 0} icon={Users} />

      <div className="bg-white rounded-xl border shadow-sm overflow-hidden">
        <div className="px-4 py-3 border-b">
          <h2 className="font-semibold">Assigned Members</h2>
        </div>
        <table className="w-full">
          <thead>
            <tr className="border-b bg-gray-50">
              <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Name</th>
              <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Email</th>
              <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Assigned</th>
            </tr>
          </thead>
          <tbody>
            {(data.members ?? []).map((a: any) => (
              <tr
                key={a.id}
                className="border-b last:border-0 hover:bg-gray-50 cursor-pointer"
                onClick={() => navigate(`/members/${a.member_id}`)}
              >
                <td className="px-4 py-3 text-sm font-medium">{a.profiles?.full_name}</td>
                <td className="px-4 py-3 text-sm text-gray-500">{a.profiles?.email}</td>
                <td className="px-4 py-3 text-sm text-gray-500">
                  {new Date(a.assigned_at).toLocaleDateString()}
                </td>
              </tr>
            ))}
            {(!data.members || data.members.length === 0) && (
              <tr><td colSpan={3} className="text-center py-8 text-gray-400">No assigned members</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}
```

---

### Task 9: Memberships Feature

**Files:**
- Create: `admin/src/features/memberships/hooks/useMemberships.ts`
- Create: `admin/src/features/memberships/pages/MembershipsPage.tsx`
- Create: `admin/src/features/memberships/components/MembershipTable.tsx`
- Modify: `admin/src/App.tsx`

- [ ] **Step 1: Create useMemberships hook**

```ts
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import type { Membership } from '@/types'

export function useMemberships() {
  return useQuery({
    queryKey: ['memberships'],
    queryFn: async () => {
      const { data } = await supabase
        .from('memberships')
        .select('*, profiles!memberships_member_id_fkey(full_name, email)')
        .order('created_at', { ascending: false })
      return data ?? []
    },
  })
}
```

- [ ] **Step 2: Create MembershipsPage**

```tsx
import { useMemberships } from '../hooks/useMemberships'
import StatusBadge from '@/components/StatusBadge'

export default function MembershipsPage() {
  const { data: memberships, isLoading } = useMemberships()

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">Memberships</h1>

      {isLoading ? (
        <div className="text-center py-8 text-gray-500">Loading...</div>
      ) : (
        <div className="bg-white rounded-xl border shadow-sm overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="border-b bg-gray-50">
                <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Member</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Plan</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Price</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Start</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">End</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Status</th>
              </tr>
            </thead>
            <tbody>
              {memberships?.map(m => (
                <tr key={m.id} className="border-b last:border-0 hover:bg-gray-50">
                  <td className="px-4 py-3 text-sm font-medium">{m.profiles?.full_name}</td>
                  <td className="px-4 py-3 text-sm">{m.plan_name}</td>
                  <td className="px-4 py-3 text-sm">${m.price}</td>
                  <td className="px-4 py-3 text-sm">{new Date(m.start_date).toLocaleDateString()}</td>
                  <td className="px-4 py-3 text-sm">{new Date(m.end_date).toLocaleDateString()}</td>
                  <td className="px-4 py-3"><StatusBadge status={m.status} /></td>
                </tr>
              ))}
              {memberships?.length === 0 && (
                <tr><td colSpan={6} className="px-4 py-8 text-center text-gray-400">No memberships</td></tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
```

- [ ] **Step 3: Create StatusBadge component**

```tsx
import { cn } from '@/lib/utils'

export default function StatusBadge({ status }: { status: string }) {
  const colors: Record<string, string> = {
    active: 'bg-green-100 text-green-700',
    expired: 'bg-red-100 text-red-700',
    cancelled: 'bg-gray-100 text-gray-700',
    in_progress: 'bg-blue-100 text-blue-700',
    high: 'bg-green-100 text-green-700',
    medium: 'bg-yellow-100 text-yellow-700',
    low: 'bg-red-100 text-red-700',
  }

  return (
    <span className={cn(
      'px-2 py-0.5 rounded-full text-xs font-medium',
      colors[status] || 'bg-gray-100 text-gray-700'
    )}>
      {status.replace('_', ' ')}
    </span>
  )
}
```

- [ ] **Step 4: Add membership route to App.tsx**

```tsx
import MembershipsPage from '@/features/memberships/pages/MembershipsPage'

<Route path="/memberships" element={<MembershipsPage />} />
```

---

### Task 10: Attendance Feature

**Files:**
- Create: `admin/src/features/attendance/hooks/useAttendance.ts`
- Create: `admin/src/features/attendance/pages/AttendancePage.tsx`
- Modify: `admin/src/App.tsx`

- [ ] **Step 1: Create useAttendance hook**

```ts
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

export function useAttendance(date?: string) {
  return useQuery({
    queryKey: ['attendance', date],
    queryFn: async () => {
      const query = supabase
        .from('attendance')
        .select('*, profiles!attendance_member_id_fkey(full_name, email)')
        .order('check_in_time', { ascending: false })

      if (date) query.eq('check_in_date', date)

      const { data } = await query
      return data ?? []
    },
  })
}
```

- [ ] **Step 2: Create AttendancePage**

```tsx
import { useState } from 'react'
import { useAttendance } from '../hooks/useAttendance'

export default function AttendancePage() {
  const today = new Date().toISOString().split('T')[0]
  const [date, setDate] = useState(today)
  const { data: records, isLoading } = useAttendance(date)

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Attendance</h1>
        <input
          type="date"
          value={date}
          onChange={e => setDate(e.target.value)}
          className="px-3 py-2 border rounded-lg text-sm"
        />
      </div>

      {isLoading ? (
        <div className="text-center py-8 text-gray-500">Loading...</div>
      ) : (
        <div className="bg-white rounded-xl border shadow-sm overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="border-b bg-gray-50">
                <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Member</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Check-in Time</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Date</th>
              </tr>
            </thead>
            <tbody>
              {records?.map(r => (
                <tr key={r.id} className="border-b last:border-0 hover:bg-gray-50">
                  <td className="px-4 py-3 text-sm font-medium">{r.profiles?.full_name}</td>
                  <td className="px-4 py-3 text-sm">{new Date(r.check_in_time).toLocaleTimeString()}</td>
                  <td className="px-4 py-3 text-sm">{r.check_in_date}</td>
                </tr>
              ))}
              {records?.length === 0 && (
                <tr><td colSpan={3} className="px-4 py-8 text-center text-gray-400">No attendance records</td></tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
```

- [ ] **Step 3: Add attendance route to App.tsx**

```tsx
import AttendancePage from '@/features/attendance/pages/AttendancePage'

<Route path="/attendance" element={<AttendancePage />} />
```

---

### Task 11: Workouts Feature

**Files:**
- Create: `admin/src/features/workouts/hooks/useWorkouts.ts`
- Create: `admin/src/features/workouts/pages/WorkoutsPage.tsx`
- Modify: `admin/src/App.tsx`

- [ ] **Step 1: Create useWorkouts hook**

```ts
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

export function useWorkouts() {
  return useQuery({
    queryKey: ['workouts'],
    queryFn: async () => {
      const { data } = await supabase
        .from('workout_logs')
        .select('*, profiles!workout_logs_member_id_fkey(full_name)')
        .order('logged_at', { ascending: false })
        .limit(50)
      return data ?? []
    },
  })
}

export function useMemberWorkouts(memberId: string) {
  return useQuery({
    queryKey: ['member-workouts', memberId],
    queryFn: async () => {
      const { data } = await supabase
        .from('workout_logs')
        .select('*')
        .eq('member_id', memberId)
        .order('logged_at', { ascending: false })
      return data ?? []
    },
  })
}
```

- [ ] **Step 2: Create WorkoutsPage**

```tsx
import { useNavigate } from 'react-router-dom'
import { useWorkouts } from '../hooks/useWorkouts'

export default function WorkoutsPage() {
  const { data: workouts, isLoading } = useWorkouts()
  const navigate = useNavigate()

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">Workout Logs</h1>

      {isLoading ? (
        <div className="text-center py-8 text-gray-500">Loading...</div>
      ) : (
        <div className="bg-white rounded-xl border shadow-sm overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="border-b bg-gray-50">
                <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Member</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Exercise</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Sets</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Reps</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Weight</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Duration</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Date</th>
              </tr>
            </thead>
            <tbody>
              {workouts?.map(w => (
                <tr
                  key={w.id}
                  className="border-b last:border-0 hover:bg-gray-50 cursor-pointer"
                  onClick={() => navigate(`/members/${w.member_id}`)}
                >
                  <td className="px-4 py-3 text-sm font-medium">{w.profiles?.full_name}</td>
                  <td className="px-4 py-3 text-sm">{w.exercise_name}</td>
                  <td className="px-4 py-3 text-sm">{w.sets ?? '—'}</td>
                  <td className="px-4 py-3 text-sm">{w.reps ?? '—'}</td>
                  <td className="px-4 py-3 text-sm">{w.weight ? `${w.weight}kg` : '—'}</td>
                  <td className="px-4 py-3 text-sm">{w.duration_minutes ? `${w.duration_minutes}min` : '—'}</td>
                  <td className="px-4 py-3 text-sm">{new Date(w.logged_at).toLocaleDateString()}</td>
                </tr>
              ))}
              {workouts?.length === 0 && (
                <tr><td colSpan={7} className="text-center py-8 text-gray-400">No workouts logged</td></tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
```

- [ ] **Step 3: Add workout routes to App.tsx**

```tsx
import WorkoutsPage from '@/features/workouts/pages/WorkoutsPage'

<Route path="/workouts" element={<WorkoutsPage />} />
<Route path="/workouts/:memberId" element={<WorkoutsPage />} />
```

---

### Task 12: Reports Page

**Files:**
- Create: `admin/src/features/reports/pages/ReportsPage.tsx`
- Create: `admin/src/features/reports/components/ReportCharts.tsx`
- Modify: `admin/src/App.tsx`

- [ ] **Step 1: Create ReportsPage**

```tsx
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  PieChart, Pie, Cell, Legend,
} from 'recharts'

const COLORS = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6']

export default function ReportsPage() {
  const { data: membershipData } = useQuery({
    queryKey: ['report-memberships'],
    queryFn: async () => {
      const { data } = await supabase
        .from('memberships')
        .select('plan_name')
      const counts: Record<string, number> = {}
      data?.forEach(m => { counts[m.plan_name] = (counts[m.plan_name] || 0) + 1 })
      return Object.entries(counts).map(([name, value]) => ({ name, value }))
    },
  })

  const { data: genderData } = useQuery({
    queryKey: ['report-gender'],
    queryFn: async () => {
      const { data } = await supabase
        .from('profiles')
        .select('gender')
        .eq('role', 'member')
      const m = data?.filter(p => p.gender === 'male').length ?? 0
      const f = data?.filter(p => p.gender === 'female').length ?? 0
      const o = data?.filter(p => p.gender && !['male', 'female'].includes(p.gender)).length ?? 0
      return [
        { name: 'Male', value: m },
        { name: 'Female', value: f },
        { name: 'Other', value: o },
      ].filter(d => d.value > 0)
    },
  })

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Reports & Analytics</h1>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-white p-6 rounded-xl border shadow-sm">
          <h2 className="text-lg font-semibold mb-4">Membership Plans</h2>
          <div className="h-72">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={membershipData ?? []}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="name" />
                <YAxis />
                <Tooltip />
                <Bar dataKey="value" fill="#3b82f6" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="bg-white p-6 rounded-xl border shadow-sm">
          <h2 className="text-lg font-semibold mb-4">Gender Distribution</h2>
          <div className="h-72">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={genderData ?? []}
                  cx="50%"
                  cy="50%"
                  outerRadius={80}
                  dataKey="value"
                  label={({ name, value }) => `${name}: ${value}`}
                >
                  {(genderData ?? []).map((_, i) => (
                    <Cell key={i} fill={COLORS[i % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip />
                <Legend />
              </PieChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Add reports route to App.tsx**

```tsx
import ReportsPage from '@/features/reports/pages/ReportsPage'

<Route path="/reports" element={<ReportsPage />} />
```

---

### Task 13: Predictions Page

**Files:**
- Create: `admin/src/features/predictions/pages/PredictionsPage.tsx`
- Modify: `admin/src/App.tsx`

- [ ] **Step 1: Create PredictionsPage**

```tsx
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { TrendingUp, TrendingDown, Minus } from 'lucide-react'
import StatusBadge from '@/components/StatusBadge'

export default function PredictionsPage() {
  const { data: predictions } = useQuery({
    queryKey: ['predictions'],
    queryFn: async () => {
      const { data } = await supabase
        .from('predictions')
        .select('*, profiles!predictions_member_id_fkey(full_name)')
        .order('created_at', { ascending: false })
        .limit(20)
      return data ?? []
    },
  })

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Predictive Analytics</h1>
        <p className="text-gray-500 text-sm mt-1">
          AI-powered predictions for member progress and trends
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-white p-6 rounded-xl border shadow-sm">
          <div className="flex items-center gap-2 text-sm text-gray-500 mb-2">
            <TrendingUp className="w-4 h-4 text-green-500" />
            <span>Predicted Retention</span>
          </div>
          <p className="text-2xl font-bold">87%</p>
          <p className="text-xs text-gray-400 mt-1">Next 30 days</p>
        </div>
        <div className="bg-white p-6 rounded-xl border shadow-sm">
          <div className="flex items-center gap-2 text-sm text-gray-500 mb-2">
            <TrendingDown className="w-4 h-4 text-orange-500" />
            <span>At Risk Members</span>
          </div>
          <p className="text-2xl font-bold">12</p>
          <p className="text-xs text-gray-400 mt-1">Low engagement</p>
        </div>
        <div className="bg-white p-6 rounded-xl border shadow-sm">
          <div className="flex items-center gap-2 text-sm text-gray-500 mb-2">
            <TrendingUp className="w-4 h-4 text-blue-500" />
            <span>Avg. Goal Completion</span>
          </div>
          <p className="text-2xl font-bold">64%</p>
          <p className="text-xs text-gray-400 mt-1">Across all members</p>
        </div>
      </div>

      <div className="bg-white rounded-xl border shadow-sm overflow-hidden">
        <div className="px-4 py-3 border-b">
          <h2 className="font-semibold">Recent Predictions</h2>
        </div>
        <table className="w-full">
          <thead>
            <tr className="border-b bg-gray-50">
              <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Member</th>
              <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Metric</th>
              <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Predicted</th>
              <th className="text-left px-4 py-3 text-sm font-medium text-gray-500">Confidence</th>
            </tr>
          </thead>
          <tbody>
            {predictions?.map(p => (
              <tr key={p.id} className="border-b last:border-0 hover:bg-gray-50">
                <td className="px-4 py-3 text-sm font-medium">{p.profiles?.full_name}</td>
                <td className="px-4 py-3 text-sm">{p.metric_name}</td>
                <td className="px-4 py-3 text-sm">{p.predicted_value}</td>
                <td className="px-4 py-3">
                  <StatusBadge status={p.confidence >= 0.8 ? 'high' : p.confidence >= 0.5 ? 'medium' : 'low'} />
                </td>
              </tr>
            ))}
            {predictions?.length === 0 && (
              <tr><td colSpan={4} className="text-center py-8 text-gray-400">No predictions yet</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Add predictions route to App.tsx**

```tsx
import PredictionsPage from '@/features/predictions/pages/PredictionsPage'

<Route path="/predictions" element={<PredictionsPage />} />
```

---

### Task 14: Settings Page

**Files:**
- Create: `admin/src/features/settings/pages/SettingsPage.tsx`
- Modify: `admin/src/App.tsx`

- [ ] **Step 1: Create SettingsPage**

```tsx
import { useAuth } from '@/features/auth/hooks/useAuth'

export default function SettingsPage() {
  const { profile, signOut } = useAuth()

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Settings</h1>

      <div className="bg-white p-6 rounded-xl border shadow-sm max-w-lg">
        <h2 className="text-lg font-semibold mb-4">Admin Profile</h2>
        <div className="space-y-3 mb-6">
          <div>
            <label className="block text-sm font-medium text-gray-500">Name</label>
            <p className="text-sm">{profile?.full_name}</p>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-500">Email</label>
            <p className="text-sm">{profile?.email}</p>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-500">Role</label>
            <p className="text-sm capitalize">{profile?.role}</p>
          </div>
        </div>

        <button
          onClick={signOut}
          className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 text-sm"
        >
          Sign Out
        </button>
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Add settings route to App.tsx**

```tsx
import SettingsPage from '@/features/settings/pages/SettingsPage'

<Route path="/settings" element={<SettingsPage />} />
```

---

### Final Step: Verify Build

- [ ] **Step 1: Build the project**

Run: `cd admin && npm run build`
Expected: TypeScript compiles without errors, Vite outputs to `admin/dist/`.

- [ ] **Step 2: Run dev server to verify**

Run: `cd admin && npm run dev`
Expected: Dev server starts on localhost, login page renders, sign in with admin credentials works.

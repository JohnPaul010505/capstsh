# Admin Website — Design Spec

## Overview

Admin-facing web dashboard for the Intelligent Fitness Progress Monitoring System. Allows admins to manage members, trainers, memberships, attendance, workouts, reports, and predictive analytics.

## Tech Stack

- React 18 + TypeScript
- Vite (build tool)
- Tailwind CSS (styling)
- Shadcn/UI (component library, Radix UI primitives)
- TanStack Query (server state)
- React Router v6 (routing)
- Recharts (charts)
- Supabase JS SDK (auth + data)

## Project Structure

```
capshiii/
├── supabase/
│   ├── migrations/
│   ├── seed.sql
│   └── config.toml
├── admin/
│   ├── src/
│   │   ├── components/       # Shared UI (Shadcn + custom)
│   │   ├── features/         # Feature modules
│   │   │   ├── auth/
│   │   │   ├── dashboard/
│   │   │   ├── members/
│   │   │   ├── trainers/
│   │   │   ├── memberships/
│   │   │   ├── attendance/
│   │   │   ├── workouts/
│   │   │   ├── reports/
│   │   │   ├── predictions/
│   │   │   └── settings/
│   │   ├── hooks/
│   │   ├── layouts/
│   │   ├── lib/              # Supabase client, utils
│   │   ├── pages/            # Route pages
│   │   ├── types/
│   │   └── main.tsx
│   ├── index.html
│   ├── package.json
│   └── vite.config.ts
└── .env
```

## Supabase Schema

Tables (admin-focused subset of the full system):

- **profiles** — extends `auth.users` with role (admin/trainer/member), full_name, email, phone, avatar, DOB, gender
- **memberships** — plan_name, price, start/end_date, status, member_id
- **trainer_assignments** — trainer_id, member_id, assigned_at, status
- **attendance** — member_id, check_in_time, check_in_date
- **workout_logs** — admin read-only
- **body_measurements** — admin read-only
- **goals** — admin view/edit
- **trainer_feedback** — admin read-only
- **meal_records** — admin read-only
- **chat_rooms / chat_messages** — admin read-only
- **admin_logs** — audit trail of admin actions

All tables protected by Row Level Security (RLS). Admins have full access; trainers scoped to assigned members; members see only their own data.

## Routes

| Path | Page |
|---|---|
| `/login` | Auth page |
| `/` | Redirects to `/dashboard` |
| `/dashboard` | Overview with stats, charts, recent activity |
| `/members` | Member list (search, filter, paginate) |
| `/members/:id` | Member detail profile |
| `/trainers` | Trainer list |
| `/trainers/:id` | Trainer detail + assigned members |
| `/memberships` | Membership plans + member subscriptions |
| `/attendance` | Attendance logs with date filter |
| `/workouts` | Workout logs (all members) |
| `/workouts/:memberId` | Workout history for a member |
| `/reports` | Reports & analytics |
| `/predictions` | Predictive analytics dashboard |
| `/settings` | Admin settings |

## Auth & Data Layer

- Supabase Auth with email/password
- AuthGuard component checks `profiles.role = 'admin'`
- TanStack Query for all server data
- Each feature uses custom hooks: `useMembers`, `useMember`, `useTrainers`, etc.
- Mutations invalidate related query keys on success

## Component Architecture

```
<AuthGuard>
  <AdminLayout>
    <Sidebar />        — collapsible nav links
    <Header />         — search, notifications, avatar dropdown
    <main>
      <Outlet />       — React Router page content
    </main>
  </AdminLayout>
</AuthGuard>
```

Each feature module follows: `pages/`, `components/`, `hooks/` sub-folders within `features/<name>/`.

Key shared components: DataTable, StatsCard, ChartWrapper, SearchInput, ConfirmDialog, StatusBadge.

## Development Phases

Admin website follows the roadmap phases from the system plan. Starting with Phase 1 backend setup + admin features.

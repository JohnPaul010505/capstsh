# Implementation Plan: Admin Reports + Trainer Notifications + In & Out

## Overview

Split the current admin Reports page into Analytics and Reports, add per-user notifications for inactive users, and add notifications + In & Out screen to the trainer app.

---

## 1. Admin — Split Reports into Analytics + Reports

### 1.1 Analytics Page (`/reports`)
- **File:** `admin/src/features/reports/pages/ReportsPage.tsx`
- Remove the "Inactive Members" section (lines 105–158 and its UI block).
- Keep everything else: Total Plans, Total Revenue, Total Members, Avg Revenue/Member, Membership Plans chart, Revenue by Plan chart.
- No route change needed — `/reports` stays as Analytics.

### 1.2 Reports Page (new, `/reports/inactive`)
- **New file:** `admin/src/features/reports/pages/InactiveReportPage.tsx`
- Route: `/reports/inactive` in `App.tsx`.
- Two sections:
  1. **Inactive Members** — Daily-plan members with no check-in in the last 7 days
  2. **Inactive Trainers** — Trainers with no check-in in the last 7 days
- Each row: name, code, last check-in date, days inactive count, status badge, **Notify** button.
- Sorted descending by days inactive.

### 1.3 Admin Navigation
- **File:** `admin/src/layouts/Sidebar.tsx`
- Rename existing `/reports` nav item label from "Reports" to "Analytics".
- Add new `/reports/inactive` nav item labeled "Reports" below Analytics.

---

## 2. Admin — Per-User Notification API

### 2.1 New API Endpoint
- **File:** `admin/server/index.js`
- Add `POST /api/notifications/send`:
  - Body: `{ userId, title, body }`
  - Inserts a single row into `notifications` table using admin service role.
  - Returns `{ success: true }` or error.
- Existing `/api/notifications/broadcast` stays unchanged.

### 2.2 Reports Page Notify Action
- Notify button calls `/api/notifications/send` with:
  - `userId`: target member/trainer profile id
  - `title`: "Inactivity Notice"
  - `body`: "You have been flagged for inactivity. Please check in to the gym."
- After successful send, navigate admin to `/notifications` (existing notifications page).

---

## 3. Trainer — Notifications Screen

### 3.1 New Notification Screen
- **New file:** `mobile/fitness_app/lib/features/trainer/notifications/pages/notifications_page.dart`
- Replicate member notifications page structure:
  - `notificationsProvider` — fetches current trainer's notifications from `notifications` table, ordered by `created_at` desc.
  - Mark-as-read on tap (update `read = true`).
  - Bell icon in app bar.
- **Route:** `/trainer/notifications` in `router.dart`.

### 3.2 Unread Count Provider
- **New file:** `mobile/fitness_app/lib/features/trainer/notifications/providers/notifications_provider.dart`
- `unreadNotificationsProvider` — counts unread notifications for current trainer.
- Used by home screen badge and profile features section.

---

## 4. Trainer — Home Screen Notification Button

### 4.1 Modify Home Top Bar
- **File:** `mobile/fitness_app/lib/features/trainer/dashboard/pages/dashboard_page.dart`
- Replace `_buildTrainerNavBar('Dashboard')` with a custom `Row`:
  - Left: empty spacer (or back if needed)
  - Center: "Dashboard" title
  - Right: bell icon button with unread badge count
- Bell tap → `context.push('/trainer/notifications')`.
- Badge shows `unreadNotificationsProvider` count; hide if 0.

---

## 5. Trainer — Profile Features Section

### 5.1 Modify Profile Page
- **File:** `mobile/fitness_app/lib/features/trainer/profile/pages/profile_page.dart`
- Add "Features" section below the profile `ClayCard`.
- Only one feature button: **Notifications** (bell icon + label).
- Tap → `context.push('/trainer/notifications')`.
- Keep existing sign-out button below.

---

## 6. Trainer — Sign Out Confirmation

### 6.1 Modify Profile Page Sign Out
- **File:** `mobile/fitness_app/lib/features/trainer/profile/pages/profile_page.dart`
- Replace direct sign-out `PressableCard` onTap with a `showDialog` confirmation:
  - Title: "Confirm Sign Out"
  - Message: "Are you sure you want to log out?"
  - Buttons: "Yes" and "No"
- Yes → call `ref.read(authProvider.notifier).signOut()` then `context.go('/login')`.
- No → dismiss dialog.

---

## 7. Trainer — In & Out Nav Tab

### 7.1 Add Tab to Trainer Nav Bar
- **File:** `mobile/fitness_app/lib/features/shared/widgets/trainer_nav_bar.dart`
- Add 5th tab: `(inactive: Icons.qr_code_scanner_outlined, active: Icons.qr_code_scanner, label: 'In & Out')`
- Route `/trainer/checkin` already exists and uses shared `CheckinPage` — just expose it in the nav.

### 7.2 TrainerShell Route Mapping
- **File:** `mobile/fitness_app/lib/app/router.dart`
- Ensure `/trainer/checkin` is in the `ShellRoute` routes (it already is).
- Update `_currentIndex` mapping in `TrainerShell` to include index 4 for checkin.

---

## 8. Bug Fix — Member Notifications Display Field

### 8.1 Fix Wrong Field Name
- **File:** `mobile/fitness_app/lib/features/member/notifications/pages/notifications_page.dart`
- Change `n['message']` to `n['body']` in the notification row text render.
- The `notifications` table schema uses `body`, not `message`.

---

## 9. Shared / Reusable

### 9.1 Notification Service (shared)
- **New file:** `mobile/shared/lib/services/notification_service.dart`
- Extract common notification operations:
  - `fetchNotifications(userId)` — get all notifications for user
  - `markAsRead(notificationId)` — set read = true
  - `unreadCount(userId)` — count unread
- Used by both member and trainer notification screens.

---

## Implementation Order

1. Admin: Split Reports page (Analytics + Reports) + nav update
2. Admin: Add `/api/notifications/send` endpoint
3. Admin: Reports page with inactive lists + Notify buttons
4. Shared: Create `notification_service.dart`
5. Trainer: Notifications screen + providers
6. Trainer: Home notification bell + badge
7. Trainer: Profile Features section
8. Trainer: Sign out confirmation dialog
9. Trainer: In & Out nav tab
10. Bug fix: Member notifications `body` field

---

## Validation

- Admin: `/reports` shows only analytics (no inactive members). `/reports/inactive` shows inactive members + trainers with Notify buttons.
- Admin: Notify button creates notification for target user and redirects to notifications page.
- Trainer: Home screen shows bell with unread badge. Profile shows Features section with Notifications. Sign out shows confirmation dialog. In & Out tab is visible and functional.
- Member: Notifications page correctly displays notification body text.

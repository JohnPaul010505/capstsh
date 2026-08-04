# Member / Trainer Auto-Generated Code System

> **Status:** Design approved
> **Date:** 2026-07-12

## Problem

Members and trainers need a short, readable, auto-generated identifier (`M001`, `T001`) for:
- Display on admin pages (members list, member detail, attendance, memberships, trainers)
- Mobile login using code + password instead of email + password

## Solution

Add a `code` column to the `profiles` table. Auto-generate on creation server-side. Mobile login uses a Supabase RPC to look up email by code, then authenticates with standard `signInWithPassword`.

## Database

**Migration:** `ALTER TABLE profiles ADD COLUMN code TEXT UNIQUE;`

**Format:** `{PREFIX}{SEQUENTIAL}`
- Member: `M001`, `M002`, ...
- Trainer: `T001`, `T002`, ...
- Sequential numbers are 3-digit zero-padded

**Supabase RPC Function:**
```sql
CREATE OR REPLACE FUNCTION lookup_user_by_code(p_code TEXT, p_role TEXT)
RETURNS TABLE(email TEXT, id UUID) SECURITY DEFINER AS $$
  SELECT email, id FROM profiles WHERE code = p_code AND role = p_role LIMIT 1;
$$ LANGUAGE sql;
```

## Code Generation (server-side)

In `POST /api/users` and `POST /api/enroll`, after validation but before DB insert:

1. Determine prefix: `'M'` if role is `'member'`, `'T'` if `'trainer'`
2. Query: `SELECT code FROM profiles WHERE code LIKE '${prefix}%' ORDER BY code DESC LIMIT 1`
3. Parse numeric part, increment by 1, pad to 3 digits
4. If no existing codes → start at `001`
5. Include `code` in the profile insert

## Type Changes

### `admin/src/types/index.ts` — Profile interface
Add: `code: string | null`

### `shared/lib/models/profile.dart` — Profile class
Add: `String? code` field, update `fromJson` / `toJson`

## Admin UI Changes

| Component | Change |
|---|---|
| `MemberTable.tsx` | Add "Code" column between Name and Email |
| `MemberDetailPage.tsx` | Show code prominently near name |
| `MembersListPage.tsx` | Pass code data from API (already works via `useMembers`) |
| `TrainersListPage.tsx` | Show code on trainer cards (below name) |
| `TrainerDetailPage.tsx` | Show code near name |
| `MembershipsPage.tsx` | Show member code alongside member name (if member data visible) |
| `AttendancePage.tsx` | Show code alongside member name |
| `QRPage.tsx` | After enrollment confirm, display the generated code |
| `EnrollmentForm.tsx` | No change — code generated server-side on confirm |

## Mobile Login Changes

### `auth_service.dart`
New method:
```dart
Future<Profile?> signInWithCode({
  required String code,
  required String password,
  required String role,
}) async {
  // 1. Lookup email via RPC
  final result = await _client.rpc('lookup_user_by_code', params: {
    'p_code': code,
    'p_role': role,
  });
  if (result.isEmpty) throw Exception('Invalid code or role');
  final email = result[0]['email'] as String;

  // 2. Standard auth with email
  final response = await _client.auth.signInWithPassword(email: email, password: password);
  if (response.user == null) throw Exception('Invalid credentials');

  // 3. Fetch and verify profile
  final profile = await _fetchProfile(response.user!.id);
  if (profile == null) throw Exception('Profile not found');
  if (profile.role != role) {
    await _client.auth.signOut();
    throw Exception('This account is not a $role account');
  }
  return profile;
}
```

### `auth_provider.dart`
New method `signInWithCode(code, password, role)` in `AuthNotifier`.

### `login_page.dart`
- Replace email text field with a code text field (shorter, uppercase, prefix styled)
- Keep password field and role selector (already exists)
- Submit calls `signInWithCode` instead of `signIn`
- No email login on mobile — code + password is the only method

## Backfill

One-time endpoint `POST /api/backfill-codes` or standalone script:
- Assigns codes to all existing members ordered by `created_at` (ascending)
- Assigns codes to all existing trainers ordered by `created_at` (ascending)
- Skipped profiles that already have a code

## Order of Implementation

1. Database migration + RPC function
2. Server-side code generation in `/api/users` and `/api/enroll`
3. Backfill existing users
4. TypeScript Profile update + admin UI changes
5. Dart Profile update + mobile auth changes
6. Mobile login page UI change

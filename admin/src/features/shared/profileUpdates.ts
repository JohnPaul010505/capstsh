/**
 * Shared profile-edit plumbing for the admin Member / Trainer detail pages.
 *
 * Why this exists: both pages used to spread their form straight into the
 * Supabase update, and `profiles.date_of_birth` is a `date` column. A member
 * with no birthday on file therefore sent `date_of_birth: ''`, Postgres
 * rejected the whole statement with
 *
 *   400 {"code":"22007","message":"invalid input syntax for type date: \"\""}
 *
 * and nothing was written - while the Save button just stopped spinning,
 * because the mutation had no error handler. Normalising here (once) keeps the
 * two pages from drifting apart again, and `describeError` turns a thrown
 * mutation into something an admin can read.
 */

/** Columns an admin may edit on a member from the detail page. */
export type MemberEditableFields = {
  full_name?: string
  email?: string
  phone?: string
  date_of_birth?: string
  gender?: string
  address?: string
  emergency_contact_name?: string
  emergency_contact_phone?: string
}

/** Columns an admin may edit on a trainer from the detail page. */
export type TrainerEditableFields = {
  full_name?: string
  email?: string
  phone?: string
  specialty?: string
}

/**
 * Trim every value, then map "the admin cleared this field" to `null`.
 *
 * For a `text` column `null` and `''` mean the same thing to the reader, but
 * for `date` only `null` is legal - so empty must never reach Postgres as ''.
 * Keys that are absent from the input are left absent: an update that carries
 * only the keys the form actually owns cannot clobber a column it never showed.
 */
export function normalizeProfileUpdates<T extends Record<string, unknown>>(
  updates: T,
): Partial<T> {
  const out: Record<string, unknown> = {}
  for (const [key, value] of Object.entries(updates)) {
    if (value === undefined) continue
    if (typeof value === 'string') {
      const trimmed = value.trim()
      if (trimmed === '') {
        out[key] = null
      } else {
        out[key] = trimmed
      }
      continue
    }
    out[key] = value
  }
  return out as Partial<T>
}

/**
 * Client-side guard so an obviously invalid edit never costs a round trip:
 * email is what the app logs in against, so it must at least look like one.
 */
export function validateProfileUpdates(
  updates: Record<string, unknown>,
): string | null {
  const email = updates.email
  if (typeof email === 'string' && email.trim() !== '' && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) {
    return 'Enter a valid email address.'
  }
  return null
}

/** PostgREST/Postgres error -> one readable sentence for an inline banner. */
export function describeError(err: unknown): string {
  if (err && typeof err === 'object') {
    const e = err as { message?: string; error_description?: string; code?: string }
    const message = e.message || e.error_description
    if (message) {
      // Postgres type errors name the column; that is the useful part.
      if (e.code === '22007' && /date/i.test(message)) {
        return 'That date is not valid — clear the field or pick a real date.'
      }
      return message
    }
  }
  if (err instanceof Error) return err.message
  return 'Could not save. Please try again.'
}

import { usePagedTable } from '@/lib/pagedTable'
import type { Profile } from '@/types'

/**
 * Rows per page for every admin list page: members, trainers, memberships and
 * the renewal queue.
 *
 * PINNED at 15, not measured. The page size is a promise to the reader - "15
 * members, the rest overleaf" - so it must not change when the window is
 * resized. What the window gets to decide is the ROW HEIGHT: the pages measure
 * it with `useFitRowHeight({ count: LIST_PAGE_SIZE })`, so fifteen rows always
 * fill the card exactly.
 *
 * The previous setup had this the other way round, which is the whole reason the
 * page scrolled: a hardcoded 25-row page inside a body that fits 14 rows. The
 * footer promised "1-25 of 987" above a list that visibly stopped at 14, the
 * header said "showing 14 per view" next to "25 on this page", and the extra
 * rows were reachable only through a scrollbar.
 */
export const LIST_PAGE_SIZE = 15

export interface PeopleListParams {
  /** 1-based. */
  page: number
  pageSize: number
  /** Matches full_name, code or email, so "M034" and "Dela" both work. */
  search?: string
  /** Inclusive 'YYYY-MM-DD' filter on the profile's join date. */
  from?: string
  to?: string
}

const PEOPLE_COLUMNS =
  'id, full_name, email, code, gender, phone, is_active, date_of_birth, created_at'

/**
 * Members, paged and filtered server-side.
 *
 * `select` is an explicit column list rather than `*`: the old hook fetched
 * every column of every row, which is a large payload for a table showing a
 * handful of fields.
 */
export function useMembersList({ page, pageSize, search, from, to }: PeopleListParams) {
  return usePagedTable<Profile>({
    table: 'profiles',
    select: PEOPLE_COLUMNS,
    // `code` is unique per role but is NULL for some rows, so `id` is kept as
    // the unique tiebreak that keeps pages disjoint.
    orderBy: [{ column: 'code', ascending: true }, { column: 'id', ascending: true }],
    page, pageSize, search,
    searchColumns: ['full_name', 'code', 'email'],
    dateColumn: 'created_at', from, to,
    // Without this the query returns EVERY profile: 1,077 rows including the
    // 89 trainers and the admin, and the members page lists them. The role
    // predicate is part of what the list *is*, not an optional extra filter.
    eq: { role: 'member' },
  })
}

/** Trainers: same shape as the members list, so Task 13 can share one table. */
export function useTrainersList({ page, pageSize, search, from, to }: PeopleListParams) {
  return usePagedTable<Profile>({
    table: 'profiles',
    select: `${PEOPLE_COLUMNS}, specialty, available_days`,
    orderBy: [{ column: 'code', ascending: true }, { column: 'id', ascending: true }],
    page, pageSize, search,
    searchColumns: ['full_name', 'code', 'email'],
    dateColumn: 'created_at', from, to,
    eq: { role: 'trainer' },
  })
}

const MEMBERSHIP_SELECT =
  'id, member_id, plan_name, price, start_date, end_date, status, created_at, ' +
  'profiles!memberships_member_id_fkey(full_name, email, code)'

export interface MembershipListParams extends PeopleListParams {
  planName?: string
  status?: string
}

/**
 * Memberships, paged with the member join and filtered by plan and start date.
 *
 * Search is deliberately NOT applied here: the member's name and code live on
 * the joined profile, not on the membership row, so they cannot participate in
 * the same PostgREST `or()` filter. Use `useMembershipSearchIds` to resolve the
 * term to member ids first, then pass the result as `memberIds`.
 */
export function useMembershipsList({
  page, pageSize, from, to, planName, status, memberIds,
}: MembershipListParams & { memberIds?: string[] }) {
  return usePagedTable<any>({
    table: 'memberships',
    select: MEMBERSHIP_SELECT,
    orderBy: [{ column: 'start_date', ascending: false }, { column: 'id', ascending: false }],
    page, pageSize,
    dateColumn: 'start_date', from, to,
    eq: { plan_name: planName, status },
    inFilter: memberIds === undefined ? undefined : { member_id: memberIds },
  })
}

/**
 * Resolve a search term to the member ids whose name or code matches, so a
 * membership list can be searched by member without a join-side filter.
 * Returns undefined when the term is empty, meaning "do not filter by member".
 */
export function useMembershipSearchIds(search?: string) {
  return usePagedTable<{ id: string }>({
    table: 'profiles',
    select: 'id',
    orderBy: [{ column: 'id', ascending: true }],
    page: 1,
    // The cap is a backstop against a pathological term; a search matching
    // everyone is better served by not filtering at all.
    pageSize: 1000,
    search,
    searchColumns: ['full_name', 'code', 'email'],
    // Members only. These ids feed the memberships `in` filter, so a term that
    // matched a trainer would list that trainer's (empty) membership history.
    eq: { role: 'member' },
    enabled: !!search?.trim(),
  })
}

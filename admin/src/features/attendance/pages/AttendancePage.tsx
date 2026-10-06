import { useState, useEffect } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { useAttendance } from '../hooks/useAttendance'
import { Plus, LogOut, LogIn, X, Clock } from 'lucide-react'
import RecordsTable, { type RecordsColumn } from '@/components/RecordsTable'
import ListToolbar from '@/components/ListToolbar'
import { formatRangeLabel, MONTH_PRESETS, todayRange, type Range } from '@/features/dashboard/lib/dateRange'

// PostgREST REJECTS unknown columns ('Could not find the ... column'), so
// the manual check-in insert below retries without entry_method when
// migration 0033 has not been applied yet.
async function insertCheckin(payload: Record<string, unknown>) {
  const first = await supabase.from('attendance').insert(payload)
  if (!first.error) return first
  if (/entry_method|column/i.test(first.error.message) && 'entry_method' in payload) {
    const { entry_method: _dropped, ...rest } = payload
    void _dropped
    return supabase.from('attendance').insert(rest)
  }
  return first
}

export default function AttendancePage() {
  // check_in_date is written by the mobile app in the DEVICE-LOCAL day, so the
  // admin default must be local too — toISOString() is UTC (PH local and UTC
  // differ from midnight to 8 AM), which silently hid same-day scans.
  const localToday = () => {
    const d = new Date()
    const pad = (n: number) => String(n).padStart(2, '0')
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
  }
  const today = localToday()
  // The window of check-ins being read. Opened on today, which is what this page
  // has always opened on - a one-day range, and the picker's label collapses a
  // single day to one date rather than printing it twice.
  const [range, setRange] = useState<Range>(() => todayRange())
  const [category, setCategory] = useState<'member' | 'trainer'>('member')
  const [showModal, setShowModal] = useState(false)
  const [drawerCategory, setDrawerCategory] = useState<'member' | 'trainer'>('member')
  const [search, setSearch] = useState('')
  // A SECOND term for the table below, deliberately not shared with the drawer
  // search above. The drawer is a one-off picker that filters people in memory;
  // the table filters the day's check-ins. One variable for both would clear
  // the picker's box the moment someone typed in the table, and filter the
  // table by whatever was last typed into a modal.
  const [tableSearch, setTableSearch] = useState('')

  useEffect(() => {
    if (!showModal) return
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setShowModal(false)
    }
    document.addEventListener('keydown', onKeyDown)
    return () => document.removeEventListener('keydown', onKeyDown)
  }, [showModal])
  const { data: sessions, isLoading, isFetching, isError, error, refetch } = useAttendance(range, category)
  const queryClient = useQueryClient()

  // The table used to render "No attendance records" for BOTH an empty day and a
  // FAILED request, because the query's error was never read: on any error
  // `sessions` stayed undefined, `isLoading` went false, and the empty row was
  // the only thing on screen. A 500 or an expired session was indistinguishable
  // from a gym that nobody visited, which is how a whole broken day reader went
  // unnoticed. The count and the closed-on-Sundays note below make the remaining
  // "genuinely nothing here" case say so out loud.
  const rowCount = sessions?.length ?? 0
  // The dataset models a Mon-Sat gym (see scripts/seed/lib/attendance.mjs), so a
  // Sunday is legitimately empty and a weekday with no rows is worth flagging.
  // Both of those are claims about ONE day, though, so they only hold when the
  // window is a single day: a month containing one Sunday is not "closed", and
  // a range with no rows is a different statement from a day with no rows.
  const isSingleDay = range.start === range.end
  const isSunday = isSingleDay && new Date(`${range.start}T00:00:00`).getDay() === 0
  // One day gets the long form ("Monday, October 5, 2026") because that is what
  // the page always said; a window gets the picker's own label.
  const longDate = isSingleDay
    ? new Date(`${range.start}T00:00:00`).toLocaleDateString(undefined, {
      weekday: 'long', month: 'long', day: 'numeric', year: 'numeric',
    })
    : formatRangeLabel(range)
  const roleLabel = category === 'trainer' ? 'Trainers' : 'Members'

  const { data: people, isLoading: peopleLoading } = useQuery({
    queryKey: ['attendance-people', drawerCategory],
    enabled: showModal,
    queryFn: async () => {
      const { data } = await supabase
        .from('profiles')
        .select('id, full_name, email, code')
        .eq('role', drawerCategory === 'trainer' ? 'trainer' : 'member')
        .order('full_name')
      return data ?? []
    },
  })

  const filteredPeople = (people ?? []).filter(p => {
    const q = search.trim().toLowerCase()
    if (!q) return true
    return [p.full_name, p.email, p.code].some(v => v?.toLowerCase().includes(q))
  })

  const checkinMutation = useMutation({
    mutationFn: async (memberId: string) => {
      const { count } = await supabase
        .from('attendance')
        .select('id', { count: 'exact', head: true })
        .eq('member_id', memberId)
        .eq('check_in_date', today)
        .is('check_out_time', null)
      if (count !== null && count > 0) throw new Error('Already checked in')
      const { error } = await insertCheckin({
        member_id: memberId,
        check_in_time: new Date().toISOString(),
        check_in_date: today,
        expires_at: new Date(Date.now() + 12 * 3600000).toISOString(),
        // Labels the row as an admin manual check-in; migration 0033 adds
        // this column (see supabase/migrations). insertCheckin drops it if
        // 0033 has not been applied yet.
        entry_method: 'manual',
      })
      if (error) throw error
    },
    onSuccess: () => {
      setCategory(drawerCategory)
      setShowModal(false)
      queryClient.invalidateQueries({ queryKey: ['attendance'] })
    },
  })

  const checkoutMutation = useMutation({
    mutationFn: async (memberId: string) => {
      const { error } = await supabase
        .from('attendance')
        .update({ check_out_time: new Date().toISOString() })
        .eq('member_id', memberId)
        .eq('check_in_date', today)
        .is('check_out_time', null)
      if (error) throw error
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['attendance'] })
    },
  })

  const rows = sessions ?? []

  // `leading-5` (20px) on every cell is what keeps a row at the 44px
  // `RecordsTable` budgets. The Check Out button is the tight one: at `py-1` it
  // renders 24px of content and every row becomes 48px, so the measured page
  // size is wrong by 4px a row and the body scrolls with nothing to explain it.
  const columns: RecordsColumn<any>[] = [
    {
      key: 'name',
      header: 'Name',
      render: s => (
        <span className="font-medium text-fg-strong leading-5">
          {s.profiles?.full_name}
        </span>
      ),
    },
    {
      /* The code used to ride inline after the name in purple, where it read
         as part of the name rather than as an ID. It gets a column of its own
         here, in the same neutral white as the name - so a column of IDs can
         be scanned independently, and nothing in the row is purple text.

         NO `leading-5` here, unlike the other cells: a 12px `text-xs` line box
         under a 20px one makes the monospace font's ascent set the row height,
         and the row grows to 47px against the 44px `RecordsTable` budgets. At
         `text-xs`'s own 16px the shared line box stays at the cell's 20px. */
      key: 'code',
      header: 'Member ID',
      render: s => (
        <span className="text-xs font-mono text-fg-strong">{s.profiles?.code ?? '—'}</span>
      ),
    },
    {
      key: 'role',
      header: 'Role',
      render: s => <span className="text-fg capitalize leading-5">{s.profiles?.role || 'member'}</span>,
    },
    {
      key: 'checkin',
      header: 'Check-in',
      render: s => (
        <span className="inline-flex items-center gap-1 text-accent-green leading-5">
          <LogIn className="w-3 h-3" />
          {new Date(s.check_in_time).toLocaleTimeString()}
        </span>
      ),
    },
    {
      key: 'checkout',
      header: 'Check-out',
      render: s => (s.check_out_time ? (
        <span className="inline-flex items-center gap-1 text-fg leading-5">
          <LogOut className="w-3 h-3" />
          {new Date(s.check_out_time).toLocaleTimeString()}
        </span>
      ) : (
        <span className="inline-flex items-center gap-1 text-accent-amber text-xs font-medium leading-5">
          <Clock className="w-3 h-3" />
          Until {new Date(s.expires_at).toLocaleTimeString()}
        </span>
      )),
    },
    {
      key: 'actions',
      header: 'Actions',
      align: 'right',
      render: s => (!s.check_out_time ? (
        <button
          onClick={() => checkoutMutation.mutate(s.member_id)}
          disabled={checkoutMutation.isPending}
          className="px-3 py-0.5 text-xs leading-4 bg-[#F59E0B]/15 text-accent-amber rounded-lg hover:bg-[#F59E0B]/25 disabled:opacity-50 whitespace-nowrap"
        >
          Check Out
        </button>
      ) : null),
    },
  ]

  return (
    /* `h-full min-h-0 flex flex-col` is the shell the Reports and QR pages
       use, and for the same reason: `main` is `flex-1 overflow-hidden`, so this
       page used to be an auto-height `space-y-3` stack that simply ran off the
       bottom of the viewport with no scrollbar to say so. The day's check-ins
       were therefore reachable only as far as the window happened to be. */
    <div className="h-full min-h-0 flex flex-col gap-3">
      <div className="flex items-center justify-between gap-3 shrink-0">
        {/* This slot was an empty <div />, which is why the page could not say
            how much it had actually found. */}
        <div className="min-w-0">
          <p className="text-sm text-fg-strong truncate">
            {isLoading ? 'Loading…' : `${rowCount} ${rowCount === 1 ? 'check-in' : 'check-ins'}`}
            <span className="text-fg-muted font-normal"> · {roleLabel} · {longDate}</span>
          </p>
          {!isLoading && !isError && rowCount === 0 && (
            <p className="text-xs text-fg-muted truncate">
              {isSunday
                ? 'The gym is closed on Sundays, so no check-ins are expected.'
                : isSingleDay
                  ? 'No one checked in on this day.'
                  : 'No one checked in on any day in this range.'}
            </p>
          )}
        </div>
      </div>

      {/*
        ONE ROW: who you are looking at (Members / Trainers) pinned left, and the
        window plus the action collected on the right - which puts the calendar
        immediately beside "+ Check In".

        The picker used to be a `ListToolbar` row of its own ABOVE these tabs, so
        the control that defines the window and the button that acts inside it
        sat on different lines and read as two unrelated controls. `ListToolbar`
        already owns both halves - a `left` slot and a right-aligned cluster
        holding the date filter followed by the action button - so all three now
        render through it and there is one row where there used to be two.

        `MONTH_PRESETS` is the month-oriented set - Last month / This month /
        Today / All time - because a rolling 7-day chip is the wrong shape of
        question here. This picker replaces a bare `<input type=date>` that could
        only ever name one day: an admin reading a gym sheet wants "last month",
        not "pick Tuesday".
      */}
      <ListToolbar
        left={
          <div className="flex gap-2">
            <button
              onClick={() => setCategory('member')}
              className={`px-4 py-1.5 text-sm rounded-lg font-medium transition-colors ${
                category === 'member'
                  ? 'bg-[#7C3AED] text-white'
                  : 'bg-overlay-8 text-fg hover:bg-overlay-10'
              }`}
            >
              Members
            </button>
            <button
              onClick={() => setCategory('trainer')}
              className={`px-4 py-1.5 text-sm rounded-lg font-medium transition-colors ${
                category === 'trainer'
                  ? 'bg-[#7C3AED] text-white'
                  : 'bg-overlay-8 text-fg hover:bg-overlay-10'
              }`}
            >
              Trainers
            </button>
          </div>
        }
        range={range}
        onRangeChange={setRange}
        presets={MONTH_PRESETS}
      >
        <button
          onClick={() => { setDrawerCategory(category); setSearch(''); setShowModal(true) }}
          className="flex items-center gap-1 px-3 py-1.5 text-sm bg-[#7C3AED] text-white rounded-lg hover:bg-[#6D28D9]"
        >
          <Plus className="w-4 h-4" /> Check In
        </button>
      </ListToolbar>

      {isError ? (
        /* A failure must never wear the empty state. The old table reported
           "No attendance records" for a dead request, so a 500 looked exactly
           like a quiet day. This says what broke and offers the one action that
           can help. */
        <div className="glass-card rounded-xl px-5 py-10 text-center">
          <p className="text-sm font-medium text-fg-strong">Could not load attendance for this day</p>
          <p className="text-xs text-fg-muted mt-1 break-words">
            {error instanceof Error ? error.message : 'Unknown error'}
          </p>
          <button
            onClick={() => { void refetch() }}
            disabled={isFetching}
            className="mt-4 px-4 py-2 text-sm bg-[#7C3AED] text-white rounded-lg hover:bg-[#6D28D9] disabled:opacity-50"
          >
            {isFetching ? 'Retrying…' : 'Retry'}
          </button>
        </div>
      ) : (
        <RecordsTable
          key={category}
          title={roleLabel}
          columns={columns}
          rows={rows}
          rowKey={s => s.id}
          searchFields={s => [s.profiles?.full_name, s.profiles?.code, s.profiles?.role]}
          searchPlaceholder="Search by name or ID…"
          searchValue={tableSearch}
          onSearchChange={setTableSearch}
          isLoading={isLoading}
          emptyMessage={rows.length === 0
            ? (isSunday
              ? 'Gym closed on Sundays - no check-ins recorded'
              : isSingleDay
                ? `No ${category === 'trainer' ? 'trainer' : 'member'} check-ins on this day`
                : `No ${category === 'trainer' ? 'trainer' : 'member'} check-ins in this range`)
            : 'No check-ins match this search'}
        />
      )}

      {showModal && (
        <div className="fixed inset-0 bg-black/60 z-50" onClick={() => setShowModal(false)}>
          <div className="glass-card slide-in-right fixed right-0 top-0 h-full w-full max-w-md flex flex-col rounded-l-2xl border-l border-line" onClick={e => e.stopPropagation()}>
            <div className="px-6 py-4 border-b border-line">
              <div className="flex items-center justify-between">
                <h2 className="text-lg font-semibold text-fg-strong">Select {drawerCategory === 'trainer' ? 'Trainer' : 'Member'}</h2>
                <button onClick={() => setShowModal(false)} className="text-fg-muted hover:text-fg">
                  <X className="w-5 h-5" />
                </button>
              </div>
              <div className="flex gap-2 mt-3">
                <button
                  onClick={() => setDrawerCategory('member')}
                  className={`px-4 py-1.5 text-sm rounded-lg font-medium transition-colors ${
                    drawerCategory === 'member'
                      ? 'bg-[#7C3AED] text-white'
                      : 'bg-overlay-8 text-fg hover:bg-overlay-10'
                  }`}
                >
                  Member
                </button>
                <button
                  onClick={() => setDrawerCategory('trainer')}
                  className={`px-4 py-1.5 text-sm rounded-lg font-medium transition-colors ${
                    drawerCategory === 'trainer'
                      ? 'bg-[#7C3AED] text-white'
                      : 'bg-overlay-8 text-fg hover:bg-overlay-10'
                  }`}
                >
                  Trainer
                </button>
              </div>
            </div>
            <div className="px-6 py-3 border-b border-line">
              <input
                type="text"
                value={search}
                onChange={e => setSearch(e.target.value)}
                placeholder="Search by name, email, or code..."
                className="w-full px-3 py-2 bg-overlay-8 border border-line rounded-lg text-sm text-fg-strong focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50 focus:border-[#7C3AED] placeholder:text-fg-muted"
              />
            </div>
            <div className="px-6 py-4 flex-1 overflow-y-auto space-y-2">
              {peopleLoading ? (
                <p className="text-fg-muted text-center py-8">Loading...</p>
              ) : filteredPeople.length === 0 ? (
                <p className="text-fg-muted text-center py-8">
                  {search
                    ? 'No results found'
                    : drawerCategory === 'trainer'
                      ? 'No trainers found'
                      : 'No members found'}
                </p>
              ) : (
                filteredPeople.map(p => (
                  <button
                    key={p.id}
                    onClick={() => checkinMutation.mutate(p.id)}
                    disabled={checkinMutation.isPending}
                    className="w-full flex items-center justify-between p-3 rounded-lg border border-line hover:bg-[#7C3AED]/10 cursor-pointer disabled:opacity-50 text-left transition-colors"
                  >
                    <div>
                      <p className="font-medium text-sm text-fg-strong">{p.full_name}</p>
                      <p className="text-xs text-fg-muted">{p.code} — {p.email}</p>
                    </div>
                    <LogIn className="w-4 h-4 text-accent-green shrink-0" />
                  </button>
                ))
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

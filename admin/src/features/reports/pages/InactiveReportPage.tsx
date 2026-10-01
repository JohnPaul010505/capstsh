import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import StatusBadge from '@/components/StatusBadge'
import RecordsTable, { type RecordsColumn } from '@/components/RecordsTable'

const DAY = 24 * 60 * 60 * 1000

/** One row of either list; `daysInactive` is the 999 sentinel for "never". */
interface InactiveRow {
  userId: string
  name: string
  /** May be missing on a profile that has no code - printed as an em dash. */
  code?: string | null
  lastCheckIn: string | null
  daysInactive: number
}

/**
 * The two lists as views, the way QR Pending/Confirmed are.
 *
 * They were tabs inside the card's own header row, wrapped around a hand-rolled
 * `<table>` in a `max-h-[420px]` scroller. That gave the page the one thing
 * every list page here had already thrown off: a fixed inner scrollbar with no
 * page of numbers, no `#` column, no search, and no way to tell which of the
 * 60 rows you were looking at. It also left the page itself auto-height under a
 * `main` that is `overflow-hidden`, so anything past 420px was unreachable.
 *
 * Both queries now run on mount rather than one per selected tab. That is the
 * price of counting in the tab labels ("Inactive Members (60)"), the same thing
 * the QR page pays by fetching its enrolments once instead of per view.
 */
const SUB_TABS = [
  { id: 'members', label: 'Inactive Members', noun: 'members', idHeader: 'Member' },
  { id: 'trainers', label: 'Inactive Trainers', noun: 'trainers', idHeader: 'Trainer' },
] as const

type SubTab = (typeof SUB_TABS)[number]['id']

export default function InactiveReportPage() {
  const [subTab, setSubTab] = useState<SubTab>('members')
  const [notifiedUserIds, setNotifiedUserIds] = useState<Set<string>>(new Set())
  // One term per page, cleared on the tab switch. Sharing it would silently
  // pre-filter the other list, which is exactly what QR's two search boxes
  // exist to avoid.
  const [search, setSearch] = useState('')

  const { data: inactiveMembers, isLoading: membersLoading } = useQuery({
    queryKey: ['report-inactive-members'],
    queryFn: async () => {
      const sevenDaysAgo = new Date(Date.now() - 7 * DAY).toISOString().split('T')[0]
      const [membershipsRes, attendanceRes] = await Promise.all([
        supabase
          .from('memberships')
          .select('member_id, plan_name')
          .eq('plan_name', 'Daily')
          .eq('status', 'active'),
        supabase
          .from('attendance')
          .select('member_id, check_in_date')
          .gte('check_in_date', sevenDaysAgo)
          .order('check_in_date', { ascending: false }),
      ])

      const lastCheckIn: Record<string, string> = {}
      attendanceRes.data?.forEach(a => {
        if (!lastCheckIn[a.member_id] || a.check_in_date > lastCheckIn[a.member_id]) {
          lastCheckIn[a.member_id] = a.check_in_date
        }
      })

      const memberIds = membershipsRes.data?.map(m => m.member_id) ?? []
      let profileMap: Record<string, { full_name: string; code: string }> = {}
      if (memberIds.length > 0) {
        const { data: profiles } = await supabase
          .from('profiles')
          .select('id, full_name, code')
          .in('id', memberIds)
        profiles?.forEach(p => { profileMap[p.id] = p })
      }

      const now = new Date()
      now.setHours(0, 0, 0, 0)
      return (membershipsRes.data ?? [])
        .map(m => {
          const last = lastCheckIn[m.member_id]
          const daysInactive = last
            ? Math.floor((now.getTime() - new Date(last).getTime()) / DAY)
            : 999
          return {
            userId: m.member_id,
            name: profileMap[m.member_id]?.full_name ?? 'Unknown',
            code: profileMap[m.member_id]?.code,
            lastCheckIn: last ?? null,
            daysInactive,
          }
        })
        .filter(r => r.daysInactive >= 7)
        .sort((a, b) => b.daysInactive - a.daysInactive)
    },
  })

  const { data: inactiveTrainers, isLoading: trainersLoading } = useQuery({
    queryKey: ['report-inactive-trainers'],
    queryFn: async () => {
      const sevenDaysAgo = new Date(Date.now() - 7 * DAY).toISOString().split('T')[0]
      const { data: trainers } = await supabase
        .from('profiles')
        .select('id, full_name, code')
        .eq('role', 'trainer')

      const trainerIds = (trainers ?? []).map(t => t.id)
      let attendanceData: { member_id: string; check_in_date: string }[] = []
      if (trainerIds.length > 0) {
        const { data } = await supabase
          .from('attendance')
          .select('member_id, check_in_date')
          .in('member_id', trainerIds)
          .gte('check_in_date', sevenDaysAgo)
          .order('check_in_date', { ascending: false })
        attendanceData = data ?? []
      }

      const lastCheckIn: Record<string, string> = {}
      attendanceData.forEach(a => {
        if (!lastCheckIn[a.member_id] || a.check_in_date > lastCheckIn[a.member_id]) {
          lastCheckIn[a.member_id] = a.check_in_date
        }
      })

      const profileMap: Record<string, { full_name: string; code: string }> = {}
      trainers?.forEach(t => { profileMap[t.id] = t })

      const now = new Date()
      now.setHours(0, 0, 0, 0)
      return (trainers ?? [])
        .map(t => {
          const last = lastCheckIn[t.id]
          const daysInactive = last
            ? Math.floor((now.getTime() - new Date(last).getTime()) / DAY)
            : 999
          return {
            userId: t.id,
            name: profileMap[t.id]?.full_name ?? 'Unknown',
            code: profileMap[t.id]?.code,
            lastCheckIn: last ?? null,
            daysInactive,
          }
        })
        .filter(r => r.daysInactive >= 7)
        .sort((a, b) => b.daysInactive - a.daysInactive)
    },
  })

  const handleNotify = async (userId: string, daysInactive: number) => {
    try {
      const res = await fetch('/api/notifications/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId,
          title: 'Stay on Track!',
          body: `You've been inactive for a while in ${daysInactive} days. Let's get moving again!`,
        }),
      })
      if (!res.ok) {
        const err = await res.json().catch(() => ({}))
        throw new Error(err.error || 'Failed to send notification')
      }
      setNotifiedUserIds(prev => new Set(prev).add(userId))
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to send notification')
    }
  }

  const active = SUB_TABS.find(t => t.id === subTab)!
  const data = subTab === 'members' ? inactiveMembers : inactiveTrainers
  const isLoading = subTab === 'members' ? membersLoading : trainersLoading
  const rows = data ?? []

  // The member code moves OUT of the name cell and into a column of its own.
  // `RecordsTable` measures its rows at a fixed 44px, which is what makes the
  // page size exact and the pager honest; the old two-line name cell quietly
  // broke that measurement and put the code in the second line of every row.
  const columns: RecordsColumn<InactiveRow>[] = [
    {
      key: 'name',
      header: active.idHeader,
      render: r => <span className="font-medium text-fg-strong">{r.name}</span>,
    },
    {
      key: 'code',
      header: 'Member ID',
      render: r => <span className="font-mono text-[12px] text-fg-muted">{r.code ?? '—'}</span>,
    },
    {
      key: 'last',
      header: 'Last Check-in',
      render: r => r.lastCheckIn
        ? <span className="text-fg-strong whitespace-nowrap">{new Date(r.lastCheckIn).toLocaleDateString()}</span>
        : <span className="text-fg-faint">Never</span>,
    },
    {
      key: 'days',
      header: 'Days Inactive',
      render: r => <span className="text-accent-amber font-medium whitespace-nowrap">{r.daysInactive} days</span>,
    },
    {
      key: 'status',
      header: 'Status',
      render: () => <StatusBadge status="inactive" />,
    },
    {
      key: 'action',
      header: 'Action',
      align: 'right',
      render: r => (
        <button
          type="button"
          onClick={() => handleNotify(r.userId, r.daysInactive)}
          disabled={notifiedUserIds.has(r.userId)}
          className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
            notifiedUserIds.has(r.userId)
              ? 'bg-overlay-8 text-fg-muted border border-line cursor-not-allowed'
              : 'bg-[#7C3AED] text-white hover:bg-[#6D28D9] cursor-pointer'
          }`}
        >
          {notifiedUserIds.has(r.userId) ? 'Sent' : 'Notify'}
        </button>
      ),
    },
  ]

  return (
    /*
      A full-height flex column, exactly like QRPage. `main` is
      `flex-1 overflow-hidden`, so an auto-height page simply runs off the
      bottom of the viewport with no scrollbar to say so; `flex-1 min-h-0` on the
      tabpanel is what hands the table a real height budget for `useFitRows` to
      measure a whole page of rows from.
    */
    <div className="h-full min-h-0 flex flex-col gap-3">
      <div role="tablist" aria-label="Inactive report sections" className="flex flex-wrap items-center gap-1.5 shrink-0">
        {SUB_TABS.map(t => {
          const count = t.id === 'members' ? inactiveMembers?.length : inactiveTrainers?.length
          return (
            <button
              key={t.id}
              type="button"
              role="tab"
              aria-selected={subTab === t.id}
              onClick={() => { setSubTab(t.id); setSearch('') }}
              className={`px-3.5 py-2 rounded-xl text-sm transition-colors cursor-pointer ${
                subTab === t.id
                  ? 'bg-[#7C3AED] text-white'
                  : 'bg-overlay-8 border border-line text-fg-muted hover:text-fg-strong hover:border-[#7C3AED]/40'
              }`}
            >
              {t.label}{count === undefined ? '' : ` (${count})`}
            </button>
          )
        })}
      </div>

      <div role="tabpanel" aria-label={active.label} className="flex-1 min-h-0 min-w-0 flex">
        {/* `key` resets the table's own page index when the view changes, so page
            4 of the members never opens as page 4 of a shorter trainer list. */}
        <RecordsTable
          key={subTab}
          title={active.label}
          columns={columns}
          rows={rows}
          rowKey={r => r.userId}
          searchFields={r => [r.name, r.code]}
          searchPlaceholder={`Search by ${active.noun === 'members' ? 'member' : 'trainer'} name or ID…`}
          searchValue={search}
          onSearchChange={setSearch}
          isLoading={isLoading}
          emptyMessage={rows.length === 0
            ? `No inactive ${active.noun}`
            : `No inactive ${active.noun} match this search`}
        />
      </div>
    </div>
  )
}

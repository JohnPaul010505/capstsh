import { useEffect, useMemo, useRef, useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { useCreateMembership, useDeleteMembership, useAttendanceLast7Days, useRenewalRequests } from '../hooks/useMemberships'
import { useMembershipsList, useMembershipSearchIds, LIST_PAGE_SIZE } from '@/lib/listHooks'
import { useResetPageOnChange } from '@/lib/pagedTable'
import { useFitRowHeight } from '@/hooks/useFitRows'
import PeopleTable, { peopleCells, type PeopleColumn } from '@/components/PeopleTable'
import ListToolbar from '@/components/ListToolbar'
import PaginationFooter from '@/components/PaginationFooter'
import StatusBadge from '@/components/StatusBadge'
import type { Membership, MembershipRenewalRequest } from '@/types'
import { Plus, X, ChevronDown, CheckCircle, XCircle } from 'lucide-react'

const PLANS = {
  daily: { label: 'Daily', price: 60, days: 1 },
  monthly: { label: 'Monthly', price: 1800, days: 30 },
} as const

/**
 * NOTE: this page used to carry three hardcoded "demo" renewal requests
 * (MOCK_PENDING_RENEWALS) plus a lookup that tried to match their @mock.fit
 * emails to real profiles so the panel was never empty. The database is seeded
 * with real pending requests now, so the mocks are gone: they made the panel
 * look populated while the approve/decline buttons operated on rows that did
 * not exist.
 */
function todayStr() {
  return new Date().toISOString().split('T')[0]
}

function addDays(date: string, days: number) {
  const d = new Date(date)
  d.setDate(d.getDate() + days)
  return d.toISOString().split('T')[0]
}

/** End of day (23:59:59) for a YYYY-MM-DD date string — matches the mobile app's
 *  `Membership.isExpired` semantics, so the admin and mobile panels agree. */
function endOfDay(date: string) {
  const d = new Date(date)
  d.setHours(23, 59, 59, 999)
  return d
}

function computeStatus(m: Membership, recentAttendance: Set<string>) {
  if (endOfDay(m.end_date).getTime() < Date.now()) return 'expired'
  const startDate = new Date(m.start_date)
  const daysSinceStart = Math.floor((Date.now() - startDate.getTime()) / 86400000)
  if (daysSinceStart < 7) return 'active'
  if (!recentAttendance.has(m.member_id)) return 'inactive'
  return 'active'
}

/**
 * Whether this membership can carry the renewal affordances.
 *
 * `plan_name` is free text in the database (the seed and the create drawer both
 * write 'Daily'/'Monthly'), so the test is on 'daily' rather than on 'Monthly':
 * anything that is not a daily plan stays renewable, so a custom plan an admin
 * typed by hand does not silently lose its Renew button. A daily pass is
 * bought per day, so there is nothing to renew.
 */
function canRenew(m: Membership) {
  return (m.plan_name ?? '').trim().toLowerCase() !== 'daily'
}

type MemberOption = { id: string; full_name: string; email: string; code: string | null }

/** Glass-styled custom dropdown (native <select> popups render white and can't be themed). */
function MemberSelect({ members, value, onChange }: { members: MemberOption[] | undefined; value: string; onChange: (id: string) => void }) {
  const [open, setOpen] = useState(false)
  const [search, setSearch] = useState('')
  const rootRef = useRef<HTMLDivElement>(null)
  const selected = members?.find(m => m.id === value)

  useEffect(() => {
    if (!open) return
    const onPointerDown = (e: MouseEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) setOpen(false)
    }
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false)
    }
    document.addEventListener('mousedown', onPointerDown)
    document.addEventListener('keydown', onKeyDown)
    return () => {
      document.removeEventListener('mousedown', onPointerDown)
      document.removeEventListener('keydown', onKeyDown)
    }
  }, [open])

  // Type-to-filter by name, code or email — a searchable combobox instead of
  // scrolling the whole roster.
  const term = search.trim().toLowerCase()
  const filtered = (members ?? []).filter(m =>
    term === '' ||
    m.full_name?.toLowerCase().includes(term) ||
    m.code?.toLowerCase().includes(term) ||
    m.email?.toLowerCase().includes(term),
  )

  return (
    <div ref={rootRef} className="relative">
      <button
        type="button"
        onClick={() => setOpen(o => !o)}
        className="w-full flex items-center justify-between gap-2 px-3 py-2 bg-overlay-8 border border-line rounded-lg text-sm text-left cursor-pointer hover:border-[#7C3AED]/50 focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50 transition-colors"
      >
        <span className={`truncate ${selected ? 'text-fg-strong' : 'text-fg-muted'}`}>
          {selected ? `${selected.full_name} (${selected.code ?? '—'}) — ${selected.email}` : 'Select member...'}
        </span>
        <ChevronDown className={`w-4 h-4 text-fg-muted shrink-0 transition-transform ${open ? 'rotate-180' : ''}`} />
      </button>
      {open && (
        <div className="glass-card absolute left-0 right-0 top-full mt-1 z-20 max-h-56 overflow-y-auto rounded-lg border border-line py-1 shadow-xl">
          <div className="px-2 pb-1 sticky top-0">
            <input
              type="text"
              autoFocus
              placeholder="Search name, code or email…"
              value={search}
              onChange={e => setSearch(e.target.value)}
              className="w-full px-2 py-1.5 text-sm bg-page-deep border border-line rounded-lg text-fg-strong placeholder-fg-muted focus:outline-none focus:border-[#7C3AED]"
            />
          </div>
          <button
            type="button"
            onClick={() => { onChange(''); setOpen(false) }}
            className={`w-full text-left px-3 py-2 text-sm cursor-pointer transition-colors ${
              !value ? 'bg-[#7C3AED]/15 text-accent-purple' : 'text-fg-muted hover:bg-[#7C3AED]/10 hover:text-fg-strong'
            }`}
          >
            Select member...
          </button>
          {filtered.map(m => (
            <button
              key={m.id}
              type="button"
              onClick={() => { onChange(m.id); setOpen(false) }}
              className={`w-full text-left px-3 py-2 text-sm cursor-pointer transition-colors ${
                m.id === value ? 'bg-[#7C3AED]/15 text-accent-purple' : 'text-fg hover:bg-[#7C3AED]/10 hover:text-fg-strong'
              }`}
            >
              {m.full_name} ({m.code ?? '—'}) — {m.email}
            </button>
          ))}
          {filtered.length === 0 && (
            <div className="text-center py-3 text-fg-muted text-sm">No members match “{search}”</div>
          )}
        </div>
      )}
    </div>
  )
}

export default function MembershipsPage() {
  const [activeTab, setActiveTab] = useState<'daily' | 'monthly' | 'renewal'>('daily')
  const [showModal, setShowModal] = useState(false)
  const [form, setForm] = useState({
    member_id: '',
    plan_type: 'daily' as 'daily' | 'monthly',
    months: 1,
    custom: false,
    end_date: addDays(todayStr(), 30),
    price: String(PLANS.daily.price),
    start_date: todayStr(),
  })
  const [saving, setSaving] = useState(false)
  const [planError, setPlanError] = useState('')

  // List controls. The search box is shared by all three tabs and sits above
  // them, so the term is one piece of state: Daily/Monthly resolve it to member
  // ids server-side, the Renewal queue filters its pending rows in memory.
  //
  // There is no start-date filter on this page. It was a second, redundant way
  // to ask a question the tabs already answer, and it cost a row of chrome
  // above a table that has to fit fifteen rows without a scrollbar. The list
  // hook still accepts `from`/`to`; nothing here uses them.
  const [membershipPage, setMembershipPage] = useState(1)
  const [renewPage, setRenewPage] = useState(1)
  const [membershipSearch, setMembershipSearch] = useState('')

  // The member's name and code live on the JOINED profile, so they cannot take
  // part in the same PostgREST `or()` as a column on the membership row. The
  // term is therefore resolved to member ids first, and those ids go in as an
  // `in` filter. Declared before the membership query because it feeds it.
  const { rows: searchIdRows } = useMembershipSearchIds(membershipSearch)
  const membershipSearchIds = useMemo(
    () => (membershipSearch.trim() ? searchIdRows.map(r => r.id) : undefined),
    [membershipSearch, searchIdRows],
  )

  const planTab = activeTab === 'renewal' ? 'daily' : activeTab
  // Paged + filtered server-side. The previous useMemberships(plan) fetched
  // every row of the plan - 1,800 for Monthly - and rendered them in one block
  // with a 420px cap, so most of the plan sat unreachable behind an inner
  // scrollbar.
  const { rows: memberships, isLoading, total: membershipTotal, pageCount: membershipPages } =
    useMembershipsList({
      page: membershipPage,
      pageSize: LIST_PAGE_SIZE,
      planName: PLANS[planTab].label,
      memberIds: membershipSearchIds,
    })
  useResetPageOnChange(setMembershipPage, membershipSearch)
  const { data: recentAttendance } = useAttendanceLast7Days()
  const { data: members } = useQuery({
    queryKey: ['members-simple'],
    queryFn: async () => {
      const { data } = await supabase.from('profiles').select('id, full_name, email, code').eq('role', 'member').order('full_name')
      return data ?? []
    },
  })
  const createMutation = useCreateMembership()
  const deleteMutation = useDeleteMembership()
  const qc = useQueryClient()

  const recentMemberIds = new Set(recentAttendance?.map(a => a.member_id) ?? [])

  // Live check: as soon as a member is picked, look up whether they already
  // hold a non-expired membership so the error shows without saving.
  const { data: activeForMember } = useQuery({
    queryKey: ['member-active-memberships', form.member_id],
    enabled: showModal && !!form.member_id,
    queryFn: async () => {
      const { data } = await supabase
        .from('memberships')
        .select('id, plan_name, end_date')
        .eq('member_id', form.member_id)
        .gte('end_date', todayStr())
      return data ?? []
    },
  })
  const livePlanError =
    form.member_id && activeForMember && activeForMember.length > 0
      ? `This member already has an active plan: ${activeForMember.map(e => `${e.plan_name} (ends ${new Date(e.end_date).toLocaleDateString()})`).join(', ')}`
      : ''

  // Monthly length = selected months × 30-day plan cycle; Daily stays 1 day.
  const durationDays = PLANS[form.plan_type].days * (form.plan_type === 'monthly' ? form.months : 1)
  // Monthly + Custom: the admin picks the end date by hand instead of the auto calculation.
  const endDate = form.plan_type === 'monthly' && form.custom
    ? form.end_date
    : addDays(form.start_date, durationDays)
  const customInvalid = form.plan_type === 'monthly' && form.custom
    && (!form.end_date || form.end_date <= form.start_date)

  // Close the drawer with the Escape key.
  useEffect(() => {
    if (!showModal) return
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setShowModal(false)
    }
    document.addEventListener('keydown', onKeyDown)
    return () => document.removeEventListener('keydown', onKeyDown)
  }, [showModal])

  const openCreate = () => {
    setForm({
      member_id: '', plan_type: 'daily', months: 1, custom: false,
      end_date: addDays(todayStr(), 30), price: String(PLANS.daily.price), start_date: todayStr(),
    })
    setPlanError('')
    setShowModal(true)
  }

  const handleSave = async () => {
    if (!form.member_id || !Number(form.price) || customInvalid) return
    setPlanError('')
    setSaving(true)
    try {
      const { data: existing } = await supabase
        .from('memberships')
        .select('id, plan_name, end_date')
        .eq('member_id', form.member_id)
        .gte('end_date', new Date().toISOString().split('T')[0])

      if (existing && existing.length > 0) {
        setPlanError(`This member already has an active plan: ${existing.map(e => e.plan_name).join(', ')}`)
        setSaving(false)
        return
      }

      const plan = PLANS[form.plan_type]
      await createMutation.mutateAsync({
        member_id: form.member_id,
        plan_name: plan.label,
        price: Number(form.price),
        start_date: form.start_date,
        end_date: endDate,
      })
      setShowModal(false)
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to create membership')
    } finally {
      setSaving(false)
    }
  }

  const handleDelete = async (id: string) => {
    if (!confirm('Delete this membership?')) return
    try {
      await deleteMutation.mutateAsync(id)
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to delete')
    }
  }

  // ── Renewal decision state & handlers (Phases 3–4) ─────────────────────────
  const [renewRequestId, setRenewRequestId] = useState<string | null>(null)
  const [adminId, setAdminId] = useState<string>('')
  const { data: pendingData } = useRenewalRequests()
  const pendingList = useMemo(() => pendingData ?? [], [pendingData])
  const pendingByMember = useRef<Map<string, MembershipRenewalRequest>>(new Map())
  useEffect(() => {
    pendingByMember.current.clear()
    for (const r of pendingList) pendingByMember.current.set(r.member_id, r)
  }, [pendingList])
  useEffect(() => {
    supabase.auth.getUser().then(u => setAdminId(u.data?.user?.id ?? '')).catch(() => {})
  }, [])

  // The queue is small (24 seeded requests) and `useRenewalRequests` already
  // fetches all of it, so the shared search box filters it in memory. It cannot
  // reuse the member-id path the Daily/Monthly tabs use, because that path
  // filters the `memberships` table - these rows are requests, not memberships.
  const renewalMatches = useMemo(() => {
    const q = membershipSearch.trim().toLowerCase()
    if (!q) return pendingList
    return pendingList.filter(r =>
      [r.profiles?.full_name, r.profiles?.code, r.profiles?.email]
        .some(v => (v ?? '').toLowerCase().includes(q)),
    )
  }, [pendingList, membershipSearch])

  useResetPageOnChange(setRenewPage, membershipSearch)
  const renewPageCount = Math.max(1, Math.ceil(renewalMatches.length / LIST_PAGE_SIZE))
  // Clamp rather than reset: a search that shrinks the queue must not be able to
  // park the reader on a page past the end.
  const safeRenewPage = Math.min(renewPage, renewPageCount)
  const renewalRows = renewalMatches.slice(
    (safeRenewPage - 1) * LIST_PAGE_SIZE,
    safeRenewPage * LIST_PAGE_SIZE,
  )

  // Fifteen rows is the contract on every tab; the height of one of them is what
  // gives. One measurement serves both tables - they are never on screen at once.
  const [scrollRef, rowHeight] = useFitRowHeight<HTMLDivElement>({ count: LIST_PAGE_SIZE })

  /**
   * The member's code gets its own column here, as it already has on the Members
   * and Trainers pages. It used to be printed inside the name cell, which meant
   * name and code had to share one line, they ran together for anyone scanning a
   * column of names, and the code could not be picked out the way a whole column
   * of them can.
   */
  const membershipColumns: PeopleColumn<Membership>[] = [
    { key: 'member', header: 'Member', render: m => <span className="font-medium text-fg-strong">{m.profiles?.full_name ?? '—'}</span> },
    { key: 'code', header: 'Code', render: m => peopleCells.code(m.profiles?.code) },
    { key: 'plan', header: 'Plan', render: m => m.plan_name },
    { key: 'price', header: 'Price', render: m => `₱${m.price}` },
    { key: 'start', header: 'Start', render: m => peopleCells.date(m.start_date) },
    { key: 'end', header: 'End', render: m => peopleCells.date(m.end_date) },
    {
      key: 'status',
      header: 'Status',
      render: m => {
        const status = computeStatus(m, recentMemberIds)
        // A renewal is a monthly-plan concept: a daily pass is bought the day it
        // is used, so a member on one does not renew it - they buy the next day.
        // The badge therefore keys off the row's OWN plan, not just "this member
        // has something pending", which is what used to print RENEWAL REQUESTED
        // and a Renew button on the Daily tab.
        const pendingRequest = canRenew(m) ? pendingByMember.current.get(m.member_id) : undefined
        return (
          <div className="flex items-center gap-2">
            <StatusBadge status={status} />
            {pendingRequest && (
              <span className="inline-flex items-center gap-1 text-xs font-medium text-amber-600 bg-amber-50 px-2 py-0.5 rounded-full border border-amber-200">
                <span className="w-1.5 h-1.5 rounded-full bg-amber-500" />
                RENEWAL REQUESTED
              </span>
            )}
          </div>
        )
      },
    },
    {
      key: 'actions',
      header: 'Actions',
      align: 'right',
      render: m => {
        // Same rule as the Status cell: no Renew button on a daily row. The
        // delete button stays - a daily pass is still a row that can be removed -
        // which is also what makes the Daily Actions column one icon wide and
        // evenly spaced instead of a ragged mix of a button and an icon.
        const pendingRequest = canRenew(m) ? pendingByMember.current.get(m.member_id) : undefined
        return (
          <div className="flex items-center justify-end gap-2">
            {pendingRequest && (
              <button
                onClick={() => handleRenewClick(m.member_id)}
                className="text-xs font-medium text-white bg-[#7C3AED] px-2.5 py-1 rounded-lg hover:bg-[#6D28D9] transition-colors cursor-pointer"
              >
                Renew
              </button>
            )}
            {peopleCells.deleteButton('Delete membership', () => handleDelete(m.id))}
          </div>
        )
      },
    },
  ]

  const handleRenewClick = (memberId: string) => {
    const r = pendingByMember.current.get(memberId)
    if (!r) return
    setRenewRequestId(r.id)
  }

  const [savingRequest, setSavingRequest] = useState<string | null>(null)

  const handleApprove = async (request: MembershipRenewalRequest) => {
    if (request.id.startsWith('mock-')) {
      if (!request.member_id.startsWith('mock-')) {
        const { data: existing } = await supabase
          .from('memberships').select('id, plan_name, price, end_date')
          .eq('member_id', request.member_id).order('end_date', { ascending: false }).limit(1).single()
        const lastEnd = existing?.end_date
        const newStart = lastEnd && endOfDay(lastEnd).getTime() > Date.now()
          ? addDays(lastEnd, 1) : todayStr()
        const planKey = (request.plan_name || '').toLowerCase() as keyof typeof PLANS
        const plan = PLANS[planKey] ?? PLANS.monthly
        const durationDays = planKey === 'daily' ? 1 : request.months * 30
        const samePlanPrice = existing && existing.plan_name === request.plan_name ? existing.price : null
        await supabase.from('memberships').insert({
          member_id: request.member_id,
          plan_name: request.plan_name,
          price: samePlanPrice ?? plan.price,
          start_date: newStart,
          end_date: addDays(newStart, durationDays),
          status: 'active',
        })
        await qc.invalidateQueries({ queryKey: ['memberships'] })
        setActiveTab(planKey === 'daily' ? 'daily' : 'monthly')
      }
      return
    }
    setSavingRequest(request.id)
    try {
      const { data: existing } = await supabase
        .from('memberships').select('id, plan_name, price, end_date')
        .eq('member_id', request.member_id).order('end_date', { ascending: false }).limit(1).single()
      const lastEnd = existing?.end_date
      const newStart = lastEnd && endOfDay(lastEnd).getTime() > Date.now()
        ? addDays(lastEnd, 1) : todayStr()
      const planKey = (request.plan_name || '').toLowerCase() as keyof typeof PLANS
      const plan = PLANS[planKey] ?? PLANS.monthly
      const durationDays = planKey === 'daily' ? 1 : request.months * 30
      const price = existing?.price ? existing.price : plan.price
      await supabase.from('memberships').insert({
        member_id: request.member_id,
        plan_name: request.plan_name,
        price,
        start_date: newStart,
        end_date: addDays(newStart, durationDays),
        status: 'active',
      })
      await supabase
        .from('membership_renewal_requests')
        .update({ status: 'approved', decided_at: new Date().toISOString(), decided_by: adminId })
        .eq('id', request.id)
      await qc.invalidateQueries({ queryKey: ['memberships'] })
      await qc.invalidateQueries({ queryKey: ['membership_renewal_requests'] })
      setActiveTab(planKey === 'daily' ? 'daily' : 'monthly')
    } catch (err) {
      console.error('[ renewals ] approve:', err)
    } finally {
      setSavingRequest(null)
    }
  }

  const handleDecline = async (request: MembershipRenewalRequest) => {
    setSavingRequest(request.id)
    try {
      await supabase
        .from('membership_renewal_requests')
        .update({ status: 'declined', decided_at: new Date().toISOString(), decided_by: adminId })
        .eq('id', request.id)
      await qc.invalidateQueries({ queryKey: ['membership_renewal_requests'] })
    } catch (err) {
      console.error('[ renewals ] decline:', err)
    } finally {
      setSavingRequest(null)
    }
  }

  /**
   * A queue row is deliberately one line: the member's email rides along as the
   * name's tooltip and their note as the plan cell's, because a variable-height
   * row cannot be part of a fixed fifteen-row page. Both are still one click
   * away - the row itself opens the full request panel.
   */
  const renewalColumns: PeopleColumn<MembershipRenewalRequest>[] = [
    {
      key: 'member',
      header: 'Member',
      render: r => (
        <span className="font-medium text-fg-strong" title={r.profiles?.email ?? undefined}>
          {r.profiles?.full_name ?? '—'}
        </span>
      ),
    },
    { key: 'code', header: 'Code', render: r => peopleCells.code(r.profiles?.code) },
    {
      key: 'plan',
      header: 'Plan',
      render: r => (
        <div className="flex items-center gap-1.5" title={r.note ?? undefined}>
          <span className="bg-[#7C3AED]/10 text-accent-purple px-2 py-0.5 rounded-full text-xs font-medium">{r.plan_name}</span>
          <span className="text-xs text-fg-muted">
            {r.plan_name.toLowerCase() === 'daily' ? '1 day' : `${r.months} month${r.months === 1 ? '' : 's'}`}
          </span>
        </div>
      ),
    },
    {
      key: 'requested',
      header: 'Requested',
      render: r => (
        <span className="text-xs text-fg-muted whitespace-nowrap">
          {new Date(r.requested_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
          {' at '}
          {new Date(r.requested_at).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })}
        </span>
      ),
    },
    {
      key: 'actions',
      header: 'Actions',
      align: 'right',
      render: r => (
        <div className="flex items-center justify-end gap-2">
          {/* `py-1`, not `py-1.5`: at 15 fixed rows the button is the tallest
              thing in the row, so every pixel it is taller is a pixel the row
              cannot give back - and at 1366x768 the queue needs those pixels. */}
          <button
            onClick={e => { e.stopPropagation(); void handleApprove(r) }}
            disabled={savingRequest === r.id}
            className="flex items-center gap-1 px-2.5 py-1 text-xs bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 disabled:opacity-50 cursor-pointer"
          >
            <CheckCircle className="w-3.5 h-3.5" />
            {savingRequest === r.id ? 'Saving...' : 'Approve'}
          </button>
          <button
            onClick={e => { e.stopPropagation(); void handleDecline(r) }}
            disabled={savingRequest === r.id}
            className="flex items-center gap-1 px-2.5 py-1 text-xs bg-rose-600 text-white rounded-lg hover:bg-rose-700 disabled:opacity-50 cursor-pointer"
          >
            <XCircle className="w-3.5 h-3.5" />
            {savingRequest === r.id ? 'Saving...' : 'Decline'}
          </button>
        </div>
      ),
    },
  ]

  return (
    <div className="h-full min-h-0 flex flex-col gap-3">
      {/*
        ONE control row, and that is the whole change here.

        The action button sat in a toolbar strip with the Daily/Monthly/Renewal
        tabs in a SECOND row below it, so the two things an admin uses to decide
        what they are looking at - which view, and adding to it - were on
        different lines with a gap between them. `left` pins the tab strip and
        the button stays in the right-aligned cluster, putting both on one line
        the way every other list page's controls already were.

        The SEARCH is not up here either: it lives in each table's own card
        header, beside the tab's title - the same place the QR queue keeps it.
        The tab strip is what selects the queue, so the "Start date" button that
        once duplicated it stays gone, and this page still has no date filter.

        Losing a row is worth having on this page in particular: the table below
        is a fixed fifteen rows measured against the space it is given, so every
        row of chrome it does not need is breathing room for those rows.
      */}
      <ListToolbar
        left={(
          <div className="flex gap-1 glass-card rounded-xl p-1 w-fit" role="tablist" aria-label="Membership views">
            {(['daily', 'monthly', 'renewal'] as const).map(tab => (
              <button
                key={tab}
                type="button"
                role="tab"
                aria-selected={activeTab === tab}
                onClick={() => setActiveTab(tab)}
                className={`px-5 py-2 text-sm rounded-lg font-medium transition-all cursor-pointer ${
                  activeTab === tab
                    ? 'bg-[#7C3AED] text-white shadow-sm'
                    : 'text-fg hover:text-fg-strong'
                }`}
              >
                {tab === 'daily' ? 'Daily' : tab === 'monthly' ? 'Monthly' : 'Renewal'}
              </button>
            ))}
          </div>
        )}
      >
        <button onClick={openCreate} className="flex items-center gap-2 px-4 py-2 bg-[#7C3AED] text-white rounded-xl text-sm hover:bg-[#6D28D9] shrink-0 cursor-pointer">
          <Plus className="w-4 h-4" /> Add Membership
        </button>
      </ListToolbar>

      {activeTab === 'renewal' ? (
        pendingList.length > 0 ? (
          <PeopleTable
            title="Renewal Requests"
            rows={renewalRows}
            columns={renewalColumns}
            rowKey={r => r.id}
            onRowClick={r => setRenewRequestId(r.id)}
            emptyMessage={`No renewal requests match "${membershipSearch}"`}
            scrollRef={scrollRef}
            rowHeight={rowHeight}
            search={{ value: membershipSearch, onChange: setMembershipSearch, placeholder: 'Search by member name or code…' }}
            startIndex={(safeRenewPage - 1) * LIST_PAGE_SIZE + 1}
            footer={
              <PaginationFooter
                page={safeRenewPage}
                pageCount={renewPageCount}
                total={renewalMatches.length}
                pageSize={LIST_PAGE_SIZE}
                onPageChange={setRenewPage}
              />
            }
          />
        ) : (
          <div className="glass-card rounded-xl p-8 text-center text-sm text-fg-muted">
            No pending renewal requests.
          </div>
        )
      ) : (
        <PeopleTable
          title={`${PLANS[planTab].label} Memberships`}
          rows={memberships}
          columns={membershipColumns}
          rowKey={m => m.id}
          isLoading={isLoading}
          emptyMessage={
            membershipSearch
              ? `No memberships match "${membershipSearch}"`
              : `No ${PLANS[planTab].label} memberships found`
          }
          scrollRef={scrollRef}
          rowHeight={rowHeight}
          search={{ value: membershipSearch, onChange: setMembershipSearch, placeholder: 'Search by member name or code…' }}
          startIndex={(membershipPage - 1) * LIST_PAGE_SIZE + 1}
          footer={
            <PaginationFooter
              page={membershipPage}
              pageCount={membershipPages}
              total={membershipTotal}
              pageSize={LIST_PAGE_SIZE}
              onPageChange={setMembershipPage}
            />
          }
        />
      )}

      {showModal && (
        <div className="fixed inset-0 bg-black/60 z-50" onClick={() => setShowModal(false)}>
          <div
            className="glass-card slide-in-right fixed right-0 top-0 h-full w-full max-w-md flex flex-col rounded-l-2xl border-l border-line"
            onClick={e => e.stopPropagation()}
          >
            <div className="px-6 py-4 border-b border-line flex items-center justify-between">
              <h2 className="text-lg font-semibold text-fg-strong">New Membership</h2>
              <button onClick={() => setShowModal(false)} className="text-fg-muted hover:text-fg cursor-pointer"><X className="w-5 h-5" /></button>
            </div>
            <div className="px-6 py-4 space-y-4 flex-1 overflow-y-auto">
              <div>
                <label className="block text-sm font-medium text-fg mb-1">Member</label>
                <MemberSelect
                  members={members}
                  value={form.member_id}
                  onChange={id => { setForm({ ...form, member_id: id }); setPlanError('') }}
                />
              </div>
              {(livePlanError || planError) && (
                <div className="bg-[#EF4444]/10 border border-[#EF4444]/30 rounded-lg px-4 py-3 text-sm text-[#EF4444]">
                  {livePlanError || planError}
                </div>
              )}
              <div>
                <label className="block text-sm font-medium text-fg mb-1">Plan Type</label>
                <div className="grid grid-cols-2 gap-3">
                  <button
                    type="button"
                    onClick={() => setForm({ ...form, plan_type: 'daily', months: 1, custom: false, price: String(PLANS.daily.price) })}
                    className={`px-4 py-3 rounded-lg border text-sm font-medium transition-all ${
                      form.plan_type === 'daily'
                        ? 'bg-[#7C3AED] border-[#7C3AED] text-white shadow-sm'
                        : 'bg-overlay-8 border-line text-fg hover:border-fg-muted'
                    }`}
                  >
                    Daily
                  </button>
                  <button
                    type="button"
                    onClick={() => setForm({ ...form, plan_type: 'monthly', months: 1, custom: false, price: String(PLANS.monthly.price) })}
                    className={`px-4 py-3 rounded-lg border text-sm font-medium transition-all ${
                      form.plan_type === 'monthly'
                        ? 'bg-[#7C3AED] border-[#7C3AED] text-white shadow-sm'
                        : 'bg-overlay-8 border-line text-fg hover:border-fg-muted'
                    }`}
                  >
                    Monthly
                  </button>
                </div>
              </div>
              {form.plan_type === 'monthly' && (
                <div>
                  <label className="block text-sm font-medium text-fg mb-1">Duration (months)</label>
                  <div className="grid grid-cols-4 gap-2">
                    {[1, 2, 3, 4, 5, 6].map(n => (
                      <button
                        key={n}
                        type="button"
                        onClick={() => setForm({ ...form, months: n, custom: false })}
                        className={`py-2 rounded-lg border text-sm font-medium transition-all ${
                          form.months === n && !form.custom
                            ? 'bg-[#7C3AED] border-[#7C3AED] text-white shadow-sm'
                            : 'bg-overlay-8 border-line text-fg hover:border-fg-muted'
                        }`}
                      >
                        {n}
                      </button>
                    ))}
                    <button
                      type="button"
                      onClick={() => setForm({ ...form, custom: true })}
                      className={`py-2 col-span-2 rounded-lg border text-sm font-medium transition-all ${
                        form.custom
                          ? 'bg-[#7C3AED] border-[#7C3AED] text-white shadow-sm'
                          : 'bg-overlay-8 border-line text-fg hover:border-fg-muted'
                      }`}
                    >
                      Custom
                    </button>
                  </div>
                </div>
              )}
              <div>
                <label className="block text-sm font-medium text-fg mb-1">Price</label>
                <div className="relative">
                  <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sm text-fg-muted">₱</span>
                  <input
                    type="text"
                    inputMode="numeric"
                    pattern="[0-9]*"
                    value={form.price}
                    onChange={e => setForm({ ...form, price: e.target.value.replace(/[^0-9]/g, '') })}
                    placeholder="0"
                    className="w-full pl-8 pr-3 py-2 bg-overlay-8 border border-line rounded-lg text-sm text-fg-strong"
                  />
                </div>
                {!Number(form.price) && (
                  <p className="text-xs text-[#EF4444] mt-1">Price must be greater than 0</p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-fg mb-1">Start Date</label>
                <input type="date" value={form.start_date} onChange={e => setForm({ ...form, start_date: e.target.value })} className="w-full px-3 py-2 bg-overlay-8 border border-line rounded-lg text-sm text-fg-strong" />
              </div>
              {form.plan_type === 'monthly' && (
                <div>
                  <label className="block text-sm font-medium text-fg mb-1">End Date</label>
                  {form.custom ? (
                    <>
                      <input
                        type="date"
                        value={form.end_date}
                        min={form.start_date}
                        onChange={e => setForm({ ...form, end_date: e.target.value })}
                        className="w-full px-3 py-2 bg-overlay-8 border border-line rounded-lg text-sm text-fg-strong"
                      />
                      <p className={`text-xs mt-1 ${customInvalid ? 'text-[#EF4444]' : 'text-fg-muted'}`}>
                        {customInvalid
                          ? 'Custom end date must be after the start date.'
                          : 'Custom range — set your own end date.'}
                      </p>
                    </>
                  ) : (
                    <>
                      <div className="w-full px-3 py-2 bg-overlay-8 border border-line rounded-lg text-sm text-fg-strong opacity-80 cursor-not-allowed">
                        {endDate}
                      </div>
                      <p className="text-xs text-fg-muted mt-1">Auto-calculated: start date + {durationDays} days</p>
                    </>
                  )}
                </div>
              )}
              <div className="bg-overlay-8 rounded-lg px-4 py-3 border border-line">
                <div className="text-xs text-fg-muted mb-1">Summary</div>
                <div className="flex justify-between text-sm">
                  <span className="text-fg">Plan</span>
                  <span className="text-fg-strong font-medium">{PLANS[form.plan_type].label}</span>
                </div>
                <div className="flex justify-between text-sm mt-1">
                  <span className="text-fg">Price</span>
                  <span className="text-fg-strong font-medium">₱{form.price ? Number(form.price).toLocaleString() : '—'}</span>
                </div>
                {form.plan_type === 'monthly' && (
                  <div className="flex justify-between text-sm mt-1">
                    <span className="text-fg">End Date</span>
                    <span className="text-fg-strong font-medium">{endDate}</span>
                  </div>
                )}
              </div>
            </div>
            <div className="px-6 py-4 border-t border-line flex justify-end gap-3">
              <button onClick={() => setShowModal(false)} className="px-4 py-2 text-sm border border-line rounded-lg text-fg hover:bg-overlay-8">Cancel</button>
              <button onClick={handleSave} disabled={saving || !form.member_id || !!livePlanError || !Number(form.price) || customInvalid} className="px-4 py-2 text-sm bg-[#7C3AED] text-white rounded-lg hover:bg-[#6D28D9] disabled:opacity-50 cursor-pointer">
                {saving ? 'Saving...' : 'Create'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Renewal decision modal (Phase 3) ── */}
      {renewRequestId && pendingList.length > 0 && (() => {
        const request = pendingList.filter(r => r.id === renewRequestId)[0]
        if (!request) return null
        return (
          <div className="fixed inset-0 bg-black/60 z-40" onClick={() => setRenewRequestId(null)}>
            <div
              className="glass-card slide-in-right fixed right-0 top-0 h-full w-full max-w-md flex flex-col rounded-l-2xl border-l border-line"
              onClick={e => e.stopPropagation()}
            >
              <div className="px-6 py-4 border-b border-line flex items-center justify-between">
                <h2 className="text-lg font-semibold text-fg-strong">Renewal Request</h2>
                <button onClick={() => setRenewRequestId(null)} className="text-fg-muted hover:text-fg cursor-pointer"><X className="w-5 h-5" /></button>
              </div>
              <div className="px-6 py-4 space-y-4 flex-1 overflow-y-auto">
                <div>
                  <label className="block text-xs font-medium text-fg-muted uppercase tracking-wide mb-1">Member</label>
                  {/* Name, code and email stack instead of sharing one line: the
                      code belongs beside the other members' codes, not wedged
                      into the middle of this one name. */}
                  <p className="text-sm font-medium text-fg-strong">{request.profiles?.full_name ?? '—'}</p>
                  {request.profiles?.code != null && <p className="text-xs font-mono text-fg-strong mt-0.5">{request.profiles.code}</p>}
                  {request.profiles?.email != null && <p className="text-xs text-fg-muted mt-0.5">{request.profiles.email}</p>}
                </div>
                <div>
                  <label className="block text-xs font-medium text-fg-muted uppercase tracking-wide mb-1">Requested Plan</label>
                  <div className="flex flex-wrap gap-2">
                    <span className="bg-[#7C3AED]/10 text-accent-purple px-3 py-1 rounded-full text-sm font-medium">{request.plan_name}</span>
                    <span className="text-sm text-fg">{request.months} month{request.months === 1 ? '' : 's'}</span>
                  </div>
                </div>
                {request.note != null && request.note.trim() !== '' && (
                  <div>
                    <label className="block text-xs font-medium text-fg-muted uppercase tracking-wide mb-1">Note from Member</label>
                    <p className="text-sm text-fg bg-overlay-8 rounded-lg px-3 py-2 border border-line">{request.note}</p>
                  </div>
                )}
                <div>
                  <label className="block text-xs font-medium text-fg-muted uppercase tracking-wide mb-1">Requested On</label>
                  <p className="text-sm text-fg">
                    {new Date(request.requested_at).toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' })}
                    {' at '}
                    {new Date(request.requested_at).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })}
                  </p>
                </div>
                <div className="bg-overlay-5 rounded-xl border border-line p-4 space-y-2">
                  <p className="text-xs text-fg-muted text-center">Approve creates a new active membership for this member. Decline marks the request as declined.</p>
                  <div className="flex gap-3">
                    <button
                      onClick={() => handleApprove(request)}
                      disabled={savingRequest === request.id}
                      className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 text-sm bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 disabled:opacity-50 cursor-pointer transition-colors"
                    >
                      <CheckCircle className="w-4 h-4" />
                      {savingRequest === request.id ? 'Saving...' : 'Approve Renewal'}
                    </button>
                    <button
                      onClick={() => handleDecline(request)}
                      disabled={savingRequest === request.id}
                      className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 text-sm bg-rose-600 text-white rounded-lg hover:bg-rose-700 disabled:opacity-50 cursor-pointer transition-colors"
                    >
                      <XCircle className="w-4 h-4" />
                      {savingRequest === request.id ? 'Saving...' : 'Decline'}
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )
      })()}
    </div>
  )
}

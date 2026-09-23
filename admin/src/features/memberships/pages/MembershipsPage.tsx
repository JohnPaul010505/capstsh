import { useEffect, useMemo, useRef, useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { useMemberships, useCreateMembership, useDeleteMembership, useAttendanceLast7Days, useRenewalRequests } from '../hooks/useMemberships'
import StatusBadge from '@/components/StatusBadge'
import type { Membership, MembershipRenewalRequest } from '@/types'
import { Plus, X, Trash2, ChevronDown, CheckCircle, XCircle } from 'lucide-react'

const PLANS = {
  daily: { label: 'Daily', price: 60, days: 1 },
  monthly: { label: 'Monthly', price: 1800, days: 30 },
} as const

/** Demo pending renewals — shown when the database has none, so the panel is not empty. */
const MOCK_PENDING_RENEWALS: MembershipRenewalRequest[] = [
  {
    id: 'mock-renewal-1',
    member_id: 'mock-member-1',
    membership_id: null,
    plan_name: 'Monthly',
    months: 1,
    status: 'pending',
    note: 'Continuing my plan, please!',
    requested_at: new Date(Date.now() - 2 * 3600_000).toISOString(),
    decided_at: null,
    decided_by: null,
    profiles: { full_name: 'Maria Santos', code: 'M005', email: 'member2@mock.fit' },
  },
  {
    id: 'mock-renewal-2',
    member_id: 'mock-member-2',
    membership_id: null,
    plan_name: 'Daily',
    months: 1,
    status: 'pending',
    note: null,
    requested_at: new Date(Date.now() - 24 * 60 * 60_000).toISOString(),
    decided_at: null,
    decided_by: null,
    profiles: { full_name: 'Juan Dela Cruz', code: 'M004', email: 'member1@mock.fit' },
  },
  {
    id: 'mock-renewal-3',
    member_id: 'mock-member-3',
    membership_id: null,
    plan_name: 'Monthly',
    months: 1,
    status: 'pending',
    note: 'Thank you!',
    requested_at: new Date(Date.now() - 3 * 24 * 60 * 60_000).toISOString(),
    decided_at: null,
    decided_by: null,
    profiles: { full_name: 'Ana Reyes', code: 'M007', email: 'member4@mock.fit' },
  },
]

  const MOCK_RENEWAL_EMAILS: string[] = [...new Set(
    MOCK_PENDING_RENEWALS.map(m => m.profiles?.email).filter((e): e is string => !!e)
  )]
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

type MemberOption = { id: string; full_name: string; email: string; code: string | null }

/** Glass-styled custom dropdown (native <select> popups render white and can't be themed). */
function MemberSelect({ members, value, onChange }: { members: MemberOption[] | undefined; value: string; onChange: (id: string) => void }) {
  const [open, setOpen] = useState(false)
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
          <button
            type="button"
            onClick={() => { onChange(''); setOpen(false) }}
            className={`w-full text-left px-3 py-2 text-sm cursor-pointer transition-colors ${
              !value ? 'bg-[#7C3AED]/15 text-accent-purple' : 'text-fg-muted hover:bg-[#7C3AED]/10 hover:text-fg-strong'
            }`}
          >
            Select member...
          </button>
          {members?.map(m => (
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
        </div>
      )}
    </div>
  )
}

export default function MembershipsPage() {
  const [activeTab, setActiveTab] = useState<'daily' | 'monthly' | 'renewal'>('daily')
  const [showModal, setShowModal] = useState(false)
  const [form, setForm] = useState({ member_id: '', plan_type: 'daily' as 'daily' | 'monthly', months: 1, price: String(PLANS.daily.price), start_date: todayStr() })
  const [saving, setSaving] = useState(false)
  const [planError, setPlanError] = useState('')

  const planTab = activeTab === 'renewal' ? 'daily' : activeTab
  const { data: memberships, isLoading } = useMemberships(PLANS[planTab].label)
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
  const endDate = addDays(form.start_date, durationDays)

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
    setForm({ member_id: '', plan_type: 'daily', months: 1, price: String(PLANS.daily.price), start_date: todayStr() })
    setPlanError('')
    setShowModal(true)
  }

  const handleSave = async () => {
    if (!form.member_id || !Number(form.price)) return
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
  const [dismissedMocks, setDismissedMocks] = useState<string[]>([])
  const visibleMocks = MOCK_PENDING_RENEWALS.filter(m => !dismissedMocks.includes(m.id))
  const { data: mockProfiles } = useQuery({
    queryKey: ['mock-renewal-profiles'],
    queryFn: async () => {
      const { data } = await supabase
        .from('profiles').select('id, email, code').in('email', MOCK_RENEWAL_EMAILS)
      return (data ?? [])
    },
  })
  const pendingList = useMemo(() => {
    const byEmail = new Map((mockProfiles ?? []).map(p => [p.email, p]))
    return visibleMocks.map(m => {
      const hit = m.profiles?.email ? byEmail.get(m.profiles.email) : undefined
      if (!hit || !m.profiles) return m
      return { ...m, member_id: hit.id, profiles: { ...m.profiles, code: hit.code ?? m.profiles.code } }
    }).concat(pendingData ?? [])
  }, [pendingData, dismissedMocks, mockProfiles])
  const pendingByMember = useRef<Map<string, MembershipRenewalRequest>>(new Map())
  useEffect(() => {
    pendingByMember.current.clear()
    for (const r of pendingList) pendingByMember.current.set(r.member_id, r)
  }, [pendingList])
  useEffect(() => {
    supabase.auth.getUser().then(u => setAdminId(u.data?.user?.id ?? '')).catch(() => {})
  }, [])

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
      setDismissedMocks(prev => prev.includes(request.id) ? prev : [...prev, request.id])
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
    if (request.id.startsWith('mock-')) {
      setDismissedMocks(prev => prev.includes(request.id) ? prev : [...prev, request.id])
      return
    }
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

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <div />
        <button onClick={openCreate} className="flex items-center gap-2 px-4 py-2 bg-[#7C3AED] text-white rounded-lg text-sm hover:bg-[#6D28D9]">
          <Plus className="w-4 h-4" /> Add Membership
        </button>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 glass-card rounded-xl p-1 w-fit">
        <button
          onClick={() => setActiveTab('daily')}
          className={`px-5 py-2 text-sm rounded-lg font-medium transition-all ${
            activeTab === 'daily'
              ? 'bg-[#7C3AED] text-white shadow-sm'
              : 'text-fg hover:text-fg-strong'
          }`}
        >
          Daily
        </button>
        <button
          onClick={() => setActiveTab('monthly')}
          className={`px-5 py-2 text-sm rounded-lg font-medium transition-all ${
            activeTab === 'monthly'
              ? 'bg-[#7C3AED] text-white shadow-sm'
              : 'text-fg hover:text-fg-strong'
          }`}
        >
          Monthly
        </button>

        <button
          onClick={() => setActiveTab('renewal')}
          className={`px-5 py-2 text-sm rounded-lg font-medium transition-all ${
            activeTab === 'renewal'
              ? 'bg-[#7C3AED] text-white shadow-sm'
              : 'text-fg hover:text-fg-strong'
          }`}
        >
          Renewal
        </button>
      </div>

      {activeTab === 'renewal' ? (
        pendingList.length > 0 ? (
          <div className="glass-card rounded-xl p-4">
            <div className="flex items-center justify-between mb-3">
              <h2 className="text-sm font-semibold text-fg-strong">Pending Renewals</h2>
              <span className="text-xs text-fg-muted">{pendingList.length} request{pendingList.length === 1 ? '' : 's'}</span>
            </div>
            <div className="space-y-3">
              {pendingList.map(request => (
                <div key={request.id} className="flex items-start justify-between gap-4">
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <span className="text-sm font-medium text-fg-strong">{request.profiles?.full_name ?? '—'}</span>
                      {request.profiles?.code != null && <span className="text-xs font-mono text-accent-purple">{request.profiles.code}</span>}
                    </div>
                    {request.profiles?.email != null && <p className="text-xs text-fg-muted mb-2">{request.profiles.email}</p>}
                    <div className="flex flex-wrap gap-1.5">
                      <span className="bg-[#7C3AED]/10 text-accent-purple px-2 py-0.5 rounded-full text-xs font-medium">{request.plan_name}</span>
                      <span className="text-xs text-fg-muted">{request.plan_name.toLowerCase() === 'daily' ? '1 day' : `${request.months} month${request.months === 1 ? '' : 's'}`}</span>
                      {request.note != null && request.note.trim() !== '' && <span className="text-xs text-fg">"{request.note}"</span>}
                    </div>
                    <p className="text-xs text-fg-muted mt-1">
                      Requested{' '}
                      {new Date(request.requested_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
                      {' at '}
                      {new Date(request.requested_at).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })}
                    </p>
                  </div>
                  <div className="flex items-center gap-2 shrink-0">
                    <button
                      onClick={() => handleApprove(request)}
                      disabled={savingRequest === request.id}
                      className="flex items-center gap-1 px-3 py-1.5 text-xs bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 disabled:opacity-50"
                    >
                      <CheckCircle className="w-3.5 h-3.5" />
                      {savingRequest === request.id ? 'Saving...' : 'Approve'}
                    </button>
                    <button
                      onClick={() => handleDecline(request)}
                      disabled={savingRequest === request.id}
                      className="flex items-center gap-1 px-3 py-1.5 text-xs bg-rose-600 text-white rounded-lg hover:bg-rose-700 disabled:opacity-50"
                    >
                      <XCircle className="w-3.5 h-3.5" />
                      {savingRequest === request.id ? 'Saving...' : 'Decline'}
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        ) : (
          <div className="glass-card rounded-xl p-8 text-center text-sm text-fg-muted">
            No pending renewal requests.
          </div>
        )
      ) : isLoading ? (
        <div className="text-center py-8 text-fg-muted">Loading...</div>
      ) : (
        <div className="glass-card rounded-xl overflow-hidden flex flex-col min-h-0">
          <div className="overflow-x-auto flex-1 max-h-[420px]">
            <table className="w-full">
              <thead>
                <tr className="border-b border-line bg-overlay-5">
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Member</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Plan</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Price</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Start</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">End</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Status</th>
                  <th className="text-right px-3 py-2 text-sm font-medium text-fg-muted">Actions</th>
                </tr>
              </thead>
              <tbody>
                {memberships?.map((m: Membership) => {
                  const status = computeStatus(m, recentMemberIds)
                  const pendingRequest = pendingByMember.current.get(m.member_id)
                  return (
                    <tr key={m.id} className="border-b border-line-soft last:border-0 hover:bg-[#7C3AED]/5 transition-colors">
                      <td className="px-3 py-2 text-sm font-medium text-fg-strong">
                          {m.profiles?.full_name ?? '—'}
                        <span className="ml-2 text-xs font-mono text-[#7C3AED]">{m.profiles?.code}</span>
                      </td>
                      <td className="px-3 py-2 text-sm text-fg">{m.plan_name}</td>
                      <td className="px-3 py-2 text-sm text-fg">                        ₱{m.price}</td>
                      <td className="px-3 py-2 text-sm text-fg">{new Date(m.start_date).toLocaleDateString()}</td>
                      <td className="px-3 py-2 text-sm text-fg">{new Date(m.end_date).toLocaleDateString()}</td>
                      <td className="px-3 py-2">
                        <div className="flex items-center gap-2">
                          <StatusBadge status={status} />
                          {pendingRequest && (
                            <span className="inline-flex items-center gap-1 text-xs font-medium text-amber-600 bg-amber-50 px-2 py-0.5 rounded-full border border-amber-200">
                              <span className="w-1.5 h-1.5 rounded-full bg-amber-500" />
                              RENEWAL REQUESTED
                            </span>
                          )}
                        </div>
                      </td>
                      <td className="px-3 py-2 text-right">
                        <div className="flex items-center justify-end gap-2">
                          {pendingRequest && (
                            <button
                              onClick={() => handleRenewClick(m.member_id)}
                              className="text-xs font-medium text-accent-purple bg-[#7C3AED]/10 px-2 py-1 rounded border border-[#7C3AED]/20 hover:bg-[#7C3AED]/20 transition-colors"
                            >
                              Renew
                            </button>
                          )}
                          <button onClick={() => handleDelete(m.id)} className="text-fg-muted hover:text-[#EF4444]"><Trash2 className="w-4 h-4 inline" /></button>
                        </div>
                      </td>
                    </tr>
                  )
                })}
                {memberships?.length === 0 && (
                  <tr><td colSpan={7} className="px-3 py-6 text-center text-fg-muted">No memberships</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
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
                    onClick={() => setForm({ ...form, plan_type: 'daily', months: 1, price: String(PLANS.daily.price) })}
                    className={`px-4 py-3 rounded-lg border text-sm font-medium transition-all ${
                      form.plan_type === 'daily'
                        ? 'bg-[#7C3AED]/15 border-[#7C3AED] text-accent-purple'
                        : 'bg-overlay-8 border-line text-fg hover:border-fg-muted'
                    }`}
                  >
                    Daily
                  </button>
                  <button
                    type="button"
                    onClick={() => setForm({ ...form, plan_type: 'monthly', months: 1, price: String(PLANS.monthly.price) })}
                    className={`px-4 py-3 rounded-lg border text-sm font-medium transition-all ${
                      form.plan_type === 'monthly'
                        ? 'bg-[#7C3AED]/15 border-[#7C3AED] text-accent-purple'
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
                  <div className="grid grid-cols-6 gap-2">
                    {[1, 2, 3, 4, 5, 6].map(n => (
                      <button
                        key={n}
                        type="button"
                        onClick={() => setForm({ ...form, months: n })}
                        className={`py-2 rounded-lg border text-sm font-medium transition-all ${
                          form.months === n
                            ? 'bg-[#7C3AED]/15 border-[#7C3AED] text-accent-purple'
                            : 'bg-overlay-8 border-line text-fg hover:border-fg-muted'
                        }`}
                      >
                        {n}
                      </button>
                    ))}
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
                  <div className="w-full px-3 py-2 bg-overlay-8 border border-line rounded-lg text-sm text-fg-strong opacity-80 cursor-not-allowed">
                    {endDate}
                  </div>
                  <p className="text-xs text-fg-muted mt-1">Auto-calculated: start date + {durationDays} days</p>
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
              <button onClick={handleSave} disabled={saving || !form.member_id || !!livePlanError || !Number(form.price)} className="px-4 py-2 text-sm bg-[#7C3AED] text-white rounded-lg hover:bg-[#6D28D9] disabled:opacity-50 cursor-pointer">
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
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-medium text-fg-strong">{request.profiles?.full_name ?? '—'}</span>
                    {request.profiles?.code != null && <span className="text-xs font-mono text-accent-purple">{request.profiles.code}</span>}
                  </div>
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

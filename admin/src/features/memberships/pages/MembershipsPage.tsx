import { useEffect, useRef, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { useMemberships, useCreateMembership, useDeleteMembership, useAttendanceLast7Days } from '../hooks/useMemberships'
import StatusBadge from '@/components/StatusBadge'
import type { Membership } from '@/types'
import { Plus, X, Trash2, ChevronDown } from 'lucide-react'

const PLANS = {
  daily: { label: 'Daily', price: 60, days: 1 },
  monthly: { label: 'Monthly', price: 1800, days: 30 },
} as const

function todayStr() {
  return new Date().toISOString().split('T')[0]
}

function addDays(date: string, days: number) {
  const d = new Date(date)
  d.setDate(d.getDate() + days)
  return d.toISOString().split('T')[0]
}

function computeStatus(m: Membership, recentAttendance: Set<string>) {
  if (new Date(m.end_date) < new Date()) return 'expired'
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
  const [activeTab, setActiveTab] = useState<'daily' | 'monthly'>('daily')
  const [showModal, setShowModal] = useState(false)
  const [form, setForm] = useState({ member_id: '', plan_type: 'daily' as 'daily' | 'monthly', start_date: todayStr() })
  const [saving, setSaving] = useState(false)
  const [planError, setPlanError] = useState('')

  const { data: memberships, isLoading } = useMemberships(PLANS[activeTab].label)
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
    setForm({ member_id: '', plan_type: 'daily', start_date: todayStr() })
    setPlanError('')
    setShowModal(true)
  }

  const handleSave = async () => {
    if (!form.member_id) return
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
        price: plan.price,
        start_date: form.start_date,
        end_date: addDays(form.start_date, plan.days),
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
      </div>

      {isLoading ? (
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
                      <td className="px-3 py-2"><StatusBadge status={status} /></td>
                      <td className="px-3 py-2 text-right">
                        <button onClick={() => handleDelete(m.id)} className="text-fg-muted hover:text-[#EF4444]"><Trash2 className="w-4 h-4 inline" /></button>
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
                    onClick={() => setForm({ ...form, plan_type: 'daily' })}
                    className={`px-4 py-3 rounded-lg border text-sm font-medium transition-all ${
                      form.plan_type === 'daily'
                        ? 'bg-[#7C3AED]/15 border-[#7C3AED] text-accent-purple'
                        : 'bg-overlay-8 border-line text-fg hover:border-fg-muted'
                    }`}
                  >
                    <div className="text-base font-bold">₱60</div>
                    <div className="text-xs mt-0.5">Daily</div>
                  </button>
                  <button
                    type="button"
                    onClick={() => setForm({ ...form, plan_type: 'monthly' })}
                    className={`px-4 py-3 rounded-lg border text-sm font-medium transition-all ${
                      form.plan_type === 'monthly'
                        ? 'bg-[#7C3AED]/15 border-[#7C3AED] text-accent-purple'
                        : 'bg-overlay-8 border-line text-fg hover:border-fg-muted'
                    }`}
                  >
                    <div className="text-base font-bold">₱1,800</div>
                    <div className="text-xs mt-0.5">Monthly</div>
                  </button>
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-fg mb-1">Start Date</label>
                <input type="date" value={form.start_date} onChange={e => setForm({ ...form, start_date: e.target.value })} className="w-full px-3 py-2 bg-overlay-8 border border-line rounded-lg text-sm text-fg-strong" />
              </div>
              <div className="bg-overlay-8 rounded-lg px-4 py-3 border border-line">
                <div className="text-xs text-fg-muted mb-1">Summary</div>
                <div className="flex justify-between text-sm">
                  <span className="text-fg">Plan</span>
                  <span className="text-fg-strong font-medium">{PLANS[form.plan_type].label}</span>
                </div>
                <div className="flex justify-between text-sm mt-1">
                  <span className="text-fg">Price</span>
                  <span className="text-fg-strong font-medium">₱{PLANS[form.plan_type].price}</span>
                </div>
                <div className="flex justify-between text-sm mt-1">
                  <span className="text-fg">End Date</span>
                  <span className="text-fg-strong font-medium">{addDays(form.start_date, PLANS[form.plan_type].days)}</span>
                </div>
              </div>
            </div>
            <div className="px-6 py-4 border-t border-line flex justify-end gap-3">
              <button onClick={() => setShowModal(false)} className="px-4 py-2 text-sm border border-line rounded-lg text-fg hover:bg-overlay-8">Cancel</button>
              <button onClick={handleSave} disabled={saving || !form.member_id || !!livePlanError} className="px-4 py-2 text-sm bg-[#7C3AED] text-white rounded-lg hover:bg-[#6D28D9] disabled:opacity-50 cursor-pointer">
                {saving ? 'Saving...' : 'Create'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

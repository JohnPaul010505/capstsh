import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { useMemberships, useCreateMembership, useDeleteMembership, useAttendanceLast7Days } from '../hooks/useMemberships'
import StatusBadge from '@/components/StatusBadge'
import type { Membership } from '@/types'
import { Plus, X, Trash2 } from 'lucide-react'

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
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-[#ECECFC]">Memberships</h1>
        <button onClick={openCreate} className="flex items-center gap-2 px-4 py-2 bg-[#7C3AED] text-white rounded-lg text-sm hover:bg-[#6D28D9]">
          <Plus className="w-4 h-4" /> Add Membership
        </button>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 glass-card rounded-xl p-1 border border-white/10 w-fit">
        <button
          onClick={() => setActiveTab('daily')}
          className={`px-5 py-2 text-sm rounded-lg font-medium transition-all ${
            activeTab === 'daily'
              ? 'bg-[#7C3AED] text-white shadow-sm'
              : 'text-[#B4B4D0] hover:text-[#ECECFC]'
          }`}
        >
          Daily (â‚±60)
        </button>
        <button
          onClick={() => setActiveTab('monthly')}
          className={`px-5 py-2 text-sm rounded-lg font-medium transition-all ${
            activeTab === 'monthly'
              ? 'bg-[#7C3AED] text-white shadow-sm'
              : 'text-[#B4B4D0] hover:text-[#ECECFC]'
          }`}
        >
          Monthly (â‚±1,800)
        </button>
      </div>

      {isLoading ? (
        <div className="text-center py-8 text-[#55557A]">Loading...</div>
      ) : (
        <div className="glass-card rounded-xl border border-white/10 shadow-sm overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="border-b border-white/10 bg-white/5">
                <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Member</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Plan</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Price</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Start</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">End</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Status</th>
                <th className="text-right px-4 py-3 text-sm font-medium text-[#55557A]">Actions</th>
              </tr>
            </thead>
            <tbody>
              {memberships?.map((m: Membership) => {
                const status = computeStatus(m, recentMemberIds)
                return (
                  <tr key={m.id} className="border-b border-white/5 last:border-0 hover:bg-[#7C3AED]/5 transition-colors">
                    <td className="px-4 py-3 text-sm font-medium text-[#ECECFC]">
                      {m.profiles?.full_name ?? 'â€”'}
                      <span className="ml-2 text-xs font-mono text-[#7C3AED]">{m.profiles?.code}</span>
                    </td>
                    <td className="px-4 py-3 text-sm text-[#B4B4D0]">{m.plan_name}</td>
                    <td className="px-4 py-3 text-sm text-[#B4B4D0]">â‚±{m.price}</td>
                    <td className="px-4 py-3 text-sm text-[#B4B4D0]">{new Date(m.start_date).toLocaleDateString()}</td>
                    <td className="px-4 py-3 text-sm text-[#B4B4D0]">{new Date(m.end_date).toLocaleDateString()}</td>
                    <td className="px-4 py-3"><StatusBadge status={status} /></td>
                    <td className="px-4 py-3 text-right">
                      <button onClick={() => handleDelete(m.id)} className="text-[#55557A] hover:text-[#EF4444]"><Trash2 className="w-4 h-4 inline" /></button>
                    </td>
                  </tr>
                )
              })}
              {memberships?.length === 0 && (
                <tr><td colSpan={7} className="px-4 py-8 text-center text-[#55557A]">No memberships</td></tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      {showModal && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setShowModal(false)}>
          <div className="glass-card rounded-xl shadow-xl max-w-md w-full mx-4 border border-white/10" onClick={e => e.stopPropagation()}>
            <div className="px-6 py-4 border-b border-white/10 flex items-center justify-between">
              <h2 className="text-lg font-semibold text-[#ECECFC]">New Membership</h2>
              <button onClick={() => setShowModal(false)} className="text-[#55557A] hover:text-[#B4B4D0]"><X className="w-5 h-5" /></button>
            </div>
            <div className="px-6 py-4 space-y-4">
              <div>
                <label className="block text-sm font-medium text-[#B4B4D0] mb-1">Member</label>
                <select value={form.member_id} onChange={e => { setForm({ ...form, member_id: e.target.value }); setPlanError('') }} className="w-full px-3 py-2 bg-white/[0.08] border border-white/10 rounded-lg text-sm text-[#ECECFC]">
                  <option value="">Select member...</option>
                  {members?.map(m => <option key={m.id} value={m.id}>{m.full_name} ({m.code ?? 'â€”'}) â€” {m.email}</option>)}
                </select>
              </div>
              {planError && (
                <div className="bg-[#EF4444]/10 border border-[#EF4444]/30 rounded-lg px-4 py-3 text-sm text-[#EF4444]">
                  {planError}
                </div>
              )}
              <div>
                <label className="block text-sm font-medium text-[#B4B4D0] mb-1">Plan Type</label>
                <div className="grid grid-cols-2 gap-3">
                  <button
                    type="button"
                    onClick={() => setForm({ ...form, plan_type: 'daily' })}
                    className={`px-4 py-3 rounded-lg border text-sm font-medium transition-all ${
                      form.plan_type === 'daily'
                        ? 'bg-[#7C3AED]/15 border-[#7C3AED] text-[#C084FC]'
                        : 'bg-white/[0.08] border-white/10 text-[#B4B4D0] hover:border-[#55557A]'
                    }`}
                  >
                    <div className="text-base font-bold">â‚±60</div>
                    <div className="text-xs mt-0.5">Daily</div>
                  </button>
                  <button
                    type="button"
                    onClick={() => setForm({ ...form, plan_type: 'monthly' })}
                    className={`px-4 py-3 rounded-lg border text-sm font-medium transition-all ${
                      form.plan_type === 'monthly'
                        ? 'bg-[#7C3AED]/15 border-[#7C3AED] text-[#C084FC]'
                        : 'bg-white/[0.08] border-white/10 text-[#B4B4D0] hover:border-[#55557A]'
                    }`}
                  >
                    <div className="text-base font-bold">â‚±1,800</div>
                    <div className="text-xs mt-0.5">Monthly</div>
                  </button>
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-[#B4B4D0] mb-1">Start Date</label>
                <input type="date" value={form.start_date} onChange={e => setForm({ ...form, start_date: e.target.value })} className="w-full px-3 py-2 bg-white/[0.08] border border-white/10 rounded-lg text-sm text-[#ECECFC]" />
              </div>
              <div className="bg-white/[0.08] rounded-lg px-4 py-3 border border-white/10">
                <div className="text-xs text-[#55557A] mb-1">Summary</div>
                <div className="flex justify-between text-sm">
                  <span className="text-[#B4B4D0]">Plan</span>
                  <span className="text-[#ECECFC] font-medium">{PLANS[form.plan_type].label}</span>
                </div>
                <div className="flex justify-between text-sm mt-1">
                  <span className="text-[#B4B4D0]">Price</span>
                  <span className="text-[#ECECFC] font-medium">â‚±{PLANS[form.plan_type].price}</span>
                </div>
                <div className="flex justify-between text-sm mt-1">
                  <span className="text-[#B4B4D0]">End Date</span>
                  <span className="text-[#ECECFC] font-medium">{addDays(form.start_date, PLANS[form.plan_type].days)}</span>
                </div>
              </div>
            </div>
            <div className="px-6 py-4 border-t border-white/10 flex justify-end gap-3">
              <button onClick={() => setShowModal(false)} className="px-4 py-2 text-sm border border-white/10 rounded-lg text-[#B4B4D0] hover:bg-white/[0.08]">Cancel</button>
              <button onClick={handleSave} disabled={saving || !form.member_id} className="px-4 py-2 text-sm bg-[#7C3AED] text-white rounded-lg hover:bg-[#6D28D9] disabled:opacity-50">
                {saving ? 'Saving...' : 'Create'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

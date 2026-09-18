import { useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { ArrowLeft, Mail, Phone, Users, UserPlus, X, Search, Trash2 } from 'lucide-react'

export default function TrainerDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [showAssignModal, setShowAssignModal] = useState(false)
  const [memberSearch, setMemberSearch] = useState('')

  const { data: trainer } = useQuery({
    queryKey: ['trainer', id],
    queryFn: async () => {
      const { data } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', id)
        .eq('role', 'trainer')
        .single()
      return data
    },
  })

  const { data: assignedMembers } = useQuery({
    queryKey: ['trainer-members', id],
    queryFn: async () => {
      const { data } = await supabase
        .from('trainer_assignments')
        .select('*, profiles!trainer_assignments_member_id_fkey(full_name, email, phone)')
        .eq('trainer_id', id)
        .eq('status', 'active')
      return data ?? []
    },
  })

  const { data: recentFeedback } = useQuery({
    queryKey: ['trainer-feedback', id],
    queryFn: async () => {
      const { data } = await supabase
        .from('trainer_feedback')
        .select('*, profiles!trainer_feedback_member_id_fkey(full_name)')
        .eq('trainer_id', id)
        .order('created_at', { ascending: false })
        .limit(10)
      return data ?? []
    },
  })

  const { data: unassignedMembers } = useQuery({
    queryKey: ['unassigned-members', id],
    queryFn: async () => {
      const assignedIds = assignedMembers?.map(a => a.member_id) ?? []
      const { data } = await supabase
        .from('profiles')
        .select('id, full_name, email, code')
        .eq('role', 'member')
        .order('full_name')
      return (data ?? []).filter(m => !assignedIds.includes(m.id))
    },
    enabled: showAssignModal,
  })

  const assignMutation = useMutation({
    mutationFn: async (memberId: string) => {
      const res = await fetch('/api/assign-trainer', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ trainer_id: id, member_id: memberId }),
      })
      if (!res.ok) throw new Error('Failed to assign')
      return res.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['trainer-members', id] })
      queryClient.invalidateQueries({ queryKey: ['unassigned-members', id] })
      setShowAssignModal(false)
    },
  })

  const unassignMutation = useMutation({
    mutationFn: async (assignmentId: string) => {
      const res = await fetch('/api/unassign-trainer', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ assignment_id: assignmentId }),
      })
      if (!res.ok) throw new Error('Failed to unassign')
      return res.json()
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['trainer-members', id] })
      queryClient.invalidateQueries({ queryKey: ['unassigned-members', id] })
    },
  })

  if (!trainer) {
    return <div className="text-center py-8 text-fg-muted">Trainer not found</div>
  }

  return (
    <div className="space-y-3">
      <button onClick={() => navigate('/trainers')} className="flex items-center gap-1 text-sm text-fg-muted hover:text-fg">
        <ArrowLeft className="w-4 h-4" /> Back to Trainers
      </button>

      <div className="glass-card p-4 rounded-xl">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-full bg-gradient-to-br from-[#22C55E]/30 to-[#4ADE80]/30 flex items-center justify-center">
            <span className="text-xl font-bold text-accent-green">{trainer.full_name.charAt(0)}</span>
          </div>
          <div>
            <div className="text-lg font-bold text-fg-strong">{trainer.full_name}</div>
            <p className="text-sm text-fg">{trainer.email}</p>
            <p className="text-xs font-mono text-[#7C3AED] mt-1">{trainer.code}</p>
            {trainer.specialty && <p className="text-xs text-[#22C55E] mt-1">{trainer.specialty}</p>}
            {trainer.available_days && <p className="text-xs text-fg mt-0.5">Available: {trainer.available_days}</p>}
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        <div className="glass-card p-4 rounded-xl">
          <div className="flex items-center gap-2 text-sm text-fg-muted mb-1">
            <Mail className="w-4 h-4" />
            <span>Email</span>
          </div>
          <p className="text-sm text-fg-strong">{trainer.email}</p>
        </div>
        <div className="glass-card p-4 rounded-xl">
          <div className="flex items-center gap-2 text-sm text-fg-muted mb-1">
            <Phone className="w-4 h-4" />
            <span>Phone</span>
          </div>
          <p className="text-sm text-fg-strong">{trainer.phone || '—'}</p>
        </div>
        <div className="glass-card p-4 rounded-xl">
          <div className="flex items-center gap-2 text-sm text-fg-muted mb-1">
            <Users className="w-4 h-4" />
            <span>Assigned Members</span>
          </div>
          <p className="text-xl font-bold text-fg-strong">{assignedMembers?.length ?? 0}</p>
        </div>
      </div>

      <div className="glass-card rounded-xl overflow-hidden flex flex-col min-h-0">
        <div className="flex items-center justify-between px-4 py-3 border-b border-line">
          <h2 className="font-semibold text-fg-strong">Assigned Members</h2>
          <button
            onClick={() => setShowAssignModal(true)}
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-white bg-[#7C3AED] hover:bg-[#6D28D9] rounded-lg transition-colors"
          >
            <UserPlus className="w-3.5 h-3.5" /> Assign Member
          </button>
        </div>
        {assignedMembers?.length === 0 ? (
          <div className="text-center py-6 text-fg-muted">No members assigned</div>
        ) : (
          <div className="overflow-x-auto flex-1">
            <table className="w-full">
              <thead>
                <tr className="border-b border-line bg-overlay-5">
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Name</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Email</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Phone</th>
                  <th className="text-right px-3 py-2 text-sm font-medium text-fg-muted">Actions</th>
                </tr>
              </thead>
              <tbody>
                {assignedMembers?.map(a => (
                  <tr key={a.id} className="border-b border-line-soft last:border-0 hover:bg-[#7C3AED]/5 transition-colors">
                    <td className="px-3 py-2 text-sm font-medium text-fg-strong">{a.profiles?.full_name}</td>
                    <td className="px-3 py-2 text-sm text-fg">{a.profiles?.email}</td>
                    <td className="px-3 py-2 text-sm text-fg">{a.profiles?.phone || '—'}</td>
                    <td className="px-3 py-2 text-right">
                      <button
                        onClick={() => unassignMutation.mutate(a.id)}
                        disabled={unassignMutation.isPending}
                        className="text-[#EF4444] hover:text-[#DC2626] disabled:opacity-50 transition-colors"
                        title="Remove assignment"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <div className="glass-card rounded-xl overflow-hidden flex flex-col min-h-0">
        <div className="px-4 py-3 border-b border-line">
          <h2 className="font-semibold text-fg-strong">Recent Feedback</h2>
        </div>
        {recentFeedback?.length === 0 ? (
          <div className="text-center py-6 text-fg-muted">No feedback yet</div>
        ) : (
          <div className="overflow-x-auto flex-1">
            <table className="w-full">
              <thead>
                <tr className="border-b border-line bg-overlay-5">
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Member</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Feedback</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Date</th>
                </tr>
              </thead>
              <tbody>
                {recentFeedback?.map(f => (
                  <tr key={f.id} className="border-b border-line-soft last:border-0 hover:bg-[#7C3AED]/5 transition-colors">
                    <td className="px-3 py-2 text-sm font-medium text-fg-strong">{f.profiles?.full_name}</td>
                    <td className="px-3 py-2 text-sm text-fg max-w-md truncate">{f.content}</td>
                    <td className="px-3 py-2 text-sm text-fg-muted">{new Date(f.created_at).toLocaleDateString()}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {showAssignModal && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setShowAssignModal(false)}>
          <div className="glass-card rounded-xl w-full max-w-lg mx-4 max-h-[80vh] flex flex-col" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between px-4 py-3 border-b border-line">
              <h3 className="font-semibold text-fg-strong">Assign Member</h3>
              <button onClick={() => setShowAssignModal(false)} className="text-fg-muted hover:text-fg-strong transition-colors">
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="px-4 py-3 border-b border-line">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-fg-muted" />
                <input
                  type="text"
                  placeholder="Search members..."
                  value={memberSearch}
                  onChange={e => setMemberSearch(e.target.value)}
                  className="w-full pl-9 pr-3 py-2 text-sm bg-page-deep border border-line rounded-lg text-fg-strong placeholder-fg-muted focus:outline-none focus:border-[#7C3AED]"
                />
              </div>
            </div>
            <div className="flex-1 overflow-y-auto p-2">
              {unassignedMembers
                ?.filter(m =>
                  memberSearch === '' ||
                  m.full_name?.toLowerCase().includes(memberSearch.toLowerCase()) ||
                  m.email?.toLowerCase().includes(memberSearch.toLowerCase()) ||
                  m.code?.toLowerCase().includes(memberSearch.toLowerCase())
                )
                .map(m => (
                  <button
                    key={m.id}
                    onClick={() => assignMutation.mutate(m.id)}
                    disabled={assignMutation.isPending}
                    className="w-full flex items-center justify-between px-3 py-2.5 rounded-lg hover:bg-[#7C3AED]/10 transition-colors disabled:opacity-50 text-left"
                  >
                    <div>
                      <div className="text-sm font-medium text-fg-strong">{m.full_name}</div>
                      <div className="text-xs text-fg-muted">{m.email} {m.code ? `· ${m.code}` : ''}</div>
                    </div>
                    <UserPlus className="w-4 h-4 text-[#7C3AED]" />
                  </button>
                ))}
              {unassignedMembers?.filter(m =>
                memberSearch === '' ||
                m.full_name?.toLowerCase().includes(memberSearch.toLowerCase()) ||
                m.email?.toLowerCase().includes(memberSearch.toLowerCase()) ||
                m.code?.toLowerCase().includes(memberSearch.toLowerCase())
              ).length === 0 && (
                <div className="text-center py-6 text-fg-muted text-sm">No members found</div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

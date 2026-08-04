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
    return <div className="text-center py-8 text-[#55557A]">Trainer not found</div>
  }

  return (
    <div className="space-y-6">
      <button onClick={() => navigate('/trainers')} className="flex items-center gap-1 text-sm text-[#55557A] hover:text-[#B4B4D0]">
        <ArrowLeft className="w-4 h-4" /> Back to Trainers
      </button>

      <div className="glass-card p-6 rounded-xl border border-white/10 shadow-sm">
        <div className="flex items-center gap-4">
          <div className="w-16 h-16 rounded-full bg-gradient-to-br from-[#22C55E]/30 to-[#4ADE80]/30 flex items-center justify-center">
            <span className="text-2xl font-bold text-[#4ADE80]">{trainer.full_name.charAt(0)}</span>
          </div>
          <div>
            <h1 className="text-xl font-bold text-[#ECECFC]">{trainer.full_name}</h1>
            <p className="text-sm text-[#B4B4D0]">{trainer.email}</p>
            <p className="text-xs font-mono text-[#7C3AED] mt-1">{trainer.code}</p>
            {trainer.specialty && <p className="text-xs text-[#22C55E] mt-1">{trainer.specialty}</p>}
            {trainer.available_days && <p className="text-xs text-[#B4B4D0] mt-0.5">Available: {trainer.available_days}</p>}
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="glass-card p-6 rounded-xl border border-white/10 shadow-sm">
          <div className="flex items-center gap-2 text-sm text-[#55557A] mb-1">
            <Mail className="w-4 h-4" />
            <span>Email</span>
          </div>
          <p className="text-sm text-[#ECECFC]">{trainer.email}</p>
        </div>
        <div className="glass-card p-6 rounded-xl border border-white/10 shadow-sm">
          <div className="flex items-center gap-2 text-sm text-[#55557A] mb-1">
            <Phone className="w-4 h-4" />
            <span>Phone</span>
          </div>
          <p className="text-sm text-[#ECECFC]">{trainer.phone || 'â€”'}</p>
        </div>
        <div className="glass-card p-6 rounded-xl border border-white/10 shadow-sm">
          <div className="flex items-center gap-2 text-sm text-[#55557A] mb-1">
            <Users className="w-4 h-4" />
            <span>Assigned Members</span>
          </div>
          <p className="text-2xl font-bold text-[#ECECFC]">{assignedMembers?.length ?? 0}</p>
        </div>
      </div>

      <div className="glass-card rounded-xl border border-white/10 shadow-sm overflow-hidden">
        <div className="flex items-center justify-between px-4 py-3 border-b border-white/10">
          <h2 className="font-semibold text-[#ECECFC]">Assigned Members</h2>
          <button
            onClick={() => setShowAssignModal(true)}
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-white bg-[#7C3AED] hover:bg-[#6D28D9] rounded-lg transition-colors"
          >
            <UserPlus className="w-3.5 h-3.5" /> Assign Member
          </button>
        </div>
        {assignedMembers?.length === 0 ? (
          <div className="text-center py-8 text-[#55557A]">No members assigned</div>
        ) : (
          <table className="w-full">
            <thead>
              <tr className="border-b border-white/10 bg-white/5">
                <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Name</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Email</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Phone</th>
                <th className="text-right px-4 py-3 text-sm font-medium text-[#55557A]">Actions</th>
              </tr>
            </thead>
            <tbody>
              {assignedMembers?.map(a => (
                <tr key={a.id} className="border-b border-white/5 last:border-0 hover:bg-[#7C3AED]/5 transition-colors">
                  <td className="px-4 py-3 text-sm font-medium text-[#ECECFC]">{a.profiles?.full_name}</td>
                  <td className="px-4 py-3 text-sm text-[#B4B4D0]">{a.profiles?.email}</td>
                  <td className="px-4 py-3 text-sm text-[#B4B4D0]">{a.profiles?.phone || 'â€”'}</td>
                  <td className="px-4 py-3 text-right">
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
        )}
      </div>

      <div className="glass-card rounded-xl border border-white/10 shadow-sm overflow-hidden">
        <div className="px-4 py-3 border-b border-white/10">
          <h2 className="font-semibold text-[#ECECFC]">Recent Feedback</h2>
        </div>
        {recentFeedback?.length === 0 ? (
          <div className="text-center py-8 text-[#55557A]">No feedback yet</div>
        ) : (
          <table className="w-full">
            <thead>
              <tr className="border-b border-white/10 bg-white/5">
                <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Member</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Feedback</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Date</th>
              </tr>
            </thead>
            <tbody>
              {recentFeedback?.map(f => (
                <tr key={f.id} className="border-b border-white/5 last:border-0 hover:bg-[#7C3AED]/5 transition-colors">
                  <td className="px-4 py-3 text-sm font-medium text-[#ECECFC]">{f.profiles?.full_name}</td>
                  <td className="px-4 py-3 text-sm text-[#B4B4D0] max-w-md truncate">{f.content}</td>
                  <td className="px-4 py-3 text-sm text-[#55557A]">{new Date(f.created_at).toLocaleDateString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {showAssignModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60">
          <div className="glass-card rounded-xl border border-white/10 shadow-xl w-full max-w-lg mx-4 max-h-[80vh] flex flex-col">
            <div className="flex items-center justify-between px-4 py-3 border-b border-white/10">
              <h3 className="font-semibold text-[#ECECFC]">Assign Member</h3>
              <button onClick={() => setShowAssignModal(false)} className="text-[#55557A] hover:text-[#ECECFC] transition-colors">
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="px-4 py-3 border-b border-white/10">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#55557A]" />
                <input
                  type="text"
                  placeholder="Search members..."
                  value={memberSearch}
                  onChange={e => setMemberSearch(e.target.value)}
                  className="w-full pl-9 pr-3 py-2 text-sm bg-[#0D0D1A] border border-white/10 rounded-lg text-[#ECECFC] placeholder-[#55557A] focus:outline-none focus:border-[#7C3AED]"
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
                      <div className="text-sm font-medium text-[#ECECFC]">{m.full_name}</div>
                      <div className="text-xs text-[#55557A]">{m.email} {m.code ? `Â· ${m.code}` : ''}</div>
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
                <div className="text-center py-8 text-[#55557A] text-sm">No members found</div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

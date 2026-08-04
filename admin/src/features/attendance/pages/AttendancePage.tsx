import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { useAttendance } from '../hooks/useAttendance'
import { Plus, LogOut, LogIn, X, Clock } from 'lucide-react'

export default function AttendancePage() {
  const today = new Date().toISOString().split('T')[0]
  const [date, setDate] = useState(today)
  const [category, setCategory] = useState<'daily' | 'monthly' | 'trainer'>('daily')
  const [showModal, setShowModal] = useState(false)
  const { data: sessions, isLoading } = useAttendance(date, category)
  const queryClient = useQueryClient()

  const { data: people } = useQuery({
    queryKey: ['attendance-people', category],
    enabled: showModal,
    queryFn: async () => {
      const { data } = await supabase
        .from('profiles')
        .select('id, full_name, email, code')
        .eq('role', category === 'trainer' ? 'trainer' : 'member')
        .order('full_name')
      return data ?? []
    },
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
      const { error } = await supabase.from('attendance').insert({
        member_id: memberId,
        check_in_time: new Date().toISOString(),
        check_in_date: today,
        expires_at: new Date(Date.now() + 12 * 3600000).toISOString(),
      })
      if (error) throw error
    },
    onSuccess: () => {
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

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-[#ECECFC]">Attendance</h1>
        <input
          type="date"
          value={date}
          onChange={e => setDate(e.target.value)}
          className="px-3 py-2 bg-white/[0.08] border border-white/10 rounded-lg text-sm text-[#ECECFC] focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50"
        />
      </div>

      <div className="flex items-center justify-between">
        <div className="flex gap-2">
          <button
            onClick={() => setCategory('daily')}
            className={`px-4 py-1.5 text-sm rounded-lg font-medium transition-colors ${
              category === 'daily'
                ? 'bg-[#7C3AED] text-white'
                : 'bg-white/[0.08] text-[#B4B4D0] hover:bg-white/10'
            }`}
          >
            Daily
          </button>
          <button
            onClick={() => setCategory('monthly')}
            className={`px-4 py-1.5 text-sm rounded-lg font-medium transition-colors ${
              category === 'monthly'
                ? 'bg-[#7C3AED] text-white'
                : 'bg-white/[0.08] text-[#B4B4D0] hover:bg-white/10'
            }`}
          >
            Monthly
          </button>
          <button
            onClick={() => setCategory('trainer')}
            className={`px-4 py-1.5 text-sm rounded-lg font-medium transition-colors ${
              category === 'trainer'
                ? 'bg-[#7C3AED] text-white'
                : 'bg-white/[0.08] text-[#B4B4D0] hover:bg-white/10'
            }`}
          >
            Trainers
          </button>
        </div>
        <button
          onClick={() => setShowModal(true)}
          className="flex items-center gap-1 px-3 py-1.5 text-sm bg-[#7C3AED] text-white rounded-lg hover:bg-[#6D28D9]"
        >
          <Plus className="w-4 h-4" /> Check In
        </button>
      </div>

      {isLoading ? (
        <div className="text-center py-8 text-[#55557A]">Loading...</div>
      ) : (
        <div className="glass-card rounded-xl border border-white/10 shadow-sm overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="border-b border-white/10 bg-white/5">
                <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Name</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Role</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Check-in</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Check-out</th>
                <th className="text-center px-4 py-3 text-sm font-medium text-[#55557A]">Actions</th>
              </tr>
            </thead>
            <tbody>
              {sessions?.map(s => (
                <tr key={s.id} className="border-b border-white/5 last:border-0 hover:bg-[#7C3AED]/5">
                  <td className="px-4 py-3 text-sm font-medium text-[#ECECFC]">
                    {s.profiles?.full_name}
                    <span className="ml-2 text-xs font-mono text-[#7C3AED]">{s.profiles?.code}</span>
                  </td>
                  <td className="px-4 py-3 text-sm text-[#B4B4D0] capitalize">{s.profiles?.role || 'member'}</td>
                  <td className="px-4 py-3 text-sm">
                    <span className="inline-flex items-center gap-1 text-[#4ADE80]">
                      <LogIn className="w-3 h-3" />
                      {new Date(s.check_in_time).toLocaleTimeString()}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm">
                    {s.check_out_time ? (
                      <span className="inline-flex items-center gap-1 text-[#B4B4D0]">
                        <LogOut className="w-3 h-3" />
                        {new Date(s.check_out_time).toLocaleTimeString()}
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1 text-[#FBBF24] text-xs font-medium">
                        <Clock className="w-3 h-3" />
                        Until {new Date(s.expires_at).toLocaleTimeString()}
                      </span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-center">
                    {!s.check_out_time && (
                      <button
                        onClick={() => checkoutMutation.mutate(s.member_id)}
                        disabled={checkoutMutation.isPending}
                        className="px-3 py-1 text-xs bg-[#F59E0B]/15 text-[#FBBF24] rounded-lg hover:bg-[#F59E0B]/25 disabled:opacity-50"
                      >
                        Check Out
                      </button>
                    )}
                  </td>
                </tr>
              ))}
              {sessions?.length === 0 && (
                <tr><td colSpan={5} className="px-4 py-8 text-center text-[#55557A]">No attendance records</td></tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      {showModal && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setShowModal(false)}>
          <div className="glass-card rounded-xl shadow-xl max-w-lg w-full mx-4 max-h-[80vh] flex flex-col border border-white/10" onClick={e => e.stopPropagation()}>
            <div className="px-6 py-4 border-b border-white/10 flex items-center justify-between">
              <h2 className="text-lg font-semibold text-[#ECECFC]">Select {category === 'trainer' ? 'Trainer' : 'Member'}</h2>
              <button onClick={() => setShowModal(false)} className="text-[#55557A] hover:text-[#B4B4D0]">
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="px-6 py-4 flex-1 overflow-y-auto space-y-2">
              {people?.length === 0 ? (
                <p className="text-[#55557A] text-center py-8">No {category === 'trainer' ? 'trainers' : 'members'} found</p>
              ) : (
                people?.map(p => (
                  <button
                    key={p.id}
                    onClick={() => checkinMutation.mutate(p.id)}
                    disabled={checkinMutation.isPending}
                    className="w-full flex items-center justify-between p-3 rounded-lg border border-white/10 hover:bg-[#7C3AED]/10 cursor-pointer disabled:opacity-50 text-left transition-colors"
                  >
                    <div>
                      <p className="font-medium text-sm text-[#ECECFC]">{p.full_name}</p>
                      <p className="text-xs text-[#55557A]">{p.code} â€” {p.email}</p>
                    </div>
                    <LogIn className="w-4 h-4 text-[#4ADE80] shrink-0" />
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

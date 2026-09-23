import { useState, useEffect } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { useAttendance } from '../hooks/useAttendance'
import { Plus, LogOut, LogIn, X, Clock } from 'lucide-react'

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
  const [date, setDate] = useState(today)
  const [category, setCategory] = useState<'member' | 'trainer'>('member')
  const [showModal, setShowModal] = useState(false)
  const [drawerCategory, setDrawerCategory] = useState<'member' | 'trainer'>('member')
  const [search, setSearch] = useState('')

  useEffect(() => {
    if (!showModal) return
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setShowModal(false)
    }
    document.addEventListener('keydown', onKeyDown)
    return () => document.removeEventListener('keydown', onKeyDown)
  }, [showModal])
  const { data: sessions, isLoading } = useAttendance(date, category)
  const queryClient = useQueryClient()

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
      const { error } = await supabase.from('attendance').insert({
        member_id: memberId,
        check_in_time: new Date().toISOString(),
        check_in_date: today,
        expires_at: new Date(Date.now() + 12 * 3600000).toISOString(),
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

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <div />
        <input
          type="date"
          value={date}
          onChange={e => setDate(e.target.value)}
          className="px-3 py-2 bg-overlay-8 border border-line rounded-lg text-sm text-fg-strong focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50"
        />
      </div>

      <div className="flex items-center justify-between">
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
        <button
          onClick={() => { setDrawerCategory(category); setSearch(''); setShowModal(true) }}
          className="flex items-center gap-1 px-3 py-1.5 text-sm bg-[#7C3AED] text-white rounded-lg hover:bg-[#6D28D9]"
        >
          <Plus className="w-4 h-4" /> Check In
        </button>
      </div>

      {isLoading ? (
        <div className="text-center py-8 text-fg-muted">Loading...</div>
      ) : (
        <div className="glass-card rounded-xl overflow-hidden flex flex-col min-h-0">
          <div className="overflow-x-auto flex-1">
            <table className="w-full">
              <thead>
                <tr className="border-b border-line bg-overlay-5">
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Name</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Role</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Check-in</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Check-out</th>
                  <th className="text-center px-3 py-2 text-sm font-medium text-fg-muted">Actions</th>
                </tr>
              </thead>
              <tbody>
                {sessions?.map(s => (
                  <tr key={s.id} className="border-b border-line-soft last:border-0 hover:bg-[#7C3AED]/5">
                    <td className="px-3 py-2 text-sm font-medium text-fg-strong">
                      {s.profiles?.full_name}
                      <span className="ml-2 text-xs font-mono text-[#7C3AED]">{s.profiles?.code}</span>
                    </td>
                    <td className="px-3 py-2 text-sm text-fg capitalize">{s.profiles?.role || 'member'}</td>
                    <td className="px-3 py-2 text-sm">
                      <span className="inline-flex items-center gap-1 text-accent-green">
                        <LogIn className="w-3 h-3" />
                        {new Date(s.check_in_time).toLocaleTimeString()}
                      </span>
                    </td>
                    <td className="px-3 py-2 text-sm">
                      {s.check_out_time ? (
                        <span className="inline-flex items-center gap-1 text-fg">
                          <LogOut className="w-3 h-3" />
                          {new Date(s.check_out_time).toLocaleTimeString()}
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 text-accent-amber text-xs font-medium">
                          <Clock className="w-3 h-3" />
                          Until {new Date(s.expires_at).toLocaleTimeString()}
                        </span>
                      )}
                    </td>
                    <td className="px-3 py-2 text-center">
                      {!s.check_out_time && (
                        <button
                          onClick={() => checkoutMutation.mutate(s.member_id)}
                          disabled={checkoutMutation.isPending}
                          className="px-3 py-1 text-xs bg-[#F59E0B]/15 text-accent-amber rounded-lg hover:bg-[#F59E0B]/25 disabled:opacity-50"
                        >
                          Check Out
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
                {sessions?.length === 0 && (
                  <tr><td colSpan={5} className="px-3 py-6 text-center text-fg-muted">No attendance records</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
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

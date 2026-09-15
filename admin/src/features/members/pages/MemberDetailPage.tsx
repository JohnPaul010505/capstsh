import { useParams, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { useMember } from '../hooks/useMembers'
import { ArrowLeft, Phone, Calendar, MapPin, PhoneCall } from 'lucide-react'
import StatsCard from '@/components/StatsCard'
import {
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, LineChart, Line,
} from 'recharts'

export default function MemberDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { data: member, isLoading } = useMember(id!)

  const { data: address } = useQuery({
    queryKey: ['member-address', id],
    queryFn: async () => {
      const { data } = await supabase
        .from('addresses')
        .select('*')
        .eq('member_id', id)
        .maybeSingle()
      return data
    },
  })

  const { data: measurements } = useQuery({
    queryKey: ['member-measurements', id],
    queryFn: async () => {
      const { data } = await supabase
        .from('body_measurements')
        .select('*')
        .eq('member_id', id)
        .order('measured_at', { ascending: true })
      return data ?? []
    },
  })

  const { data: trainerAssignment } = useQuery({
    queryKey: ['member-trainer', id],
    queryFn: async () => {
      const { data } = await supabase
        .from('trainer_assignments')
        .select('*, profiles!trainer_assignments_trainer_id_fkey(full_name, email)')
        .eq('member_id', id)
        .eq('status', 'active')
        .maybeSingle()
      return data as any ?? null
    },
  })

  const { data: workoutCount } = useQuery({
    queryKey: ['member-workout-count', id],
    queryFn: async () => {
      const { count } = await supabase
        .from('workout_logs')
        .select('*', { count: 'exact', head: true })
        .eq('member_id', id)
      return count ?? 0
    },
  })

  if (isLoading) return <div className="text-center py-8 text-[#55557A]">Loading...</div>
  if (!member) return <div className="text-center py-8 text-[#55557A]">Member not found</div>

  const structuredAddress = address ? [address.line1, address.line2, address.city, address.state, address.postal_code, address.country].filter(Boolean).join(', ') : null
  const fullAddress = structuredAddress || member.address || null

  return (
    <div className="space-y-3">
      <button onClick={() => navigate('/members')} className="flex items-center gap-1 text-sm text-[#55557A] hover:text-[#B4B4D0]">
        <ArrowLeft className="w-4 h-4" /> Back to Members
      </button>

      {/* Profile header */}
      <div className="glass-card p-4 rounded-xl border border-white/10 shadow-sm">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-full bg-gradient-to-br from-[#7C3AED]/30 to-[#C084FC]/30 flex items-center justify-center">
            <span className="text-xl font-bold text-[#C084FC]">
              {member.full_name.charAt(0)}
            </span>
          </div>
          <div>
            <div className="text-lg font-bold text-[#ECECFC]">{member.full_name}</div>
            <p className="text-sm text-[#B4B4D0]">{member.email}</p>
            <p className="text-xs font-mono text-[#7C3AED] mt-1">{member.code}</p>
          </div>
        </div>
      </div>

      {/* Trainer assignment */}
      {trainerAssignment && (
        <div className="glass-card p-4 rounded-xl border border-white/10 shadow-sm">
          <h2 className="text-base font-semibold mb-3 text-[#ECECFC]">Assigned Trainer</h2>
          <div className="flex items-center gap-3 cursor-pointer"
            onClick={() => navigate(`/trainers/${trainerAssignment.trainer_id}`)}
          >
            <div className="w-9 h-9 rounded-full bg-[#22C55E]/20 flex items-center justify-center">
              <span className="text-sm font-bold text-[#4ADE80]">
                {trainerAssignment.profiles?.full_name?.charAt(0)}
              </span>
            </div>
            <div>
              <p className="font-medium text-[#ECECFC]">{trainerAssignment.profiles?.full_name}</p>
              <p className="text-xs text-[#B4B4D0]">{trainerAssignment.profiles?.email}</p>
            </div>
          </div>
        </div>
      )}

      {/* Personal Info */}
      <div className="glass-card p-4 rounded-xl border border-white/10 shadow-sm">
        <h2 className="text-base font-semibold mb-3 text-[#ECECFC]">Personal Information</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          <div className="flex items-center gap-3">
            <Phone className="w-4 h-4 text-[#55557A]" />
            <div>
              <p className="text-xs text-[#55557A]">Phone</p>
              <p className="text-sm text-[#ECECFC]">{member.phone || '—'}</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <Calendar className="w-4 h-4 text-[#55557A]" />
            <div>
              <p className="text-xs text-[#55557A]">Date of Birth</p>
              <p className="text-sm text-[#ECECFC]">{member.date_of_birth || '—'}</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <div className="w-4 h-4 flex items-center justify-center text-[#55557A]">
              <span className="text-xs font-bold">G</span>
            </div>
            <div>
              <p className="text-xs text-[#55557A]">Gender</p>
              <p className="text-sm text-[#ECECFC] capitalize">{member.gender || '—'}</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <MapPin className="w-4 h-4 text-[#55557A]" />
            <div>
              <p className="text-xs text-[#55557A]">Address</p>
              <p className="text-sm text-[#ECECFC]">{fullAddress || '—'}</p>
            </div>
          </div>
        </div>
        <div className="border-t border-white/10 mt-3 pt-3">
          <h3 className="text-sm font-semibold text-[#ECECFC] mb-2">Emergency Contact</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div className="flex items-center gap-3">
              <PhoneCall className="w-4 h-4 text-[#55557A]" />
              <div>
                <p className="text-xs text-[#55557A]">Contact Name</p>
                <p className="text-sm text-[#ECECFC]">{member.emergency_contact_name || '—'}</p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <Phone className="w-4 h-4 text-[#55557A]" />
              <div>
                <p className="text-xs text-[#55557A]">Contact Phone</p>
                <p className="text-sm text-[#ECECFC]">{member.emergency_contact_phone || '—'}</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        <StatsCard title="Total Workouts" value={workoutCount ?? 0} />
        <StatsCard
          title="BMI"
          value={
            measurements && measurements.length > 0 && measurements[measurements.length - 1].height_cm
              ? (measurements[measurements.length - 1].weight_kg / Math.pow(measurements[measurements.length - 1].height_cm / 100, 2)).toFixed(1)
              : '—'
          }
        />
      </div>

      {/* Weight chart */}
      {measurements && measurements.length > 0 && (
        <div className="glass-card p-4 rounded-xl border border-white/10 shadow-sm">
          <h2 className="text-base font-semibold mb-3 text-[#ECECFC]">Weight Progress</h2>
          <div className="h-40">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={measurements}>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.06)" />
                <XAxis
                  dataKey="measured_at"
                  tickFormatter={v => new Date(v).toLocaleDateString()}
                  tick={{ fontSize: 12, fill: '#9494BD' }}
                  axisLine={{ stroke: 'rgba(255,255,255,0.06)' }}
                  tickLine={false}
                />
                <YAxis tick={{ fontSize: 12, fill: '#9494BD' }} axisLine={false} tickLine={false} width={32} />
                <Tooltip
                  contentStyle={{ backgroundColor: 'rgba(20,20,42,0.9)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 10, color: '#ECECFC' }}
                  labelStyle={{ color: '#B4B4D0' }}
                />
                <Line type="monotone" dataKey="weight_kg" stroke="#7C3AED" strokeWidth={2} dot={{ fill: '#C084FC', r: 3 }} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}
    </div>
  )
}

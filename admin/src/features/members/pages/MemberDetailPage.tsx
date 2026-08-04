import { useParams, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { useMember } from '../hooks/useMembers'
import { ArrowLeft, Dumbbell, Scale, Phone, Calendar, MapPin, PhoneCall } from 'lucide-react'
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
    <div className="space-y-6">
      <button onClick={() => navigate('/members')} className="flex items-center gap-1 text-sm text-[#55557A] hover:text-[#B4B4D0]">
        <ArrowLeft className="w-4 h-4" /> Back to Members
      </button>

      {/* Profile header */}
      <div className="glass-card p-6 rounded-xl border border-white/10 shadow-sm">
        <div className="flex items-center gap-4">
          <div className="w-16 h-16 rounded-full bg-gradient-to-br from-[#7C3AED]/30 to-[#C084FC]/30 flex items-center justify-center">
            <span className="text-2xl font-bold text-[#C084FC]">
              {member.full_name.charAt(0)}
            </span>
          </div>
          <div>
            <h1 className="text-xl font-bold text-[#ECECFC]">{member.full_name}</h1>
            <p className="text-sm text-[#B4B4D0]">{member.email}</p>
            <p className="text-xs font-mono text-[#7C3AED] mt-1">{member.code}</p>
          </div>
        </div>
      </div>

      {/* Trainer assignment */}
      {trainerAssignment && (
        <div className="glass-card p-6 rounded-xl border border-white/10 shadow-sm">
          <h2 className="text-lg font-semibold mb-4 text-[#ECECFC]">Assigned Trainer</h2>
          <div className="flex items-center gap-3 cursor-pointer"
            onClick={() => navigate(`/trainers/${trainerAssignment.trainer_id}`)}
          >
            <div className="w-10 h-10 rounded-full bg-[#22C55E]/20 flex items-center justify-center">
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
      <div className="glass-card p-6 rounded-xl border border-white/10 shadow-sm">
        <h2 className="text-lg font-semibold mb-4 text-[#ECECFC]">Personal Information</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="flex items-center gap-3">
            <Phone className="w-4 h-4 text-[#55557A]" />
            <div>
              <p className="text-xs text-[#55557A]">Phone</p>
              <p className="text-sm text-[#ECECFC]">{member.phone || 'â€”'}</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <Calendar className="w-4 h-4 text-[#55557A]" />
            <div>
              <p className="text-xs text-[#55557A]">Date of Birth</p>
              <p className="text-sm text-[#ECECFC]">{member.date_of_birth || 'â€”'}</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <div className="w-4 h-4 flex items-center justify-center text-[#55557A]">
              <span className="text-xs font-bold">G</span>
            </div>
            <div>
              <p className="text-xs text-[#55557A]">Gender</p>
              <p className="text-sm text-[#ECECFC] capitalize">{member.gender || 'â€”'}</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <MapPin className="w-4 h-4 text-[#55557A]" />
            <div>
              <p className="text-xs text-[#55557A]">Address</p>
              <p className="text-sm text-[#ECECFC]">{fullAddress || 'â€”'}</p>
            </div>
          </div>
        </div>
        <div className="border-t border-white/10 mt-4 pt-4">
          <h3 className="text-sm font-semibold text-[#ECECFC] mb-3">Emergency Contact</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="flex items-center gap-3">
              <PhoneCall className="w-4 h-4 text-[#55557A]" />
              <div>
                <p className="text-xs text-[#55557A]">Contact Name</p>
                <p className="text-sm text-[#ECECFC]">{member.emergency_contact_name || 'â€”'}</p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <Phone className="w-4 h-4 text-[#55557A]" />
              <div>
                <p className="text-xs text-[#55557A]">Contact Phone</p>
                <p className="text-sm text-[#ECECFC]">{member.emergency_contact_phone || 'â€”'}</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <StatsCard title="Workouts" value={workoutCount ?? 0} icon={Dumbbell} />
        <StatsCard title="Measurements" value={measurements?.length ?? 0} icon={Scale} />
      </div>

      {/* Weight chart */}
      {measurements && measurements.length > 0 && (
        <div className="glass-card p-6 rounded-xl border border-white/10 shadow-sm">
          <h2 className="text-lg font-semibold mb-4 text-[#ECECFC]">Weight Progress</h2>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={measurements}>
                <CartesianGrid strokeDasharray="3 3" stroke="#2A2A45" />
                <XAxis
                  dataKey="measured_at"
                  tickFormatter={v => new Date(v).toLocaleDateString()}
                  tick={{ fontSize: 12, fill: '#55557A' }}
                />
                <YAxis tick={{ fontSize: 12, fill: '#55557A' }} />
                <Tooltip
                  contentStyle={{ backgroundColor: '#1C1C35', border: '1px solid #2A2A45', borderRadius: '8px', color: '#ECECFC' }}
                  labelStyle={{ color: '#B4B4D0' }}
                />
                <Line type="monotone" dataKey="weight_kg" stroke="#7C3AED" strokeWidth={2} dot={{ fill: '#C084FC', r: 4 }} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}
    </div>
  )
}

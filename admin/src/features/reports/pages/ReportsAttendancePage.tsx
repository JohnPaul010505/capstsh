import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { DailyCheckinTable } from '../components/DailyCheckinTable'
import { FeedbackTable } from '../components/FeedbackTable'

export default function ReportsAttendancePage() {
  const { data: attendanceData, isLoading: attendanceLoading } = useQuery({
    queryKey: ['reports-attendance-7days'],
    queryFn: async () => {
      const now = new Date()
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1)
      const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0)
      const { data } = await supabase
        .from('attendance')
        .select('member_id, check_in_date, check_in_time, profiles!attendance_member_id_fkey(full_name)')
        .gte('check_in_date', monthStart.toISOString().split('T')[0])
        .lte('check_in_date', monthEnd.toISOString().split('T')[0])

      const grouped: Record<string, { name: string; count: number; lastCheckIn: string }> = {}
      data?.forEach((a: any) => {
        const id = a.member_id
        if (!grouped[id]) grouped[id] = { name: a.profiles?.full_name ?? 'Unknown', count: 0, lastCheckIn: a.check_in_date }
        grouped[id].count++
        if (a.check_in_date > grouped[id].lastCheckIn) grouped[id].lastCheckIn = a.check_in_date
      })
      return Object.entries(grouped)
        .map(([id, v]) => ({ memberId: id, ...v }))
        .sort((a, b) => b.count - a.count)
    },
  })

  const { data: feedbackData, isLoading: feedbackLoading } = useQuery({
    queryKey: ['reports-feedback'],
    queryFn: async () => {
      const { data } = await supabase
        .from('trainer_feedback')
        .select('*, profiles!trainer_feedback_member_id_fkey(full_name)')
        .order('created_at', { ascending: false })
        .limit(50)
      return data ?? []
    },
  })

  return (
    <div className="space-y-6">
      <DailyCheckinTable data={attendanceData ?? []} isLoading={attendanceLoading} />
      <FeedbackTable data={feedbackData ?? []} isLoading={feedbackLoading} />
    </div>
  )
}

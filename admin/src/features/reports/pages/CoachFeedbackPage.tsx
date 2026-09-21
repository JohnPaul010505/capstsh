import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { FeedbackTable } from '../components/FeedbackTable'

export default function CoachFeedbackPage() {
  const { data, isLoading } = useQuery({
    queryKey: ['coach-feedback'],
    queryFn: async () => {
      const { data } = await supabase
        .from('trainer_feedback')
        .select('*, member:profiles!trainer_feedback_member_id_fkey(full_name), trainer:profiles!trainer_feedback_trainer_id_fkey(full_name)')
        .order('created_at', { ascending: false })
        .limit(50)
      return data ?? []
    },
  })

  const rated = (data ?? []).filter((f: any) => f.rating != null)
  const average = rated.length
    ? rated.reduce((sum: number, f: any) => sum + f.rating, 0) / rated.length
    : null

  return (
    <div className="space-y-3">
      {average != null && (
        <div className="glass-card p-4 rounded-xl flex items-center gap-3">
          <span className="text-2xl font-bold text-fg-strong">{average.toFixed(1)}</span>
          <span className="text-[#FFC107] text-lg tracking-wide">
            {'★'.repeat(Math.round(average))}
            <span className="text-fg-faint">{'★'.repeat(5 - Math.round(average))}</span>
          </span>
          <span className="text-xs text-fg-muted">
            average member rating · {rated.length} of {(data ?? []).length} feedback entries rated
          </span>
        </div>
      )}
      <FeedbackTable data={data ?? []} isLoading={isLoading} />
    </div>
  )
}

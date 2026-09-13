import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { FeedbackTable } from '../components/FeedbackTable'

export default function CoachFeedbackPage() {
  const { data, isLoading } = useQuery({
    queryKey: ['coach-feedback'],
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
    <div className="space-y-3">
      <FeedbackTable data={data ?? []} isLoading={isLoading} />
    </div>
  )
}

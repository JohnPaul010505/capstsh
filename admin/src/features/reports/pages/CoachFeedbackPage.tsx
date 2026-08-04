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
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-[#ECECFC]">Coach Feedback</h1>
        <p className="text-[#55557A] text-sm mt-1">Feedback given to members by their assigned trainers</p>
      </div>
      <FeedbackTable data={data ?? []} isLoading={isLoading} />
    </div>
  )
}

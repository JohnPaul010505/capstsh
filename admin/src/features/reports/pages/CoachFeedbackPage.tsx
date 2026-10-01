import { useQuery } from '@tanstack/react-query'
import { Star } from 'lucide-react'
import { supabase } from '@/lib/supabase'
import KpiCard from '@/components/KpiCard'
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
    /*
      A full-height flex column, the same shell the QR page uses. `main` is
      `flex-1 overflow-hidden`, so an auto-height stack under it simply runs off
      the bottom of the viewport - which is exactly what the old `space-y-3`
      page did. The table below is the `flex-1` child, so `useFitRows` has a real
      height budget to measure a whole page of rows from.
    */
    <div className="h-full min-h-0 flex flex-col gap-3">
      {/*
        HALF WIDTH, CENTRED - and a real KPI card.

        The average used to be one full-width strip of "4.1  stars  average
        member rating - 35 of 50 feedback entries rated", a single line with three
        unrelated pieces of text on it, stretched across 1,690px with 1,600px of
        empty card to the right of it. It is now the same component the four
        dashboard KPI cards use: icon tile, title, value, sub-line. Centred
        because a half-width card with 800px of gap to its right looks like a
        mistake, and centred at the same 52rem ceiling as the Member Distribution
        card so the two do not disagree.
      */}
      <div className="mx-auto w-full lg:w-1/2 lg:max-w-[52rem] shrink-0">
        <KpiCard
          title="Average Member Rating"
          value={average != null ? average.toFixed(1) : '—'}
          stars={average}
          sub={`${rated.length} of ${(data ?? []).length} feedback entries rated`}
          icon={Star}
          tone="amber"
          isLoading={isLoading}
        />
      </div>
      <FeedbackTable data={data ?? []} isLoading={isLoading} />
    </div>
  )
}

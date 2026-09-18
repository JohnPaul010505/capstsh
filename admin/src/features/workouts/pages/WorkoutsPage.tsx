import { useParams } from 'react-router-dom'
import { useWorkouts, useMemberWorkouts } from '../hooks/useWorkouts'

export default function WorkoutsPage() {
  const { memberId } = useParams()
  const { data: workouts, isLoading } = memberId ? useMemberWorkouts(memberId) : useWorkouts()

  return (
    <div className="space-y-4">
      {isLoading ? (
        <div className="text-center py-8 text-fg-muted">Loading...</div>
      ) : (
        <div className="glass-card rounded-xl overflow-hidden flex flex-col min-h-0">
          <div className="overflow-x-auto flex-1">
            <table className="w-full">
              <thead>
                <tr className="border-b border-line bg-overlay-5">
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Member</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Exercise</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Sets</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Reps</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Weight</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-fg-muted">Date</th>
                </tr>
              </thead>
              <tbody>
                {workouts?.map(w => (
                  <tr key={w.id} className="border-b border-line-soft last:border-0 hover:bg-[#7C3AED]/5 transition-colors">
                    <td className="px-3 py-2 text-sm font-medium text-fg-strong">
                      {w.profiles?.full_name ?? 'Unknown'}
                    </td>
                    <td className="px-3 py-2 text-sm text-fg">{w.exercise_name}</td>
                    <td className="px-3 py-2 text-sm text-fg">{w.sets ?? '-'}</td>
                    <td className="px-3 py-2 text-sm text-fg">{w.reps ?? '-'}</td>
                    <td className="px-3 py-2 text-sm text-fg">{w.weight ? `${w.weight} kg` : '-'}</td>
                    <td className="px-3 py-2 text-sm text-fg">
                      {new Date(w.logged_at).toLocaleDateString()}
                    </td>
                  </tr>
                ))}
                {workouts?.length === 0 && (
                  <tr><td colSpan={6} className="px-3 py-6 text-center text-fg-muted">No workouts logged</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  )
}

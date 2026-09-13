import { useParams } from 'react-router-dom'
import { useWorkouts, useMemberWorkouts } from '../hooks/useWorkouts'

export default function WorkoutsPage() {
  const { memberId } = useParams()
  const { data: workouts, isLoading } = memberId ? useMemberWorkouts(memberId) : useWorkouts()

  return (
    <div className="space-y-4">
      {isLoading ? (
        <div className="text-center py-8 text-[#55557A]">Loading...</div>
      ) : (
        <div className="glass-card rounded-xl border border-white/10 shadow-sm overflow-hidden flex flex-col min-h-0">
          <div className="overflow-x-auto flex-1">
            <table className="w-full">
              <thead>
                <tr className="border-b border-white/10 bg-white/5">
                  <th className="text-left px-3 py-2 text-sm font-medium text-[#55557A]">Member</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-[#55557A]">Exercise</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-[#55557A]">Sets</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-[#55557A]">Reps</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-[#55557A]">Weight</th>
                  <th className="text-left px-3 py-2 text-sm font-medium text-[#55557A]">Date</th>
                </tr>
              </thead>
              <tbody>
                {workouts?.map(w => (
                  <tr key={w.id} className="border-b border-white/5 last:border-0 hover:bg-[#7C3AED]/5 transition-colors">
                    <td className="px-3 py-2 text-sm font-medium text-[#ECECFC]">
                      {w.profiles?.full_name ?? 'Unknown'}
                    </td>
                    <td className="px-3 py-2 text-sm text-[#B4B4D0]">{w.exercise_name}</td>
                    <td className="px-3 py-2 text-sm text-[#B4B4D0]">{w.sets ?? '-'}</td>
                    <td className="px-3 py-2 text-sm text-[#B4B4D0]">{w.reps ?? '-'}</td>
                    <td className="px-3 py-2 text-sm text-[#B4B4D0]">{w.weight ? `${w.weight} kg` : '-'}</td>
                    <td className="px-3 py-2 text-sm text-[#B4B4D0]">
                      {new Date(w.logged_at).toLocaleDateString()}
                    </td>
                  </tr>
                ))}
                {workouts?.length === 0 && (
                  <tr><td colSpan={6} className="px-3 py-6 text-center text-[#55557A]">No workouts logged</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  )
}

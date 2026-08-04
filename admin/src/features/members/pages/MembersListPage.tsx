import { useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { useMembers } from '../hooks/useMembers'
import MemberTable from '../components/MemberTable'
import type { Profile } from '@/types'

export default function MembersListPage() {
  const [search, setSearch] = useState('')
  const [deleteTarget, setDeleteTarget] = useState<Profile | null>(null)
  const [deleting, setDeleting] = useState(false)
  const queryClient = useQueryClient()
  const { data: members, isLoading } = useMembers(search)

  const handleDelete = async () => {
    if (!deleteTarget) return
    setDeleting(true)
    try {
      const res = await fetch('/api/delete-user', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: deleteTarget.id }),
      })
      if (!res.ok) {
        const err = await res.json()
        throw new Error(err.error || 'Failed to delete user')
      }
      setDeleteTarget(null)
      queryClient.invalidateQueries({ queryKey: ['members'] })
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to delete')
    } finally {
      setDeleting(false)
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-[#ECECFC]">Members</h1>
      </div>

      <input
        placeholder="Search members..."
        value={search}
        onChange={e => setSearch(e.target.value)}
        className="w-full max-w-xs px-3 py-2 bg-white/[0.08] border border-white/10 rounded-lg text-sm text-[#ECECFC] focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50 focus:border-[#7C3AED] placeholder:text-[#55557A]"
      />

      {isLoading ? (
        <div className="text-center py-8 text-[#55557A]">Loading...</div>
      ) : (
        <MemberTable members={members ?? []} onDelete={setDeleteTarget} />
      )}

      {deleteTarget && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setDeleteTarget(null)}>
          <div className="glass-card rounded-xl shadow-xl max-w-sm w-full mx-4 p-6 border border-white/10" onClick={e => e.stopPropagation()}>
            <h2 className="text-lg font-bold text-[#ECECFC] mb-2">Delete Member?</h2>
            <p className="text-sm text-[#B4B4D0] mb-4">
              This will permanently delete <strong className="text-[#ECECFC]">{deleteTarget.full_name}</strong>'s account and all access. They will not be able to log in again.
            </p>
            <div className="flex justify-end gap-3">
              <button onClick={() => setDeleteTarget(null)} className="px-4 py-2 text-sm border border-white/10 rounded-lg text-[#B4B4D0] hover:bg-white/[0.08]">Cancel</button>
              <button onClick={handleDelete} disabled={deleting}
                className="px-4 py-2 text-sm bg-[#EF4444] text-white rounded-lg hover:bg-[#DC2626] disabled:opacity-50">
                {deleting ? 'Deleting...' : 'Delete'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

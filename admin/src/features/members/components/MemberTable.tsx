import { useNavigate } from 'react-router-dom'
import { Trash2 } from 'lucide-react'
import type { Profile } from '@/types'

interface MemberTableProps {
  members: Profile[]
  onDelete: (member: Profile) => void
}

export default function MemberTable({ members, onDelete }: MemberTableProps) {
  const navigate = useNavigate()

  return (
    <div className="glass-card rounded-xl border border-white/10 shadow-sm overflow-hidden">
      <table className="w-full">
        <thead>
          <tr className="border-b border-white/10 bg-white/5">
            <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Name</th>
            <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Code</th>
            <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Email</th>
            <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Phone</th>
            <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Joined</th>
            <th className="text-right px-4 py-3 text-sm font-medium text-[#55557A]">Actions</th>
          </tr>
        </thead>
        <tbody>
          {members.map(member => (
            <tr
              key={member.id}
              className="border-b border-white/5 last:border-0 hover:bg-[#7C3AED]/5 cursor-pointer transition-colors"
              onClick={() => navigate(`/members/${member.id}`)}
            >
              <td className="px-4 py-3 text-sm font-medium text-[#ECECFC]">{member.full_name}</td>
              <td className="px-4 py-3 text-sm font-mono font-medium text-[#7C3AED]">{member.code}</td>
              <td className="px-4 py-3 text-sm text-[#B4B4D0]">{member.email}</td>
              <td className="px-4 py-3 text-sm text-[#B4B4D0]">{member.phone || 'â€”'}</td>
              <td className="px-4 py-3 text-sm text-[#B4B4D0]">
                {new Date(member.created_at).toLocaleDateString()}
              </td>
              <td className="px-4 py-3 text-right">
                <button
                  onClick={e => { e.stopPropagation(); onDelete(member) }}
                  className="p-1 text-[#55557A] hover:text-[#EF4444]"
                  title="Delete"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </td>
            </tr>
          ))}
          {members.length === 0 && (
            <tr>
              <td colSpan={6} className="px-4 py-8 text-center text-[#55557A]">No members found</td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  )
}

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
    <div className="glass-card rounded-xl overflow-hidden">
      <table className="w-full">
        <thead>
          <tr className="border-b border-line bg-overlay-5">
            <th className="text-left px-4 py-3 text-sm font-medium text-fg-muted">Name</th>
            <th className="text-left px-4 py-3 text-sm font-medium text-fg-muted">Code</th>
            <th className="text-left px-4 py-3 text-sm font-medium text-fg-muted">Email</th>
            <th className="text-left px-4 py-3 text-sm font-medium text-fg-muted">Phone</th>
            <th className="text-left px-4 py-3 text-sm font-medium text-fg-muted">Joined</th>
            <th className="text-right px-4 py-3 text-sm font-medium text-fg-muted">Actions</th>
          </tr>
        </thead>
        <tbody>
          {members.map(member => (
            <tr
              key={member.id}
              className="border-b border-line-soft last:border-0 hover:bg-[#7C3AED]/5 cursor-pointer transition-colors"
              onClick={() => navigate(`/members/${member.id}`)}
            >
              <td className="px-4 py-3 text-sm font-medium text-fg-strong">{member.full_name}</td>
              <td className="px-4 py-3 text-sm font-mono font-medium text-[#7C3AED]">{member.code}</td>
              <td className="px-4 py-3 text-sm text-fg">{member.email}</td>
              <td className="px-4 py-3 text-sm text-fg">{member.phone || '—'}</td>
              <td className="px-4 py-3 text-sm text-fg">
                {new Date(member.created_at).toLocaleDateString()}
              </td>
              <td className="px-4 py-3 text-right">
                <button
                  onClick={e => { e.stopPropagation(); onDelete(member) }}
                  className="p-1 text-fg-muted hover:text-[#EF4444]"
                  title="Delete"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </td>
            </tr>
          ))}
          {members.length === 0 && (
            <tr>
              <td colSpan={6} className="px-4 py-8 text-center text-fg-muted">No members found</td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  )
}

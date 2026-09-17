import { useState } from 'react'
import { useAuth } from '@/features/auth/hooks/useAuth'
import { supabase } from '@/lib/supabase'

export default function SettingsPage() {
  const { profile, refreshProfile } = useAuth()
  const [editing, setEditing] = useState(false)
  const [name, setName] = useState(profile?.full_name ?? '')
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState<string | null>(null)

  const startEdit = () => {
    setName(profile?.full_name ?? '')
    setEditing(true)
    setMessage(null)
  }

  const cancelEdit = () => {
    setEditing(false)
    setName(profile?.full_name ?? '')
    setMessage(null)
  }

  const saveName = async () => {
    if (!profile?.id) return
    const trimmed = name.trim()
    if (!trimmed) return
    setSaving(true)
    setMessage(null)
    const { error } = await supabase
      .from('profiles')
      .update({ full_name: trimmed })
      .eq('id', profile.id)

    if (error) {
      setMessage('Failed to update name')
    } else {
      await refreshProfile()
      setEditing(false)
      setMessage('Name updated')
    }
    setSaving(false)
  }

  return (
    <div className="space-y-3">
      <div className="glass-card p-4 rounded-xl border border-white/10 shadow-sm max-w-lg">
        <h2 className="text-base font-semibold mb-3 text-[#ECECFC]">Admin Profile</h2>
        <div className="space-y-2">
          <div>
            <label className="block text-sm font-medium text-[#55557A]">Name</label>
            {editing ? (
              <div className="flex items-center gap-2 mt-1">
                <input
                  value={name}
                  onChange={e => setName(e.target.value)}
                  className="flex-1 px-2.5 py-1.5 text-sm rounded-md bg-white/[0.08] border border-white/10 text-[#ECECFC] focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50"
                  placeholder="Enter name"
                />
                <button
                  onClick={saveName}
                  disabled={saving || !name.trim()}
                  className="px-3 py-1.5 text-xs font-medium rounded-md bg-[#7C3AED] text-white hover:bg-[#6D28D9] disabled:opacity-50"
                >
                  {saving ? 'Saving...' : 'Save'}
                </button>
                <button
                  onClick={cancelEdit}
                  className="px-3 py-1.5 text-xs font-medium rounded-md border border-white/10 text-[#B4B4D0] hover:bg-white/[0.06]"
                >
                  Cancel
                </button>
              </div>
            ) : (
              <div className="flex items-center gap-2 mt-1">
                <p className="text-sm text-[#ECECFC]">{profile?.full_name}</p>
                <button
                  onClick={startEdit}
                  className="text-xs font-medium px-2.5 py-1 rounded-md border border-white/10 text-[#B4B4D0] hover:bg-white/[0.06]"
                >
                  Edit
                </button>
              </div>
            )}
            {message && <p className="text-xs mt-1 text-[#4ADE80]">{message}</p>}
          </div>
          <div>
            <label className="block text-sm font-medium text-[#55557A]">Email</label>
            <p className="text-sm text-[#ECECFC]">{profile?.email}</p>
          </div>
          <div>
            <label className="block text-sm font-medium text-[#55557A]">Role</label>
            <p className="text-sm text-[#ECECFC] capitalize">{profile?.role}</p>
          </div>
        </div>
      </div>
    </div>
  )
}

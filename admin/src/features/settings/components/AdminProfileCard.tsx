import { useState } from 'react'
import { useAuth } from '@/features/auth/hooks/useAuth'
import { supabase } from '@/lib/supabase'

/**
 * The admin's own name, email and role, with the name editable in place.
 *
 * This exists as its own component because the profile is now reachable from two
 * places: the `/settings` page, and the menu that opens when the admin clicks
 * their name in the header. Those are the same three fields and the same save
 * path, and the previous version - a card written straight into `SettingsPage` -
 * would have meant either a second copy that drifts or a settings page with no
 * route of its own.
 *
 * `bare` drops the glass card. Inside the header menu the panel is already a
 * glass card, and a card inside a card reads as a border around a border; on the
 * settings page the card is the surface and stays.
 */
export default function AdminProfileCard({ bare = false }: { bare?: boolean }) {
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
    <div className={bare ? 'p-4' : 'glass-card p-4 rounded-xl max-w-lg'}>
      <h2 className="text-base font-semibold mb-3 text-fg-strong">Admin Profile</h2>
      <div className="space-y-2">
        <div>
          <label className="block text-sm font-medium text-fg-muted">Name</label>
          {editing ? (
            <div className="flex items-center gap-2 mt-1">
              <input
                value={name}
                onChange={e => setName(e.target.value)}
                className="flex-1 min-w-0 px-2.5 py-1.5 text-sm rounded-md bg-overlay-8 border border-line text-fg-strong focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50"
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
                className="px-3 py-1.5 text-xs font-medium rounded-md border border-line text-fg hover:bg-overlay-6"
              >
                Cancel
              </button>
            </div>
          ) : (
            <div className="flex items-center gap-2 mt-1">
              <p className="text-sm text-fg-strong">{profile?.full_name}</p>
              <button
                onClick={startEdit}
                className="text-xs font-medium px-2.5 py-1 rounded-md bg-[#7C3AED] text-white hover:bg-[#6D28D9]"
              >
                Edit
              </button>
            </div>
          )}
          {message && <p className="text-xs mt-1 text-accent-green">{message}</p>}
        </div>
        <div>
          <label className="block text-sm font-medium text-fg-muted">Email</label>
          <p className="text-sm text-fg-strong break-all">{profile?.email}</p>
        </div>
        <div>
          <label className="block text-sm font-medium text-fg-muted">Role</label>
          <p className="text-sm text-fg-strong capitalize">{profile?.role}</p>
        </div>
      </div>
    </div>
  )
}
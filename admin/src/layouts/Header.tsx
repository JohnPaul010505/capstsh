import { useState, useRef, useEffect } from 'react'
import { createPortal } from 'react-dom'
import { useAuth } from '@/features/auth/hooks/useAuth'
import { supabase } from '@/lib/supabase'
import { Bell, ChevronDown, LogOut } from 'lucide-react'
import { Link } from 'react-router-dom'
import ThemeToggle from '@/components/ThemeToggle'
import AdminProfileCard from '@/features/settings/components/AdminProfileCard'
import ConfirmDialog from '@/components/ConfirmDialog'

interface HeaderProps {
  title: string
}

export default function Header({ title }: HeaderProps) {
  const { profile, signOut } = useAuth()
  const [notificationDropdownOpen, setNotificationDropdownOpen] = useState(false)
  const dropdownRef = useRef<HTMLDivElement>(null)
  const buttonRef = useRef<HTMLButtonElement>(null)
  // The admin's own name is the account menu: it opens the settings card that
  // used to be its own sidebar destination, with Sign Out underneath it. Both
  // moved out of the sidebar together, so an admin has exactly one place that
  // answers "who am I and how do I leave".
  const [profileMenuOpen, setProfileMenuOpen] = useState(false)
  const [showLogout, setShowLogout] = useState(false)
  const profileBtnRef = useRef<HTMLButtonElement>(null)
  const profileMenuRef = useRef<HTMLDivElement>(null)
  const [profileMenuStyle, setProfileMenuStyle] = useState({})
  const [notifications, setNotifications] = useState<Array<{
    id: string
    title: string
    body: string
    read: boolean
    created_at: string
    profiles?: { full_name: string }
  }>>([])
  const [dropdownStyle, setDropdownStyle] = useState({})

  // One handler for both menus. Each closes on a mousedown that is outside its
  // own panel AND outside its own trigger, so clicking the name does not also
  // register as an outside click that closes what it just opened.
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as HTMLElement
      if (notificationDropdownOpen) {
        const inPanel = dropdownRef.current?.contains(target)
        const onTrigger = buttonRef.current?.contains(target)
        if (!inPanel && !onTrigger) setNotificationDropdownOpen(false)
      }
      if (profileMenuOpen) {
        const inPanel = profileMenuRef.current?.contains(target)
        const onTrigger = profileBtnRef.current?.contains(target)
        if (!inPanel && !onTrigger) setProfileMenuOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [notificationDropdownOpen, profileMenuOpen])

  // Escape closes whichever menu is open, without disturbing the other.
  useEffect(() => {
    if (!notificationDropdownOpen && !profileMenuOpen) return
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key !== 'Escape') return
      setNotificationDropdownOpen(false)
      setProfileMenuOpen(false)
    }
    document.addEventListener('keydown', onKeyDown)
    return () => document.removeEventListener('keydown', onKeyDown)
  }, [notificationDropdownOpen, profileMenuOpen])

  // Anchor the notification panel under its bell...
  useEffect(() => {
    if (notificationDropdownOpen && buttonRef.current) {
      const rect = buttonRef.current.getBoundingClientRect()
      setDropdownStyle({
        position: 'fixed',
        top: `${rect.bottom + 8}px`,
        right: `${window.innerWidth - rect.right}px`,
      })
    }
  }, [notificationDropdownOpen])

  // ...and the account panel under the name. Both are portalled and fixed, so
  // `header` being a flex row with `overflow` on an ancestor cannot clip them.
  useEffect(() => {
    if (profileMenuOpen && profileBtnRef.current) {
      const rect = profileBtnRef.current.getBoundingClientRect()
      setProfileMenuStyle({
        position: 'fixed',
        top: `${rect.bottom + 8}px`,
        right: `${window.innerWidth - rect.right}px`,
      })
    }
  }, [profileMenuOpen])

  const fetchNotifications = async () => {
    const { data } = await supabase
      .from('notifications')
      .select('*, profiles!notifications_user_id_fkey(full_name)')
      .order('created_at', { ascending: false })
      .limit(10)
    setNotifications(data ?? [])
  }

  useEffect(() => {
    fetchNotifications()
    const channel = supabase
      .channel('notifications_header')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'notifications' },
        () => fetchNotifications()
      )
      .subscribe()
    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  const formatDate = (dateStr: string) => {
    const date = new Date(dateStr)
    const now = new Date()
    const diff = now.getTime() - date.getTime()
    const days = Math.floor(diff / (1000 * 60 * 60 * 24))
    const hours = Math.floor(diff / (1000 * 60 * 60))
    const minutes = Math.floor(diff / (1000 * 60))
    if (days > 0) return `${days}d ago`
    if (hours > 0) return `${hours}h ago`
    if (minutes > 0) return `${minutes}m ago`
    return 'Just now'
  }

  return (
    <header className="glass-chrome h-14 rounded-2xl flex items-center justify-between px-5">
      <h1 className="text-[30px] font-bold text-fg-strong">{title}</h1>
      <div className="flex items-center gap-3">
        <ThemeToggle />
        <div className="relative">
          <button
            ref={buttonRef}
            onClick={() => {
              setNotificationDropdownOpen(open => !open)
              // The outside-mousedown handler already closes the account menu
              // when the bell is clicked, but a keyboard activation of the bell
              // fires no mousedown at all, so the two menus would overlap.
              setProfileMenuOpen(false)
            }}
            className="p-2 rounded-lg transition-colors cursor-pointer"
            aria-label="Notifications"
          >
            <Bell
              className={`w-5 h-5 transition-colors ${notificationDropdownOpen ? 'text-accent-purple' : 'text-fg-strong'}`}
              strokeWidth={2}
            />
          </button>
        </div>
        {/* The account trigger. It was an inert <span>, so nothing about it said
            it did anything - hence the ring, the caret and `aria-expanded`. */}
        <button
          ref={profileBtnRef}
          type="button"
          onClick={() => {
            setProfileMenuOpen(open => !open)
            setNotificationDropdownOpen(false)
          }}
          aria-haspopup="menu"
          aria-expanded={profileMenuOpen}
          aria-label="Account menu"
          className={`flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg transition-colors cursor-pointer ${
            profileMenuOpen ? 'bg-overlay-10 text-fg-strong' : 'text-fg hover:bg-overlay-6'
          }`}
        >
          <span className="text-sm">{profile?.full_name || 'System Admin'}</span>
          <ChevronDown
            className={`w-4 h-4 transition-transform duration-200 ${profileMenuOpen ? 'rotate-180' : ''}`}
            strokeWidth={2}
          />
        </button>
      </div>
      {notificationDropdownOpen && createPortal(
        <div
          ref={dropdownRef}
          className="w-80 glass-card rounded-xl z-50 overflow-hidden"
          style={dropdownStyle}
        >
          <div className="px-4 py-3 border-b border-line flex items-center justify-between">
            <h2 className="font-semibold text-fg-strong">Recent Notifications</h2>
            <span className="px-2 py-0.5 rounded-full text-xs font-medium bg-[#7C3AED] text-white">
              {`Total:${notifications.length}`}
            </span>
          </div>
          <div className="max-h-96 overflow-y-auto">
            {notifications.length === 0 ? (
              <div className="px-4 py-8 text-center text-sm text-fg-muted">No notifications yet</div>
            ) : (
              notifications.map(n => (
                <div
                  key={n.id}
                  className={`px-4 py-3 border-b border-line-soft hover:bg-[#7C3AED]/5 transition-colors ${
                    n.read ? '' : 'bg-[#7C3AED]/10'
                  }`}
                >
                  <p className="text-sm font-medium text-fg-strong">{n.title}</p>
                  <p className="text-sm text-fg mt-1 line-clamp-2">{n.body}</p>
                  <div className="flex items-center justify-between mt-2">
                    <span className="text-xs text-fg-muted">{n.profiles?.full_name ? `- ${n.profiles.full_name}` : '- Admin'}</span>
                    <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                      n.read ? 'bg-[#22C55E]/15 text-accent-green' : 'bg-[#F59E0B]/15 text-accent-amber'
                    }`}>
                      {n.read ? 'Read' : 'Unread'}
                    </span>
                  </div>
                  <p className="text-xs text-fg-muted mt-1">{formatDate(n.created_at)}</p>
                </div>
              ))
            )}
          </div>
          <div className="px-4 py-2 border-t border-line">
            <Link
              to="/notifications"
              onClick={() => setNotificationDropdownOpen(false)}
              className="text-sm text-accent-purple hover:underline"
            >
              View all notifications
            </Link>
          </div>
        </div>,
        document.body
      )}

      {/* The account menu: the settings card the sidebar used to link to, with
          Sign Out underneath it. `role="menu"`/`role="menuitem"` are on the
          container and the one item, and the panel is `w-[22rem]` so the card -
          which is `max-w-lg` on the settings page - fills it instead of
          overflowing the panel. */}
      {profileMenuOpen && createPortal(
        <div
          ref={profileMenuRef}
          role="menu"
          aria-label="Account"
          className="w-[22rem] glass-card rounded-xl z-50 overflow-hidden"
          style={profileMenuStyle}
        >
          <AdminProfileCard bare />
          <div className="px-3 pb-3">
            <button
              type="button"
              role="menuitem"
              onClick={() => { setProfileMenuOpen(false); setShowLogout(true) }}
              className="flex items-center gap-2 w-full px-3 py-2 text-sm font-medium rounded-lg bg-[#EF4444] text-white hover:bg-[#DC2626]"
            >
              <LogOut className="w-4 h-4 shrink-0" strokeWidth={2} />
              Sign Out
            </button>
          </div>
        </div>,
        document.body
      )}

      {/* The confirmation moved here with the button. It is a portal at z-[70],
          above the menu it was opened from. */}
      <ConfirmDialog
        open={showLogout}
        title="Sign Out"
        message="Are you sure you want to sign out?"
        onConfirm={() => { setShowLogout(false); signOut() }}
        onCancel={() => setShowLogout(false)}
      />
    </header>
  )
}

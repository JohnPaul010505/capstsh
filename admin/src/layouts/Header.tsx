import { useState, useRef, useEffect } from 'react'
import { createPortal } from 'react-dom'
import { useAuth } from '@/features/auth/hooks/useAuth'
import { supabase } from '@/lib/supabase'
import { Bell } from 'lucide-react'
import { Link } from 'react-router-dom'
import ThemeToggle from '@/components/ThemeToggle'

interface HeaderProps {
  title: string
}

export default function Header({ title }: HeaderProps) {
  const { profile } = useAuth()
  const [notificationDropdownOpen, setNotificationDropdownOpen] = useState(false)
  const dropdownRef = useRef<HTMLDivElement>(null)
  const buttonRef = useRef<HTMLButtonElement>(null)
  const [notifications, setNotifications] = useState<Array<{
    id: string
    title: string
    body: string
    read: boolean
    created_at: string
    profiles?: { full_name: string }
  }>>([])
  const [dropdownStyle, setDropdownStyle] = useState({})

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        const target = event.target as HTMLElement
        if (buttonRef.current?.contains(target)) return
        setNotificationDropdownOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

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
            onClick={() => setNotificationDropdownOpen(!notificationDropdownOpen)}
            className="p-2 rounded-lg transition-colors cursor-pointer"
            aria-label="Notifications"
          >
            <Bell
              className={`w-5 h-5 transition-colors ${notificationDropdownOpen ? 'text-accent-purple' : 'text-fg-strong'}`}
              strokeWidth={2}
            />
          </button>
        </div>
        <span className="text-sm text-fg">{profile?.full_name || 'System Admin'}</span>
      </div>
      {notificationDropdownOpen && createPortal(
        <div
          ref={dropdownRef}
          className="w-80 glass-card rounded-xl z-50 overflow-hidden"
          style={dropdownStyle}
        >
          <div className="px-4 py-3 border-b border-line flex items-center justify-between">
            <h2 className="font-semibold text-fg-strong">Recent Notifications</h2>
            <span className="px-2 py-0.5 rounded-full text-xs font-medium bg-[#7C3AED]/15 text-accent-purple">
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
    </header>
  )
}

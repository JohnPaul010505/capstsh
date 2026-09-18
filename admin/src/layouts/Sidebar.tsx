import { useState } from 'react'
import { NavLink } from 'react-router-dom'
import { cn } from '@/lib/utils'
import { useAuth } from '@/features/auth/hooks/useAuth'
import ConfirmDialog from '@/components/ConfirmDialog'
import {
  LayoutDashboard, Users, Dumbbell, CreditCard,
  CalendarCheck, BarChart3, QrCode, Settings, LogOut, MessageSquare, Bell,
} from 'lucide-react'

const navItems = [
  { to: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { to: '/members', label: 'Members', icon: Users },
  { to: '/trainers', label: 'Trainers', icon: Dumbbell },
  { to: '/memberships', label: 'Memberships', icon: CreditCard },
  { to: '/qr', label: 'QR', icon: QrCode },
  { to: '/attendance', label: 'Attendance', icon: CalendarCheck },
  { to: '/reports/inactive', label: 'Reports', icon: BarChart3, end: true },
  { to: '/reports/feedback', label: 'Feedback', icon: MessageSquare },
  { to: '/notifications', label: 'Notifications', icon: Bell },
  { to: '/settings', label: 'Settings', icon: Settings },
]

// Sidebar shell: transparent-edge liquid glass, so no white border line shows.
const chromeBg = 'glass-chrome'

export default function Sidebar() {
  const { signOut } = useAuth()
  const [showLogout, setShowLogout] = useState(false)

  return (
    <aside
      className={cn(
        chromeBg,
        "flex flex-col overflow-hidden",
        "w-[180px] mx-2 mb-3 mt-20 rounded-[28px] h-[calc(100vh-56px)]"
      )}
    >
      <div className="h-10" />
      {/* Navigation */}
      <nav className="flex-1 px-3 space-y-5">
        {navItems.map(item => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.end}
            className={({ isActive }) => cn(
              "flex items-center gap-3 rounded-2xl transition-all duration-200 relative",
              isActive
                ? "bg-purple-600/80 border border-purple-400/30 text-white shadow-[0_0_25px_rgba(139,92,246,0.30),inset_0_1px_0_rgba(255,255,255,0.25)]"
                : "text-fg-faint hover:text-fg-strong hover:bg-overlay-5",
              "px-3 py-2"
            )}
          >
            {({ isActive }) => (
              <>
                <item.icon className={cn("w-[18px] h-[18px] shrink-0", isActive ? "text-white" : "text-[#7C3AED]")} strokeWidth={2} />
                <span className="text-[13px] whitespace-nowrap">{item.label}</span>
              </>
            )}
          </NavLink>
        ))}
      </nav>

      {/* Bottom section */}
      <div className="px-3 pb-3 pt-5">
        <button onClick={() => setShowLogout(true)} className={cn(
          "flex items-center gap-3 rounded-2xl transition-all duration-200 w-full bg-[#EF4444] text-white hover:bg-[#DC2626]",
          "px-3 py-2"
        )}>
          <LogOut className="w-[18px] h-[18px] shrink-0" strokeWidth={2} />
          <span className="text-[13px] whitespace-nowrap">Sign Out</span>
        </button>
      </div>

      <ConfirmDialog
        open={showLogout}
        title="Sign Out"
        message="Are you sure you want to sign out?"
        onConfirm={() => { setShowLogout(false); signOut() }}
        onCancel={() => setShowLogout(false)}
      />
    </aside>
  )
}

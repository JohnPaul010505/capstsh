import { useState } from 'react'
import { NavLink } from 'react-router-dom'
import { cn } from '@/lib/utils'
import { useAuth } from '@/features/auth/hooks/useAuth'
import ConfirmDialog from '@/components/ConfirmDialog'
import {
  LayoutDashboard, Users, Dumbbell, CreditCard,
  CalendarCheck, BarChart3, QrCode, Settings, LogOut, MessageSquare,
} from 'lucide-react'

const navItems = [
  { to: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { to: '/members', label: 'Members', icon: Users },
  { to: '/trainers', label: 'Trainers', icon: Dumbbell },
  { to: '/memberships', label: 'Memberships', icon: CreditCard },
  { to: '/qr', label: 'QR', icon: QrCode },
  { to: '/attendance', label: 'Attendance', icon: CalendarCheck },
  { to: '/reports/inactive', label: 'Reports', icon: BarChart3, end: true },
  { to: '/reports/feedback', label: 'Coach Feedback', icon: MessageSquare },
  { to: '/settings', label: 'Settings', icon: Settings },
]

const pillBg = 'bg-[#0F0F1E] border border-white/10 shadow-[0_0_20px_rgba(124,58,237,0.08)]'

export default function Sidebar() {
  const { signOut } = useAuth()
  const [showLogout, setShowLogout] = useState(false)

  return (
    <aside
      className={cn(
        pillBg,
        "flex flex-col overflow-hidden",
        "w-[180px] mx-2 mb-0 mt-20 rounded-[36px] h-[calc(100vh-56px)]"
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
                ? "bg-gradient-to-r from-[#7C3AED] to-[#6D28D9] text-white shadow-[0_0_12px_rgba(124,58,237,0.35)]"
                : "text-[#8A8AB0] hover:text-white hover:bg-white/5",
              "px-3 py-2"
            )}
          >
            {({ isActive }) => (
              <>
                <item.icon className={cn("w-[18px] h-[18px] shrink-0", isActive ? "text-white" : "text-[#7A7AA0]")} strokeWidth={2} />
                <span className="text-[13px] whitespace-nowrap">{item.label}</span>
              </>
            )}
          </NavLink>
        ))}
      </nav>

      {/* Bottom section */}
      <div className="px-3 pb-10 pt-5">
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

import { NavLink } from 'react-router-dom'
import { cn } from '@/lib/utils'
import {
  LayoutDashboard, Users, Dumbbell, CreditCard,
  CalendarCheck, BarChart3, QrCode, MessageSquare, Bell,
  TrendingUp,
} from 'lucide-react'

// Settings and Sign Out are NOT here. Both live in the menu behind the admin's
// name in the header: the sidebar is navigation between sections of the app, and
// "edit your own display name" and "log out" are neither. A settings entry in a
// list of ten destinations also implied a settings page worth a destination of
// its own, which it is not - it is one card.
//
// The `/settings` route is still registered in App.tsx, so the URL keeps working.
const navItems = [
  { to: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { to: '/members', label: 'Members', icon: Users },
  { to: '/trainers', label: 'Trainers', icon: Dumbbell },
  { to: '/memberships', label: 'Memberships', icon: CreditCard },
  { to: '/qr', label: 'QR', icon: QrCode },
  { to: '/attendance', label: 'Attendance', icon: CalendarCheck },
  { to: '/reports/inactive', label: 'Reports', icon: BarChart3, end: true },
  { to: '/reports/feedback', label: 'Feedback', icon: MessageSquare },
  { to: '/predictions', label: 'Predictions', icon: TrendingUp },
  { to: '/notifications', label: 'Notifications', icon: Bell },
]

// Sidebar shell: transparent-edge liquid glass, so no white border line shows.
const chromeBg = 'glass-chrome'

export default function Sidebar() {
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
    </aside>
  )
}

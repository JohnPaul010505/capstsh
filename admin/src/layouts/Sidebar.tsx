import { useState } from 'react'
import { NavLink } from 'react-router-dom'
import { cn } from '@/lib/utils'
import { useSidebar } from '@/contexts/SidebarContext'
import { useAuth } from '@/features/auth/hooks/useAuth'
import ConfirmDialog from '@/components/ConfirmDialog'
import {
  LayoutDashboard, Users, Dumbbell, CreditCard,
  CalendarCheck, BarChart3, TrendingUp, QrCode, Settings, LogOut, MessageSquare,
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
  { to: '/predictions', label: 'Predictions', icon: TrendingUp },
  { to: '/settings', label: 'Settings', icon: Settings },
]

const gradientBg = 'bg-[#0D0D1A]/60 backdrop-blur-xl'

export default function Sidebar() {
  const { collapsed, setCollapsed } = useSidebar()
  const { signOut } = useAuth()
  const [showLogout, setShowLogout] = useState(false)

  return (
    <aside
      onMouseEnter={() => setCollapsed(false)}
      onMouseLeave={() => setCollapsed(true)}
      className={cn(
        gradientBg,
        "border-r border-white/10 flex flex-col transition-all duration-300 overflow-hidden shadow-[2px_0_20px_rgba(124,58,237,0.08)]",
        collapsed ? "w-16" : "w-60"
      )}
    >
      {/* Logo area */}
      <div className="h-14 flex items-center shrink-0 px-4 border-b border-[#7C3AED]/10">
        <div className="flex items-center gap-2.5">
          <div className="w-10 h-10 rounded-lg flex items-center justify-center shrink-0 overflow-hidden">
            <img src="/logo.png" alt="Logo" className="w-full h-full object-contain" />
          </div>
          
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 py-3 space-y-1 px-2">
        {navItems.map(item => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.end}
            className={({ isActive }) => cn(
              "flex items-center gap-3 px-3 py-2.5 text-sm rounded-lg transition-all duration-200 group relative",
              isActive
                ? "text-[#C084FC] font-semibold bg-[#7C3AED]/15"
                : "text-[#7070A0] hover:text-[#B4B4D0] hover:bg-white/5"
            )}
          >
            {({ isActive }) => (
              <>
                {/* Active left accent bar */}
                {isActive && (
                  <div className="absolute left-0 top-1/2 -translate-y-1/2 w-[3px] h-5 rounded-r-full bg-gradient-to-b from-[#7C3AED] to-[#C084FC] shadow-[0_0_6px_rgba(124,58,237,0.3)]" />
                )}
                <div className={cn(
                  "w-6 h-6 rounded-md flex items-center justify-center shrink-0 transition-all duration-200",
                  isActive ? "bg-[#7C3AED]/20" : "group-hover:bg-[#7C3AED]/10"
                )}>
                  <item.icon className={cn(
                    "w-5 h-5 transition-colors duration-200",
                    isActive ? "text-[#C084FC]" : "text-[#55557A] group-hover:text-[#B4B4D0]"
                  )} />
                </div>
                <span className={cn(
                  "whitespace-nowrap transition-all duration-200",
                  collapsed ? "max-w-0 opacity-0 overflow-hidden" : "max-w-32 opacity-100"
                )}>{item.label}</span>
                {isActive && (
                  <div className={cn(
                    "ml-auto transition-all duration-200",
                    collapsed ? "opacity-0" : "opacity-100"
                  )}>
                    <div className="w-1.5 h-1.5 rounded-full bg-[#C084FC]" />
                  </div>
                )}
              </>
            )}
          </NavLink>
        ))}
      </nav>

      {/* Bottom section */}
      <div className="border-t border-[#7C3AED]/10 px-3 py-3">
        <button onClick={() => setShowLogout(true)} className={cn(
          "flex items-center gap-3 px-2 py-2 rounded-lg text-[#EF4444]/70 text-sm transition-all duration-200 w-full",
          collapsed ? "justify-center" : ""
        )}>
          <LogOut className="w-4 h-4" />
          <span className={cn(
            "whitespace-nowrap transition-all duration-200",
            collapsed ? "max-w-0 opacity-0 overflow-hidden" : "max-w-32 opacity-100"
          )}>Sign Out</span>
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

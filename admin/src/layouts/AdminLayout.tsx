import { type ReactNode } from 'react'
import { useLocation } from 'react-router-dom'
import Sidebar from './Sidebar'
import Header from './Header'
import AppBackground from '@/components/AppBackground'

const ROUTE_TITLES: Record<string, string> = {
  '/dashboard': 'Dashboard',
  '/members': 'Members',
  '/trainers': 'Trainers',
  '/memberships': 'Memberships',
  '/predictions': 'Predictions',
  '/qr': 'QR',
  '/attendance': 'Attendance',
  '/reports': 'Reports',
  '/reports/inactive': 'Reports',
  '/reports/feedback': 'Coach Feedback',
  '/notifications': 'Notifications',
  '/settings': 'Settings',
}

function getPageTitle(pathname: string): string {
  if (pathname.startsWith('/members/')) return 'Member Details'
  if (pathname.startsWith('/trainers/')) return 'Trainer Details'
  return ROUTE_TITLES[pathname] || 'Dashboard'
}

function LayoutInner({ children }: { children: ReactNode }) {
  const location = useLocation()
  const title = getPageTitle(location.pathname)

  return (
    <div className="relative flex h-screen overflow-hidden">
      <a href="#main-content" className="sr-only focus:not-sr-only focus:fixed focus:top-2 focus:left-2 focus:z-50 focus:px-4 focus:py-2 focus:rounded-lg focus:bg-[#7C3AED] focus:text-white focus:text-sm">Skip to content</a>
      {/* Futuristic neon background: shared component (also used by Login
          and the public QR enrollment page). */}
      <AppBackground />
      <div className="relative flex flex-col mr-4">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 z-50">
          <img
            src="/logo.png"
            alt="Logo"
            className="w-20 h-20 object-contain drop-shadow-[0_6px_14px_rgba(15,23,42,0.25)]"
          />
        </div>
        <Sidebar />
      </div>
      <div className="flex-1 flex flex-col overflow-hidden">
        <Header title={title} />
        <main id="main-content" className="flex-1 overflow-hidden pt-5 px-1 pb-3">
          {children}
        </main>
      </div>
    </div>
  )
}

export default function AdminLayout({ children }: { children: ReactNode }) {
  return <LayoutInner>{children}</LayoutInner>
}
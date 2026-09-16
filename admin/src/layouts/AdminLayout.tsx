import { type ReactNode } from 'react'
import { useLocation } from 'react-router-dom'
import Sidebar from './Sidebar'
import Header from './Header'

const ROUTE_TITLES: Record<string, string> = {
  '/dashboard': 'Dashboard',
  '/members': 'Members',
  '/trainers': 'Trainers',
  '/memberships': 'Memberships',
  '/qr': 'QR',
  '/attendance': 'Attendance',
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
    <div className="flex h-screen">
      <a href="#main-content" className="sr-only focus:not-sr-only focus:fixed focus:top-2 focus:left-2 focus:z-50 focus:px-4 focus:py-2 focus:rounded-lg focus:bg-[#7C3AED] focus:text-white focus:text-sm">Skip to content</a>
      <div className="fixed inset-0 bg-[#050B24] -z-30" aria-hidden="true" />
      <div className="pointer-events-none fixed inset-0 -z-20" aria-hidden="true">
        <div className="absolute -top-[30%] left-[25%] h-[600px] w-[900px] -rotate-[25deg] bg-gradient-to-r from-blue-600/20 via-indigo-600/20 to-purple-600/20 blur-[80px]" />
        <div className="absolute -bottom-[20%] right-[5%] h-[500px] w-[700px] rounded-full bg-purple-600/20 blur-[120px]" />
        <div className="absolute -top-[15%] right-[15%] h-[400px] w-[500px] rounded-full bg-blue-500/15 blur-[120px]" />
      </div>
      <div className="absolute inset-0 bg-[#050B24]/55 -z-10" aria-hidden="true" />
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,transparent_20%,rgba(3,5,18,0.45)_100%)] -z-5 pointer-events-none" aria-hidden="true" />
      <div className="relative flex flex-col mr-4">
        <div className="absolute top-3 left-1/2 -translate-x-1/2 z-50">
          <img src="/logo.png" alt="Logo" className="w-14 h-14 object-contain" />
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

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
    <div className="relative flex h-screen overflow-hidden">
      <a href="#main-content" className="sr-only focus:not-sr-only focus:fixed focus:top-2 focus:left-2 focus:z-50 focus:px-4 focus:py-2 focus:rounded-lg focus:bg-[#7C3AED] focus:text-white focus:text-sm">Skip to content</a>
      {/* ================================
          FUTURISTIC NEON BACKGROUND
          ================================ */}

      {/* Base background */}
      <div
        className="fixed inset-0 -z-30 bg-[#05091F]"
        aria-hidden="true"
      />

      {/* Main atmospheric background */}
      <div
        className="pointer-events-none fixed inset-0 -z-20 overflow-hidden"
        aria-hidden="true"
      >
        {/* =================================
            LARGE PURPLE LIGHT TRAIL - TOP LEFT
            ================================= */}
        <div
          className="
            absolute
            -left-[420px]
            -top-[420px]
            h-[850px]
            w-[1450px]
            rotate-[-18deg]
            rounded-[50%]
            bg-gradient-to-br
            from-purple-500/28
            via-indigo-500/14
            to-transparent
            blur-[3px]
            shadow-[0_0_60px_rgba(139,92,246,0.35),0_0_120px_rgba(139,92,246,0.18)]
          "
        />

        {/* Soft glow around top-left trail */}
        <div
          className="
            absolute
            -left-[300px]
            -top-[300px]
            h-[600px]
            w-[1000px]
            rounded-full
            bg-purple-600/10
            blur-[130px]
          "
        />

        {/* =================================
            BLUE LIGHT TRAIL - TOP RIGHT
            ================================= */}
        <div
          className="
            absolute
            -right-[500px]
            -top-[320px]
            h-[700px]
            w-[1300px]
            rotate-[12deg]
            rounded-[50%]
            bg-gradient-to-bl
            from-blue-500/28
            via-indigo-500/14
            to-transparent
            blur-[3px]
            shadow-[0_0_65px_rgba(59,130,246,0.35),0_0_130px_rgba(59,130,246,0.18)]
          "
        />

        {/* Blue atmospheric glow */}
        <div
          className="
            absolute
            right-[-120px]
            top-[-160px]
            h-[500px]
            w-[650px]
            rounded-full
            bg-blue-600/12
            blur-[140px]
          "
        />

        {/* =================================
            LARGE INDIGO SWEEP - CENTER
            ================================= */}
        <div
          className="
            absolute
            left-[15%]
            top-[5%]
            h-[850px]
            w-[1500px]
            rotate-[-8deg]
            rounded-[50%]
            bg-gradient-to-br
            from-indigo-500/16
            via-indigo-500/8
            to-transparent
            blur-[3px]
            shadow-[0_0_80px_rgba(99,102,241,0.22),0_0_160px_rgba(99,102,241,0.12)]
          "
        />

        {/* Center blue/purple atmosphere */}
        <div
          className="
            absolute
            left-[35%]
            top-[15%]
            h-[500px]
            w-[650px]
            rounded-full
            bg-indigo-600/10
            blur-[160px]
          "
        />

        {/* =================================
            PURPLE SWEEP - BOTTOM RIGHT
            ================================= */}
        <div
          className="
            absolute
            -right-[420px]
            -bottom-[480px]
            h-[900px]
            w-[1500px]
            rotate-[-15deg]
            rounded-[50%]
            bg-gradient-to-tl
            from-purple-500/30
            via-violet-500/14
            to-transparent
            blur-[3px]
            shadow-[0_0_70px_rgba(139,92,246,0.38),0_0_140px_rgba(139,92,246,0.20)]
          "
        />

        {/* Stronger bottom-right glow */}
        <div
          className="
            absolute
            right-[-100px]
            bottom-[-180px]
            h-[550px]
            w-[650px]
            rounded-full
            bg-purple-600/15
            blur-[150px]
          "
        />

        {/* =================================
            BLUE SWEEP - BOTTOM LEFT
            ================================= */}
        <div
          className="
            absolute
            -left-[500px]
            -bottom-[500px]
            h-[850px]
            w-[1400px]
            rotate-[12deg]
            rounded-[50%]
            bg-gradient-to-tr
            from-blue-500/28
            via-indigo-500/14
            to-transparent
            blur-[3px]
            shadow-[0_0_65px_rgba(59,130,246,0.35),0_0_130px_rgba(59,130,246,0.18)]
          "
        />

        {/* Bottom-left blue glow */}
        <div
          className="
            absolute
            left-[-150px]
            bottom-[-150px]
            h-[450px]
            w-[550px]
            rounded-full
            bg-blue-600/10
            blur-[140px]
          "
        />

        {/* =================================
            SMALL PURPLE LIGHT SOURCE
            ================================= */}
        <div
          className="
            absolute
            left-[42%]
            top-[-100px]
            h-[280px]
            w-[400px]
            rounded-full
            bg-purple-500/12
            blur-[110px]
          "
        />

        {/* =================================
            SMALL BLUE LIGHT SOURCE
            ================================= */}
        <div
          className="
            absolute
            right-[25%]
            top-[10%]
            h-[260px]
            w-[350px]
            rounded-full
            bg-blue-500/10
            blur-[110px]
          "
        />
      </div>

      {/* =================================
          DARK VIGNETTE
          Keeps the center readable
          ================================= */}
      <div
        className="
          pointer-events-none
          fixed
          inset-0
          -z-10
          bg-[radial-gradient(circle_at_center,transparent_25%,rgba(2,5,20,0.55)_100%)]
        "
        aria-hidden="true"
      />
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

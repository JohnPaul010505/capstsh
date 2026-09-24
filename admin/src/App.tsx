import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import { Routes, Route, Navigate, useNavigate, useLocation } from 'react-router-dom'
import { AuthProvider, useAuth } from '@/features/auth/hooks/useAuth'
import type { Profile } from '@/types'
import LoginPage from '@/features/auth/pages/LoginPage'
import AdminLayout from '@/layouts/AdminLayout'
import DashboardPage from '@/features/dashboard/pages/DashboardPage'
import MembersListPage from '@/features/members/pages/MembersListPage'
import MemberDetailPage from '@/features/members/pages/MemberDetailPage'
import TrainersListPage from '@/features/trainers/pages/TrainersListPage'
import TrainerDetailPage from '@/features/trainers/pages/TrainerDetailPage'
import AttendancePage from '@/features/attendance/pages/AttendancePage'
import WorkoutsPage from '@/features/workouts/pages/WorkoutsPage'
import MembershipsPage from '@/features/memberships/pages/MembershipsPage'
import ReportsPage from '@/features/reports/pages/ReportsPage'
import InactiveReportPage from '@/features/reports/pages/InactiveReportPage'
import CoachFeedbackPage from '@/features/reports/pages/CoachFeedbackPage'
import QRPage from '@/features/qr/pages/QRPage'
import NotificationsPage from '@/features/notifications/pages/NotificationsPage'
import SettingsPage from '@/features/settings/pages/SettingsPage'
import PredictionsPage from '@/features/predictions/pages/PredictionsPage'

/** How long each login<->dashboard handoff animation runs (ms). */
const LOGIN_EXIT_MS = 750
const LOGIN_ENTER_MS = 750

type Handoff = 'none' | 'exit' | 'enter'

function DashboardShell() {
  return (
    <AdminLayout>
      <Routes>
        <Route path="/" element={<Navigate to="/dashboard" replace />} />
        <Route path="/dashboard" element={<DashboardPage />} />
        <Route path="/members" element={<MembersListPage />} />
        <Route path="/members/:id" element={<MemberDetailPage />} />
        <Route path="/trainers" element={<TrainersListPage />} />
        <Route path="/trainers/:id" element={<TrainerDetailPage />} />
        <Route path="/attendance" element={<AttendancePage />} />
        <Route path="/workouts" element={<WorkoutsPage />} />
        <Route path="/memberships" element={<MembershipsPage />} />
        <Route path="/reports" element={<ReportsPage />} />
        <Route path="/reports/inactive" element={<InactiveReportPage />} />
        <Route path="/reports/feedback" element={<CoachFeedbackPage />} />
        <Route path="/predictions" element={<PredictionsPage />} />
        <Route path="/qr" element={<QRPage />} />
        <Route path="/notifications" element={<NotificationsPage />} />
        <Route path="/settings" element={<SettingsPage />} />
      </Routes>
    </AdminLayout>
  )
}

function AppRoutes() {
  const { profile, loading } = useAuth()
  const navigate = useNavigate()
  const [handoff, setHandoff] = useState<Handoff>('none')
  const prevAuth = useRef<{ profile: Profile | null; ready: boolean }>({
    profile: null,
    ready: false,
  })

  // Both wrappers are always present in the tree (the inactive one is hidden
  // with CSS). This keeps the LoginPage instance AND the DashboardShell
  // instance stable across every transition, so the exit split animates the
  // form the admin actually typed into and the reverse handoff reforms the
  // same card instead of remounting a fresh one.
  // Login is visible when signed out (idle) or during any active handoff.
  // Dashboard is visible when signed in (idle) or during any active handoff.
  // During a handoff both render so one can dissolve while the other fades in
  // behind it; at idle only the active screen is visible.
  const showLogin = profile === null || handoff !== 'none'
  const showDashboard = profile !== null || handoff !== 'none'

  const loginClass = showLogin
    ? handoff === 'exit'
        ? 'login-exit-overlay fixed inset-0 z-[60]'
        : handoff === 'enter'
            ? 'login-enter-overlay fixed inset-0 z-[60]'
            : undefined
    : 'hidden'

  const dashboardClass = showDashboard
    ? handoff === 'enter'
        ? 'app-fade-out'
        : 'app-fade-in'
    : 'hidden'

  // Detect the auth transition in a layout effect: it runs after the tree is
  // committed but BEFORE the browser paints, so the handoff class is already in
  // the DOM for the first frame in which the dashboard exists. That is what
  // removes the old black flash -- there is never a painted frame with neither
  // screen visible.
  //
  // This used to be a render-phase update, which React silently drops: with
  // StrictMode's double render pass the first (discarded) pass advanced the ref,
  // so the second pass saw no transition and the overlay never mounted.
  useLayoutEffect(() => {
    const ready = !loading
    const prev = prevAuth.current
    if (prev.ready === ready && prev.profile === profile) return

    const becameSignedIn = prev.ready && !prev.profile && profile !== null
    const becameSignedOut = prev.ready && prev.profile !== null && profile === null
    prevAuth.current = { profile, ready }

    // A newer transition supersedes a handoff still in flight.
    if (becameSignedIn) setHandoff('exit')
    else if (becameSignedOut) setHandoff('enter')
  }, [profile, loading])

  // Keyed ONLY on "handoff". A previous version of this effect depended on
  // "location.pathname", so navigating to /dashboard re-ran the effect and
  // clearTimeout'd the exit overlay (frozen UI until refresh).
  // useNavigate's identity is stable in react-router-dom, but we keep it out of
  // deps entirely via a ref so nothing here can be cancelled by a route change.
  const navigateRef = useRef(navigate)
  navigateRef.current = navigate

  const location = useLocation()

  useEffect(() => {
    if (handoff === 'none') return
    const timer = window.setTimeout(
      () => setHandoff('none'),
      handoff === 'exit' ? LOGIN_EXIT_MS : LOGIN_ENTER_MS,
    )
    if (handoff === 'exit' && window.location.pathname === '/login') {
      // /login has no route inside AdminLayout -- land on the dashboard.
      navigateRef.current('/dashboard', { replace: true })
    }
    return () => window.clearTimeout(timer)
  }, [handoff])

  if (loading) {
    return (
      <div className="min-h-screen bg-page-deep flex items-center justify-center text-fg-muted">
        Loading...
      </div>
    )
  }

  // Public access: guests who scan the enrollment QR land on /qr without an
  // account. Show the public enrollment form instead of the login gate.
  // (An in-flight login handoff animation takes precedence while running.)
  if (handoff === 'none' && profile === null && location.pathname === '/qr') {
    return <QRPage />
  }

  const loginAriaHidden = handoff !== 'none' ? 'true' : undefined

  return (
    <>
      <div className={dashboardClass}>
        <DashboardShell />
      </div>
      <div className={loginClass} aria-hidden={loginAriaHidden}>
        <LoginPage exiting={handoff === 'exit'} entering={handoff === 'enter'} />
      </div>
    </>
  )
}

export default function App() {
  return (
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>
  )
}

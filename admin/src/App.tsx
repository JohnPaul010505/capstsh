import { useEffect, useRef, useState } from 'react'
import { Routes, Route, Navigate, useLocation, useNavigate } from 'react-router-dom'
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

/** How long the login overlay stays mounted during the exit handoff (ms). */
const LOGIN_EXIT_MS = 750

function AppRoutes() {
  const { profile, loading } = useAuth()
  const location = useLocation()
  const navigate = useNavigate()
  const [loginExiting, setLoginExiting] = useState(false)
  // Last observed auth state — lets us tell "user just signed in in-app"
  // apart from "page loaded while a session was already stored" (a refresh
  // must NOT replay the exit animation).
  const prevAuth = useRef<{ profile: Profile | null; ready: boolean }>({
    profile: null,
    ready: false,
  })

  useEffect(() => {
    const ready = !loading
    const wasSignedOut = prevAuth.current.ready && !prevAuth.current.profile
    prevAuth.current = { profile, ready }

    if (wasSignedOut && profile && ready) {
      // /login has no route inside AdminLayout — land on the dashboard.
      if (location.pathname === '/login') {
        navigate('/dashboard', { replace: true })
      }
      setLoginExiting(true)
      const timer = window.setTimeout(() => setLoginExiting(false), LOGIN_EXIT_MS)
      return () => window.clearTimeout(timer)
    }
  }, [profile, loading, location.pathname, navigate])

  if (loading) {
    return <div className="min-h-screen bg-page-deep flex items-center justify-center text-fg-muted">Loading...</div>
  }

  if (!profile) return <LoginPage />

  return (
    <>
      {/* Dashboard fades in beneath the login overlay during the handoff. */}
      <div className="app-fade-in">
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
      </div>

      {/* Login card splitting apart on top of the incoming dashboard.
          z-[60] sits above the dashboard's z-50 floating logo. */}
      {loginExiting && (
        <div className="login-exit-overlay fixed inset-0 z-[60]" aria-hidden="true">
          <LoginPage exiting />
        </div>
      )}
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

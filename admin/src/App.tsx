import { Routes, Route, Navigate } from 'react-router-dom'
import { AuthProvider, useAuth } from '@/features/auth/hooks/useAuth'
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
import CoachFeedbackPage from '@/features/reports/pages/CoachFeedbackPage'
import PredictionsPage from '@/features/predictions/pages/PredictionsPage'
import QRPage from '@/features/qr/pages/QRPage'
import NotificationsPage from '@/features/notifications/pages/NotificationsPage'
import SettingsPage from '@/features/settings/pages/SettingsPage'

function AppRoutes() {
  const { profile, loading } = useAuth()
  const isQR = window.location.pathname === '/qr'

  if (loading) {
    return <div className="min-h-screen bg-[#0D0D1A] flex items-center justify-center text-[#55557A]">Loading...</div>
  }

  if (isQR) return <QRPage />

  if (!profile) return <LoginPage />

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
        <Route path="/reports/feedback" element={<CoachFeedbackPage />} />
        <Route path="/predictions" element={<PredictionsPage />} />
        <Route path="/qr" element={<QRPage />} />
        <Route path="/notifications" element={<NotificationsPage />} />
        <Route path="/settings" element={<SettingsPage />} />
      </Routes>
    </AdminLayout>
  )
}

export default function App() {
  return (
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>
  )
}

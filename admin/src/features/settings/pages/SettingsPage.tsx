import { useAuth } from '@/features/auth/hooks/useAuth'

export default function SettingsPage() {
  const { profile} = useAuth()

  return (
    <div className="space-y-3">
      <div className="glass-card p-4 rounded-xl border border-white/10 shadow-sm max-w-lg">
        <h2 className="text-base font-semibold mb-3 text-[#ECECFC]">Admin Profile</h2>
        <div className="space-y-2">
          <div>
            <label className="block text-sm font-medium text-[#55557A]">Name</label>
            <p className="text-sm text-[#ECECFC]">{profile?.full_name}</p>
          </div>
          <div>
            <label className="block text-sm font-medium text-[#55557A]">Email</label>
            <p className="text-sm text-[#ECECFC]">{profile?.email}</p>
          </div>
          <div>
            <label className="block text-sm font-medium text-[#55557A]">Role</label>
            <p className="text-sm text-[#ECECFC] capitalize">{profile?.role}</p>
          </div>
        </div>

        
      </div>
    </div>
  )
}

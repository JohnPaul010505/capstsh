import { useAuth } from '@/features/auth/hooks/useAuth'

export default function Header() {
  const { profile } = useAuth()

  return (
    <header className="h-14 bg-[#14142A]/60 backdrop-blur-xl border-b border-white/10 flex items-center justify-between px-4">
      <div />
      <div className="flex items-center gap-3">
        <span className="text-sm text-[#B4B4D0]">{profile?.full_name}</span>
      </div>
    </header>
  )
}

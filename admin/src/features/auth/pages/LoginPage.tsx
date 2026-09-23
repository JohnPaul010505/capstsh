import { useEffect, useState } from 'react'
import AppBackground from '@/components/AppBackground'
import { useAuth } from '../hooks/useAuth'
import { useTheme } from '@/contexts/ThemeContext'
import { Mail, Lock, Eye, EyeOff, ArrowRight } from 'lucide-react'

/** How long each brand silhouette stays centred before the swap (ms). */
const SWAP_MS = 3000

function Field({ label, type, value, onChange, icon, trailing }: {
  label: string
  type: string
  value: string
  onChange: (v: string) => void
  icon: React.ReactNode
  trailing?: React.ReactNode
}) {
  return (
    <div>
      <label className="block text-sm font-medium text-fg-strong mb-2">{label}</label>
      <div className="relative">
        <span className="absolute left-3.5 top-1/2 -translate-y-1/2 text-fg-muted pointer-events-none">
          {icon}
        </span>
        <input
          type={type}
          value={value}
          onChange={e => onChange(e.target.value)}
          required
          className={`w-full py-3 glass-input border rounded-lg text-fg-strong text-sm placeholder:text-fg-muted focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50 focus:border-[#7C3AED] ${trailing ? 'pl-11 pr-11' : 'pl-11 pr-4'}`}
        />
        {trailing && (
          <span className="absolute right-3.5 top-1/2 -translate-y-1/2">{trailing}</span>
        )}
      </div>
    </div>
  )
}

export default function LoginPage({ exiting = false, entering = false }: { exiting?: boolean; entering?: boolean }) {
  const { signIn } = useAuth()
  const { setTheme } = useTheme()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const [showWoman, setShowWoman] = useState(false)

  // Login always presents (and hands off to the dashboard) on the dark
  // neon theme so the backdrop matches through the whole transition.
  useEffect(() => {
    setTheme('dark')
  }, [setTheme])

  // Man <-> woman silhouette swap: each stays on stage for SWAP_MS, then
  // they trade places — man slides out to the left while the woman slides
  // in from the right (and vice-versa).
  useEffect(() => {
    const id = window.setInterval(() => setShowWoman(v => !v), SWAP_MS)
    return () => window.clearInterval(id)
  }, [])

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    setLoading(true)
    const err = await signIn(email, password)
    if (err) setError(err)
    setLoading(false)
  }

  return (
    <div className="min-h-screen flex items-center justify-center relative overflow-hidden p-4 sm:p-6">
      <AppBackground />

      {/* Split glass card */}
      <div className="w-full max-w-4xl glass-card shadow-[0_0_60px_rgba(124,58,237,0.28)] relative z-10 overflow-hidden md:grid md:grid-cols-2">
        {/* ============ LEFT — BRAND PANEL ============ */}
        <div
          className={`relative hidden md:flex flex-col items-center justify-center overflow-hidden min-h-[580px] ${
            exiting ? 'panel-exit-left' : entering ? 'panel-enter-left' : ''
          }`}
        >
          {/* base: deep navy (man phase) */}
          <div
            aria-hidden="true"
            className="absolute inset-0 bg-gradient-to-br from-[#0A0F22] via-[#0D1330] to-[#111A3F]"
          />
          {/* warm pink wash (woman phase) — crossfades over the navy */}
          <div
            aria-hidden="true"
            className={`brand-crossfade absolute inset-0 bg-gradient-to-br from-[#2D0F21] via-[#45152F] to-[#5A1D3C] transition-opacity duration-[1200ms] ease-in-out ${
              showWoman ? 'opacity-100' : 'opacity-0'
            }`}
          />

          {/* neon accents — violet set (man phase) */}
          <div
            aria-hidden="true"
            className={`brand-crossfade absolute inset-0 transition-opacity duration-1000 ease-in-out ${
              showWoman ? 'opacity-0' : 'opacity-100'
            }`}
          >
            <div className="absolute -top-24 -left-24 h-72 w-72 rotate-12 rounded-[50%] bg-gradient-to-br from-purple-500/25 via-indigo-500/12 to-transparent blur-2xl" />
            <div className="absolute -bottom-24 -right-16 h-80 w-80 bg-[radial-gradient(closest-side,rgba(139,92,246,0.32),transparent)]" />
            <div className="absolute -bottom-32 -left-20 h-72 w-72 bg-[radial-gradient(closest-side,rgba(59,130,246,0.22),transparent)]" />
          </div>
          {/* neon accents — rose set (woman phase). Kept clear of the
              silhouette's head; fuchsia/peach accents add variety while
              warm pink stays dominant. */}
          <div
            aria-hidden="true"
            className={`brand-crossfade absolute inset-0 transition-opacity duration-1000 ease-in-out ${
              showWoman ? 'opacity-100' : 'opacity-0'
            }`}
          >
            <div className="absolute -top-28 -right-28 h-80 w-80 rotate-12 rounded-[50%] bg-gradient-to-bl from-rose-500/25 via-pink-500/12 to-transparent blur-2xl" />
            <div className="absolute -bottom-24 -right-16 h-80 w-80 bg-[radial-gradient(closest-side,rgba(244,114,182,0.30),transparent)]" />
            <div className="absolute -bottom-32 -left-20 h-72 w-72 bg-[radial-gradient(closest-side,rgba(251,113,133,0.20),transparent)]" />
            <div className="absolute left-[-120px] top-[28%] h-80 w-80 bg-[radial-gradient(closest-side,rgba(217,70,239,0.22),transparent)]" />
            <div className="absolute -bottom-28 left-[18%] h-64 w-64 bg-[radial-gradient(closest-side,rgba(251,191,36,0.14),transparent)]" />
          </div>

          {/* man.png silhouette — slides in from the LEFT edge */}
          <img
            src="/man.png"
            alt=""
            aria-hidden="true"
            draggable={false}
            className={`brand-silhouette absolute bottom-[-10%] left-1/2 w-[92%] max-w-[430px] pointer-events-none select-none transition-all duration-700 ease-in-out will-change-transform ${
              showWoman ? 'translate-x-[-220%] opacity-0' : '-translate-x-1/2 opacity-90'
            }`}
            style={{
              maskImage: 'linear-gradient(to bottom, transparent 0%, black 22%, black 100%)',
              WebkitMaskImage: 'linear-gradient(to bottom, transparent 0%, black 22%, black 100%)',
            }}
          />
          {/* women.png silhouette — slides in from the RIGHT edge */}
          <img
            src="/women.png"
            alt=""
            aria-hidden="true"
            draggable={false}
            className={`brand-silhouette absolute bottom-[-10%] left-1/2 w-[92%] max-w-[430px] pointer-events-none select-none transition-all duration-700 ease-in-out will-change-transform ${
              showWoman ? '-translate-x-1/2 opacity-90' : 'translate-x-[120%] opacity-0'
            }`}
            style={{
              // Gentler top fade than the man so her head/ponytail renders
              // fully solid against the pink wash.
              maskImage: 'linear-gradient(to bottom, transparent 0%, black 10%, black 100%)',
              WebkitMaskImage: 'linear-gradient(to bottom, transparent 0%, black 10%, black 100%)',
            }}
          />

          {/* brand: centered logo + wordmark */}
          <div className="relative z-10 flex flex-col items-center px-6">
            <img
              src="/logo.png"
              alt="Triple J logo"
              draggable={false}
              className="w-28 h-28 object-contain drop-shadow-[0_0_28px_rgba(220,38,38,0.35)]"
            />
            <h1 className="mt-6 text-4xl font-extrabold display tracking-tight">
              <span className="bg-gradient-to-b from-[#F8FAFC] via-[#CBD5E1] to-[#94A3B8] bg-clip-text text-transparent">
                Triple{' '}
              </span>
              <span className="text-[#E02020] drop-shadow-[0_0_16px_rgba(224,32,32,0.55)]">J</span>
            </h1>
            <p className="mt-4 text-[10px] font-medium uppercase tracking-[0.4em] text-purple-300/60">
              Fitness &nbsp;•&nbsp; Strength &nbsp;•&nbsp; Community
            </p>
          </div>
        </div>

        {/* ============ RIGHT — FORM PANEL ============ */}
        <div
          className={`flex flex-col justify-center px-6 py-10 sm:px-10 md:py-12 lg:px-14 ${
            exiting ? 'panel-exit-right' : entering ? 'panel-enter-right' : ''
          }`}
        >
          {/* compact brand row for small screens */}
          <div className="md:hidden mb-8 flex items-center justify-center gap-3">
            <img src="/logo.png" alt="Triple J logo" className="w-11 h-11 object-contain" />
            <h1 className="text-2xl font-extrabold display tracking-tight">
              <span className="bg-gradient-to-b from-[#F8FAFC] via-[#CBD5E1] to-[#94A3B8] bg-clip-text text-transparent">
                Triple{' '}
              </span>
              <span className="text-[#E02020] drop-shadow-[0_0_12px_rgba(224,32,32,0.55)]">J</span>
            </h1>
          </div>

          {/* accent bar — sized to run from the left edge to the final
              "e" of "Welcome" (measured at text-3xl Unbounded bold) */}
          <div className="h-1.5 w-[176px] rounded-full bg-gradient-to-r from-[#7C3AED] to-[#A78BFA]" />
          <h2 className="mt-3 text-3xl font-bold display">
            <span className="text-fg-strong">Welcome </span>
            <span className="text-[#A78BFA]">Admin</span>
          </h2>

          <form onSubmit={handleSubmit} className="mt-8">
            <Field
              label="Email"
              type="email"
              value={email}
              onChange={setEmail}
              icon={<Mail size={16} />}
            />
            {/* same 24px rhythm as the email field above */}
            <div className="mt-6">
              <Field
                label="Password"
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={setPassword}
                icon={<Lock size={16} />}
                trailing={
                  <button
                    type="button"
                    onClick={() => setShowPassword(v => !v)}
                    className="text-fg-muted hover:text-fg-strong transition-colors"
                    aria-label={showPassword ? 'Hide password' : 'Show password'}
                  >
                    {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                  </button>
                }
              />
            </div>

            {error && <p className="mt-6 text-[#EF4444] text-sm">{error}</p>}

            {/* matches the full email-input -> password-input visual spacing */}
            <div className="mt-[52px]">
              <button
                type="submit"
                disabled={loading}
                className="w-full py-3 px-4 bg-gradient-to-r from-[#7C3AED] to-[#6D28D9] text-white rounded-lg hover:from-[#6D28D9] hover:to-[#7C3AED] disabled:opacity-50 font-medium transition-all shadow-[0_0_14px_rgba(124,58,237,0.35)] flex items-center justify-center gap-2"
              >
                {loading ? 'Signing in...' : 'Sign in'}
                {!loading && <ArrowRight size={16} />}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  )
}

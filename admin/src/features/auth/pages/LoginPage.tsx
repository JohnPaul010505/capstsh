import { useState, useRef } from 'react'
import { useAuth } from '../hooks/useAuth'

function FloatingInput({ label, type, value, onChange }: {
  label: string
  type: string
  value: string
  onChange: (v: string) => void
}) {
  const [focused, setFocused] = useState(false)
  const inputRef = useRef<HTMLInputElement>(null)
  const isFloating = focused || value.length > 0

  return (
    <div className="relative" onClick={() => inputRef.current?.focus()}>
      <input
        ref={inputRef}
        type={type}
        value={value}
        onChange={e => onChange(e.target.value)}
        onFocus={() => setFocused(true)}
        onBlur={() => setFocused(false)}
        className="w-full px-3 pt-5 pb-2 glass-input border rounded-lg text-[#ECECFC] text-sm focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50 focus:border-[#7C3AED]"
        required
      />
      <span
        className={`absolute left-3 transition-all duration-180 ease-in-out pointer-events-none ${
          isFloating
            ? 'text-[11px] -top-[7px] px-1 glass-input border rounded text-white'
            : 'text-sm top-[18px] text-[#55557A]'
        }`}
      >
        {label}
      </span>
    </div>
  )
}

export default function LoginPage() {
  const { signIn } = useAuth()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    setLoading(true)
    const err = await signIn(email, password)
    if (err) setError(err)
    setLoading(false)
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-[#0D0D1A] relative overflow-hidden">
      <div className="fixed inset-0 app-bg-image -z-10" aria-hidden="true" />
      <div className="fixed inset-0 bg-[#0D0D1A]/70 backdrop-blur-[3px] -z-10" aria-hidden="true" />
      <div className="w-full max-w-md space-y-8 p-8 glass-strong rounded-xl shadow-[0_0_30px_rgba(124,58,237,0.15)] relative z-10">
        <div className="text-center">
          <div className="w-16 h-16 mx-auto mb-4 flex items-center justify-center overflow-hidden">
            <img src="/logo.png" alt="Logo" className="w-full h-full object-contain" />
          </div>
          <h1 className="text-2xl font-bold text-[#ECECFC] display">Admin Panel</h1>
          <p className="text-[#55557A] mt-2 text-sm">Sign in to your account</p>
        </div>
        <form onSubmit={handleSubmit} className="space-y-4">
          <FloatingInput label="Email" type="email" value={email} onChange={setEmail} />
          <FloatingInput label="Password" type="password" value={password} onChange={setPassword} />
          {error && <p className="text-[#EF4444] text-sm">{error}</p>}
          <button
            type="submit"
            disabled={loading}
            className="w-full py-2.5 px-4 bg-gradient-to-r from-[#7C3AED] to-[#6D28D9] text-white rounded-lg hover:from-[#6D28D9] hover:to-[#7C3AED] disabled:opacity-50 font-medium transition-all shadow-[0_0_12px_rgba(124,58,237,0.3)]"
          >
            {loading ? 'Signing in...' : 'Sign in'}
          </button>
        </form>
      </div>
    </div>
  )
}

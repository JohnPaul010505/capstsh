import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { useTrainers } from '../hooks/useTrainers'
import { Trash2 } from 'lucide-react'

const DAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']

export default function TrainersListPage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { data: trainers, isLoading } = useTrainers()
  const [showModal, setShowModal] = useState(false)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [passwordConfirm, setPasswordConfirm] = useState('')
  const [fullName, setFullName] = useState('')
  const [phone, setPhone] = useState('')
  const [specialty, setSpecialty] = useState('')
  const [availableDays, setAvailableDays] = useState<string[]>([])
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [saving, setSaving] = useState(false)
  const [deleteTarget, setDeleteTarget] = useState<any>(null)
  const [deleting, setDeleting] = useState(false)

  const handleCreate = async () => {
    const newErrors: Record<string, string> = {}
    if (!fullName) newErrors.fullName = 'Full name is required'
    if (!email) newErrors.email = 'Email is required'
    if (!password) newErrors.password = 'Password is required'
    if (password !== passwordConfirm) newErrors.passwordConfirm = 'Passwords do not match'
    if (phone && !/^\d{11}$/.test(phone)) newErrors.phone = 'Phone must be exactly 11 digits'
    if (Object.keys(newErrors).length > 0) {
      setErrors(newErrors)
      return
    }
    setErrors({})
    setSaving(true)
    try {
      const res = await fetch('/api/users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email, password, fullName, role: 'trainer',
          phone: phone || undefined,
          specialty: specialty || undefined,
          availableDays: availableDays.length > 0 ? availableDays.join(',') : undefined,
        }),
      })
      if (!res.ok) {
        const err = await res.json()
        throw new Error(err.error || 'Failed to create trainer')
      }
      setShowModal(false)
      setEmail('')
      setPassword('')
      setPasswordConfirm('')
      setFullName('')
      setPhone('')
      setSpecialty('')
      setAvailableDays([])
      queryClient.invalidateQueries({ queryKey: ['trainers'] })
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to create trainer')
    } finally {
      setSaving(false)
    }
  }

  useEffect(() => {
    const newErrors: Record<string, string> = {}
    if (passwordConfirm && password !== passwordConfirm) {
      newErrors.passwordConfirm = 'Passwords do not match'
    }
    if (phone && !/^\d{11}$/.test(phone)) {
      newErrors.phone = 'Phone must be exactly 11 digits'
    }
    setErrors(prev => {
      const merged = { ...prev, ...newErrors }
      if (!newErrors.passwordConfirm) delete merged.passwordConfirm
      if (!newErrors.phone) delete merged.phone
      return merged
    })
  }, [password, passwordConfirm, phone])

  const toggleDay = (day: string) => {
    setAvailableDays(prev =>
      prev.includes(day) ? prev.filter(d => d !== day) : [...prev, day]
    )
  }

  const handleDelete = async () => {
    if (!deleteTarget) return
    setDeleting(true)
    try {
      const res = await fetch('/api/delete-user', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: deleteTarget.id }),
      })
      if (!res.ok) {
        const err = await res.json()
        throw new Error(err.error || 'Failed to delete trainer')
      }
      setDeleteTarget(null)
      queryClient.invalidateQueries({ queryKey: ['trainers'] })
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to delete')
    } finally {
      setDeleting(false)
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-[#ECECFC]">Trainers</h1>
        <button onClick={() => setShowModal(true)}
          className="px-4 py-2 bg-[#7C3AED] text-white rounded-lg hover:bg-[#6D28D9] text-sm">
          + Create Trainer
        </button>
      </div>

      {isLoading ? (
        <div className="text-center py-8 text-[#55557A]">Loading...</div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {trainers?.map(trainer => (
            <div
              key={trainer.id}
              className="glass-card p-6 rounded-xl border border-white/10 shadow-sm hover:border-[#7C3AED]/30 cursor-pointer transition-all duration-200 relative group"
              onClick={() => navigate(`/trainers/${trainer.id}`)}
            >
              <button
                onClick={e => { e.stopPropagation(); setDeleteTarget(trainer) }}
                className="absolute top-3 right-3 p-1.5 text-[#55557A] hover:text-[#EF4444] opacity-0 group-hover:opacity-100 transition-opacity"
                title="Delete"
              >
                <Trash2 className="w-4 h-4" />
              </button>
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-full bg-gradient-to-br from-[#22C55E]/30 to-[#4ADE80]/30 flex items-center justify-center">
                  <span className="text-lg font-bold text-[#4ADE80]">{trainer.full_name.charAt(0)}</span>
                </div>
                  <div>
                    <p className="font-semibold text-[#ECECFC]">{trainer.full_name}</p>
                    <p className="text-xs font-mono text-[#7C3AED] mt-0.5">{trainer.code}</p>
                    <p className="text-sm text-[#B4B4D0] mt-0.5">{trainer.email}</p>
                    {trainer.specialty && <p className="text-xs text-[#22C55E] mt-1">{trainer.specialty}</p>}
                  </div>
              </div>
            </div>
          ))}
          {trainers?.length === 0 && (
            <p className="text-[#55557A] col-span-full text-center py-8">No trainers found</p>
          )}
        </div>
      )}

      {showModal && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setShowModal(false)}>
          <div className="glass-card rounded-xl shadow-xl max-w-md w-full mx-4 border border-white/10" onClick={e => e.stopPropagation()}>
            <div className="px-6 py-4 border-b border-white/10">
              <h2 className="text-lg font-semibold text-[#ECECFC]">Create Trainer Account</h2>
            </div>
            <div className="px-6 py-4 space-y-4">
              <div>
                <label className="block text-sm font-medium text-[#B4B4D0] mb-1">Full Name *</label>
                <input value={fullName} onChange={e => { setFullName(e.target.value); setErrors(prev => ({...prev, fullName: ''})) }}
                  className="w-full px-3 py-2 bg-white/[0.08] border border-white/10 rounded-lg text-sm text-[#ECECFC] focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50" />
                {errors.fullName && <p className="text-xs text-[#EF4444] mt-1">{errors.fullName}</p>}
              </div>
              <div>
                <label className="block text-sm font-medium text-[#B4B4D0] mb-1">Email *</label>
                <input value={email} onChange={e => { setEmail(e.target.value); setErrors(prev => ({...prev, email: ''})) }}
                  className="w-full px-3 py-2 bg-white/[0.08] border border-white/10 rounded-lg text-sm text-[#ECECFC] focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50" type="email" />
                {errors.email && <p className="text-xs text-[#EF4444] mt-1">{errors.email}</p>}
              </div>
              <div>
                <label className="block text-sm font-medium text-[#B4B4D0] mb-1">Password *</label>
                <input value={password} onChange={e => { setPassword(e.target.value); setErrors(prev => ({...prev, password: ''})) }}
                  className="w-full px-3 py-2 bg-white/[0.08] border border-white/10 rounded-lg text-sm text-[#ECECFC] focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50" type="password" />
                {errors.password && <p className="text-xs text-[#EF4444] mt-1">{errors.password}</p>}
              </div>
              <div>
                <label className="block text-sm font-medium text-[#B4B4D0] mb-1">Confirm Password *</label>
                <input value={passwordConfirm} onChange={e => { setPasswordConfirm(e.target.value); setErrors(prev => ({...prev, passwordConfirm: ''})) }}
                  className="w-full px-3 py-2 bg-white/[0.08] border border-white/10 rounded-lg text-sm text-[#ECECFC] focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50" type="password" />
                {errors.passwordConfirm && <p className="text-xs text-[#EF4444] mt-1">{errors.passwordConfirm}</p>}
              </div>
              <div>
                <label className="block text-sm font-medium text-[#B4B4D0] mb-1">Specialty</label>
                <input value={specialty} onChange={e => setSpecialty(e.target.value)} placeholder="e.g. Weight Training, Yoga, Cardio"
                  className="w-full px-3 py-2 bg-white/[0.08] border border-white/10 rounded-lg text-sm text-[#ECECFC] focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50 placeholder-[#55557A]" />
              </div>
              <div>
                <label className="block text-sm font-medium text-[#B4B4D0] mb-2">Available Days</label>
                <div className="flex gap-1.5 flex-wrap">
                  {DAYS.map(day => (
                    <button key={day} type="button" onClick={() => toggleDay(day)}
                      className={`px-3 py-1.5 text-xs font-medium rounded-lg transition-colors ${
                        availableDays.includes(day)
                          ? 'bg-[#7C3AED] text-white'
                          : 'bg-white/[0.08] text-[#B4B4D0] border border-white/10 hover:border-[#7C3AED]/50'
                      }`}>
                      {day}
                    </button>
                  ))}
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-[#B4B4D0] mb-1">Phone</label>
                <input value={phone} onChange={e => { setPhone(e.target.value); setErrors(prev => ({...prev, phone: ''})) }} placeholder="09171234567"
                  className="w-full px-3 py-2 bg-white/[0.08] border border-white/10 rounded-lg text-sm text-[#ECECFC] focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50 placeholder-[#55557A]" />
                {errors.phone && <p className="text-xs text-[#EF4444] mt-1">{errors.phone}</p>}
              </div>
            </div>
            <div className="px-6 py-4 border-t border-white/10 flex justify-end gap-3">
              <button onClick={() => setShowModal(false)}
                className="px-4 py-2 text-sm border border-white/10 rounded-lg text-[#B4B4D0] hover:bg-white/[0.08]">Cancel</button>
              <button onClick={handleCreate} disabled={saving || !fullName || !email || !password || password !== passwordConfirm}
                className="px-4 py-2 text-sm bg-[#7C3AED] text-white rounded-lg hover:bg-[#6D28D9] disabled:opacity-50">
                {saving ? 'Creating...' : 'Create Trainer'}
              </button>
            </div>
          </div>
        </div>
      )}

      {deleteTarget && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setDeleteTarget(null)}>
          <div className="glass-card rounded-xl shadow-xl max-w-sm w-full mx-4 p-6 border border-white/10" onClick={e => e.stopPropagation()}>
            <h2 className="text-lg font-bold text-[#ECECFC] mb-2">Delete Trainer?</h2>
            <p className="text-sm text-[#B4B4D0] mb-4">
              This will permanently delete <strong className="text-[#ECECFC]">{deleteTarget.full_name}</strong>'s account and all access.
            </p>
            <div className="flex justify-end gap-3">
              <button onClick={() => setDeleteTarget(null)}
                className="px-4 py-2 text-sm border border-white/10 rounded-lg text-[#B4B4D0] hover:bg-white/[0.08]">Cancel</button>
              <button onClick={handleDelete} disabled={deleting}
                className="px-4 py-2 text-sm bg-[#EF4444] text-white rounded-lg hover:bg-[#DC2626] disabled:opacity-50">
                {deleting ? 'Deleting...' : 'Delete'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

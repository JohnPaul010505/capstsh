import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import PeopleTable, { peopleCells, type PeopleColumn } from '@/components/PeopleTable'
import PaginationFooter from '@/components/PaginationFooter'
import ListToolbar from '@/components/ListToolbar'
import { useFitRowHeight } from '@/hooks/useFitRows'
import { useTrainersList, LIST_PAGE_SIZE } from '@/lib/listHooks'
import { useResetPageOnChange } from '@/lib/pagedTable'
import type { Profile } from '@/types'
import { X } from 'lucide-react'

const DAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']

export default function TrainersListPage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [page, setPage] = useState(1)
  const [search, setSearch] = useState('')
  const [from, setFrom] = useState<string | undefined>()
  const [to, setTo] = useState<string | undefined>()

  const { rows, total, pageCount, isLoading } = useTrainersList({ page, pageSize: LIST_PAGE_SIZE, search, from, to })
  // Fifteen rows is the contract; the height of one of them is what gives.
  const [scrollRef, rowHeight] = useFitRowHeight<HTMLDivElement>({ count: LIST_PAGE_SIZE })
  useResetPageOnChange(setPage, search, from, to)

  const columns: PeopleColumn<Profile>[] = [
    {
      key: 'name',
      header: 'Name',
      render: t => (
        <span className="flex items-center gap-2.5">
          <span className="w-7 h-7 rounded-full bg-gradient-to-br from-[#22C55E]/30 to-[#4ADE80]/30 flex items-center justify-center shrink-0">
            <span className="text-[11px] font-bold text-accent-green">{t.full_name.charAt(0)}</span>
          </span>
          <span className="font-medium text-fg-strong">{t.full_name}</span>
        </span>
      ),
    },
    { key: 'code', header: 'Code', render: t => peopleCells.code(t.code) },
    { key: 'email', header: 'Email', render: t => t.email },
    { key: 'specialty', header: 'Specialty', render: t => t.specialty || '—' },
    { key: 'joined', header: 'Hired', render: t => peopleCells.date(t.created_at) },
    {
      key: 'actions',
      header: 'Actions',
      align: 'right',
      render: t => peopleCells.deleteButton('Delete trainer', () => setDeleteTarget(t)),
    },
  ]

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

  useEffect(() => {
    if (!showModal) return
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setShowModal(false)
    }
    document.addEventListener('keydown', onKeyDown)
    return () => document.removeEventListener('keydown', onKeyDown)
  }, [showModal])

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
    <div className="h-full min-h-0 flex flex-col gap-3">
      <ListToolbar
        from={from}
        to={to}
        onDateRangeChange={(a, b) => { setFrom(a); setTo(b) }}
        dateLabel="Hired"
      >
        <button onClick={() => setShowModal(true)}
          className="px-4 py-2 bg-[#7C3AED] text-white rounded-xl hover:bg-[#6D28D9] text-sm shrink-0 cursor-pointer">
          + Create Trainer
        </button>
      </ListToolbar>

      <PeopleTable
        title="Trainers"
        rows={rows}
        columns={columns}
        rowKey={t => t.id}
        onRowClick={t => navigate(`/trainers/${t.id}`)}
        isLoading={isLoading}
        emptyMessage="No trainers match these filters"
        scrollRef={scrollRef}
        rowHeight={rowHeight}
        search={{ value: search, onChange: setSearch, placeholder: 'Search by name, code or email…' }}
        startIndex={(page - 1) * LIST_PAGE_SIZE + 1}
        footer={
          <PaginationFooter
            page={page}
            pageCount={pageCount}
            total={total}
            pageSize={LIST_PAGE_SIZE}
            onPageChange={setPage}
          />
        }
      />

      {showModal && (
        <div className="fixed inset-0 bg-black/60 z-50" onClick={() => setShowModal(false)}>
          <div className="glass-card slide-in-right fixed right-0 top-0 h-full w-full max-w-md flex flex-col rounded-l-2xl border-l border-line" onClick={e => e.stopPropagation()}>
            <div className="px-6 py-4 border-b border-line flex items-center justify-between">
              <h2 className="text-lg font-semibold text-fg-strong">Create Trainer Account</h2>
              <button onClick={() => setShowModal(false)} className="text-fg-muted hover:text-fg cursor-pointer"><X className="w-5 h-5" /></button>
            </div>
            <div className="px-6 py-4 space-y-4 flex-1 overflow-y-auto">
              <div>
                <label className="block text-sm font-medium text-fg mb-1">Full Name *</label>
                <input value={fullName} onChange={e => { setFullName(e.target.value); setErrors(prev => ({...prev, fullName: ''})) }}
                  className="w-full px-3 py-2 bg-overlay-8 border border-line rounded-lg text-sm text-fg-strong focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50" />
                {errors.fullName && <p className="text-xs text-[#EF4444] mt-1">{errors.fullName}</p>}
              </div>
              <div>
                <label className="block text-sm font-medium text-fg mb-1">Email *</label>
                <input value={email} onChange={e => { setEmail(e.target.value); setErrors(prev => ({...prev, email: ''})) }}
                  className="w-full px-3 py-2 bg-overlay-8 border border-line rounded-lg text-sm text-fg-strong focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50" type="email" />
                {errors.email && <p className="text-xs text-[#EF4444] mt-1">{errors.email}</p>}
              </div>
              <div>
                <label className="block text-sm font-medium text-fg mb-1">Password *</label>
                <input value={password} onChange={e => { setPassword(e.target.value); setErrors(prev => ({...prev, password: ''})) }}
                  className="w-full px-3 py-2 bg-overlay-8 border border-line rounded-lg text-sm text-fg-strong focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50" type="password" />
                {errors.password && <p className="text-xs text-[#EF4444] mt-1">{errors.password}</p>}
              </div>
              <div>
                <label className="block text-sm font-medium text-fg mb-1">Confirm Password *</label>
                <input value={passwordConfirm} onChange={e => { setPasswordConfirm(e.target.value); setErrors(prev => ({...prev, passwordConfirm: ''})) }}
                  className="w-full px-3 py-2 bg-overlay-8 border border-line rounded-lg text-sm text-fg-strong focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50" type="password" />
                {errors.passwordConfirm && <p className="text-xs text-[#EF4444] mt-1">{errors.passwordConfirm}</p>}
              </div>
              <div>
                <label className="block text-sm font-medium text-fg mb-1">Specialty</label>
                <input value={specialty} onChange={e => setSpecialty(e.target.value)} placeholder="e.g. Weight Training, Yoga, Cardio"
                  className="w-full px-3 py-2 bg-overlay-8 border border-line rounded-lg text-sm text-fg-strong focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50 placeholder-fg-muted" />
              </div>
              <div>
                <label className="block text-sm font-medium text-fg mb-2">Available Days</label>
                <div className="flex gap-1.5 flex-wrap">
                  {DAYS.map(day => (
                    <button key={day} type="button" onClick={() => toggleDay(day)}
                      className={`px-3 py-1.5 text-xs font-medium rounded-lg transition-colors ${
                        availableDays.includes(day)
                          ? 'bg-[#7C3AED] text-white'
                          : 'bg-overlay-8 text-fg border border-line hover:border-[#7C3AED]/50'
                      }`}>
                      {day}
                    </button>
                  ))}
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-fg mb-1">Phone</label>
                <input value={phone} onChange={e => { setPhone(e.target.value); setErrors(prev => ({...prev, phone: ''})) }} placeholder="09171234567"
                  className="w-full px-3 py-2 bg-overlay-8 border border-line rounded-lg text-sm text-fg-strong focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50 placeholder-fg-muted" />
                {errors.phone && <p className="text-xs text-[#EF4444] mt-1">{errors.phone}</p>}
              </div>
            </div>
            <div className="px-6 py-4 border-t border-line flex justify-end gap-3">
              <button onClick={() => setShowModal(false)}
                className="px-4 py-2 text-sm border border-line rounded-lg text-fg hover:bg-overlay-8">Cancel</button>
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
          <div className="glass-card rounded-xl max-w-sm w-full mx-4 p-6" onClick={e => e.stopPropagation()}>
            <h2 className="text-lg font-bold text-fg-strong mb-2">Delete Trainer?</h2>
            <p className="text-sm text-fg mb-4">
              This will permanently delete <strong className="text-fg-strong">{deleteTarget.full_name}</strong>'s account and all access.
            </p>
            <div className="flex justify-end gap-3">
              <button onClick={() => setDeleteTarget(null)}
                className="px-4 py-2 text-sm border border-line rounded-lg text-fg hover:bg-overlay-8">Cancel</button>
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

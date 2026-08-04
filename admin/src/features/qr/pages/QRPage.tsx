import { useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { QRCodeSVG } from 'qrcode.react'
import { supabase } from '@/lib/supabase'
import EnrollmentForm, { emptyForm, type EnrollmentFormData } from '../components/EnrollmentForm'
import { useAuth } from '@/features/auth/hooks/useAuth'
import { Eye, Check, X, Plus } from 'lucide-react'

const ORIGIN = import.meta.env.VITE_PUBLIC_URL || window.location.origin
const PAGE_URL = `${ORIGIN}/qr`

export default function QRPage() {
  const { profile } = useAuth()
  const isAdmin = !!profile
  const queryClient = useQueryClient()
  const [selected, setSelected] = useState<any>(null)
  const [showModal, setShowModal] = useState(false)
  const [isManual, setIsManual] = useState(false)
  const [formData, setFormData] = useState<EnrollmentFormData>(emptyForm)
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [saving, setSaving] = useState(false)

  const [enrollFormData, setEnrollFormData] = useState<EnrollmentFormData>(emptyForm)
  const [enrollSubmitted, setEnrollSubmitted] = useState(false)
  const [enrollError, setEnrollError] = useState('')
  const [enrollSaving, setEnrollSaving] = useState(false)

  const { data: enrollments, isLoading } = useQuery({
    queryKey: ['enrollments'],
    queryFn: async () => {
      const { data } = await supabase.from('enrollments').select('*').order('created_at', { ascending: false })
      return data ?? []
    },
    enabled: isAdmin,
  })

  const handleConfirm = async (enrollment: any) => {
    const { data: { user } } = await supabase.auth.getUser()
    try {
      const res = await fetch('/api/confirm-enrollment', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ enrollment, confirmedBy: user?.id }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Failed to confirm')
      alert(`Member confirmed!\nCode: ${data.code}\nTemporary password: ${data.tempPassword}`)
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to confirm enrollment')
    }
    queryClient.invalidateQueries({ queryKey: ['enrollments'] })
  }

  const handleReject = async (id: string) => {
    await supabase.from('enrollments').update({ status: 'rejected' }).eq('id', id)
    queryClient.invalidateQueries({ queryKey: ['enrollments'] })
  }

  function phoneError(v: string) {
    if (!v) return null
    const digits = v.replace(/\D/g, '')
    return digits.length !== 11 ? 'Phone number must be exactly 11 digits' : null
  }

  const handleManualSave = async () => {
    if (!formData.fullName || !formData.email || !password) return
    if (password !== confirmPassword) { alert('Passwords do not match'); return }
    if (phoneError(formData.phone)) { alert(phoneError(formData.phone)); return }
    if (formData.emergencyContactPhone && phoneError(formData.emergencyContactPhone)) { alert(phoneError(formData.emergencyContactPhone)); return }
    setSaving(true)
    try {
      const res = await fetch('/api/users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: formData.email, password, fullName: formData.fullName, role: 'member',
          phone: formData.phone || undefined, dateOfBirth: formData.dateOfBirth || undefined,
          gender: formData.gender || undefined, address: formData.address || undefined,
          emergencyContactName: formData.emergencyContactName || undefined,
          emergencyContactPhone: formData.emergencyContactPhone || undefined,
        }),
      })
      if (!res.ok) throw new Error('Failed to create user')
      setShowModal(false); setFormData(emptyForm); setPassword(''); setConfirmPassword('')
      queryClient.invalidateQueries({ queryKey: ['enrollments'] })
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to create user')
    } finally { setSaving(false) }
  }

  const handleEditEnrollment = async () => {
    if (!selected || !formData.fullName || !formData.email) return
    setSaving(true)
    const { error } = await supabase.from('enrollments').update({
      full_name: formData.fullName, email: formData.email,
      phone: formData.phone || null, date_of_birth: formData.dateOfBirth || null,
      gender: formData.gender || null, address: formData.address || null,
    }).eq('id', selected.id)
    setSaving(false)
    if (!error) { setShowModal(false); setSelected(null); queryClient.invalidateQueries({ queryKey: ['enrollments'] }) }
  }

  const openView = (enrollment: any) => {
    setSelected(enrollment); setIsManual(false)
    setFormData({
      fullName: enrollment.full_name ?? '', email: enrollment.email ?? '',
      phone: enrollment.phone ?? '', dateOfBirth: enrollment.date_of_birth ?? '',
      gender: enrollment.gender ?? '', address: enrollment.address ?? '',
      emergencyContactName: enrollment.emergency_contact_name ?? '',
      emergencyContactPhone: enrollment.emergency_contact_phone ?? '',
    })
    setShowModal(true)
  }

  const openManual = () => { setSelected(null); setIsManual(true); setFormData(emptyForm); setPassword(''); setConfirmPassword(''); setShowModal(true) }

  const handleEnrollSubmit = async () => {
    if (!enrollFormData.fullName || !enrollFormData.email) { setEnrollError('Name and email are required'); return }
    const enrollPhoneErr = phoneError(enrollFormData.phone)
    if (enrollPhoneErr) { setEnrollError(enrollPhoneErr); return }
    setEnrollSaving(true); setEnrollError('')
    try {
      const res = await fetch('/api/enroll', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(enrollFormData),
      })
      if (res.ok) setEnrollSubmitted(true)
      else {
        const data = await res.json()
        setEnrollError(data.error || 'Failed to submit')
      }
    } catch {
      setEnrollError('Network error. Please try again.')
    }
    setEnrollSaving(false)
  }

  const pending = enrollments?.filter(e => e.status === 'pending') ?? []
  const confirmed = enrollments?.filter(e => e.status === 'confirmed') ?? []

  if (!isAdmin) {
    return (
      <div className="min-h-screen bg-[#0D0D1A] flex items-center justify-center py-8">
        <div className="fixed inset-0 app-bg-image -z-10" aria-hidden="true" />
        <div className="fixed inset-0 bg-[#0D0D1A]/70 backdrop-blur-[3px] -z-10" aria-hidden="true" />
        <div className="glass-card p-8 rounded-xl max-w-2xl w-full mx-4">
          {enrollSubmitted ? (
            <div className="text-center">
              <div className="w-16 h-16 bg-[#22C55E]/20 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg className="w-8 h-8 text-[#4ADE80]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <h1 className="text-xl font-bold text-[#ECECFC] mb-2">Application Submitted!</h1>
              <p className="text-[#B4B4D0] text-sm">The admin will review your information and confirm your membership.</p>
            </div>
          ) : (
            <>
              <h1 className="text-xl font-bold text-[#ECECFC] mb-1">Gym Membership Enrollment</h1>
              <p className="text-sm text-[#55557A] mb-6">Fill in your details to apply for membership.</p>
              <EnrollmentForm data={enrollFormData} onChange={setEnrollFormData} />
              {enrollError && <p className="text-sm text-[#EF4444] mt-4">{enrollError}</p>}
              <button onClick={handleEnrollSubmit}
                disabled={enrollSaving || !enrollFormData.fullName || !enrollFormData.email}
                className="mt-6 w-full px-4 py-3 bg-[#7C3AED] text-white rounded-lg hover:bg-[#6D28D9] disabled:opacity-50 font-medium">
                {enrollSaving ? 'Submitting...' : 'Submit Application'}
              </button>
            </>
          )}
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-[#ECECFC]">QR Code Management</h1>
        <button onClick={openManual} className="flex items-center gap-2 px-4 py-2 bg-[#7C3AED] text-white rounded-lg text-sm hover:bg-[#6D28D9]">
          <Plus className="w-4 h-4" /> Add Manually
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="glass-card p-6 rounded-xl border border-white/10 shadow-sm flex flex-col items-center justify-center">
          <p className="text-sm font-semibold text-[#ECECFC] mb-3">Enrollment Form</p>
          <QRCodeSVG value={PAGE_URL} size={160} bgColor="#14142A" fgColor="#ECECFC" />
        </div>
        <div className="glass-card p-6 rounded-xl border border-white/10 shadow-sm flex flex-col items-center justify-center border-[#22C55E]/30">
          <p className="text-sm font-semibold text-[#ECECFC] mb-3">Check-in / Check-out</p>
          <QRCodeSVG value="FITGYM:ATTENDANCE" size={160} bgColor="#14142A" fgColor="#ECECFC" />
          <p className="text-xs text-[#55557A] mt-3 text-center">Scan in fitness app to check in or out</p>
        </div>
      </div>

      {/* Pending enrollments */}
      <div className="glass-card rounded-xl border border-white/10 shadow-sm">
        <div className="px-4 py-3 border-b border-white/10">
          <h2 className="font-semibold text-[#ECECFC]">Pending ({pending.length})</h2>
        </div>
        {isLoading ? (
          <div className="text-center py-8 text-[#55557A]">Loading...</div>
        ) : pending.length === 0 ? (
          <div className="text-center py-8 text-[#55557A]">No pending enrollments</div>
        ) : (
          <table className="w-full">
            <thead>
              <tr className="border-b border-white/10 bg-white/5">
                <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Name</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Email</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Date</th>
                <th className="text-right px-4 py-3 text-sm font-medium text-[#55557A]">Actions</th>
              </tr>
            </thead>
            <tbody>
              {pending.map(e => (
                <tr key={e.id} className="border-b border-white/5 last:border-0 hover:bg-[#7C3AED]/5 transition-colors">
                  <td className="px-4 py-3 text-sm font-medium text-[#ECECFC]">{e.full_name}</td>
                  <td className="px-4 py-3 text-sm text-[#B4B4D0]">{e.email}</td>
                  <td className="px-4 py-3 text-sm text-[#B4B4D0]">{new Date(e.created_at).toLocaleDateString()}</td>
                  <td className="px-4 py-3 text-sm text-right">
                    <button onClick={() => openView(e)} className="p-1 text-[#55557A] hover:text-[#C084FC]" title="View"><Eye className="w-4 h-4 inline" /></button>
                    <button onClick={() => handleConfirm(e)} className="p-1 text-[#55557A] hover:text-[#4ADE80]" title="Confirm"><Check className="w-4 h-4 inline" /></button>
                    <button onClick={() => handleReject(e.id)} className="p-1 text-[#55557A] hover:text-[#EF4444]" title="Reject"><X className="w-4 h-4 inline" /></button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Confirmed enrollments */}
      <div className="glass-card rounded-xl border border-white/10 shadow-sm">
        <div className="px-4 py-3 border-b border-white/10">
          <h2 className="font-semibold text-[#ECECFC]">Confirmed ({confirmed.length})</h2>
        </div>
        {confirmed.length === 0 ? (
          <div className="text-center py-8 text-[#55557A]">No confirmed members</div>
        ) : (
          <table className="w-full">
            <thead>
              <tr className="border-b border-white/10 bg-white/5">
                <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Name</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Email</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-[#55557A]">Confirmed</th>
              </tr>
            </thead>
            <tbody>
              {confirmed.map(e => (
                <tr key={e.id} className="border-b border-white/5 last:border-0 hover:bg-[#7C3AED]/5 transition-colors">
                  <td className="px-4 py-3 text-sm font-medium text-[#ECECFC]">{e.full_name}</td>
                  <td className="px-4 py-3 text-sm text-[#B4B4D0]">{e.email}</td>
                  <td className="px-4 py-3 text-sm text-[#B4B4D0]">{new Date(e.confirmed_at).toLocaleDateString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50" onClick={() => setShowModal(false)}>
          <div className="glass-card rounded-xl shadow-xl max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto border border-white/10" onClick={e => e.stopPropagation()}>
            <div className="px-6 py-4 border-b border-white/10">
              <h2 className="text-lg font-semibold text-[#ECECFC]">
                {isManual ? 'Add Member Manually' : selected?.status === 'pending' ? 'Review Enrollment' : 'View Enrollment'}
              </h2>
            </div>
            <div className="px-6 py-4">
              <EnrollmentForm
                data={formData} onChange={setFormData}
                includePassword={isManual} password={password} onPasswordChange={setPassword}
                confirmPassword={confirmPassword} onConfirmPasswordChange={setConfirmPassword}
              />
            </div>
            <div className="px-6 py-4 border-t border-white/10 flex justify-end gap-3">
              <button onClick={() => setShowModal(false)}
                className="px-4 py-2 text-sm border border-white/10 rounded-lg text-[#B4B4D0] hover:bg-white/[0.08]">Cancel</button>
              {isManual && (
                <button onClick={handleManualSave} disabled={saving || !formData.fullName || !formData.email || !password || password !== confirmPassword}
                  className="px-4 py-2 text-sm bg-[#7C3AED] text-white rounded-lg hover:bg-[#6D28D9] disabled:opacity-50">
                  {saving ? 'Creating...' : 'Create Member'}
                </button>
              )}
              {selected && selected.status === 'pending' && !isManual && (
                <button onClick={handleEditEnrollment} disabled={saving}
                  className="px-4 py-2 text-sm bg-[#7C3AED] text-white rounded-lg hover:bg-[#6D28D9] disabled:opacity-50">
                  {saving ? 'Saving...' : 'Save Changes'}
                </button>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

import { useState, useEffect } from 'react'
import { useLocation } from 'react-router-dom'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { QRCodeSVG } from 'qrcode.react'
import { supabase } from '@/lib/supabase'
import RecordsTable, { type RecordsColumn } from '@/components/RecordsTable'
import EnrollmentForm, { emptyForm, type EnrollmentFormData } from '../components/EnrollmentForm'
import HealthBackgroundSection, { emptyHealthBackground, type HealthBackgroundAnswers } from '../components/HealthBackgroundSection'
import { useAuth } from '@/features/auth/hooks/useAuth'
import { useTheme } from '@/contexts/ThemeContext'
import { useFitSquare } from '@/hooks/useFitRows'
import { Eye, Check, X, Plus } from 'lucide-react'
import AppBackground from '@/components/AppBackground'

// In development the LAN URL lets a phone on the same Wi-Fi reach this Vite
// server. In production, use the serving origin so no development IP is baked
// into the QR.
const PUBLIC_ORIGIN = import.meta.env.DEV
  ? (import.meta.env.VITE_PUBLIC_URL?.trim() || window.location.origin)
  : window.location.origin
const ENROLLMENT_URL = import.meta.env.VITE_ENROLLMENT_URL?.trim() || 'https://capstsh.vercel.app/enroll'
const PAGE_URL = ENROLLMENT_URL
  ? new URL(ENROLLMENT_URL).toString()
  : new URL('/enroll', PUBLIC_ORIGIN).toString()

/**
 * The page is three views, not one long page.
 *
 * It used to be the two QR codes followed by a Pending table and a Confirmed
 * table, both rendered in full, inside a plain `space-y-3` block. `main` is
 * `flex-1 overflow-hidden`, so an auto-height child simply ran off the bottom
 * of the viewport: with 10 pending and 45 confirmed rows, most of the page was
 * unreachable and no scrollbar said so. Splitting the lists into their own
 * views also makes them addressable by a click, and each one gets a real pager.
 *
 * These are tabs rather than routes on purpose: App.tsx renders the public
 * enrolment form for a signed-out visitor at exactly `/qr`, so a `/qr/pending`
 * sub-route would fall through to the login gate for the people most likely to
 * be holding the phone.
 */
const QR_VIEWS = [
  { id: 'codes', label: 'QR Codes' },
  { id: 'pending', label: 'Pending' },
  { id: 'confirmed', label: 'Confirmed' },
] as const

type QrView = (typeof QR_VIEWS)[number]['id']

export default function QRPage() {
  const { profile } = useAuth()
  const location = useLocation()
  const isAdmin = !!profile && location.pathname !== '/enroll'
  const { theme } = useTheme()
  const qrBg = theme === 'light' ? '#FFFFFF' : '#14142A'
  const qrFg = theme === 'light' ? '#0F172A' : '#ECECFC'
  const queryClient = useQueryClient()
  const [selected, setSelected] = useState<any>(null)
  const [showModal, setShowModal] = useState(false)
  // The QR pair is the landing view: the lists are one click away rather than
  // pushing it down the page.
  const [view, setView] = useState<QrView>('codes')
  // One search term per list. Sharing one would make a name typed into Pending
  // silently pre-filter Confirmed when the tab changed.
  const [pendingSearch, setPendingSearch] = useState('')
  const [confirmedSearch, setConfirmedSearch] = useState('')

  /* A ceiling, and a much lower one than the hook's own default of 500. Both
     codes are scanned off a phone, not read across a room: at 500 the code
     filled 60%+ of its card on a 1080p monitor, which is when a visitor holding
     their phone has to hunt for it. 240 is the old `fallback` - the size the
     hook used before the fit-to-card behaviour was added - and it is the
     smallest size a phone camera still locks onto without the admin leaning in.
     The hook still shrinks it on a short window, so this is a ceiling on a
     measurement rather than a fixed box. */
  const [enrollRef, enrollSize] = useFitSquare<HTMLDivElement>({ max: 240 })
  const [checkinRef, checkinSize] = useFitSquare<HTMLDivElement>({ max: 240 })

  useEffect(() => {
    if (!showModal) return
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setShowModal(false)
    }
    document.addEventListener('keydown', onKeyDown)
    return () => document.removeEventListener('keydown', onKeyDown)
  }, [showModal])
  const [isManual, setIsManual] = useState(false)
  const [formData, setFormData] = useState<EnrollmentFormData>(emptyForm)
  const [healthBackground, setHealthBackground] = useState<HealthBackgroundAnswers>(emptyHealthBackground)
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
      const { data, error } = await supabase.from('enrollments').select('*').order('created_at', { ascending: false })
      if (error) throw error
      return data ?? []
    },
    enabled: isAdmin,
  })

  useEffect(() => {
    if (!isAdmin) return
    const channel = supabase
      .channel('qr-enrollments-live')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'enrollments' }, () => {
        void queryClient.invalidateQueries({ queryKey: ['enrollments'] })
      })
      .subscribe()
    return () => { void supabase.removeChannel(channel) }
  }, [isAdmin, queryClient])

  const authorizedRequest = async (url: string, body: Record<string, unknown>) => {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session?.access_token) throw new Error('Your admin session expired. Please sign in again.')
    return fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${session.access_token}` },
      body: JSON.stringify(body),
    })
  }

  const handleConfirm = async (enrollment: any) => {
    try {
      const res = await authorizedRequest('/api/confirm-enrollment', { enrollmentId: enrollment.id })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Failed to confirm')
      alert(data.legacyPassword
        ? `Member confirmed!\nCode: ${data.code}\nTemporary password: ${data.legacyPassword}`
        : `Member confirmed!\nCode: ${data.code}\nThey can now sign in using the password created during enrollment.`)
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to confirm enrollment')
    }
    queryClient.invalidateQueries({ queryKey: ['enrollments'] })
  }

  const handleReject = async (id: string) => {
    try {
      const res = await authorizedRequest('/api/reject-enrollment', { enrollmentId: id })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Failed to reject application')
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to reject application')
    }
    queryClient.invalidateQueries({ queryKey: ['enrollments'] })
  }

  function phoneError(v: string) {
    if (!v) return null
    const digits = v.replace(/\D/g, '')
    return digits.length > 11 ? 'Phone number must be no more than 11 digits' : null
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
          civilStatus: formData.civilStatus || undefined,
          religion: formData.religion || undefined, religionOther: formData.religionOther || undefined,
          emergencyContactName: formData.emergencyContactName || undefined,
          emergencyContactPhone: formData.emergencyContactPhone || undefined,
        }),
      })
      const data = await res.json().catch(() => ({}))
      if (!res.ok) {
        const detail = [data.error, data.details].filter(Boolean).join(' — ')
        throw new Error(detail || `Failed to create user (HTTP ${res.status})`)
      }
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
      civil_status: formData.civilStatus || null, religion: formData.religion || null,
      religion_other: formData.religion === 'other' ? formData.religionOther || null : null,
      emergency_contact_name: formData.emergencyContactName || null,
      emergency_contact_phone: formData.emergencyContactPhone || null,
      health_background: healthBackground,
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
      civilStatus: enrollment.civil_status ?? '', religion: enrollment.religion ?? '',
      religionOther: enrollment.religion_other ?? '',
      emergencyContactName: enrollment.emergency_contact_name ?? '',
      emergencyContactPhone: enrollment.emergency_contact_phone ?? '',
    })
    setHealthBackground({ ...emptyHealthBackground, ...(enrollment.health_background ?? {}) })
    setShowModal(true)
  }

  const openManual = () => { setSelected(null); setIsManual(true); setFormData(emptyForm); setHealthBackground(emptyHealthBackground); setPassword(''); setConfirmPassword(''); setShowModal(true) }

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

  /* Date and time are columns of their own now, in the same two-column shape
     the dashboard's check-in and activity lists already use (`CheckinsTab`,
     `ActivityTab`, `GrowthTab`): the day in the strong tone, the clock in the
     muted 12px beside it. They used to be ONE combined cell led by a
     "Submitted"/"Confirmed" column at the far left, which put the only
     timestamp on a membership list ahead of the name, email and phone the list
     is actually about - and on the Confirmed view headed a column with the word
     "Confirmed" over a time that says nothing the tab does not already say.

     The `leading-tight` wrapper on BOTH cells is there to keep the type tight,
     exactly as the combined cell had it - it is not doing any work on the row
     height. (Measured: the Confirmed list's rows are 45px either way, because
     the cell's own `text-sm` strut sets the line box and a block child sits
     inside it. `RecordsTable` budgets 44px, so the 45th pixel is the cell's, not
     the column's - which is why the measured page size still comes out honest
     and the body does not scroll.) */
  const dateCell = (iso: string | null) => {
    if (!iso) return <span className="text-fg-faint">—</span>
    return (
      <div className="leading-tight">
        <span className="text-fg-strong whitespace-nowrap">{new Date(iso).toLocaleDateString()}</span>
      </div>
    )
  }

  const timeCell = (iso: string | null) => {
    if (!iso) return <span className="text-fg-faint">—</span>
    return (
      <div className="leading-tight">
        <span className="text-fg-muted text-[12px] whitespace-nowrap">
          {new Date(iso).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}
        </span>
      </div>
    )
  }

  // The three row actions keep the exact tint/border treatment they had in the
  // old inline table — verify-membership-qr-ux.mjs asserts those class names
  // once it has opened this view.
  const actionsFor = (e: any) => (
    <div className="flex items-center justify-end gap-1.5">
      <button
        onClick={() => openView(e)}
        title="View"
        aria-label="View enrollment"
        className="p-1.5 rounded-lg border border-[#7C3AED]/40 bg-[#7C3AED]/15 text-accent-purple hover:bg-[#7C3AED] hover:text-white hover:border-[#7C3AED] transition-colors"
      >
        <Eye className="w-4 h-4" />
      </button>
      <button
        onClick={() => handleConfirm(e)}
        title="Confirm"
        aria-label="Confirm enrollment"
        className="p-1.5 rounded-lg border border-[#22C55E]/50 bg-[#22C55E]/15 text-accent-green hover:bg-[#22C55E] hover:text-white hover:border-[#22C55E] transition-colors"
      >
        <Check className="w-4 h-4" />
      </button>
      <button
        onClick={() => handleReject(e.id)}
        title="Reject"
        aria-label="Reject enrollment"
        className="p-1.5 rounded-lg border border-[#EF4444]/50 bg-[#EF4444]/15 text-[#EF4444] hover:bg-[#EF4444] hover:text-white hover:border-[#EF4444] transition-colors"
      >
        <X className="w-4 h-4" />
      </button>
    </div>
  )

  const identityColumns: RecordsColumn<any>[] = [
    { key: 'name', header: 'Name', render: e => <span className="font-medium text-fg-strong">{e.full_name}</span> },
    { key: 'email', header: 'Email', render: e => <span className="text-fg">{e.email}</span> },
    { key: 'phone', header: 'Phone', render: e => <span className="text-fg">{e.phone || <span className="text-fg-faint">—</span>}</span> },
  ]

  // Identity first, then when. The leading timestamp column is gone: the
  // visible order on both lists is now # | Name | Email | Phone | Date | Time,
  // with Actions last on Pending.
  const pendingColumns: RecordsColumn<any>[] = [
    ...identityColumns,
    { key: 'date', header: 'Date', render: e => dateCell(e.created_at) },
    { key: 'time', header: 'Time', render: e => timeCell(e.created_at) },
    { key: 'actions', header: 'Actions', align: 'right', render: e => actionsFor(e) },
  ]

  const confirmedColumns: RecordsColumn<any>[] = [
    ...identityColumns,
    { key: 'date', header: 'Date', render: e => dateCell(e.confirmed_at) },
    { key: 'time', header: 'Time', render: e => timeCell(e.confirmed_at) },
  ]

  const identityFields = (e: any) => [e.full_name, e.email, e.phone]

  if (!isAdmin) {
    return (
      <div className="min-h-screen flex items-center justify-center py-8 relative overflow-hidden">
        <AppBackground />
        <div className="fixed inset-0 bg-page-deep/70 backdrop-blur-[3px] -z-10" aria-hidden="true" />
        <div className="glass-card p-8 rounded-xl max-w-2xl w-full mx-4">
          {enrollSubmitted ? (
            <div className="text-center">
              <div className="w-16 h-16 bg-[#22C55E]/20 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg className="w-8 h-8 text-accent-green" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <h1 className="text-xl font-bold text-fg-strong mb-2">Application Submitted!</h1>
              <p className="text-fg text-sm">The admin will review your information and confirm your membership.</p>
            </div>
          ) : (
            <>
              <h1 className="text-xl font-bold text-fg-strong mb-1">Gym Membership Enrollment</h1>
              <p className="text-sm text-fg-muted mb-6">Fill in your details to apply for membership.</p>
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
    <div className="h-full min-h-0 flex flex-col gap-3">
      {/* View switch + the one page-level action. The counts live in the tab
          labels, which is also what verify-admin-ui.mjs reads to confirm the
          pending queue is intact. */}
      <div className="flex flex-wrap items-center justify-between gap-2 shrink-0">
        <div role="tablist" aria-label="QR sections" className="flex flex-wrap items-center gap-1.5">
          {QR_VIEWS.map(v => {
            const count = v.id === 'pending' ? pending.length : v.id === 'confirmed' ? confirmed.length : null
            return (
              <button
                key={v.id}
                type="button"
                role="tab"
                aria-selected={view === v.id}
                onClick={() => setView(v.id)}
                className={`px-3.5 py-2 rounded-xl text-sm transition-colors ${
                  view === v.id
                    ? 'bg-[#7C3AED] text-white'
                    : 'bg-overlay-8 border border-line text-fg-muted hover:text-fg-strong hover:border-[#7C3AED]/40'
                }`}
              >
                {v.label}{count === null ? '' : ` (${count})`}
              </button>
            )
          })}
        </div>
        <button onClick={openManual} className="flex items-center gap-2 px-4 py-2 bg-[#7C3AED] text-white rounded-lg text-sm hover:bg-[#6D28D9]">
          <Plus className="w-4 h-4" /> Add Manually
        </button>
      </div>

      <div role="tabpanel" aria-label="QR content" className="flex-1 min-h-0 min-w-0 flex">
        {view === 'codes' && (
          /* The pair now SPANS the content width - one card hard left, one hard
             right - instead of sitting as a centred island in a wide empty
             band. Each code is measured to fill its own card (useFitSquare), so
             the two grow together instead of one size being right for a 1080p
             monitor and wrong for a laptop.

             `data-qr` sits on the CARD, not on the <svg>: the verification
             scripts used to find the codes by `svg[height="160"]`, which
             silently stops matching the moment the size is anything but 160.
             A test hook that describes the element rather than its pixel size
             survives the layout change that is the point of this edit. */
          <div className="flex-1 min-h-0 min-w-0 grid grid-cols-1 lg:grid-cols-2 gap-5">
            <div
              data-qr="enrollment"
              ref={enrollRef}
              className="glass-card rounded-2xl w-full min-h-0 min-w-0 p-6 flex flex-col items-center justify-center"
            >
              <p className="text-base font-semibold text-fg-strong mb-4">Enrollment Form</p>
              <QRCodeSVG value={PAGE_URL} size={enrollSize} bgColor={qrBg} fgColor={qrFg} />
              <p className="text-sm text-fg-muted mt-5 text-center">Scan to open the sign-up form</p>
            </div>
            <div
              data-qr="checkin"
              ref={checkinRef}
              className="glass-card rounded-2xl w-full min-h-0 min-w-0 p-6 flex flex-col items-center justify-center border-[#22C55E]/30"
            >
              <p className="text-base font-semibold text-fg-strong mb-4">Check-in / Check-out</p>
              <QRCodeSVG value="FITGYM:ATTENDANCE" size={checkinSize} bgColor={qrBg} fgColor={qrFg} />
              <p className="text-sm text-fg-muted mt-5 text-center">Scan in fitness app to check in or out</p>
            </div>
          </div>
        )}

      {/* The two lists are now views of their own, each a paged records table
          instead of a full-height inline card with no pager. The page size is
          left to RecordsTable to MEASURE, as every dashboard tab does: pinning
          15 rows overflowed the body this page actually has by 15px (the tab
          strip costs the table its last row), and a pinned size that scrolls is
          the failure mode the list pages' measured row height was built to
          avoid. */}
      {view === 'pending' && (
        <RecordsTable
          title="Pending Enrollments"
          columns={pendingColumns}
          rows={pending}
          rowKey={e => e.id}
          searchFields={identityFields}
          searchPlaceholder="Search by name, email or phone…"
          searchValue={pendingSearch}
          onSearchChange={setPendingSearch}
          isLoading={isLoading}
          emptyMessage="No pending enrollments match these filters"
        />
      )}

      {view === 'confirmed' && (
        <RecordsTable
          title="Confirmed Members"
          columns={confirmedColumns}
          rows={confirmed}
          rowKey={e => e.id}
          searchFields={identityFields}
          searchPlaceholder="Search by name, email or phone…"
          searchValue={confirmedSearch}
          onSearchChange={setConfirmedSearch}
          isLoading={isLoading}
          emptyMessage="No confirmed members match these filters"
        />
      )}
      </div>

      {/* Drawer */}
      {showModal && (
        <div className="fixed inset-0 bg-black/60 z-50" onClick={() => setShowModal(false)}>
          <div className="glass-card slide-in-right fixed right-0 top-0 h-full w-full max-w-md flex flex-col rounded-l-2xl border-l border-line" onClick={e => e.stopPropagation()}>
            <div className="px-6 py-4 border-b border-line flex items-center justify-between">
              <h2 className="text-lg font-semibold text-fg-strong">
                {isManual ? 'Add Member Manually' : selected?.status === 'pending' ? 'Review Enrollment' : 'View Enrollment'}
              </h2>
              <button onClick={() => setShowModal(false)} className="text-fg-muted hover:text-fg">
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="px-6 py-4 flex-1 overflow-y-auto">
              <EnrollmentForm
                data={formData} onChange={setFormData}
                includePassword={isManual} password={password} onPasswordChange={setPassword}
                confirmPassword={confirmPassword} onConfirmPasswordChange={setConfirmPassword}
                singleColumn
              />
              {selected && !isManual && (
                <HealthBackgroundSection value={healthBackground} onChange={setHealthBackground} />
              )}
            </div>
            <div className="px-6 py-4 border-t border-line flex justify-end gap-3">
              <button onClick={() => setShowModal(false)}
                className="px-4 py-2 text-sm border border-line rounded-lg text-fg hover:bg-overlay-8">Cancel</button>
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

import { useState } from 'react'
import { Eye, EyeOff } from 'lucide-react'


interface EnrollmentFormData {
  fullName: string
  email: string
  phone: string
  dateOfBirth: string
  gender: string
  civilStatus: string
  religion: string
  religionOther: string
  address: string
  emergencyContactName: string
  emergencyContactPhone: string
}

interface EnrollmentFormProps {
  data: EnrollmentFormData
  onChange: (data: EnrollmentFormData) => void
  includePassword?: boolean
  password?: string
  onPasswordChange?: (v: string) => void
  confirmPassword?: string
  onConfirmPasswordChange?: (v: string) => void
  singleColumn?: boolean
}

const emptyForm: EnrollmentFormData = {
  fullName: '',
  email: '',
  phone: '',
  dateOfBirth: '',
  gender: '',
  civilStatus: '',
  religion: '',
  religionOther: '',
  address: '',
  emergencyContactName: '',
  emergencyContactPhone: '',
}

const inputCls = 'w-full px-3 py-2.5 bg-overlay-8 border border-line rounded-lg text-sm text-fg-strong focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50 focus:border-[#7C3AED] placeholder:text-fg-muted'
const inputErrorCls = 'w-full px-3 py-2.5 bg-overlay-8 border border-[#EF4444] rounded-lg text-sm text-fg-strong focus:outline-none focus:ring-2 focus:ring-[#EF4444]/50 focus:border-[#EF4444] placeholder:text-fg-muted'
const labelCls = 'block text-sm font-medium text-fg mb-1'

function getPhoneError(v: string): string | null {
  if (!v) return null
  const digits = v.replace(/\D/g, '')
  if (digits.length > 11) return 'Phone number must be no more than 11 digits'
  return null
}

function getAge(value: string): string {
  if (!value) return ''
  const dob = new Date(`${value}T00:00:00`)
  if (Number.isNaN(dob.getTime()) || dob > new Date()) return ''
  const now = new Date()
  let age = now.getFullYear() - dob.getFullYear()
  if (now.getMonth() < dob.getMonth() || (now.getMonth() === dob.getMonth() && now.getDate() < dob.getDate())) age -= 1
  return age >= 0 ? String(age) : ''
}

export { emptyForm }
export type { EnrollmentFormData }

export default function EnrollmentForm({ data, onChange, includePassword, password, onPasswordChange, confirmPassword, onConfirmPasswordChange, singleColumn }: EnrollmentFormProps) {
  const [showPassword, setShowPassword] = useState(false)
  const [showConfirmPassword, setShowConfirmPassword] = useState(false)
  const phoneError = getPhoneError(data.phone)
  const emergencyPhoneError = getPhoneError(data.emergencyContactPhone)
  const set = (field: keyof EnrollmentFormData) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    onChange({ ...data, [field]: e.target.value })
  }
  const gridCls = singleColumn ? 'grid grid-cols-1 gap-4' : 'grid grid-cols-1 md:grid-cols-2 gap-4'

  return (
    <div className="space-y-4">
      <div className={gridCls}>
        <div>
          <label className={labelCls}>Full Name *</label>
          <input value={data.fullName} onChange={set('fullName')} className={inputCls} placeholder="Enter full name" />
        </div>
        <div>
          <label className={labelCls}>Email *</label>
          <input value={data.email} onChange={set('email')} className={inputCls} type="email" placeholder="email@example.com" />
        </div>
        <div>
          <label className={labelCls}>Phone</label>
          <input value={data.phone} onChange={e => onChange({ ...data, phone: e.target.value.replace(/\D/g, '').slice(0, 11) })} className={phoneError ? inputErrorCls : inputCls} type="tel" inputMode="numeric" maxLength={11} placeholder="09123456789" />
          {phoneError && <p className="text-xs text-[#EF4444] mt-1">{phoneError}</p>}
        </div>
        <div>
          <label className={labelCls}>Date of Birth</label>
          <input value={data.dateOfBirth} onChange={set('dateOfBirth')} className={inputCls} type="date" />
        </div>
        <div>
          <label className={labelCls}>Age</label>
          <input value={getAge(data.dateOfBirth)} className={`${inputCls} opacity-75`} readOnly placeholder="Calculated from date of birth" />
        </div>
        <div>
          <label className={labelCls}>Gender</label>
          <select value={data.gender} onChange={set('gender')} className={inputCls} style={{ colorScheme: 'dark' }}>
            <option style={{ backgroundColor: '#11152F', color: '#FFFFFF' }} value="">Select</option>
            <option style={{ backgroundColor: '#11152F', color: '#FFFFFF' }} value="male">Male</option>
            <option style={{ backgroundColor: '#11152F', color: '#FFFFFF' }} value="female">Female</option>
            <option style={{ backgroundColor: '#11152F', color: '#FFFFFF' }} value="prefer_not_to_say">Prefer not to say</option>
          </select>
        </div>
        <div>
          <label className={labelCls}>Civil Status</label>
          <select value={data.civilStatus} onChange={set('civilStatus')} className={inputCls}>
            <option value="">Select</option>
            <option value="single">Single</option>
            <option value="married">Married</option>
          </select>
        </div>
        <div>
          <label className={labelCls}>Religion</label>
          <select value={data.religion} onChange={set('religion')} className={inputCls}>
            <option value="">Select</option>
            <option value="roman_catholic">Roman Catholic</option>
            <option value="christian">Christian</option>
            <option value="iglesia_ni_cristo">Iglesia ni Cristo</option>
            <option value="islam">Islam</option>
            <option value="other">Other</option>
          </select>
        </div>
        {data.religion === 'other' && <div>
          <label className={labelCls}>Please specify religion</label>
          <input value={data.religionOther} onChange={set('religionOther')} className={inputCls} maxLength={120} />
        </div>}
        <div className="md:col-span-2">
          <label className={labelCls}>Address</label>
          <textarea value={data.address} onChange={set('address')} className={inputCls} rows={2} placeholder="Enter address" />
        </div>
      </div>

      <div className="border-t border-line pt-4">
        <h4 className="text-sm font-semibold text-fg-strong mb-3">Emergency Contact</h4>
        <div className={gridCls}>
          <div>
            <label className={labelCls}>Contact Name</label>
            <input value={data.emergencyContactName} onChange={set('emergencyContactName')} className={inputCls} placeholder="Emergency contact name" />
          </div>
          <div>
            <label className={labelCls}>Contact Phone</label>
            <input value={data.emergencyContactPhone} onChange={e => onChange({ ...data, emergencyContactPhone: e.target.value.replace(/\D/g, '').slice(0, 11) })} className={emergencyPhoneError ? inputErrorCls : inputCls} type="tel" inputMode="numeric" maxLength={11} placeholder="09123456789" />
            {emergencyPhoneError && <p className="text-xs text-[#EF4444] mt-1">{emergencyPhoneError}</p>}
          </div>
        </div>
      </div>

      {includePassword && (
        <div className="border-t border-line pt-4">
          <h4 className="text-sm font-semibold text-fg-strong mb-3">Account Setup</h4>
          <div className={`${gridCls} max-w-md`}>
            <div>
              <label className={labelCls}>Password *</label>
              <div className="relative">
                <input value={password ?? ''} onChange={e => onPasswordChange?.(e.target.value)} className={`${inputCls} min-h-[44px] pr-12`} type={showPassword ? 'text' : 'password'} placeholder="Enter password" autoComplete="new-password" />
                <button type="button" onClick={() => setShowPassword(value => !value)} aria-label={showPassword ? 'Hide password' : 'Show password'} aria-pressed={showPassword}
                  className="absolute right-1 top-1/2 grid h-11 w-11 -translate-y-1/2 place-items-center rounded-lg text-fg-muted transition-colors hover:bg-overlay-8 hover:text-fg focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#7C3AED]">
                  {showPassword ? <EyeOff className="h-5 w-5" aria-hidden="true" /> : <Eye className="h-5 w-5" aria-hidden="true" />}
                </button>
              </div>
            </div>
            <div>
              <label className={labelCls}>Confirm Password *</label>
              <div className="relative">
                <input value={confirmPassword ?? ''} onChange={e => onConfirmPasswordChange?.(e.target.value)} className={`${inputCls} min-h-[44px] pr-12 ${confirmPassword && password !== confirmPassword ? 'border-[#EF4444] focus:ring-[#EF4444]/50' : ''}`} type={showConfirmPassword ? 'text' : 'password'} placeholder="Confirm password" autoComplete="new-password" aria-invalid={!!confirmPassword && password !== confirmPassword} aria-describedby={confirmPassword && password !== confirmPassword ? 'manual-password-match-error' : undefined} />
                <button type="button" onClick={() => setShowConfirmPassword(value => !value)} aria-label={showConfirmPassword ? 'Hide confirmation password' : 'Show confirmation password'} aria-pressed={showConfirmPassword}
                  className="absolute right-1 top-1/2 grid h-11 w-11 -translate-y-1/2 place-items-center rounded-lg text-fg-muted transition-colors hover:bg-overlay-8 hover:text-fg focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#7C3AED]">
                  {showConfirmPassword ? <EyeOff className="h-5 w-5" aria-hidden="true" /> : <Eye className="h-5 w-5" aria-hidden="true" />}
                </button>
              </div>
              {confirmPassword && password !== confirmPassword && (
                <p id="manual-password-match-error" className="mt-1.5 text-xs text-[#FCA5A5]" role="alert">Passwords do not match.</p>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}


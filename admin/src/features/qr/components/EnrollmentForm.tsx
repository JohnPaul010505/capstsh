interface EnrollmentFormData {
  fullName: string
  email: string
  phone: string
  dateOfBirth: string
  gender: string
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
}

const emptyForm: EnrollmentFormData = {
  fullName: '',
  email: '',
  phone: '',
  dateOfBirth: '',
  gender: '',
  address: '',
  emergencyContactName: '',
  emergencyContactPhone: '',
}

const inputCls = 'w-full px-3 py-2.5 bg-white/[0.08] border border-white/10 rounded-lg text-sm text-[#ECECFC] focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/50 focus:border-[#7C3AED] placeholder:text-[#55557A]'
const inputErrorCls = 'w-full px-3 py-2.5 bg-white/[0.08] border border-[#EF4444] rounded-lg text-sm text-[#ECECFC] focus:outline-none focus:ring-2 focus:ring-[#EF4444]/50 focus:border-[#EF4444] placeholder:text-[#55557A]'
const labelCls = 'block text-sm font-medium text-[#B4B4D0] mb-1'

function getPhoneError(v: string): string | null {
  if (!v) return null
  const digits = v.replace(/\D/g, '')
  if (digits.length !== 11) return 'Phone number must be exactly 11 digits'
  return null
}

export { emptyForm }
export type { EnrollmentFormData }

export default function EnrollmentForm({ data, onChange, includePassword, password, onPasswordChange, confirmPassword, onConfirmPasswordChange }: EnrollmentFormProps) {
  const phoneError = getPhoneError(data.phone)
  const emergencyPhoneError = getPhoneError(data.emergencyContactPhone)
  const set = (field: keyof EnrollmentFormData) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    onChange({ ...data, [field]: e.target.value })
  }

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
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
          <input value={data.phone} onChange={set('phone')} className={phoneError ? inputErrorCls : inputCls} placeholder="09123456789" />
          {phoneError && <p className="text-xs text-[#EF4444] mt-1">{phoneError}</p>}
        </div>
        <div>
          <label className={labelCls}>Date of Birth</label>
          <input value={data.dateOfBirth} onChange={set('dateOfBirth')} className={inputCls} type="date" />
        </div>
        <div>
          <label className={labelCls}>Gender</label>
          <select value={data.gender} onChange={set('gender')} className={inputCls}>
            <option className="bg-white/[0.08]" value="">Select</option>
            <option className="bg-white/[0.08]" value="male">Male</option>
            <option className="bg-white/[0.08]" value="female">Female</option>
            <option className="bg-white/[0.08]" value="other">Other</option>
          </select>
        </div>
        <div className="md:col-span-2">
          <label className={labelCls}>Address</label>
          <textarea value={data.address} onChange={set('address')} className={inputCls} rows={2} placeholder="Enter address" />
        </div>
      </div>

      <div className="border-t border-white/10 pt-4">
        <h4 className="text-sm font-semibold text-[#ECECFC] mb-3">Emergency Contact</h4>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className={labelCls}>Contact Name</label>
            <input value={data.emergencyContactName} onChange={set('emergencyContactName')} className={inputCls} placeholder="Emergency contact name" />
          </div>
          <div>
            <label className={labelCls}>Contact Phone</label>
            <input value={data.emergencyContactPhone} onChange={set('emergencyContactPhone')} className={emergencyPhoneError ? inputErrorCls : inputCls} placeholder="09123456789" />
            {emergencyPhoneError && <p className="text-xs text-[#EF4444] mt-1">{emergencyPhoneError}</p>}
          </div>
        </div>
      </div>

      {includePassword && (
        <div className="border-t border-white/10 pt-4">
          <h4 className="text-sm font-semibold text-[#ECECFC] mb-3">Account Setup</h4>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 max-w-md">
            <div>
              <label className={labelCls}>Password *</label>
              <input value={password ?? ''} onChange={e => onPasswordChange?.(e.target.value)} className={inputCls} type="password" placeholder="Enter password" />
            </div>
            <div>
              <label className={labelCls}>Confirm Password *</label>
              <input value={confirmPassword ?? ''} onChange={e => onConfirmPasswordChange?.(e.target.value)} className={`${inputCls} ${confirmPassword && password !== confirmPassword ? 'border-[#EF4444] focus:ring-[#EF4444]/50' : ''}`} type="password" placeholder="Confirm password" />
            </div>
          </div>
          {confirmPassword && password !== confirmPassword && (
            <p className="text-xs text-[#EF4444] mt-2">Passwords do not match</p>
          )}
        </div>
      )}
    </div>
  )
}

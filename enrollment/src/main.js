import './style.css'

const form = document.querySelector('#enrollment-form')
const message = document.querySelector('#form-message')
const submitButton = document.querySelector('#submit-button')
const successPanel = document.querySelector('#success-panel')

function hasValidPhone(value) {
  if (!value.trim()) return true
  return value.replace(/\D/g, '').length === 11
}

function showError(text) {
  message.textContent = text
  message.classList.add('is-error')
}

form.addEventListener('submit', async (event) => {
  event.preventDefault()
  message.textContent = ''
  message.classList.remove('is-error')

  if (!form.reportValidity()) return

  const fields = new FormData(form)
  const phone = String(fields.get('phone') || '').trim()
  const emergencyContactPhone = String(fields.get('emergencyContactPhone') || '').trim()
  if (!hasValidPhone(phone) || !hasValidPhone(emergencyContactPhone)) {
    showError('Phone numbers must contain exactly 11 digits.')
    return
  }

  const payload = {
    fullName: String(fields.get('fullName') || '').trim(),
    email: String(fields.get('email') || '').trim(),
    phone,
    dateOfBirth: String(fields.get('dateOfBirth') || ''),
    gender: String(fields.get('gender') || ''),
    address: String(fields.get('address') || '').trim(),
    emergencyContactName: String(fields.get('emergencyContactName') || '').trim(),
    emergencyContactPhone,
    website: String(fields.get('website') || ''),
  }

  submitButton.disabled = true
  submitButton.textContent = 'Sending application…'
  try {
    const response = await fetch('/api/enroll', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    })
    const result = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(result.error || 'We could not send your application. Please try again.')
    form.hidden = true
    successPanel.hidden = false
  } catch (error) {
    showError(error instanceof Error ? error.message : 'Connection problem. Please try again.')
  } finally {
    submitButton.disabled = false
    submitButton.textContent = 'Submit application'
  }
})

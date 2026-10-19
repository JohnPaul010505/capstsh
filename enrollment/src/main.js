import './style.css'

const form = document.querySelector('#enrollment-form')
const message = document.querySelector('#form-message')
const submitButton = document.querySelector('#submit-button')
const successPanel = document.querySelector('#success-panel')
const detailsStep = document.querySelector('#details-step')
const healthStep = document.querySelector('#health-step')
const accountStep = document.querySelector('#account-step')
const indicatorOne = document.querySelector('#step-one-indicator')
const indicatorTwo = document.querySelector('#step-two-indicator')
const indicatorThree = document.querySelector('#step-three-indicator')
const passwordInput = document.querySelector('#password-input')
const confirmPasswordInput = document.querySelector('#confirm-password-input')
const passwordMatchError = document.querySelector('#password-match-error')

function showError(text) {
  message.textContent = text
  message.classList.add('is-error')
}

function clearError() {
  message.textContent = ''
  message.classList.remove('is-error')
}

function syncPasswordMatch(force = false) {
  const mismatch = (confirmPasswordInput.value.length > 0 || force) &&
    confirmPasswordInput.value !== passwordInput.value
  passwordMatchError.hidden = !mismatch
  confirmPasswordInput.setAttribute('aria-invalid', String(mismatch))
  return mismatch
}

document.querySelectorAll('[data-toggle-password]').forEach((button) => {
  button.addEventListener('click', () => {
    const input = document.getElementById(button.dataset.togglePassword)
    const show = input.type === 'password'
    input.type = show ? 'text' : 'password'
    button.textContent = show ? 'Hide' : 'Show'
    button.setAttribute('aria-pressed', String(show))
    button.setAttribute('aria-label', `${show ? 'Hide' : 'Show'} ${input.name === 'confirmPassword' ? 'confirmation password' : 'password'}`)
  })
})

passwordInput.addEventListener('input', () => syncPasswordMatch())
confirmPasswordInput.addEventListener('input', () => syncPasswordMatch())

function setStep(step) {
  detailsStep.hidden = step !== 1
  healthStep.hidden = step !== 2
  accountStep.hidden = step !== 3
  ;[indicatorOne, indicatorTwo, indicatorThree].forEach((indicator, index) => {
    const current = index + 1 === step
    indicator.classList.toggle('is-current', current)
    if (current) indicator.setAttribute('aria-current', 'step')
    else indicator.removeAttribute('aria-current')
  })
  clearError()
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

function validDigits(value) {
  return !value || /^\d{1,11}$/.test(value)
}

function readPhoneInput(event) {
  const input = event.currentTarget
  input.value = input.value.replace(/\D/g, '').slice(0, 11)
  input.setCustomValidity(input.value && !validDigits(input.value) ? 'Enter up to 11 digits.' : '')
}

document.querySelectorAll('input[name="phone"], input[name="emergencyContactPhone"]').forEach((input) => {
  input.addEventListener('input', readPhoneInput)
})

document.querySelector('#religion').addEventListener('change', (event) => {
  const otherField = document.querySelector('#religion-other-field')
  const otherInput = otherField.querySelector('input')
  const isOther = event.target.value === 'other'
  otherField.hidden = !isOther
  otherInput.required = isOther
  if (!isOther) otherInput.value = ''
})

document.querySelector('[name="dateOfBirth"]').addEventListener('change', (event) => {
  const value = event.target.value
  const ageInput = document.querySelector('#age')
  if (!value) {
    ageInput.value = ''
    return
  }
  const dob = new Date(`${value}T00:00:00`)
  const today = new Date()
  let age = today.getFullYear() - dob.getFullYear()
  const beforeBirthday = today.getMonth() < dob.getMonth() ||
    (today.getMonth() === dob.getMonth() && today.getDate() < dob.getDate())
  if (beforeBirthday) age -= 1
  ageInput.value = age >= 0 ? String(age) : ''
})

document.querySelectorAll('input[type="radio"][name]').forEach((radio) => {
  radio.addEventListener('change', () => {
    const name = radio.name
    const selected = form.querySelector(`input[name="${name}"]:checked`)?.value
    const otherField = document.querySelector(`[data-other-for="${name}"]`)
    if (!otherField) return
    otherField.hidden = selected !== 'other'
    const input = otherField.querySelector('textarea')
    input.required = selected === 'other'
    if (selected !== 'other') input.value = ''
  })
})

document.querySelector('#to-health-button').addEventListener('click', () => {
  clearError()
  const requiredInputs = detailsStep.querySelectorAll('input[required]')
  for (const input of requiredInputs) {
    if (!input.reportValidity()) return
  }
  const phone = form.elements.phone.value.trim()
  const emergencyPhone = form.elements.emergencyContactPhone.value.trim()
  if (!validDigits(phone) || !validDigits(emergencyPhone)) {
    showError('Phone numbers can contain a maximum of 11 digits.')
    return
  }
  if (form.elements.dateOfBirth.value && !document.querySelector('#age').value) {
    showError('Date of birth cannot be in the future.')
    return
  }
  setStep(2)
})

document.querySelector('#back-to-details-button').addEventListener('click', () => setStep(1))
document.querySelector('#back-to-health-button').addEventListener('click', () => setStep(2))

document.querySelector('#to-account-button').addEventListener('click', () => {
  clearError()
  const fields = new FormData(form)
  for (const key of ['illnessOrHeartProblem', 'recentDoctorVisit', 'movementDifficulty', 'jointBackShoulderLegInjury']) {
    const choice = fields.get(key)
    if (!choice) {
      showError('Please answer all health screening questions.')
      form.querySelector(`input[name="${key}"]`).focus()
      return
    }
    if (choice === 'other' && !String(fields.get(`${key}Details`) || '').trim()) {
      showError('Please explain each answer marked Other.')
      form.querySelector(`[data-other-for="${key}"] textarea`).focus()
      return
    }
  }
  setStep(3)
})

function getHealthAnswer(fields, key) {
  const choice = String(fields.get(key) || '')
  return {
    choice,
    details: choice === 'other' ? String(fields.get(`${key}Details`) || '').trim() : '',
  }
}

form.addEventListener('submit', async (event) => {
  event.preventDefault()
  clearError()
  if (accountStep.hidden) return

  const fields = new FormData(form)
  const healthKeys = [
    'illnessOrHeartProblem',
    'recentDoctorVisit',
    'movementDifficulty',
    'jointBackShoulderLegInjury',
  ]
  for (const key of healthKeys) {
    if (!fields.get(key)) {
      showError('Please answer all health screening questions.')
      document.querySelector(`input[name="${key}"]`).focus()
      return
    }
    if (fields.get(key) === 'other' && !String(fields.get(`${key}Details`) || '').trim()) {
      showError('Please add a short explanation for each Other answer.')
      document.querySelector(`[data-other-for="${key}"] textarea`).focus()
      return
    }
  }

  const password = String(fields.get('password') || '')
  const confirmPassword = String(fields.get('confirmPassword') || '')
  if (password.length < 8 || password.length > 72) {
    showError('Choose a password between 8 and 72 characters.')
    form.elements.password.focus()
    return
  }
  if (password !== confirmPassword) {
    syncPasswordMatch(true)
    form.elements.confirmPassword.focus()
    return
  }

  const payload = {
    fullName: String(fields.get('fullName') || '').trim(),
    email: String(fields.get('email') || '').trim(),
    phone: String(fields.get('phone') || '').trim(),
    dateOfBirth: String(fields.get('dateOfBirth') || ''),
    gender: String(fields.get('gender') || ''),
    civilStatus: String(fields.get('civilStatus') || ''),
    religion: String(fields.get('religion') || ''),
    religionOther: String(fields.get('religionOther') || '').trim(),
    address: String(fields.get('address') || '').trim(),
    emergencyContactName: String(fields.get('emergencyContactName') || '').trim(),
    emergencyContactPhone: String(fields.get('emergencyContactPhone') || '').trim(),
    healthBackground: Object.fromEntries(healthKeys.map((key) => [key, getHealthAnswer(fields, key)])),
    password,
    confirmPassword,
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

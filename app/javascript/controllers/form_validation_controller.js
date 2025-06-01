import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "feedback"]
  static values = { rules: Object }

  connect() {
    this.validateAll()
  }

  validateField(event) {
    const field = event.target
    const fieldName = field.name.split('[').pop().split(']')[0]
    this.validateSingleField(field, fieldName)
  }

  validateAll() {
    this.fieldTargets.forEach(field => {
      const fieldName = field.name.split('[').pop().split(']')[0]
      this.validateSingleField(field, fieldName)
    })
  }

  validateSingleField(field, fieldName) {
    const rules = this.rulesValue[fieldName]
    if (!rules) return

    const value = field.value
    const errors = []

    // Required validation
    if (rules.required && (!value || value.trim() === '')) {
      errors.push('Este campo é obrigatório')
    }

    // Minimum length validation
    if (rules.minLength && value.length < rules.minLength) {
      errors.push(`Deve ter pelo menos ${rules.minLength} caracteres`)
    }

    // Minimum value validation
    if (rules.minValue && parseFloat(value) < rules.minValue) {
      errors.push(`Deve ser maior que ${rules.minValue}`)
    }

    // Email validation
    if (rules.email && value && !this.isValidEmail(value)) {
      errors.push('Email inválido')
    }

    // Update field appearance
    this.updateFieldAppearance(field, errors.length === 0)
    
    // Update feedback
    this.updateFeedback(fieldName, errors)
  }

  updateFieldAppearance(field, isValid) {
    if (isValid) {
      field.classList.remove('input-error', 'select-error')
      field.classList.add('input-success', 'select-success')
    } else {
      field.classList.remove('input-success', 'select-success')
      field.classList.add('input-error', 'select-error')
    }
  }

  updateFeedback(fieldName, errors) {
    const feedbackElement = this.feedbackTargets.find(
      el => el.dataset.field === fieldName
    )
    
    if (feedbackElement) {
      if (errors.length > 0) {
        feedbackElement.textContent = errors[0]
        feedbackElement.classList.remove('text-success')
        feedbackElement.classList.add('text-error')
      } else {
        feedbackElement.textContent = '✓ Válido'
        feedbackElement.classList.remove('text-error')
        feedbackElement.classList.add('text-success')
      }
    }
  }

  isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  }
}

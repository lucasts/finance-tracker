import { Controller } from "@hotwired/stimulus"

// Focused controller for currency validation
export default class extends Controller {
  static targets = ["input", "helper", "error"]
  static values = { 
    min: Number, 
    max: Number, 
    required: Boolean 
  }

  connect() {
    this.setupValidation()
  }

  setupValidation() {
    if (this.hasInputTarget) {
      this.inputTarget.addEventListener('blur', this.validate.bind(this))
      this.inputTarget.addEventListener('input', this.updateHelper.bind(this))
    }
  }

  validate() {
    const value = MoneyFormatter.getNumericValue(this.inputTarget)
    const errors = []

    // Required validation
    if (this.requiredValue && value === 0) {
      errors.push('Valor é obrigatório')
    }

    // Min validation
    if (this.hasMinValue && value < this.minValue) {
      errors.push(`Valor mínimo: ${MoneyFormatter.format(this.minValue)}`)
    }

    // Max validation  
    if (this.hasMaxValue && value > this.maxValue) {
      errors.push(`Valor máximo: ${MoneyFormatter.format(this.maxValue)}`)
    }

    this.displayErrors(errors)
    return errors.length === 0
  }

  updateHelper() {
    if (this.hasHelperTarget) {
      const value = MoneyFormatter.getNumericValue(this.inputTarget)
      
      if (value > 0) {
        this.helperTarget.textContent = `Valor: ${MoneyFormatter.format(value)}`
        this.helperTarget.classList.remove('text-muted')
      } else {
        this.helperTarget.textContent = 'Digite o valor'
        this.helperTarget.classList.add('text-muted')
      }
    }
  }

  displayErrors(errors) {
    if (this.hasErrorTarget) {
      if (errors.length > 0) {
        this.errorTarget.textContent = errors[0]
        this.errorTarget.classList.remove('hidden')
        this.inputTarget.classList.add('input-error')
      } else {
        this.errorTarget.classList.add('hidden')
        this.inputTarget.classList.remove('input-error')
      }
    }
  }

  get isValid() {
    return this.validate()
  }
}

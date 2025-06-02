import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="recurrence"
export default class extends Controller {
  static targets = [
    "repeatCheckbox",
    "repeatOptions",
    "repeatType",
    "hiddenType",
    "recurringSection", 
    "installmentSection",
    "frequency",
    "installmentsCount",
    "installmentPreview",
    "installmentValue",
    "firstDate",
    "lastDate",
    "createRecurring",
    "createInstallment"
  ]

  connect() {
    this.updateDisplay()
  }

  handleRepeatToggle() {
    this.updateDisplay()
  }

  handleTypeChange() {
    this.updateDisplay()
  }

  updateDisplay() {
    const isRepeating = this.repeatCheckboxTarget.checked
    const selectedType = this.getSelectedRepeatType()
    
    // Show/hide repeat options
    if (isRepeating) {
      this.repeatOptionsTarget.classList.remove('hidden')
    } else {
      this.repeatOptionsTarget.classList.add('hidden')
    }
    
    // Hide all sections first
    this.recurringSection?.classList.add('hidden')
    this.installmentSection?.classList.add('hidden')
    
    // Update hidden field and show relevant section
    if (!isRepeating) {
      this.hiddenTypeTarget.value = "single"
      this.createRecurringTarget.value = ""
      this.createInstallmentTarget.value = ""
    } else {
      switch(selectedType) {
        case 'recurring':
          this.hiddenTypeTarget.value = "recurring"
          this.recurringSection?.classList.remove('hidden')
          this.createRecurringTarget.value = "true"
          this.createInstallmentTarget.value = ""
          break
        case 'installment':
          this.hiddenTypeTarget.value = "installment"
          this.installmentSection?.classList.remove('hidden')
          this.createInstallmentTarget.value = "true" 
          this.createRecurringTarget.value = ""
          break
        default:
          this.hiddenTypeTarget.value = "single"
          this.createRecurringTarget.value = ""
          this.createInstallmentTarget.value = ""
          break
      }
    }
  }

  getSelectedRepeatType() {
    const checkedRadio = this.repeatTypeTargets.find(radio => radio.checked)
    return checkedRadio ? checkedRadio.value : null
  }
      calculateInstallment() {
    const installmentsCount = parseInt(this.installmentsCountTarget.value)
    const amountField = document.querySelector('[data-transaction-form-target="amount"]')
    const eventDateField = document.querySelector('[data-transaction-form-target="eventDate"]')
    
    if (!installmentsCount || installmentsCount < 2 || !amountField?.value || !eventDateField?.value) {
      this.installmentPreviewTarget?.classList.add('hidden')
      return
    }

    const totalAmount = parseFloat(amountField.value)
    const installmentValue = totalAmount / installmentsCount
    const startDate = new Date(eventDateField.value)
    
    // Calculate dates
    const firstDate = new Date(startDate)
    const lastDate = new Date(startDate)
    lastDate.setMonth(lastDate.getMonth() + installmentsCount - 1)
    
    // Update preview
    this.installmentValueTarget.textContent = this.formatCurrency(installmentValue)
    this.firstDateTarget.textContent = this.formatDate(firstDate)
    this.lastDateTarget.textContent = this.formatDate(lastDate)
    
    // Show preview
    this.installmentPreviewTarget?.classList.remove('hidden')
  }

  formatCurrency(amount) {
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: 'BRL'
    }).format(amount)
  }

  formatDate(date) {
    return new Intl.DateTimeFormat('pt-BR', {
      month: 'short',
      year: 'numeric'
    }).format(date)
  }
}

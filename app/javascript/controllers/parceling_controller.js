import { Controller } from "@hotwired/stimulus"
import FormatUtils from "../utilities/format_utils"

export default class extends Controller {
  static targets = ["toggle", "section", "installmentsCount", "preview", "installmentValue", "firstDate", "lastDate", "createInstallments"]

  connect() {
    this.toggle()
    this.setupListeners()
    this.debounceTimeout = null
  }

  setupListeners() {
    // Add listeners for fields that affect installment calculation
    const amountInput = document.querySelector('input[name="transaction[amount]"]')
    const paymentDateInput = document.querySelector('input[name="transaction[payment_date]"]')
    const eventDateInput = document.querySelector('input[name="transaction[event_date]"]')

    if (amountInput) {
      amountInput.addEventListener('input', () => this.debouncedRecalculate())
    }

    if (paymentDateInput) {
      paymentDateInput.addEventListener('change', () => this.recalculateIfNeeded())
    }

    if (eventDateInput) {
      eventDateInput.addEventListener('change', () => this.recalculateIfNeeded())
    }
  }

  debouncedRecalculate() {
    // Clear previous timeout if exists
    if (this.debounceTimeout) {
      clearTimeout(this.debounceTimeout)
    }
    
    // Set a new timeout to recalculate after 300ms of inactivity
    this.debounceTimeout = setTimeout(() => {
      this.recalculateIfNeeded()
    }, 300)
  }

  recalculateIfNeeded() {
    // Only recalculate if installment is active and visible
    if (this.toggleTarget.checked && !this.sectionTarget.classList.contains('hidden')) {
      this.calculateInstallment()
    }
  }

  toggle() {
    const isChecked = this.toggleTarget.checked
    
    if (isChecked) {
      this.sectionTarget.classList.remove("hidden")
      this.sectionTarget.classList.add("animate-fade-in")
    } else {
      this.sectionTarget.classList.add("hidden")
      this.sectionTarget.classList.remove("animate-fade-in")
      this.hidePreview()
    }
  }

  calculateInstallment() {
    // Get the amount field value from the main form
    const amountInput = document.querySelector('input[name="transaction[amount]"]')
    // Use MoneyFormatter.parse to correctly handle Brazilian currency format
    const totalAmount = amountInput ? MoneyFormatter.parse(amountInput.value) : 0
    
    const installmentsCount = parseInt(this.installmentsCountTarget.value)

    if (!totalAmount || !installmentsCount || totalAmount <= 0 || installmentsCount < 2) {
      this.hidePreview()
      return
    }

    // Calculate installment value
    const installmentValue = totalAmount / installmentsCount

    // Get payment date from main form (priority) or event date
    const paymentDateInput = document.querySelector('input[name="transaction[payment_date]"]')
    const eventDateInput = document.querySelector('input[name="transaction[event_date]"]')
    
    let startDate
    if (paymentDateInput && paymentDateInput.value) {
      // Create date correctly avoiding timezone issues
      const dateParts = paymentDateInput.value.split('-')
      startDate = new Date(parseInt(dateParts[0]), parseInt(dateParts[1]) - 1, parseInt(dateParts[2]))
    } else if (eventDateInput && eventDateInput.value) {
      // Create date correctly avoiding timezone issues
      const dateParts = eventDateInput.value.split('-')
      startDate = new Date(parseInt(dateParts[0]), parseInt(dateParts[1]) - 1, parseInt(dateParts[2]))
    } else {
      startDate = new Date()
    }

    // Calculate first and last installment
    const firstDate = new Date(startDate)
    const lastDate = new Date(startDate)
    lastDate.setMonth(lastDate.getMonth() + installmentsCount - 1)

    // Add a small update animation
    this.addUpdateAnimation()

    // Update preview
    this.installmentValueTarget.textContent = MoneyFormatter.format(installmentValue)
    this.firstDateTarget.textContent = FormatUtils.formatDate(firstDate)
    this.lastDateTarget.textContent = FormatUtils.formatDate(lastDate)

    // Prepare data for backend
    const installmentData = {
      total_amount: totalAmount,
      installment_count: installmentsCount, // ✅ FIXED: Using installment_count for consistency
      installment_value: installmentValue,
      start_date: FormatUtils.formatDateForBackend(firstDate)
    }

    this.createInstallmentsTarget.value = JSON.stringify(installmentData)

    this.showPreview()
  }

  showPreview() {
    this.previewTarget.classList.remove("hidden")
    this.previewTarget.classList.add("animate-fade-in")
    
    // Add a small indicator that it was updated
    this.showUpdateIndicator()
  }

  showUpdateIndicator() {
    // Create a small temporary indicator
    const indicator = document.createElement('div')
    indicator.className = 'text-xs text-success opacity-75 animate-pulse'
    indicator.textContent = '✓ Updated'
    
    const previewDiv = this.previewTarget.querySelector('.bg-base-200')
    if (previewDiv && !previewDiv.querySelector('.update-indicator')) {
      indicator.classList.add('update-indicator')
      previewDiv.appendChild(indicator)
      
      // Remove indicator after 2 seconds
      setTimeout(() => {
        if (indicator.parentNode) {
          indicator.parentNode.removeChild(indicator)
        }
      }, 2000)
    }
  }

  hidePreview() {
    this.previewTarget.classList.add("hidden")
    this.previewTarget.classList.remove("animate-fade-in")
    this.createInstallmentsTarget.value = ""
  }

  addUpdateAnimation() {
    // Add a subtle animation to indicate data was updated
    const previewDiv = this.previewTarget.querySelector('.bg-base-200')
    if (previewDiv) {
      previewDiv.classList.add('animate-pulse')
      setTimeout(() => {
        previewDiv.classList.remove('animate-pulse')
      }, 300)
    }
  }
}

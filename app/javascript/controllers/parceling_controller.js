import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "section", "installmentsCount", "preview", "installmentValue", "firstDate", "lastDate", "createInstallments"]

  connect() {
    this.toggle()
    this.setupListeners()
    this.debounceTimeout = null
  }

  setupListeners() {
    // Adiciona listeners para campos que afetam o parcelamento
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
    // Limpa o timeout anterior se existir
    if (this.debounceTimeout) {
      clearTimeout(this.debounceTimeout)
    }
    
    // Define um novo timeout para recalcular após 300ms de inatividade
    this.debounceTimeout = setTimeout(() => {
      this.recalculateIfNeeded()
    }, 300)
  }

  recalculateIfNeeded() {
    // Só recalcula se o parcelamento estiver ativo e visível
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
    // Pega o valor do campo amount do formulário principal
    const amountInput = document.querySelector('input[name="transaction[amount]"]')
    const totalAmount = amountInput ? parseFloat(amountInput.value) : 0
    
    const installmentsCount = parseInt(this.installmentsCountTarget.value)

    if (!totalAmount || !installmentsCount || totalAmount <= 0 || installmentsCount < 2) {
      this.hidePreview()
      return
    }

    // Calcula valor da parcela
    const installmentValue = totalAmount / installmentsCount

    // Pega a data de pagamento do formulário principal (prioridade) ou data do evento
    const paymentDateInput = document.querySelector('input[name="transaction[payment_date]"]')
    const eventDateInput = document.querySelector('input[name="transaction[event_date]"]')
    
    let startDate
    if (paymentDateInput && paymentDateInput.value) {
      // Cria data corretamente evitando problemas de timezone
      const dateParts = paymentDateInput.value.split('-')
      startDate = new Date(parseInt(dateParts[0]), parseInt(dateParts[1]) - 1, parseInt(dateParts[2]))
    } else if (eventDateInput && eventDateInput.value) {
      // Cria data corretamente evitando problemas de timezone
      const dateParts = eventDateInput.value.split('-')
      startDate = new Date(parseInt(dateParts[0]), parseInt(dateParts[1]) - 1, parseInt(dateParts[2]))
    } else {
      startDate = new Date()
    }

    // Calcula primeira e última parcela
    const firstDate = new Date(startDate)
    const lastDate = new Date(startDate)
    lastDate.setMonth(lastDate.getMonth() + installmentsCount - 1)

    // Adiciona uma pequena animação de atualização
    this.addUpdateAnimation()

    // Atualiza preview
    this.installmentValueTarget.textContent = this.formatCurrency(installmentValue)
    this.firstDateTarget.textContent = this.formatDate(firstDate)
    this.lastDateTarget.textContent = this.formatDate(lastDate)

    // Prepara dados para o backend
    const installmentData = {
      total_amount: totalAmount,
      installments_count: installmentsCount,
      installment_value: installmentValue,
      start_date: this.formatDateForBackend(firstDate)
    }

    this.createInstallmentsTarget.value = JSON.stringify(installmentData)

    this.showPreview()
  }

  showPreview() {
    this.previewTarget.classList.remove("hidden")
    this.previewTarget.classList.add("animate-fade-in")
    
    // Adiciona um pequeno indicador de que foi atualizado
    this.showUpdateIndicator()
  }

  showUpdateIndicator() {
    // Cria um pequeno indicador temporário
    const indicator = document.createElement('div')
    indicator.className = 'text-xs text-success opacity-75 animate-pulse'
    indicator.textContent = '✓ Atualizado'
    
    const previewDiv = this.previewTarget.querySelector('.bg-base-200')
    if (previewDiv && !previewDiv.querySelector('.update-indicator')) {
      indicator.classList.add('update-indicator')
      previewDiv.appendChild(indicator)
      
      // Remove o indicador após 2 segundos
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
    // Adiciona uma animação sutil para indicar que os dados foram atualizados
    const previewDiv = this.previewTarget.querySelector('.bg-base-200')
    if (previewDiv) {
      previewDiv.classList.add('animate-pulse')
      setTimeout(() => {
        previewDiv.classList.remove('animate-pulse')
      }, 300)
    }
  }

  formatCurrency(value) {
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: 'BRL'
    }).format(value)
  }

  formatDate(date) {
    return new Intl.DateTimeFormat('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric'
    }).format(date)
  }

  formatDateForBackend(date) {
    // Formata a data evitando problemas de timezone
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    return `${year}-${month}-${day}`
  }
}

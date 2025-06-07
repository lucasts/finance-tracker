import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["amount", "amountHelper"]

  connect() {
    console.log("ImportedTransactionForm controller connected")
    this.setupInitialState()
  }

  setupInitialState() {
    // Initialize amount helper with current value
    this.handleAmountChange()
  }

  handleAmountChange() {
    const amount = parseFloat(this.amountTarget.value)
    
    if (amount > 0) {
      const formattedAmount = new Intl.NumberFormat('pt-BR', {
        style: 'currency',
        currency: 'BRL'
      }).format(amount)
      
      this.amountHelperTarget.textContent = `Valor: ${formattedAmount}`
    } else {
      this.amountHelperTarget.textContent = "Informe o valor da transação (use vírgula para centavos)"
    }
  }
}

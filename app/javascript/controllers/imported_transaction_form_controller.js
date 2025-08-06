import ApplicationController from "../helpers/application_controller"

export default class extends ApplicationController {
  static targets = ["amount"]
  static optionalTargets = ["amountHelper"]

  connect() {
    super.connect()
    this.setupInitialState()
  }

  setupInitialState() {
    // Initialize amount helper with current value
    this.handleAmountChange()
  }

  handleAmountChange() {
    if (!this.hasAmountTarget) {
      console.warn("Amount target not found")
      return
    }

    // Use MoneyFormatter.parse to correctly handle Brazilian currency format  
    const amount = MoneyFormatter.parse(this.amountTarget.value)
    
    if (this.hasAmountHelperTarget) {
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
}

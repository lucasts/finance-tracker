import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "transactionType", "description", "amount", "eventDate", "paymentDate",
    "fromAccount", "toAccount", "category", "submitButton",
    "accountsTitle", "fromAccountLabel", "toAccountLabel", 
    "fromAccountHelper", "toAccountHelper", "paymentDateHelper",
    "paymentDateSection", "creditCardInfo", "creditCardDetails",
    "categorySuggestions", "suggestionButtons", "amountHelper",
    "accountData", "categoryData", "categorySection"
  ]

  connect() {
    this.accountData = JSON.parse(this.accountDataTarget.textContent)
    this.categoryData = JSON.parse(this.categoryDataTarget.textContent)
    
    // Initialize form state
    this.updateFormState()
    this.setupInitialState()
    
    console.log("TransactionForm controller connected")
  }

  setupInitialState() {
    // Set default values if creating new transaction
    if (!this.eventDateTarget.value) {
      this.eventDateTarget.value = new Date().toISOString().split('T')[0]
    }
    
    // Trigger initial updates
    this.handleTypeChange()
    this.handleAccountChange()
    this.handleDescriptionChange()
  }

  handleTypeChange() {
    const selectedType = this.getSelectedTransactionType()
    
    if (selectedType === 'income') {
      this.updateForIncome()
    } else if (selectedType === 'expense') {
      this.updateForExpense()
    } else if (selectedType === 'transfer') {
      this.updateForTransfer()
    }
    
    // Filter categories based on transaction type
    this.filterCategoriesByType(selectedType)
    
    this.updateFormState()
  }

  handleDescriptionChange() {
    const description = this.descriptionTarget.value.toLowerCase()
    this.suggestCategory(description)
    this.suggestAccounts(description)
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
      this.amountHelperTarget.textContent = "Digite o valor da transação"
    }
  }

  handleDateChange() {
    this.updatePaymentDate()
  }

  handleAccountChange() {
    const fromAccountId = this.fromAccountTarget.value
    const fromAccount = this.accountData.find(acc => acc.id.toString() === fromAccountId)
    
    if (fromAccount) {
      this.updateForAccountType(fromAccount)
      this.filterToAccounts(fromAccount)
    }
    
    this.updateFormState()
  }

  handleToAccountChange() {
    this.updateFormState()
  }

  handleCategoryChange() {
    this.updateFormState()
  }

  // Private methods

  getSelectedTransactionType() {
    const checkedRadio = this.transactionTypeTargets.find(radio => radio.checked)
    return checkedRadio ? checkedRadio.value : null
  }

  updateForIncome() {
    this.accountsTitleTarget.textContent = "💰 Contas (Receita)"
    this.fromAccountLabelTarget.textContent = "De onde vem o dinheiro"
    this.toAccountLabelTarget.textContent = "Para qual conta"
    this.fromAccountHelperTarget.textContent = "Origem da receita (cliente, empregador, etc.)"
    this.toAccountHelperTarget.textContent = "Conta que receberá o dinheiro"
    
    // Show category section for income
    this.showCategorySection()
    
    // Filter accounts for income
    this.filterAccountsForIncome()
  }

  updateForExpense() {
    this.accountsTitleTarget.textContent = "💳 Contas (Despesa)"
    this.fromAccountLabelTarget.textContent = "Conta de Origem"
    this.toAccountLabelTarget.textContent = "Destino da Despesa"
    this.fromAccountHelperTarget.textContent = "De onde sai o dinheiro"
    this.toAccountHelperTarget.textContent = "Para onde vai o dinheiro (loja, serviço, etc.)"
    
    // Show category section for expenses
    this.showCategorySection()
    
    // Filter accounts for expense
    this.filterAccountsForExpense()
  }

  updateForTransfer() {
    this.accountsTitleTarget.textContent = "🔄 Contas (Transferência)"
    this.fromAccountLabelTarget.textContent = "Conta de Origem"
    this.toAccountLabelTarget.textContent = "Conta de Destino"
    this.fromAccountHelperTarget.textContent = "De onde sai o dinheiro"
    this.toAccountHelperTarget.textContent = "Para onde vai o dinheiro"
    
    // Hide category section for transfers
    this.hideCategorySection()
    
    // Clear category selection for transfers
    this.categoryTarget.value = ''
  }

  updateForAccountType(account) {
    if (account.type_code === 'CREDIT') {
      this.showCreditCardInfo(account)
      this.updatePaymentDateForCredit(account)
    } else {
      this.hideCreditCardInfo()
      this.updatePaymentDate()
    }
  }

  showCreditCardInfo(account) {
    this.creditCardInfoTarget.classList.remove('hidden')
    
    let detailsText = `Esta transação será associada automaticamente à fatura do cartão ${account.name}.`
    
    if (account.closing_day) {
      detailsText += ` Fechamento: dia ${account.closing_day} de cada mês.`
    }
    
    if (account.due_day) {
      detailsText += ` Vencimento: dia ${account.due_day} do mês seguinte.`
    }
    
    this.creditCardDetailsTarget.textContent = detailsText
  }

  hideCreditCardInfo() {
    this.creditCardInfoTarget.classList.add('hidden')
  }

  showCategorySection() {
    if (this.hasCategorySectionTarget) {
      this.categorySectionTarget.classList.remove('hidden')
    }
  }

  hideCategorySection() {
    if (this.hasCategorySectionTarget) {
      this.categorySectionTarget.classList.add('hidden')
    }
  }

  updatePaymentDate() {
    const eventDate = this.eventDateTarget.value
    if (eventDate && !this.paymentDateTarget.value) {
      this.paymentDateTarget.value = eventDate
      this.paymentDateHelperTarget.textContent = "Mesmo dia do evento (padrão)"
    }
  }

  updatePaymentDateForCredit(account) {
    const eventDate = new Date(this.eventDateTarget.value)
    
    if (account.due_day && eventDate) {
      // Credit card payment is usually next month on due day
      const paymentDate = new Date(eventDate)
      paymentDate.setMonth(paymentDate.getMonth() + 1)
      paymentDate.setDate(account.due_day)
      
      this.paymentDateTarget.value = paymentDate.toISOString().split('T')[0]
      this.paymentDateHelperTarget.textContent = `Vencimento da fatura: dia ${account.due_day} do próximo mês`
    }
  }

  suggestCategory(description) {
    // Simple category suggestion based on keywords
    const suggestions = this.getCategorySuggestions(description)
    
    if (suggestions.length > 0) {
      this.showCategorySuggestions(suggestions)
    } else {
      this.hideCategorySuggestions()
    }
  }

  getCategorySuggestions(description) {
    const transactionType = this.getSelectedTransactionType()
    
    const keywords = {
      'Supermercado': ['mercado', 'supermercado', 'zaffari', 'carrefour', 'walmart', 'big'],
      'Restaurante': ['restaurante', 'ifood', 'uber eats', 'pizza', 'lanche', 'café'],
      'Farmácia': ['farmácia', 'panvel', 'droga', 'medicamento', 'remédio'],
      'Combustível': ['posto', 'gasolina', 'álcool', 'combustível', 'ipiranga', 'shell'],
      'Saúde': ['médico', 'dentista', 'hospital', 'consulta', 'exame'],
      'Educação': ['escola', 'faculdade', 'curso', 'material escolar', 'mensalidade'],
      'Lazer': ['cinema', 'teatro', 'parque', 'viagem', 'netflix', 'spotify'],
      'Vestuário': ['roupa', 'sapato', 'calça', 'camisa', 'renner', 'c&a'],
      'Transporte': ['uber', '99', 'ônibus', 'taxi', 'passagem', 'transporte'],
      'Habitação': ['aluguel', 'condomínio', 'iptu', 'água', 'luz', 'energia'],
      // Income keywords
      'Salário': ['salário', 'salary', 'pagamento', 'ordenado'],
      'Freelance': ['freelance', 'freela', 'trabalho', 'projeto'],
      'PIX Recebido': ['pix', 'transferência', 'recebimento']
    }

    const suggestions = []
    
    for (const [category, keywordList] of Object.entries(keywords)) {
      if (keywordList.some(keyword => description.includes(keyword))) {
        const categoryData = this.categoryData.find(cat => 
          cat.name === category && cat.category_type === transactionType
        )
        if (categoryData) {
          suggestions.push(categoryData)
        }
      }
    }

    return suggestions.slice(0, 3) // Limit to 3 suggestions
  }

  showCategorySuggestions(suggestions) {
    this.categorySuggestionsTarget.classList.remove('hidden')
    
    this.suggestionButtonsTarget.innerHTML = suggestions.map(category => 
      `<button type="button" 
               class="btn btn-outline btn-sm" 
               data-action="click->transaction-form#selectSuggestedCategory"
               data-category-id="${category.id}">
         ${category.name}
       </button>`
    ).join('')
  }

  hideCategorySuggestions() {
    this.categorySuggestionsTarget.classList.add('hidden')
  }

  filterCategoriesByType(transactionType) {
    if (!transactionType) return
    
    // Get all option elements in the category select
    const categorySelect = this.categoryTarget
    const options = Array.from(categorySelect.options)
    
    // Clear current selection if it doesn't match the transaction type
    const currentCategoryId = categorySelect.value
    if (currentCategoryId) {
      const currentCategory = this.categoryData.find(cat => cat.id.toString() === currentCategoryId)
      if (currentCategory && currentCategory.category_type !== transactionType) {
        categorySelect.value = ''
      }
    }
    
    // Filter options based on transaction type
    options.forEach(option => {
      if (option.value === '') {
        // Keep the empty option
        option.style.display = ''
        return
      }
      
      const categoryData = this.categoryData.find(cat => cat.id.toString() === option.value)
      if (categoryData && categoryData.category_type === transactionType) {
        option.style.display = ''
      } else {
        option.style.display = 'none'
      }
    })
  }

  selectSuggestedCategory(event) {
    const categoryId = event.target.dataset.categoryId
    this.categoryTarget.value = categoryId
    this.hideCategorySuggestions()
    
    // Trigger change event
    this.categoryTarget.dispatchEvent(new Event('change'))
  }

  suggestAccounts(description) {
    // Auto-suggest accounts based on description keywords
    const transactionType = this.getSelectedTransactionType()
    
    if (transactionType === 'expense') {
      this.suggestExpenseAccounts(description)
    } else if (transactionType === 'income') {
      this.suggestIncomeAccounts(description)
    }
  }

  suggestExpenseAccounts(description) {
    // Suggest from_account based on amount and description
    const amount = parseFloat(this.amountTarget.value) || 0
    
    // Suggest credit card for larger amounts or online purchases
    if (amount > 200 || description.includes('online') || description.includes('amazon') || description.includes('ifood')) {
      const creditAccounts = this.accountData.filter(acc => acc.type_code === 'CREDIT')
      if (creditAccounts.length > 0 && !this.fromAccountTarget.value) {
        // Don't auto-select, but could highlight in the future
      }
    }
  }

  suggestIncomeAccounts(description) {
    // Suggest appropriate accounts for income
    if (description.includes('salário') || description.includes('salary')) {
      const bankAccounts = this.accountData.filter(acc => acc.type_code === 'BANK')
      if (bankAccounts.length > 0 && !this.toAccountTarget.value) {
        // Could auto-suggest the main bank account
      }
    }
  }

  filterAccountsForIncome() {
    // For income: from_account should be revenue accounts, to_account should be asset accounts
    // This would require updating the select options dynamically
    // For now, just update helper text
  }

  filterAccountsForExpense() {
    // For expense: from_account should be asset accounts, to_account should be expense accounts
    // This would require updating the select options dynamically
    // For now, just update helper text
  }

  filterToAccounts(fromAccount) {
    // Filter to_account options based on from_account selection
    // This would require dynamic updating of select options
    // For now, just update helper text based on account type
    
    if (fromAccount.type_code === 'CREDIT') {
      this.toAccountHelperTarget.textContent = "Onde foi gasto o dinheiro do cartão"
    } else if (fromAccount.type_code === 'BANK') {
      this.toAccountHelperTarget.textContent = "Destino do pagamento"
    }
  }

  updateFormState() {
    // Update submit button state
    const isValid = this.validateForm()
    
    if (isValid) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.classList.remove('btn-disabled')
    } else {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add('btn-disabled')
    }
  }

  validateForm() {
    // Basic validation
    const hasDescription = this.descriptionTarget.value.trim().length > 0
    const hasAmount = parseFloat(this.amountTarget.value) > 0
    const hasEventDate = this.eventDateTarget.value.length > 0
    const hasFromAccount = this.fromAccountTarget.value.length > 0
    const hasTransactionType = this.getSelectedTransactionType() !== null
    
    const transactionType = this.getSelectedTransactionType()
    
    // For transfers, we need both from_account and to_account, but no category
    if (transactionType === 'transfer') {
      const hasToAccount = this.toAccountTarget.value.length > 0
      const accountsAreDifferent = this.fromAccountTarget.value !== this.toAccountTarget.value
      return hasDescription && hasAmount && hasEventDate && hasFromAccount && hasToAccount && hasTransactionType && accountsAreDifferent
    }
    
    // For income and expense, we need category but to_account is optional
    const hasCategory = this.categoryTarget.value.length > 0
    return hasDescription && hasAmount && hasEventDate && hasFromAccount && hasCategory && hasTransactionType
  }
}

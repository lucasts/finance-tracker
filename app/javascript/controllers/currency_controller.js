import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    if (this.hasInputTarget) {
      this.setupMask()
    }
  }

  disconnect() {
    // Remove listener para evitar leaks
    this.inputTarget.removeEventListener('input', this.nativeCurrencyMask)
    if (this.mask) this.mask.destroy()
  }

  setupMask() {
    // Remove IMask, implement simple native currency mask
    this.inputTarget.addEventListener('input', this.nativeCurrencyMask.bind(this))
    // Ao editar, formata o valor inicial se houver
    if (this.inputTarget.value && this.inputTarget.value.match(/\d/)) {
      this.formatInitialValue()
    } else {
      this.nativeCurrencyMask() // inicializa
    }
  }

  formatInitialValue() {
    // Remove tudo que não for número, vírgula ou ponto
    let raw = this.inputTarget.value.replace(/[^\d,.]/g, '')
    // Se já está no formato brasileiro (ex: 123,45), apenas normaliza
    if (raw.match(/^\d{1,3}(\.\d{3})*,\d{2}$/)) {
      // Ex: 1.234,56 → 1234,56
      raw = raw.replace(/\./g, '')
      this.inputTarget.value = raw
      this.nativeCurrencyMask()
      return
    }
    // Se está no formato americano (ex: 123.45), converte para brasileiro
    if (raw.match(/^\d+\.\d{2}$/)) {
      raw = raw.replace('.', ',')
      this.inputTarget.value = raw
      this.nativeCurrencyMask()
      return
    }
    // Se for só número inteiro, multiplica por 100 para centavos
    if (raw.match(/^\d+$/)) {
      let value = raw.replace(/^0+(?!$)/, '')
      value = value.padStart(3, '0')
      let cents = value.slice(-2)
      let integer = value.slice(0, -2)
      integer = integer.replace(/^0+(?!$)/, '')
      if (integer.length === 0) integer = '0'
      integer = integer.replace(/\B(?=(\d{3})+(?!\d))/g, '.')
      this.inputTarget.value = integer + ',' + cents
      this.updateHelper()
      return
    }
    // fallback: tenta parsear float
    let value = Math.round(parseFloat(raw.replace(',', '.')) * 100).toString()
    if (isNaN(value) || value === 'NaN') value = '0'
    value = value.replace(/^0+(?!$)/, '')
    value = value.padStart(3, '0')
    let cents = value.slice(-2)
    let integer = value.slice(0, -2)
    integer = integer.replace(/^0+(?!$)/, '')
    if (integer.length === 0) integer = '0'
    integer = integer.replace(/\B(?=(\d{3})+(?!\d))/g, '.')
    this.inputTarget.value = integer + ',' + cents
    this.updateHelper()
  }

  nativeCurrencyMask() {
    let value = this.inputTarget.value.replace(/\D/g, '')
    if (value.length === 0) value = '0'
    // Remove zeros à esquerda, mas mantém pelo menos 3 dígitos para centavos
    value = value.replace(/^0+(?!$)/, '')
    value = value.padStart(3, '0')
    // Separa centavos
    let cents = value.slice(-2)
    let integer = value.slice(0, -2)
    // Remove zeros à esquerda do inteiro
    integer = integer.replace(/^0+(?!$)/, '')
    // Adiciona separador de milhar
    if (integer.length === 0) integer = '0'
    integer = integer.replace(/\B(?=(\d{3})+(?!\d))/g, '.')
    this.inputTarget.value = integer + ',' + cents
    this.updateHelper()
  }

  updateHelper() {
    const helper = this.element.querySelector('[data-currency-helper]')
    if (helper) {
      // Extrai valor numérico do input formatado
      const raw = this.inputTarget.value.replace(/\./g, '').replace(',', '.')
      // Garante sempre duas casas decimais
      const value = Number.isNaN(Number(raw)) ? 0 : parseFloat(raw)
      helper.textContent = value > 0 ? `Valor: ${(value).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL', minimumFractionDigits: 2 })}` : "Digite o valor"
    }
  }

  get numericValue() {
    // Extrai valor numérico do input formatado
    if (!this.inputTarget) return 0
    const raw = this.inputTarget.value.replace(/\./g, '').replace(',', '.')
    return parseFloat(raw) || 0
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["testDate", "form"]
  static values = { url: String }

  connect() {
    this.setupDateSubmission()
  }

  setupDateSubmission() {
    // Setup form submission handlers
    window.submitWithDate = this.submitWithDate.bind(this)
  }

  submitWithDate(url) {
    const testDate = this.testDateTarget.value
    
    if (!testDate) {
      alert('Por favor, selecione uma data de teste.')
      return
    }

    if (confirm(`Executar automação para a data ${testDate}?`)) {
      this.createAndSubmitForm(url, testDate)
    }
  }

  createAndSubmitForm(url, testDate) {
    const form = document.createElement('form')
    form.method = 'post'
    form.action = url
    
    // Add test date
    const dateInput = this.createHiddenInput('test_date', testDate)
    form.appendChild(dateInput)
    
    // Add CSRF token
    const tokenInput = this.createHiddenInput(
      'authenticity_token', 
      document.querySelector('meta[name="csrf-token"]').content
    )
    form.appendChild(tokenInput)
    
    // Submit form
    document.body.appendChild(form)
    form.submit()
  }

  createHiddenInput(name, value) {
    const input = document.createElement('input')
    input.type = 'hidden'
    input.name = name
    input.value = value
    return input
  }

  // Handle direct button clicks with data attributes
  submit(event) {
    const url = event.currentTarget.dataset.url
    this.submitWithDate(url)
  }
}

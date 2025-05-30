import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "content"]

  async show(event) {
    event.preventDefault()
    const url = event.target.dataset.url
    
    try {
      const response = await fetch(url, {
        headers: {
          "Accept": "text/html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })
      
      if (response.ok) {
        const html = await response.text()
        this.contentTarget.innerHTML = html
        this.modalTarget.checked = true
      }
    } catch (error) {
      console.error("Failed to load transaction details:", error)
    }
  }

  hide() {
    this.modalTarget.checked = false
    this.contentTarget.innerHTML = ""
  }

  // Close modal when clicking outside
  closeOnBackdrop(event) {
    if (event.target.classList.contains('modal')) {
      this.hide()
    }
  }
}

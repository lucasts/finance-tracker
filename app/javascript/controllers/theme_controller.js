import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select"]

  connect() {
    const savedTheme = localStorage.getItem("theme")
    if (savedTheme) {
      document.documentElement.setAttribute("data-theme", savedTheme)
      if (this.hasSelectTarget) {
        this.selectTarget.value = savedTheme
      }
    }
  }

  change(event) {
    const selected = event.target.value
    document.documentElement.setAttribute("data-theme", selected)
    localStorage.setItem("theme", selected)
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["icon", "content"]

  connect() {
    // Initialize collapsed state
    this.collapsed = true
  }

  toggle() {
    this.collapsed = !this.collapsed
    
    if (this.collapsed) {
      this.contentTarget.classList.add("hidden")
      this.iconTarget.style.transform = "rotate(0deg)"
    } else {
      this.contentTarget.classList.remove("hidden")
      this.iconTarget.style.transform = "rotate(180deg)"
    }
  }
}

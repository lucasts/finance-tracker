import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["icon", "content"]

  connect() {
    // Initialize collapsed state
    this.collapsed = this.contentTarget.classList.contains("hidden")
    this.updateIcon()
  }

  toggle() {
    this.collapsed = !this.collapsed
    
    if (this.collapsed) {
      this.contentTarget.style.display = "none"
      this.contentTarget.classList.add("hidden")
    } else {
      this.contentTarget.style.display = "block"
      this.contentTarget.classList.remove("hidden")
    }
    
    this.updateIcon()
  }
  
  updateIcon() {
    if (this.hasIconTarget) {
      this.iconTarget.style.transform = this.collapsed ? "rotate(0deg)" : "rotate(180deg)"
    }
  }
}

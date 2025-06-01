import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "section"]

  connect() {
    this.toggle()
  }

  toggle() {
    const isChecked = this.toggleTarget.checked
    
    if (isChecked) {
      this.sectionTarget.classList.remove("hidden")
      this.sectionTarget.classList.add("animate-fade-in")
    } else {
      this.sectionTarget.classList.add("hidden")
      this.sectionTarget.classList.remove("animate-fade-in")
    }
  }
}

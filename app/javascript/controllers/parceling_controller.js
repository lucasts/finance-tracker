import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "section"]

  connect() {
    this.toggle()
  }

  toggle() {
    this.sectionTarget.classList.toggle("hidden", !this.toggleTarget.checked)
  }
}

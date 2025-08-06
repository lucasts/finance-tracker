// Dismissible Controller
// Manages dismissible elements like alerts, notifications, and removable items

import ApplicationController from "../helpers/application_controller"

export default class extends ApplicationController {
  static values = {
    autoHide: { type: Boolean, default: false },
    hideAfter: { type: Number, default: 5000 },
    confirmMessage: String,
    animate: { type: Boolean, default: true }
  }

  connect() {
    super.connect()
    this.setupAutoHide()
  }

  setupAutoHide() {
    if (this.autoHideValue && this.hideAfterValue > 0) {
      this.autoHideTimeout = setTimeout(() => {
        this.dismiss()
      }, this.hideAfterValue)
    }
  }

  // Dismiss/remove the element
  dismiss(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }

    // Clear auto-hide timeout if it exists
    if (this.autoHideTimeout) {
      clearTimeout(this.autoHideTimeout)
    }

    // Show confirmation if required
    if (this.confirmMessageValue) {
      if (!confirm(this.confirmMessageValue)) {
        return
      }
    }

    this.performDismiss()
  }

  // Perform the actual dismissal
  performDismiss() {
    this.dispatch("dismissing")

    if (this.animateValue) {
      this.animatedRemove()
    } else {
      this.immediateRemove()
    }
  }

  // Remove with animation
  animatedRemove() {
    this.element.style.transition = 'all 0.3s ease-out'
    this.element.style.opacity = '0'
    this.element.style.transform = 'translateX(100%)'
    
    setTimeout(() => {
      this.immediateRemove()
    }, 300)
  }

  // Remove immediately
  immediateRemove() {
    // Announce to screen readers
    this.log("Item removido")
    
    // Dispatch event before removal
    this.dispatch("dismissed")
    
    // Remove from DOM
    this.element.remove()
    
    this.log("Element dismissed and removed")
  }

  // Pause auto-hide (useful for hover interactions)
  pauseAutoHide() {
    if (this.autoHideTimeout) {
      clearTimeout(this.autoHideTimeout)
      this.autoHideTimeout = null
    }
  }

  // Resume auto-hide
  resumeAutoHide() {
    if (this.autoHideValue && !this.autoHideTimeout) {
      this.setupAutoHide()
    }
  }

  // Hide temporarily (can be shown again)
  hide() {
    if (this.animateValue) {
      this.element.style.transition = 'all 0.3s ease-out'
      this.element.style.opacity = '0'
      this.element.style.transform = 'scale(0.95)'
      
      setTimeout(() => {
        this.hideElement(this.element)
      }, 300)
    } else {
      this.hideElement(this.element)
    }

    this.dispatch("hidden")
    this.log("Item ocultado")
  }

  // Show if hidden
  show() {
    this.showElement(this.element)
    
    if (this.animateValue) {
      this.element.style.opacity = '0'
      this.element.style.transform = 'scale(0.95)'
      
      // Force reflow
      this.element.offsetHeight
      
      this.element.style.transition = 'all 0.3s ease-out'
      this.element.style.opacity = '1'
      this.element.style.transform = 'scale(1)'
    }

    this.dispatch("shown")
    this.log("Item exibido")
  }

  // Toggle visibility
  toggle() {
    if (this.element.hidden || this.element.style.display === 'none') {
      this.show()
    } else {
      this.hide()
    }
  }
}

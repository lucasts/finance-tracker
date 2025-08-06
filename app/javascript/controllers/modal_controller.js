import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "trigger", "closeButton"]
  static values = { 
    id: String,
    autoFocus: { type: Boolean, default: true },
    closeOnOutsideClick: { type: Boolean, default: true },
    closeOnEscape: { type: Boolean, default: true }
  }

  connect() {
    this.setupEventListeners()
    console.log("Modal controller connected", { id: this.idValue })
  }

  disconnect() {
    this.cleanup()
    // super.disconnect() removed
  }

  setupEventListeners() {
    if (this.closeOnEscapeValue) {
      this.boundHandleKeydown = this.handleKeydown.bind(this)
      document.addEventListener('keydown', this.boundHandleKeydown)
    }

    if (this.closeOnOutsideClickValue && this.hasDialogTarget) {
      this.boundHandleOutsideClick = this.handleOutsideClick.bind(this)
      this.dialogTarget.addEventListener('click', this.boundHandleOutsideClick)
    }
  }

  cleanup() {
    if (this.boundHandleKeydown) {
      document.removeEventListener('keydown', this.boundHandleKeydown)
    }
    
    if (this.boundHandleOutsideClick && this.hasDialogTarget) {
      this.dialogTarget.removeEventListener('click', this.boundHandleOutsideClick)
    }
  }

  // Open modal
  async open(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }

    // Check if we need to load content from URL
    const url = event?.currentTarget?.dataset?.url
    if (url) {
      await this.loadContent(url)
    }

    if (!this.hasDialogTarget) {
      console.error("No dialog target found")
      return
    }

    this.previouslyFocusedElement = document.activeElement
    this.dialogTarget.showModal()
    this.element.classList.remove('hidden')

    if (this.autoFocusValue) {
      this.setInitialFocus()
    }

    this.announce("Modal aberto")
    this.dispatch("opened", { modalId: this.idValue })
    console.log("Modal opened")
  }

  // Close modal
  close(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }

    if (!this.hasDialogTarget) {
      return
    }

    this.dialogTarget.close()
    this.element.classList.add('hidden')

    if (this.previouslyFocusedElement && this.previouslyFocusedElement.focus) {
      this.previouslyFocusedElement.focus()
    }

    this.announce("Modal fechado")
    this.dispatch("closed", { modalId: this.idValue })
    console.log("Modal closed")
  }

  // Toggle modal state
  toggle(event) {
    // Check if modal is currently open
    const isOpen = this.hasDialogTarget ? this.dialogTarget.open : false

    if (isOpen) {
      this.close(event)
    } else {
      this.open(event)
    }
  }

  // Handle keyboard navigation
  handleKeydown(event) {
    if (event.key === 'Escape' && this.closeOnEscapeValue) {
      this.close()
    }
  }

  // Handle clicks outside modal content
  handleOutsideClick(event) {
    if (event.target === this.dialogTarget) {
      this.close()
    }
  }

  // Set initial focus when modal opens
  setInitialFocus() {
    const focusableElements = this.getFocusableElements()
    
    if (focusableElements.length > 0) {
      const preferredElements = focusableElements.filter(el => 
        el.matches('input:not([type="hidden"]), textarea, select')
      )
      
      const elementToFocus = preferredElements[0] || focusableElements[0]
      elementToFocus.focus()
    }
  }

  // Get all focusable elements within the modal
  getFocusableElements() {
    const selector = [
      'button:not([disabled])',
      'input:not([disabled]):not([type="hidden"])',
      'textarea:not([disabled])',
      'select:not([disabled])',
      'a[href]',
      '[tabindex]:not([tabindex="-1"])'
    ].join(', ')

    const container = this.hasDialogTarget ? this.dialogTarget : this.element
    return Array.from(container.querySelectorAll(selector))
      .filter(el => !el.hidden && el.offsetParent !== null)
  }

  // Load content from URL via AJAX
  async loadContent(url) {
    const contentTarget = this.element.querySelector('[data-modal-target="content"]') || 
                         this.element.querySelector('.modal-box')

    if (!contentTarget) {
      console.error("No content target found in modal")
      return
    }

    try {
      contentTarget.innerHTML = '<div class="loading loading-spinner loading-lg mx-auto"></div>'
      
      const response = await fetch(url, {
        headers: {
          'Accept': 'text/html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }

      const content = await response.text()
      contentTarget.innerHTML = content

      console.log("Modal content loaded from:", url)
      
    } catch (error) {
      console.error("Failed to load modal content:", error)
      contentTarget.innerHTML = `
        <div class="alert alert-error">
          <div>
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
            <span>Erro ao carregar conteúdo</span>
          </div>
        </div>
      `
    }
  }
}

// File Upload Controller
// Enhanced file upload with preview, validation and progress tracking

import ApplicationController from "../helpers/application_controller"

export default class extends ApplicationController {
  static targets = ["input", "preview", "progress", "error", "submit"]
  static values = {
    maxSize: { type: Number, default: 10485760 }, // 10MB default
    allowedTypes: { type: Array, default: [] },
    showPreview: { type: Boolean, default: true },
    autoSubmit: { type: Boolean, default: false }
  }

  connect() {
    super.connect()
    this.setupFileValidation()
  }

  setupFileValidation() {
    if (this.hasInputTarget) {
      this.inputTarget.addEventListener('change', this.handleFileChange.bind(this))
    }
  }

  // Handle file selection
  handleFileChange(event) {
    const files = Array.from(event.target.files)
    
    if (files.length === 0) {
      this.clearPreview()
      return
    }

    this.clearError()
    
    // Validate files
    const validationResult = this.validateFiles(files)
    
    if (!validationResult.isValid) {
      this.showError(validationResult.error)
      this.clearFileInput()
      return
    }

    // Show preview if enabled
    if (this.showPreviewValue) {
      this.updatePreview(files)
    }

    // Enable submit button
    this.enableSubmit()

    // Auto-submit if enabled
    if (this.autoSubmitValue) {
      this.submitForm()
    }

    this.dispatch("file-selected", { files: files })
    this.log("Files selected", { count: files.length })
  }

  // Validate selected files
  validateFiles(files) {
    for (const file of files) {
      // Check file size
      if (file.size > this.maxSizeValue) {
        return {
          isValid: false,
          error: `Arquivo muito grande. Tamanho máximo: ${this.format.formatFileSize(this.maxSizeValue)}`
        }
      }

      // Check file type
      if (this.allowedTypesValue.length > 0) {
        const isValidType = this.allowedTypesValue.some(type => {
          if (type.startsWith('.')) {
            return file.name.toLowerCase().endsWith(type.toLowerCase())
          }
          return file.type.startsWith(type)
        })

        if (!isValidType) {
          return {
            isValid: false,
            error: `Tipo de arquivo não permitido. Tipos aceitos: ${this.allowedTypesValue.join(', ')}`
          }
        }
      }
    }

    return { isValid: true }
  }

  // Update file preview
  updatePreview(files) {
    if (!this.hasPreviewTarget) return

    this.clearPreview()

    files.forEach((file, index) => {
      const previewElement = this.createPreviewElement(file, index)
      this.previewTarget.appendChild(previewElement)
    })

    this.showElement(this.previewTarget)
  }

  // Create preview element for a file
  createPreviewElement(file, index) {
    const container = this.dom.createElement('div', {
      className: 'file-preview-item flex items-center gap-3 p-3 bg-base-200 rounded-lg',
      dataset: { fileIndex: index }
    })

    // File icon or image preview
    const iconContainer = this.dom.createElement('div', {
      className: 'flex-shrink-0'
    })

    if (file.type.startsWith('image/')) {
      const img = this.dom.createElement('img', {
        className: 'w-12 h-12 object-cover rounded',
        alt: 'Preview da imagem'
      })
      
      const reader = new FileReader()
      reader.onload = (e) => {
        img.src = e.target.result
      }
      reader.readAsDataURL(file)
      
      iconContainer.appendChild(img)
    } else {
      const icon = this.dom.createElement('div', {
        className: 'w-12 h-12 bg-primary/10 rounded flex items-center justify-center'
      }, `
        <svg class="w-6 h-6 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
        </svg>
      `)
      iconContainer.appendChild(icon)
    }

    // File details
    const details = this.dom.createElement('div', {
      className: 'flex-grow min-w-0'
    }, `
      <div class="font-medium text-sm truncate" title="${file.name}">${file.name}</div>
      <div class="text-xs text-base-content/60">${this.format.formatFileSize(file.size)}</div>
    `)

    // Remove button
    const removeBtn = this.dom.createElement('button', {
      type: 'button',
      className: 'btn btn-ghost btn-sm btn-circle',
      'aria-label': 'Remover arquivo'
    }, `
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
      </svg>
    `)

    removeBtn.addEventListener('click', () => {
      this.removeFile(index)
    })

    container.appendChild(iconContainer)
    container.appendChild(details)
    container.appendChild(removeBtn)

    return container
  }

  // Remove a file from selection
  removeFile(index) {
    const dt = new DataTransfer()
    const files = Array.from(this.inputTarget.files)
    
    files.forEach((file, i) => {
      if (i !== index) {
        dt.items.add(file)
      }
    })

    this.inputTarget.files = dt.files
    this.handleFileChange({ target: this.inputTarget })
    this.log("Arquivo removido")
  }

  // Clear file preview
  clearPreview() {
    if (this.hasPreviewTarget) {
      this.previewTarget.innerHTML = ''
      this.hideElement(this.previewTarget)
    }
  }

  // Clear file input
  clearFileInput() {
    if (this.hasInputTarget) {
      this.inputTarget.value = ''
    }
    this.clearPreview()
    this.disableSubmit()
  }

  // Show error message
  showError(message) {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message
      this.showElement(this.errorTarget)
    }
    this.log(`Erro: ${message}`)
  }

  // Clear error message
  clearError() {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = ''
      this.hideElement(this.errorTarget)
    }
  }

  // Enable submit button
  enableSubmit() {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = false
      this.submitTarget.classList.remove('btn-disabled')
    }
  }

  // Disable submit button
  disableSubmit() {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
      this.submitTarget.classList.add('btn-disabled')
    }
  }

  // Submit form with loading state
  submitForm() {
    const form = this.element.closest('form')
    
    if (!form) {
      console.error("No form found for submission")
      return
    }

    this.setLoadingState(true)
    this.log("Enviando arquivo...")

    // Add a small delay to show loading state
    setTimeout(() => {
      form.submit()
    }, 100)
  }

  // Set loading state
  setLoadingState(isLoading) {
    if (this.hasSubmitTarget) {
      if (isLoading) {
        this.submitTarget.classList.add('loading')
        this.submitTarget.disabled = true
      } else {
        this.submitTarget.classList.remove('loading')
        this.submitTarget.disabled = false
      }
    }
  }

  // Handle form submission
  handleSubmit(event) {
    if (!this.hasInputTarget || this.inputTarget.files.length === 0) {
      event.preventDefault()
      this.showError("Por favor, selecione um arquivo")
      return
    }

    this.setLoadingState(true)
  }

  // Trigger file selection
  triggerFileSelection() {
    if (this.hasInputTarget) {
      this.inputTarget.click()
    }
  }
}

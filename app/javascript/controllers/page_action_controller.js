// Page Action Controller  
// Enhanced page-level actions with improved accessibility and feedback

import ApplicationController from "../helpers/application_controller"

export default class extends ApplicationController {
  static values = {
    action: String,
    url: String,
    delay: { type: Number, default: 0 },
    confirm: String
  }

  // Reload the page
  reload(event) {
    if (event) {
      event.preventDefault()
    }

    if (this.confirmValue && !confirm(this.confirmValue)) {
      return
    }

    this.performAction(() => {
      location.reload()
    })
  }

  // Redirect to URL
  redirect(event) {
    if (event) {
      event.preventDefault()
    }

    const url = this.urlValue || event.target.dataset.url || event.target.href

    if (!url) {
      console.error("No URL provided for redirect")
      return
    }

    if (this.confirmValue && !confirm(this.confirmValue)) {
      return
    }

    this.performAction(() => {
      location.href = url
    })
  }

  // Go back in browser history
  back(event) {
    if (event) {
      event.preventDefault()
    }

    if (this.confirmValue && !confirm(this.confirmValue)) {
      return
    }

    this.performAction(() => {
      if (window.history.length > 1) {
        window.history.back()
      } else {
        // Fallback if no history
        location.href = '/'
      }
    })
  }

  // Go forward in browser history
  forward(event) {
    if (event) {
      event.preventDefault()
    }

    this.performAction(() => {
      window.history.forward()
    })
  }

  // Perform action with optional delay and loading state
  performAction(actionFunction) {
    // Set loading state on triggering element
    const trigger = event?.target
    if (trigger) {
      trigger.classList.add('loading')
      trigger.disabled = true
    }

    this.dispatch("action-starting", { action: this.actionValue })

    if (this.delayValue > 0) {
      setTimeout(() => {
        actionFunction()
      }, this.delayValue)
    } else {
      actionFunction()
    }
  }

  // Handle generic action based on data attribute
  handleAction(event) {
    const action = this.actionValue || event.target.dataset.action

    switch (action) {
      case 'reload':
        this.reload(event)
        break
      case 'redirect':
        this.redirect(event)
        break
      case 'back':
        this.back(event)
        break
      case 'forward':
        this.forward(event)
        break
      default:
        console.error(`Unknown action: ${action}`)
    }
  }

  // Open URL in new tab/window
  openExternal(event) {
    if (event) {
      event.preventDefault()
    }

    const url = this.urlValue || event.target.dataset.url || event.target.href

    if (!url) {
      console.error("No URL provided for external open")
      return
    }

    window.open(url, '_blank', 'noopener,noreferrer')
  }

  // Print current page
  print(event) {
    if (event) {
      event.preventDefault()
    }

    window.print()
  }

  // Share page (if Web Share API is available)
  async share(event) {
    if (event) {
      event.preventDefault()
    }

    const shareData = {
      title: document.title,
      url: window.location.href,
      text: document.querySelector('meta[name="description"]')?.content || ''
    }

    if (navigator.share) {
      try {
        await navigator.share(shareData)
        this.log("Página compartilhada")
      } catch (error) {
        if (error.name !== 'AbortError') {
          console.error("Share failed", error)
        }
      }
    } else {
      // Fallback: copy URL to clipboard
      try {
        await this.dom.copyToClipboard(shareData.url)
        this.log("Link copiado para a área de transferência")
      } catch (error) {
        console.error("Copy to clipboard failed", error)
      }
    }
  }
}

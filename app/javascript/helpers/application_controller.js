// Stimulus Helper
// Enhanced base functionality for all Stimulus controllers

import { Controller } from "@hotwired/stimulus"
import DOMUtils from "utilities/dom_utils"
import ValidationUtils from "utilities/validation_utils"
import FormatUtils from "utilities/format_utils"
import ASSET_CONFIG from "config/assets"

export default class ApplicationController extends Controller {
  // Global configuration access
  get config() {
    return ASSET_CONFIG;
  }

  // Enhanced utilities access
  get dom() {
    return DOMUtils;
  }

  get validation() {
    return ValidationUtils;
  }

  get format() {
    return FormatUtils;
  }

  // Enhanced logging with controller context
  log(message, data = {}) {
    if (this.config.performance.preloadCriticalAssets || this.application.debug) {
      console.log(`[${this.identifier}] ${message}`, data);
    }
  }

  logError(message, error, data = {}) {
    console.error(`[${this.identifier}] ${message}`, error, data);
    
    if (this.application.handleError) {
      this.application.handleError(error, `${this.identifier}: ${message}`, data);
    }
  }

  // Enhanced element selection with caching
  findElement(selector) {
    return this.dom.$(selector, this.element);
  }

  findElements(selector) {
    return this.dom.$$(selector, this.element);
  }

  // Show/hide with accessibility
  showElement(element, options = {}) {
    this.dom.show(element, options);
    this.log(`Showing element: ${element.tagName}`);
  }

  hideElement(element, options = {}) {
    this.dom.hide(element, options);
    this.log(`Hiding element: ${element.tagName}`);
  }

  // Announce to screen readers
  announce(message, priority = 'polite') {
    this.dom.announceToScreenReader(message, priority);
    this.log(`Screen reader announcement: ${message}`);
  }

  // Specific announcement methods
  announceError(message) {
    this.dom.announceFormError(this.identifier, message);
    this.log(`Error announcement: ${message}`);
  }

  announceSuccess(message) {
    this.dom.announceSuccess(message);
    this.log(`Success announcement: ${message}`);
  }

  announceLoading(message = 'Carregando...') {
    this.dom.announceLoading(message);
    this.log(`Loading announcement: ${message}`);
  }

  announceContentChange(message) {
    this.dom.announceContentChange(message);
    this.log(`Content change announcement: ${message}`);
  }

  // Enhanced event dispatch with bubbling
  dispatch(eventName, detail = {}) {
    const event = new CustomEvent(`${this.identifier}:${eventName}`, {
      detail: { controller: this, ...detail },
      bubbles: true,
      cancelable: true
    });

    this.element.dispatchEvent(event);
    this.log(`Dispatched event: ${eventName}`, detail);
    
    return event;
  }

  // Listen to custom events
  listen(eventName, handler, options = {}) {
    const fullEventName = eventName.includes(':') ? eventName : `${this.identifier}:${eventName}`;
    
    this.element.addEventListener(fullEventName, handler, options);
    this.log(`Listening to event: ${fullEventName}`);
  }

  // Enhanced form handling
  getFormData(form = null) {
    const formElement = form || this.element.closest('form') || this.findElement('form');
    
    if (!formElement) {
      this.logError('No form found for getFormData');
      return {};
    }

    const formData = new FormData(formElement);
    const data = {};

    for (const [key, value] of formData.entries()) {
      // Handle multiple values (checkboxes, multiple selects)
      if (data[key]) {
        if (Array.isArray(data[key])) {
          data[key].push(value);
        } else {
          data[key] = [data[key], value];
        }
      } else {
        data[key] = value;
      }
    }

    return data;
  }

  // Enhanced form validation
  validateForm(validationSchema, form = null) {
    const formData = this.getFormData(form);
    const result = this.validation.validateForm(formData, validationSchema);

    // Update UI for all fields
    Object.entries(result.fields).forEach(([fieldName, fieldResult]) => {
      const field = this.findElement(`[name="${fieldName}"]`);
      if (field) {
        this.validation.updateFieldUI(field, fieldResult);
      }
    });

    if (!result.isValid) {
      this.announce('Formulário possui erros de validação');
    }

    return result;
  }

  // Enhanced loading state management
  setLoading(isLoading, element = null) {
    const targetElement = element || this.element;
    
    if (isLoading) {
      targetElement.classList.add('loading');
      targetElement.setAttribute('aria-busy', 'true');
      
      // Disable interactive elements
      const interactiveElements = this.findElements('button, input, select, textarea, a');
      interactiveElements.forEach(el => {
        el.setAttribute('data-original-disabled', el.disabled);
        el.disabled = true;
      });
    } else {
      targetElement.classList.remove('loading');
      targetElement.setAttribute('aria-busy', 'false');
      
      // Re-enable interactive elements
      const interactiveElements = this.findElements('button, input, select, textarea, a');
      interactiveElements.forEach(el => {
        const wasDisabled = el.getAttribute('data-original-disabled') === 'true';
        el.disabled = wasDisabled;
        el.removeAttribute('data-original-disabled');
      });
    }

    this.log(`Loading state changed: ${isLoading}`, { element: targetElement.tagName });
  }

  // Enhanced async operation handling
  async performAsync(operation, options = {}) {
    const { 
      showLoading = true, 
      loadingElement = null,
      onSuccess = null,
      onError = null,
      successMessage = null,
      errorMessage = 'Ocorreu um erro. Tente novamente.'
    } = options;

    if (showLoading) {
      this.setLoading(true, loadingElement);
    }

    try {
      const result = await operation();
      
      if (onSuccess) {
        onSuccess(result);
      }

      if (successMessage) {
        this.announce(successMessage);
      }

      this.dispatch('async:success', { result });
      return result;

    } catch (error) {
      this.logError('Async operation failed', error);
      
      if (onError) {
        onError(error);
      } else {
        this.announce(errorMessage);
      }

      this.dispatch('async:error', { error });
      throw error;

    } finally {
      if (showLoading) {
        this.setLoading(false, loadingElement);
      }
    }
  }

  // Enhanced lifecycle hooks
  connect() {
    super.connect();
    this.log('Controller connected');
    this.dispatch('connected');
  }

  disconnect() {
    this.log('Controller disconnecting');
    this.dispatch('disconnecting');
    super.disconnect();
  }

  // Debounced method decorator
  debounce(method, delay = 300) {
    let timeoutId;
    
    return (...args) => {
      clearTimeout(timeoutId);
      timeoutId = setTimeout(() => method.apply(this, args), delay);
    };
  }

  // Throttled method decorator
  throttle(method, delay = 100) {
    let lastCall = 0;
    
    return (...args) => {
      const now = Date.now();
      
      if (now - lastCall >= delay) {
        lastCall = now;
        method.apply(this, args);
      }
    };
  }
}

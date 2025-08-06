// Validation Utilities
// Comprehensive validation helpers for forms and data

export class ValidationUtils {
  // Validation rules registry
  static rules = {
    // Required field validation
    required: {
      validate: (value) => value !== null && value !== undefined && value.toString().trim() !== '',
      message: 'Este campo é obrigatório'
    },

    // Email validation
    email: {
      validate: (value) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value),
      message: 'Por favor, insira um email válido'
    },

    // Money amount validation
    money: {
      validate: (value) => {
        const numericValue = parseFloat(value.toString().replace(/[^\d.-]/g, ''));
        return !isNaN(numericValue) && numericValue >= 0;
      },
      message: 'Por favor, insira um valor monetário válido'
    },

    // Positive number validation
    positiveNumber: {
      validate: (value) => {
        const numericValue = parseFloat(value);
        return !isNaN(numericValue) && numericValue > 0;
      },
      message: 'O valor deve ser um número positivo'
    },

    // Date validation
    date: {
      validate: (value) => {
        const date = new Date(value);
        return date instanceof Date && !isNaN(date);
      },
      message: 'Por favor, insira uma data válida'
    },

    // Minimum length validation
    minLength: (min) => ({
      validate: (value) => value.toString().length >= min,
      message: `Deve ter pelo menos ${min} caracteres`
    }),

    // Maximum length validation
    maxLength: (max) => ({
      validate: (value) => value.toString().length <= max,
      message: `Deve ter no máximo ${max} caracteres`
    }),

    // Pattern validation
    pattern: (regex, message) => ({
      validate: (value) => regex.test(value),
      message: message || 'Formato inválido'
    })
  };

  // Validate a single field
  static validateField(value, rules) {
    const errors = [];

    rules.forEach(rule => {
      let validator;

      if (typeof rule === 'string') {
        validator = this.rules[rule];
      } else if (typeof rule === 'function') {
        validator = rule;
      } else {
        validator = rule;
      }

      if (validator && !validator.validate(value)) {
        errors.push(validator.message);
      }
    });

    return {
      isValid: errors.length === 0,
      errors
    };
  }

  // Validate an entire form
  static validateForm(formData, validationSchema) {
    const results = {};
    let isFormValid = true;

    Object.entries(validationSchema).forEach(([fieldName, rules]) => {
      const fieldValue = formData[fieldName];
      const fieldResult = this.validateField(fieldValue, rules);
      
      results[fieldName] = fieldResult;
      
      if (!fieldResult.isValid) {
        isFormValid = false;
      }
    });

    return {
      isValid: isFormValid,
      fields: results,
      errors: Object.fromEntries(
        Object.entries(results)
          .filter(([_, result]) => !result.isValid)
          .map(([field, result]) => [field, result.errors])
      )
    };
  }

  // Real-time field validation
  static setupRealtimeValidation(form, validationSchema) {
    Object.keys(validationSchema).forEach(fieldName => {
      const field = form.querySelector(`[name="${fieldName}"]`);
      
      if (field) {
        const validateAndUpdate = () => {
          const result = this.validateField(field.value, validationSchema[fieldName]);
          this.updateFieldUI(field, result);
        };

        // Validate on blur for better UX
        field.addEventListener('blur', validateAndUpdate);
        
        // For money fields, also validate on input
        if (field.dataset.currency) {
          field.addEventListener('input', this.debounce(validateAndUpdate, 300));
        }
      }
    });
  }

  // Update field UI based on validation result
  static updateFieldUI(field, validationResult) {
    const fieldContainer = field.closest('.form-control') || field.parentElement;
    const errorContainer = fieldContainer.querySelector('.field-error') || 
                          this.createErrorContainer(fieldContainer);

    // Remove existing validation classes
    field.classList.remove('input-success', 'input-error', 'input-warning');
    fieldContainer.classList.remove('field-valid', 'field-invalid');

    if (validationResult.isValid) {
      field.classList.add('input-success');
      fieldContainer.classList.add('field-valid');
      errorContainer.textContent = '';
      errorContainer.hidden = true;
    } else {
      field.classList.add('input-error');
      fieldContainer.classList.add('field-invalid');
      errorContainer.textContent = validationResult.errors[0];
      errorContainer.hidden = false;
    }
  }

  // Create error message container
  static createErrorContainer(fieldContainer) {
    const errorDiv = document.createElement('div');
    errorDiv.className = 'field-error text-error text-sm mt-1';
    errorDiv.hidden = true;
    fieldContainer.appendChild(errorDiv);
    return errorDiv;
  }

  // Debounce helper
  static debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout);
        func(...args);
      };
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
    };
  }

  // Custom validation for Brazilian formats
  static brazilianValidators = {
    cpf: {
      validate: (value) => {
        const cpf = value.replace(/[^\d]/g, '');
        
        if (cpf.length !== 11 || /^(.)\1*$/.test(cpf)) {
          return false;
        }

        let sum = 0;
        for (let i = 0; i < 9; i++) {
          sum += parseInt(cpf.charAt(i)) * (10 - i);
        }
        
        let remainder = 11 - (sum % 11);
        if (remainder === 10 || remainder === 11) remainder = 0;
        if (remainder !== parseInt(cpf.charAt(9))) return false;

        sum = 0;
        for (let i = 0; i < 10; i++) {
          sum += parseInt(cpf.charAt(i)) * (11 - i);
        }
        
        remainder = 11 - (sum % 11);
        if (remainder === 10 || remainder === 11) remainder = 0;
        return remainder === parseInt(cpf.charAt(10));
      },
      message: 'CPF inválido'
    },

    cnpj: {
      validate: (value) => {
        const cnpj = value.replace(/[^\d]/g, '');
        
        if (cnpj.length !== 14 || /^(.)\1*$/.test(cnpj)) {
          return false;
        }

        const weights1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
        const weights2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

        let sum = 0;
        for (let i = 0; i < 12; i++) {
          sum += parseInt(cnpj.charAt(i)) * weights1[i];
        }
        
        let remainder = sum % 11;
        const digit1 = remainder < 2 ? 0 : 11 - remainder;
        
        if (digit1 !== parseInt(cnpj.charAt(12))) return false;

        sum = 0;
        for (let i = 0; i < 13; i++) {
          sum += parseInt(cnpj.charAt(i)) * weights2[i];
        }
        
        remainder = sum % 11;
        const digit2 = remainder < 2 ? 0 : 11 - remainder;
        
        return digit2 === parseInt(cnpj.charAt(13));
      },
      message: 'CNPJ inválido'
    }
  };

  // Register Brazilian validators
  static {
    Object.assign(this.rules, this.brazilianValidators);
  }
}

export default ValidationUtils;

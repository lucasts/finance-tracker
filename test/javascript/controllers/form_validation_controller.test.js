/**
 * Form Validation Controller Tests
 * Tests for form validation logic and user feedback
 */

import { Application } from '@hotwired/stimulus';
import FormValidationController from 'controllers/form_validation_controller';

describe('FormValidationController', () => {
  let application;
  let controller;
  let element;

  beforeEach(() => {
    // Setup Stimulus application
    application = Application.start();
    application.register('form-validation', FormValidationController);

    // Create form HTML structure with validation rules
    document.body.innerHTML = `
      <form data-controller="form-validation" 
            data-form-validation-rules-value='{
              "name": {"required": true, "minLength": 2},
              "email": {"required": true, "email": true},
              "age": {"required": false, "minValue": 18},
              "password": {"required": true, "minLength": 6}
            }'>
        
        <div class="form-field">
          <input type="text" name="user[name]" data-form-validation-target="field" data-action="blur->form-validation#validateField" />
          <div data-form-validation-target="feedback" data-field="name" class="feedback"></div>
        </div>

        <div class="form-field">
          <input type="email" name="user[email]" data-form-validation-target="field" data-action="blur->form-validation#validateField" />
          <div data-form-validation-target="feedback" data-field="email" class="feedback"></div>
        </div>

        <div class="form-field">
          <input type="number" name="user[age]" data-form-validation-target="field" data-action="blur->form-validation#validateField" />
          <div data-form-validation-target="feedback" data-field="age" class="feedback"></div>
        </div>

        <div class="form-field">
          <input type="password" name="user[password]" data-form-validation-target="field" data-action="blur->form-validation#validateField" />
          <div data-form-validation-target="feedback" data-field="password" class="feedback"></div>
        </div>

        <select name="user[country]" data-form-validation-target="field">
          <option value="">Select country</option>
          <option value="BR">Brazil</option>
          <option value="US">United States</option>
        </select>

      </form>
    `;

    element = document.querySelector('[data-controller="form-validation"]');
    
    // Wait for controller to initialize
    return new Promise(resolve => {
      setTimeout(() => {
        controller = application.getControllerForElementAndIdentifier(element, 'form-validation');
        resolve();
      }, 10);
    });
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    jest.clearAllMocks();
  });

  describe('Controller initialization', () => {
    test('connects successfully and validates all fields', () => {
      expect(controller).toBeDefined();
      expect(controller).not.toBeNull();
    });

    test('has correct targets and values', () => {
      expect(controller.fieldTargets.length).toBe(5); // 4 inputs + 1 select
      expect(controller.feedbackTargets.length).toBe(4); // 4 feedback divs
      expect(controller.rulesValue).toEqual({
        name: { required: true, minLength: 2 },
        email: { required: true, email: true },
        age: { required: false, minValue: 18 },
        password: { required: true, minLength: 6 }
      });
    });
  });

  describe('Field validation', () => {
    test('validates required fields correctly', () => {
      const nameField = element.querySelector('input[name="user[name]"]');
      const nameFeedback = element.querySelector('[data-field="name"]');

      // Test empty required field
      nameField.value = '';
      controller.validateSingleField(nameField, 'name');

      expect(nameField.classList.contains('input-error')).toBe(true);
      expect(nameField.classList.contains('input-success')).toBe(false);
      expect(nameFeedback.textContent).toBe('Este campo é obrigatório');
      expect(nameFeedback.classList.contains('text-error')).toBe(true);

      // Test valid required field
      nameField.value = 'John Doe';
      controller.validateSingleField(nameField, 'name');

      expect(nameField.classList.contains('input-error')).toBe(false);
      expect(nameField.classList.contains('input-success')).toBe(true);
      expect(nameFeedback.textContent).toBe('✓ Válido');
      expect(nameFeedback.classList.contains('text-success')).toBe(true);
    });

    test('validates minimum length correctly', () => {
      const nameField = element.querySelector('input[name="user[name]"]');
      const nameFeedback = element.querySelector('[data-field="name"]');

      // Test too short value
      nameField.value = 'J';
      controller.validateSingleField(nameField, 'name');

      expect(nameField.classList.contains('input-error')).toBe(true);
      expect(nameFeedback.textContent).toBe('Deve ter pelo menos 2 caracteres');

      // Test valid length
      nameField.value = 'Jo';
      controller.validateSingleField(nameField, 'name');

      expect(nameField.classList.contains('input-success')).toBe(true);
      expect(nameFeedback.textContent).toBe('✓ Válido');
    });

    test('validates email format correctly', () => {
      const emailField = element.querySelector('input[name="user[email]"]');
      const emailFeedback = element.querySelector('[data-field="email"]');

      // Test invalid email
      emailField.value = 'invalid-email';
      controller.validateSingleField(emailField, 'email');

      expect(emailField.classList.contains('input-error')).toBe(true);
      expect(emailFeedback.textContent).toBe('Email inválido');

      // Test valid email
      emailField.value = 'user@example.com';
      controller.validateSingleField(emailField, 'email');

      expect(emailField.classList.contains('input-success')).toBe(true);
      expect(emailFeedback.textContent).toBe('✓ Válido');
    });

    test('validates minimum value correctly', () => {
      const ageField = element.querySelector('input[name="user[age]"]');
      const ageFeedback = element.querySelector('[data-field="age"]');

      // Test value below minimum
      ageField.value = '15';
      controller.validateSingleField(ageField, 'age');

      expect(ageField.classList.contains('input-error')).toBe(true);
      expect(ageFeedback.textContent).toBe('Deve ser maior que 18');

      // Test valid value
      ageField.value = '25';
      controller.validateSingleField(ageField, 'age');

      expect(ageField.classList.contains('input-success')).toBe(true);
      expect(ageFeedback.textContent).toBe('✓ Válido');
    });

    test('handles optional fields correctly', () => {
      const ageField = element.querySelector('input[name="user[age]"]');
      const ageFeedback = element.querySelector('[data-field="age"]');

      // Test empty optional field (should be valid)
      ageField.value = '';
      controller.validateSingleField(ageField, 'age');

      expect(ageField.classList.contains('input-success')).toBe(true);
      expect(ageFeedback.textContent).toBe('✓ Válido');
    });

    test('validates password length correctly', () => {
      const passwordField = element.querySelector('input[name="user[password]"]');
      const passwordFeedback = element.querySelector('[data-field="password"]');

      // Test short password
      passwordField.value = '123';
      controller.validateSingleField(passwordField, 'password');

      expect(passwordField.classList.contains('input-error')).toBe(true);
      expect(passwordFeedback.textContent).toBe('Deve ter pelo menos 6 caracteres');

      // Test valid password
      passwordField.value = 'password123';
      controller.validateSingleField(passwordField, 'password');

      expect(passwordField.classList.contains('input-success')).toBe(true);
      expect(passwordFeedback.textContent).toBe('✓ Válido');
    });
  });

  describe('Event handling', () => {
    test('validates field on blur event', () => {
      const validateSingleFieldSpy = jest.spyOn(controller, 'validateSingleField');
      const nameField = element.querySelector('input[name="user[name]"]');

      nameField.value = 'Test Name';
      const blurEvent = new Event('blur');
      Object.defineProperty(blurEvent, 'target', { value: nameField });
      
      controller.validateField(blurEvent);

      expect(validateSingleFieldSpy).toHaveBeenCalledWith(nameField, 'name');
    });

    test('extracts field name correctly from nested attributes', () => {
      const validateSingleFieldSpy = jest.spyOn(controller, 'validateSingleField');
      const emailField = element.querySelector('input[name="user[email]"]');

      const blurEvent = new Event('blur');
      Object.defineProperty(blurEvent, 'target', { value: emailField });
      
      controller.validateField(blurEvent);

      expect(validateSingleFieldSpy).toHaveBeenCalledWith(emailField, 'email');
    });
  });

  describe('Validation all fields', () => {
    test('validates all form fields', () => {
      const validateSingleFieldSpy = jest.spyOn(controller, 'validateSingleField');
      
      controller.validateAll();

      expect(validateSingleFieldSpy).toHaveBeenCalledTimes(5); // One for each field
    });

    test('applies validation to each field target', () => {
      const nameField = element.querySelector('input[name="user[name]"]');
      const emailField = element.querySelector('input[name="user[email]"]');

      // Set some invalid values
      nameField.value = '';
      emailField.value = 'invalid';

      controller.validateAll();

      expect(nameField.classList.contains('input-error')).toBe(true);
      expect(emailField.classList.contains('input-error')).toBe(true);
    });
  });

  describe('Field appearance updates', () => {
    test('updates field appearance for valid input', () => {
      const field = element.querySelector('input[name="user[name]"]');
      
      controller.updateFieldAppearance(field, true);

      expect(field.classList.contains('input-success')).toBe(true);
      expect(field.classList.contains('select-success')).toBe(true);
      expect(field.classList.contains('input-error')).toBe(false);
      expect(field.classList.contains('select-error')).toBe(false);
    });

    test('updates field appearance for invalid input', () => {
      const field = element.querySelector('input[name="user[name]"]');
      
      controller.updateFieldAppearance(field, false);

      expect(field.classList.contains('input-error')).toBe(true);
      expect(field.classList.contains('select-error')).toBe(true);
      expect(field.classList.contains('input-success')).toBe(false);
      expect(field.classList.contains('select-success')).toBe(false);
    });
  });

  describe('Feedback updates', () => {
    test('updates feedback for validation errors', () => {
      const errors = ['Este campo é obrigatório'];
      
      controller.updateFeedback('name', errors);

      const nameFeedback = element.querySelector('[data-field="name"]');
      expect(nameFeedback.textContent).toBe('Este campo é obrigatório');
      expect(nameFeedback.classList.contains('text-error')).toBe(true);
      expect(nameFeedback.classList.contains('text-success')).toBe(false);
    });

    test('updates feedback for successful validation', () => {
      const errors = [];
      
      controller.updateFeedback('name', errors);

      const nameFeedback = element.querySelector('[data-field="name"]');
      expect(nameFeedback.textContent).toBe('✓ Válido');
      expect(nameFeedback.classList.contains('text-success')).toBe(true);
      expect(nameFeedback.classList.contains('text-error')).toBe(false);
    });

    test('shows first error when multiple errors exist', () => {
      const errors = ['Este campo é obrigatório', 'Deve ter pelo menos 2 caracteres'];
      
      controller.updateFeedback('name', errors);

      const nameFeedback = element.querySelector('[data-field="name"]');
      expect(nameFeedback.textContent).toBe('Este campo é obrigatório');
    });

    test('handles missing feedback element gracefully', () => {
      expect(() => {
        controller.updateFeedback('nonexistent', ['Error']);
      }).not.toThrow();
    });
  });

  describe('Email validation helper', () => {
    test('validates correct email formats', () => {
      expect(controller.isValidEmail('user@example.com')).toBe(true);
      expect(controller.isValidEmail('test.email+tag@domain.co.uk')).toBe(true);
      expect(controller.isValidEmail('user123@test-domain.org')).toBe(true);
    });

    test('rejects invalid email formats', () => {
      expect(controller.isValidEmail('invalid-email')).toBe(false);
      expect(controller.isValidEmail('user@')).toBe(false);
      expect(controller.isValidEmail('@domain.com')).toBe(false);
      expect(controller.isValidEmail('user.domain.com')).toBe(false);
      expect(controller.isValidEmail('user@domain')).toBe(false);
      expect(controller.isValidEmail('')).toBe(false);
    });
  });

  describe('Edge cases', () => {
    test('handles fields without validation rules', () => {
      const countryField = element.querySelector('select[name="user[country]"]');
      
      expect(() => {
        controller.validateSingleField(countryField, 'country');
      }).not.toThrow();
    });

    test('handles whitespace in required fields', () => {
      const nameField = element.querySelector('input[name="user[name]"]');
      const nameFeedback = element.querySelector('[data-field="name"]');

      // Test field with only whitespace
      nameField.value = '   ';
      controller.validateSingleField(nameField, 'name');

      expect(nameField.classList.contains('input-error')).toBe(true);
      expect(nameFeedback.textContent).toBe('Este campo é obrigatório');
    });

    test('handles non-numeric values for minValue validation', () => {
      const ageField = element.querySelector('input[name="user[age]"]');
      
      ageField.value = 'not-a-number';
      
      expect(() => {
        controller.validateSingleField(ageField, 'age');
      }).not.toThrow();
    });

    test('validates trimmed values', () => {
      const nameField = element.querySelector('input[name="user[name]"]');
      const nameFeedback = element.querySelector('[data-field="name"]');

      // Test value with leading/trailing spaces
      nameField.value = '  Valid Name  ';
      controller.validateSingleField(nameField, 'name');

      expect(nameField.classList.contains('input-success')).toBe(true);
      expect(nameFeedback.textContent).toBe('✓ Válido');
    });
  });

  describe('Multiple validation rules', () => {
    test('validates all rules for a field', () => {
      const passwordField = element.querySelector('input[name="user[password]"]');
      const passwordFeedback = element.querySelector('[data-field="password"]');

      // Test empty password (fails required rule first)
      passwordField.value = '';
      controller.validateSingleField(passwordField, 'password');

      expect(passwordFeedback.textContent).toBe('Este campo é obrigatório');

      // Test short password (fails minLength after required passes)
      passwordField.value = '123';
      controller.validateSingleField(passwordField, 'password');

      expect(passwordFeedback.textContent).toBe('Deve ter pelo menos 6 caracteres');
    });

    test('validates email field with multiple rules', () => {
      const emailField = element.querySelector('input[name="user[email]"]');
      const emailFeedback = element.querySelector('[data-field="email"]');

      // Test empty email (fails required)
      emailField.value = '';
      controller.validateSingleField(emailField, 'email');

      expect(emailFeedback.textContent).toBe('Este campo é obrigatório');

      // Test invalid email format (passes required, fails email format)
      emailField.value = 'invalid-email';
      controller.validateSingleField(emailField, 'email');

      expect(emailFeedback.textContent).toBe('Email inválido');
    });
  });
});

/**
 * CurrencyValidationController Tests
 * Tests for currency input validation Stimulus controller
 */

import { Application } from '@hotwired/stimulus';
import CurrencyValidationController from 'controllers/currency_validation_controller';

// Mock MoneyFormatter since we tested it separately
const mockMoneyFormatter = {
  getNumericValue: jest.fn(),
  format: jest.fn()
};

// Make MoneyFormatter available globally
global.MoneyFormatter = mockMoneyFormatter;

describe('CurrencyValidationController', () => {
  let application;
  let controller;
  let element;

  beforeEach(() => {
    // Setup Stimulus application
    application = Application.start();
    application.register('currency-validation', CurrencyValidationController);

    // Create test DOM structure
    document.body.innerHTML = `
      <div data-controller="currency-validation" 
           data-currency-validation-min-value="10"
           data-currency-validation-max-value="1000"
           data-currency-validation-required-value="true">
        <input type="text" 
               data-currency-validation-target="input" 
               id="amount-input" />
        <div data-currency-validation-target="helper" 
             class="text-muted">Digite o valor</div>
        <div data-currency-validation-target="error" 
             class="error-message hidden"></div>
      </div>
    `;

    element = document.querySelector('[data-controller="currency-validation"]');
    
    // Wait for controller to initialize
    return new Promise(resolve => {
      setTimeout(() => {
        controller = application.getControllerForElementAndIdentifier(element, 'currency-validation');
        resolve();
      }, 10);
    });
  });

  afterEach(() => {
    if (application) {
      application.stop();
    }
    document.body.innerHTML = '';
    jest.clearAllMocks();
  });

  describe('Controller initialization', () => {
    test('connects and sets up validation', () => {
      expect(controller).toBeDefined();
      expect(controller.minValue).toBe(10);
      expect(controller.maxValue).toBe(1000);
      expect(controller.requiredValue).toBe(true);
    });

    test('has correct targets', () => {
      expect(controller.hasInputTarget).toBe(true);
      expect(controller.hasHelperTarget).toBe(true);
      expect(controller.hasErrorTarget).toBe(true);
    });
  });

  describe('Validation logic', () => {
    beforeEach(() => {
      // Reset mocks
      mockMoneyFormatter.getNumericValue.mockReturnValue(0);
      mockMoneyFormatter.format.mockImplementation(value => `R$\u00A0${value.toFixed(2).replace('.', ',')}`);
    });

    test('validates required fields correctly', () => {
      mockMoneyFormatter.getNumericValue.mockReturnValue(0);
      
      const isValid = controller.validate();
      
      expect(isValid).toBe(false);
      expect(controller.errorTarget.textContent).toBe('Valor é obrigatório');
      expect(controller.errorTarget.classList.contains('hidden')).toBe(false);
      expect(controller.inputTarget.classList.contains('input-error')).toBe(true);
    });

    test('validates minimum value correctly', () => {
      mockMoneyFormatter.getNumericValue.mockReturnValue(5); // Below min of 10
      mockMoneyFormatter.format.mockReturnValue('R$\u00A010,00');
      
      const isValid = controller.validate();
      
      expect(isValid).toBe(false);
      expect(controller.errorTarget.textContent).toBe('Valor mínimo: R$\u00A010,00');
      expect(mockMoneyFormatter.format).toHaveBeenCalledWith(10);
    });

    test('validates maximum value correctly', () => {
      mockMoneyFormatter.getNumericValue.mockReturnValue(1500); // Above max of 1000
      mockMoneyFormatter.format.mockReturnValue('R$\u00A01.000,00');
      
      const isValid = controller.validate();
      
      expect(isValid).toBe(false);
      expect(controller.errorTarget.textContent).toBe('Valor máximo: R$\u00A01.000,00');
      expect(mockMoneyFormatter.format).toHaveBeenCalledWith(1000);
    });

    test('validates successfully with valid value', () => {
      mockMoneyFormatter.getNumericValue.mockReturnValue(500); // Valid value between 10-1000
      
      const isValid = controller.validate();
      
      expect(isValid).toBe(true);
      expect(controller.errorTarget.classList.contains('hidden')).toBe(true);
      expect(controller.inputTarget.classList.contains('input-error')).toBe(false);
    });

    test('clears errors when validation passes', () => {
      // First make it invalid
      mockMoneyFormatter.getNumericValue.mockReturnValue(0);
      controller.validate();
      expect(controller.errorTarget.classList.contains('hidden')).toBe(false);
      
      // Then make it valid
      mockMoneyFormatter.getNumericValue.mockReturnValue(100);
      controller.validate();
      expect(controller.errorTarget.classList.contains('hidden')).toBe(true);
    });
  });

  describe('Helper text updates', () => {
    test('updates helper with formatted value when input has value', () => {
      mockMoneyFormatter.getNumericValue.mockReturnValue(250);
      mockMoneyFormatter.format.mockReturnValue('R$\u00A0250,00');
      
      controller.updateHelper();
      
      expect(controller.helperTarget.textContent).toBe('Valor: R$\u00A0250,00');
      expect(controller.helperTarget.classList.contains('text-muted')).toBe(false);
      expect(mockMoneyFormatter.format).toHaveBeenCalledWith(250);
    });

    test('shows default text when input is empty', () => {
      mockMoneyFormatter.getNumericValue.mockReturnValue(0);
      
      controller.updateHelper();
      
      expect(controller.helperTarget.textContent).toBe('Digite o valor');
      expect(controller.helperTarget.classList.contains('text-muted')).toBe(true);
    });
  });

  describe('Error display', () => {
    test('displays single error correctly', () => {
      const errors = ['Test error message'];
      
      controller.displayErrors(errors);
      
      expect(controller.errorTarget.textContent).toBe('Test error message');
      expect(controller.errorTarget.classList.contains('hidden')).toBe(false);
      expect(controller.inputTarget.classList.contains('input-error')).toBe(true);
    });

    test('displays first error when multiple errors exist', () => {
      const errors = ['First error', 'Second error', 'Third error'];
      
      controller.displayErrors(errors);
      
      expect(controller.errorTarget.textContent).toBe('First error');
    });

    test('hides error when no errors exist', () => {
      // First show an error
      controller.displayErrors(['Some error']);
      expect(controller.errorTarget.classList.contains('hidden')).toBe(false);
      
      // Then clear errors
      controller.displayErrors([]);
      expect(controller.errorTarget.classList.contains('hidden')).toBe(true);
      expect(controller.inputTarget.classList.contains('input-error')).toBe(false);
    });
  });

  describe('Public API', () => {
    test('isValid getter returns current validation state', () => {
      mockMoneyFormatter.getNumericValue.mockReturnValue(0); // Invalid
      expect(controller.isValid).toBe(false);
      
      mockMoneyFormatter.getNumericValue.mockReturnValue(100); // Valid
      expect(controller.isValid).toBe(true);
    });
  });

  describe('Event handling', () => {
    test('validates on input blur', async () => {
      const validateSpy = jest.spyOn(controller, 'validate');
      mockMoneyFormatter.getNumericValue.mockReturnValue(100);
      
      // Manually call setupValidation to ensure event listeners are attached
      controller.setupValidation();
      
      // Dispatch the event
      controller.inputTarget.dispatchEvent(new Event('blur'));
      
      expect(validateSpy).toHaveBeenCalled();
      validateSpy.mockRestore();
    });

    test('updates helper on input change', async () => {
      const updateHelperSpy = jest.spyOn(controller, 'updateHelper');
      
      // Manually call setupValidation to ensure event listeners are attached
      controller.setupValidation();
      
      // Dispatch the event
      controller.inputTarget.dispatchEvent(new Event('input'));
      
      expect(updateHelperSpy).toHaveBeenCalled();
      updateHelperSpy.mockRestore();
    });
  });

  describe('Configuration variants', () => {
    test('works without min value constraint', async () => {
      document.body.innerHTML = `
        <div data-controller="currency-validation" 
             data-currency-validation-max-value="1000">
          <input type="text" data-currency-validation-target="input" />
          <div data-currency-validation-target="error" class="hidden"></div>
        </div>
      `;
      
      const element = document.querySelector('[data-controller="currency-validation"]');
      
      return new Promise(resolve => {
        setTimeout(() => {
          const controller = application.getControllerForElementAndIdentifier(element, 'currency-validation');
          mockMoneyFormatter.getNumericValue.mockReturnValue(5);
          expect(controller.validate()).toBe(true); // Should pass without min constraint
          resolve();
        }, 10);
      });
    });

    test('works without required constraint', async () => {
      document.body.innerHTML = `
        <div data-controller="currency-validation" 
             data-currency-validation-required-value="false">
          <input type="text" data-currency-validation-target="input" />
          <div data-currency-validation-target="error" class="hidden"></div>
        </div>
      `;
      
      const element = document.querySelector('[data-controller="currency-validation"]');
      
      return new Promise(resolve => {
        setTimeout(() => {
          const controller = application.getControllerForElementAndIdentifier(element, 'currency-validation');
          mockMoneyFormatter.getNumericValue.mockReturnValue(0);
          expect(controller.validate()).toBe(true); // Should pass when not required
          resolve();
        }, 10);
      });
    });
  });

  describe('Integration with MoneyFormatter', () => {
    test('calls MoneyFormatter.getNumericValue with correct input', () => {
      controller.validate();
      
      expect(mockMoneyFormatter.getNumericValue).toHaveBeenCalledWith(controller.inputTarget);
    });

    test('calls MoneyFormatter.format for error messages', () => {
      mockMoneyFormatter.getNumericValue.mockReturnValue(5); // Below min
      
      controller.validate();
      
      expect(mockMoneyFormatter.format).toHaveBeenCalledWith(controller.minValue);
    });

    test('calls MoneyFormatter.format for helper updates', () => {
      mockMoneyFormatter.getNumericValue.mockReturnValue(150);
      
      controller.updateHelper();
      
      expect(mockMoneyFormatter.format).toHaveBeenCalledWith(150);
    });
  });
});

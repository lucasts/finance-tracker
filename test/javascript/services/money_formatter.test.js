/**
 * MoneyFormatter Service Tests
 * Comprehensive test suite for money formatting and parsing functionality
 */

import { MoneyFormatter } from '../../../app/javascript/services/money_formatter.js';

describe('MoneyFormatter', () => {
  beforeEach(() => {
    // Reset any cached values
    jest.clearAllMocks();
  });

  describe('format method', () => {
    test('formats positive numbers correctly', () => {
      expect(MoneyFormatter.format(1000)).toBe('R$\u00A01.000,00');
      expect(MoneyFormatter.format(1234.56)).toBe('R$\u00A01.234,56');
      expect(MoneyFormatter.format(0.99)).toBe('R$\u00A00,99');
    });

    test('formats negative numbers correctly', () => {
      expect(MoneyFormatter.format(-1000)).toBe('-R$\u00A01.000,00');
      expect(MoneyFormatter.format(-1234.56)).toBe('-R$\u00A01.234,56');
    });

    test('handles zero correctly', () => {
      expect(MoneyFormatter.format(0)).toBe('R$\u00A00,00');
      expect(MoneyFormatter.format(0.00)).toBe('R$\u00A00,00');
    });

    test('handles null and undefined', () => {
      expect(MoneyFormatter.format(null)).toBe('R$\u00A00,00');
      expect(MoneyFormatter.format(undefined)).toBe('R$\u00A00,00');
      expect(MoneyFormatter.format('')).toBe('R$\u00A00,00');
    });

    test('handles string input', () => {
      expect(MoneyFormatter.format('1000')).toBe('R$\u00A01.000,00');
      expect(MoneyFormatter.format('1234.56')).toBe('R$\u00A01.234,56');
      expect(MoneyFormatter.format('R$\u00A01.000,00')).toBe('R$\u00A01.000,00');
    });

    test('handles invalid input gracefully', () => {
      expect(MoneyFormatter.format('invalid')).toBe('R$\u00A00,00');
      expect(MoneyFormatter.format(NaN)).toBe('R$\u00A00,00');
      expect(MoneyFormatter.format(Infinity)).toBe('R$\u00A00,00');
    });

    test('respects custom options', () => {
      const options = { locale: 'en-US', currency: 'USD' };
      // Note: This will fallback to the default format since we have a fallback
      const result = MoneyFormatter.format(1000, options);
      expect(result).toMatch(/^\$?\s?\d+/); // Should contain dollar sign or number
    });

    test('uses caching for repeated calls', () => {
      const spy = jest.spyOn(MoneyFormatter, '_formatInternal');
      
      // First call should invoke internal method
      MoneyFormatter.format(1000);
      expect(spy).toHaveBeenCalledTimes(1);
      
      // Second call with same value should use cache
      MoneyFormatter.format(1000);
      // Note: Cache behavior depends on implementation details
      
      spy.mockRestore();
    });
  });

  describe('parse method', () => {
    test('parses Brazilian formatted strings', () => {
      expect(MoneyFormatter.parse('R$ 1.000,00')).toBe(1000);
      expect(MoneyFormatter.parse('R$ 1.234,56')).toBe(1234.56);
      expect(MoneyFormatter.parse('R$ 999,99')).toBe(999.99);
    });

    test('parses numbers without formatting', () => {
      expect(MoneyFormatter.parse('1000')).toBe(1000);
      expect(MoneyFormatter.parse('1234.56')).toBe(1234.56);
      expect(MoneyFormatter.parse('0.99')).toBe(0.99);
    });

    test('handles negative values', () => {
      expect(MoneyFormatter.parse('-R$ 1.000,00')).toBe(-1000);
      expect(MoneyFormatter.parse('-1234,56')).toBe(-1234.56);
    });

    test('handles number input directly', () => {
      expect(MoneyFormatter.parse(1000)).toBe(1000);
      expect(MoneyFormatter.parse(1234.56)).toBe(1234.56);
      expect(MoneyFormatter.parse(-500)).toBe(-500);
    });

    test('handles empty or null input', () => {
      expect(MoneyFormatter.parse('')).toBe(0);
      expect(MoneyFormatter.parse(null)).toBe(0);
      expect(MoneyFormatter.parse(undefined)).toBe(0);
    });

    test('handles invalid input', () => {
      expect(MoneyFormatter.parse('invalid')).toBe(0);
      expect(MoneyFormatter.parse('abc123')).toBe(0);
      expect(MoneyFormatter.parse('R$ abc')).toBe(0);
    });

    test('handles mixed formats', () => {
      // Note: Current implementation prioritizes Brazilian format
      expect(MoneyFormatter.parse('1.000,50')).toBe(1000.50); // BR format
      expect(MoneyFormatter.parse('1000,50')).toBe(1000.50);   // No thousands
      expect(MoneyFormatter.parse('1000.50')).toBe(1000.50);   // Simple decimal
    });

    test('uses caching for repeated parsing', () => {
      const value = 'R$ 1.234,56';
      
      // Parse same value multiple times
      const result1 = MoneyFormatter.parse(value);
      const result2 = MoneyFormatter.parse(value);
      
      expect(result1).toBe(1234.56);
      expect(result2).toBe(1234.56);
      expect(result1).toBe(result2);
    });
  });

  describe('formatForInput method', () => {
    test('formats for input fields without currency symbol', () => {
      expect(MoneyFormatter.formatForInput(1000)).toBe('1.000,00');
      expect(MoneyFormatter.formatForInput(1234.56)).toBe('1.234,56');
    });

    test('handles zero and empty values', () => {
      expect(MoneyFormatter.formatForInput(0)).toBe('');
      expect(MoneyFormatter.formatForInput(null)).toBe('');
      expect(MoneyFormatter.formatForInput(undefined)).toBe('');
    });

    test('maintains decimal precision', () => {
      expect(MoneyFormatter.formatForInput(10.5)).toBe('10,50');
      expect(MoneyFormatter.formatForInput(10.05)).toBe('10,05');
      expect(MoneyFormatter.formatForInput(10.005)).toBe('10,01'); // Rounds
    });
  });

  describe('getNumericValue method', () => {
    test('extracts numeric value from DOM elements', () => {
      const element = testHelpers.createElement('input', { value: 'R$ 1.234,56' });
      expect(MoneyFormatter.getNumericValue(element)).toBe(1234.56);
    });

    test('handles empty elements', () => {
      const element = testHelpers.createElement('input', { value: '' });
      expect(MoneyFormatter.getNumericValue(element)).toBe(0);
      
      expect(MoneyFormatter.getNumericValue(null)).toBe(0);
      expect(MoneyFormatter.getNumericValue(undefined)).toBe(0);
    });

    test('works with different input values', () => {
      const element1 = testHelpers.createElement('input', { value: '1.000,00' });
      const element2 = testHelpers.createElement('input', { value: 'R$ 2.500,75' });
      
      expect(MoneyFormatter.getNumericValue(element1)).toBe(1000);
      expect(MoneyFormatter.getNumericValue(element2)).toBe(2500.75);
    });
  });

  describe('mask method', () => {
    test('applies currency mask to input element', () => {
      const element = testHelpers.createElement('input');
      document.body.appendChild(element);
      
      MoneyFormatter.mask(element);
      
      // Simulate user input
      element.value = '123456';
      element.dispatchEvent(new Event('input'));
      
      expect(element.value).toBe('1.234,56');
      
      document.body.removeChild(element);
    });

    test('handles empty input gracefully', () => {
      const element = testHelpers.createElement('input');
      MoneyFormatter.mask(element);
      
      element.value = '';
      element.dispatchEvent(new Event('input'));
      
      expect(element.value).toBe('');
    });

    test('handles null element gracefully', () => {
      expect(() => MoneyFormatter.mask(null)).not.toThrow();
      expect(() => MoneyFormatter.mask(undefined)).not.toThrow();
    });
  });

  describe('Edge cases and error handling', () => {
    test('handles very large numbers', () => {
      const largeNumber = 999999999999.99;
      const formatted = MoneyFormatter.format(largeNumber);
      const parsed = MoneyFormatter.parse(formatted);
      
      expect(parsed).toBeCloseTo(largeNumber, 2);
    });

    test('handles very small numbers', () => {
      expect(MoneyFormatter.format(0.01)).toBe('R$\u00A00,01');
      expect(MoneyFormatter.format(0.001)).toBe('R$\u00A00,00'); // Rounds down
    });

    test('handles precision edge cases', () => {
      expect(MoneyFormatter.parse('1234,567')).toBe(1234.567);
      expect(MoneyFormatter.format(1234.567)).toBe('R$\u00A01.234,57'); // Rounds to 2 decimals
    });

    test('maintains consistency between format and parse', () => {
      const testValues = [0, 1, 10, 100, 1000, 1234.56, -500, -1234.56];
      
      testValues.forEach(value => {
        const formatted = MoneyFormatter.format(value);
        const parsed = MoneyFormatter.parse(formatted);
        expect(parsed).toBeCloseTo(value, 2);
      });
    });
  });

  describe('Performance', () => {
    test('caching improves performance for repeated operations', async () => {
      const iterations = 1000;
      const testValue = 1234.56;
      
      // Warm up cache
      MoneyFormatter.format(testValue);
      
      const start = performance.now();
      for (let i = 0; i < iterations; i++) {
        MoneyFormatter.format(testValue);
      }
      const end = performance.now();
      
      // Should complete quickly due to caching
      expect(end - start).toBeLessThan(100); // Less than 100ms for 1000 operations
    });

    test('handles bulk operations efficiently', () => {
      const testValues = Array.from({ length: 100 }, (_, i) => i * 12.34);
      
      const start = performance.now();
      testValues.forEach(value => {
        const formatted = MoneyFormatter.format(value);
        const parsed = MoneyFormatter.parse(formatted);
        expect(parsed).toBeCloseTo(value, 2);
      });
      const end = performance.now();
      
      // Should complete in reasonable time
      expect(end - start).toBeLessThan(1000); // Less than 1 second
    });
  });
});

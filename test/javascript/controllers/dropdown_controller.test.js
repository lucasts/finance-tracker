/**
 * Dropdown Controller Tests
 * Tests for dropdown toggle functionality
 */

import { Application } from '@hotwired/stimulus';
import DropdownController from 'controllers/dropdown_controller';

describe('DropdownController', () => {
  let application;
  let controller;
  let element;
  let menuTarget;

  beforeEach(() => {
    // Setup Stimulus application
    application = Application.start();
    application.register('dropdown', DropdownController);

    // Create dropdown HTML structure
    document.body.innerHTML = `
      <div data-controller="dropdown" class="dropdown">
        <button data-action="click->dropdown#toggle" class="btn">
          Dropdown Toggle
        </button>
        <div data-dropdown-target="menu" class="dropdown-menu hidden">
          <a href="#" class="dropdown-item">Item 1</a>
          <a href="#" class="dropdown-item">Item 2</a>
          <a href="#" class="dropdown-item">Item 3</a>
        </div>
      </div>
    `;

    element = document.querySelector('[data-controller="dropdown"]');
    menuTarget = element.querySelector('[data-dropdown-target="menu"]');
    
    // Wait for controller to initialize
    return new Promise(resolve => {
      setTimeout(() => {
        controller = application.getControllerForElementAndIdentifier(element, 'dropdown');
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
    test('connects successfully', () => {
      expect(controller).toBeDefined();
      expect(controller).not.toBeNull();
    });

    test('has correct targets', () => {
      expect(controller.hasMenuTarget).toBe(true);
      expect(controller.menuTarget).toBe(menuTarget);
    });
  });

  describe('Toggle functionality', () => {
    test('shows hidden menu when toggled', () => {
      // Initially hidden
      expect(menuTarget.classList.contains('hidden')).toBe(true);

      // Toggle to show
      controller.toggle();

      expect(menuTarget.classList.contains('hidden')).toBe(false);
    });

    test('hides visible menu when toggled', () => {
      // Start with menu visible
      menuTarget.classList.remove('hidden');
      expect(menuTarget.classList.contains('hidden')).toBe(false);

      // Toggle to hide
      controller.toggle();

      expect(menuTarget.classList.contains('hidden')).toBe(true);
    });

    test('toggles multiple times correctly', () => {
      // Initially hidden
      expect(menuTarget.classList.contains('hidden')).toBe(true);

      // First toggle - show
      controller.toggle();
      expect(menuTarget.classList.contains('hidden')).toBe(false);

      // Second toggle - hide
      controller.toggle();
      expect(menuTarget.classList.contains('hidden')).toBe(true);

      // Third toggle - show again
      controller.toggle();
      expect(menuTarget.classList.contains('hidden')).toBe(false);
    });
  });

  describe('Event handling', () => {
    test('responds to click events on trigger button', () => {
      const toggleSpy = jest.spyOn(controller, 'toggle');
      const button = element.querySelector('button');

      // Simulate click event
      button.click();

      expect(toggleSpy).toHaveBeenCalled();
    });

    test('can toggle through direct method call', () => {
      expect(() => {
        controller.toggle();
      }).not.toThrow();

      expect(menuTarget.classList.contains('hidden')).toBe(false);
    });
  });

  describe('State management', () => {
    test('maintains consistent state across toggles', () => {
      const initialState = menuTarget.classList.contains('hidden');

      // Toggle twice should return to initial state
      controller.toggle();
      controller.toggle();

      expect(menuTarget.classList.contains('hidden')).toBe(initialState);
    });

    test('works with menu that starts visible', () => {
      // Remove initial hidden class
      menuTarget.classList.remove('hidden');
      
      // Should still toggle correctly
      controller.toggle();
      expect(menuTarget.classList.contains('hidden')).toBe(true);

      controller.toggle();
      expect(menuTarget.classList.contains('hidden')).toBe(false);
    });
  });

  describe('DOM manipulation', () => {
    test('only modifies the hidden class', () => {
      const initialClasses = Array.from(menuTarget.classList);
      
      controller.toggle();
      
      const newClasses = Array.from(menuTarget.classList);
      const addedClasses = newClasses.filter(cls => !initialClasses.includes(cls));
      const removedClasses = initialClasses.filter(cls => !newClasses.includes(cls));
      
      // Should only change the 'hidden' class
      expect(addedClasses.concat(removedClasses)).toEqual(['hidden']);
    });

    test('preserves other CSS classes', () => {
      menuTarget.classList.add('custom-class', 'another-class');
      
      controller.toggle();
      
      expect(menuTarget.classList.contains('custom-class')).toBe(true);
      expect(menuTarget.classList.contains('another-class')).toBe(true);
      expect(menuTarget.classList.contains('dropdown-menu')).toBe(true);
    });
  });

  describe('Error handling', () => {
    test('handles missing menu target gracefully', () => {
      // Create a controller without menu target to test error handling
      const brokenHTML = `
        <div data-controller="dropdown" class="dropdown">
          <button data-action="click->dropdown#toggle" class="btn">
            Dropdown Toggle (No Menu)
          </button>
        </div>
      `;
      
      document.body.innerHTML = brokenHTML;
      const brokenElement = document.querySelector('[data-controller="dropdown"]');
      
      // Controller should connect but will error when trying to access missing target
      const brokenController = application.getControllerForElementAndIdentifier(brokenElement, 'dropdown');
      expect(brokenController).toBeDefined();
      
      // Should throw when trying to toggle without menu target
      expect(() => {
        brokenController.toggle();
      }).toThrow();
    });
  });

  describe('Multiple dropdown instances', () => {
    test('operates independently from other dropdowns', () => {
      // Create second dropdown
      const secondDropdownHTML = `
        <div data-controller="dropdown" class="dropdown" id="second-dropdown">
          <button data-action="click->dropdown#toggle" class="btn">
            Second Dropdown
          </button>
          <div data-dropdown-target="menu" class="dropdown-menu hidden">
            <a href="#" class="dropdown-item">Second Item 1</a>
          </div>
        </div>
      `;
      
      document.body.insertAdjacentHTML('beforeend', secondDropdownHTML);
      
      const secondElement = document.getElementById('second-dropdown');
      const secondMenuTarget = secondElement.querySelector('[data-dropdown-target="menu"]');
      
      return new Promise(resolve => {
        setTimeout(() => {
          const secondController = application.getControllerForElementAndIdentifier(secondElement, 'dropdown');

          // Toggle first dropdown
          controller.toggle();
          expect(menuTarget.classList.contains('hidden')).toBe(false);
          expect(secondMenuTarget.classList.contains('hidden')).toBe(true);

          // Toggle second dropdown
          secondController.toggle();
          expect(menuTarget.classList.contains('hidden')).toBe(false);
          expect(secondMenuTarget.classList.contains('hidden')).toBe(false);

          // Both should be independent
          controller.toggle();
          expect(menuTarget.classList.contains('hidden')).toBe(true);
          expect(secondMenuTarget.classList.contains('hidden')).toBe(false);
          
          resolve();
        }, 10);
      });
    });
  });
});

# frozen_string_literal: true

# Base service class to standardize service patterns across the application
#
# Usage patterns:
#
# 1. Simple services (recommended for most cases):
#    class ExampleService < BaseService
#      def self.call(**params)
#        new(**params).execute
#      end
#
#      private
#
#      def initialize(**params)
#        @params = params
#      end
#
#      def execute
#        # implementation
#      end
#    end
#
# 2. Callback services:
#    class CallbackService < BaseService
#      def self.call(object:, operation:)
#        new(object).send("execute_#{operation}")
#      end
#
#      def initialize(object)
#        @object = object
#      end
#
#      def execute_after_save
#        # implementation
#      end
#    end
#
# 3. Utility services (class methods only):
#    For mathematical calculations, date utilities, etc.
#    No inheritance needed, just class methods.
#
class BaseService
  # Placeholder for shared service logic if needed in the future
  # Currently serves as documentation and namespace
end

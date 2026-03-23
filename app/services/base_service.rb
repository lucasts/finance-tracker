# frozen_string_literal: true

# Base class documenting canonical service patterns used across the application.
#
# == Constructor/call convention ==
#
# All services expose a single class-level entry point:
#
#   SomeService.call(keyword: args)
#
# Pattern 1 — Simple services (most common):
#
#   class ExampleService < BaseService
#     def self.call(user:, **params)
#       new(user: user, **params).execute
#     end
#
#     private
#
#     def initialize(user:, **params)
#       @user   = user
#       @params = params
#     end
#
#     def execute
#       # ...
#     end
#   end
#
# Pattern 2 — Callback dispatch (used where operation varies at call-time):
#
#   class CallbackService < BaseService
#     def self.call(object:, operation:)
#       new(object).send("execute_#{operation}")
#     end
#
#     def execute_after_save; end
#     def execute_before_save; end
#   end
#
# Pattern 3 — Utility (pure class methods, no instance needed):
#   No inheritance required; just define class methods directly.
#
# == Error handling conventions ==
#
# Choose the pattern that best matches the service's responsibility:
#
# A. Raise exceptions — for unrecoverable external/parse failures:
#      raise StandardError, "Invalid input: #{reason}"
#    Callers must rescue. Use for: OFX/CSV parse errors, fatal config problems.
#
# B. Return the ActiveRecord model — for single-model persistence services:
#      return transaction   # caller checks transaction.errors.any?
#    Rails-idiomatic. Use for: CreateTransactionService.
#
# C. Return a result hash — for multi-step operations with multiple failure modes:
#      { success: true/false, errors: [], result: object }
#    Explicit contract. Use for: RecurringCommitmentEditorUnifiedService,
#    VariableExpenseAnalysisUnifiedService.
#
# Each service should document in its class comment which pattern it uses.
#
class BaseService
end

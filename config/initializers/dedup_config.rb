# frozen_string_literal: true

# Loads dedup tolerance configuration from config/dedup.yml and exposes it
# via Rails.application.config.dedup (a HashWithIndifferentAccess).
#
# Usage in services:
#   cfg = Rails.application.config.dedup
#   cfg[:exact_amount_tolerance]   # => 0.01
#   cfg[:similar_date_tolerance_days] # => 3

raw = YAML.load_file(Rails.root.join("config/dedup.yml"), aliases: true, permitted_classes: [Symbol])
env_config = raw.fetch(Rails.env, raw.fetch("default", {}))
Rails.application.config.dedup = env_config.with_indifferent_access

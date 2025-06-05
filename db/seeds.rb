# Load setup seeds (basic structure - runs in all environments)
puts "Loading essential setup seeds..."
load Rails.root.join('db', 'seeds', 'setup.rb')

# Demo data is now separated and won't load automatically
# To load demo data manually, run: rails db:seed:demo
puts "Essential seeds completed."
puts ""
puts "💡 Para carregar dados de demonstração, execute: rails db:seed:demo"

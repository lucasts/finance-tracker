# Load setup seeds (basic structure - runs in all environments)
puts "Loading essential setup seeds..."
load Rails.root.join('db', 'seeds', 'setup.rb')

# Load demo data only in development environment
if Rails.env.development?
  puts "Development environment detected - loading demo data..."
  load Rails.root.join('db', 'seeds', 'demo_realistic.rb')
else
  puts "Environment: #{Rails.env} - skipping demo data (only loads in development)"
end

puts "Seeds completed for #{Rails.env} environment."

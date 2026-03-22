# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"

# Controllers
pin_all_from "app/javascript/controllers", under: "controllers"

# Services and utilities
pin_all_from "app/javascript/services", under: "services"
pin_all_from "app/javascript/utilities", under: "utilities"

# Configuration and initializers
pin_all_from "app/javascript/config", under: "config"
pin_all_from "app/javascript/initializers", under: "initializers"

# Third-party libraries
pin "apexcharts", to: "https://cdn.jsdelivr.net/npm/apexcharts@3.45.2/dist/apexcharts.esm.js"

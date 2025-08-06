// Chart Controller
// Enhanced chart management with ApexCharts integration

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "legend", "toolbar"]
  static values = {
    type: { type: String, default: "line" },
    data: { type: Array, default: [] },
    categories: { type: Array, default: [] },
    options: { type: Object, default: {} },
    height: { type: Number, default: 350 },
    colors: { type: Array, default: [] },
    title: String,
    subtitle: String
  }

  connect() {
    this.chart = null
    // Wait for ApexCharts to be available
    this.waitForApexCharts().then(() => {
      this.initializeChart()
    })
    console.log("Chart controller connected", { type: this.typeValue })
  }

  // Wait for ApexCharts library to be loaded
  async waitForApexCharts() {
    let attempts = 0
    const maxAttempts = 50 // 5 seconds max
    
    while (!window.ApexCharts && attempts < maxAttempts) {
      await new Promise(resolve => setTimeout(resolve, 100))
      attempts++
    }
    
    if (!window.ApexCharts) {
      console.error("ApexCharts failed to load after 5 seconds")
    }
  }

  disconnect() {
    this.destroyChart()
  }

  // Initialize chart with configuration
  async initializeChart() {
    if (!window.ApexCharts) {
      console.error("ApexCharts library not loaded")
      return
    }

    if (!this.hasContainerTarget) {
      console.log("No container target found for chart - chart will be available for method calls")
      return
    }

    try {
      let options;
      
      // Check if we have complete options from server
      if (this.optionsValue && Object.keys(this.optionsValue).length > 0 && this.optionsValue.series) {
        // Use server-provided options but sanitize them for JavaScript
        options = this.sanitizeServerOptions(this.optionsValue);
        console.log("Using server-provided chart options")
      } else {
        // For reports page or when no server data, don't initialize empty chart
        // Chart will be created when user clicks buttons via showSampleChart
        console.log("No server data available, chart will be created on demand")
        return
      }
      
      // Validate options before creating chart
      if (!options.series || options.series.length === 0) {
        console.warn("No series data available, skipping chart initialization")
        return
      }
      
      // Log chart options for debugging
      console.log("Final chart options:", options)
      
      this.chart = new ApexCharts(this.containerTarget, options)
      
      await this.chart.render()
      this.dispatch("chart-rendered", { chart: this.chart })
      this.announceSuccess("Gráfico carregado com sucesso")
      console.log("Chart rendered successfully")
      
    } catch (error) {
      console.error("Failed to initialize chart", error)
      this.announceError("Falha ao carregar gráfico: " + error.message)
      this.showError("Erro ao carregar gráfico: " + error.message)
    }
  }

  // Sanitize server options for JavaScript compatibility
  sanitizeServerOptions(serverOptions) {
    const options = JSON.parse(JSON.stringify(serverOptions)); // Deep clone
    
    // Add Brazilian currency formatter
    const formatCurrency = (value) => {
      if (value == null || isNaN(value)) return 'R$ 0,00';
      return 'R$ ' + parseFloat(value).toLocaleString('pt-BR', {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
      });
    };
    
    // Fix yaxis labels formatter
    if (options.yaxis && Array.isArray(options.yaxis)) {
      options.yaxis.forEach(axis => {
        if (axis.labels) {
          axis.labels.formatter = formatCurrency;
        } else {
          axis.labels = { formatter: formatCurrency };
        }
      });
    }
    
    // Fix tooltip formatter
    if (options.tooltip) {
      if (!options.tooltip.y) {
        options.tooltip.y = {};
      }
      options.tooltip.y.formatter = formatCurrency;
    }
    
    // Ensure series data is valid
    if (options.series) {
      options.series = options.series.map(series => ({
        ...series,
        data: this.sanitizeData(series.data || [])
      }));
    }
    
    return options;
  }

  // Build chart configuration
  buildChartOptions() {
    const defaultColors = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd'];

    // Ensure we have valid series data
    let series = this.buildSeries();
    if (!series || series.length === 0) {
      console.warn("No valid series, creating default")
      series = [{
        name: 'Sem dados',
        data: [0]
      }];
    }

    // Ensure all series have at least one data point
    series = series.map(s => ({
      ...s,
      data: s.data && s.data.length > 0 ? s.data : [0]
    }));

    // Simple, robust base configuration
    const baseOptions = {
      chart: {
        type: this.typeValue || 'line',
        height: this.heightValue || 350,
        animations: {
          enabled: true,
          easing: 'easeinout',
          speed: 800
        },
        toolbar: {
          show: false // Simplify by disabling toolbar
        },
        background: 'transparent'
      },
      series: series,
      colors: this.colorsValue && this.colorsValue.length > 0 ? this.colorsValue : defaultColors,
      xaxis: {
        categories: this.categoriesValue && this.categoriesValue.length > 0 ? this.categoriesValue : ['Dados'],
        labels: {
          style: {
            fontSize: '12px'
          }
        }
      },
      yaxis: {
        labels: {
          style: {
            fontSize: '12px'
          },
          formatter: function(value) {
            if (value == null || isNaN(value)) return '0,00'
            return parseFloat(value).toLocaleString('pt-BR', {
              minimumFractionDigits: 2,
              maximumFractionDigits: 2
            })
          }
        }
      },
      title: this.titleValue ? {
        text: this.titleValue,
        align: 'center',
        style: {
          fontSize: '16px',
          fontWeight: 'bold',
          color: '#333'
        }
      } : undefined,
      legend: {
        show: true,
        position: 'bottom',
        fontSize: '12px'
      },
      dataLabels: {
        enabled: false
      },
      stroke: {
        curve: 'smooth',
        width: 2
      },
      tooltip: {
        enabled: true,
        y: {
          formatter: function(value) {
            if (value == null || isNaN(value)) return 'R$ 0,00'
            return 'R$ ' + parseFloat(value).toLocaleString('pt-BR', {
              minimumFractionDigits: 2,
              maximumFractionDigits: 2
            })
          }
        }
      },
      grid: {
        show: true,
        strokeDashArray: 3
      },
      responsive: [{
        breakpoint: 768,
        options: {
          chart: {
            height: 300
          },
          legend: {
            position: 'bottom'
          }
        }
      }]
    }

    console.log("Built chart options:", {
      seriesCount: baseOptions.series.length,
      seriesNames: baseOptions.series.map(s => s.name),
      categoriesCount: baseOptions.xaxis.categories.length,
      type: baseOptions.chart.type,
      height: baseOptions.chart.height
    })
    
    return baseOptions
  }

  // Build series data based on chart type
  buildSeries() {
    if (!this.dataValue || this.dataValue.length === 0) {
      console.log("No dataValue available, returning default series")
      return [{
        name: 'Sem dados',
        data: [0]
      }]
    }

    try {
      console.log("Building series from dataValue:", this.dataValue)
      
      // Handle different data formats
      if (Array.isArray(this.dataValue[0])) {
        // Multiple series format: [[series1], [series2], ...]
        const series = this.dataValue.map((seriesData, index) => ({
          name: seriesData.name || `Série ${index + 1}`,
          data: this.sanitizeData(seriesData.data || seriesData)
        }))
        console.log("Built multiple series:", series)
        return series
      } else if (typeof this.dataValue[0] === 'object' && this.dataValue[0].name) {
        // Already formatted series: [{name: '', data: []}, ...]
        const series = this.dataValue.map(series => ({
          name: series.name || 'Dados',
          data: this.sanitizeData(series.data || [])
        }))
        console.log("Built from formatted series:", series)
        return series
      } else {
        // Single series format: [value1, value2, ...]
        const series = [{
          name: 'Dados',
          data: this.sanitizeData(this.dataValue)
        }]
        console.log("Built single series:", series)
        return series
      }
    } catch (error) {
      console.error("Error building series data:", error)
      return [{
        name: 'Erro nos dados',
        data: [0]
      }]
    }
  }

  // Sanitize data to ensure valid numbers
  sanitizeData(data) {
    if (!Array.isArray(data)) {
      return []
    }
    
    return data.map(value => {
      if (value === null || value === undefined || isNaN(value)) {
        return 0
      }
      return parseFloat(value) || 0
    })
  }

  // Merge chart options recursively
  mergeOptions(base, custom) {
    const result = { ...base }
    
    for (const key in custom) {
      if (custom[key] && typeof custom[key] === 'object' && !Array.isArray(custom[key])) {
        result[key] = this.mergeOptions(result[key] || {}, custom[key])
      } else {
        result[key] = custom[key]
      }
    }
    
    return result
  }

  // Update chart data
  updateData(newData, newCategories = null) {
    if (!this.chart) {
      console.error("Chart not initialized")
      return
    }

    try {
      this.dataValue = newData
      
      if (newCategories) {
        this.categoriesValue = newCategories
      }

      const newSeries = this.buildSeries()
      this.chart.updateSeries(newSeries)

      if (newCategories) {
        this.chart.updateOptions({
          xaxis: {
            categories: this.categoriesValue
          }
        })
      }

      this.dispatch("chart-updated", { data: newData, categories: newCategories })
      console.log("Chart data updated")
      
    } catch (error) {
      console.error("Failed to update chart data", error)
    }
  }

  // Destroy chart instance
  destroyChart() {
    if (this.chart) {
      try {
        this.chart.destroy()
        this.chart = null
        console.log("Chart destroyed")
      } catch (error) {
        console.error("Failed to destroy chart", error)
        this.chart = null // Force reset even if destroy fails
      }
    }
    
    // Clear container content to ensure clean state
    if (this.hasContainerTarget) {
      this.containerTarget.innerHTML = ''
    }
  }

  // Show error message
  showError(message) {
    if (this.hasContainerTarget) {
      this.containerTarget.innerHTML = `
        <div class="flex items-center justify-center h-full text-error">
          <div class="text-center">
            <svg class="w-12 h-12 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
            <p>${message}</p>
          </div>
        </div>
      `
    }
  }

  // Value change handlers
  dataValueChanged() {
    if (this.chart && this.dataValue) {
      this.updateData(this.dataValue)
    }
  }

  categoriesValueChanged() {
    if (this.chart && this.categoriesValue) {
      this.updateData(this.dataValue, this.categoriesValue)
    }
  }

  optionsValueChanged() {
    if (this.chart && this.optionsValue) {
      this.chart.updateOptions(this.optionsValue)
    }
  }

  // Show chart method for buttons
  show(event) {
    const chartType = event.currentTarget.dataset.chartType
    console.log("Show chart requested:", chartType)
    
    if (!this.hasContainerTarget) {
      console.error("No container target available to show chart")
      return
    }

    // Update button states
    this.element.querySelectorAll('button').forEach(btn => {
      btn.classList.remove('btn-primary')
      btn.classList.add('btn-outline')
    })
    
    event.currentTarget.classList.remove('btn-outline')
    event.currentTarget.classList.add('btn-primary')
    
    // Here you can load different chart data based on chartType
    // For now, just show a sample chart
    this.showSampleChart(chartType)
  }

  // Show sample chart (to be replaced with real data)
  showSampleChart(type) {
    console.log("showSampleChart called with type:", type)
    
    if (!this.hasContainerTarget) {
      console.error("No container target available for chart")
      return
    }

    const sampleData = {
      'expense-trends': {
        series: [{ name: 'Despesas', data: [1000, 1200, 800, 1500, 900, 1100] }],
        categories: ['Jan', 'Feb', 'Mar', 'Apr', 'Mai', 'Jun'],
        title: 'Tendência de Despesas'
      },
      'income-vs-expense': {
        series: [
          { name: 'Receitas', data: [3000, 3200, 2800, 3500, 2900, 3100] },
          { name: 'Despesas', data: [1000, 1200, 800, 1500, 900, 1100] }
        ],
        categories: ['Jan', 'Feb', 'Mar', 'Apr', 'Mai', 'Jun'],
        title: 'Receitas vs Despesas'
      },
      'savings-rate': {
        series: [{ name: 'Taxa de Poupança (%)', data: [20, 25, 18, 30, 22, 28] }],
        categories: ['Jan', 'Feb', 'Mar', 'Apr', 'Mai', 'Jun'],
        title: 'Taxa de Poupança'
      },
      'category-breakdown': {
        series: [
          { name: 'Alimentação', data: [800, 850, 750, 900, 820, 880] },
          { name: 'Transporte', data: [300, 320, 280, 350, 310, 330] },
          { name: 'Lazer', data: [200, 180, 220, 250, 190, 210] }
        ],
        categories: ['Jan', 'Feb', 'Mar', 'Apr', 'Mai', 'Jun'],
        title: 'Gastos por Categoria'
      }
    }

    const chartData = sampleData[type] || sampleData['expense-trends']
    
    // Update chart with new data
    this.dataValue = chartData.series
    this.categoriesValue = chartData.categories
    this.titleValue = chartData.title
    
    // Always destroy existing chart first to prevent conflicts
    this.destroyChart()
    
    // Use setTimeout to ensure DOM is ready
    setTimeout(() => {
      this.createChartWithData()
    }, 50)
  }

  // Create chart with current data values (for on-demand creation)
  async createChartWithData() {
    if (!window.ApexCharts) {
      console.error("ApexCharts library not loaded")
      return
    }

    if (!this.hasContainerTarget) {
      console.error("No container target found for chart")
      return
    }

    try {
      // Clear container content completely
      this.containerTarget.innerHTML = ''
      
      // Force container to have minimum dimensions
      if (!this.containerTarget.style.minHeight) {
        this.containerTarget.style.minHeight = '350px'
      }
      if (!this.containerTarget.style.width) {
        this.containerTarget.style.width = '100%'
      }
      
      // Wait a bit more for the container to be properly cleared and sized
      await new Promise(resolve => setTimeout(resolve, 200))
      
      // Check if container is in DOM and visible
      if (!document.contains(this.containerTarget)) {
        console.error("Container target not in DOM")
        return
      }
      
      // Get computed styles to check visibility
      const computedStyle = window.getComputedStyle(this.containerTarget)
      if (computedStyle.display === 'none' || computedStyle.visibility === 'hidden') {
        console.error("Container target is hidden")
        return
      }
      
      const options = this.buildChartOptions()
      
      // Validate options more thoroughly
      if (!options || !options.series || options.series.length === 0) {
        console.error("No valid series data for chart creation")
        return
      }
      
      // Ensure all series have valid data
      const validSeries = options.series.filter(series => 
        series && series.data && Array.isArray(series.data) && series.data.length > 0
      )
      
      if (validSeries.length === 0) {
        console.error("No series with valid data found")
        return
      }
      
      options.series = validSeries
      
      console.log("Creating chart with validated options:", {
        seriesCount: options.series.length,
        categoriesCount: options.xaxis?.categories?.length || 0,
        containerDimensions: {
          width: this.containerTarget.offsetWidth,
          height: this.containerTarget.offsetHeight,
          clientWidth: this.containerTarget.clientWidth,
          clientHeight: this.containerTarget.clientHeight
        }
      })
      
      // Create the chart instance
      this.chart = new ApexCharts(this.containerTarget, options)
      
      // Render with error handling
      await this.chart.render()
      
      this.dispatch("chart-rendered", { chart: this.chart })
      console.log("Chart created successfully with local data")
      
    } catch (error) {
      console.error("Failed to create chart with data", error)
      console.error("Error stack:", error.stack)
      
      // Clean up on error
      if (this.chart) {
        try {
          this.chart.destroy()
        } catch (destroyError) {
          console.error("Failed to destroy chart after error:", destroyError)
        }
        this.chart = null
      }
      
      this.showError("Erro ao criar gráfico: " + error.message)
    }
  }
}
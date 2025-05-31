import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts"

export default class extends Controller {
  static values = { options: Object }

  connect() {
    // Adiciona formatadores para os tooltips
    const options = {
      ...this.optionsValue,
      tooltip: {
        ...this.optionsValue.tooltip,
        y: {
          formatter: function(value, { series, seriesIndex, dataPointIndex, w }) {
            return "R$ " + value.toLocaleString('pt-BR', { 
              minimumFractionDigits: 2, 
              maximumFractionDigits: 2 
            })
          }
        }
      },
      yaxis: {
        ...this.optionsValue.yaxis,
        labels: {
          formatter: function(value) {
            return "R$ " + value.toLocaleString('pt-BR', { 
              minimumFractionDigits: 0, 
              maximumFractionDigits: 0 
            })
          }
        }
      }
    }

    this.chart = new ApexCharts(this.element, options)
    this.chart.render()
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }
}

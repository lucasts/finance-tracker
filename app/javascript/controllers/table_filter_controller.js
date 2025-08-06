// Table Filter Controller
// Manages table filtering with enhanced search and accessibility

import ApplicationController from "../helpers/application_controller"

export default class extends ApplicationController {
  static targets = ["table", "row", "statusFilter", "typeFilter", "searchInput", "noResults"]
  static values = {
    searchColumns: { type: Array, default: [] },
    caseSensitive: { type: Boolean, default: false },
    debounceDelay: { type: Number, default: 300 }
  }

  connect() {
    super.connect()
    this.debouncedFilter = this.debounce(this.applyFilters.bind(this), this.debounceDelayValue)
    this.setupInitialState()
  }

  setupInitialState() {
    // Store original rows for filtering
    this.originalRows = this.rowTargets.slice()
    
    // Apply any pre-selected filters
    this.applyFilters()
  }

  // Main filtering method
  applyFilters() {
    this.log("Applying filters")
    
    const searchTerm = this.getSearchTerm()
    const statusFilter = this.getStatusFilter()
    const typeFilter = this.getTypeFilter()
    
    let visibleCount = 0
    
    this.originalRows.forEach(row => {
      const isVisible = this.shouldShowRow(row, searchTerm, statusFilter, typeFilter)
      
      if (isVisible) {
        this.showElement(row)
        visibleCount++
      } else {
        this.hideElement(row)
      }
    })
    
    this.updateNoResultsDisplay(visibleCount)
    this.announceFilterResults(visibleCount)
    this.dispatch("filtered", { visibleCount, totalCount: this.originalRows.length })
  }

  // Check if row should be visible based on all filters
  shouldShowRow(row, searchTerm, statusFilter, typeFilter) {
    // Search filter
    if (searchTerm && !this.matchesSearch(row, searchTerm)) {
      return false
    }
    
    // Status filter
    if (statusFilter && statusFilter !== 'all' && !this.matchesStatus(row, statusFilter)) {
      return false
    }
    
    // Type filter
    if (typeFilter && typeFilter !== 'all' && !this.matchesType(row, typeFilter)) {
      return false
    }
    
    return true
  }

  // Search matching logic
  matchesSearch(row, searchTerm) {
    if (!searchTerm) return true
    
    const searchText = this.caseSensitiveValue ? searchTerm : searchTerm.toLowerCase()
    
    // If specific columns are defined, search only those
    if (this.searchColumnsValue.length > 0) {
      return this.searchColumnsValue.some(columnIndex => {
        const cell = row.cells[columnIndex]
        if (!cell) return false
        
        const cellText = this.caseSensitiveValue ? 
          cell.textContent.trim() : 
          cell.textContent.trim().toLowerCase()
        
        return cellText.includes(searchText)
      })
    }
    
    // Otherwise search all visible text in the row
    const rowText = this.caseSensitiveValue ? 
      row.textContent.trim() : 
      row.textContent.trim().toLowerCase()
    
    return rowText.includes(searchText)
  }

  // Status matching logic
  matchesStatus(row, statusFilter) {
    const statusElement = row.querySelector('[data-status], .badge, .status')
    
    if (!statusElement) return true
    
    const rowStatus = statusElement.dataset.status || 
                     statusElement.className.match(/status-(\w+)/)?.[1] ||
                     statusElement.textContent.trim().toLowerCase()
    
    return rowStatus.toLowerCase() === statusFilter.toLowerCase()
  }

  // Type matching logic
  matchesType(row, typeFilter) {
    const typeElement = row.querySelector('[data-type], .type')
    
    if (!typeElement) return true
    
    const rowType = typeElement.dataset.type || 
                   typeElement.textContent.trim().toLowerCase()
    
    return rowType.toLowerCase() === typeFilter.toLowerCase()
  }

  // Get current search term
  getSearchTerm() {
    return this.hasSearchInputTarget ? 
      this.searchInputTarget.value.trim() : 
      ''
  }

  // Get current status filter
  getStatusFilter() {
    return this.hasStatusFilterTarget ? 
      this.statusFilterTarget.value : 
      'all'
  }

  // Get current type filter
  getTypeFilter() {
    return this.hasTypeFilterTarget ? 
      this.typeFilterTarget.value : 
      'all'
  }

  // Update no results message
  updateNoResultsDisplay(visibleCount) {
    if (this.hasNoResultsTarget) {
      if (visibleCount === 0) {
        this.showElement(this.noResultsTarget)
      } else {
        this.hideElement(this.noResultsTarget)
      }
    }
  }

  // Announce filter results to screen readers
  announceFilterResults(visibleCount) {
    const total = this.originalRows.length
    
    if (visibleCount === total) {
      this.log("Todos os itens estão visíveis")
    } else if (visibleCount === 0) {
      this.log("Nenhum item encontrado com os filtros aplicados")
    } else {
      this.log(`${visibleCount} de ${total} itens encontrados`)
    }
  }

  // Event handlers
  handleSearch() {
    this.debouncedFilter()
  }

  handleStatusChange() {
    this.applyFilters()
  }

  handleTypeChange() {
    this.applyFilters()
  }

  // Clear all filters
  clearFilters() {
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ''
    }
    
    if (this.hasStatusFilterTarget) {
      this.statusFilterTarget.value = 'all'
    }
    
    if (this.hasTypeFilterTarget) {
      this.typeFilterTarget.value = 'all'
    }
    
    this.applyFilters()
    this.log("Filtros limpos")
  }

  // Reset to show all rows
  showAll() {
    this.originalRows.forEach(row => {
      this.showElement(row)
    })
    
    this.updateNoResultsDisplay(this.originalRows.length)
    this.log("Todos os itens estão visíveis")
  }

  // Get current filter state
  getFilterState() {
    return {
      search: this.getSearchTerm(),
      status: this.getStatusFilter(),
      type: this.getTypeFilter()
    }
  }

  // Apply filter state
  applyFilterState(state) {
    if (state.search !== undefined && this.hasSearchInputTarget) {
      this.searchInputTarget.value = state.search
    }
    
    if (state.status !== undefined && this.hasStatusFilterTarget) {
      this.statusFilterTarget.value = state.status
    }
    
    if (state.type !== undefined && this.hasTypeFilterTarget) {
      this.typeFilterTarget.value = state.type
    }
    
    this.applyFilters()
  }
}

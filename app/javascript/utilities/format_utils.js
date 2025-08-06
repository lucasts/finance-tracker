// Format Utilities
// Comprehensive formatting helpers for data display and input

import { MoneyFormatter } from '../services/money_formatter.js';

export class FormatUtils {
  // Locale settings
  static locale = 'pt-BR';
  static currency = 'BRL';

  // Number formatting with Brazilian locale
  static formatNumber(value, options = {}) {
    const defaults = {
      minimumFractionDigits: 0,
      maximumFractionDigits: 2
    };

    const formatter = new Intl.NumberFormat(this.locale, { ...defaults, ...options });
    return formatter.format(value);
  }

  // Currency formatting (unified with MoneyFormatter)
  static formatCurrency(value, options = {}) {
    return MoneyFormatter.format(value);
  }

  // Percentage formatting
  static formatPercentage(value, options = {}) {
    const defaults = {
      style: 'percent',
      minimumFractionDigits: 1,
      maximumFractionDigits: 2
    };

    const formatter = new Intl.NumberFormat(this.locale, { ...defaults, ...options });
    return formatter.format(value / 100);
  }

  // Date formatting
  static formatDate(date, format = 'short') {
    if (!date) return '';
    
    const dateObj = typeof date === 'string' ? new Date(date) : date;
    
    const formats = {
      short: { day: '2-digit', month: '2-digit', year: 'numeric' },
      medium: { day: '2-digit', month: 'short', year: 'numeric' },
      long: { weekday: 'long', day: '2-digit', month: 'long', year: 'numeric' },
      time: { hour: '2-digit', minute: '2-digit' },
      datetime: { 
        day: '2-digit', 
        month: '2-digit', 
        year: 'numeric',
        hour: '2-digit', 
        minute: '2-digit' 
      }
    };

    const formatter = new Intl.DateTimeFormat(this.locale, formats[format] || formats.short);
    return formatter.format(dateObj);
  }

  // Date formatting for backend (ISO format)
  static formatDateForBackend(date) {
    if (!date) return '';
    
    const dateObj = typeof date === 'string' ? new Date(date) : date;
    return dateObj.toISOString().split('T')[0]; // Returns YYYY-MM-DD
  }

  // Relative time formatting
  static formatRelativeTime(date) {
    if (!date) return '';
    
    const dateObj = typeof date === 'string' ? new Date(date) : date;
    const now = new Date();
    const diffInMs = now - dateObj;
    const diffInDays = Math.floor(diffInMs / (1000 * 60 * 60 * 24));

    if (diffInDays === 0) {
      return 'Hoje';
    } else if (diffInDays === 1) {
      return 'Ontem';
    } else if (diffInDays === -1) {
      return 'Amanhã';
    } else if (diffInDays > 1 && diffInDays <= 7) {
      return `${diffInDays} dias atrás`;
    } else if (diffInDays < -1 && diffInDays >= -7) {
      return `Em ${Math.abs(diffInDays)} dias`;
    } else {
      return this.formatDate(dateObj);
    }
  }

  // Phone number formatting
  static formatPhone(phone) {
    if (!phone) return '';
    
    const cleaned = phone.replace(/\D/g, '');
    
    if (cleaned.length === 11) {
      // Mobile: (11) 99999-9999
      return cleaned.replace(/(\d{2})(\d{5})(\d{4})/, '($1) $2-$3');
    } else if (cleaned.length === 10) {
      // Landline: (11) 9999-9999
      return cleaned.replace(/(\d{2})(\d{4})(\d{4})/, '($1) $2-$3');
    }
    
    return phone;
  }

  // CPF formatting
  static formatCPF(cpf) {
    if (!cpf) return '';
    
    const cleaned = cpf.replace(/\D/g, '');
    
    if (cleaned.length === 11) {
      return cleaned.replace(/(\d{3})(\d{3})(\d{3})(\d{2})/, '$1.$2.$3-$4');
    }
    
    return cpf;
  }

  // CNPJ formatting
  static formatCNPJ(cnpj) {
    if (!cnpj) return '';
    
    const cleaned = cnpj.replace(/\D/g, '');
    
    if (cleaned.length === 14) {
      return cleaned.replace(/(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})/, '$1.$2.$3/$4-$5');
    }
    
    return cnpj;
  }

  // Bank account formatting
  static formatBankAccount(account, agency) {
    if (!account) return '';
    
    let formatted = account.toString();
    
    if (agency) {
      return `${agency}-${formatted}`;
    }
    
    return formatted;
  }

  // Credit card number formatting
  static formatCardNumber(cardNumber) {
    if (!cardNumber) return '';
    
    const cleaned = cardNumber.replace(/\D/g, '');
    
    // Add spaces every 4 digits
    return cleaned.replace(/(\d{4})(?=\d)/g, '$1 ');
  }

  // File size formatting
  static formatFileSize(bytes, decimals = 2) {
    if (bytes === 0) return '0 Bytes';

    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];

    const i = Math.floor(Math.log(bytes) / Math.log(k));

    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
  }

  // Capitalize first letter
  static capitalize(str) {
    if (!str) return '';
    return str.charAt(0).toUpperCase() + str.slice(1).toLowerCase();
  }

  // Title case formatting
  static titleCase(str) {
    if (!str) return '';
    
    return str.toLowerCase().split(' ').map(word => {
      // Don't capitalize small words unless they're the first word
      const smallWords = ['a', 'o', 'e', 'de', 'da', 'do', 'das', 'dos', 'em', 'na', 'no', 'para'];
      
      if (smallWords.includes(word) && str.indexOf(word) !== 0) {
        return word;
      }
      
      return this.capitalize(word);
    }).join(' ');
  }

  // Truncate text with ellipsis
  static truncate(text, maxLength, suffix = '...') {
    if (!text || text.length <= maxLength) return text;
    
    return text.substring(0, maxLength - suffix.length) + suffix;
  }

  // Clean input by removing non-numeric characters
  static cleanNumeric(value) {
    return value.toString().replace(/[^\d.-]/g, '');
  }

  // Clean input by removing non-alphanumeric characters
  static cleanAlphanumeric(value) {
    return value.toString().replace(/[^a-zA-Z0-9]/g, '');
  }

  // Format bank slip barcode
  static formatBankSlipBarcode(barcode) {
    if (!barcode) return '';
    
    const cleaned = barcode.replace(/\D/g, '');
    
    if (cleaned.length === 47) {
      // Linha digitável
      return cleaned.replace(
        /(\d{5})(\d{5})(\d{5})(\d{6})(\d{5})(\d{6})(\d{1})(\d{14})/,
        '$1.$2 $3.$4 $5.$6 $7 $8'
      );
    } else if (cleaned.length === 44) {
      // Código de barras
      return cleaned.replace(
        /(\d{4})(\d{5})(\d{10})(\d{10})(\d{15})/,
        '$1 $2 $3 $4 $5'
      );
    }
    
    return barcode;
  }

  // Parse currency string to number
  static parseCurrency(currencyString) {
    return MoneyFormatter.parse(currencyString);
  }

  // Format large numbers with abbreviations
  static formatCompactNumber(value, options = {}) {
    const defaults = {
      notation: 'compact',
      compactDisplay: 'short'
    };

    const formatter = new Intl.NumberFormat(this.locale, { ...defaults, ...options });
    return formatter.format(value);
  }
}

export default FormatUtils;

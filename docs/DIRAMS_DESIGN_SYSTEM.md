# DiRams Design System

Sistema de design inspirado nos princípios de design industrial de Dieter Rams.

## Princípios

1. **Elementos HTML semânticos primeiro** - Usar `<section>`, `<article>`, `<header>`, `<footer>`, `<mark>`, `<data>`, etc.
2. **Classes apenas onde necessário** - Evitar "sopa de classes" utilitárias
3. **CSS contextual** - Estilos baseados em hierarquia e estrutura
4. **"Weniger, aber besser"** - Menos, mas melhor

## Paleta de Cores (DiRams Authentic)

### Base (Terrosa & Atemporal)
- **Soft Linen** `#E6E2D8` - Background bege claro quente
- **Alabaster Grey** `#E1E0DE` - Elementos secundários, bordas
- **Off-White** `#fafaf8` - Surface branco quente para cards
- **Gunmetal** `#414141` - Texto principal cinza metálico

### Acentos Braun
- **Toasted Almond** `#E88745` - Laranja terroso (primário)
  - Hover: `#d67435` - Mais escuro
- **Dusty Olive** `#6A7E64` - Verde oliva militar (success)
  - Light: `#89a584` - Mais claro
- **Error Red** `#d9534f` - Vermelho terroso
- **Warning Amber** `#e8a75e` - Âmbar suave

### Cinzas (escala completa)
```css
--color-gunmetal: #414141     /* Texto */
--color-soft-linen: #E6E2D8   /* Background */
--color-alabaster: #E1E0DE    /* Bordas */
--color-gray-700: #5a5a5a
--color-gray-600: #787878
--color-gray-500: #9a9a9a
--color-gray-400: #b8b8b8
--color-gray-300: #d4d4d4
--color-white: #fafaf8        /* Off-white */
```

## Sombras (quentes e sutis)

```css
--shadow-inset: inset 0 1px 3px rgba(65, 65, 65, 0.08)
--shadow-sm: 0 1px 2px rgba(65, 65, 65, 0.06)
--shadow-base: 0 1px 3px rgba(65, 65, 65, 0.10), 0 2px 6px rgba(65, 65, 65, 0.06)
--shadow-md: 0 2px 8px rgba(65, 65, 65, 0.10), 0 4px 12px rgba(65, 65, 65, 0.06)
--shadow-lg: 0 4px 16px rgba(65, 65, 65, 0.10), 0 8px 24px rgba(65, 65, 65, 0.06)
```
*Sombras com tom de gunmetal para harmonizar com a paleta terrosa.*

## Border Radius

```css
--border-radius-sm: 3px      /* Inputs e botões */
--border-radius-base: 6px    /* Padrão - cards */
--border-radius-lg: 12px     /* Cards grandes (não usado atualmente) */
--border-radius-full: 9999px /* Badges circulares */
```

## Estrutura de Arquivos

```
app/assets/stylesheets/
├── application.css          # Entry point (apenas imports)
├── dirams/
│   ├── variables.css       # Design tokens (139 linhas)
│   ├── reset.css           # Base semântica (212 linhas)
│   ├── layout.css          # Navegação e estrutura (54 linhas)
│   ├── components.css      # Botões, forms, tables (106 linhas)
│   └── utilities.css       # Apenas .sr-only (17 linhas)
└── pages/
    └── transactions.css    # Estilos específicos da página (407 linhas)
```

**Total: 935 linhas de CSS**

## Exemplo de Uso

### ✅ Correto (Semântico)
```html
<section class="summary">
  <article class="metric income">
    <label>Receitas</label>
    <data value="1500">R$ 1.500,00</data>
  </article>
</section>
```

### ❌ Evitar (Sopa de classes)
```html
<div class="grid grid-4 gap-4 mb-6">
  <div class="card bg-white p-5 rounded-lg shadow-base">
    <label class="text-xs text-muted uppercase">Receitas</label>
    <p class="text-xl font-bold text-success">R$ 1.500,00</p>
  </div>
</div>
```

## Componentes

### Botões

**Primário (Toasted Almond)**
- Background: `#E88745`
- Hover: `#d67435`
- Text: `#fafaf8` (off-white)
- Shadow: `var(--shadow-base)`

**Secundário (Off-White)**
- Background: `#fafaf8`
- Hover: `#E6E2D8` (soft linen)
- Text: `#414141` (gunmetal)
- Shadow: `var(--shadow-base)`

### Badges

**Circulares com paleta Braun:**
- Income: `#6A7E64` (dusty olive) com background `rgba(106, 126, 100, 0.12)`
- Expense: `#d9534f` (red) com background `rgba(217, 83, 79, 0.12)`
- Transfer: `#e8a75e` (amber) com background `rgba(232, 167, 94, 0.12)`

### Cards

- Background: `#fafaf8` (off-white)
- Border: none
- Border-radius: `6px`
- Shadow: `var(--shadow-base)`

## Referências Visuais

### Braun Vintage Aesthetic
Design terroso e atemporal inspirado nos produtos Braun dos anos 60-80:
- Cores quentes e naturais
- Laranja terroso como ponto de atenção
- Verde oliva militar característico
- Texturas suaves e elegantes

### Paleta Autêntica
- **Toasted Almond**: Laranja Braun clássico
- **Soft Linen**: Background bege quente
- **Dusty Olive**: Verde militar icônico
- **Alabaster Grey**: Cinza alabastro para elementos secundários
- **Gunmetal**: Cinza metálico para texto

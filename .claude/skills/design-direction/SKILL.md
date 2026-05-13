---
name: design-direction
description: "Framework untuk generate design decisions — anti-slop checklist dan reference methodology"
---

# Design Direction Skill

## PURPOSE
Framework untuk design-director agent dalam menghasilkan keputusan desain yang intentional, bukan generic AI slop.

## ANTI-SLOP CHECKLIST
Sebelum finalize design-direction.md, verifikasi:

### Fonts
- [ ] BUKAN Inter, Roboto, Arial, Poppins, system-ui (kecuali justified)
- [ ] Font dipilih berdasarkan brand personality, bukan "yang paling umum"
- [ ] Fallback font stack yang proper
- [ ] Font loading strategy (swap, optional, block)

### Colors
- [ ] BUKAN generic blue/purple gradient
- [ ] Palette derived from brand/domain, bukan random
- [ ] Contrast ratio WCAG AA (4.5:1 body text, 3:1 large text)
- [ ] Dark mode consideration
- [ ] Semantic colors (success, warning, error) yang BUKAN default Bootstrap

### Patterns
- [ ] BUKAN cookie-cutter hero section
- [ ] BUKAN floating cards tanpa hierarchy
- [ ] BUKAN glassmorphism tanpa design system
- [ ] Spacing berdasarkan system (4px/8px grid), bukan random
- [ ] Border-radius konsisten dan intentional

## REFERENCE HARVEST METHODOLOGY
1. Identifikasi 3-5 reference sites dari domain yang sama
2. Screenshot key pages
3. Extract: color usage, typography, spacing, component patterns
4. Identify differentiators — apa yang BEDA dari generic template
5. Document: "inspired by X, but our take is Y because Z"

## DESIGN TOKENS FORMAT
```css
:root {
  /* Colors */
  --color-primary: #HEXVAL;
  --color-secondary: #HEXVAL;
  --color-accent: #HEXVAL;
  
  /* Typography */
  --font-heading: 'FontName', fallback;
  --font-body: 'FontName', fallback;
  --font-mono: 'FontName', monospace;
  
  /* Spacing */
  --space-unit: 4px;
  --space-xs: calc(var(--space-unit) * 1);
  --space-sm: calc(var(--space-unit) * 2);
  --space-md: calc(var(--space-unit) * 4);
  --space-lg: calc(var(--space-unit) * 8);
  --space-xl: calc(var(--space-unit) * 16);
  
  /* Radius */
  --radius-sm: 4px;
  --radius-md: 8px;
  --radius-lg: 12px;
}
```

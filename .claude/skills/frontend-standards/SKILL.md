---
name: frontend-standards
description: >
  Unified frontend design guide — combines design philosophy (WHY) and craft execution (HOW).
  Covers: 4 Apple-style principles, clarification protocol, Golden Test, typography, color system,
  motion, spatial composition, backgrounds, and anti-AI-slop checklist.
  Loaded by fe-developer before implementation, validated by qa-tester after.
---

# Frontend Standards — Design Philosophy + Craft Execution

> This is the single source of truth for all frontend design decisions.
> WHY = principles, process, Golden Test | HOW = typography, color, motion, composition

---

## A. CORE PRINCIPLES (Apple Design)

### 1. Clarity — UI must be instantly understood
- Clear visual hierarchy: most important element is most prominent
- Simple labels: fewest words, clearest meaning
- One page = one primary task, max 1-2 main CTAs

### 2. Deference — UI doesn't dominate content
- Whitespace is a feature, not emptiness
- Neutral colors as base; strong colors only for key actions
- Minimal shadows and borders

### 3. Depth — Structure and relationships are clear
- Visual grouping of related elements
- Consistent spacing creates visual rhythm
- Consistent grid system across pages

### 4. Simplicity — Remove everything unnecessary
- If an element doesn't help the user → remove it
- If it can be 1 click → don't make it 3
- If it can be 3 words → don't make it 10

---

## B. CLARIFICATION PROTOCOL — Before Any Implementation

### Step 1 — Check existing decisions
```bash
cat docs/design-decisions.md 2>/dev/null && echo "EXISTS" || echo "NOT_FOUND"
```

**If EXISTS:** Read file, use those decisions. Don't re-ask unless gaps exist.
**If NOT_FOUND:** Continue to Step 2.

### Step 2 — Ask user (one batch, not one-by-one)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DESIGN CLARIFICATION — before implementation starts
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Color mode     → Light / Dark / Both?           Default: Light
2. Brand color    → Hex code or brand name?        Default: #2563EB
3. Layout density → Compact or Spacious?           Default: Spacious
4. Target device  → Mobile-first / Desktop-first?  Default: Desktop-first
5. Design system  → Existing CSS/component lib?    Default: None
6. Visual tone    → Formal / Friendly / Minimal?   Default: Minimal & clean
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**STOP — Wait for user response.**

### Step 3 — Save to `docs/design-decisions.md`

Save decisions in table format. Then proceed to implementation.

---

## C. DESIGN THINKING — Before Writing Code

Commit to a **BOLD** aesthetic direction and execute with precision. Don't default to safe. Extraordinary work comes from specific, intentional choices — not generic best practices.

Answer four questions:
1. **Purpose** — What is this page's primary goal? One sentence.
2. **Tone** — Pick a BOLD direction: brutally minimal, maximalist chaos, retro-futuristic, organic/natural, luxury/refined, playful/toy-like, editorial/magazine, brutalist/raw, art deco/geometric, soft/pastel, industrial/utilitarian — or define your own. These are starting points, not limits.
3. **Constraints** — Technical, brand, or time limits?
4. **Differentiation** — What's the ONE thing someone will remember about this interface?

Commit to one aesthetic direction **before** writing any code.

### Complexity-Vision Matching
Match implementation complexity to the aesthetic vision:
- **Maximalist** → elaborate code, extensive animations, layered effects, rich textures
- **Minimalist** → restraint, precision, careful spacing, subtle details
- **Elegance** = executing the chosen vision well, not always adding more

---

## D. TYPOGRAPHY

### Principles
- Choose fonts that are **distinctive and characterful** — not the safe default
- Ideal pairing: strong display font + refined readable body font
- Max 2 font families unless visually justified

### Avoid
- Inter, Roboto, Arial, system fonts — too generic
- Mixing >2 families without clear visual justification

### Baseline
| Element | Starting size |
|---------|--------------|
| Main heading | 32px |
| Secondary heading | 24px |
| Subheading | 18px |
| Body | 16px |
| Caption/label | 14px |

Deviation is fine with clear compositional justification.

---

## E. COLOR SYSTEM

### Principles
- Commit to **one cohesive palette** — don't mix aesthetic directions
- **Dominant color + sharp accent** always outperforms even-distributed palettes
- Colors must support the chosen tone, not just "look good"

### Avoid
- Purple gradient on white background — overused
- Color schemes that work on any project without feeling wrong
- Colors chosen because "standard" instead of supporting the tone

### Categories
| Category | Function |
|----------|----------|
| Primary | Main actions, CTAs, most important elements |
| Neutral | Text, backgrounds, structural elements |
| Semantic | Success, error, warning (only when needed) |

Decorative colors allowed if they support the chosen aesthetic.

---

## F. MOTION & MICRO-INTERACTIONS

### Principles
- Motion reinforces hierarchy and focus, not decoration
- **High-impact**: staggered page-load reveals > scattered micro-interactions everywhere
- Every animation must have a one-sentence purpose

### Implementation
- HTML/CSS: Prefer CSS-only transitions and animations
- React: Use Motion library (Framer Motion) for complex orchestration
- Use `animation-delay` for natural visual rhythm
- Memorable scroll-triggering and hover states

### Avoid
- Animating every element without hierarchy → noise, not polish
- Duration <150ms (too fast) or >600ms (too slow) for UI transitions
- Animations that can't be disabled (respect `prefers-reduced-motion`)

---

## G. SPATIAL COMPOSITION

### Principles
- **Asymmetry, overlap, diagonal flow, grid-breaking** are valid techniques
- Choose: **generous negative space** OR **controlled density** — both valid, no position is not
- Commit to one approach

### Avoid
- Predictable: header, 3 cards, footer — no variation
- Same component patterns as thousands of other projects
- "Balanced" margins without compositional intent

### Techniques
- Overlapping elements for depth without excessive shadows
- Grid-breaking for hero or featured elements
- Diagonal or curves as compositional elements when fitting the tone

---

## H. BACKGROUNDS & VISUAL DEPTH

### Techniques Available
- **Gradient meshes** — multi-point, organic feel
- **Noise/grain overlay** — adds texture, avoids flat digital feel
- **Layered transparencies** — varied opacity for depth
- **Dramatic shadows** — compositionally meaningful, not generic drop-shadow

### Avoid
- Solid white/gray as default without consideration
- Overused gradients (purple-to-blue, pink-to-orange)

---

## I. ANTI-AI-SLOP CHECKLIST

Before marking UI as done:

- [ ] No two pages look identical in this project
- [ ] Font is not Inter, Roboto, or system font
- [ ] Color palette can't be used on another project without feeling wrong
- [ ] Layout doesn't use "3 equal cards in a row" without variation
- [ ] Background is not solid white/gray without justification
- [ ] At least one motion or depth element feels intentional
- [ ] This design does NOT converge on the same choices as previous generations
- [ ] Font choices, theme, and layout differ from the last component built

> "Does this feel *genuinely designed* for this specific context,
> or could it be copy-pasted to any project?"
>
> If the latter → return to Section C and commit to a more specific direction.

### Variation Mandate
Every generation must differ. Vary between light/dark themes, different font pairings, different aesthetic directions. NEVER converge on the same common choices (e.g., Space Grotesk, blue-purple gradients) across multiple builds.

---

## J. GOLDEN TEST — Final Validation

Before UI is considered done, answer honestly:

```
GOLDEN TEST
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Does the user understand this page in 3 seconds?
   → YES / NO

2. Can this page be made even simpler?
   → NO / YES (if YES — simplify first)

3. Does every visual element have a clear purpose?
   → YES / NO (if NO — remove purposeless elements)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Only if all answers pass → UI is done.**
If question 2 or 3 fails → fix before commit.

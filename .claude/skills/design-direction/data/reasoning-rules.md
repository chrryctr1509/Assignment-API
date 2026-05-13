# Design Reasoning Rules
# Conditional logic for industry-specific and page-type-specific design decisions.
# Format: IF [condition] THEN [directive] BECAUSE [rationale]
# Grep-friendly: each rule is a self-contained block.

---

## Rule: fintech-color-temperature
IF industry = fintech
THEN use cool colors (blue, teal, navy) as primary; warm accents only for CTAs
BECAUSE financial users associate cool tones with trust, stability, and professionalism
EXAMPLE: Primary #1A56DB (trust blue), accent #F59E0B (amber for action buttons only)

## Rule: fintech-data-density
IF industry = fintech AND page_type = dashboard
THEN use glassmorphism or dashboard-dense style with high information density
BECAUSE financial users need data at a glance; sparse layouts waste screen real estate
EXAMPLE: 13-14px body text, compact card padding (12-16px), monospace for numbers

## Rule: healthcare-accessibility
IF industry = healthcare
THEN enforce WCAG AAA compliance, ban neon colors and heavy animations
BECAUSE patients may have visual impairments, anxiety, or cognitive load; accessibility is legally required
EXAMPLE: Contrast ratio 7:1 minimum, prefers-reduced-motion respected, clear large text

## Rule: healthcare-trust-colors
IF industry = healthcare
THEN use teal/blue primary with white/light backgrounds, green for positive indicators
BECAUSE clinical environments use these colors; patients associate them with cleanliness and care
EXAMPLE: Primary #047481, background #FFFFFF, success #0E9F6E

## Rule: education-readability
IF industry = education AND target_audience = children
THEN use large fonts (18px+ body), rounded shapes, playful but not chaotic colors
BECAUSE children need larger text and visual anchors; too much stimulation reduces focus
EXAMPLE: Font Nunito/Manrope, border-radius 16px+, max 3 primary colors

## Rule: education-engagement
IF industry = education AND page_type = dashboard
THEN include progress indicators, achievement badges, streak counters
BECAUSE gamification drives learning engagement; visible progress motivates continuation
EXAMPLE: Progress bars, level indicators, celebration micro-animations (150ms)

## Rule: saas-onboarding
IF industry = saas AND page_type = onboarding
THEN maximum 5 steps, show progress bar, allow skip, remember state
BECAUSE SaaS churn is highest during onboarding; every extra step loses users
EXAMPLE: Step 1-5 wizard, skip button, progress saved to localStorage

## Rule: saas-dashboard-hierarchy
IF industry = saas AND page_type = dashboard
THEN primary metrics as large cards (top), secondary as charts (middle), details as table (bottom)
BECAUSE users scan top-to-bottom; most important data should be visible without scrolling
EXAMPLE: 3-4 KPI cards → 2-col chart grid → sortable data table

## Rule: ecommerce-urgency
IF industry = ecommerce AND page_type = landing
THEN use warm accent colors (amber, orange) for CTAs, add subtle urgency cues
BECAUSE warm colors trigger action; urgency (limited stock, countdown) increases conversion
EXAMPLE: CTA button #F59E0B, "Only 3 left" badge, countdown timer for promotions

## Rule: ecommerce-trust-checkout
IF industry = ecommerce AND page_type = checkout
THEN minimize distractions, show trust badges, use clean minimalism style
BECAUSE cart abandonment peaks at checkout; every distraction is a lost sale
EXAMPLE: Remove nav, show SSL badge, payment icons, money-back guarantee, clean white background

## Rule: internal-tool-efficiency
IF industry = internal-tool
THEN prioritize keyboard shortcuts, dense layouts, minimal decorative elements
BECAUSE internal users are power users who value speed over aesthetics
EXAMPLE: Cmd+K search, compact spacing (4-8px gaps), no hero images, tabular data default

## Rule: internal-tool-color
IF industry = internal-tool
THEN use neutral gray palette with single blue accent for interactive elements
BECAUSE tools should not fatigue eyes during 8+ hour usage; color should signal interactivity only
EXAMPLE: Gray #374151 base, blue #3B82F6 for links/buttons only, no decorative gradients

## Rule: creative-expression
IF industry = creative
THEN allow bold typography, experimental layouts, more saturated colors
BECAUSE creative brands need to signal creativity; safe/corporate design undermines the brand
EXAMPLE: Clash Display headings, bento grid layout, saturated accent colors, asymmetric composition

## Rule: gaming-dark-first
IF industry = gaming
THEN default to dark mode with high-saturation accent colors, allow motion
BECAUSE gamers expect immersive dark interfaces; bright interfaces feel out of context
EXAMPLE: Background #0F172A, neon accents #06FFA5 or #A855F7, animation timing 200-600ms

## Rule: gaming-no-motion-medical
IF industry = healthcare OR industry = government
THEN animation timing max 300ms, no parallax, no auto-playing video
BECAUSE these audiences may have vestibular disorders or cognitive load; motion must be optional
EXAMPLE: Transition 150-300ms ease-out only, respect prefers-reduced-motion

## Rule: government-accessibility
IF industry = government
THEN WCAG AA minimum (AAA preferred), high-contrast mode, simple navigation
BECAUSE government sites serve all citizens including elderly and disabled; legal compliance required
EXAMPLE: Public Sans font, 16px+ body, skip nav, focus rings 3-4px, contrast 4.5:1+

## Rule: nonprofit-warmth
IF industry = nonprofit
THEN use warm blues with amber accents, approachable typography, real photography
BECAUSE nonprofits need to build trust AND emotional connection; stock photos undermine authenticity
EXAMPLE: Blue #1D4ED8 trust, amber #F59E0B hope, serif headings for gravitas, real donor photos

## Rule: food-appetite
IF industry = food
THEN use warm colors (red, orange, amber), organic shapes, appetizing photography
BECAUSE warm colors stimulate appetite; cold blues suppress it in food context
EXAMPLE: Red #DC2626 primary, amber #F59E0B accents, rounded cards, full-bleed food photography

## Rule: travel-aspiration
IF industry = travel
THEN use full-bleed hero imagery, vibrant accent colors, immersive layouts
BECAUSE travel purchase is aspirational; large beautiful imagery drives desire and conversion
EXAMPLE: Hero image 100vh, blue #0369A1 (sky/ocean), amber #F59E0B (sunshine), parallax subtle

## Rule: real-estate-premium
IF industry = real-estate
THEN use dark/neutral base with gold accents, large property imagery, clean typography
BECAUSE real estate buyers associate dark+gold with premium/luxury; property images are the product
EXAMPLE: Dark #1F2937, gold #D97706, Instrument Serif headings, full-width property galleries

## Rule: mobile-thumb-zone
IF platform = mobile
THEN place primary actions in bottom 1/3 of screen (thumb zone)
BECAUSE 75% of mobile users operate with one thumb; top actions require hand repositioning
EXAMPLE: Bottom nav bar, FAB in bottom-right, swipe gestures for common actions

## Rule: form-single-column
IF page_type = form
THEN use single-column layout, max-width 600px, group related fields
BECAUSE multi-column forms have 30% higher error rate; single column is faster to complete
EXAMPLE: Fieldsets with legends, 16px gap between fields, inline validation, sticky submit

## Rule: auth-simplicity
IF page_type = auth
THEN maximum 3 form fields visible at once, social login prominent, brand panel optional
BECAUSE every extra field reduces signup conversion by 10-15%
EXAMPLE: Email + password + submit. Social login above form. "Sign up" as secondary link.

## Rule: error-page-recovery
IF page_type = error
THEN always provide navigation back (home button) and context about what happened
BECAUSE dead-end error pages cause users to leave; recovery path retains them
EXAMPLE: Friendly illustration, clear error message, "Go Home" button, support contact link

## Rule: dark-mode-contrast
IF style = dark-mode
THEN reduce white text to #E2E8F0 (not pure white), use dark gray #0F172A (not pure black)
BECAUSE pure white on pure black causes eye strain (halation effect); slight reduction is gentler
EXAMPLE: Background slate-900 #0F172A, text slate-200 #E2E8F0, borders slate-700 #334155

## Rule: animation-budget
IF page has more than 2 animated elements
THEN reduce to max 2 key animations, make others instant transitions
BECAUSE multiple competing animations create cognitive overload and feel unprofessional
EXAMPLE: Hero fade-in + one scroll-triggered chart animation. Everything else: transition 0ms or 150ms.

## Rule: table-mobile
IF page_type = list-table AND platform = mobile
THEN transform table to card layout or use horizontal scroll container
BECAUSE tables wider than viewport are unusable; card transformation maintains data hierarchy
EXAMPLE: Each row becomes a card with label:value pairs stacked vertically

## Rule: loading-skeleton
IF any page has async data loading
THEN show skeleton screens (not spinners) that match the eventual layout
BECAUSE skeletons reduce perceived loading time by 30% vs spinners; layout doesn't shift when data arrives
EXAMPLE: Gray animated placeholder boxes matching card/text dimensions

## Rule: cta-hierarchy
IF page has multiple CTAs
THEN exactly 1 primary CTA (filled, accent color), others are secondary (outlined or text)
BECAUSE multiple equal-weight CTAs create decision paralysis; clear hierarchy guides action
EXAMPLE: "Get Started" filled button, "Learn More" text link, "Contact Sales" outlined button

## Rule: typography-enterprise
IF industry = fintech OR industry = government OR industry = enterprise
THEN use conservative, high-readability fonts; no decorative or display fonts for body text
BECAUSE professional context demands readability and trust; playful fonts undermine authority
EXAMPLE: Space Grotesk headings, Work Sans body, JetBrains Mono for data/code

## Rule: typography-consumer
IF industry = lifestyle OR industry = food OR industry = travel
THEN allow expressive heading fonts with readable body; warmth over sterility
BECAUSE consumer brands need personality; purely functional typography feels cold
EXAMPLE: Fraunces serif headings (warmth), Commissioner body (readability)

---
name: convention-research
description: "Panduan web search untuk riset official docs dan conventions per stack"
---

# Convention Research Skill

## PURPOSE
Panduan untuk convention-scout agent dalam melakukan web search yang efektif untuk menemukan latest conventions, breaking changes, dan deprecated patterns.

## QUERY TEMPLATES

### Laravel/PHP
- `"Laravel {version} upgrade guide" site:laravel.com`
- `"Laravel {version} migration guide" site:laravel.com`
- `"Laravel deprecated" {year} changelog`
- `"PHP {version} breaking changes" site:php.net`

### React/Next.js
- `"React {version} changelog" site:react.dev`
- `"Next.js {version} migration" site:nextjs.org`
- `"React deprecated API" {year}`
- `"Next.js breaking changes" {version}`

### Node.js/Express
- `"Node.js {version} changelog" site:nodejs.org`
- `"Express {version} migration guide"`
- `"Node.js deprecated" {version}`

### Python/FastAPI
- `"Python {version} what's new" site:docs.python.org`
- `"FastAPI changelog" {version}`
- `"Python deprecated" {version}`

### Database
- `"MySQL {version} upgrade" site:dev.mysql.com`
- `"PostgreSQL {version} release notes" site:postgresql.org`

### Docker
- `"Docker compose v2 migration" site:docs.docker.com`
- `"Docker deprecated features" {year}`

## OUTPUT FORMAT
```
## [Stack] — v[current] → v[latest]

### Breaking Changes
- [API/function]: [apa yang berubah] | Source: [URL]

### Deprecated
- [API/pattern]: sejak v[X], gunakan [replacement] | Source: [URL]

### New Recommended Patterns
- [pattern]: [kapan pakai] | Source: [URL]
```

## RULES
- SELALU verifikasi version number dari official source
- JANGAN fabricate breaking changes
- Prioritaskan official docs > blog posts > Stack Overflow
- Include URL source untuk setiap item
- Focus pada DELTA saja — bukan full convention guide

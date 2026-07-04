# Design — NotchBar landing page (bilingual FR/EN)

**Date:** 2026-07-04
**Status:** Approved
**Scope:** A public landing page for NotchBar, hosted on GitHub Pages, that presents the app with a witty student-facing tone and drives downloads. Second step of the distribution roadmap (after the v0.1.0 Release).

## Goal

A single, self-explanatory page a bored student can land on and, within seconds, understand what NotchBar is and download it. Witty, clean, durable — no build step, no rotting links, no drift between languages.

## Constraints & context

- **Static only.** Plain HTML/CSS/JS, no framework, no build tooling — matches the project's zero-dependency spirit and keeps GitHub Pages trivial.
- **Hosting:** GitHub Pages serving from `/docs` on `main`. A push to `main` deploys.
- **Tone:** witty & casual, aimed at students ("are we done yet?"). Credible but with attitude.
- **Bilingual FR/EN done properly** — no duplicated pages that drift (see i18n below).
- Default page URL will be `https://periicles.github.io/Notchapp/`; structure must make adding a custom-domain `CNAME` trivial later.
- Reuses existing brand assets: the Nightfall icon (`Supporting/Icon/NotchBar.svg`) and the notch mockup (from the approved hero concept B).
- Repo: `https://github.com/Periicles/Notchapp`. Releases page: `https://github.com/Periicles/Notchapp/releases`.

## Non-goals (YAGNI)

- Custom domain, analytics, video/animated screencasts, more than two languages, a CMS.
- A LICENSE file (see Tech debt) — the page will not claim a specific OSS license.

## i18n approach (the "done properly" part)

- **One HTML file, structure written once.** Translatable text nodes carry a `data-i18n="key"` attribute; the element's default (in-markup) text is **English**, so the page is fully readable if JS never runs (graceful degradation).
- **One dictionary** in `main.js`: a single object `{ key: { en: "...", fr: "..." } }` where both languages live side by side. Editing a string touches both languages in one place → no drift.
- **Language resolution order on load:** `?lang=` query param → `localStorage.lang` → `navigator.language` (`fr*` → French, else English) → English default.
- **Toggle** (FR / EN) in the header: swaps all `data-i18n` nodes, updates `document.documentElement.lang`, persists to `localStorage`, and updates the `?lang=` param (via `history.replaceState`) so the current view is shareable.
- Attributes that need translating (e.g. `<meta>` description, `aria-label`, `alt`) use `data-i18n-attr="attr:key"` handled by the same swap function.

## File structure

```
docs/
  index.html          # structure + semantic markup, data-i18n keys, links style.css + main.js
  style.css           # all styles (brand tokens, notch mockup, layout, responsive)
  main.js             # i18n dictionary + language resolution/toggle logic
  assets/
    favicon.png       # 512px, generated from NotchBar.svg
    og-image.svg      # 1200×630 social card source (notch mockup + wordmark + tagline)
    og-image.png      # rendered from og-image.svg, referenced by OG/Twitter meta
```

- **`.gitignore` cleanup:** the blanket `docs/*` ignore (a template leftover for generated API docs that don't exist) plus its `!docs/superpowers/` exception are removed, so `docs/` is tracked normally. This un-fights the ignore that already needed one exception and cleanly tracks both the specs and the site.

## Page structure (single scroll)

Order: **Hero → What it does → Install → Footer.** Header holds the wordmark and the FR/EN toggle.

### 1. Hero — "are we done yet?"
Concept B (approved): light ground, massive typographic headline, supporting notch mockup showing a live event (lecture, 68%, 23 min left). Download button + a requirements meta line.

### 2. What it does — three points
Short, witty, each with a one-liner. Optionally shows the notch in the in-progress and collapsed states.

### 3. Install — three steps + the honest note
Download → drag to Applications → right-click → Open. Plus the plain-language "why the extra click" note (app not notarized yet).

### 4. Footer
Link to the GitHub repo, author credit, requirements restated. Says "free · source on GitHub" — **not** "open source" (no LICENSE yet).

## Copy (EN default / FR)

| Key | English | Français |
|---|---|---|
| `hero.title` | are we done yet? | c'est bientôt fini ? |
| `hero.sub` | Your notch answers that now. Live event progress, right where you're already staring. | Ton notch répond à la question. La progression de ton cours, là où tu regardes déjà. |
| `cta.download` | Download for Mac | Télécharger pour Mac |
| `meta.reqs` | macOS 14+ · Apple Silicon · free | macOS 14+ · Apple Silicon · gratuit |
| `mock.title` | Organic Chemistry | Chimie organique |
| `mock.left` | {b}23 min{/b} left | {b}23 min{/b} restantes |
| `feat.heading` | What it does | Ce que ça fait |
| `feat.1.t` | Live progress | En direct |
| `feat.1.d` | See how far along your current event is, at a glance. | Vois d'un coup d'œil où en est ton cours. |
| `feat.2.t` | Invisible at rest | Invisible au repos |
| `feat.2.d` | The notch stays black until you hover. No clutter, no menu-bar icon. | Le notch reste noir tant que tu ne survoles pas. Zéro encombrement. |
| `feat.3.t` | Barely there | Quasi rien |
| `feat.3.d` | ~0% CPU while collapsed. Your battery won't notice it's running. | ~0% CPU replié. Ta batterie ne le sentira même pas. |
| `install.heading` | Install | Installation |
| `install.1` | Download NotchBar.dmg and open it. | Télécharge NotchBar.dmg et ouvre-le. |
| `install.2` | Drag NotchBar into your Applications folder. | Glisse NotchBar dans ton dossier Applications. |
| `install.3` | Right-click NotchBar → Open, then confirm Open. | Clic droit sur NotchBar → Ouvrir, puis confirme. |
| `install.note` | The right-click is a one-time step while NotchBar isn't notarized by Apple yet. After that, it opens normally. | Le clic droit est une étape unique tant que NotchBar n'est pas encore notariée par Apple. Ensuite, elle s'ouvre normalement. |
| `footer.source` | Source on GitHub | Code sur GitHub |
| `footer.made` | Made by Periicles | Fait par Periicles |
| `og.desc` | Turn your MacBook's notch into a live countdown for whatever you're stuck in. | Transforme le notch de ton MacBook en compte à rebours pour ce qui t'ennuie. |

The `{b}…{/b}` markers denote a `<b>` span that stays green; the swap function renders them as inline markup, not literal text.

## Download link (durability)

- The button points to the **Releases page**: `https://github.com/Periicles/Notchapp/releases`. Always valid, never rots (GitHub's `/releases/latest` excludes pre-releases, so it can't be used until a stable release exists).
- The URL is defined **once** (a single constant in `main.js`, or one `href` in the markup — not repeated in copy). When a stable release is cut, switching to `/releases/latest/download/NotchBar.dmg` is a one-line change.

## Social / meta

- `<title>`, `<meta name="description">` (translatable), and Open Graph + Twitter Card tags: `og:title` "NotchBar — are we done yet?", `og:description` = `og.desc`, `og:image` = `assets/og-image.png` (absolute URL), `og:type` website, `twitter:card` summary_large_image.
- `og-image.png` (1200×630) is rendered from `og-image.svg` via `rsvg-convert` and committed. Favicon likewise from `NotchBar.svg`.
- OG text is English (single canonical card).

## Accessibility & responsive

- Semantic landmarks (`header`, `main`, `section`, `footer`), one `h1` (the hero), logical heading order.
- Keyboard-operable download button and language toggle with visible `:focus-visible` states.
- Responsive: single-column below ~720px; no horizontal body scroll; fluid type via `clamp()`.
- `prefers-reduced-motion`: the progress-bar fill animation is disabled.

## Acceptance criteria

Verified before done:

1. `docs/index.html` opens locally and renders the full page (hero → features → install → footer).
2. Language toggle swaps **all** text FR↔EN and updates `<html lang>`; `?lang=fr` loads French directly; choice persists across reload (localStorage).
3. With JS disabled, the page still renders in English.
4. Download button links to the Releases page and opens it.
5. OG/Twitter meta present; `og-image.png` exists at 1200×630; favicon renders in the tab.
6. Layout has no horizontal scroll at 375px width; toggle and button are keyboard-focusable with a visible focus ring.
7. `.gitignore` no longer blanket-ignores `docs/`; the site files are tracked.

No automated tests (static page); acceptance is behavioral, verified in a browser.

## Tech debt flagged (out of scope)

- **No LICENSE file.** Without one the code isn't formally open-source; the footer deliberately avoids the term. Adding an OSS license (e.g. MIT) is a small separate task worth doing before promoting the repo widely.

## Future hooks

- **Stable release:** switch the download href to `/releases/latest/download/NotchBar.dmg`.
- **Custom domain:** add `docs/CNAME` with the domain and configure DNS.
- **Notarization:** once done, soften/remove the install "extra click" note.

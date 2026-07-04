# NotchBar Landing Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a bilingual (FR/EN) static landing page for NotchBar under `docs/`, served by GitHub Pages, that presents the app and drives downloads.

**Architecture:** Plain static site — `docs/index.html` (semantic structure, English text in-markup with `data-i18n` keys), `docs/style.css` (all styling incl. the notch mockup), `docs/main.js` (one dictionary holding EN+FR, plus language resolution/toggle). No build step. Assets (favicon, OG image) are rendered from SVG with `rsvg-convert` and committed.

**Tech Stack:** HTML5, CSS3, vanilla JS (no framework), `rsvg-convert` (librsvg) for asset generation, GitHub Pages.

## Global Constraints

- Static only — no framework, no build tooling.
- Hosting: GitHub Pages from `/docs` on `main`.
- Language default in markup is **English**; page must be fully readable with JS disabled.
- One dictionary in `main.js`, EN+FR co-located — no duplicated pages.
- Download button href is the Releases page verbatim: `https://github.com/Periicles/Notchapp/releases` (never rots; `/releases/latest` can't be used while only a pre-release exists). Present as a real `<a href>` so it works without JS.
- Repo URL: `https://github.com/Periicles/Notchapp`. Pages base URL: `https://periicles.github.io/Notchapp/`.
- Footer says "Source on GitHub" / "free" — never "open source" (no LICENSE yet).
- Accessible (focus-visible, semantic landmarks, one `h1`), responsive (single column ≤720px, no horizontal scroll), `prefers-reduced-motion` disables the fill animation.
- Spec: `docs/superpowers/specs/2026-07-04-landing-page-design.md`.

---

### Task 1: Repo prep & image assets

**Files:**
- Modify: `.gitignore`
- Create: `docs/assets/og-image.svg`
- Create (generated, committed): `docs/assets/favicon.png`, `docs/assets/og-image.png`

**Interfaces:**
- Produces: `docs/assets/favicon.png` (512×512) and `docs/assets/og-image.png` (1200×630), referenced by `index.html` in Task 2.

- [ ] **Step 1: Stop blanket-ignoring `docs/`**

In `.gitignore`, replace these three lines:
```
docs/*
# ...but keep hand-written specs/design docs.
!docs/superpowers/
```
with:
```
# (docs/ is tracked: it holds specs, plans, and the GitHub Pages site)
```
Leave the `dist/` block below it untouched.

- [ ] **Step 2: Verify docs/ is now tracked**

Run: `git check-ignore docs/index.html; echo "exit $?"`
Expected: `exit 1` (not ignored).

- [ ] **Step 3: Generate the favicon from the app icon**

Run:
```bash
mkdir -p docs/assets
rsvg-convert -w 512 -h 512 Supporting/Icon/NotchBar.svg -o docs/assets/favicon.png
file docs/assets/favicon.png
```
Expected: `PNG image data, 512 x 512`.

- [ ] **Step 4: Create the OG card source SVG**

Create `docs/assets/og-image.svg` with exactly this content:

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#0e1018"/><stop offset="1" stop-color="#05060a"/>
    </linearGradient>
    <linearGradient id="fill" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#37D67A"/><stop offset="1" stop-color="#59E8A0"/>
    </linearGradient>
  </defs>
  <rect width="1200" height="630" fill="url(#bg)"/>
  <g transform="translate(600,140)">
    <rect x="-200" y="-44" width="400" height="150" rx="26" fill="#000000"/>
    <text x="-160" y="-2" fill="#F4F6F8" font-family="sans-serif" font-size="27" font-weight="600">Organic Chemistry</text>
    <text x="160" y="-2" text-anchor="end" fill="#59E8A0" font-family="sans-serif" font-size="25" font-weight="700">23 min</text>
    <rect x="-160" y="26" width="320" height="16" rx="8" fill="#23262F"/>
    <rect x="-160" y="26" width="218" height="16" rx="8" fill="url(#fill)"/>
  </g>
  <text x="600" y="390" text-anchor="middle" fill="#FFFFFF" font-family="sans-serif" font-size="88" font-weight="800" letter-spacing="-3">are we done yet?</text>
  <text x="600" y="452" text-anchor="middle" fill="#9BA2B0" font-family="sans-serif" font-size="30">Your notch, but useful.</text>
  <text x="600" y="566" text-anchor="middle" fill="#C7CCD6" font-family="sans-serif" font-size="26" font-weight="700">NotchBar</text>
</svg>
```

- [ ] **Step 5: Render the OG PNG**

Run:
```bash
rsvg-convert -w 1200 -h 630 docs/assets/og-image.svg -o docs/assets/og-image.png
file docs/assets/og-image.png
```
Expected: `PNG image data, 1200 x 630`.

- [ ] **Step 6: Commit**

```bash
git add .gitignore docs/assets/og-image.svg docs/assets/favicon.png docs/assets/og-image.png
git commit -m "chore(landing): track docs/, add favicon and OG image"
```

---

### Task 2: Page structure & styling (English default)

**Files:**
- Create: `docs/index.html`
- Create: `docs/style.css`

**Interfaces:**
- Consumes: `docs/assets/favicon.png`, `docs/assets/og-image.png` (Task 1).
- Produces: DOM with `data-i18n`, `data-i18n-html`, and `data-i18n-attr` hooks and `.lang-btn[data-lang]` buttons, consumed by `main.js` (Task 3). The page is complete and correct in English without JS.

- [ ] **Step 1: Create `docs/index.html`**

Create `docs/index.html` with exactly this content:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>NotchBar — are we done yet?</title>
  <meta name="description" data-i18n-attr="content:og.desc"
        content="Turn your MacBook's notch into a live countdown for whatever you're stuck in.">
  <link rel="icon" type="image/png" href="assets/favicon.png">
  <meta property="og:type" content="website">
  <meta property="og:title" content="NotchBar — are we done yet?">
  <meta property="og:description" content="Turn your MacBook's notch into a live countdown for whatever you're stuck in.">
  <meta property="og:image" content="https://periicles.github.io/Notchapp/assets/og-image.png">
  <meta property="og:url" content="https://periicles.github.io/Notchapp/">
  <meta name="twitter:card" content="summary_large_image">
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <header class="site">
    <a class="wordmark" href="./">NotchBar</a>
    <div class="lang" role="group" aria-label="Language">
      <button type="button" class="lang-btn" data-lang="en" aria-pressed="true">EN</button>
      <button type="button" class="lang-btn" data-lang="fr" aria-pressed="false">FR</button>
    </div>
  </header>

  <main>
    <section class="hero">
      <div class="hero-copy">
        <h1 data-i18n="hero.title">are we done yet?</h1>
        <p class="sub" data-i18n="hero.sub">Your notch answers that now. Live event progress, right where you're already staring.</p>
        <a class="btn" href="https://github.com/Periicles/Notchapp/releases" data-i18n="cta.download">Download for Mac</a>
        <p class="meta" data-i18n="meta.reqs">macOS 14+ · Apple Silicon · free</p>
      </div>
      <div class="hero-stage">
        <div class="desktop">
          <div class="menubar"><span class="clock">10:27</span><span class="mi"></span></div>
          <div class="notchwrap">
            <div class="nb">
              <div class="nb-row1">
                <span class="nb-title" data-i18n="mock.title">Organic Chemistry</span>
                <span class="nb-left" data-i18n-html="mock.left"><b>23 min</b> left</span>
              </div>
              <div class="nb-track"><div class="nb-fill"></div></div>
            </div>
          </div>
          <div class="desktop-pad"></div>
        </div>
      </div>
    </section>

    <section class="features">
      <h2 data-i18n="feat.heading">What it does</h2>
      <div class="cards">
        <article>
          <h3 data-i18n="feat.1.t">Live progress</h3>
          <p data-i18n="feat.1.d">See how far along your current event is, at a glance.</p>
        </article>
        <article>
          <h3 data-i18n="feat.2.t">Invisible at rest</h3>
          <p data-i18n="feat.2.d">The notch stays black until you hover. No clutter, no menu-bar icon.</p>
        </article>
        <article>
          <h3 data-i18n="feat.3.t">Barely there</h3>
          <p data-i18n="feat.3.d">~0% CPU while collapsed. Your battery won't notice it's running.</p>
        </article>
      </div>
    </section>

    <section class="install">
      <h2 data-i18n="install.heading">Install</h2>
      <ol>
        <li data-i18n="install.1">Download NotchBar.dmg and open it.</li>
        <li data-i18n="install.2">Drag NotchBar into your Applications folder.</li>
        <li data-i18n="install.3">Right-click NotchBar → Open, then confirm Open.</li>
      </ol>
      <p class="note" data-i18n="install.note">The right-click is a one-time step while NotchBar isn't notarized by Apple yet. After that, it opens normally.</p>
      <a class="btn" href="https://github.com/Periicles/Notchapp/releases" data-i18n="cta.download">Download for Mac</a>
    </section>
  </main>

  <footer class="site">
    <a href="https://github.com/Periicles/Notchapp" data-i18n="footer.source">Source on GitHub</a>
    <span data-i18n="footer.made">Made by Periicles</span>
    <span class="reqs" data-i18n="meta.reqs">macOS 14+ · Apple Silicon · free</span>
  </footer>

  <script src="main.js" defer></script>
</body>
</html>
```

- [ ] **Step 2: Create `docs/style.css`**

Create `docs/style.css` with exactly this content:

```css
:root{
  --ink:#12141A; --muted:#4A5160; --faint:#7A8291;
  --bg:#EEF0F2; --card:#FFFFFF; --hair:#E1E4EA;
  --brand:#37D67A; --brand-2:#59E8A0; --ink-accent:#0E9F58;
  --max:1080px;
}
*{box-sizing:border-box}
html{scroll-behavior:smooth}
body{margin:0;background:var(--bg);color:var(--ink);
  font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text","Segoe UI",Roboto,sans-serif;
  -webkit-font-smoothing:antialiased;line-height:1.55}
img{max-width:100%}

header.site,footer.site{max-width:var(--max);margin:0 auto;padding:22px 24px;
  display:flex;align-items:center;justify-content:space-between;gap:16px}
.wordmark{font-weight:800;letter-spacing:-.02em;text-decoration:none;font-size:16px;color:var(--ink)}
.lang{display:inline-flex;border:1px solid var(--hair);border-radius:999px;overflow:hidden;background:var(--card)}
.lang-btn{appearance:none;border:0;background:transparent;cursor:pointer;font:600 13px/1 inherit;color:var(--muted);padding:8px 14px}
.lang-btn[aria-pressed="true"]{background:var(--ink);color:#fff}
.lang-btn:focus-visible,.btn:focus-visible,a:focus-visible{outline:3px solid var(--brand);outline-offset:2px;border-radius:6px}

.btn{display:inline-flex;align-items:center;gap:9px;background:var(--ink);color:#fff;
  font-weight:700;font-size:15px;border-radius:12px;padding:14px 24px;text-decoration:none;
  box-shadow:0 10px 26px -10px rgba(0,0,0,.45)}
.btn::before{content:"↓";font-weight:800}
.meta{color:var(--faint);font-size:13px;margin:12px 0 0}

.hero{max-width:var(--max);margin:0 auto;padding:40px 24px 64px;
  display:grid;grid-template-columns:1.15fr .85fr;gap:40px;align-items:center}
.hero h1{font-size:clamp(44px,8vw,92px);font-weight:850;letter-spacing:-.045em;line-height:.9;margin:0 0 20px}
.hero .sub{color:var(--muted);font-size:17px;max-width:42ch;margin:0 0 24px}
.hero-stage{display:flex;align-items:center}

.desktop{position:relative;width:100%;border-radius:14px 14px 10px 10px;overflow:hidden;
  background:radial-gradient(120% 90% at 20% -10%,#1a2340 0,rgba(26,35,64,0) 55%),
            radial-gradient(120% 90% at 90% 10%,#13303a 0,rgba(19,48,58,0) 50%),
            linear-gradient(160deg,#0d0f16 0,#070810 100%);
  box-shadow:0 30px 60px -34px rgba(0,0,0,.6)}
.menubar{height:26px;display:flex;align-items:center;justify-content:flex-end;gap:12px;padding:0 14px;color:rgba(255,255,255,.5);font-size:11px}
.menubar .mi{width:12px;height:12px;border-radius:3px;background:rgba(255,255,255,.16)}
.clock{font-variant-numeric:tabular-nums}
.notchwrap{position:absolute;top:0;left:50%;transform:translateX(-50%)}
.nb{background:#000;border-radius:0 0 20px 20px;box-shadow:0 8px 30px rgba(0,0,0,.55);padding:12px 18px 14px;min-width:280px}
.nb-row1{display:flex;align-items:center;justify-content:space-between;gap:14px}
.nb-title{color:#F4F6F8;font-size:14px;font-weight:600}
.nb-left{color:#8B93A3;font-size:12.5px;font-weight:600;font-variant-numeric:tabular-nums}
.nb-left b{color:var(--brand-2);font-weight:700}
.nb-track{margin-top:11px;height:8px;border-radius:5px;background:#23262F;overflow:hidden}
.nb-fill{height:100%;width:68%;border-radius:5px;background:linear-gradient(90deg,var(--brand),var(--brand-2));
  animation:grow 2.4s cubic-bezier(.4,0,.2,1) both}
.desktop-pad{height:150px}
@keyframes grow{from{width:0}to{width:68%}}

.features,.install{max-width:var(--max);margin:0 auto;padding:56px 24px}
.features h2,.install h2{font-size:clamp(24px,4vw,34px);font-weight:800;letter-spacing:-.02em;margin:0 0 28px}
.cards{display:grid;grid-template-columns:repeat(3,1fr);gap:20px}
.cards article{background:var(--card);border:1px solid var(--hair);border-radius:16px;padding:22px}
.cards h3{margin:0 0 8px;font-size:18px;font-weight:700;letter-spacing:-.01em}
.cards p{margin:0;color:var(--muted);font-size:15px}

.install ol{margin:0 0 20px;padding:0;list-style:none;counter-reset:step;display:flex;flex-direction:column;gap:14px}
.install li{counter-increment:step;position:relative;padding-left:44px;font-size:16px}
.install li::before{content:counter(step);position:absolute;left:0;top:-2px;width:30px;height:30px;
  display:grid;place-items:center;background:var(--ink);color:#fff;border-radius:50%;font-weight:700;font-size:14px}
.install .note{background:#fff;border:1px solid var(--hair);border-left:3px solid var(--brand);
  border-radius:10px;padding:14px 16px;color:var(--muted);font-size:14.5px;max-width:64ch;margin:0 0 22px}

footer.site{border-top:1px solid var(--hair);margin-top:40px;color:var(--faint);font-size:14px;flex-wrap:wrap}
footer.site a{color:var(--muted);font-weight:600}
footer .reqs{color:var(--faint)}

@media(max-width:720px){
  .hero{grid-template-columns:1fr;padding-top:12px}
  .hero-stage{order:2}
  .cards{grid-template-columns:1fr}
}
@media(prefers-reduced-motion:reduce){.nb-fill{animation:none}html{scroll-behavior:auto}}
```

- [ ] **Step 3: Open the page and verify it renders in English without JS**

Run: `open docs/index.html`
Expected in the browser: hero headline "are we done yet?", a dark notch mockup with a green progress bar, three feature cards, three numbered install steps + the note, footer. No console errors. (The `main.js` 404/none yet is fine — page must look complete without it.)

- [ ] **Step 4: Verify structure and no stray i18n placeholders leaked as text**

Run:
```bash
grep -o 'data-i18n="' docs/index.html | wc -l   # expect: 21 (plain text bindings)
grep -o 'data-i18n-html="' docs/index.html | wc -l   # expect: 1 (mock.left)
grep -o 'data-i18n-attr="' docs/index.html | wc -l   # expect: 1 (meta description)
grep -o 'og:image" content="[^"]*"' docs/index.html
```
Expected: counts are `21`, `1`, `1`; the og:image line prints the absolute `https://periicles.github.io/Notchapp/assets/og-image.png` URL.

- [ ] **Step 5: Commit**

```bash
git add docs/index.html docs/style.css
git commit -m "feat(landing): page structure and styling (English default)"
```

---

### Task 3: Bilingual i18n behaviour

**Files:**
- Create: `docs/main.js`

**Interfaces:**
- Consumes: `data-i18n`, `data-i18n-html`, `data-i18n-attr` attributes and `.lang-btn[data-lang]` buttons from `index.html` (Task 2).
- Produces: runtime language switching. No later task depends on it.

- [ ] **Step 1: Create `docs/main.js`**

Create `docs/main.js` with exactly this content:

```js
(function () {
  "use strict";

  var DICT = {
    "hero.title":  { en: "are we done yet?", fr: "c'est bientôt fini ?" },
    "hero.sub":    { en: "Your notch answers that now. Live event progress, right where you're already staring.",
                     fr: "Ton notch répond à la question. La progression de ton cours, là où tu regardes déjà." },
    "cta.download":{ en: "Download for Mac", fr: "Télécharger pour Mac" },
    "meta.reqs":   { en: "macOS 14+ · Apple Silicon · free", fr: "macOS 14+ · Apple Silicon · gratuit" },
    "mock.title":  { en: "Organic Chemistry", fr: "Chimie organique" },
    "mock.left":   { en: "<b>23 min</b> left", fr: "<b>23 min</b> restantes" },
    "feat.heading":{ en: "What it does", fr: "Ce que ça fait" },
    "feat.1.t":    { en: "Live progress", fr: "En direct" },
    "feat.1.d":    { en: "See how far along your current event is, at a glance.",
                     fr: "Vois d'un coup d'œil où en est ton cours." },
    "feat.2.t":    { en: "Invisible at rest", fr: "Invisible au repos" },
    "feat.2.d":    { en: "The notch stays black until you hover. No clutter, no menu-bar icon.",
                     fr: "Le notch reste noir tant que tu ne survoles pas. Zéro encombrement." },
    "feat.3.t":    { en: "Barely there", fr: "Quasi rien" },
    "feat.3.d":    { en: "~0% CPU while collapsed. Your battery won't notice it's running.",
                     fr: "~0% CPU replié. Ta batterie ne le sentira même pas." },
    "install.heading": { en: "Install", fr: "Installation" },
    "install.1":   { en: "Download NotchBar.dmg and open it.", fr: "Télécharge NotchBar.dmg et ouvre-le." },
    "install.2":   { en: "Drag NotchBar into your Applications folder.", fr: "Glisse NotchBar dans ton dossier Applications." },
    "install.3":   { en: "Right-click NotchBar → Open, then confirm Open.", fr: "Clic droit sur NotchBar → Ouvrir, puis confirme." },
    "install.note":{ en: "The right-click is a one-time step while NotchBar isn't notarized by Apple yet. After that, it opens normally.",
                     fr: "Le clic droit est une étape unique tant que NotchBar n'est pas encore notariée par Apple. Ensuite, elle s'ouvre normalement." },
    "footer.source": { en: "Source on GitHub", fr: "Code sur GitHub" },
    "footer.made": { en: "Made by Periicles", fr: "Fait par Periicles" },
    "og.desc":     { en: "Turn your MacBook's notch into a live countdown for whatever you're stuck in.",
                     fr: "Transforme le notch de ton MacBook en compte à rebours pour ce qui t'ennuie." }
  };

  var SUPPORTED = ["en", "fr"];

  function resolveLang() {
    var q = new URLSearchParams(window.location.search).get("lang");
    if (SUPPORTED.indexOf(q) !== -1) return q;
    var stored = localStorage.getItem("lang");
    if (SUPPORTED.indexOf(stored) !== -1) return stored;
    var nav = (navigator.language || "en").toLowerCase();
    return nav.indexOf("fr") === 0 ? "fr" : "en";
  }

  function t(key, lang) {
    var e = DICT[key];
    if (!e) return "";
    return e[lang] != null ? e[lang] : e.en;
  }

  function apply(lang) {
    document.documentElement.lang = lang;

    document.querySelectorAll("[data-i18n]").forEach(function (el) {
      el.textContent = t(el.getAttribute("data-i18n"), lang);
    });
    document.querySelectorAll("[data-i18n-html]").forEach(function (el) {
      el.innerHTML = t(el.getAttribute("data-i18n-html"), lang);
    });
    document.querySelectorAll("[data-i18n-attr]").forEach(function (el) {
      el.getAttribute("data-i18n-attr").split(",").forEach(function (pair) {
        var bits = pair.split(":");
        el.setAttribute(bits[0].trim(), t(bits[1].trim(), lang));
      });
    });

    document.querySelectorAll(".lang-btn").forEach(function (b) {
      b.setAttribute("aria-pressed", String(b.getAttribute("data-lang") === lang));
    });

    localStorage.setItem("lang", lang);
    var url = new URL(window.location.href);
    url.searchParams.set("lang", lang);
    history.replaceState(null, "", url);
  }

  document.querySelectorAll(".lang-btn").forEach(function (b) {
    b.addEventListener("click", function () { apply(b.getAttribute("data-lang")); });
  });

  apply(resolveLang());
})();
```

- [ ] **Step 2: Verify FR/EN toggle and language resolution in the browser**

Run: `open docs/index.html`
Check, in order:
1. Click **FR** → every string flips to French (headline "c'est bientôt fini ?", steps in French, toggle shows FR active). Click **EN** → back to English.
2. Reload the page → it stays in the last language chosen (localStorage).
3. Open `docs/index.html?lang=fr` → loads directly in French.
4. In DevTools, confirm `<html lang>` matches the active language and the URL carries `?lang=`.
Expected: all four behave as described; no console errors.

- [ ] **Step 3: Verify graceful degradation (JS off)**

In the browser, disable JavaScript and reload `docs/index.html`.
Expected: the page still renders fully in **English**; the download buttons still link to the Releases page.

- [ ] **Step 4: Commit**

```bash
git add docs/main.js
git commit -m "feat(landing): bilingual FR/EN toggle with persistence and deep-link"
```

---

### Task 4: Deploy on GitHub Pages (runs after the branch is merged to `main`)

**Files:** none (repo settings only).

**Interfaces:**
- Consumes: `docs/index.html` present on `main` (Tasks 1–3, merged).
- Produces: the live site at `https://periicles.github.io/Notchapp/`.

- [ ] **Step 1: Enable Pages from `main` `/docs`**

Run (creates or updates the Pages config):
```bash
gh api -X POST repos/Periicles/Notchapp/pages \
  -f 'source[branch]=main' -f 'source[path]=/docs' 2>/dev/null \
|| gh api -X PUT repos/Periicles/Notchapp/pages \
  -f 'source[branch]=main' -f 'source[path]=/docs'
```
Expected: JSON describing the Pages site (no error). If Pages is already enabled, the PUT branch updates it.

- [ ] **Step 2: Wait for the build, then verify the site is live**

Run:
```bash
sleep 60
curl -sSI https://periicles.github.io/Notchapp/ | head -1
curl -sS  https://periicles.github.io/Notchapp/ | grep -o '<title>[^<]*</title>'
```
Expected: first line is `HTTP/2 200`; the title line prints `<title>NotchBar — are we done yet?</title>`. (First-ever Pages build can take a few minutes — re-run if it 404s.)

- [ ] **Step 3: Update the README with the live link**

In `README.md`, in the `## Installation` section, change step 1 from the plain Releases reference to also mention the site. Replace:
```markdown
1. Download the latest `NotchBar.dmg` from the [Releases](https://github.com/Periicles/Notchapp/releases) page.
```
with:
```markdown
1. Grab it from the [NotchBar website](https://periicles.github.io/Notchapp/), or download the latest `NotchBar.dmg` from the [Releases](https://github.com/Periicles/Notchapp/releases) page.
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs(readme): link the NotchBar website"
```

---

## Self-Review

**Spec coverage:**
- Static, no build → Tasks 2–3 (plain files). ✓
- Hosting `/docs` on main → Task 4. ✓
- i18n: one dictionary, EN+FR co-located, `?lang`→localStorage→navigator→EN, toggle updates text/`<html lang>`/`?lang`, attr translation → Task 3. ✓
- English default in markup, works without JS → Task 2 Step 3 + Task 3 Step 3. ✓
- File structure `index.html`/`style.css`/`main.js`/`assets/` → Tasks 1–3. ✓
- `.gitignore` cleanup → Task 1 Steps 1–2. ✓
- Page sections hero/features/install/footer → Task 2. ✓
- Copy table (all keys EN+FR) → Task 3 DICT + Task 2 markup. ✓
- Download → Releases page, real `<a href>`, works without JS → Task 2 markup (both buttons). ✓
- Footer "Source on GitHub"/"free", not "open source" → Task 2 footer + DICT. ✓
- OG/Twitter meta + `og-image.png` 1200×630 + favicon → Task 1 + Task 2 head. ✓
- Accessibility (focus-visible, landmarks, one h1) + responsive + reduced-motion → Task 2 `style.css`. ✓
- Custom-domain-ready (assets referenced by relative/absolute paths; adding `docs/CNAME` later is trivial) → structure in Task 2. ✓
- Tech debt (no LICENSE) → noted in spec, page avoids "open source". ✓

**Placeholder scan:** All file contents are complete and literal; no TBD/TODO. ✓

**Type/name consistency:** i18n keys match one-to-one between `index.html` (`data-i18n*` attributes) and `main.js` `DICT` (21 keys): `hero.title`, `hero.sub`, `cta.download`, `meta.reqs`, `mock.title`, `mock.left`, `feat.heading`, `feat.{1,2,3}.{t,d}`, `install.heading`, `install.{1,2,3}`, `install.note`, `footer.source`, `footer.made`, `og.desc`. Plain `data-i18n="` bindings = 21 (Task 2 Step 4): 19 distinct keys, with `cta.download` and `meta.reqs` each used twice (hero + install/footer). `mock.left` binds via `data-i18n-html`, `og.desc` via `data-i18n-attr` — every DICT key is referenced, and every referenced key exists in DICT. ✓

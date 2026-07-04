(function () {
  "use strict";

  var DICT = {
    "hero.title":  { en: "are we done yet?", fr: "c'est bientôt fini ?" },
    "hero.sub":    { en: "Your notch answers that now. Live event progress, right where you're already staring.",
                     fr: "Ton notch répond à la question. La progression de ton cours, là où tu regardes déjà." },
    "cta.download":{ en: "Download for Mac", fr: "Télécharger pour Mac" },
    "meta.reqs":   { en: "macOS 14+ · Apple Silicon · free & open source", fr: "macOS 14+ · Apple Silicon · gratuit & open source" },
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
    "install.3":   { en: "Open NotchBar. macOS blocks it the first time — that's expected.",
                     fr: "Ouvre NotchBar. macOS le bloque la première fois — c'est normal." },
    "install.4":   { en: "Open System Settings → Privacy & Security, then click “Open Anyway” and confirm.",
                     fr: "Va dans Réglages Système → Confidentialité et sécurité, puis clique « Ouvrir quand même » et confirme." },
    "install.note":{ en: "macOS blocks it only because NotchBar isn't notarized by Apple yet — it's safe, just unsigned. You do this once; afterwards it opens with a normal double-click.",
                     fr: "macOS le bloque seulement parce que NotchBar n'est pas encore notariée par Apple — c'est sûr, juste non signé. Tu le fais une fois ; ensuite elle s'ouvre d'un double-clic normal." },
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

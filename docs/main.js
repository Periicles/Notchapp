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
    "feat.1.d":    { en: "Hover the notch: what you're in, when it ends, and how much of it is left.",
                     fr: "Survole le notch : ce que tu subis, quand ça finit, et ce qu'il en reste." },
    "feat.2.t":    { en: "Countdown in the menu bar", fr: "Compte à rebours dans la barre de menus" },
    "feat.2.d":    { en: "The time left, next to the clock — 23 min, then 1h05. No hovering required.",
                     fr: "Le temps restant, à côté de l'horloge — 23 min, puis 1 h 05. Sans rien survoler." },
    "feat.3.t":    { en: "Told before it ends", fr: "Prévenu avant la fin" },
    "feat.3.d":    { en: "A notification five minutes before an event starts, and five before it's over. Off until you ask for it.",
                     fr: "Une notification cinq minutes avant que ça commence, et cinq avant que ça se termine. Désactivé tant que tu ne le demandes pas." },
    "feat.4.t":    { en: "Barely there", fr: "Quasi rien" },
    "feat.4.d":    { en: "The notch stays black until you hover, and NotchBar wakes up once every 30 seconds. Your battery won't notice.",
                     fr: "Le notch reste noir tant que tu ne survoles pas, et NotchBar ne se réveille qu'une fois toutes les 30 secondes. Ta batterie ne le sentira même pas." },
    "install.heading": { en: "Install", fr: "Installation" },
    "install.1":   { en: "Download NotchBar.dmg and open it.", fr: "Télécharge NotchBar.dmg et ouvre-le." },
    "install.2":   { en: "Drag NotchBar into your Applications folder.", fr: "Glisse NotchBar dans ton dossier Applications." },
    "install.3":   { en: "Open NotchBar. macOS blocks it the first time — expected for an unsigned app.",
                     fr: "Ouvre NotchBar. macOS le bloque la première fois — normal pour une app non signée." },
    "install.4":   { en: "Open System Settings → Privacy & Security, then click “Open Anyway” and confirm.",
                     fr: "Va dans Réglages Système → Confidentialité et sécurité, puis clique « Ouvrir quand même » et confirme." },
    "install.note":{ en: "NotchBar is unsigned, so Gatekeeper rejects the quarantine flag your browser attached to the download. You do this once; afterwards it opens with a normal double-click. Either command below skips the step entirely.",
                     fr: "NotchBar n'est pas signée, donc Gatekeeper refuse l'étiquette de quarantaine posée par ton navigateur. Tu le fais une fois ; ensuite elle s'ouvre d'un double-clic normal. Les commandes ci-dessous évitent complètement cette étape." },
    "install.brew":{ en: "Prefer the terminal? Homebrew skips the steps above entirely. <code>brew tap periicles/tap &amp;&amp; brew trust periicles/tap &amp;&amp; brew install --cask --no-quarantine notchbar</code>",
                     fr: "Plutôt le terminal ? Homebrew évite complètement les étapes ci-dessus. <code>brew tap periicles/tap &amp;&amp; brew trust periicles/tap &amp;&amp; brew install --cask --no-quarantine notchbar</code>" },
    "install.curl":{ en: "No Homebrew? This does the same, and nothing is piped into a shell. <code>curl -fsSL -o /tmp/NotchBar.dmg https://github.com/Periicles/Notchapp/releases/latest/download/NotchBar.dmg &amp;&amp;\nhdiutil attach -quiet -nobrowse -mountpoint /tmp/NotchBar.mount /tmp/NotchBar.dmg &amp;&amp;\ncp -R /tmp/NotchBar.mount/NotchBar.app /Applications/ &amp;&amp;\nhdiutil detach -quiet /tmp/NotchBar.mount &amp;&amp; rm /tmp/NotchBar.dmg</code>",
                     fr: "Pas de Homebrew ? Ceci fait la même chose, et rien n'est envoyé dans un shell. <code>curl -fsSL -o /tmp/NotchBar.dmg https://github.com/Periicles/Notchapp/releases/latest/download/NotchBar.dmg &amp;&amp;\nhdiutil attach -quiet -nobrowse -mountpoint /tmp/NotchBar.mount /tmp/NotchBar.dmg &amp;&amp;\ncp -R /tmp/NotchBar.mount/NotchBar.app /Applications/ &amp;&amp;\nhdiutil detach -quiet /tmp/NotchBar.mount &amp;&amp; rm /tmp/NotchBar.dmg</code>" },
    "uninstall.line":{ en: "Changed your mind? Turn off <b>Launch at login</b>, then drag NotchBar to the Trash. <a href='https://github.com/Periicles/Notchapp#uninstall'>Full steps</a>.",
                     fr: "Tu changes d'avis ? Désactive <b>Launch at login</b>, puis glisse NotchBar dans la Corbeille. <a href='https://github.com/Periicles/Notchapp#uninstall'>Étapes complètes</a>." },
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

(function () {
  var root = document.documentElement;
  var btn = document.querySelector("[data-theme-toggle]");

  function current() {
    return root.getAttribute("data-theme") === "dark" ? "dark" : "light";
  }

  function apply(theme) {
    root.setAttribute("data-theme", theme);
    root.style.colorScheme = theme;
    try { localStorage.setItem("ie-theme", theme); } catch (e) {}
    if (btn) {
      var next = theme === "dark" ? "light" : "dark";
      btn.setAttribute("aria-label", "Switch to " + next + " theme");
      btn.setAttribute("aria-pressed", theme === "dark" ? "true" : "false");
    }
  }

  if (btn) {
    btn.addEventListener("click", function () {
      apply(current() === "dark" ? "light" : "dark");
    });
    apply(current());
  }

  document.querySelectorAll("[data-copy]").forEach(function (el) {
    var label = el.textContent;
    el.addEventListener("click", function () {
      var text = el.getAttribute("data-copy") || "";
      function done(ok) {
        el.textContent = ok ? "Copied" : "Copy failed";
        window.setTimeout(function () { el.textContent = label; }, 1600);
      }
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(function () { done(true); }).catch(function () { done(false); });
      } else {
        done(false);
      }
    });
  });
})();

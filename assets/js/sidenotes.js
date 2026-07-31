// Transform Hugo footnotes into Tufte-style sidenotes/marginnotes
(function () {
  document.addEventListener("DOMContentLoaded", function () {
    var article = document.querySelector("article");
    if (!article) return;

    var footnotesSection = article.querySelector(".footnotes");
    if (!footnotesSection) return;

    var counter = 0;
    var refs = article.querySelectorAll("a.footnote-ref");

    refs.forEach(function (ref) {
      counter++;
      var id = ref.getAttribute("href").replace("#", "");
      var defEl = footnotesSection.querySelector("#" + CSS.escape(id));
      if (!defEl) return;

      // Get the footnote text, strip the back-ref link
      var text = defEl.innerHTML;
      text = text.replace(/<a[^>]*>.*?<\/a>\s*$/, "").trim();

      var isMargin = text.startsWith("*");
      if (isMargin) text = text.substring(1).trim();

      // Create the sidenote/marginnote structure
      var noteId = "sn-" + counter;

      var label = document.createElement("label");
      label.setAttribute("for", noteId);
      label.className = isMargin
        ? "margin-toggle"
        : "margin-toggle sidenote-number";

      if (isMargin) {
        label.innerHTML = "&#8853;";
      }

      var checkbox = document.createElement("input");
      checkbox.type = "checkbox";
      checkbox.id = noteId;
      checkbox.className = "margin-toggle";

      var span = document.createElement("span");
      span.className = isMargin ? "marginnote" : "sidenote";
      span.innerHTML = text;

      // Insert after the footnote reference
      ref.parentNode.insertBefore(label, ref.nextSibling);
      label.parentNode.insertBefore(checkbox, label.nextSibling);
      checkbox.parentNode.insertBefore(span, checkbox.nextSibling);

      // Remove the original footnote link
      ref.remove();
    });

    // Remove the footnotes section
    footnotesSection.remove();
  });
})();

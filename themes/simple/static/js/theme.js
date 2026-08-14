(function () {
  'use strict';

  var prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;

  document.documentElement.classList.add('dark');

  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function (e) {
    document.documentElement.classList.toggle('dark', e.matches);
  });
})();

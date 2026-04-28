(function() {
    const de = document.documentElement;
    const storageKey = 'theme';

    // Theme Initialization
    const currentTheme = localStorage.getItem(storageKey);
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;

    if (currentTheme === 'dark' || (!currentTheme && prefersDark)) {
        de.setAttribute('data-theme', 'dark');
    }

    // Theme Toggle Logic
    document.addEventListener('DOMContentLoaded', () => {
        const toggle = document.querySelector('.theme-toggle');
        if (!toggle) return;

        const updateToggleText = () => {
            toggle.innerText = de.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
        };

        toggle.addEventListener('click', (e) => {
            e.preventDefault();
            if (de.getAttribute('data-theme') === 'dark') {
                de.removeAttribute('data-theme');
                localStorage.setItem(storageKey, 'light');
            } else {
                de.setAttribute('data-theme', 'dark');
                localStorage.setItem(storageKey, 'dark');
            }
            updateToggleText();
        });

        updateToggleText();
    });
})();

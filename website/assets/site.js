const setupSwitch = document.querySelector('.setup-switch');
if (setupSwitch) {
  const panels = [...document.querySelectorAll('[data-setup-protocol]')];
  const choices = [...setupSwitch.querySelectorAll('[data-setup-choice]')];
  const outline = [...document.querySelectorAll('[data-setup-outline]')];
  const hashPanel = () => document.getElementById(decodeURIComponent(location.hash.slice(1)))?.closest('[data-setup-protocol]');
  const selectProtocol = protocol => {
    panels.forEach(panel => { panel.hidden = panel.dataset.setupProtocol !== protocol; });
    choices.forEach(button => { button.setAttribute('aria-pressed', String(button.dataset.setupChoice === protocol)); });
    outline.forEach(link => { link.hidden = link.dataset.setupOutline !== protocol; });
  };
  const restoreProtocol = () => {
    const requested = new URL(location.href).searchParams.get('protocol');
    const protocol = ['jdbc', 'rest'].includes(requested) ? requested : hashPanel()?.dataset.setupProtocol || 'jdbc';
    selectProtocol(protocol);
    const target = hashPanel();
    if (target && target.hidden) {
      const id = decodeURIComponent(location.hash.slice(1));
      const equivalent = document.getElementById(protocol === 'rest' ? `${id}-1` : id.replace(/-1$/, ''));
      if (equivalent?.closest('[data-setup-protocol]')?.dataset.setupProtocol === protocol) {
        history.replaceState(null, '', `${location.pathname}${location.search}#${equivalent.id}`);
      }
    }
    if (location.hash) document.getElementById(decodeURIComponent(location.hash.slice(1)))?.scrollIntoView();
  };
  choices.forEach(button => button.addEventListener('click', () => {
    const protocol = button.dataset.setupChoice;
    const url = new URL(location.href);
    url.searchParams.set('protocol', protocol);
    if (hashPanel()?.dataset.setupProtocol !== protocol) url.hash = '';
    history.pushState(null, '', url);
    selectProtocol(protocol);
  }));
  window.addEventListener('popstate', restoreProtocol);
  window.addEventListener('hashchange', () => {
    const panel = hashPanel();
    if (!panel) return;
    const url = new URL(location.href);
    url.searchParams.set('protocol', panel.dataset.setupProtocol);
    history.replaceState(null, '', url);
    selectProtocol(panel.dataset.setupProtocol);
    document.getElementById(decodeURIComponent(location.hash.slice(1)))?.scrollIntoView();
  });
  restoreProtocol();
}

document.querySelectorAll('.assistant-launcher').forEach(panel => {
  const prompts = JSON.parse(panel.dataset.prompts);
  const code = panel.querySelector('.starter-prompt code');
  panel.querySelector('#prompt-protocol').addEventListener('change', event => {
    const prompt = prompts[event.target.value];
    code.textContent = prompt;
    const encoded = encodeURIComponent(prompt);
    panel.querySelector('[data-assistant="codex"]').href = `codex://threads/new?prompt=${encoded}`;
    panel.querySelector('[data-assistant="cursor"]').href = `cursor://anysphere.cursor-deeplink/prompt?text=${encoded}`;
    panel.querySelector('[data-assistant="claude"]').href = `claude://code/new?q=${encoded}`;
  });
});

document.querySelectorAll('pre').forEach(pre => {
  const code = pre.querySelector('code');
  if (!code) return;
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'copy-button';
  button.textContent = 'Copy';
  button.setAttribute('aria-label', 'Copy code to clipboard');
  button.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(code.textContent);
      button.textContent = 'Copied';
    } catch {
      const range = document.createRange();
      range.selectNodeContents(code);
      const selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      button.textContent = 'Select and copy';
    }
    setTimeout(() => { button.textContent = 'Copy'; }, 2200);
  });
  pre.append(button);
});

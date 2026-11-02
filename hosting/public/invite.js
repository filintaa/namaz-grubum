(() => {
  const parts = window.location.pathname.split('/').filter(Boolean);
  const groupId = parts[0] === 'g' ? parts[1] : null;
  const button = document.getElementById('open-app');
  if (!groupId || !/^[A-Za-z0-9_-]{3,128}$/.test(groupId)) {
    button.removeAttribute('href');
    button.textContent = 'Davet bağlantısı geçersiz';
    button.setAttribute('aria-disabled', 'true');
    return;
  }
  button.href = `namazgrubum://g/${encodeURIComponent(groupId)}`;
})();

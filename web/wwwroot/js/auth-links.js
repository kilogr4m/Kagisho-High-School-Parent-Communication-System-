(() => {
  'use strict';
  // Supabase invitation/recovery tokens arrive in the URL fragment; fragments never reach the server.
  // Move the short-lived access token into the form and immediately clear the fragment from the address bar.
  const params = new URLSearchParams(location.hash.replace(/^#/, ''));
  const token = params.get('access_token');
  const type = params.get('type');
  const el = document.querySelector('#inviteToken');
  if (el && token && ((location.pathname === '/activate' && type === 'invite') || (location.pathname === '/reset-password' && type === 'recovery'))) {
    el.value = token;
    history.replaceState(null, '', location.pathname);
  } else if (el && !el.value) {
    const help = document.querySelector('#inviteHelp');
    if (help) help.textContent = 'Please open the complete link from your email. If it has expired, request a new link from your school.';
  }
})();

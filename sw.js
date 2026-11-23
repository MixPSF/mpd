const CACHE = 'mpd-uzk-v24';
const SHELL = ['./', './index.html', './config.js', './manifest.json', './icon-192.png', './icon-512.png', './wp-ind.jpg', './wp-fun.jpg', './wp-coffee.jpg'];
self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const req = e.request, url = new URL(req.url);
  if (req.method !== 'GET' || url.hostname.endsWith('supabase.co')) return; // данные — только онлайн
  e.respondWith(
    fetch(req).then(res => {
      const copy = res.clone();
      caches.open(CACHE).then(c => c.put(req, copy));
      return res;
    }).catch(() => caches.match(req).then(r => r || caches.match('./index.html')))
  );
});

// ===== Push-уведомления (приходят даже при свёрнутом/закрытом приложении) =====
self.addEventListener('push', e => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch (er) { d = { title: 'Контроль МПД / УЗК', body: e.data ? e.data.text() : '' }; }
  e.waitUntil((async () => {
    const cs = await clients.matchAll({ type: 'window', includeUncontrolled: true });
    if (cs.some(c => c.visibilityState === 'visible')) return;      // приложение открыто — показывает баннер само
    await self.registration.showNotification(d.title || 'Контроль МПД / УЗК', {
      body: d.body || '', tag: d.tag, renotify: !!d.tag, requireInteraction: !!d.ri,
      vibrate: [300, 120, 300, 120, 500], icon: 'icon-192.png', badge: 'icon-192.png', data: { url: d.url || './' }
    });
  })());
});
self.addEventListener('notificationclick', e => {
  e.notification.close();
  e.waitUntil(clients.matchAll({ type: 'window', includeUncontrolled: true }).then(cs => {
    for (const c of cs) if ('focus' in c) return c.focus();
    return clients.openWindow((e.notification.data && e.notification.data.url) || './');
  }));
});

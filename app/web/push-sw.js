self.addEventListener('push', (event) => {
  let data = {};
  try { data = event.data ? event.data.json() : {}; } catch (_) { data = {body: event.data ? event.data.text() : ''}; }
  const title = data.title || 'LoveSpace';
  event.waitUntil(Promise.all([self.registration.showNotification(title, {
    body: data.body || '你们的空间有一条新消息',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: {path: data.path || '/notifications'},
    tag: data.path || 'lovespace-notification'
  }), self.navigator.setAppBadge ? self.navigator.setAppBadge(1) : Promise.resolve()]));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  if (self.navigator.clearAppBadge) self.navigator.clearAppBadge();
  const target = new URL(event.notification.data?.path || '/notifications', self.location.origin).href;
  event.waitUntil(clients.matchAll({type: 'window', includeUncontrolled: true}).then((windows) => {
    for (const client of windows) {
      if ('navigate' in client) client.navigate(target);
      return client.focus();
    }
    return clients.openWindow(target);
  }));
});

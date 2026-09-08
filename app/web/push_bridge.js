(function () {
  function base64Url(bytes) {
    let value = '';
    new Uint8Array(bytes).forEach((byte) => value += String.fromCharCode(byte));
    return btoa(value).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }

  function decodeKey(value) {
    const padding = '='.repeat((4 - value.length % 4) % 4);
    const raw = atob((value + padding).replace(/-/g, '+').replace(/_/g, '/'));
    return Uint8Array.from(raw, (character) => character.charCodeAt(0));
  }

  function installed() {
    return window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true;
  }

  window.loveSpacePush = {
    status: async function () {
      const supported = 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
      let message = supported ? '可开启通知' : '此浏览器不支持 Web Push';
      if (supported && !installed()) message = '请先用 Safari 添加到主屏幕，再从主屏幕打开';
      if (supported && Notification.permission === 'granted') message = 'Web Push 已授权';
      return JSON.stringify({supported, installed: installed(), permission: supported ? Notification.permission : 'unsupported', message});
    },
    subscribe: async function (vapidPublicKey) {
      if (!installed()) throw new Error('请先添加到主屏幕，再从主屏幕打开 LoveSpace');
      if (Notification.permission !== 'granted') {
        const permission = await Notification.requestPermission();
        if (permission !== 'granted') throw new Error('没有获得通知权限');
      }
      const registration = await navigator.serviceWorker.register('/push-sw.js', {scope: '/'});
      await navigator.serviceWorker.ready;
      let subscription = await registration.pushManager.getSubscription();
      if (!subscription) {
        subscription = await registration.pushManager.subscribe({userVisibleOnly: true, applicationServerKey: decodeKey(vapidPublicKey)});
      }
      const json = subscription.toJSON();
      const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(subscription.endpoint));
      return JSON.stringify({
        deviceId: 'web-' + base64Url(digest).slice(0, 32),
        endpoint: subscription.endpoint,
        publicKey: json.keys.p256dh,
        authSecret: json.keys.auth
      });
    }
  };
})();

var CACHE_NAME = 'scheer-playbooks-v2';

var SHELL_ASSETS = [
  './',
  './index.html',
  './manifest.json'
];

// Install: cache the app shell
self.addEventListener('install', function(event) {
  event.waitUntil(
    caches.open(CACHE_NAME).then(function(cache) { return cache.addAll(SHELL_ASSETS); })
  );
  self.skipWaiting();
});

// Activate: clean ALL old caches
self.addEventListener('activate', function(event) {
  event.waitUntil(
    caches.keys().then(function(keys) {
      return Promise.all(keys.filter(function(k) { return k !== CACHE_NAME; }).map(function(k) { return caches.delete(k); }));
    })
  );
  self.clients.claim();
});

// Fetch: ALWAYS network-first, cache only as offline fallback
self.addEventListener('fetch', function(event) {
  event.respondWith(
    fetch(event.request)
      .then(function(response) {
        var clone = response.clone();
        caches.open(CACHE_NAME).then(function(cache) { cache.put(event.request, clone); });
        return response;
      })
      .catch(function() { return caches.match(event.request); })
  );
});

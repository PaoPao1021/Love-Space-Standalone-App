{{flutter_js}}
{{flutter_build_config}}

// LoveSpace owns the root Service Worker scope through push-sw.js.
// Do not let Flutter register flutter_service_worker.js over that scope.
_flutter.loader.load();

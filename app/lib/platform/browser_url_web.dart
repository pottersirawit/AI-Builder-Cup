import 'dart:js_interop';

@JS('window.history.replaceState')
external void _replaceState(JSAny? data, JSString unused, JSString url);

/// Rewrites the address bar without reloading or adding a history entry.
void replaceBrowserUrl(Uri url) =>
    _replaceState(null, ''.toJS, url.toString().toJS);

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'models.dart';
import 'places.dart';
import 'platform/browser_url.dart';

/// Where a native build sends the browser back to after Google.
const _webApp = 'https://ai-cup-511208.web.app/';

/// Connects the user's Google account (Calendar and Gmail, one consent)
/// through the server's OAuth flow. The account counts as connected only once
/// the server says so: by polling /v1/oauth/status for this sign-in's nonce,
/// when the app comes back to the foreground, or when the browser returns
/// with `?connected=<email>`.
class GoogleLink {
  GoogleLink({
    required this.api,
    required this.places,
    Uri? appBase,
    Future<bool> Function(Uri url)? launch,
    void Function(Uri url)? replaceUrl,
    this.every = const Duration(seconds: 3),
    this.patience = const Duration(seconds: 60),
  }) : appBase = appBase ?? Uri.base,
       _launch = launch ?? _openGoogle,
       _replaceUrl = replaceUrl ?? replaceBrowserUrl;

  final FonTokMaiApi api;
  final PlacesStore places;

  /// The app's own URL: where Google returns, and where `?connected=` lands.
  final Uri appBase;
  final Duration every;
  final Duration patience;
  final Future<bool> Function(Uri url) _launch;
  final void Function(Uri url) _replaceUrl;

  String? _nonce;

  /// The server URL that starts sign-in and comes back to this app.
  Uri startUrl(String nonce) {
    final web = appBase.scheme == 'http' || appBase.scheme == 'https';
    final back = web
        ? Uri(
            scheme: appBase.scheme,
            host: appBase.host,
            port: appBase.hasPort ? appBase.port : null,
            path: appBase.path.isEmpty ? '/' : appBase.path,
          ).toString()
        : _webApp;
    return Uri.parse(
      '${api.baseUrl}/v1/oauth/start',
    ).replace(queryParameters: {'return': back, 'nonce': nonce});
  }

  /// Opens Google and waits up to [patience] for the server to confirm.
  Future<void> connect() async {
    if (places.calendar == LinkState.connecting && _nonce != null) return;
    final nonce = _newNonce();
    _nonce = nonce;
    places.beginGoogleConnect();
    var opened = false;
    try {
      opened = await _launch(startUrl(nonce));
    } catch (e) {
      debugPrint('fontokmai: could not open Google sign-in ($e)');
    }
    if (!opened) {
      _giveUp(nonce);
      return;
    }
    final deadline = DateTime.now().add(patience);
    while (_nonce == nonce) {
      await Future<void>.delayed(every);
      if (_nonce != nonce) return;
      if (await check()) return;
      if (!DateTime.now().isBefore(deadline)) {
        _giveUp(nonce);
        return;
      }
    }
  }

  /// Asks the server once whether the pending sign-in finished; true when
  /// it did and the account is now connected.
  Future<bool> check() async {
    final nonce = _nonce;
    if (nonce == null) return false;
    try {
      final s = await api.oauthStatus(nonce: nonce);
      if (_nonce != nonce || !s.connected || s.email.isEmpty) return false;
      _nonce = null;
      places.connectGoogle(s.email);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Stops waiting; the rows show the connect button again.
  void cancel() {
    final nonce = _nonce;
    if (nonce != null) _giveUp(nonce);
  }

  /// Connects the account the server put in `?connected=` and removes it
  /// from the address bar. False when the URL carries none.
  bool acceptReturn() {
    final email = appBase.queryParameters['connected'];
    if (email == null || email.isEmpty) return false;
    _nonce = null;
    places.connectGoogle(email);
    final rest = {...appBase.queryParameters}..remove('connected');
    final clean = Uri.parse(appBase.toString().split('?').first).replace(
      queryParameters: rest.isEmpty ? null : rest,
      fragment: appBase.hasFragment ? appBase.fragment : null,
    );
    _replaceUrl(clean);
    return true;
  }

  void _giveUp(String nonce) {
    if (_nonce != nonce) return;
    _nonce = null;
    places.failGoogleConnect();
  }

  static String _newNonce() {
    final r = math.Random.secure();
    return base64Url
        .encode(List<int>.generate(16, (_) => r.nextInt(256)))
        .replaceAll('=', '');
  }
}

/// On the web Google opens in this tab, so the page comes back with
/// `?connected=`; elsewhere in the system browser while the app polls.
Future<bool> _openGoogle(Uri url) => kIsWeb
    ? launchUrl(url, webOnlyWindowName: '_self')
    : launchUrl(url, mode: LaunchMode.externalApplication);

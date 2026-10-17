import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/config.dart';

void main() {
  test('the default API is the Cloud Run service the OAuth redirect points at', () {
    expect(resolveApiBaseUrl(), 'https://fontokmai-api-lmr33aj5zq-as.a.run.app');
  });

  test('the web shell paints the dark background and a splash before Flutter boots', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html, contains('background:#060A14'));
    expect(html, contains('id="splash"'));
    expect(html, contains('flutter-first-frame'));
  });

  test('Firebase Hosting serves the Flutter build as a single-page app', () {
    final config = jsonDecode(File('../firebase.json').readAsStringSync()) as Map<String, dynamic>;
    final hosting = config['hosting'] as Map<String, dynamic>;
    expect(hosting['public'], 'app/build/web');
    expect(hosting['rewrites'], [
      {'source': '**', 'destination': '/index.html'},
    ]);
    final noCache = [
      for (final h in hosting['headers'] as List)
        if ((h['headers'] as List).any((v) => v['value'] == 'no-cache')) h['source'],
    ];
    expect(
      noCache,
      containsAll(['/index.html', '/flutter_bootstrap.js', '/flutter_service_worker.js', '/version.json']),
    );
    final rc = jsonDecode(File('../.firebaserc').readAsStringSync()) as Map<String, dynamic>;
    expect(rc['projects']['default'], 'ai-cup-511208');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/api.dart';
import 'package:fontokmai/design/components/places.dart';
import 'package:fontokmai/google_link.dart';
import 'package:fontokmai/models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

const owner = 'owner.real@example.com';

/// An API whose /v1/oauth/status answers from [connected]; every other
/// request fails. [log] collects the paths asked for.
FonTokMaiApi statusApi(bool Function() connected, List<Uri> log) =>
    FonTokMaiApi(
      baseUrl: 'http://api.test',
      client: MockClient((req) async {
        log.add(req.url);
        if (req.url.path == '/v1/oauth/status') {
          return jsonResponse(
            connected()
                ? {'email': owner, 'connected': true, 'scopes': []}
                : {'email': '', 'connected': false, 'scopes': []},
          );
        }
        throw http.ClientException('offline');
      }),
    );

void main() {
  group('GoogleLink', () {
    test('starts the server flow with the app origin and a nonce', () async {
      final store = await emptyStore();
      final link = GoogleLink(
        api: statusApi(() => false, []),
        places: store,
        appBase: Uri.parse('https://ai-cup-511208.web.app/?x=1#/settings'),
      );
      final url = link.startUrl('abcdefgh1234');
      expect(url.origin, 'http://api.test');
      expect(url.path, '/v1/oauth/start');
      expect(url.queryParameters, {
        'return': 'https://ai-cup-511208.web.app/',
        'nonce': 'abcdefgh1234',
      });
    });

    test('connected only after the server says status=connected', () async {
      final store = await emptyStore();
      final log = <Uri>[];
      var polls = 0;
      Uri? launched;
      final link = GoogleLink(
        api: statusApi(() => ++polls >= 3, log),
        places: store,
        appBase: Uri.parse('https://ai-cup-511208.web.app/'),
        launch: (u) async {
          launched = u;
          return true;
        },
        every: const Duration(milliseconds: 5),
      );

      final f = link.connect();
      await Future<void>.delayed(Duration.zero);
      expect(launched?.path, '/v1/oauth/start');
      expect(store.calendar, LinkState.connecting);
      expect(store.calendarAccount, isNull);

      await f;
      expect(polls, 3);
      final nonce = launched!.queryParameters['nonce'];
      expect(
        log.every((u) => u.queryParameters['nonce'] == nonce),
        isTrue,
        reason: 'polls ask for this sign-in, not an email',
      );
      expect(store.calendar, LinkState.connected);
      expect(store.gmail, LinkState.connected);
      expect(store.calendarAccount, owner);
      expect(store.gmailAccount, owner);
      expect(store.takeSyncDue(), isTrue);
      expect(store.takeSyncDue(), isFalse);
    });

    test('gives up after its patience and says it failed', () async {
      final store = await emptyStore();
      final link = GoogleLink(
        api: statusApi(() => false, []),
        places: store,
        appBase: Uri.parse('https://ai-cup-511208.web.app/'),
        launch: (_) async => true,
        every: const Duration(milliseconds: 5),
        patience: const Duration(milliseconds: 30),
      );
      await link.connect();
      expect(store.calendar, LinkState.error);
      expect(store.calendarAccount, isNull);
    });

    test('?connected= on the app URL connects and is stripped', () async {
      final store = await emptyStore();
      Uri? replaced;
      final link = GoogleLink(
        api: statusApi(() => false, []),
        places: store,
        appBase: Uri.parse(
          'https://ai-cup-511208.web.app/?connected=owner.real%40example.com#/',
        ),
        replaceUrl: (u) => replaced = u,
      );
      expect(link.acceptReturn(), isTrue);
      expect(store.calendar, LinkState.connected);
      expect(store.calendarAccount, owner);
      expect(store.takeSyncDue(), isTrue);
      expect(replaced.toString(), 'https://ai-cup-511208.web.app/#/');
    });

    test('a URL without ?connected= changes nothing', () async {
      final store = await emptyStore();
      final link = GoogleLink(
        api: statusApi(() => false, []),
        places: store,
        appBase: Uri.parse('https://ai-cup-511208.web.app/#/'),
        replaceUrl: (_) => fail('nothing to strip'),
      );
      expect(link.acceptReturn(), isFalse);
      expect(store.calendar, LinkState.notConnected);
    });
  });

  testWidgets('one Connect Google sheet, waiting until Google answers', (
    tester,
  ) async {
    final store = await emptyStore();
    final asked = <String>[];
    var signedIn = false;
    Uri? launched;
    final state = await pumpApp(
      tester,
      null,
      places: store,
      launch: (u) async {
        launched = u;
        return true;
      },
      respond: (req) {
        asked.add(req.url.path);
        if (req.url.path == '/v1/oauth/status') {
          return jsonResponse({'email': owner, 'connected': signedIn});
        }
        if (req.url.path == '/v1/trips/sync') {
          return jsonResponse({'trips': []});
        }
        return null;
      },
    );
    state.locale = const Locale('en');
    await settle(tester);

    await tapAndSettle(tester, find.text('Connect Google Calendar').first);
    expect(find.text('Connect Google'), findsOneWidget);
    expect(find.byType(TextField), findsNothing, reason: 'no email field');
    expect(find.textContaining('the32069'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('google-sign-in')));
    await tester.pump();
    expect(launched?.path, '/v1/oauth/start');
    expect(find.text('Waiting for Google…'), findsOneWidget);
    expect(store.calendar, LinkState.connecting);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(asked, contains('/v1/oauth/status'));
    expect(store.calendar, LinkState.connecting, reason: 'not yet consented');

    signedIn = true;
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(store.calendar, LinkState.connected);
    expect(store.calendarAccount, owner);
    expect(asked, contains('/v1/trips/sync'));
    expect(find.text('Waiting for Google…'), findsNothing);
  });

  testWidgets('coming back to the app checks the sign-in and syncs', (
    tester,
  ) async {
    final store = await emptyStore();
    final asked = <String>[];
    await pumpApp(
      tester,
      null,
      places: store,
      launch: (_) async => true,
      respond: (req) {
        asked.add(req.url.path);
        if (req.url.path == '/v1/oauth/status') {
          return jsonResponse({'email': owner, 'connected': true});
        }
        if (req.url.path == '/v1/trips/sync') {
          return jsonResponse({'trips': []});
        }
        return null;
      },
    );
    await tapAndSettle(tester, find.text('เชื่อม Google Calendar').first);
    await tester.tap(find.byKey(const ValueKey('google-sign-in')));
    await tester.pump();
    expect(store.calendar, LinkState.connecting);
    expect(asked, isNot(contains('/v1/oauth/status')));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      store.calendar,
      LinkState.connected,
      reason: 'before the 3 s poll would have asked',
    );
    await settle(tester);
    expect(asked, contains('/v1/trips/sync'));
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('?connected= on launch connects that account and syncs', (
    tester,
  ) async {
    final store = await emptyStore();
    final asked = <Uri>[];
    await pumpApp(
      tester,
      null,
      places: store,
      appBase: Uri.parse(
        'https://ai-cup-511208.web.app/?connected=owner.real%40example.com#/',
      ),
      respond: (req) {
        asked.add(req.url);
        if (req.url.path == '/v1/trips/sync') {
          return jsonResponse({'trips': []});
        }
        return null;
      },
    );
    expect(store.calendarAccount, owner);
    final sync = asked.where((u) => u.path == '/v1/trips/sync');
    expect(sync, isNotEmpty);
    expect(sync.first.queryParameters['email'], owner);
  });

  testWidgets('reconnecting Gmail alone opens Google, not a false success', (
    tester,
  ) async {
    final store = await emptyStore();
    store
      ..connectGoogle(owner)
      ..takeSyncDue()
      ..disconnectGmail();
    var signedIn = false;
    Uri? launched;
    final state = await pumpApp(
      tester,
      null,
      places: store,
      launch: (u) async {
        launched = u;
        return true;
      },
      respond: (req) {
        if (req.url.path == '/v1/oauth/status') {
          return jsonResponse({'email': owner, 'connected': signedIn});
        }
        if (req.url.path.startsWith('/v1/trips')) {
          return jsonResponse({'trips': []});
        }
        return null;
      },
    );
    state.locale = const Locale('en');
    await settle(tester);
    await tapAndSettle(tester, find.byTooltip('Settings'));
    final gmail = find.ancestor(
      of: find.text('Gmail'),
      matching: find.byType(ConnectRow),
    );
    await reveal(tester, gmail);
    await tapAndSettle(
      tester,
      find.descendant(of: gmail, matching: find.text('Connect')),
    );
    expect(find.text('Connect Google'), findsOneWidget, reason: 'sheet stays');
    expect(find.textContaining('Connected as'), findsNothing);
    expect(launched, isNull);

    await tester.tap(find.byKey(const ValueKey('google-sign-in')));
    await tester.pump();
    expect(launched?.path, '/v1/oauth/start');
    expect(store.gmail, LinkState.connecting);

    signedIn = true;
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(store.gmail, LinkState.connected);
    expect(store.gmailAccount, owner);
    expect(find.text('Connect Google'), findsNothing);
  });
}

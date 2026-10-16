import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fontokmai/api.dart';
import 'package:fontokmai/app_state.dart';
import 'package:fontokmai/trips_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

FonTokMaiApi offlineApi() => FonTokMaiApi(
  baseUrl: 'http://offline.test',
  client: MockClient((_) async => throw http.ClientException('offline')),
  bundle: _DiskBundle(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a real account never gets มิว\'s sample trips', () async {
    final store = (await emptyStore())..connectGoogle('owner.real@example.com');
    final state = AppState();
    final repo = TripsRepository(
      api: offlineApi(),
      state: state,
      places: store,
    );

    await repo.refresh(sync: true);

    expect(repo.error, isNotNull, reason: 'shows the error state with Retry');
    expect(repo.trips, isEmpty);
    expect(store.cachedTrips, isEmpty);
    expect(repo.loading, isFalse);
  });

  test('the demo profile still demos offline from the fixtures', () async {
    final store = await demoStore();
    final repo = TripsRepository(
      api: offlineApi(),
      state: AppState(),
      places: store,
    );

    await repo.refresh();

    expect(repo.error, isNull);
    expect(repo.trips, isNotEmpty);
    expect(store.cachedTrips, isEmpty, reason: 'sample trips are never cached');
  });
}

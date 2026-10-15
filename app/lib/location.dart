import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'l10n/l10n.dart';

/// Ratchadaphisek Rd at Soi Lat Phrao 32: the demo scenario's flood spot,
/// used when GPS is off, denied or slow.
const fallbackSpot = (
  lat: 13.8063,
  lng: 100.5737,
  nameTh: 'ถ.รัชดาภิเษก หน้าซอยลาดพร้าว 32',
);

/// Why a [Fix] carries the note it does.
enum FixNote { gpsOff, denied, unavailable, current, spot }

/// Where a report is pinned, and how we know.
class Fix {
  const Fix({
    required this.lat,
    required this.lng,
    required this.fromGps,
    required this.noteTh,
    this.note = FixNote.unavailable,
  });
  final double lat;
  final double lng;
  final bool fromGps;

  /// Place name, or why the fallback was used.
  final String noteTh;
  final FixNote note;

  /// [noteTh] in the app language.
  String noteText(AppLocalizations l) => switch (note) {
    FixNote.gpsOff => l.locationGpsOff,
    FixNote.denied => l.locationDenied,
    FixNote.unavailable => l.locationUnavailable,
    FixNote.current => l.locationCurrent,
    FixNote.spot => fallbackSpotName(l),
  };
}

String fallbackSpotName(AppLocalizations l) => l.locationFallbackSpot;

Fix _fallback(String why, FixNote note) => Fix(
  lat: fallbackSpot.lat,
  lng: fallbackSpot.lng,
  fromGps: false,
  noteTh: why,
  note: note,
);

/// Current position with permission handling; never throws.
Future<Fix> currentFix() async {
  try {
    // Non-interactive calls get a deadline; the permission prompt does not.
    const quick = Duration(seconds: 3);
    if (!await Geolocator.isLocationServiceEnabled().timeout(quick))
      return _fallback('GPS ปิดอยู่', FixNote.gpsOff);
    var p = await Geolocator.checkPermission().timeout(quick);
    if (p == LocationPermission.denied)
      p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied ||
        p == LocationPermission.deniedForever) {
      return _fallback('ไม่ได้อนุญาตให้ใช้ตำแหน่ง', FixNote.denied);
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
    final near =
        Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          fallbackSpot.lat,
          fallbackSpot.lng,
        ) <
        400;
    return Fix(
      lat: pos.latitude,
      lng: pos.longitude,
      fromGps: true,
      noteTh: near ? fallbackSpot.nameTh : 'ตำแหน่งปัจจุบัน',
      note: near ? FixNote.spot : FixNote.current,
    );
  } catch (_) {
    return _fallback('หาตำแหน่งไม่ได้', FixNote.unavailable);
  }
}

/// Outcome of asking for the phone's position, one per UI state.
enum LocateStatus {
  ok,
  notAsked,
  denied,
  deniedForever,
  servicesOff,
  timeout,
  error,
}

class LocateResult {
  const LocateResult(
    this.status, {
    this.lat = 0,
    this.lng = 0,
    this.accuracyM,
    this.nameTh,
    this.isManual = false,
  });
  final LocateStatus status;
  final double lat;
  final double lng;
  final double? accuracyM;
  final String? nameTh;
  final bool isManual;

  bool get ok => status == LocateStatus.ok;

  /// Worse than 200 m: show the fix, but say it may be off. Manual fixes are never low accuracy.
  bool get lowAccuracy => !isManual && (accuracyM ?? 0) > 200;
}

/// Seam over geolocator, so tests and screenshots can stage each
/// permission state. Never throws.
class Locator {
  const Locator();

  static const _quick = Duration(seconds: 3);

  Future<bool> servicesEnabled() =>
      Geolocator.isLocationServiceEnabled().timeout(_quick);
  Future<LocationPermission> permission() =>
      Geolocator.checkPermission().timeout(_quick);
  Future<LocationPermission> request() => Geolocator.requestPermission();
  Future<Position> position() => Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 10),
    ),
  );
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// The phone's position. Without [prompt], a permission that was never
  /// asked comes back as [LocateStatus.notAsked] so the caller can explain
  /// why first; [askedBefore] turns that into [LocateStatus.denied] so the
  /// OS prompt never loops.
  Future<LocateResult> locate({
    required bool prompt,
    bool askedBefore = false,
  }) async {
    try {
      if (!await servicesEnabled())
        return const LocateResult(LocateStatus.servicesOff);
      var p = await permission();
      if (p == LocationPermission.deniedForever)
        return const LocateResult(LocateStatus.deniedForever);
      if (p == LocationPermission.denied) {
        if (!prompt) {
          return LocateResult(
            askedBefore ? LocateStatus.denied : LocateStatus.notAsked,
          );
        }
        p = await request();
        if (p == LocationPermission.deniedForever)
          return const LocateResult(LocateStatus.deniedForever);
        if (p == LocationPermission.denied)
          return const LocateResult(LocateStatus.denied);
      }
      final pos = await position();
      return LocateResult(
        LocateStatus.ok,
        lat: pos.latitude,
        lng: pos.longitude,
        accuracyM: pos.accuracy,
      );
    } on TimeoutException {
      return const LocateResult(LocateStatus.timeout);
    } catch (_) {
      return const LocateResult(LocateStatus.error);
    }
  }
}

/// Always lands in [status]: screenshots and tests of each permission state.
class StagedLocator extends Locator {
  const StagedLocator(
    this.status, {
    this.lat = 13.7456,
    this.lng = 100.5341,
    this.accuracyM = 25,
  });
  final LocateStatus status;
  final double lat;
  final double lng;
  final double accuracyM;

  @override
  Future<LocateResult> locate({
    required bool prompt,
    bool askedBefore = false,
  }) async => status == LocateStatus.ok
      ? LocateResult(status, lat: lat, lng: lng, accuracyM: accuracyM)
      : LocateResult(
          status == LocateStatus.notAsked && (prompt || askedBefore)
              ? LocateStatus.denied
              : status,
        );

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

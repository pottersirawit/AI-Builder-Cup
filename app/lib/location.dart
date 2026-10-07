import 'package:geolocator/geolocator.dart';

/// Ratchadaphisek Rd at Soi Lat Phrao 32: the demo scenario's flood spot,
/// used when GPS is off, denied or slow.
const fallbackSpot = (lat: 13.8063, lng: 100.5737, nameTh: 'ถ.รัชดาภิเษก หน้าซอยลาดพร้าว 32');

/// Where a report is pinned, and how we know.
class Fix {
  const Fix({required this.lat, required this.lng, required this.fromGps, required this.noteTh});
  final double lat;
  final double lng;
  final bool fromGps;

  /// Place name, or why the fallback was used.
  final String noteTh;
}

Fix _fallback(String why) =>
    Fix(lat: fallbackSpot.lat, lng: fallbackSpot.lng, fromGps: false, noteTh: why);

/// Current position with permission handling; never throws.
Future<Fix> currentFix() async {
  try {
    // Non-interactive calls get a deadline; the permission prompt does not.
    const quick = Duration(seconds: 3);
    if (!await Geolocator.isLocationServiceEnabled().timeout(quick)) return _fallback('GPS ปิดอยู่');
    var p = await Geolocator.checkPermission().timeout(quick);
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      return _fallback('ไม่ได้อนุญาตให้ใช้ตำแหน่ง');
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
    final near = Geolocator.distanceBetween(
            pos.latitude, pos.longitude, fallbackSpot.lat, fallbackSpot.lng) <
        400;
    return Fix(
      lat: pos.latitude,
      lng: pos.longitude,
      fromGps: true,
      noteTh: near ? fallbackSpot.nameTh : 'ตำแหน่งปัจจุบัน',
    );
  } catch (_) {
    return _fallback('หาตำแหน่งไม่ได้');
  }
}

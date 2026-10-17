import 'l10n/l10n.dart';

// Bangkok (UTC+7, no DST) time helpers. The app always shows Bangkok time
// regardless of the device time zone, so demo screenshots match the scenario.

const _bkkOffset = Duration(hours: 7);

DateTime toBangkok(DateTime t) => t.toUtc().add(_bkkOffset);

String _two(int n) => n.toString().padLeft(2, '0');

String hhmm(DateTime t) {
  final b = toBangkok(t);
  return '${_two(b.hour)}:${_two(b.minute)}';
}

/// ISO-8601 with +07:00, e.g. 2026-09-29T16:45:00+07:00.
String isoBangkok(DateTime t) {
  final b = toBangkok(t);
  return '${b.year}-${_two(b.month)}-${_two(b.day)}'
      'T${_two(b.hour)}:${_two(b.minute)}:00+07:00';
}

/// [hour]:[minute] Bangkok time on the Bangkok day of [day].
DateTime bangkokAt(DateTime day, int hour, int minute) {
  final b = toBangkok(day);
  return DateTime.utc(
    b.year,
    b.month,
    b.day,
    hour,
    minute,
  ).subtract(_bkkOffset);
}

/// The Bangkok date of [t], YYYY-MM-DD.
String isoDay(DateTime t) {
  final b = toBangkok(t);
  return '${b.year}-${_two(b.month)}-${_two(b.day)}';
}

int dayOfMonth(DateTime t) => toBangkok(t).day;

String monthShort(AppLocalizations l, DateTime t) =>
    l.monthShort('${toBangkok(t).month}');

/// e.g. "เสาร์ 3 ต.ค. 19:00" or "Sat 3 Oct 19:00"
String dayTime(AppLocalizations l, DateTime t) {
  final b = toBangkok(t);
  return '${l.weekdayName('${b.weekday}')} ${b.day} ${monthShort(l, t)} ${hhmm(t)}';
}

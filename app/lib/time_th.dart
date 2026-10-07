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

const _monthsShortTh = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];
const _weekdaysTh = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัส', 'ศุกร์', 'เสาร์', 'อาทิตย์'];

String monthShortTh(DateTime t) => _monthsShortTh[toBangkok(t).month - 1];
int dayOfMonth(DateTime t) => toBangkok(t).day;

/// e.g. "เสาร์ 3 ต.ค. 19:00"
String dayTimeTh(DateTime t) {
  final b = toBangkok(t);
  return '${_weekdaysTh[b.weekday - 1]} ${b.day} ${_monthsShortTh[b.month - 1]} ${hhmm(t)}';
}

import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';

/// Words and icons the design system uses for domain values.
extension TravelModeLabels on TravelMode {
  String get labelTh => switch (this) {
        TravelMode.car => 'รถยนต์',
        TravelMode.transit => 'BTS / MRT',
        TravelMode.moto => 'มอเตอร์ไซค์',
      };

  /// Fits a pass segment.
  String get shortTh => switch (this) {
        TravelMode.car => 'รถยนต์',
        TravelMode.transit => 'รถไฟฟ้า',
        TravelMode.moto => 'มอไซค์',
      };

  IconData get icon => switch (this) {
        TravelMode.car => Symbols.directions_car_rounded,
        TravelMode.transit => Symbols.train_rounded,
        TravelMode.moto => Symbols.two_wheeler_rounded,
      };
}

extension RiskLabels on Risk {
  String get labelTh => switch (this) {
        Risk.low => 'เสี่ยงต่ำ',
        Risk.medium => 'เสี่ยงกลาง',
        Risk.high => 'เสี่ยงสูง',
      };

  IconData get icon => switch (this) {
        Risk.low => Symbols.check_circle_rounded,
        Risk.medium => Symbols.error_rounded,
        Risk.high => Symbols.warning_rounded,
      };
}

/// Departure-board status words: what the row means for you, in two syllables.
String boardStatus(Verdict v, Risk r) => switch (v) {
      Verdict.leaveNow => r == Risk.low ? 'ออกได้' : 'เผื่อเวลา',
      Verdict.wait => 'รอก่อน',
      Verdict.switchMode => 'เปลี่ยนทาง',
      Verdict.dontGo => 'งดไป',
    };

/// Risk a verdict implies for chips when the API gives only the verdict.
Risk riskOfVerdict(Verdict v) => switch (v) {
      Verdict.leaveNow => Risk.low,
      Verdict.wait || Verdict.switchMode => Risk.medium,
      Verdict.dontGo => Risk.high,
    };

Risk riskOfHomeLevel(HomeLevel l) => switch (l) {
      HomeLevel.normal => Risk.low,
      HomeLevel.watch => Risk.medium,
      HomeLevel.danger => Risk.high,
    };

String homeLevelLabel(HomeLevel l) => switch (l) {
      HomeLevel.normal => 'ปกติ',
      HomeLevel.watch => 'จับตา',
      HomeLevel.danger => 'อันตราย',
    };

String passableLabel(String v) => switch (v) {
      'yes' => 'ผ่านได้',
      'slow' => 'ผ่านช้า ๆ',
      _ => 'ไม่ควรผ่าน',
    };

Risk passableRisk(String v) => switch (v) {
      'yes' => Risk.low,
      'slow' => Risk.medium,
      _ => Risk.high,
    };

String percent(double confidence) => '${(confidence * 100).round()}%';

/// "~230 ม." or "~1.5 กม.": a GPS error radius as a person would say it.
String approxDistanceTh(double meters) {
  if (meters < 1000) return '~${(meters / 10).round() * 10} ม.';
  final km = meters / 1000;
  if (km >= 10) return '~${km.round()} กม.';
  final tenths = (km * 10).round();
  return '~${tenths % 10 == 0 ? tenths ~/ 10 : tenths / 10} กม.';
}

String sourceTitle(String source) => switch (source) {
      'calendar' => 'Google Calendar',
      'gmail' => 'Gmail',
      'routine' => 'สถานที่ของฉัน',
      _ => 'พิมพ์ถามเอง',
    };

IconData sourceIcon(String source) => switch (source) {
      'calendar' => Symbols.calendar_month_rounded,
      'gmail' => Symbols.mail_rounded,
      'routine' => Symbols.repeat_rounded,
      _ => Symbols.keyboard_rounded,
    };

/// Icon keys a saved place can carry, in picker order.
const placeIconKeys = ['home', 'work', 'shop', 'food', 'gym', 'school', 'family', 'stadium', 'train', 'pin'];

IconData placeIcon(String key) => switch (key) {
      'home' => Symbols.home_rounded,
      'work' => Symbols.work_rounded,
      'shop' => Symbols.storefront_rounded,
      'food' => Symbols.restaurant_rounded,
      'gym' => Symbols.fitness_center_rounded,
      'school' => Symbols.school_rounded,
      'family' => Symbols.favorite_rounded,
      'stadium' => Symbols.stadium_rounded,
      'train' => Symbols.train_rounded,
      _ => Symbols.location_on_rounded,
    };

/// Thai weekday initials, Monday first (ISO weekday - 1).
const weekdayInitialsTh = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];

/// "จ–ศ", "ทุกวัน", or the initials joined.
String workDaysLabel(List<int> days) {
  final d = [...days]..sort();
  if (d.length == 7) return 'ทุกวัน';
  if (d.join() == '12345') return 'จ–ศ';
  return d.map((x) => weekdayInitialsTh[x - 1]).join(' ');
}

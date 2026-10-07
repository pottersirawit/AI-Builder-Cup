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

String sourceTitle(String source) => switch (source) {
      'calendar' => 'Google Calendar',
      'gmail' => 'Gmail',
      _ => 'พิมพ์ถามเอง',
    };

IconData sourceIcon(String source) => switch (source) {
      'calendar' => Symbols.calendar_month_rounded,
      'gmail' => Symbols.mail_rounded,
      _ => Symbols.keyboard_rounded,
    };

import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/l10n.dart';
import '../models.dart';

/// Words and icons the design system uses for domain values.
extension TravelModeLabels on TravelMode {
  IconData get icon => switch (this) {
    TravelMode.car => Symbols.directions_car_rounded,
    TravelMode.transit => Symbols.train_rounded,
    TravelMode.moto => Symbols.two_wheeler_rounded,
  };
}

extension RiskLabels on Risk {
  IconData get icon => switch (this) {
    Risk.low => Symbols.check_circle_rounded,
    Risk.medium => Symbols.error_rounded,
    Risk.high => Symbols.warning_rounded,
  };
}

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

Risk passableRisk(String v) => switch (v) {
  'yes' => Risk.low,
  'slow' => Risk.medium,
  _ => Risk.high,
};

String percent(double confidence) => '${(confidence * 100).round()}%';

IconData sourceIcon(String source) => switch (source) {
  'calendar' => Symbols.calendar_month_rounded,
  'gmail' => Symbols.mail_rounded,
  'routine' => Symbols.repeat_rounded,
  _ => Symbols.keyboard_rounded,
};

/// Icon keys a saved place can carry, in picker order.
const placeIconKeys = [
  'home',
  'work',
  'shop',
  'food',
  'gym',
  'school',
  'family',
  'stadium',
  'train',
  'pin',
];

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

// ---- Localized words ----

extension TravelModeText on TravelMode {
  String label(AppLocalizations l) => switch (this) {
    TravelMode.car => l.modeCar,
    TravelMode.transit => l.modeTransit,
    TravelMode.moto => l.modeMoto,
  };

  /// Fits a pass segment.
  String shortLabel(AppLocalizations l) => switch (this) {
    TravelMode.car => l.modeCarShort,
    TravelMode.transit => l.modeTransitShort,
    TravelMode.moto => l.modeMotoShort,
  };
}

extension RiskText on Risk {
  String label(AppLocalizations l) => switch (this) {
    Risk.low => l.riskLow,
    Risk.medium => l.riskMedium,
    Risk.high => l.riskHigh,
  };
}

String boardStatusText(AppLocalizations l, Verdict v, Risk r) => switch (v) {
  Verdict.leaveNow => r == Risk.low ? l.boardLeaveOk : l.boardLeaveWithBuffer,
  Verdict.wait => l.boardWait,
  Verdict.switchMode => l.boardSwitchMode,
  Verdict.dontGo => l.boardDontGo,
};

String homeLevelText(AppLocalizations l, HomeLevel level) => switch (level) {
  HomeLevel.normal => l.homeLevelNormal,
  HomeLevel.watch => l.homeLevelWatch,
  HomeLevel.danger => l.homeLevelDanger,
};

String passableText(AppLocalizations l, String v) => switch (v) {
  'yes' => l.passableYes,
  'slow' => l.passableSlow,
  _ => l.passableNo,
};

/// "~230 m" or "~1.5 km": a GPS error radius as a person would say it.
String approxDistance(AppLocalizations l, double meters) {
  if (meters < 1000) return l.approxMeters((meters / 10).round() * 10);
  final km = meters / 1000;
  if (km >= 10) return l.approxKm('${km.round()}');
  final tenths = (km * 10).round();
  return l.approxKm('${tenths % 10 == 0 ? tenths ~/ 10 : tenths / 10}');
}

/// Weekday initial for an ISO weekday (1 = Monday).
String weekdayInitial(AppLocalizations l, int isoWeekday) =>
    l.weekdayInitial('$isoWeekday');

/// "Mon–Fri", "Every day", or the initials joined.
String workDaysText(AppLocalizations l, List<int> days) {
  final d = [...days]..sort();
  if (d.length == 7) return l.workDaysEveryday;
  if (d.join() == '12345') return l.workDaysWeekdays;
  return d.map((x) => weekdayInitial(l, x)).join(' ');
}

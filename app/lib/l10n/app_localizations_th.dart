// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get appTitle => 'ฝนตกไหม';

  @override
  String get settingsLanguage => 'ภาษา';

  @override
  String get settingsLanguageThai => 'ไทย';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get shellTabTrip => 'เดินทาง';

  @override
  String get shellTabReport => 'แจ้งน้ำท่วม';

  @override
  String get shellTabHome => 'บ้าน';

  @override
  String get designBack => 'กลับ';

  @override
  String get designAskTooltip => 'ถาม';

  @override
  String get designAskHint => 'ไปไหน กี่โมง? เช่น ห้าโมงไปสยาม';

  @override
  String get designDismissBanner => 'ปิดแจ้งเตือน';

  @override
  String get designRetry => 'ลองอีกครั้ง';

  @override
  String get designLoadingAnswer => 'กำลังโหลดคำตอบ';

  @override
  String get boardNoteTransitCrowded => 'ขบวนไม่สนฝน แต่ชานชาลาแน่น เผื่อเวลา';

  @override
  String get boardNoteDry => 'ไม่โดนฝนระหว่างทาง';

  @override
  String get boardNoteCarHeavy => 'ฝนหนัก น้ำรอระบาย รถติดสะสม';

  @override
  String get boardNoteCarDrizzle => 'เจอฝนปรอยช่วงท้าย ขับช้าลง';

  @override
  String get boardNoteBeatRain => 'ถึงก่อนฝน';

  @override
  String get boardNoteMotoHeavy => 'ฝนหนักกลางทาง มอเตอร์ไซค์ไม่ควรไป';

  @override
  String get boardNoteMotoTight => 'ทันพอดี ช้ากว่านี้จะโดนฝน';

  @override
  String boardHeadlineLeave(String time) {
    return 'ออก $time ได้';
  }

  @override
  String get boardHeadlineWait => 'อย่าเพิ่งออก';

  @override
  String get boardHeadlineSwitchTransit => 'เปลี่ยนเป็น BTS ดีกว่า';

  @override
  String get homeLoadErrorTitle => 'โหลดทริปไม่ได้';

  @override
  String get homeLoadErrorBody =>
      'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้และไม่มีข้อมูลตัวอย่างในเครื่อง ตรวจอินเทอร์เน็ตแล้วลองอีกครั้ง';

  @override
  String get homeSeeWhatToDo => 'ดูสิ่งที่ต้องทำตอนนี้';

  @override
  String get homeDecideErrorTitle => 'ยังตัดสินไม่ได้';

  @override
  String get homeDecideErrorBody =>
      'ติดต่อเซิร์ฟเวอร์ไม่ได้ ตรวจอินเทอร์เน็ตแล้วลองอีกครั้ง';

  @override
  String get homeSeeReasons => 'ดูเหตุผลและทางเลือก';

  @override
  String get homeAskMore => 'ถามต่อ';

  @override
  String get homeNoTripTitle => 'ยังไม่มีทริป';

  @override
  String get homeNoTripBody =>
      'ตั้งบ้านไว้ แอปจะเตือนก่อนเวลาเลิกงานทุกวัน หรือพิมพ์ถามด้านบนได้เลย';

  @override
  String get homeSetHome => 'ตั้งบ้าน';

  @override
  String get homeSetWork => 'ตั้งที่ทำงาน';

  @override
  String get homeNoHomeTripTitle => 'วันนี้ไม่มีทริปกลับบ้าน';

  @override
  String get homeWfhBody =>
      'ทำงานที่บ้าน แอปจะเตือนเฉพาะทริปอื่น พิมพ์ถามด้านล่างได้เลย เช่น “ห้าโมงไปสยาม”';

  @override
  String get homeNotWorkdayBody =>
      'วันนี้ไม่ใช่วันทำงาน ถ้าจะออกไปไหน พิมพ์ถามด้านล่างได้เลย';

  @override
  String get homePastCommuteBody =>
      'เลยเวลากลับบ้านปกติมาแล้ว พรุ่งนี้แอปจะเช็กให้ก่อนเลิกงาน';

  @override
  String homeGpsInaccurate(String distance) {
    return 'ตำแหน่งอาจคลาดเคลื่อน $distance';
  }

  @override
  String get homePinMyself => 'ปักหมุดเอง';

  @override
  String get homeSetHomeHint => 'ตั้งบ้านเพื่อให้เตือนตอนกลับ';

  @override
  String get homeSetWorkHint => 'ตั้งที่ทำงานเพื่อให้เตือนได้แม่นขึ้น';

  @override
  String get homeWfhNotice => 'ทำงานที่บ้าน — แอปจะเตือนเฉพาะทริปอื่น';

  @override
  String get homeCalendarHint => 'เชื่อม Calendar เพื่อให้แอปเห็นนัด';

  @override
  String get homeConnect => 'เชื่อมต่อ';

  @override
  String get homeNoCalendarSoon => 'ไม่มีนัดที่มีสถานที่ใน 24 ชม.';

  @override
  String get homeAskHintHero => 'ไปไหน กี่โมง?';

  @override
  String get homeGreetingDemo => 'สวัสดีมิว';

  @override
  String get homeGreeting => 'สวัสดี';

  @override
  String get homeCurrentPlace => 'ตำแหน่งตอนนี้';

  @override
  String get homeCurrentPlaceAlt => 'ตำแหน่งปัจจุบัน';

  @override
  String homeHereSemantics(String name) {
    return 'ตำแหน่งตอนนี้ $name แตะเพื่อปักหมุดตำแหน่งเอง';
  }

  @override
  String get homeSettings => 'ตั้งค่า';

  @override
  String homeRouteTo(String place) {
    return 'ทางกลับ$place';
  }

  @override
  String homePreview(String time) {
    return 'พรีวิว $time';
  }

  @override
  String homeDepart(String time) {
    return 'ออก $time';
  }

  @override
  String get homeArriveCaption => 'ถึง';

  @override
  String homeModeEta(String mode, int minutes) {
    return '$mode · $minutes นาที';
  }

  @override
  String get homeNextTrips => 'ทริปถัดไป';

  @override
  String homeUnresolvedSubtitle(String location) {
    return '“$location” · แตะเพื่อเลือกสถานที่';
  }

  @override
  String get homeUnresolvedStatus => 'ไม่รู้ว่าที่ไหน';

  @override
  String homeFutureSubtitle(String place) {
    return '$place · จะเตือนวันเดินทางว่าออกกี่โมงดี';
  }

  @override
  String get homeFutureStatus => 'รอวัน';

  @override
  String get homeTonightTitle => 'ที่บ้านคืนนี้';

  @override
  String get homeNoCanalStation => 'ไม่มีสถานีวัดระดับคลองใกล้บ้าน';

  @override
  String get homeOutOfArea => 'นอกพื้นที่ที่รองรับ · มีเฉพาะข้อมูลฝน';

  @override
  String homeCanalLevel(String canal, String level, String bank) {
    return '$canal $level จาก $bank ม.';
  }

  @override
  String get homeQuickAsk => 'ถามเร็ว';

  @override
  String get homeQuestionHomeNow => 'กลับบ้านตอนนี้';

  @override
  String homeQuestionToNow(String place) {
    return 'ไป$placeตอนนี้';
  }

  @override
  String homeSetPlaceTooltip(String label) {
    return 'ตั้ง$label';
  }

  @override
  String get homeDefaultPlaceHome => 'บ้าน';

  @override
  String get homeDefaultPlaceWork => 'ที่ทำงาน';

  @override
  String get homeDefaultPlaceSiam => 'สยาม';

  @override
  String get homeDefaultPlaceThonglor => 'ทองหล่อ';

  @override
  String get homeDefaultPlaceImpact => 'อิมแพ็ค';

  @override
  String homeUsingPinned(String name) {
    return 'ใช้ “$name” เป็นตำแหน่งตอนนี้แล้ว';
  }

  @override
  String get homeBackToGps => 'กลับไปใช้ GPS';

  @override
  String get homeTripGoHome => 'กลับบ้าน';

  @override
  String get homeFromHereSemantics => 'กลับบ้าน จากตำแหน่งตอนนี้';

  @override
  String get homeFromHereTitle => 'กลับบ้าน · จากตำแหน่งตอนนี้';

  @override
  String homeLeaveAround(String time) {
    return 'ออกราว $time';
  }

  @override
  String get homeCheckRainHome => 'เช็กฝนบนทางกลับบ้าน';

  @override
  String get homeLocationOnTap =>
      'แอปใช้ตำแหน่งตอนกดเท่านั้น เพื่อเป็นจุดเริ่มต้นของทาง';

  @override
  String get homeCheckWayHome => 'เช็กทางกลับบ้าน';

  @override
  String get askSuggestion1 => 'ถ้ารอถึงสองทุ่มค่อยกลับล่ะ';

  @override
  String get askSuggestion2 => 'ไป BTS แทนดีไหม';

  @override
  String get askOpeningPlain => 'อยากรู้อะไรเรื่องฝนกับการเดินทาง ถามได้เลย';

  @override
  String askOpeningWith(String headline) {
    return 'ตอนนี้แนะนำ “$headline” นะ มีอะไรอยากถามต่อไหม';
  }

  @override
  String get askFailed =>
      'ตอบไม่ได้ เพราะติดต่อเซิร์ฟเวอร์ไม่ได้ ตรวจอินเทอร์เน็ตแล้วถามใหม่';

  @override
  String get askTitle => 'ถามต่อ';

  @override
  String get askInputHint => 'พิมพ์คำถาม เช่น ถ้าไปมอเตอร์ไซค์ล่ะ';

  @override
  String get askRetry => 'ถามใหม่';

  @override
  String partsQuestion(String question) {
    return 'คำถาม: “$question”';
  }

  @override
  String partsArriveBy(String time) {
    return 'ถึงก่อน $time';
  }

  @override
  String get partsChecking => 'กำลังตรวจเวลานี้…';

  @override
  String get partsPreviewEstimate =>
      'ประเมินจากฝนบนเส้นทาง ปล่อยนิ้วเพื่อยืนยัน';

  @override
  String partsTakesMin(int minutes) {
    return 'ใช้เวลา $minutes นาที';
  }

  @override
  String get partsSegLeave => 'ออก';

  @override
  String get partsSegArrive => 'ถึง';

  @override
  String get partsSegMode => 'โหมด';

  @override
  String get partsSegConfidence => 'มั่นใจ';

  @override
  String get partsNow => 'ตอนนี้';

  @override
  String get partsDragHint => 'ลากหมุดเพื่อลองเวลาออก';

  @override
  String get partsLeaveNow => 'ออกตอนนี้';

  @override
  String get partsOutOfArea => 'นอกพื้นที่ที่รองรับ';

  @override
  String get partsRainToday => 'ฝนวันนี้';

  @override
  String partsMm(int mm) {
    return '$mm มม.';
  }

  @override
  String get partsFloodSpots => 'จุดเสี่ยง 2 กม.';

  @override
  String get partsReports => 'รายงาน 500 ม.';

  @override
  String get partsCanalLevel => 'ระดับคลอง';

  @override
  String partsCanalLevelValue(String level, String bank) {
    return '$level/$bank ม.';
  }

  @override
  String get partsCanalRise => 'ขึ้นใน 2 ชม.';

  @override
  String partsCm(int cm) {
    return '$cm ซม.';
  }

  @override
  String get partsToBank => 'ถึงตลิ่ง';

  @override
  String get partsAtBank => 'ถึงแล้ว';

  @override
  String partsCmLeft(int cm) {
    return 'อีก $cm ซม.';
  }

  @override
  String get partsNoCanalStation => 'ไม่มีสถานีวัดระดับคลองใกล้บ้าน';

  @override
  String get partsOutsideBangkok =>
      'บ้านอยู่นอกกรุงเทพฯ ข้อมูลระดับคลองและจุดน้ำท่วมยังไม่ครอบคลุม แอปเตือนได้เฉพาะฝน';

  @override
  String partsDemoClockSemantic(String time) {
    return 'เวลาสาธิต $time แตะเพื่อเปลี่ยน';
  }

  @override
  String get partsRealTime => 'เวลาจริง';

  @override
  String get partsDemoTime => 'เวลาสาธิต';

  @override
  String get partsDemoReplay =>
      'เล่นซ้ำพายุ อังคาร 29 ก.ย. 2026 · ส่งเป็น X-Demo-Clock';

  @override
  String get partsRealTimeNoHeader => 'เวลาจริง (ไม่ส่ง header)';

  @override
  String get partsPreset1610 => 'ก่อนเลิกงาน ฝนยังไม่มา';

  @override
  String get partsPreset1852 => 'พายุบนรัชดา น้ำรอระบาย';

  @override
  String get partsPreset2140 => 'โหมดน้ำท่วมที่บ้าน';

  @override
  String get partsPresetDevice => 'ใช้นาฬิกาเครื่อง';

  @override
  String partsKindLabel(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'home': 'บ้าน',
      'work': 'ที่ทำงาน',
      'other': 'สถานที่',
    });
    return '$_temp0';
  }

  @override
  String get partsNeedsFirst => 'ต้องรู้ก่อนตอบ';

  @override
  String partsNeedsWhere(String place) {
    return 'ยังไม่รู้ว่า$placeอยู่ไหน';
  }

  @override
  String get partsNeedsSaveOnce =>
      'บันทึกไว้ครั้งเดียว แล้วแอปจะตอบคำถามนี้ต่อทันที';

  @override
  String get partsUseMyLocation => 'ใช้ตำแหน่งตอนนี้';

  @override
  String get partsSearch => 'ค้นหา';

  @override
  String get partsWhichPlace => 'หมายถึงที่ไหน';

  @override
  String partsNotFound(String query) {
    return 'หา “$query” ไม่เจอ ลองค้นด้วยชื่ออื่น';
  }

  @override
  String partsSimilar(String query) {
    return 'เจอหลายที่ที่ชื่อคล้าย “$query”';
  }

  @override
  String partsSearchFor(String query) {
    return 'ค้นหา “$query”';
  }

  @override
  String get partsNoneOfThese => 'ไม่ใช่ทั้งหมด · ค้นหาเอง';

  @override
  String marksSourceSemantic(String text) {
    return 'แหล่งข้อมูล: $text';
  }

  @override
  String get marksSample => 'ข้อมูลตัวอย่าง';

  @override
  String get marksSampleSemantic => 'ข้อมูลตัวอย่าง เชื่อมต่อเซิร์ฟเวอร์ไม่ได้';

  @override
  String get marksDemo => 'เดโม';

  @override
  String get marksDemoSemantic => 'โปรไฟล์เดโม ข้อมูลจำลอง';

  @override
  String get marksConfidence => 'มั่นใจ';

  @override
  String marksConfidenceSemantic(String percent) {
    return 'ความมั่นใจ $percent';
  }

  @override
  String get marksGeneratedByAi => 'AI วิเคราะห์ให้';

  @override
  String get marksGeneratedByFallback => 'ใช้การคำนวณสำรอง · AI ไม่ตอบในรอบนี้';

  @override
  String rainBandLeave(String time) {
    return 'ออก $time';
  }

  @override
  String get rainBandSlider => 'เวลาออกเดินทาง ลากเพื่อลองเวลาอื่น';

  @override
  String get galleryTitle => 'ระบบดีไซน์';

  @override
  String get gallerySubtitle => 'ฝนตกไหม · โทเคนและคอมโพเนนต์';

  @override
  String get galleryClear => 'ฟ้าใส';

  @override
  String get galleryStorm => 'พายุ';

  @override
  String get galleryFlood => 'น้ำท่วม';

  @override
  String get gallerySkySwatches => 'พื้นท้องฟ้า';

  @override
  String get galleryPassPerSky => 'พาสในแต่ละท้องฟ้า';

  @override
  String get galleryColors => 'สี';

  @override
  String get galleryType => 'ตัวอักษร · Chakra Petch';

  @override
  String get gallerySpace => 'ระยะ · รัศมี · เงา';

  @override
  String get galleryMotion => 'การเคลื่อนไหว';

  @override
  String get galleryRainBand => 'RainBand · ลากได้';

  @override
  String get galleryRerank => 'จัดอันดับใหม่';

  @override
  String get galleryPlaces => 'สถานที่ · Notice · ConnectRow';

  @override
  String get galleryNoticeWork => 'ตั้งที่ทำงานเพื่อให้เตือนได้แม่นขึ้น';

  @override
  String get galleryNoticeOff => 'ปิดการแจ้งเตือนอยู่ แอปเตือนก่อนออกไม่ได้';

  @override
  String get galleryOpenSettings => 'เปิดการตั้งค่า';

  @override
  String get galleryNoticeCalendar => 'เชื่อม Calendar เพื่อให้แอปเห็นนัด';

  @override
  String get galleryCalendarDetail => 'เฉพาะนัดที่มีสถานที่';

  @override
  String get galleryCalendarAccount => 'miw.demo@gmail.com · บัญชีจำลอง';

  @override
  String get galleryRiskChips => 'RiskChip · ConfidenceMeter · SourceLabel';

  @override
  String get galleryNotifTitle => 'ออกก่อน 16:45 · กินข้าวเย็นกับที่บ้าน';

  @override
  String get galleryNotifBody =>
      'ฝนถึงพระราม 4 ประมาณ 17:30 ถ้าออกตอนนี้ถึงบ้านก่อนฝน';

  @override
  String get galleryStateLoading => 'สถานะ: กำลังโหลด';

  @override
  String get galleryStateError => 'สถานะ: ผิดพลาด';

  @override
  String get galleryStateEmpty => 'สถานะ: ว่าง';

  @override
  String get galleryErrorTitle => 'โหลดทริปไม่ได้';

  @override
  String get galleryErrorMessage =>
      'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ตรวจอินเทอร์เน็ตแล้วลองอีกครั้ง';

  @override
  String get galleryEmptyTitle => 'วันนี้ยังไม่มีทริป';

  @override
  String get galleryEmptyMessage => 'พิมพ์ถามได้เลย เช่น “ห้าโมงไปสยาม”';

  @override
  String get galleryConnectCalendar => 'เชื่อม Calendar';

  @override
  String get galleryRowTransitSub => 'ศาลาแดง → ลาดพร้าว ไม่ต้องพกร่ม';

  @override
  String get galleryRowCarSub => 'ถึงก่อนฝน ทันนัด 18:30';

  @override
  String get galleryRowMotoSub => 'ทันพอดี ช้ากว่านี้จะโดนฝน';

  @override
  String galleryRowTitle(String mode, int minutes) {
    return '$mode · $minutes นาที';
  }

  @override
  String get galleryHeadClear => 'ออกก่อน 16:45';

  @override
  String get galleryHeadStorm => 'อย่าเพิ่งออก';

  @override
  String get galleryHeadFlood => 'น้ำจะถึงหน้าบ้านใน 40 นาที';

  @override
  String get galleryColorPass => 'พาส';

  @override
  String get galleryColorRain => 'ฝน (ไม่มี → หนัก)';

  @override
  String get galleryColorRisk => 'ความเสี่ยง';

  @override
  String get galleryTypeVerdict => 'คำตัดสิน';

  @override
  String get galleryTypeSampleLong => 'ฝนถึงพระราม 4 ราว 17:30 น้ำขัง 25 ซม.';

  @override
  String get galleryTypeTabular =>
      'ตัวเลขเท่ากัน (Petch Tabular) เทียบตัวเลขปกติ';

  @override
  String get galleryMotionTap => 'สถานะปุ่มและการเลือก';

  @override
  String get galleryMotionFlap => 'คำตัดสินพลิกตัวอักษร';

  @override
  String get galleryMotionRerank => 'กระดานเลื่อนอันดับ';

  @override
  String get galleryMotionEnter => 'แจ้งเตือนเลื่อนลง';

  @override
  String get galleryMotionSky => 'สีท้องฟ้าเปลี่ยนสถานะ';

  @override
  String get galleryMotionCurves =>
      'เส้นโค้ง: standard (0.2, 0, 0, 1) · emphasized decelerate (0.05, 0.7, 0.1, 1)';

  @override
  String get galleryMotionReduced =>
      'ลดการเคลื่อนไหวเปิดอยู่: ทุกระยะเวลาเป็น 0';

  @override
  String get galleryFlipDemo => 'ออก 16:45 ได้';

  @override
  String get galleryFlip => 'พลิก';

  @override
  String galleryModeStatus(int minutes, String status) {
    return '$minutes น. · $status';
  }

  @override
  String get placeKindHome => 'บ้าน';

  @override
  String get placeKindWork => 'ที่ทำงาน';

  @override
  String get placeKindOther => 'สถานที่';

  @override
  String get placeDemoSiam => 'สยาม';

  @override
  String get placeDemoThonglor => 'ทองหล่อ';

  @override
  String get placeDemoImpact => 'อิมแพ็ค';

  @override
  String get locationGpsOff => 'GPS ปิดอยู่';

  @override
  String get locationDenied => 'ไม่ได้อนุญาตให้ใช้ตำแหน่ง';

  @override
  String get locationUnavailable => 'หาตำแหน่งไม่ได้';

  @override
  String get locationCurrent => 'ตำแหน่งปัจจุบัน';

  @override
  String get locationFallbackSpot => 'ถ.รัชดาภิเษก หน้าซอยลาดพร้าว 32';

  @override
  String placesPinLabel(String lat, String lng) {
    return 'หมุดตำแหน่ง $lat, $lng';
  }

  @override
  String get placesDismiss => 'ปิด';

  @override
  String get placesNotConnected => 'ยังไม่เชื่อมต่อ';

  @override
  String placesNotConnectedDetail(String detail) {
    return 'ยังไม่เชื่อมต่อ · $detail';
  }

  @override
  String get placesConnecting => 'กำลังเชื่อมต่อ…';

  @override
  String get placesConnected => 'เชื่อมต่อแล้ว';

  @override
  String get placesConnectFailed => 'เชื่อมต่อไม่สำเร็จ ลองอีกครั้ง';

  @override
  String get placesComingSoon => 'เร็ว ๆ นี้';

  @override
  String get placesConnect => 'เชื่อมต่อ';

  @override
  String get placesDisconnect => 'ยกเลิก';

  @override
  String get placesRetry => 'ลองอีกครั้ง';

  @override
  String get placesSearching => 'กำลังค้นหา';

  @override
  String get onboardingHeadline => 'ให้แอปเตือนก่อนกลับบ้าน';

  @override
  String get onboardingIntro =>
      'บอกว่าบ้านกับที่ทำงานอยู่ไหน แอปจะเช็กฝนและน้ำท่วมบนทางกลับให้ทุกเย็น และดูความเสี่ยงน้ำท่วมหน้าบ้าน';

  @override
  String get onboardingSkipNote => 'ข้ามไปก่อนก็ได้ ถามเองได้เสมอ';

  @override
  String get onboardingStart => 'เริ่มใช้';

  @override
  String get onboardingSkip => 'ข้ามไปก่อน';

  @override
  String get onboardingDemo => 'ใช้โปรไฟล์เดโม (มิว)';

  @override
  String get onboardingSet => 'ตั้งแล้ว';

  @override
  String get onboardingHomeHint => 'ใช้เตือนก่อนกลับบ้าน และดูน้ำท่วมหน้าบ้าน';

  @override
  String get onboardingWorkHint =>
      'ไม่บังคับ · ทำให้เตือนตอนเลิกงานได้แม่นขึ้น';

  @override
  String onboardingWorkSummary(String name, String days, String time) {
    return '$name · $days ออก $time';
  }

  @override
  String get onboardingUseHere => 'ใช้ตำแหน่งตอนนี้';

  @override
  String get onboardingSearch => 'ค้นหา';

  @override
  String get onboardingEdit => 'แก้ไข';

  @override
  String pickerDeleted(String label) {
    return 'ลบ “$label” แล้ว';
  }

  @override
  String get pickerUndo => 'เลิกทำ';

  @override
  String get pickerTitlePoint => 'เลือกจุด';

  @override
  String pickerTitleMove(String label) {
    return 'ย้าย$label';
  }

  @override
  String get pickerTitleHome => 'ตั้งบ้าน';

  @override
  String get pickerTitleWork => 'ตั้งที่ทำงาน';

  @override
  String get pickerTitleOther => 'เพิ่มสถานที่';

  @override
  String get pickerSubtitle => 'ค้นหา หรือใช้ตำแหน่งตอนนี้';

  @override
  String pickerHintTyping(int count) {
    return 'พิมพ์อย่างน้อย $count ตัวอักษร ชื่อสถานี BTS ห้าง ซอย หรือเขต';
  }

  @override
  String get pickerSearchFailedTitle => 'ค้นหาไม่ได้';

  @override
  String get pickerSearchFailedMessage =>
      'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ และไม่มีรายชื่อสถานที่ในเครื่อง';

  @override
  String pickerNoResultsTitle(String query) {
    return 'ไม่พบ “$query”';
  }

  @override
  String get pickerNoResultsMessage => 'ลองพิมพ์ชื่อสถานี BTS หรือห้าง';

  @override
  String get pickerNoResultsMessageOffline =>
      'ลองพิมพ์ชื่อสถานี BTS หรือห้าง ตอนนี้ค้นได้เฉพาะรายชื่อในเครื่อง';

  @override
  String get pickerUseLocation => 'ใช้ตำแหน่งตอนนี้';

  @override
  String get pickerSearchOnlineAgain => 'ค้นออนไลน์อีกครั้ง';

  @override
  String get pickerOfflineNotice => 'ค้นออนไลน์ไม่ได้ แสดงข้อมูลในเครื่อง';

  @override
  String get pickerOutOfArea => 'นอกพื้นที่';

  @override
  String get pickerSourceGoogle => 'ผลการค้นหาจาก Google Maps';

  @override
  String get pickerSourceLocal => 'สถานี BTS/MRT ห้าง และเขตในกรุงเทพฯ';

  @override
  String get pickerSearchHint => 'ชื่อสถานที่ เช่น BTS อารีย์ หรือ Central';

  @override
  String get pickerClear => 'ล้าง';

  @override
  String get pickerNaming => 'กำลังหาชื่อสถานที่…';

  @override
  String get pickerDroppedPin => 'ตำแหน่งที่ปักหมุด';

  @override
  String get pickerHereNow => 'ตำแหน่งตอนนี้';

  @override
  String get locateBusy => 'กำลังหาตำแหน่ง…';

  @override
  String get locateBusyHint => 'ใช้ GPS ของเครื่อง ไม่เกิน 10 วินาที';

  @override
  String get locateSearchInstead => 'ค้นหาแทน';

  @override
  String get locateIdleHint => 'หาจาก GPS แล้วให้ยืนยันก่อนบันทึก';

  @override
  String get locateAskTitle => 'ขอใช้ตำแหน่งครั้งนี้';

  @override
  String get locateAskMessage =>
      'แอปใช้ตำแหน่งเพื่อหาว่าตรงนี้คือที่ไหนเท่านั้น ไม่เก็บประวัติการเดินทาง';

  @override
  String get locateAllow => 'อนุญาตตำแหน่ง';

  @override
  String get locateDeniedTitle => 'ไม่ได้รับสิทธิ์ตำแหน่ง';

  @override
  String get locateDeniedForeverMessage =>
      'เปิดสิทธิ์ตำแหน่งให้ฝนตกไหมในการตั้งค่าของเครื่อง หรือค้นหาชื่อสถานที่แทน';

  @override
  String get locateDeniedMessage =>
      'อนุญาตได้ในการตั้งค่าของแอป หรือค้นหาชื่อสถานที่แทน';

  @override
  String get locateOpenSettings => 'เปิดการตั้งค่า';

  @override
  String get locateOffTitle => 'ตำแหน่งปิดอยู่';

  @override
  String get locateOffMessage =>
      'เปิดบริการตำแหน่งของเครื่องก่อน หรือค้นหาชื่อสถานที่แทน';

  @override
  String get locateOpenLocationSettings => 'เปิดการตั้งค่าตำแหน่ง';

  @override
  String get locateTimeoutTitle => 'หาตำแหน่งไม่ทันเวลา';

  @override
  String get locateErrorTitle => 'หาตำแหน่งไม่ได้';

  @override
  String get locateWeakMessage =>
      'สัญญาณ GPS อ่อน ลองอีกครั้งใกล้หน้าต่าง หรือค้นหาชื่อสถานที่แทน';

  @override
  String sheetEdit(String label) {
    return 'แก้$label';
  }

  @override
  String sheetConfirm(String label) {
    return 'ยืนยัน$label';
  }

  @override
  String get sheetSourceGps => 'ตำแหน่งจาก GPS';

  @override
  String get sheetSourceSaved => 'บันทึกไว้ในเครื่อง';

  @override
  String get sheetSourceLocal => 'ข้อมูลในเครื่อง';

  @override
  String get sheetOutOfArea =>
      'นอกพื้นที่ที่แอปรองรับ ยังเตือนฝนได้ แต่ไม่มีข้อมูลจุดน้ำท่วมและระดับคลอง';

  @override
  String sheetLowAccuracy(String distance) {
    return 'ตำแหน่งอาจคลาดเคลื่อน $distance';
  }

  @override
  String get sheetWorkFromHome => 'ทำงานที่บ้าน — แอปจะเตือนเฉพาะทริปอื่น';

  @override
  String sheetDuplicate(String label) {
    return 'ใกล้กับ ‘$label’ ที่บันทึกไว้';
  }

  @override
  String get sheetNameLabel => 'ชื่อที่เรียก';

  @override
  String get sheetIcon => 'ไอคอน';

  @override
  String get sheetWorkDays => 'วันทำงาน';

  @override
  String get sheetLeaveTime => 'เวลาออกจากที่ทำงานปกติ';

  @override
  String get sheetLeaveHint => 'แอปเช็กทางกลับบ้านให้ก่อนเวลานี้';

  @override
  String get sheetUpdateExisting => 'อัปเดตที่เดิม';

  @override
  String get sheetSaveSeparate => 'บันทึกแยก';

  @override
  String get sheetSave => 'บันทึก';

  @override
  String get sheetMove => 'ย้ายตำแหน่ง';

  @override
  String sheetDelete(String label) {
    return 'ลบ$label';
  }

  @override
  String sheetTooMany(int max) {
    return 'บันทึกได้ไม่เกิน $max แห่ง ลบที่เดิมก่อนจึงเพิ่มได้';
  }

  @override
  String get onboardingAppName => 'ฝนตกไหม';

  @override
  String get modeCar => 'รถยนต์';

  @override
  String get modeTransit => 'BTS / MRT';

  @override
  String get modeMoto => 'มอเตอร์ไซค์';

  @override
  String get modeCarShort => 'รถยนต์';

  @override
  String get modeTransitShort => 'รถไฟฟ้า';

  @override
  String get modeMotoShort => 'มอไซค์';

  @override
  String get riskLow => 'เสี่ยงต่ำ';

  @override
  String get riskMedium => 'เสี่ยงกลาง';

  @override
  String get riskHigh => 'เสี่ยงสูง';

  @override
  String get boardLeaveOk => 'ออกได้';

  @override
  String get boardLeaveWithBuffer => 'เผื่อเวลา';

  @override
  String get boardWait => 'รอก่อน';

  @override
  String get boardSwitchMode => 'เปลี่ยนทาง';

  @override
  String get boardDontGo => 'งดไป';

  @override
  String get homeLevelNormal => 'ปกติ';

  @override
  String get homeLevelWatch => 'จับตา';

  @override
  String get homeLevelDanger => 'อันตราย';

  @override
  String get passableYes => 'ผ่านได้';

  @override
  String get passableSlow => 'ผ่านช้า ๆ';

  @override
  String get passableNo => 'ไม่ควรผ่าน';

  @override
  String approxMeters(int meters) {
    return '~$meters ม.';
  }

  @override
  String approxKm(String km) {
    return '~$km กม.';
  }

  @override
  String weekdayInitial(String day) {
    String _temp0 = intl.Intl.selectLogic(day, {
      '1': 'จ',
      '2': 'อ',
      '3': 'พ',
      '4': 'พฤ',
      '5': 'ศ',
      '6': 'ส',
      '7': 'อา',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String weekdayName(String day) {
    String _temp0 = intl.Intl.selectLogic(day, {
      '1': 'จันทร์',
      '2': 'อังคาร',
      '3': 'พุธ',
      '4': 'พฤหัส',
      '5': 'ศุกร์',
      '6': 'เสาร์',
      '7': 'อาทิตย์',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String monthShort(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': 'ม.ค.',
      '2': 'ก.พ.',
      '3': 'มี.ค.',
      '4': 'เม.ย.',
      '5': 'พ.ค.',
      '6': 'มิ.ย.',
      '7': 'ก.ค.',
      '8': 'ส.ค.',
      '9': 'ก.ย.',
      '10': 'ต.ค.',
      '11': 'พ.ย.',
      '12': 'ธ.ค.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get workDaysEveryday => 'ทุกวัน';

  @override
  String get workDaysWeekdays => 'จ–ศ';

  @override
  String get verdictCantDecide => 'ยังตัดสินไม่ได้';

  @override
  String get verdictServerError =>
      'ติดต่อเซิร์ฟเวอร์ไม่ได้ ตรวจอินเทอร์เน็ตแล้วลองอีกครั้ง';

  @override
  String get verdictRetry => 'ลองอีกครั้ง';

  @override
  String get verdictSavePlace => 'บันทึกที่นี่ไว้';

  @override
  String verdictSavedSnack(String label) {
    return 'บันทึก “$label” แล้ว';
  }

  @override
  String get verdictQuestionTitle => 'คำถาม';

  @override
  String get verdictReadingQuestion => 'กำลังอ่านคำถามของคุณ';

  @override
  String verdictGoTo(String place) {
    return 'ไป$place';
  }

  @override
  String get verdictCompareModes => 'เทียบวิธีเดินทาง';

  @override
  String verdictModeStatus(int eta, String status) {
    return '$eta น. · $status';
  }

  @override
  String get verdictFloodSpotsTitle => 'จุดน้ำท่วมบนเส้นทาง';

  @override
  String get verdictNoFloodSpots => 'ไม่มีจุดน้ำขังบนเส้นทางนี้';

  @override
  String get verdictNoFloodSpotsMsg =>
      'เส้นทางนี้ไม่ผ่านจุดเสี่ยงน้ำท่วมของ กทม.';

  @override
  String verdictExpectedDepth(int cm) {
    return 'คาดน้ำสูง $cm ซม.';
  }

  @override
  String get verdictStillDry => 'ยังแห้ง';

  @override
  String get verdictTraceTitle => 'เหตุผลที่แนะนำแบบนี้';

  @override
  String get verdictSources => 'แหล่งข้อมูล';

  @override
  String get verdictSourceGps => 'GPS ตำแหน่งปัจจุบัน';

  @override
  String get verdictAskMore => 'ถามต่อ';

  @override
  String get verdictWhyTitle => 'ทำไมถึงแนะนำแบบนี้';

  @override
  String get verdictRouteAdvice => 'ทางเลี่ยงน้ำท่วม';

  @override
  String verdictAvoid(String spot) {
    return 'เลี่ยง $spot';
  }

  @override
  String get verdictHideFactors => 'ซ่อนปัจจัย';

  @override
  String verdictShowFactors(int count) {
    return 'ดูปัจจัยที่ใช้ตัดสิน ($count)';
  }

  @override
  String get floodSetHomeTitle => 'ตั้งบ้านเพื่อดูความเสี่ยงน้ำท่วมหน้า⁠บ้าน';

  @override
  String get floodSetHomeMsg =>
      'แอปจะดูระดับคลองใกล้บ้าน จุดน้ำท่วมของ กทม. และรายงานจากเพื่อนบ้าน แล้วเตือนแม้ไม่ได้เปิดแอป';

  @override
  String get floodUseLocation => 'ใช้ตำแหน่งตอนนี้';

  @override
  String get floodSearch => 'ค้นหา';

  @override
  String get floodReadError => 'อ่านระดับน้ำไม่ได้';

  @override
  String get floodReadErrorMsg =>
      'เชื่อมต่อ ThaiWater ผ่านเซิร์ฟเวอร์ไม่ได้ ถ้าน้ำขึ้นเร็วให้ยกของขึ้นที่สูงไว้ก่อน';

  @override
  String get floodRetry => 'ลองอีกครั้ง';

  @override
  String get floodModeTitle => 'โหมดน้ำท่วม';

  @override
  String get floodHome => 'บ้าน';

  @override
  String get floodSameQuestion => 'คำถามเดิม ระดับใหม่';

  @override
  String get floodNoHome => 'ยังไม่ได้ตั้งบ้าน';

  @override
  String get floodDoNow => 'ทำตอนนี้ เรียงตามลำดับ';

  @override
  String get floodPrepare => 'เตรียมไว้ก่อน';

  @override
  String get floodSpotsTitle => 'จุดเสี่ยงน้ำท่วม กทม. ใกล้บ้าน';

  @override
  String get floodNoSpots => 'ไม่มีจุดเสี่ยงใน 2 กม.';

  @override
  String get floodNoSpotsMsg =>
      'บ้านไม่อยู่ใกล้จุดน้ำท่วมซ้ำซากที่ กทม. ประกาศไว้';

  @override
  String floodFromHome(int meters) {
    return 'ห่างบ้าน $meters ม.';
  }

  @override
  String get floodNeighborsTitle => 'เพื่อนบ้านในซอย';

  @override
  String get floodNeighborsDanger => '11 คนได้รับเตือนเดียวกัน';

  @override
  String get floodNeighborsWatch => '3 คนรายงานน้ำขังใน 20 นาที';

  @override
  String get floodNeighborsNote =>
      'คนที่ไม่มีสมาร์ทโฟนได้รับข้อความทาง LINE / SMS หรือโทรอ่านให้ฟัง';

  @override
  String floodStepSemantics(int order, String text) {
    return 'ขั้นที่ $order $text';
  }

  @override
  String get floodNearbyTitle => 'รายงานน้ำท่วมใกล้ฉัน';

  @override
  String get floodNearbyButton => 'ดูรายงานน้ำท่วมใกล้ฉัน';

  @override
  String get floodHereNow => 'ตำแหน่งตอนนี้';

  @override
  String floodAround(String where) {
    return 'รอบ $where';
  }

  @override
  String get floodNoReports => 'ไม่มีรายงานใน 500 ม.';

  @override
  String get floodNoReportsMsg => 'ยังไม่มีใครรายงานน้ำขังแถวนี้ใน 24 ชั่วโมง';

  @override
  String floodWaterDepth(int min, int max) {
    return 'น้ำ $min–$max ซม.';
  }

  @override
  String floodCarPassable(String status) {
    return 'รถยนต์ $status';
  }

  @override
  String get floodOtherSpot => 'ดูจุดอื่น';

  @override
  String get reportCameraError => 'เปิดกล้องไม่ได้ ลองเลือกจากคลังภาพแทน';

  @override
  String get reportGalleryError =>
      'เปิดคลังภาพไม่ได้ ตรวจสิทธิ์รูปภาพในตั้งค่าเครื่อง';

  @override
  String get reportTitle => 'แจ้งน้ำท่วม';

  @override
  String get reportSubtitle => 'ถ่ายรูปน้ำบนถนน บอกคนที่กำลังจะผ่าน';

  @override
  String get reportTakePhoto => 'ถ่ายรูป';

  @override
  String get reportFromGallery => 'จากคลังภาพ';

  @override
  String get reportFailed => 'ส่งรายงานไม่สำเร็จ';

  @override
  String get reportFailedMsg =>
      'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ รูปยังอยู่ในเครื่อง ส่งใหม่ได้เลย';

  @override
  String get reportResend => 'ส่งอีกครั้ง';

  @override
  String get reportAnalyzing =>
      'Gemini กำลังดูภาพ ประเมินระดับน้ำเทียบกับล้อรถและขอบทาง…';

  @override
  String get reportAnalyzeHint =>
      'Gemini จะประเมินระดับน้ำจากภาพ แล้วเตือนคนที่เส้นทางผ่านจุดนี้ในรัศมี 300 ม.';

  @override
  String get reportSeeHome => 'ดูสถานการณ์ที่บ้าน';

  @override
  String get reportLocating => 'กำลังหาตำแหน่ง…';

  @override
  String get reportUsingGps => 'ใช้ GPS ของเครื่อง';

  @override
  String reportGpsDetail(String lat, String lng, String time) {
    return 'GPS · $lat, $lng · $time';
  }

  @override
  String reportFallbackDetail(String note) {
    return '$note · ใช้ตำแหน่งสำรองของเดโม';
  }

  @override
  String get reportRetryGps => 'ลองหา GPS';

  @override
  String reportDepthSemantics(int min, int max) {
    return 'น้ำสูงประมาณ $min ถึง $max เซนติเมตร';
  }

  @override
  String get reportSeenByGemini => 'Gemini ดูภาพแล้ว';

  @override
  String reportDepth(int min, int max) {
    return 'น้ำสูง $min–$max ซม.';
  }

  @override
  String reportNotified(int count) {
    return 'แจ้งคน $count คนที่กำลังจะผ่านจุดนี้';
  }

  @override
  String reportCorroborated(int count) {
    return 'ยืนยันกับอีก $count รายงานในรัศมี 300 ม.';
  }

  @override
  String get reportDemoNumbers =>
      'จำนวนคนที่แจ้งเตือนเป็นตัวเลขจำลองสำหรับเดโม';

  @override
  String get reportFrameHint => 'ถ่ายให้เห็นล้อรถหรือขอบทาง';

  @override
  String get reportNoPhoto => 'ไม่มีภาพ · ผลตัวอย่าง';

  @override
  String get settingsTitle => 'ตั้งค่า';

  @override
  String get settingsSubtitle => 'ข้อมูลเก็บไว้ในเครื่องนี้';

  @override
  String get settingsNotificationsOff =>
      'ปิดการแจ้งเตือนอยู่ แอปเตือนก่อนออกไม่ได้';

  @override
  String get settingsOpenSettings => 'เปิดการตั้งค่า';

  @override
  String get settingsMyPlaces => 'สถานที่ของฉัน';

  @override
  String get settingsSetHome => 'ตั้งบ้าน';

  @override
  String get settingsSetWork => 'ตั้งที่ทำงาน';

  @override
  String get settingsSetHomeHint =>
      'ให้แอปเตือนก่อนกลับบ้าน และดูน้ำท่วมหน้าบ้าน';

  @override
  String get settingsSetWorkHint => 'ให้เตือนตอนเลิกงานได้แม่นขึ้น';

  @override
  String settingsWorkDetail(String days, String time) {
    return ' · $days ออก $time';
  }

  @override
  String get settingsOutOfArea => 'นอกพื้นที่ที่รองรับ';

  @override
  String get settingsWfh => 'ทำงานที่บ้าน — แอปจะเตือนเฉพาะทริปอื่น';

  @override
  String get settingsAddPlace => 'เพิ่มสถานที่';

  @override
  String settingsAddPlaceHint(int count, int max) {
    return 'ยิม โรงเรียนลูก บ้านพ่อแม่ · $count จาก $max';
  }

  @override
  String settingsAddPlaceFull(int max) {
    return 'ครบ $max แห่งแล้ว ลบที่เดิมก่อนจึงเพิ่มได้';
  }

  @override
  String get settingsTravelGroup => 'การเดินทาง';

  @override
  String get settingsRemindAhead => 'เตือนล่วงหน้า';

  @override
  String get settingsRemindAheadHint => '2 ชั่วโมงก่อนเวลาที่ควรออก';

  @override
  String get settingsAutoGroup => 'ให้แอปหาทริปให้เอง';

  @override
  String get settingsCalendarDetail => 'เฉพาะนัดที่มีสถานที่';

  @override
  String settingsCalendarAccount(String account) {
    return '$account · บัญชีจำลอง';
  }

  @override
  String get settingsGmailHint =>
      'เฉพาะอีเมลยืนยันตั๋วและนัดหมาย ไม่เก็บเนื้ออีเมล';

  @override
  String get settingsRoutine => 'เรียนรู้กิจวัตร';

  @override
  String get settingsRoutineHint =>
      'รู้เองว่ากลับบ้านราวหกโมงทุกวัน · เร็ว ๆ นี้';

  @override
  String get settingsCommunityGroup => 'ชุมชนและน้ำท่วม';

  @override
  String get settingsShareReports => 'แชร์รายงานน้ำท่วมของฉัน';

  @override
  String get settingsShareReportsHint => 'ไม่ระบุตัว เฉพาะตำแหน่งและระดับน้ำ';

  @override
  String get settingsHomeAlerts => 'เตือนน้ำท่วมที่บ้าน';

  @override
  String get settingsHomeAlertsHint => 'แม้ไม่ได้เปิดแอป';

  @override
  String get settingsSmsBackup => 'สำรองทาง SMS';

  @override
  String get settingsSmsBackupHint => 'เมื่อไม่มีอินเทอร์เน็ต';

  @override
  String get settingsProfileGroup => 'โปรไฟล์';

  @override
  String get settingsExitDemo => 'ออกจากโปรไฟล์เดโม';

  @override
  String get settingsExitDemoHint => 'ลบสถานที่ของมิวและกลับไปหน้าเริ่มต้น';

  @override
  String get settingsUseDemo => 'ใช้โปรไฟล์เดโม (มิว)';

  @override
  String get settingsUseDemoHint => 'สถานที่และนัดจำลองของมิว สำหรับสาธิต';

  @override
  String get settingsTeamGroup => 'สำหรับทีม';

  @override
  String get settingsDesignSystem => 'ระบบดีไซน์';

  @override
  String get settingsDesignSystemHint =>
      'สี ตัวอักษร ระยะ และคอมโพเนนต์ทุกสถานะท้องฟ้า';

  @override
  String get settingsDemoClock => 'เวลาสาธิต';

  @override
  String get settingsRealTime => 'เวลาจริง';

  @override
  String get settingsDemoNote =>
      'ชื่อ “มิว” ตัวเลขผู้ใช้ และรายงานชุมชนในแอปนี้เป็นข้อมูลจำลองสำหรับเดโม';

  @override
  String get settingsPlaceHome => 'บ้าน';

  @override
  String get settingsPlaceWork => 'ที่ทำงาน';

  @override
  String get settingsPlaceSiam => 'สยาม';

  @override
  String get settingsPlaceThonglor => 'ทองหล่อ';

  @override
  String get settingsPlaceImpact => 'อิมแพ็ค';

  @override
  String get verdictToolParseQuestion => 'เข้าใจคำถาม';

  @override
  String get verdictToolGetTrip => 'ดูทริปของคุณ';

  @override
  String get verdictToolGetRoute => 'หาเส้นทาง';

  @override
  String get verdictToolRain => 'เช็กฝนระหว่างทาง';

  @override
  String get verdictToolFloodSpots => 'เช็กจุดน้ำท่วม';

  @override
  String get verdictToolCanals => 'เช็กระดับน้ำในคลอง';

  @override
  String get verdictToolReports => 'ดูรายงานจากคนในพื้นที่';

  @override
  String get verdictToolEvaluate => 'ประเมินความเสี่ยง';

  @override
  String get reportSampleResult =>
      'ผลประเมินตัวอย่าง ยังไม่ได้วิเคราะห์ภาพด้วย AI';

  @override
  String get reportRejectedTitle => 'ใช้ภาพนี้ไม่ได้';
}

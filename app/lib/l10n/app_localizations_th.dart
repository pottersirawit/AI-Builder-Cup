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
  String homeGpsInaccurate(String distance) {
    return 'ตำแหน่งอาจคลาดเคลื่อน $distance';
  }

  @override
  String get homePinMyself => 'ปักหมุดเอง';

  @override
  String get homeCurrentPlace => 'ตำแหน่งตอนนี้';

  @override
  String get homeSettings => 'ตั้งค่า';

  @override
  String homeModeEta(String mode, int minutes) {
    return '$mode · $minutes นาที';
  }

  @override
  String get homeQuestionHomeNow => 'กลับบ้านตอนนี้';

  @override
  String homeQuestionToNow(String place) {
    return 'ไป$placeตอนนี้';
  }

  @override
  String homeUsingPinned(String name) {
    return 'ใช้ “$name” เป็นตำแหน่งตอนนี้แล้ว';
  }

  @override
  String get homeBackToGps => 'กลับไปใช้ GPS';

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
      'เล่นซ้ำวันพายุบนวันที่วันนี้ · ส่งเป็น X-Demo-Clock';

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
    return 'ยังไม่รู้ว่า $place อยู่ไหน';
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
  String get pickerPinnedSpot => 'ตำแหน่งที่ปักหมุด';

  @override
  String pickerNearPlace(String name) {
    return 'ใกล้$name';
  }

  @override
  String pickerAboutAway(String address, int meters) {
    return '$address · ห่างราว $meters ม.';
  }

  @override
  String get settingsGoogleTitle => 'เชื่อมต่อ Google';

  @override
  String get settingsGoogleSubtitle =>
      'ปฏิทินและ Gmail ลงชื่อเข้าใช้ครั้งเดียว';

  @override
  String get settingsGoogleUseTitle => 'สิ่งที่แอปอ่าน';

  @override
  String get settingsGoogleCalendarUse =>
      'ปฏิทิน: นัดที่มีเวลาและสถานที่ เพื่อบอกว่าควรออกกี่โมง';

  @override
  String get settingsGoogleGmailUse => 'Gmail: เฉพาะอีเมลยืนยันตั๋วและการจอง';

  @override
  String get settingsGooglePrivacy =>
      'อ่านอย่างเดียว ไม่แก้ไขหรือลบอะไร นัดของคุณถูกเก็บไว้บนเซิร์ฟเวอร์ของเราระหว่างที่ใช้แอป';

  @override
  String get settingsGoogleSignIn => 'ลงชื่อเข้าใช้ด้วย Google';

  @override
  String get settingsGoogleWaiting => 'กำลังรอ Google…';

  @override
  String get settingsGoogleWaitingHint =>
      'ลงชื่อเข้าใช้ใน Google ให้เสร็จ แล้วกลับมาที่แอปนี้';

  @override
  String get settingsGoogleFailed =>
      'Google ยังไม่ยืนยันการลงชื่อเข้าใช้ ลองอีกครั้ง';

  @override
  String settingsGoogleConnected(String email) {
    return 'เชื่อมต่อแล้วกับ $email';
  }

  @override
  String get settingsGoogleCancel => 'ยกเลิก';

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
  String get navSummary => 'สรุป';

  @override
  String get navEvents => 'อีเวนต์';

  @override
  String get navAsk => 'ถามเส้นทาง';

  @override
  String get summaryTitle => 'สรุป';

  @override
  String get summaryNextEvent => 'อีเวนต์ถัดไป';

  @override
  String summaryIn(String duration) {
    return 'อีก $duration';
  }

  @override
  String get summaryStarted => 'เริ่มแล้ว';

  @override
  String durationHm(String h, String m) {
    return '$h ชม. $m นาที';
  }

  @override
  String durationH(String h) {
    return '$h ชม.';
  }

  @override
  String durationM(String m) {
    return '$m นาที';
  }

  @override
  String durationD(String d) {
    return '$d วัน';
  }

  @override
  String get summaryLeaveBefore => 'ควรออกก่อน';

  @override
  String get summaryLeaveAt => 'ออกได้ตอน';

  @override
  String get summaryLeaveNow => 'ออกได้เลย';

  @override
  String summaryOverdue(String time) {
    return 'ควรออกตั้งแต่ $time';
  }

  @override
  String get summaryGoNow => 'ออกเลย';

  @override
  String get summaryAvoid => 'เลี่ยงการเดินทาง';

  @override
  String get summaryBy => 'ไปด้วย';

  @override
  String get summaryArrive => 'ถึงราว';

  @override
  String get summaryRain => 'ฝนระหว่างทาง';

  @override
  String get summaryRainNone => 'ไม่มีฝน';

  @override
  String get summaryRainLight => 'ฝนเบา';

  @override
  String get summaryRainModerate => 'ฝนปานกลาง';

  @override
  String get summaryRainHeavy => 'ฝนหนัก';

  @override
  String get summaryLater => 'ต่อจากนี้';

  @override
  String get summarySeeAll => 'ดูทั้งหมด';

  @override
  String get summaryDecideError => 'ยังคำนวณเวลาออกไม่ได้';

  @override
  String get summaryRetry => 'ลองใหม่';

  @override
  String get summarySetPlace => 'ระบุสถานที่';

  @override
  String get summaryUnresolved =>
      'ยังไม่รู้ว่าอีเวนต์นี้อยู่ที่ไหน ระบุสถานที่แล้วจะบอกเวลาออกให้';

  @override
  String get summaryNoEventsTitle => 'ไม่มีอีเวนต์ที่กำลังจะถึง';

  @override
  String get summaryNoEventsBody =>
      'อีเวนต์ใหม่ใน Google Calendar จะขึ้นที่นี่เอง ระหว่างนี้ถามเส้นทางเองได้';

  @override
  String get summaryAskInstead => 'ถามเส้นทางเอง';

  @override
  String get summaryConnectTitle => 'เชื่อมปฏิทินก่อน';

  @override
  String get summaryConnectBody =>
      'ฝนตกไหมจะดูนัดถัดไปของคุณ แล้วบอกว่าควรออกกี่โมง ไปทางไหนไม่เปียก';

  @override
  String get summaryConnectCta => 'เชื่อม Google Calendar';

  @override
  String get summaryLoadErrorTitle => 'โหลดอีเวนต์ไม่ได้';

  @override
  String get summaryLoadErrorBody => 'เช็กอินเทอร์เน็ตแล้วลองใหม่';

  @override
  String summaryHeroSemantics(String title, String time, String leave) {
    return 'อีเวนต์ถัดไป $title เวลา $time. $leave. แตะเพื่อดูรายละเอียด';
  }

  @override
  String get summaryFloodTitle => 'น้ำท่วมใกล้บ้าน';

  @override
  String get summaryFloodWhatToDo => 'ดูสิ่งที่ต้องทำ';

  @override
  String get eventsTitle => 'อีเวนต์';

  @override
  String eventsSource(String account) {
    return 'จาก Google Calendar · $account';
  }

  @override
  String eventsToday(String date) {
    return 'วันนี้ · $date';
  }

  @override
  String eventsTomorrow(String date) {
    return 'พรุ่งนี้ · $date';
  }

  @override
  String get eventsNoTime => 'ไม่ระบุเวลา';

  @override
  String eventsLeaveAt(String time, String mode) {
    return 'ออก $time · $mode';
  }

  @override
  String get eventsAvoid => 'เลี่ยงการเดินทาง';

  @override
  String get eventsRefresh => 'รีเฟรช';

  @override
  String eventsCount(String count) {
    return '$count อีเวนต์';
  }

  @override
  String get askSheetTitle => 'อยากไปไหน';

  @override
  String get askTomorrowMorning => 'พรุ่งนี้เช้าฝนตกไหม';

  @override
  String summaryLate(String duration) {
    return 'ถึงหลังเวลานัด $duration';
  }

  @override
  String get wxRainNow => 'ฝนกำลังตก';

  @override
  String wxRainStops(String time) {
    return 'ฝนกำลังตก ซาราว $time';
  }

  @override
  String wxRainFrom(String time) {
    return 'ฝนมาราว $time';
  }

  @override
  String get wxDryAhead => 'ไม่มีฝนอีก 12 ชม.';

  @override
  String get wxSunStrong => 'แดดแรง';

  @override
  String get wxHot => 'ร้อนจัด';

  @override
  String get wxFeels => 'รู้สึกเหมือน';

  @override
  String get wxUv => 'UV';

  @override
  String get wxRainChance => 'โอกาสฝน';

  @override
  String get wxUvLow => 'ต่ำ';

  @override
  String get wxUvModerate => 'ปานกลาง';

  @override
  String get wxUvHigh => 'สูง';

  @override
  String get wxUvVeryHigh => 'สูงมาก';

  @override
  String get wxUvExtreme => 'อันตราย';

  @override
  String get wxNow => 'ตอนนี้';

  @override
  String get wxHumidity => 'ความชื้น';

  @override
  String get wxWind => 'ลม';

  @override
  String wxWindKph(Object kph) {
    return '$kph กม./ชม.';
  }

  @override
  String get wxSunset => 'อาทิตย์ตก';

  @override
  String get carryTitle => 'วันนี้ควรพก';

  @override
  String get carryNothing => 'ไม่ต้องพกอะไรเพิ่ม';

  @override
  String get carryNothingBody => 'อากาศดีตลอด 12 ชม.ข้างหน้า';

  @override
  String get carryRaincoat => 'เสื้อกันฝน';

  @override
  String get carryUmbrella => 'ร่ม';

  @override
  String get carrySpareUmbrella => 'ร่มพับติดกระเป๋า';

  @override
  String carryWhyMaybeRain(Object from, Object pct, Object to) {
    return 'อาจมีฝน $pct% · $from–$to';
  }

  @override
  String get carrySunUmbrella => 'ร่มกันแดด';

  @override
  String get carrySunscreen => 'ครีมกันแดด';

  @override
  String get carryWater => 'น้ำดื่ม';

  @override
  String get carryShoes => 'รองเท้าลุยน้ำ';

  @override
  String carryWhyRain(String pct, String from, String to) {
    return 'ฝน $pct% · $from–$to';
  }

  @override
  String carryWhyHeavy(String from, String to) {
    return 'ฝนหนัก ร่มเอาไม่อยู่ · $from–$to';
  }

  @override
  String carryWhyMoto(String from, String to) {
    return 'ขี่มอเตอร์ไซค์ฝ่าฝน · $from–$to';
  }

  @override
  String carryWhyUv(String uv, String from, String to) {
    return 'UV $uv · $from–$to';
  }

  @override
  String carryWhyShade(String from, String to) {
    return 'แดดแรงมาก กางร่มเดิน · $from–$to';
  }

  @override
  String carryWhyHeat(String c) {
    return 'รู้สึกเหมือน $c° ดื่มบ่อย ๆ';
  }

  @override
  String carryWhyShoes(String from, String to) {
    return 'น้ำขังบนถนน · $from–$to';
  }

  @override
  String get eventsAllDays => 'ทุกวัน';

  @override
  String get eventsNoneOn => 'ไม่มีอีเวนต์วันนี้';

  @override
  String get calPrev => 'เดือนก่อน';

  @override
  String get calNext => 'เดือนถัดไป';

  @override
  String calMonth(String month, String year) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': 'มกราคม',
      '2': 'กุมภาพันธ์',
      '3': 'มีนาคม',
      '4': 'เมษายน',
      '5': 'พฤษภาคม',
      '6': 'มิถุนายน',
      '7': 'กรกฎาคม',
      '8': 'สิงหาคม',
      '9': 'กันยายน',
      '10': 'ตุลาคม',
      '11': 'พฤศจิกายน',
      '12': 'ธันวาคม',
      'other': '',
    });
    return '$_temp0 $year';
  }

  @override
  String get dayToday => 'วันนี้';

  @override
  String get dayTomorrow => 'พรุ่งนี้';

  @override
  String get eventsCalendar => 'ดูปฏิทิน';

  @override
  String planTitleToday(String count) {
    return 'วันนี้อีก $count นัด';
  }

  @override
  String get planTitleFree => 'วันนี้ไม่มีนัดแล้ว';

  @override
  String get planToday => 'แผนต่อจากนี้';

  @override
  String get planTomorrow => 'พรุ่งนี้';

  @override
  String get planBring => 'พกไปด้วย';

  @override
  String get planWeatherNow => 'อากาศตอนนี้';

  @override
  String planRainAt(String pct) {
    return 'ฝน $pct%';
  }

  @override
  String get leaveIn => 'ต้องออกใน';

  @override
  String get leaveDue => 'ถึงเวลาออก';

  @override
  String get unitMin => 'นาที';

  @override
  String get unitHour => 'ชม.';

  @override
  String get alertsTitle => 'ต้องรู้ก่อนออก';

  @override
  String alertShort(String to) {
    return 'ไป $to ไม่ทัน';
  }

  @override
  String alertShortBody(String from, String end, String need, String gap) {
    return '$from จบ $end เดินทางราว $need แต่มีเวลาแค่ $gap';
  }

  @override
  String alertOverlap(String from, String to) {
    return '$from กับ $to เวลาชนกัน';
  }

  @override
  String alertTight(String to) {
    return 'เวลาไป $to เผื่อน้อย';
  }

  @override
  String alertTightBody(String need, String gap, String from) {
    return 'เดินทางราว $need มีเวลา $gap ออกจาก $from ให้ตรงเวลา';
  }

  @override
  String alertWetLeave(String pct, String to) {
    return 'ฝน $pct% ตอนออกไป $to';
  }

  @override
  String alertWetLeaveBody(String time) {
    return 'ราว $time เลือกทางที่ไม่ต้องเดินกลางฝน';
  }

  @override
  String alertWetLeaveMoto(String time) {
    return 'ราว $time ขี่มอเตอร์ไซค์ฝ่าฝน ใส่เสื้อกันฝนหรือเปลี่ยนไปรถไฟฟ้า';
  }

  @override
  String alertWetReturn(String from, String pct) {
    return 'ขากลับจาก $from ฝน $pct%';
  }

  @override
  String alertWetReturnBody(String time) {
    return 'เลิกราว $time อย่าลืมพกร่มกลับด้วย';
  }

  @override
  String alertWetReturnMoto(Object time) {
    return 'เลิกราว $time พกเสื้อกันฝนไว้ขี่กลับด้วย';
  }

  @override
  String alertNeedsPlace(String title) {
    return '$title ยังไม่มีสถานที่';
  }

  @override
  String alertNeedsPlaceBody(String when) {
    return '$when · ระบุสถานที่เพื่อวางแผนเวลาออก';
  }

  @override
  String get upNextTitle => 'ถัดไป';

  @override
  String get online => 'ออนไลน์ · ไม่ต้องเดินทาง';

  @override
  String get allDay => 'ทั้งวัน';

  @override
  String get allDayNoLeave => 'ไม่มีเวลาออก';

  @override
  String get allDayNote => 'กิจกรรมทั้งวันไม่มีเวลานัด จึงไม่มีเวลาออกให้';

  @override
  String allDayAskRoute(Object place) {
    return 'ถามทางไป$place';
  }

  @override
  String get stripTitle => 'ภาพรวมวันนี้';

  @override
  String get stripEvent => 'นัด';

  @override
  String get stripTravel => 'เดินทาง';

  @override
  String get stripRain => 'ฝน';

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
    return 'ไป $place';
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
  String get floodDoNow => 'ทำตอนนี้ เรียงตามลำดับ';

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
  String get verdictHotlinesTitle => 'สายด่วนขอความช่วยเหลือฉุกเฉิน';

  @override
  String verdictHotlineCopied(String number, String purpose) {
    return 'คัดลอกเบอร์ $number ($purpose) แล้ว';
  }
}

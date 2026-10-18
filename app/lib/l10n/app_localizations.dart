import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_th.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('th'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In th, this message translates to:
  /// **'ฝนตกไหม'**
  String get appTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In th, this message translates to:
  /// **'ภาษา'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageThai.
  ///
  /// In th, this message translates to:
  /// **'ไทย'**
  String get settingsLanguageThai;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In th, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @designBack.
  ///
  /// In th, this message translates to:
  /// **'กลับ'**
  String get designBack;

  /// No description provided for @designAskTooltip.
  ///
  /// In th, this message translates to:
  /// **'ถาม'**
  String get designAskTooltip;

  /// No description provided for @designAskHint.
  ///
  /// In th, this message translates to:
  /// **'ไปไหน กี่โมง? เช่น ห้าโมงไปสยาม'**
  String get designAskHint;

  /// No description provided for @designDismissBanner.
  ///
  /// In th, this message translates to:
  /// **'ปิดแจ้งเตือน'**
  String get designDismissBanner;

  /// No description provided for @designRetry.
  ///
  /// In th, this message translates to:
  /// **'ลองอีกครั้ง'**
  String get designRetry;

  /// No description provided for @designLoadingAnswer.
  ///
  /// In th, this message translates to:
  /// **'กำลังโหลดคำตอบ'**
  String get designLoadingAnswer;

  /// No description provided for @boardNoteTransitCrowded.
  ///
  /// In th, this message translates to:
  /// **'ขบวนไม่สนฝน แต่ชานชาลาแน่น เผื่อเวลา'**
  String get boardNoteTransitCrowded;

  /// No description provided for @boardNoteTransitWalk.
  ///
  /// In th, this message translates to:
  /// **'ฝนตกช่วงเดินไปสถานี'**
  String get boardNoteTransitWalk;

  /// No description provided for @boardNoteDry.
  ///
  /// In th, this message translates to:
  /// **'ไม่โดนฝนระหว่างทาง'**
  String get boardNoteDry;

  /// No description provided for @boardNoteCarHeavy.
  ///
  /// In th, this message translates to:
  /// **'ฝนหนัก น้ำรอระบาย รถติดสะสม'**
  String get boardNoteCarHeavy;

  /// No description provided for @boardNoteCarDrizzle.
  ///
  /// In th, this message translates to:
  /// **'เจอฝนระหว่างทาง ขับช้าลง'**
  String get boardNoteCarDrizzle;

  /// No description provided for @boardNoteBeatRain.
  ///
  /// In th, this message translates to:
  /// **'ถึงก่อนฝน'**
  String get boardNoteBeatRain;

  /// No description provided for @boardNoteMotoHeavy.
  ///
  /// In th, this message translates to:
  /// **'ฝนหนักกลางทาง มอเตอร์ไซค์ไม่ควรไป'**
  String get boardNoteMotoHeavy;

  /// No description provided for @boardNoteMotoTight.
  ///
  /// In th, this message translates to:
  /// **'ทันพอดี ช้ากว่านี้จะโดนฝน'**
  String get boardNoteMotoTight;

  /// No description provided for @boardHeadlineLeave.
  ///
  /// In th, this message translates to:
  /// **'ออก {time} ได้'**
  String boardHeadlineLeave(String time);

  /// No description provided for @boardHeadlineWait.
  ///
  /// In th, this message translates to:
  /// **'อย่าเพิ่งออก'**
  String get boardHeadlineWait;

  /// No description provided for @boardHeadlineSwitchTransit.
  ///
  /// In th, this message translates to:
  /// **'เปลี่ยนเป็น BTS ดีกว่า'**
  String get boardHeadlineSwitchTransit;

  /// No description provided for @homeGpsInaccurate.
  ///
  /// In th, this message translates to:
  /// **'ตำแหน่งอาจคลาดเคลื่อน {distance}'**
  String homeGpsInaccurate(String distance);

  /// No description provided for @homePinMyself.
  ///
  /// In th, this message translates to:
  /// **'ปักหมุดเอง'**
  String get homePinMyself;

  /// No description provided for @homeCurrentPlace.
  ///
  /// In th, this message translates to:
  /// **'ตำแหน่งตอนนี้'**
  String get homeCurrentPlace;

  /// No description provided for @homeSettings.
  ///
  /// In th, this message translates to:
  /// **'ตั้งค่า'**
  String get homeSettings;

  /// No description provided for @homeModeEta.
  ///
  /// In th, this message translates to:
  /// **'{mode} · {minutes} นาที'**
  String homeModeEta(String mode, int minutes);

  /// No description provided for @homeQuestionHomeNow.
  ///
  /// In th, this message translates to:
  /// **'กลับบ้านตอนนี้'**
  String get homeQuestionHomeNow;

  /// No description provided for @homeQuestionToNow.
  ///
  /// In th, this message translates to:
  /// **'ไป{place}ตอนนี้'**
  String homeQuestionToNow(String place);

  /// No description provided for @homeUsingPinned.
  ///
  /// In th, this message translates to:
  /// **'ใช้ “{name}” เป็นตำแหน่งตอนนี้แล้ว'**
  String homeUsingPinned(String name);

  /// No description provided for @homeBackToGps.
  ///
  /// In th, this message translates to:
  /// **'กลับไปใช้ GPS'**
  String get homeBackToGps;

  /// No description provided for @askSuggestion1.
  ///
  /// In th, this message translates to:
  /// **'ถ้ารอถึงสองทุ่มค่อยกลับล่ะ'**
  String get askSuggestion1;

  /// No description provided for @askSuggestion2.
  ///
  /// In th, this message translates to:
  /// **'ไป BTS แทนดีไหม'**
  String get askSuggestion2;

  /// No description provided for @askOpeningPlain.
  ///
  /// In th, this message translates to:
  /// **'อยากรู้อะไรเรื่องฝนกับการเดินทาง ถามได้เลย'**
  String get askOpeningPlain;

  /// No description provided for @askOpeningWith.
  ///
  /// In th, this message translates to:
  /// **'ตอนนี้แนะนำ “{headline}” นะ มีอะไรอยากถามต่อไหม'**
  String askOpeningWith(String headline);

  /// No description provided for @askFailed.
  ///
  /// In th, this message translates to:
  /// **'ตอบไม่ได้ เพราะติดต่อเซิร์ฟเวอร์ไม่ได้ ตรวจอินเทอร์เน็ตแล้วถามใหม่'**
  String get askFailed;

  /// No description provided for @askTitle.
  ///
  /// In th, this message translates to:
  /// **'ถามต่อ'**
  String get askTitle;

  /// No description provided for @askInputHint.
  ///
  /// In th, this message translates to:
  /// **'พิมพ์คำถาม เช่น ถ้าไปมอเตอร์ไซค์ล่ะ'**
  String get askInputHint;

  /// No description provided for @askRetry.
  ///
  /// In th, this message translates to:
  /// **'ถามใหม่'**
  String get askRetry;

  /// No description provided for @askDisclaimer.
  ///
  /// In th, this message translates to:
  /// **'ข้อมูลและการประเมินจาก AI อาจมีความคลาดเคลื่อนหรือไม่ถูกต้อง 100% โปรดตรวจสอบสภาพอากาศและเส้นทางจริงก่อนออกเดินทาง'**
  String get askDisclaimer;

  /// No description provided for @partsQuestion.
  ///
  /// In th, this message translates to:
  /// **'คำถาม: “{question}”'**
  String partsQuestion(String question);

  /// No description provided for @partsArriveBy.
  ///
  /// In th, this message translates to:
  /// **'ถึงก่อน {time}'**
  String partsArriveBy(String time);

  /// No description provided for @partsChecking.
  ///
  /// In th, this message translates to:
  /// **'กำลังตรวจเวลานี้…'**
  String get partsChecking;

  /// No description provided for @partsPreviewEstimate.
  ///
  /// In th, this message translates to:
  /// **'ประเมินจากฝนบนเส้นทาง ปล่อยนิ้วเพื่อยืนยัน'**
  String get partsPreviewEstimate;

  /// No description provided for @partsTakesMin.
  ///
  /// In th, this message translates to:
  /// **'ใช้เวลา {minutes} นาที'**
  String partsTakesMin(int minutes);

  /// No description provided for @partsSegLeave.
  ///
  /// In th, this message translates to:
  /// **'ออก'**
  String get partsSegLeave;

  /// No description provided for @partsSegArrive.
  ///
  /// In th, this message translates to:
  /// **'ถึง'**
  String get partsSegArrive;

  /// No description provided for @partsSegMode.
  ///
  /// In th, this message translates to:
  /// **'โหมด'**
  String get partsSegMode;

  /// No description provided for @partsSegConfidence.
  ///
  /// In th, this message translates to:
  /// **'มั่นใจ'**
  String get partsSegConfidence;

  /// No description provided for @partsNow.
  ///
  /// In th, this message translates to:
  /// **'ตอนนี้'**
  String get partsNow;

  /// No description provided for @partsDragHint.
  ///
  /// In th, this message translates to:
  /// **'ลากหมุดเพื่อลองเวลาออก'**
  String get partsDragHint;

  /// No description provided for @partsLeaveNow.
  ///
  /// In th, this message translates to:
  /// **'ออกตอนนี้'**
  String get partsLeaveNow;

  /// No description provided for @partsOutOfArea.
  ///
  /// In th, this message translates to:
  /// **'นอกพื้นที่ที่รองรับ'**
  String get partsOutOfArea;

  /// No description provided for @partsRainToday.
  ///
  /// In th, this message translates to:
  /// **'ฝนวันนี้'**
  String get partsRainToday;

  /// No description provided for @partsMm.
  ///
  /// In th, this message translates to:
  /// **'{mm} มม.'**
  String partsMm(int mm);

  /// No description provided for @partsFloodSpots.
  ///
  /// In th, this message translates to:
  /// **'จุดเสี่ยง 2 กม.'**
  String get partsFloodSpots;

  /// No description provided for @partsReports.
  ///
  /// In th, this message translates to:
  /// **'รายงาน 500 ม.'**
  String get partsReports;

  /// No description provided for @partsCanalLevel.
  ///
  /// In th, this message translates to:
  /// **'ระดับคลอง'**
  String get partsCanalLevel;

  /// No description provided for @partsCanalLevelValue.
  ///
  /// In th, this message translates to:
  /// **'{level}/{bank} ม.'**
  String partsCanalLevelValue(String level, String bank);

  /// No description provided for @partsCanalRise.
  ///
  /// In th, this message translates to:
  /// **'ขึ้นใน 2 ชม.'**
  String get partsCanalRise;

  /// No description provided for @partsCm.
  ///
  /// In th, this message translates to:
  /// **'{cm} ซม.'**
  String partsCm(int cm);

  /// No description provided for @partsToBank.
  ///
  /// In th, this message translates to:
  /// **'ถึงตลิ่ง'**
  String get partsToBank;

  /// No description provided for @partsAtBank.
  ///
  /// In th, this message translates to:
  /// **'ถึงแล้ว'**
  String get partsAtBank;

  /// No description provided for @partsCmLeft.
  ///
  /// In th, this message translates to:
  /// **'อีก {cm} ซม.'**
  String partsCmLeft(int cm);

  /// No description provided for @partsNoCanalStation.
  ///
  /// In th, this message translates to:
  /// **'ไม่มีสถานีวัดระดับคลองใกล้บ้าน'**
  String get partsNoCanalStation;

  /// No description provided for @partsOutsideBangkok.
  ///
  /// In th, this message translates to:
  /// **'บ้านอยู่นอกกรุงเทพฯ ข้อมูลระดับคลองและจุดน้ำท่วมยังไม่ครอบคลุม แอปเตือนได้เฉพาะฝน'**
  String get partsOutsideBangkok;

  /// No description provided for @partsDemoClockSemantic.
  ///
  /// In th, this message translates to:
  /// **'เวลาสาธิต {time} แตะเพื่อเปลี่ยน'**
  String partsDemoClockSemantic(String time);

  /// No description provided for @partsRealTime.
  ///
  /// In th, this message translates to:
  /// **'เวลาจริง'**
  String get partsRealTime;

  /// No description provided for @partsDemoTime.
  ///
  /// In th, this message translates to:
  /// **'เวลาสาธิต'**
  String get partsDemoTime;

  /// No description provided for @partsDemoReplay.
  ///
  /// In th, this message translates to:
  /// **'เล่นซ้ำวันพายุบนวันที่วันนี้ · ส่งเป็น X-Demo-Clock'**
  String get partsDemoReplay;

  /// No description provided for @partsRealTimeNoHeader.
  ///
  /// In th, this message translates to:
  /// **'เวลาจริง (ไม่ส่ง header)'**
  String get partsRealTimeNoHeader;

  /// No description provided for @partsPreset1610.
  ///
  /// In th, this message translates to:
  /// **'ก่อนเลิกงาน ฝนยังไม่มา'**
  String get partsPreset1610;

  /// No description provided for @partsPreset1852.
  ///
  /// In th, this message translates to:
  /// **'พายุบนรัชดา น้ำรอระบาย'**
  String get partsPreset1852;

  /// No description provided for @partsPreset2140.
  ///
  /// In th, this message translates to:
  /// **'โหมดน้ำท่วมที่บ้าน'**
  String get partsPreset2140;

  /// No description provided for @partsPresetDevice.
  ///
  /// In th, this message translates to:
  /// **'ใช้นาฬิกาเครื่อง'**
  String get partsPresetDevice;

  /// No description provided for @partsKindLabel.
  ///
  /// In th, this message translates to:
  /// **'{kind, select, home{บ้าน} work{ที่ทำงาน} other{สถานที่}}'**
  String partsKindLabel(String kind);

  /// No description provided for @partsNeedsFirst.
  ///
  /// In th, this message translates to:
  /// **'ต้องรู้ก่อนตอบ'**
  String get partsNeedsFirst;

  /// No description provided for @partsNeedsWhere.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่รู้ว่า {place} อยู่ไหน'**
  String partsNeedsWhere(String place);

  /// No description provided for @partsNeedsSaveOnce.
  ///
  /// In th, this message translates to:
  /// **'บันทึกไว้ครั้งเดียว แล้วแอปจะตอบคำถามนี้ต่อทันที'**
  String get partsNeedsSaveOnce;

  /// No description provided for @partsUseMyLocation.
  ///
  /// In th, this message translates to:
  /// **'ใช้ตำแหน่งตอนนี้'**
  String get partsUseMyLocation;

  /// No description provided for @partsSearch.
  ///
  /// In th, this message translates to:
  /// **'ค้นหา'**
  String get partsSearch;

  /// No description provided for @partsWhichPlace.
  ///
  /// In th, this message translates to:
  /// **'หมายถึงที่ไหน'**
  String get partsWhichPlace;

  /// No description provided for @partsNotFound.
  ///
  /// In th, this message translates to:
  /// **'หา “{query}” ไม่เจอ ลองค้นด้วยชื่ออื่น'**
  String partsNotFound(String query);

  /// No description provided for @partsSimilar.
  ///
  /// In th, this message translates to:
  /// **'เจอหลายที่ที่ชื่อคล้าย “{query}”'**
  String partsSimilar(String query);

  /// No description provided for @partsSearchFor.
  ///
  /// In th, this message translates to:
  /// **'ค้นหา “{query}”'**
  String partsSearchFor(String query);

  /// No description provided for @partsNoneOfThese.
  ///
  /// In th, this message translates to:
  /// **'ไม่ใช่ทั้งหมด · ค้นหาเอง'**
  String get partsNoneOfThese;

  /// No description provided for @marksSourceSemantic.
  ///
  /// In th, this message translates to:
  /// **'แหล่งข้อมูล: {text}'**
  String marksSourceSemantic(String text);

  /// No description provided for @marksSample.
  ///
  /// In th, this message translates to:
  /// **'ข้อมูลตัวอย่าง'**
  String get marksSample;

  /// No description provided for @marksSampleSemantic.
  ///
  /// In th, this message translates to:
  /// **'ข้อมูลตัวอย่าง เชื่อมต่อเซิร์ฟเวอร์ไม่ได้'**
  String get marksSampleSemantic;

  /// No description provided for @marksDemo.
  ///
  /// In th, this message translates to:
  /// **'เดโม'**
  String get marksDemo;

  /// No description provided for @marksDemoSemantic.
  ///
  /// In th, this message translates to:
  /// **'โปรไฟล์เดโม ข้อมูลจำลอง'**
  String get marksDemoSemantic;

  /// No description provided for @marksConfidence.
  ///
  /// In th, this message translates to:
  /// **'มั่นใจ'**
  String get marksConfidence;

  /// No description provided for @marksConfidenceSemantic.
  ///
  /// In th, this message translates to:
  /// **'ความมั่นใจ {percent}'**
  String marksConfidenceSemantic(String percent);

  /// No description provided for @marksGeneratedByAi.
  ///
  /// In th, this message translates to:
  /// **'AI วิเคราะห์ให้'**
  String get marksGeneratedByAi;

  /// No description provided for @marksGeneratedByFallback.
  ///
  /// In th, this message translates to:
  /// **'ใช้การคำนวณสำรอง · AI ไม่ตอบในรอบนี้'**
  String get marksGeneratedByFallback;

  /// No description provided for @rainBandLeave.
  ///
  /// In th, this message translates to:
  /// **'ออก {time}'**
  String rainBandLeave(String time);

  /// No description provided for @rainBandSlider.
  ///
  /// In th, this message translates to:
  /// **'เวลาออกเดินทาง ลากเพื่อลองเวลาอื่น'**
  String get rainBandSlider;

  /// No description provided for @galleryTitle.
  ///
  /// In th, this message translates to:
  /// **'ระบบดีไซน์'**
  String get galleryTitle;

  /// No description provided for @gallerySubtitle.
  ///
  /// In th, this message translates to:
  /// **'ฝนตกไหม · โทเคนและคอมโพเนนต์'**
  String get gallerySubtitle;

  /// No description provided for @galleryClear.
  ///
  /// In th, this message translates to:
  /// **'ฟ้าใส'**
  String get galleryClear;

  /// No description provided for @galleryStorm.
  ///
  /// In th, this message translates to:
  /// **'พายุ'**
  String get galleryStorm;

  /// No description provided for @galleryFlood.
  ///
  /// In th, this message translates to:
  /// **'น้ำท่วม'**
  String get galleryFlood;

  /// No description provided for @gallerySkySwatches.
  ///
  /// In th, this message translates to:
  /// **'พื้นท้องฟ้า'**
  String get gallerySkySwatches;

  /// No description provided for @galleryPassPerSky.
  ///
  /// In th, this message translates to:
  /// **'พาสในแต่ละท้องฟ้า'**
  String get galleryPassPerSky;

  /// No description provided for @galleryColors.
  ///
  /// In th, this message translates to:
  /// **'สี'**
  String get galleryColors;

  /// No description provided for @galleryType.
  ///
  /// In th, this message translates to:
  /// **'ตัวอักษร · Chakra Petch'**
  String get galleryType;

  /// No description provided for @gallerySpace.
  ///
  /// In th, this message translates to:
  /// **'ระยะ · รัศมี · เงา'**
  String get gallerySpace;

  /// No description provided for @galleryMotion.
  ///
  /// In th, this message translates to:
  /// **'การเคลื่อนไหว'**
  String get galleryMotion;

  /// No description provided for @galleryRainBand.
  ///
  /// In th, this message translates to:
  /// **'RainBand · ลากได้'**
  String get galleryRainBand;

  /// No description provided for @galleryRerank.
  ///
  /// In th, this message translates to:
  /// **'จัดอันดับใหม่'**
  String get galleryRerank;

  /// No description provided for @galleryPlaces.
  ///
  /// In th, this message translates to:
  /// **'สถานที่ · Notice · ConnectRow'**
  String get galleryPlaces;

  /// No description provided for @galleryNoticeWork.
  ///
  /// In th, this message translates to:
  /// **'ตั้งที่ทำงานเพื่อให้เตือนได้แม่นขึ้น'**
  String get galleryNoticeWork;

  /// No description provided for @galleryNoticeOff.
  ///
  /// In th, this message translates to:
  /// **'ปิดการแจ้งเตือนอยู่ แอปเตือนก่อนออกไม่ได้'**
  String get galleryNoticeOff;

  /// No description provided for @galleryOpenSettings.
  ///
  /// In th, this message translates to:
  /// **'เปิดการตั้งค่า'**
  String get galleryOpenSettings;

  /// No description provided for @galleryNoticeCalendar.
  ///
  /// In th, this message translates to:
  /// **'เชื่อม Calendar เพื่อให้แอปเห็นนัด'**
  String get galleryNoticeCalendar;

  /// No description provided for @galleryCalendarDetail.
  ///
  /// In th, this message translates to:
  /// **'เฉพาะนัดที่มีสถานที่'**
  String get galleryCalendarDetail;

  /// No description provided for @galleryCalendarAccount.
  ///
  /// In th, this message translates to:
  /// **'miw.demo@gmail.com · บัญชีจำลอง'**
  String get galleryCalendarAccount;

  /// No description provided for @galleryRiskChips.
  ///
  /// In th, this message translates to:
  /// **'RiskChip · ConfidenceMeter · SourceLabel'**
  String get galleryRiskChips;

  /// No description provided for @galleryNotifTitle.
  ///
  /// In th, this message translates to:
  /// **'ออกก่อน 16:45 · กินข้าวเย็นกับที่บ้าน'**
  String get galleryNotifTitle;

  /// No description provided for @galleryNotifBody.
  ///
  /// In th, this message translates to:
  /// **'ฝนถึงพระราม 4 ประมาณ 17:30 ถ้าออกตอนนี้ถึงบ้านก่อนฝน'**
  String get galleryNotifBody;

  /// No description provided for @galleryStateLoading.
  ///
  /// In th, this message translates to:
  /// **'สถานะ: กำลังโหลด'**
  String get galleryStateLoading;

  /// No description provided for @galleryStateError.
  ///
  /// In th, this message translates to:
  /// **'สถานะ: ผิดพลาด'**
  String get galleryStateError;

  /// No description provided for @galleryStateEmpty.
  ///
  /// In th, this message translates to:
  /// **'สถานะ: ว่าง'**
  String get galleryStateEmpty;

  /// No description provided for @galleryErrorTitle.
  ///
  /// In th, this message translates to:
  /// **'โหลดทริปไม่ได้'**
  String get galleryErrorTitle;

  /// No description provided for @galleryErrorMessage.
  ///
  /// In th, this message translates to:
  /// **'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ตรวจอินเทอร์เน็ตแล้วลองอีกครั้ง'**
  String get galleryErrorMessage;

  /// No description provided for @galleryEmptyTitle.
  ///
  /// In th, this message translates to:
  /// **'วันนี้ยังไม่มีทริป'**
  String get galleryEmptyTitle;

  /// No description provided for @galleryEmptyMessage.
  ///
  /// In th, this message translates to:
  /// **'พิมพ์ถามได้เลย เช่น “ห้าโมงไปสยาม”'**
  String get galleryEmptyMessage;

  /// No description provided for @galleryConnectCalendar.
  ///
  /// In th, this message translates to:
  /// **'เชื่อม Calendar'**
  String get galleryConnectCalendar;

  /// No description provided for @galleryRowTransitSub.
  ///
  /// In th, this message translates to:
  /// **'ศาลาแดง → ลาดพร้าว ไม่ต้องพกร่ม'**
  String get galleryRowTransitSub;

  /// No description provided for @galleryRowCarSub.
  ///
  /// In th, this message translates to:
  /// **'ถึงก่อนฝน ทันนัด 18:30'**
  String get galleryRowCarSub;

  /// No description provided for @galleryRowMotoSub.
  ///
  /// In th, this message translates to:
  /// **'ทันพอดี ช้ากว่านี้จะโดนฝน'**
  String get galleryRowMotoSub;

  /// No description provided for @galleryRowTitle.
  ///
  /// In th, this message translates to:
  /// **'{mode} · {minutes} นาที'**
  String galleryRowTitle(String mode, int minutes);

  /// No description provided for @galleryHeadClear.
  ///
  /// In th, this message translates to:
  /// **'ออกก่อน 16:45'**
  String get galleryHeadClear;

  /// No description provided for @galleryHeadStorm.
  ///
  /// In th, this message translates to:
  /// **'อย่าเพิ่งออก'**
  String get galleryHeadStorm;

  /// No description provided for @galleryHeadFlood.
  ///
  /// In th, this message translates to:
  /// **'น้ำจะถึงหน้าบ้านใน 40 นาที'**
  String get galleryHeadFlood;

  /// No description provided for @galleryColorPass.
  ///
  /// In th, this message translates to:
  /// **'พาส'**
  String get galleryColorPass;

  /// No description provided for @galleryColorRain.
  ///
  /// In th, this message translates to:
  /// **'ฝน (ไม่มี → หนัก)'**
  String get galleryColorRain;

  /// No description provided for @galleryColorRisk.
  ///
  /// In th, this message translates to:
  /// **'ความเสี่ยง'**
  String get galleryColorRisk;

  /// No description provided for @galleryTypeVerdict.
  ///
  /// In th, this message translates to:
  /// **'คำตัดสิน'**
  String get galleryTypeVerdict;

  /// No description provided for @galleryTypeSampleLong.
  ///
  /// In th, this message translates to:
  /// **'ฝนถึงพระราม 4 ราว 17:30 น้ำขัง 25 ซม.'**
  String get galleryTypeSampleLong;

  /// No description provided for @galleryTypeTabular.
  ///
  /// In th, this message translates to:
  /// **'ตัวเลขเท่ากัน (Petch Tabular) เทียบตัวเลขปกติ'**
  String get galleryTypeTabular;

  /// No description provided for @galleryMotionTap.
  ///
  /// In th, this message translates to:
  /// **'สถานะปุ่มและการเลือก'**
  String get galleryMotionTap;

  /// No description provided for @galleryMotionFlap.
  ///
  /// In th, this message translates to:
  /// **'คำตัดสินพลิกตัวอักษร'**
  String get galleryMotionFlap;

  /// No description provided for @galleryMotionRerank.
  ///
  /// In th, this message translates to:
  /// **'กระดานเลื่อนอันดับ'**
  String get galleryMotionRerank;

  /// No description provided for @galleryMotionEnter.
  ///
  /// In th, this message translates to:
  /// **'แจ้งเตือนเลื่อนลง'**
  String get galleryMotionEnter;

  /// No description provided for @galleryMotionSky.
  ///
  /// In th, this message translates to:
  /// **'สีท้องฟ้าเปลี่ยนสถานะ'**
  String get galleryMotionSky;

  /// No description provided for @galleryMotionCurves.
  ///
  /// In th, this message translates to:
  /// **'เส้นโค้ง: standard (0.2, 0, 0, 1) · emphasized decelerate (0.05, 0.7, 0.1, 1)'**
  String get galleryMotionCurves;

  /// No description provided for @galleryMotionReduced.
  ///
  /// In th, this message translates to:
  /// **'ลดการเคลื่อนไหวเปิดอยู่: ทุกระยะเวลาเป็น 0'**
  String get galleryMotionReduced;

  /// No description provided for @galleryFlipDemo.
  ///
  /// In th, this message translates to:
  /// **'ออก 16:45 ได้'**
  String get galleryFlipDemo;

  /// No description provided for @galleryFlip.
  ///
  /// In th, this message translates to:
  /// **'พลิก'**
  String get galleryFlip;

  /// No description provided for @galleryModeStatus.
  ///
  /// In th, this message translates to:
  /// **'{minutes} น. · {status}'**
  String galleryModeStatus(int minutes, String status);

  /// No description provided for @placeKindHome.
  ///
  /// In th, this message translates to:
  /// **'บ้าน'**
  String get placeKindHome;

  /// No description provided for @placeKindWork.
  ///
  /// In th, this message translates to:
  /// **'ที่ทำงาน'**
  String get placeKindWork;

  /// No description provided for @placeKindOther.
  ///
  /// In th, this message translates to:
  /// **'สถานที่'**
  String get placeKindOther;

  /// No description provided for @placeDemoSiam.
  ///
  /// In th, this message translates to:
  /// **'สยาม'**
  String get placeDemoSiam;

  /// No description provided for @placeDemoThonglor.
  ///
  /// In th, this message translates to:
  /// **'ทองหล่อ'**
  String get placeDemoThonglor;

  /// No description provided for @placeDemoImpact.
  ///
  /// In th, this message translates to:
  /// **'อิมแพ็ค'**
  String get placeDemoImpact;

  /// No description provided for @locationGpsOff.
  ///
  /// In th, this message translates to:
  /// **'GPS ปิดอยู่'**
  String get locationGpsOff;

  /// No description provided for @locationDenied.
  ///
  /// In th, this message translates to:
  /// **'ไม่ได้อนุญาตให้ใช้ตำแหน่ง'**
  String get locationDenied;

  /// No description provided for @locationUnavailable.
  ///
  /// In th, this message translates to:
  /// **'หาตำแหน่งไม่ได้'**
  String get locationUnavailable;

  /// No description provided for @locationCurrent.
  ///
  /// In th, this message translates to:
  /// **'ตำแหน่งปัจจุบัน'**
  String get locationCurrent;

  /// No description provided for @locationFallbackSpot.
  ///
  /// In th, this message translates to:
  /// **'ถ.รัชดาภิเษก หน้าซอยลาดพร้าว 32'**
  String get locationFallbackSpot;

  /// No description provided for @placesPinLabel.
  ///
  /// In th, this message translates to:
  /// **'หมุดตำแหน่ง {lat}, {lng}'**
  String placesPinLabel(String lat, String lng);

  /// No description provided for @placesDismiss.
  ///
  /// In th, this message translates to:
  /// **'ปิด'**
  String get placesDismiss;

  /// No description provided for @placesNotConnected.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่เชื่อมต่อ'**
  String get placesNotConnected;

  /// No description provided for @placesNotConnectedDetail.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่เชื่อมต่อ · {detail}'**
  String placesNotConnectedDetail(String detail);

  /// No description provided for @placesConnecting.
  ///
  /// In th, this message translates to:
  /// **'กำลังเชื่อมต่อ…'**
  String get placesConnecting;

  /// No description provided for @placesConnected.
  ///
  /// In th, this message translates to:
  /// **'เชื่อมต่อแล้ว'**
  String get placesConnected;

  /// No description provided for @placesConnectFailed.
  ///
  /// In th, this message translates to:
  /// **'เชื่อมต่อไม่สำเร็จ ลองอีกครั้ง'**
  String get placesConnectFailed;

  /// No description provided for @placesComingSoon.
  ///
  /// In th, this message translates to:
  /// **'เร็ว ๆ นี้'**
  String get placesComingSoon;

  /// No description provided for @placesConnect.
  ///
  /// In th, this message translates to:
  /// **'เชื่อมต่อ'**
  String get placesConnect;

  /// No description provided for @placesDisconnect.
  ///
  /// In th, this message translates to:
  /// **'ยกเลิก'**
  String get placesDisconnect;

  /// No description provided for @placesRetry.
  ///
  /// In th, this message translates to:
  /// **'ลองอีกครั้ง'**
  String get placesRetry;

  /// No description provided for @placesSearching.
  ///
  /// In th, this message translates to:
  /// **'กำลังค้นหา'**
  String get placesSearching;

  /// No description provided for @onboardingHeadline.
  ///
  /// In th, this message translates to:
  /// **'ให้แอปเตือนก่อนกลับบ้าน'**
  String get onboardingHeadline;

  /// No description provided for @onboardingIntro.
  ///
  /// In th, this message translates to:
  /// **'บอกว่าบ้านกับที่ทำงานอยู่ไหน แอปจะเช็กฝนและน้ำท่วมบนทางกลับให้ทุกเย็น และดูความเสี่ยงน้ำท่วมหน้าบ้าน'**
  String get onboardingIntro;

  /// No description provided for @onboardingSkipNote.
  ///
  /// In th, this message translates to:
  /// **'ข้ามไปก่อนก็ได้ ถามเองได้เสมอ'**
  String get onboardingSkipNote;

  /// No description provided for @onboardingStart.
  ///
  /// In th, this message translates to:
  /// **'เริ่มใช้'**
  String get onboardingStart;

  /// No description provided for @onboardingSkip.
  ///
  /// In th, this message translates to:
  /// **'ข้ามไปก่อน'**
  String get onboardingSkip;

  /// No description provided for @onboardingSet.
  ///
  /// In th, this message translates to:
  /// **'ตั้งแล้ว'**
  String get onboardingSet;

  /// No description provided for @onboardingHomeHint.
  ///
  /// In th, this message translates to:
  /// **'ใช้เตือนก่อนกลับบ้าน และดูน้ำท่วมหน้าบ้าน'**
  String get onboardingHomeHint;

  /// No description provided for @onboardingWorkHint.
  ///
  /// In th, this message translates to:
  /// **'ไม่บังคับ · ทำให้เตือนตอนเลิกงานได้แม่นขึ้น'**
  String get onboardingWorkHint;

  /// No description provided for @onboardingWorkSummary.
  ///
  /// In th, this message translates to:
  /// **'{name} · {days} ออก {time}'**
  String onboardingWorkSummary(String name, String days, String time);

  /// No description provided for @onboardingUseHere.
  ///
  /// In th, this message translates to:
  /// **'ใช้ตำแหน่งตอนนี้'**
  String get onboardingUseHere;

  /// No description provided for @onboardingSearch.
  ///
  /// In th, this message translates to:
  /// **'ค้นหา'**
  String get onboardingSearch;

  /// No description provided for @onboardingEdit.
  ///
  /// In th, this message translates to:
  /// **'แก้ไข'**
  String get onboardingEdit;

  /// No description provided for @pickerDeleted.
  ///
  /// In th, this message translates to:
  /// **'ลบ “{label}” แล้ว'**
  String pickerDeleted(String label);

  /// No description provided for @pickerUndo.
  ///
  /// In th, this message translates to:
  /// **'เลิกทำ'**
  String get pickerUndo;

  /// No description provided for @pickerTitlePoint.
  ///
  /// In th, this message translates to:
  /// **'เลือกจุด'**
  String get pickerTitlePoint;

  /// No description provided for @pickerTitleMove.
  ///
  /// In th, this message translates to:
  /// **'ย้าย{label}'**
  String pickerTitleMove(String label);

  /// No description provided for @pickerTitleHome.
  ///
  /// In th, this message translates to:
  /// **'ตั้งบ้าน'**
  String get pickerTitleHome;

  /// No description provided for @pickerTitleWork.
  ///
  /// In th, this message translates to:
  /// **'ตั้งที่ทำงาน'**
  String get pickerTitleWork;

  /// No description provided for @pickerTitleOther.
  ///
  /// In th, this message translates to:
  /// **'เพิ่มสถานที่'**
  String get pickerTitleOther;

  /// No description provided for @pickerSubtitle.
  ///
  /// In th, this message translates to:
  /// **'ค้นหา หรือใช้ตำแหน่งตอนนี้'**
  String get pickerSubtitle;

  /// No description provided for @pickerHintTyping.
  ///
  /// In th, this message translates to:
  /// **'พิมพ์อย่างน้อย {count} ตัวอักษร ชื่อสถานี BTS ห้าง ซอย หรือเขต'**
  String pickerHintTyping(int count);

  /// No description provided for @pickerSearchFailedTitle.
  ///
  /// In th, this message translates to:
  /// **'ค้นหาไม่ได้'**
  String get pickerSearchFailedTitle;

  /// No description provided for @pickerSearchFailedMessage.
  ///
  /// In th, this message translates to:
  /// **'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ และไม่มีรายชื่อสถานที่ในเครื่อง'**
  String get pickerSearchFailedMessage;

  /// No description provided for @pickerNoResultsTitle.
  ///
  /// In th, this message translates to:
  /// **'ไม่พบ “{query}”'**
  String pickerNoResultsTitle(String query);

  /// No description provided for @pickerNoResultsMessage.
  ///
  /// In th, this message translates to:
  /// **'ลองพิมพ์ชื่อสถานี BTS หรือห้าง'**
  String get pickerNoResultsMessage;

  /// No description provided for @pickerNoResultsMessageOffline.
  ///
  /// In th, this message translates to:
  /// **'ลองพิมพ์ชื่อสถานี BTS หรือห้าง ตอนนี้ค้นได้เฉพาะรายชื่อในเครื่อง'**
  String get pickerNoResultsMessageOffline;

  /// No description provided for @pickerUseLocation.
  ///
  /// In th, this message translates to:
  /// **'ใช้ตำแหน่งตอนนี้'**
  String get pickerUseLocation;

  /// No description provided for @pickerSearchOnlineAgain.
  ///
  /// In th, this message translates to:
  /// **'ค้นออนไลน์อีกครั้ง'**
  String get pickerSearchOnlineAgain;

  /// No description provided for @pickerOfflineNotice.
  ///
  /// In th, this message translates to:
  /// **'ค้นออนไลน์ไม่ได้ แสดงข้อมูลในเครื่อง'**
  String get pickerOfflineNotice;

  /// No description provided for @pickerOutOfArea.
  ///
  /// In th, this message translates to:
  /// **'นอกพื้นที่'**
  String get pickerOutOfArea;

  /// No description provided for @pickerSourceGoogle.
  ///
  /// In th, this message translates to:
  /// **'ผลการค้นหาจาก Google Maps'**
  String get pickerSourceGoogle;

  /// No description provided for @pickerSourceLocal.
  ///
  /// In th, this message translates to:
  /// **'สถานี BTS/MRT ห้าง และเขตในกรุงเทพฯ'**
  String get pickerSourceLocal;

  /// No description provided for @pickerSearchHint.
  ///
  /// In th, this message translates to:
  /// **'ชื่อสถานที่ เช่น BTS อารีย์ หรือ Central'**
  String get pickerSearchHint;

  /// No description provided for @pickerClear.
  ///
  /// In th, this message translates to:
  /// **'ล้าง'**
  String get pickerClear;

  /// No description provided for @pickerNaming.
  ///
  /// In th, this message translates to:
  /// **'กำลังหาชื่อสถานที่…'**
  String get pickerNaming;

  /// No description provided for @pickerDroppedPin.
  ///
  /// In th, this message translates to:
  /// **'ตำแหน่งที่ปักหมุด'**
  String get pickerDroppedPin;

  /// No description provided for @pickerHereNow.
  ///
  /// In th, this message translates to:
  /// **'ตำแหน่งตอนนี้'**
  String get pickerHereNow;

  /// No description provided for @locateBusy.
  ///
  /// In th, this message translates to:
  /// **'กำลังหาตำแหน่ง…'**
  String get locateBusy;

  /// No description provided for @locateBusyHint.
  ///
  /// In th, this message translates to:
  /// **'ใช้ GPS ของเครื่อง ไม่เกิน 10 วินาที'**
  String get locateBusyHint;

  /// No description provided for @locateSearchInstead.
  ///
  /// In th, this message translates to:
  /// **'ค้นหาแทน'**
  String get locateSearchInstead;

  /// No description provided for @locateIdleHint.
  ///
  /// In th, this message translates to:
  /// **'หาจาก GPS แล้วให้ยืนยันก่อนบันทึก'**
  String get locateIdleHint;

  /// No description provided for @locateAskTitle.
  ///
  /// In th, this message translates to:
  /// **'ขอใช้ตำแหน่งครั้งนี้'**
  String get locateAskTitle;

  /// No description provided for @locateAskMessage.
  ///
  /// In th, this message translates to:
  /// **'แอปใช้ตำแหน่งเพื่อหาว่าตรงนี้คือที่ไหนเท่านั้น ไม่เก็บประวัติการเดินทาง'**
  String get locateAskMessage;

  /// No description provided for @locateAllow.
  ///
  /// In th, this message translates to:
  /// **'อนุญาตตำแหน่ง'**
  String get locateAllow;

  /// No description provided for @locateDeniedTitle.
  ///
  /// In th, this message translates to:
  /// **'ไม่ได้รับสิทธิ์ตำแหน่ง'**
  String get locateDeniedTitle;

  /// No description provided for @locateDeniedForeverMessage.
  ///
  /// In th, this message translates to:
  /// **'เปิดสิทธิ์ตำแหน่งให้ฝนตกไหมในการตั้งค่าของเครื่อง หรือค้นหาชื่อสถานที่แทน'**
  String get locateDeniedForeverMessage;

  /// No description provided for @locateDeniedMessage.
  ///
  /// In th, this message translates to:
  /// **'อนุญาตได้ในการตั้งค่าของแอป หรือค้นหาชื่อสถานที่แทน'**
  String get locateDeniedMessage;

  /// No description provided for @locateOpenSettings.
  ///
  /// In th, this message translates to:
  /// **'เปิดการตั้งค่า'**
  String get locateOpenSettings;

  /// No description provided for @locateOffTitle.
  ///
  /// In th, this message translates to:
  /// **'ตำแหน่งปิดอยู่'**
  String get locateOffTitle;

  /// No description provided for @locateOffMessage.
  ///
  /// In th, this message translates to:
  /// **'เปิดบริการตำแหน่งของเครื่องก่อน หรือค้นหาชื่อสถานที่แทน'**
  String get locateOffMessage;

  /// No description provided for @locateOpenLocationSettings.
  ///
  /// In th, this message translates to:
  /// **'เปิดการตั้งค่าตำแหน่ง'**
  String get locateOpenLocationSettings;

  /// No description provided for @locateTimeoutTitle.
  ///
  /// In th, this message translates to:
  /// **'หาตำแหน่งไม่ทันเวลา'**
  String get locateTimeoutTitle;

  /// No description provided for @locateErrorTitle.
  ///
  /// In th, this message translates to:
  /// **'หาตำแหน่งไม่ได้'**
  String get locateErrorTitle;

  /// No description provided for @locateWeakMessage.
  ///
  /// In th, this message translates to:
  /// **'สัญญาณ GPS อ่อน ลองอีกครั้งใกล้หน้าต่าง หรือค้นหาชื่อสถานที่แทน'**
  String get locateWeakMessage;

  /// No description provided for @sheetEdit.
  ///
  /// In th, this message translates to:
  /// **'แก้{label}'**
  String sheetEdit(String label);

  /// No description provided for @sheetConfirm.
  ///
  /// In th, this message translates to:
  /// **'ยืนยัน{label}'**
  String sheetConfirm(String label);

  /// No description provided for @sheetSourceGps.
  ///
  /// In th, this message translates to:
  /// **'ตำแหน่งจาก GPS'**
  String get sheetSourceGps;

  /// No description provided for @sheetSourceSaved.
  ///
  /// In th, this message translates to:
  /// **'บันทึกไว้ในเครื่อง'**
  String get sheetSourceSaved;

  /// No description provided for @sheetSourceLocal.
  ///
  /// In th, this message translates to:
  /// **'ข้อมูลในเครื่อง'**
  String get sheetSourceLocal;

  /// No description provided for @sheetOutOfArea.
  ///
  /// In th, this message translates to:
  /// **'นอกพื้นที่ที่แอปรองรับ ยังเตือนฝนได้ แต่ไม่มีข้อมูลจุดน้ำท่วมและระดับคลอง'**
  String get sheetOutOfArea;

  /// No description provided for @sheetLowAccuracy.
  ///
  /// In th, this message translates to:
  /// **'ตำแหน่งอาจคลาดเคลื่อน {distance}'**
  String sheetLowAccuracy(String distance);

  /// No description provided for @sheetWorkFromHome.
  ///
  /// In th, this message translates to:
  /// **'ทำงานที่บ้าน — แอปจะเตือนเฉพาะทริปอื่น'**
  String get sheetWorkFromHome;

  /// No description provided for @sheetDuplicate.
  ///
  /// In th, this message translates to:
  /// **'ใกล้กับ ‘{label}’ ที่บันทึกไว้'**
  String sheetDuplicate(String label);

  /// No description provided for @sheetNameLabel.
  ///
  /// In th, this message translates to:
  /// **'ชื่อที่เรียก'**
  String get sheetNameLabel;

  /// No description provided for @sheetIcon.
  ///
  /// In th, this message translates to:
  /// **'ไอคอน'**
  String get sheetIcon;

  /// No description provided for @sheetWorkDays.
  ///
  /// In th, this message translates to:
  /// **'วันทำงาน'**
  String get sheetWorkDays;

  /// No description provided for @sheetLeaveTime.
  ///
  /// In th, this message translates to:
  /// **'เวลาออกจากที่ทำงานปกติ'**
  String get sheetLeaveTime;

  /// No description provided for @sheetLeaveHint.
  ///
  /// In th, this message translates to:
  /// **'แอปเช็กทางกลับบ้านให้ก่อนเวลานี้'**
  String get sheetLeaveHint;

  /// No description provided for @sheetUpdateExisting.
  ///
  /// In th, this message translates to:
  /// **'อัปเดตที่เดิม'**
  String get sheetUpdateExisting;

  /// No description provided for @sheetSaveSeparate.
  ///
  /// In th, this message translates to:
  /// **'บันทึกแยก'**
  String get sheetSaveSeparate;

  /// No description provided for @sheetSave.
  ///
  /// In th, this message translates to:
  /// **'บันทึก'**
  String get sheetSave;

  /// No description provided for @sheetMove.
  ///
  /// In th, this message translates to:
  /// **'ย้ายตำแหน่ง'**
  String get sheetMove;

  /// No description provided for @sheetDelete.
  ///
  /// In th, this message translates to:
  /// **'ลบ{label}'**
  String sheetDelete(String label);

  /// No description provided for @sheetTooMany.
  ///
  /// In th, this message translates to:
  /// **'บันทึกได้ไม่เกิน {max} แห่ง ลบที่เดิมก่อนจึงเพิ่มได้'**
  String sheetTooMany(int max);

  /// No description provided for @onboardingAppName.
  ///
  /// In th, this message translates to:
  /// **'ฝนตกไหม'**
  String get onboardingAppName;

  /// No description provided for @pickerPinnedSpot.
  ///
  /// In th, this message translates to:
  /// **'ตำแหน่งที่ปักหมุด'**
  String get pickerPinnedSpot;

  /// No description provided for @pickerNearPlace.
  ///
  /// In th, this message translates to:
  /// **'ใกล้{name}'**
  String pickerNearPlace(String name);

  /// No description provided for @pickerAboutAway.
  ///
  /// In th, this message translates to:
  /// **'{address} · ห่างราว {meters} ม.'**
  String pickerAboutAway(String address, int meters);

  /// No description provided for @settingsGoogleTitle.
  ///
  /// In th, this message translates to:
  /// **'เชื่อมต่อ Google'**
  String get settingsGoogleTitle;

  /// No description provided for @settingsGoogleSubtitle.
  ///
  /// In th, this message translates to:
  /// **'ปฏิทินและ Gmail ลงชื่อเข้าใช้ครั้งเดียว'**
  String get settingsGoogleSubtitle;

  /// No description provided for @settingsGoogleUseTitle.
  ///
  /// In th, this message translates to:
  /// **'สิ่งที่แอปอ่าน'**
  String get settingsGoogleUseTitle;

  /// No description provided for @settingsGoogleCalendarUse.
  ///
  /// In th, this message translates to:
  /// **'ปฏิทิน: นัดที่มีเวลาและสถานที่ เพื่อบอกว่าควรออกกี่โมง'**
  String get settingsGoogleCalendarUse;

  /// No description provided for @settingsGoogleGmailUse.
  ///
  /// In th, this message translates to:
  /// **'Gmail: เฉพาะอีเมลยืนยันตั๋วและการจอง'**
  String get settingsGoogleGmailUse;

  /// No description provided for @settingsGooglePrivacy.
  ///
  /// In th, this message translates to:
  /// **'อ่านอย่างเดียว ไม่แก้ไขหรือลบอะไร นัดของคุณถูกเก็บไว้บนเซิร์ฟเวอร์ของเราระหว่างที่ใช้แอป'**
  String get settingsGooglePrivacy;

  /// No description provided for @settingsGoogleSignIn.
  ///
  /// In th, this message translates to:
  /// **'ลงชื่อเข้าใช้ด้วย Google'**
  String get settingsGoogleSignIn;

  /// No description provided for @settingsGoogleWaiting.
  ///
  /// In th, this message translates to:
  /// **'กำลังรอ Google…'**
  String get settingsGoogleWaiting;

  /// No description provided for @settingsGoogleWaitingHint.
  ///
  /// In th, this message translates to:
  /// **'ลงชื่อเข้าใช้ใน Google ให้เสร็จ แล้วกลับมาที่แอปนี้'**
  String get settingsGoogleWaitingHint;

  /// No description provided for @settingsGoogleFailed.
  ///
  /// In th, this message translates to:
  /// **'Google ยังไม่ยืนยันการลงชื่อเข้าใช้ ลองอีกครั้ง'**
  String get settingsGoogleFailed;

  /// No description provided for @settingsGoogleConnected.
  ///
  /// In th, this message translates to:
  /// **'เชื่อมต่อแล้วกับ {email}'**
  String settingsGoogleConnected(String email);

  /// No description provided for @settingsGoogleCancel.
  ///
  /// In th, this message translates to:
  /// **'ยกเลิก'**
  String get settingsGoogleCancel;

  /// No description provided for @modeCar.
  ///
  /// In th, this message translates to:
  /// **'รถยนต์'**
  String get modeCar;

  /// No description provided for @modeTransit.
  ///
  /// In th, this message translates to:
  /// **'BTS / MRT'**
  String get modeTransit;

  /// No description provided for @modeMoto.
  ///
  /// In th, this message translates to:
  /// **'มอเตอร์ไซค์'**
  String get modeMoto;

  /// No description provided for @modeCarShort.
  ///
  /// In th, this message translates to:
  /// **'รถยนต์'**
  String get modeCarShort;

  /// No description provided for @modeTransitShort.
  ///
  /// In th, this message translates to:
  /// **'รถไฟฟ้า'**
  String get modeTransitShort;

  /// No description provided for @modeMotoShort.
  ///
  /// In th, this message translates to:
  /// **'มอไซค์'**
  String get modeMotoShort;

  /// No description provided for @riskLow.
  ///
  /// In th, this message translates to:
  /// **'เสี่ยงต่ำ'**
  String get riskLow;

  /// No description provided for @riskMedium.
  ///
  /// In th, this message translates to:
  /// **'เสี่ยงกลาง'**
  String get riskMedium;

  /// No description provided for @riskHigh.
  ///
  /// In th, this message translates to:
  /// **'เสี่ยงสูง'**
  String get riskHigh;

  /// No description provided for @boardLeaveOk.
  ///
  /// In th, this message translates to:
  /// **'ออกได้'**
  String get boardLeaveOk;

  /// No description provided for @boardLeaveWithBuffer.
  ///
  /// In th, this message translates to:
  /// **'เผื่อเวลา'**
  String get boardLeaveWithBuffer;

  /// No description provided for @boardWait.
  ///
  /// In th, this message translates to:
  /// **'รอก่อน'**
  String get boardWait;

  /// No description provided for @boardSwitchMode.
  ///
  /// In th, this message translates to:
  /// **'เปลี่ยนทาง'**
  String get boardSwitchMode;

  /// No description provided for @boardDontGo.
  ///
  /// In th, this message translates to:
  /// **'งดไป'**
  String get boardDontGo;

  /// No description provided for @homeLevelNormal.
  ///
  /// In th, this message translates to:
  /// **'ปกติ'**
  String get homeLevelNormal;

  /// No description provided for @homeLevelWatch.
  ///
  /// In th, this message translates to:
  /// **'จับตา'**
  String get homeLevelWatch;

  /// No description provided for @homeLevelDanger.
  ///
  /// In th, this message translates to:
  /// **'อันตราย'**
  String get homeLevelDanger;

  /// No description provided for @passableYes.
  ///
  /// In th, this message translates to:
  /// **'ผ่านได้'**
  String get passableYes;

  /// No description provided for @passableSlow.
  ///
  /// In th, this message translates to:
  /// **'ผ่านช้า ๆ'**
  String get passableSlow;

  /// No description provided for @passableNo.
  ///
  /// In th, this message translates to:
  /// **'ไม่ควรผ่าน'**
  String get passableNo;

  /// No description provided for @approxMeters.
  ///
  /// In th, this message translates to:
  /// **'~{meters} ม.'**
  String approxMeters(int meters);

  /// No description provided for @approxKm.
  ///
  /// In th, this message translates to:
  /// **'~{km} กม.'**
  String approxKm(String km);

  /// No description provided for @weekdayInitial.
  ///
  /// In th, this message translates to:
  /// **'{day, select, 1{จ} 2{อ} 3{พ} 4{พฤ} 5{ศ} 6{ส} 7{อา} other{}}'**
  String weekdayInitial(String day);

  /// No description provided for @weekdayName.
  ///
  /// In th, this message translates to:
  /// **'{day, select, 1{จันทร์} 2{อังคาร} 3{พุธ} 4{พฤหัส} 5{ศุกร์} 6{เสาร์} 7{อาทิตย์} other{}}'**
  String weekdayName(String day);

  /// No description provided for @monthShort.
  ///
  /// In th, this message translates to:
  /// **'{month, select, 1{ม.ค.} 2{ก.พ.} 3{มี.ค.} 4{เม.ย.} 5{พ.ค.} 6{มิ.ย.} 7{ก.ค.} 8{ส.ค.} 9{ก.ย.} 10{ต.ค.} 11{พ.ย.} 12{ธ.ค.} other{}}'**
  String monthShort(String month);

  /// No description provided for @workDaysEveryday.
  ///
  /// In th, this message translates to:
  /// **'ทุกวัน'**
  String get workDaysEveryday;

  /// No description provided for @workDaysWeekdays.
  ///
  /// In th, this message translates to:
  /// **'จ–ศ'**
  String get workDaysWeekdays;

  /// No description provided for @navSummary.
  ///
  /// In th, this message translates to:
  /// **'สรุป'**
  String get navSummary;

  /// No description provided for @navEvents.
  ///
  /// In th, this message translates to:
  /// **'อีเวนต์'**
  String get navEvents;

  /// No description provided for @navAsk.
  ///
  /// In th, this message translates to:
  /// **'ถามเส้นทาง'**
  String get navAsk;

  /// No description provided for @summaryTitle.
  ///
  /// In th, this message translates to:
  /// **'สรุป'**
  String get summaryTitle;

  /// No description provided for @summaryNextEvent.
  ///
  /// In th, this message translates to:
  /// **'อีเวนต์ถัดไป'**
  String get summaryNextEvent;

  /// No description provided for @summaryIn.
  ///
  /// In th, this message translates to:
  /// **'อีก {duration}'**
  String summaryIn(String duration);

  /// No description provided for @summaryStarted.
  ///
  /// In th, this message translates to:
  /// **'เริ่มแล้ว'**
  String get summaryStarted;

  /// No description provided for @durationHm.
  ///
  /// In th, this message translates to:
  /// **'{h} ชม. {m} นาที'**
  String durationHm(String h, String m);

  /// No description provided for @durationH.
  ///
  /// In th, this message translates to:
  /// **'{h} ชม.'**
  String durationH(String h);

  /// No description provided for @durationM.
  ///
  /// In th, this message translates to:
  /// **'{m} นาที'**
  String durationM(String m);

  /// No description provided for @durationD.
  ///
  /// In th, this message translates to:
  /// **'{d} วัน'**
  String durationD(String d);

  /// No description provided for @summaryLeaveBefore.
  ///
  /// In th, this message translates to:
  /// **'ควรออกก่อน'**
  String get summaryLeaveBefore;

  /// No description provided for @summaryLeaveAt.
  ///
  /// In th, this message translates to:
  /// **'ออกได้ตอน'**
  String get summaryLeaveAt;

  /// No description provided for @summaryLeaveNow.
  ///
  /// In th, this message translates to:
  /// **'ออกได้เลย'**
  String get summaryLeaveNow;

  /// No description provided for @summaryOverdue.
  ///
  /// In th, this message translates to:
  /// **'ควรออกตั้งแต่ {time}'**
  String summaryOverdue(String time);

  /// No description provided for @summaryGoNow.
  ///
  /// In th, this message translates to:
  /// **'ออกเลย'**
  String get summaryGoNow;

  /// No description provided for @summaryAvoid.
  ///
  /// In th, this message translates to:
  /// **'เลี่ยงการเดินทาง'**
  String get summaryAvoid;

  /// No description provided for @summaryBy.
  ///
  /// In th, this message translates to:
  /// **'ไปด้วย'**
  String get summaryBy;

  /// No description provided for @summaryArrive.
  ///
  /// In th, this message translates to:
  /// **'ถึงราว'**
  String get summaryArrive;

  /// No description provided for @summaryRain.
  ///
  /// In th, this message translates to:
  /// **'ฝนระหว่างทาง'**
  String get summaryRain;

  /// No description provided for @summaryRainNone.
  ///
  /// In th, this message translates to:
  /// **'ไม่มีฝน'**
  String get summaryRainNone;

  /// No description provided for @summaryRainLight.
  ///
  /// In th, this message translates to:
  /// **'ฝนเบา'**
  String get summaryRainLight;

  /// No description provided for @summaryRainModerate.
  ///
  /// In th, this message translates to:
  /// **'ฝนปานกลาง'**
  String get summaryRainModerate;

  /// No description provided for @summaryRainHeavy.
  ///
  /// In th, this message translates to:
  /// **'ฝนหนัก'**
  String get summaryRainHeavy;

  /// No description provided for @summaryLater.
  ///
  /// In th, this message translates to:
  /// **'ต่อจากนี้'**
  String get summaryLater;

  /// No description provided for @summarySeeAll.
  ///
  /// In th, this message translates to:
  /// **'ดูทั้งหมด'**
  String get summarySeeAll;

  /// No description provided for @summaryDecideError.
  ///
  /// In th, this message translates to:
  /// **'ยังคำนวณเวลาออกไม่ได้'**
  String get summaryDecideError;

  /// No description provided for @summaryRetry.
  ///
  /// In th, this message translates to:
  /// **'ลองใหม่'**
  String get summaryRetry;

  /// No description provided for @summarySetPlace.
  ///
  /// In th, this message translates to:
  /// **'ระบุสถานที่'**
  String get summarySetPlace;

  /// No description provided for @summaryUnresolved.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่รู้ว่าอีเวนต์นี้อยู่ที่ไหน ระบุสถานที่แล้วจะบอกเวลาออกให้'**
  String get summaryUnresolved;

  /// No description provided for @summaryNoEventsTitle.
  ///
  /// In th, this message translates to:
  /// **'ไม่มีอีเวนต์ที่กำลังจะถึง'**
  String get summaryNoEventsTitle;

  /// No description provided for @summaryNoEventsBody.
  ///
  /// In th, this message translates to:
  /// **'อีเวนต์ใหม่ใน Google Calendar จะขึ้นที่นี่เอง ระหว่างนี้ถามเส้นทางเองได้'**
  String get summaryNoEventsBody;

  /// No description provided for @summaryAskInstead.
  ///
  /// In th, this message translates to:
  /// **'ถามเส้นทางเอง'**
  String get summaryAskInstead;

  /// No description provided for @summaryConnectTitle.
  ///
  /// In th, this message translates to:
  /// **'เชื่อมปฏิทินก่อน'**
  String get summaryConnectTitle;

  /// No description provided for @summaryConnectBody.
  ///
  /// In th, this message translates to:
  /// **'ฝนตกไหมจะดูนัดถัดไปของคุณ แล้วบอกว่าควรออกกี่โมง ไปทางไหนไม่เปียก'**
  String get summaryConnectBody;

  /// No description provided for @summaryConnectCta.
  ///
  /// In th, this message translates to:
  /// **'เชื่อม Google Calendar'**
  String get summaryConnectCta;

  /// No description provided for @summaryLoadErrorTitle.
  ///
  /// In th, this message translates to:
  /// **'โหลดอีเวนต์ไม่ได้'**
  String get summaryLoadErrorTitle;

  /// No description provided for @summaryLoadErrorBody.
  ///
  /// In th, this message translates to:
  /// **'เช็กอินเทอร์เน็ตแล้วลองใหม่'**
  String get summaryLoadErrorBody;

  /// No description provided for @summaryHeroSemantics.
  ///
  /// In th, this message translates to:
  /// **'อีเวนต์ถัดไป {title} เวลา {time}. {leave}. แตะเพื่อดูรายละเอียด'**
  String summaryHeroSemantics(String title, String time, String leave);

  /// No description provided for @summaryFloodTitle.
  ///
  /// In th, this message translates to:
  /// **'น้ำท่วมใกล้บ้าน'**
  String get summaryFloodTitle;

  /// No description provided for @summaryFloodWhatToDo.
  ///
  /// In th, this message translates to:
  /// **'ดูสิ่งที่ต้องทำ'**
  String get summaryFloodWhatToDo;

  /// No description provided for @eventsTitle.
  ///
  /// In th, this message translates to:
  /// **'อีเวนต์'**
  String get eventsTitle;

  /// No description provided for @eventsSource.
  ///
  /// In th, this message translates to:
  /// **'จาก Google Calendar · {account}'**
  String eventsSource(String account);

  /// No description provided for @eventsToday.
  ///
  /// In th, this message translates to:
  /// **'วันนี้ · {date}'**
  String eventsToday(String date);

  /// No description provided for @eventsTomorrow.
  ///
  /// In th, this message translates to:
  /// **'พรุ่งนี้ · {date}'**
  String eventsTomorrow(String date);

  /// No description provided for @eventsNoTime.
  ///
  /// In th, this message translates to:
  /// **'ไม่ระบุเวลา'**
  String get eventsNoTime;

  /// No description provided for @eventsLeaveAt.
  ///
  /// In th, this message translates to:
  /// **'ออก {time} · {mode}'**
  String eventsLeaveAt(String time, String mode);

  /// No description provided for @eventsAvoid.
  ///
  /// In th, this message translates to:
  /// **'เลี่ยงการเดินทาง'**
  String get eventsAvoid;

  /// No description provided for @eventsRefresh.
  ///
  /// In th, this message translates to:
  /// **'รีเฟรช'**
  String get eventsRefresh;

  /// No description provided for @eventsCount.
  ///
  /// In th, this message translates to:
  /// **'{count} อีเวนต์'**
  String eventsCount(String count);

  /// No description provided for @askSheetTitle.
  ///
  /// In th, this message translates to:
  /// **'อยากไปไหน'**
  String get askSheetTitle;

  /// No description provided for @askTomorrowMorning.
  ///
  /// In th, this message translates to:
  /// **'พรุ่งนี้เช้าฝนตกไหม'**
  String get askTomorrowMorning;

  /// No description provided for @summaryLate.
  ///
  /// In th, this message translates to:
  /// **'ถึงหลังเวลานัด {duration}'**
  String summaryLate(String duration);

  /// No description provided for @wxRainNow.
  ///
  /// In th, this message translates to:
  /// **'ฝนกำลังตก'**
  String get wxRainNow;

  /// No description provided for @wxRainStops.
  ///
  /// In th, this message translates to:
  /// **'ฝนกำลังตก ซาราว {time}'**
  String wxRainStops(String time);

  /// No description provided for @wxRainFrom.
  ///
  /// In th, this message translates to:
  /// **'ฝนมาราว {time}'**
  String wxRainFrom(String time);

  /// No description provided for @wxMaybeRainFrom.
  ///
  /// In th, this message translates to:
  /// **'อาจมีฝนราว {time}'**
  String wxMaybeRainFrom(String time);

  /// No description provided for @wxMaybeRainNow.
  ///
  /// In th, this message translates to:
  /// **'อาจมีฝนชั่วโมงนี้ จากนั้นแห้ง'**
  String get wxMaybeRainNow;

  /// No description provided for @wxDryAhead.
  ///
  /// In th, this message translates to:
  /// **'ไม่มีฝนอีก 12 ชม.'**
  String get wxDryAhead;

  /// No description provided for @wxSunStrong.
  ///
  /// In th, this message translates to:
  /// **'แดดแรง'**
  String get wxSunStrong;

  /// No description provided for @wxHot.
  ///
  /// In th, this message translates to:
  /// **'ร้อนจัด'**
  String get wxHot;

  /// No description provided for @wxFeels.
  ///
  /// In th, this message translates to:
  /// **'รู้สึกเหมือน'**
  String get wxFeels;

  /// No description provided for @wxUv.
  ///
  /// In th, this message translates to:
  /// **'UV'**
  String get wxUv;

  /// No description provided for @wxRainChance.
  ///
  /// In th, this message translates to:
  /// **'โอกาสฝน'**
  String get wxRainChance;

  /// No description provided for @wxUvLow.
  ///
  /// In th, this message translates to:
  /// **'ต่ำ'**
  String get wxUvLow;

  /// No description provided for @wxUvModerate.
  ///
  /// In th, this message translates to:
  /// **'ปานกลาง'**
  String get wxUvModerate;

  /// No description provided for @wxUvHigh.
  ///
  /// In th, this message translates to:
  /// **'สูง'**
  String get wxUvHigh;

  /// No description provided for @wxUvVeryHigh.
  ///
  /// In th, this message translates to:
  /// **'สูงมาก'**
  String get wxUvVeryHigh;

  /// No description provided for @wxUvExtreme.
  ///
  /// In th, this message translates to:
  /// **'อันตราย'**
  String get wxUvExtreme;

  /// No description provided for @wxNow.
  ///
  /// In th, this message translates to:
  /// **'ตอนนี้'**
  String get wxNow;

  /// No description provided for @wxHumidity.
  ///
  /// In th, this message translates to:
  /// **'ความชื้น'**
  String get wxHumidity;

  /// No description provided for @wxWind.
  ///
  /// In th, this message translates to:
  /// **'ลม'**
  String get wxWind;

  /// No description provided for @wxWindKph.
  ///
  /// In th, this message translates to:
  /// **'{kph} กม./ชม.'**
  String wxWindKph(String kph);

  /// No description provided for @wxSunset.
  ///
  /// In th, this message translates to:
  /// **'อาทิตย์ตก'**
  String get wxSunset;

  /// No description provided for @carryTitle.
  ///
  /// In th, this message translates to:
  /// **'วันนี้ควรพก'**
  String get carryTitle;

  /// No description provided for @carryNothing.
  ///
  /// In th, this message translates to:
  /// **'ไม่ต้องพกอะไรเพิ่ม'**
  String get carryNothing;

  /// No description provided for @carryNothingBody.
  ///
  /// In th, this message translates to:
  /// **'อากาศดีตลอด 12 ชม.ข้างหน้า'**
  String get carryNothingBody;

  /// No description provided for @carryRaincoat.
  ///
  /// In th, this message translates to:
  /// **'เสื้อกันฝน'**
  String get carryRaincoat;

  /// No description provided for @carryUmbrella.
  ///
  /// In th, this message translates to:
  /// **'ร่ม'**
  String get carryUmbrella;

  /// No description provided for @carrySpareRaincoat.
  ///
  /// In th, this message translates to:
  /// **'เสื้อกันฝนไว้ใต้เบาะ'**
  String get carrySpareRaincoat;

  /// No description provided for @carrySpareUmbrella.
  ///
  /// In th, this message translates to:
  /// **'ร่มพับติดกระเป๋า'**
  String get carrySpareUmbrella;

  /// No description provided for @carryWhyMaybeRain.
  ///
  /// In th, this message translates to:
  /// **'อาจมีฝน {pct}% · {from}–{to}'**
  String carryWhyMaybeRain(String pct, String from, String to);

  /// No description provided for @carrySunUmbrella.
  ///
  /// In th, this message translates to:
  /// **'ร่มกันแดด'**
  String get carrySunUmbrella;

  /// No description provided for @carrySunscreen.
  ///
  /// In th, this message translates to:
  /// **'ครีมกันแดด'**
  String get carrySunscreen;

  /// No description provided for @carryWater.
  ///
  /// In th, this message translates to:
  /// **'น้ำดื่ม'**
  String get carryWater;

  /// No description provided for @carryShoes.
  ///
  /// In th, this message translates to:
  /// **'รองเท้าลุยน้ำ'**
  String get carryShoes;

  /// No description provided for @carryWhyRain.
  ///
  /// In th, this message translates to:
  /// **'ฝน {pct}% · {from}–{to}'**
  String carryWhyRain(String pct, String from, String to);

  /// No description provided for @carryWhyHeavy.
  ///
  /// In th, this message translates to:
  /// **'ฝนหนัก ร่มเอาไม่อยู่ · {from}–{to}'**
  String carryWhyHeavy(String from, String to);

  /// No description provided for @carryWhyMoto.
  ///
  /// In th, this message translates to:
  /// **'ขี่มอเตอร์ไซค์ฝ่าฝน · {from}–{to}'**
  String carryWhyMoto(String from, String to);

  /// No description provided for @carryWhyUv.
  ///
  /// In th, this message translates to:
  /// **'UV {uv} · {from}–{to}'**
  String carryWhyUv(String uv, String from, String to);

  /// No description provided for @carryWhyShade.
  ///
  /// In th, this message translates to:
  /// **'แดดแรงมาก กางร่มเดิน · {from}–{to}'**
  String carryWhyShade(String from, String to);

  /// No description provided for @carryWhyHeat.
  ///
  /// In th, this message translates to:
  /// **'รู้สึกเหมือน {c}° ดื่มบ่อย ๆ'**
  String carryWhyHeat(String c);

  /// No description provided for @carryWhyShoes.
  ///
  /// In th, this message translates to:
  /// **'น้ำขังบนถนน · {from}–{to}'**
  String carryWhyShoes(String from, String to);

  /// No description provided for @eventsAllDays.
  ///
  /// In th, this message translates to:
  /// **'ทุกวัน'**
  String get eventsAllDays;

  /// No description provided for @eventsNoneOn.
  ///
  /// In th, this message translates to:
  /// **'ไม่มีอีเวนต์วันนี้'**
  String get eventsNoneOn;

  /// No description provided for @calPrev.
  ///
  /// In th, this message translates to:
  /// **'เดือนก่อน'**
  String get calPrev;

  /// No description provided for @calNext.
  ///
  /// In th, this message translates to:
  /// **'เดือนถัดไป'**
  String get calNext;

  /// No description provided for @calMonth.
  ///
  /// In th, this message translates to:
  /// **'{month, select, 1{มกราคม} 2{กุมภาพันธ์} 3{มีนาคม} 4{เมษายน} 5{พฤษภาคม} 6{มิถุนายน} 7{กรกฎาคม} 8{สิงหาคม} 9{กันยายน} 10{ตุลาคม} 11{พฤศจิกายน} 12{ธันวาคม} other{}} {year}'**
  String calMonth(String month, String year);

  /// No description provided for @dayToday.
  ///
  /// In th, this message translates to:
  /// **'วันนี้'**
  String get dayToday;

  /// No description provided for @dayTomorrow.
  ///
  /// In th, this message translates to:
  /// **'พรุ่งนี้'**
  String get dayTomorrow;

  /// No description provided for @eventsCalendar.
  ///
  /// In th, this message translates to:
  /// **'ดูปฏิทิน'**
  String get eventsCalendar;

  /// No description provided for @planTitleToday.
  ///
  /// In th, this message translates to:
  /// **'วันนี้อีก {count} นัด'**
  String planTitleToday(String count);

  /// No description provided for @planTitleOneToday.
  ///
  /// In th, this message translates to:
  /// **'นัดหมายวันนี้'**
  String get planTitleOneToday;

  /// No description provided for @planTitleTomorrow.
  ///
  /// In th, this message translates to:
  /// **'นัดหมายพรุ่งนี้'**
  String get planTitleTomorrow;

  /// No description provided for @planTitleNextTripTomorrow.
  ///
  /// In th, this message translates to:
  /// **'เดินทางพรุ่งนี้'**
  String get planTitleNextTripTomorrow;

  /// No description provided for @planTitleUpcoming.
  ///
  /// In th, this message translates to:
  /// **'นัดหมายถัดไป'**
  String get planTitleUpcoming;

  /// No description provided for @planTitleFree.
  ///
  /// In th, this message translates to:
  /// **'วันนี้ไม่มีนัดแล้ว'**
  String get planTitleFree;

  /// No description provided for @planToday.
  ///
  /// In th, this message translates to:
  /// **'แผนต่อจากนี้'**
  String get planToday;

  /// No description provided for @planTomorrow.
  ///
  /// In th, this message translates to:
  /// **'พรุ่งนี้'**
  String get planTomorrow;

  /// No description provided for @planBring.
  ///
  /// In th, this message translates to:
  /// **'พกไปด้วย'**
  String get planBring;

  /// No description provided for @planWeatherNow.
  ///
  /// In th, this message translates to:
  /// **'อากาศตอนนี้'**
  String get planWeatherNow;

  /// No description provided for @planRainAt.
  ///
  /// In th, this message translates to:
  /// **'ฝน {pct}%'**
  String planRainAt(String pct);

  /// No description provided for @leaveIn.
  ///
  /// In th, this message translates to:
  /// **'ต้องออกใน'**
  String get leaveIn;

  /// No description provided for @leaveDue.
  ///
  /// In th, this message translates to:
  /// **'ถึงเวลาออก'**
  String get leaveDue;

  /// No description provided for @unitMin.
  ///
  /// In th, this message translates to:
  /// **'นาที'**
  String get unitMin;

  /// No description provided for @unitHour.
  ///
  /// In th, this message translates to:
  /// **'ชม.'**
  String get unitHour;

  /// No description provided for @alertsTitle.
  ///
  /// In th, this message translates to:
  /// **'ต้องรู้ก่อนออก'**
  String get alertsTitle;

  /// No description provided for @alertShort.
  ///
  /// In th, this message translates to:
  /// **'ไป {to} ไม่ทัน'**
  String alertShort(String to);

  /// No description provided for @alertShortBody.
  ///
  /// In th, this message translates to:
  /// **'{from} จบ {end} เดินทางราว {need} แต่มีเวลาแค่ {gap}'**
  String alertShortBody(String from, String end, String need, String gap);

  /// No description provided for @alertOverlap.
  ///
  /// In th, this message translates to:
  /// **'{from} กับ {to} เวลาชนกัน'**
  String alertOverlap(String from, String to);

  /// No description provided for @alertTight.
  ///
  /// In th, this message translates to:
  /// **'เวลาไป {to} เผื่อน้อย'**
  String alertTight(String to);

  /// No description provided for @alertTightBody.
  ///
  /// In th, this message translates to:
  /// **'เดินทางราว {need} มีเวลา {gap} ออกจาก {from} ให้ตรงเวลา'**
  String alertTightBody(String need, String gap, String from);

  /// No description provided for @alertWetLeave.
  ///
  /// In th, this message translates to:
  /// **'ฝน {pct}% ตอนออกไป {to}'**
  String alertWetLeave(String pct, String to);

  /// No description provided for @alertWetLeaveBody.
  ///
  /// In th, this message translates to:
  /// **'ราว {time} เลือกทางที่ไม่ต้องเดินกลางฝน'**
  String alertWetLeaveBody(String time);

  /// No description provided for @alertWetLeaveMoto.
  ///
  /// In th, this message translates to:
  /// **'ราว {time} ขี่มอเตอร์ไซค์ฝ่าฝน ใส่เสื้อกันฝนหรือเปลี่ยนไปรถไฟฟ้า'**
  String alertWetLeaveMoto(String time);

  /// No description provided for @alertWetReturn.
  ///
  /// In th, this message translates to:
  /// **'ขากลับจาก {from} ฝน {pct}%'**
  String alertWetReturn(String from, String pct);

  /// No description provided for @alertWetReturnBody.
  ///
  /// In th, this message translates to:
  /// **'เลิกราว {time} อย่าลืมพกร่มกลับด้วย'**
  String alertWetReturnBody(String time);

  /// No description provided for @alertWetReturnMoto.
  ///
  /// In th, this message translates to:
  /// **'เลิกราว {time} พกเสื้อกันฝนไว้ขี่กลับด้วย'**
  String alertWetReturnMoto(String time);

  /// No description provided for @alertNeedsPlace.
  ///
  /// In th, this message translates to:
  /// **'{title} ยังไม่มีสถานที่'**
  String alertNeedsPlace(String title);

  /// No description provided for @alertNeedsPlaceBody.
  ///
  /// In th, this message translates to:
  /// **'{when} · ระบุสถานที่เพื่อวางแผนเวลาออก'**
  String alertNeedsPlaceBody(String when);

  /// No description provided for @upNextTitle.
  ///
  /// In th, this message translates to:
  /// **'ถัดไป'**
  String get upNextTitle;

  /// No description provided for @online.
  ///
  /// In th, this message translates to:
  /// **'ออนไลน์ · ไม่ต้องเดินทาง'**
  String get online;

  /// No description provided for @allDay.
  ///
  /// In th, this message translates to:
  /// **'ทั้งวัน'**
  String get allDay;

  /// No description provided for @allDayNoLeave.
  ///
  /// In th, this message translates to:
  /// **'ไม่มีเวลาออก'**
  String get allDayNoLeave;

  /// No description provided for @allDayNote.
  ///
  /// In th, this message translates to:
  /// **'กิจกรรมทั้งวันไม่มีเวลานัด จึงไม่มีเวลาออกให้'**
  String get allDayNote;

  /// No description provided for @allDayAskRoute.
  ///
  /// In th, this message translates to:
  /// **'ถามทางไป{place}'**
  String allDayAskRoute(String place);

  /// No description provided for @stripTitle.
  ///
  /// In th, this message translates to:
  /// **'ภาพรวมวันนี้'**
  String get stripTitle;

  /// No description provided for @stripEvent.
  ///
  /// In th, this message translates to:
  /// **'นัด'**
  String get stripEvent;

  /// No description provided for @stripTravel.
  ///
  /// In th, this message translates to:
  /// **'เดินทาง'**
  String get stripTravel;

  /// No description provided for @stripRain.
  ///
  /// In th, this message translates to:
  /// **'ฝน'**
  String get stripRain;

  /// No description provided for @verdictCantDecide.
  ///
  /// In th, this message translates to:
  /// **'ยังตัดสินไม่ได้'**
  String get verdictCantDecide;

  /// No description provided for @verdictServerError.
  ///
  /// In th, this message translates to:
  /// **'ติดต่อเซิร์ฟเวอร์ไม่ได้ ตรวจอินเทอร์เน็ตแล้วลองอีกครั้ง'**
  String get verdictServerError;

  /// No description provided for @verdictRetry.
  ///
  /// In th, this message translates to:
  /// **'ลองอีกครั้ง'**
  String get verdictRetry;

  /// No description provided for @verdictSavePlace.
  ///
  /// In th, this message translates to:
  /// **'บันทึกที่นี่ไว้'**
  String get verdictSavePlace;

  /// No description provided for @verdictSavedSnack.
  ///
  /// In th, this message translates to:
  /// **'บันทึก “{label}” แล้ว'**
  String verdictSavedSnack(String label);

  /// No description provided for @verdictQuestionTitle.
  ///
  /// In th, this message translates to:
  /// **'คำถาม'**
  String get verdictQuestionTitle;

  /// No description provided for @verdictReadingQuestion.
  ///
  /// In th, this message translates to:
  /// **'กำลังอ่านคำถามของคุณ'**
  String get verdictReadingQuestion;

  /// No description provided for @verdictGoTo.
  ///
  /// In th, this message translates to:
  /// **'ไป {place}'**
  String verdictGoTo(String place);

  /// No description provided for @verdictCompareModes.
  ///
  /// In th, this message translates to:
  /// **'เทียบวิธีเดินทาง'**
  String get verdictCompareModes;

  /// No description provided for @verdictModeStatus.
  ///
  /// In th, this message translates to:
  /// **'{eta} น. · {status}'**
  String verdictModeStatus(int eta, String status);

  /// No description provided for @verdictModeStatusWithProb.
  ///
  /// In th, this message translates to:
  /// **'{eta} น. · {status} (โอกาสฝน {prob}%)'**
  String verdictModeStatusWithProb(int eta, String status, int prob);

  /// No description provided for @verdictFloodSpotsTitle.
  ///
  /// In th, this message translates to:
  /// **'จุดน้ำท่วมบนเส้นทาง'**
  String get verdictFloodSpotsTitle;

  /// No description provided for @verdictNoFloodSpots.
  ///
  /// In th, this message translates to:
  /// **'ไม่มีจุดน้ำขังบนเส้นทางนี้'**
  String get verdictNoFloodSpots;

  /// No description provided for @verdictNoFloodSpotsMsg.
  ///
  /// In th, this message translates to:
  /// **'เส้นทางนี้ไม่ผ่านจุดเสี่ยงน้ำท่วมของ กทม.'**
  String get verdictNoFloodSpotsMsg;

  /// No description provided for @verdictExpectedDepth.
  ///
  /// In th, this message translates to:
  /// **'คาดน้ำสูง {cm} ซม.'**
  String verdictExpectedDepth(int cm);

  /// No description provided for @verdictStillDry.
  ///
  /// In th, this message translates to:
  /// **'ยังแห้ง'**
  String get verdictStillDry;

  /// No description provided for @verdictTraceTitle.
  ///
  /// In th, this message translates to:
  /// **'เหตุผลที่แนะนำแบบนี้'**
  String get verdictTraceTitle;

  /// No description provided for @verdictSources.
  ///
  /// In th, this message translates to:
  /// **'แหล่งข้อมูล'**
  String get verdictSources;

  /// No description provided for @verdictSourceGps.
  ///
  /// In th, this message translates to:
  /// **'GPS ตำแหน่งปัจจุบัน'**
  String get verdictSourceGps;

  /// No description provided for @verdictAskMore.
  ///
  /// In th, this message translates to:
  /// **'ถามต่อ'**
  String get verdictAskMore;

  /// No description provided for @verdictWhyTitle.
  ///
  /// In th, this message translates to:
  /// **'ทำไมถึงแนะนำแบบนี้'**
  String get verdictWhyTitle;

  /// No description provided for @verdictRouteAdvice.
  ///
  /// In th, this message translates to:
  /// **'ทางเลี่ยงน้ำท่วม'**
  String get verdictRouteAdvice;

  /// No description provided for @verdictAvoid.
  ///
  /// In th, this message translates to:
  /// **'เลี่ยง {spot}'**
  String verdictAvoid(String spot);

  /// No description provided for @verdictHideFactors.
  ///
  /// In th, this message translates to:
  /// **'ซ่อนปัจจัย'**
  String get verdictHideFactors;

  /// No description provided for @verdictShowFactors.
  ///
  /// In th, this message translates to:
  /// **'ดูปัจจัยที่ใช้ตัดสิน ({count})'**
  String verdictShowFactors(int count);

  /// No description provided for @floodDoNow.
  ///
  /// In th, this message translates to:
  /// **'ทำตอนนี้ เรียงตามลำดับ'**
  String get floodDoNow;

  /// No description provided for @settingsTitle.
  ///
  /// In th, this message translates to:
  /// **'ตั้งค่า'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In th, this message translates to:
  /// **'ข้อมูลเก็บไว้ในเครื่องนี้'**
  String get settingsSubtitle;

  /// No description provided for @settingsNotificationsOff.
  ///
  /// In th, this message translates to:
  /// **'ปิดการแจ้งเตือนอยู่ แอปเตือนก่อนออกไม่ได้'**
  String get settingsNotificationsOff;

  /// No description provided for @settingsOpenSettings.
  ///
  /// In th, this message translates to:
  /// **'เปิดการตั้งค่า'**
  String get settingsOpenSettings;

  /// No description provided for @settingsMyPlaces.
  ///
  /// In th, this message translates to:
  /// **'สถานที่ของฉัน'**
  String get settingsMyPlaces;

  /// No description provided for @settingsSetHome.
  ///
  /// In th, this message translates to:
  /// **'ตั้งบ้าน'**
  String get settingsSetHome;

  /// No description provided for @settingsSetWork.
  ///
  /// In th, this message translates to:
  /// **'ตั้งที่ทำงาน'**
  String get settingsSetWork;

  /// No description provided for @settingsSetHomeHint.
  ///
  /// In th, this message translates to:
  /// **'ให้แอปเตือนก่อนกลับบ้าน และดูน้ำท่วมหน้าบ้าน'**
  String get settingsSetHomeHint;

  /// No description provided for @settingsSetWorkHint.
  ///
  /// In th, this message translates to:
  /// **'ให้เตือนตอนเลิกงานได้แม่นขึ้น'**
  String get settingsSetWorkHint;

  /// No description provided for @settingsWorkDetail.
  ///
  /// In th, this message translates to:
  /// **' · {days} ออก {time}'**
  String settingsWorkDetail(String days, String time);

  /// No description provided for @settingsOutOfArea.
  ///
  /// In th, this message translates to:
  /// **'นอกพื้นที่ที่รองรับ'**
  String get settingsOutOfArea;

  /// No description provided for @settingsWfh.
  ///
  /// In th, this message translates to:
  /// **'ทำงานที่บ้าน — แอปจะเตือนเฉพาะทริปอื่น'**
  String get settingsWfh;

  /// No description provided for @settingsAddPlace.
  ///
  /// In th, this message translates to:
  /// **'เพิ่มสถานที่'**
  String get settingsAddPlace;

  /// No description provided for @settingsAddPlaceHint.
  ///
  /// In th, this message translates to:
  /// **'ยิม โรงเรียนลูก บ้านพ่อแม่ · {count} จาก {max}'**
  String settingsAddPlaceHint(int count, int max);

  /// No description provided for @settingsAddPlaceFull.
  ///
  /// In th, this message translates to:
  /// **'ครบ {max} แห่งแล้ว ลบที่เดิมก่อนจึงเพิ่มได้'**
  String settingsAddPlaceFull(int max);

  /// No description provided for @settingsTravelGroup.
  ///
  /// In th, this message translates to:
  /// **'วิธีเดินทางที่ใช้ประจำ'**
  String get settingsTravelGroup;

  /// No description provided for @settingsAutoGroup.
  ///
  /// In th, this message translates to:
  /// **'ให้แอปหาทริปให้เอง'**
  String get settingsAutoGroup;

  /// No description provided for @settingsCalendarDetail.
  ///
  /// In th, this message translates to:
  /// **'เฉพาะนัดที่มีสถานที่'**
  String get settingsCalendarDetail;

  /// No description provided for @settingsCalendarAccount.
  ///
  /// In th, this message translates to:
  /// **'{account} · บัญชีจำลอง'**
  String settingsCalendarAccount(String account);

  /// No description provided for @settingsGmailHint.
  ///
  /// In th, this message translates to:
  /// **'เฉพาะอีเมลยืนยันตั๋วและนัดหมาย ไม่เก็บเนื้ออีเมล'**
  String get settingsGmailHint;

  /// No description provided for @settingsPlaceHome.
  ///
  /// In th, this message translates to:
  /// **'บ้าน'**
  String get settingsPlaceHome;

  /// No description provided for @settingsPlaceWork.
  ///
  /// In th, this message translates to:
  /// **'ที่ทำงาน'**
  String get settingsPlaceWork;

  /// No description provided for @settingsPlaceSiam.
  ///
  /// In th, this message translates to:
  /// **'สยาม'**
  String get settingsPlaceSiam;

  /// No description provided for @settingsPlaceThonglor.
  ///
  /// In th, this message translates to:
  /// **'ทองหล่อ'**
  String get settingsPlaceThonglor;

  /// No description provided for @settingsPlaceImpact.
  ///
  /// In th, this message translates to:
  /// **'อิมแพ็ค'**
  String get settingsPlaceImpact;

  /// No description provided for @verdictToolParseQuestion.
  ///
  /// In th, this message translates to:
  /// **'เข้าใจคำถาม'**
  String get verdictToolParseQuestion;

  /// No description provided for @verdictToolGetTrip.
  ///
  /// In th, this message translates to:
  /// **'ดูทริปของคุณ'**
  String get verdictToolGetTrip;

  /// No description provided for @verdictToolGetRoute.
  ///
  /// In th, this message translates to:
  /// **'หาเส้นทาง'**
  String get verdictToolGetRoute;

  /// No description provided for @verdictToolRain.
  ///
  /// In th, this message translates to:
  /// **'เช็กฝนระหว่างทาง'**
  String get verdictToolRain;

  /// No description provided for @verdictToolFloodSpots.
  ///
  /// In th, this message translates to:
  /// **'เช็กจุดน้ำท่วม'**
  String get verdictToolFloodSpots;

  /// No description provided for @verdictToolCanals.
  ///
  /// In th, this message translates to:
  /// **'เช็กระดับน้ำในคลอง'**
  String get verdictToolCanals;

  /// No description provided for @verdictToolReports.
  ///
  /// In th, this message translates to:
  /// **'ดูรายงานจากคนในพื้นที่'**
  String get verdictToolReports;

  /// No description provided for @verdictToolEvaluate.
  ///
  /// In th, this message translates to:
  /// **'ประเมินความเสี่ยง'**
  String get verdictToolEvaluate;

  /// No description provided for @verdictHotlinesTitle.
  ///
  /// In th, this message translates to:
  /// **'สายด่วนขอความช่วยเหลือฉุกเฉิน'**
  String get verdictHotlinesTitle;

  /// No description provided for @verdictHotlineCopied.
  ///
  /// In th, this message translates to:
  /// **'คัดลอกเบอร์ {number} ({purpose}) แล้ว'**
  String verdictHotlineCopied(String number, String purpose);

  /// No description provided for @verdictAccuracyDisclaimer.
  ///
  /// In th, this message translates to:
  /// **'ข้อมูลและการประเมินจาก AI อาจมีความคลาดเคลื่อนหรือไม่ถูกต้อง 100% โปรดตรวจสอบสภาพอากาศและเส้นทางจริงก่อนออกเดินทาง'**
  String get verdictAccuracyDisclaimer;

  /// No description provided for @eventsInferredPlacePrompt.
  ///
  /// In th, this message translates to:
  /// **'AI แนะนำสถานที่: {place}'**
  String eventsInferredPlacePrompt(String place);

  /// No description provided for @eventsConfirmPlace.
  ///
  /// In th, this message translates to:
  /// **'ยืนยันสถานที่'**
  String get eventsConfirmPlace;

  /// No description provided for @eventsChangePlace.
  ///
  /// In th, this message translates to:
  /// **'เปลี่ยน'**
  String get eventsChangePlace;

  /// No description provided for @partsBandTitle.
  ///
  /// In th, this message translates to:
  /// **'ฝนตามเส้นทาง'**
  String get partsBandTitle;

  /// No description provided for @partsBandHint.
  ///
  /// In th, this message translates to:
  /// **'แท่งยิ่งสูง ฝนยิ่งหนัก · ลากหมุดหรือแตะเวลาด้านล่างเพื่อเปลี่ยน'**
  String get partsBandHint;

  /// No description provided for @partsLegendOnRoad.
  ///
  /// In th, this message translates to:
  /// **'ช่วงที่อยู่บนถนน'**
  String get partsLegendOnRoad;

  /// No description provided for @partsPickArrive.
  ///
  /// In th, this message translates to:
  /// **'ถึง {time}'**
  String partsPickArrive(String time);

  /// No description provided for @partsPickLeaveHelp.
  ///
  /// In th, this message translates to:
  /// **'จะออกกี่โมง'**
  String get partsPickLeaveHelp;

  /// No description provided for @partsPickArriveHelp.
  ///
  /// In th, this message translates to:
  /// **'อยากไปถึงกี่โมง'**
  String get partsPickArriveHelp;

  /// No description provided for @partsPickTimeSemantic.
  ///
  /// In th, this message translates to:
  /// **'เปลี่ยนเวลา {what}'**
  String partsPickTimeSemantic(String what);

  /// No description provided for @partsUseSuggested.
  ///
  /// In th, this message translates to:
  /// **'ใช้เวลาที่แนะนำ'**
  String get partsUseSuggested;

  /// No description provided for @partsHeadlineLeaveArrive.
  ///
  /// In th, this message translates to:
  /// **'ออก {leave} ถึง {arrive}'**
  String partsHeadlineLeaveArrive(String leave, String arrive);

  /// No description provided for @partsHeadlineLate.
  ///
  /// In th, this message translates to:
  /// **'ออก {leave} จะสาย {min} นาที'**
  String partsHeadlineLate(String leave, int min);

  /// No description provided for @verdictGearTitle.
  ///
  /// In th, this message translates to:
  /// **'ของที่ควรพก'**
  String get verdictGearTitle;

  /// No description provided for @verdictGearWeather.
  ///
  /// In th, this message translates to:
  /// **'ช่วงเดินทาง {temp}° รู้สึกเหมือน {feels}°'**
  String verdictGearWeather(int temp, int feels);

  /// No description provided for @verdictGearTooFar.
  ///
  /// In th, this message translates to:
  /// **'พยากรณ์รายชั่วโมงยังไปไม่ถึงเวลานี้ ใกล้เวลาแล้วจะบอกว่าควรพกอะไร'**
  String get verdictGearTooFar;

  /// No description provided for @verdictGearNothingBody.
  ///
  /// In th, this message translates to:
  /// **'อากาศช่วงเดินทางกำลังดี'**
  String get verdictGearNothingBody;

  /// No description provided for @carryJacket.
  ///
  /// In th, this message translates to:
  /// **'เสื้อกันหนาว'**
  String get carryJacket;

  /// No description provided for @carryWhyCold.
  ///
  /// In th, this message translates to:
  /// **'อากาศเย็น รู้สึกเหมือน {c}° · {from}–{to}'**
  String carryWhyCold(String c, String from, String to);

  /// No description provided for @partsBandOutOfRange.
  ///
  /// In th, this message translates to:
  /// **'พยากรณ์ฝนละเอียดดูได้ล่วงหน้าแค่ 5 ชม. ใกล้เวลาเดินทางแล้วค่อยเปิดดูอีกครั้ง'**
  String get partsBandOutOfRange;

  /// No description provided for @partsHeadlineWet.
  ///
  /// In th, this message translates to:
  /// **'ออก {time} โดนฝนกลางทาง'**
  String partsHeadlineWet(String time);

  /// No description provided for @partsHeadlineRisky.
  ///
  /// In th, this message translates to:
  /// **'ออก {time} ไม่แนะนำ'**
  String partsHeadlineRisky(String time);

  /// No description provided for @partsAltMode.
  ///
  /// In th, this message translates to:
  /// **'{mode} ไปได้ ออก {leave} ถึง {arrive}'**
  String partsAltMode(String mode, String leave, String arrive);

  /// No description provided for @partsAltModeAction.
  ///
  /// In th, this message translates to:
  /// **'เปลี่ยนเป็น{mode}'**
  String partsAltModeAction(String mode);

  /// No description provided for @partsAltWait.
  ///
  /// In th, this message translates to:
  /// **'หรือรอออก {leave} ฝนซาแล้ว ถึง {arrive}'**
  String partsAltWait(String leave, String arrive);

  /// No description provided for @activityWhen.
  ///
  /// In th, this message translates to:
  /// **'วันไหน'**
  String get activityWhen;

  /// No description provided for @activityWhere.
  ///
  /// In th, this message translates to:
  /// **'ที่ไหน'**
  String get activityWhere;

  /// No description provided for @activitySearchPlace.
  ///
  /// In th, this message translates to:
  /// **'ค้นหาสถานที่'**
  String get activitySearchPlace;

  /// No description provided for @activityToday.
  ///
  /// In th, this message translates to:
  /// **'วันนี้'**
  String get activityToday;

  /// No description provided for @activityTomorrow.
  ///
  /// In th, this message translates to:
  /// **'พรุ่งนี้'**
  String get activityTomorrow;

  /// No description provided for @activityChecklistTitle.
  ///
  /// In th, this message translates to:
  /// **'ของที่ควรเตรียม'**
  String get activityChecklistTitle;

  /// No description provided for @activityGeneralNote.
  ///
  /// In th, this message translates to:
  /// **'รายการทั่วไปสำหรับกิจกรรมนี้ เลือกที่และวันแล้วจะเช็กอากาศให้'**
  String get activityGeneralNote;

  /// No description provided for @activityWeatherOn.
  ///
  /// In th, this message translates to:
  /// **'อากาศ{day}ที่{place}'**
  String activityWeatherOn(String day, String place);

  /// No description provided for @activityNoForecast.
  ///
  /// In th, this message translates to:
  /// **'พยากรณ์รายวันยังไปไม่ถึงวันนั้น ใกล้วันแล้วค่อยเปิดดูอีกครั้ง'**
  String get activityNoForecast;

  /// No description provided for @activityNeedsOrigin.
  ///
  /// In th, this message translates to:
  /// **'เปิดตำแหน่งหรือบันทึกบ้านก่อน จะได้คำนวณเส้นทางไปที่นั่น'**
  String get activityNeedsOrigin;

  /// No description provided for @activityChecked.
  ///
  /// In th, this message translates to:
  /// **'{done}/{total} ชิ้น'**
  String activityChecked(String done, String total);

  /// No description provided for @askActivitySuggestion.
  ///
  /// In th, this message translates to:
  /// **'เสาร์นี้ไปแคมป์ต้องเตรียมอะไร'**
  String get askActivitySuggestion;

  /// No description provided for @notificationsTitle.
  ///
  /// In th, this message translates to:
  /// **'การแจ้งเตือน'**
  String get notificationsTitle;

  /// No description provided for @notificationsEmptyTitle.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่มีการแจ้งเตือน'**
  String get notificationsEmptyTitle;

  /// No description provided for @notificationsEmptyBody.
  ///
  /// In th, this message translates to:
  /// **'เมื่อมีความเสี่ยงเรื่องฝน น้ำท่วม หรือเวลาออกเดินทาง ระบบจะแจ้งเตือนที่นี่'**
  String get notificationsEmptyBody;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In th, this message translates to:
  /// **'อ่านทั้งหมด'**
  String get notificationsMarkAllRead;

  /// No description provided for @eventsDismissConfirmTitle.
  ///
  /// In th, this message translates to:
  /// **'ซ่อนนัดหมายนี้ไหม?'**
  String get eventsDismissConfirmTitle;

  /// No description provided for @eventsDismissConfirmBody.
  ///
  /// In th, this message translates to:
  /// **'ซ่อน “{title}” ออกจากรายการนัดหมาย คุณสามารถกู้คืนได้ทุกเมื่อในแท็บอีเวนต์'**
  String eventsDismissConfirmBody(String title);

  /// No description provided for @eventsDismissConfirmAction.
  ///
  /// In th, this message translates to:
  /// **'ซ่อนนัดหมาย'**
  String get eventsDismissConfirmAction;

  /// No description provided for @eventsDismissedBanner.
  ///
  /// In th, this message translates to:
  /// **'ซ่อนนัดหมายไว้ {count} รายการ · กดเพื่อกู้คืน'**
  String eventsDismissedBanner(int count);

  /// No description provided for @eventsDismissedSheetTitle.
  ///
  /// In th, this message translates to:
  /// **'นัดหมายที่ซ่อนไว้'**
  String get eventsDismissedSheetTitle;

  /// No description provided for @eventsRestoreOne.
  ///
  /// In th, this message translates to:
  /// **'แสดงอีกครั้ง'**
  String get eventsRestoreOne;

  /// No description provided for @eventsRestoreAll.
  ///
  /// In th, this message translates to:
  /// **'คืนค่าทั้งหมด'**
  String get eventsRestoreAll;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'th'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'th':
      return AppLocalizationsTh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

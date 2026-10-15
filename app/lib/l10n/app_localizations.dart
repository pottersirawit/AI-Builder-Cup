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

  /// No description provided for @shellTabTrip.
  ///
  /// In th, this message translates to:
  /// **'เดินทาง'**
  String get shellTabTrip;

  /// No description provided for @shellTabReport.
  ///
  /// In th, this message translates to:
  /// **'แจ้งน้ำท่วม'**
  String get shellTabReport;

  /// No description provided for @shellTabHome.
  ///
  /// In th, this message translates to:
  /// **'บ้าน'**
  String get shellTabHome;

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
  /// **'เจอฝนปรอยช่วงท้าย ขับช้าลง'**
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

  /// No description provided for @homeLoadErrorTitle.
  ///
  /// In th, this message translates to:
  /// **'โหลดทริปไม่ได้'**
  String get homeLoadErrorTitle;

  /// No description provided for @homeLoadErrorBody.
  ///
  /// In th, this message translates to:
  /// **'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้และไม่มีข้อมูลตัวอย่างในเครื่อง ตรวจอินเทอร์เน็ตแล้วลองอีกครั้ง'**
  String get homeLoadErrorBody;

  /// No description provided for @homeSeeWhatToDo.
  ///
  /// In th, this message translates to:
  /// **'ดูสิ่งที่ต้องทำตอนนี้'**
  String get homeSeeWhatToDo;

  /// No description provided for @homeDecideErrorTitle.
  ///
  /// In th, this message translates to:
  /// **'ยังตัดสินไม่ได้'**
  String get homeDecideErrorTitle;

  /// No description provided for @homeDecideErrorBody.
  ///
  /// In th, this message translates to:
  /// **'ติดต่อเซิร์ฟเวอร์ไม่ได้ ตรวจอินเทอร์เน็ตแล้วลองอีกครั้ง'**
  String get homeDecideErrorBody;

  /// No description provided for @homeSeeReasons.
  ///
  /// In th, this message translates to:
  /// **'ดูเหตุผลและทางเลือก'**
  String get homeSeeReasons;

  /// No description provided for @homeAskMore.
  ///
  /// In th, this message translates to:
  /// **'ถามต่อ'**
  String get homeAskMore;

  /// No description provided for @homeNoTripTitle.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่มีทริป'**
  String get homeNoTripTitle;

  /// No description provided for @homeNoTripBody.
  ///
  /// In th, this message translates to:
  /// **'ตั้งบ้านไว้ แอปจะเตือนก่อนเวลาเลิกงานทุกวัน หรือพิมพ์ถามด้านบนได้เลย'**
  String get homeNoTripBody;

  /// No description provided for @homeSetHome.
  ///
  /// In th, this message translates to:
  /// **'ตั้งบ้าน'**
  String get homeSetHome;

  /// No description provided for @homeSetWork.
  ///
  /// In th, this message translates to:
  /// **'ตั้งที่ทำงาน'**
  String get homeSetWork;

  /// No description provided for @homeNoHomeTripTitle.
  ///
  /// In th, this message translates to:
  /// **'วันนี้ไม่มีทริปกลับบ้าน'**
  String get homeNoHomeTripTitle;

  /// No description provided for @homeWfhBody.
  ///
  /// In th, this message translates to:
  /// **'ทำงานที่บ้าน แอปจะเตือนเฉพาะทริปอื่น พิมพ์ถามด้านล่างได้เลย เช่น “ห้าโมงไปสยาม”'**
  String get homeWfhBody;

  /// No description provided for @homeNotWorkdayBody.
  ///
  /// In th, this message translates to:
  /// **'วันนี้ไม่ใช่วันทำงาน ถ้าจะออกไปไหน พิมพ์ถามด้านล่างได้เลย'**
  String get homeNotWorkdayBody;

  /// No description provided for @homePastCommuteBody.
  ///
  /// In th, this message translates to:
  /// **'เลยเวลากลับบ้านปกติมาแล้ว พรุ่งนี้แอปจะเช็กให้ก่อนเลิกงาน'**
  String get homePastCommuteBody;

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

  /// No description provided for @homeSetHomeHint.
  ///
  /// In th, this message translates to:
  /// **'ตั้งบ้านเพื่อให้เตือนตอนกลับ'**
  String get homeSetHomeHint;

  /// No description provided for @homeSetWorkHint.
  ///
  /// In th, this message translates to:
  /// **'ตั้งที่ทำงานเพื่อให้เตือนได้แม่นขึ้น'**
  String get homeSetWorkHint;

  /// No description provided for @homeWfhNotice.
  ///
  /// In th, this message translates to:
  /// **'ทำงานที่บ้าน — แอปจะเตือนเฉพาะทริปอื่น'**
  String get homeWfhNotice;

  /// No description provided for @homeCalendarHint.
  ///
  /// In th, this message translates to:
  /// **'เชื่อม Calendar เพื่อให้แอปเห็นนัด'**
  String get homeCalendarHint;

  /// No description provided for @homeConnect.
  ///
  /// In th, this message translates to:
  /// **'เชื่อมต่อ'**
  String get homeConnect;

  /// No description provided for @homeNoCalendarSoon.
  ///
  /// In th, this message translates to:
  /// **'ไม่มีนัดที่มีสถานที่ใน 24 ชม.'**
  String get homeNoCalendarSoon;

  /// No description provided for @homeAskHintHero.
  ///
  /// In th, this message translates to:
  /// **'ไปไหน กี่โมง?'**
  String get homeAskHintHero;

  /// No description provided for @homeGreetingDemo.
  ///
  /// In th, this message translates to:
  /// **'สวัสดีมิว'**
  String get homeGreetingDemo;

  /// No description provided for @homeGreeting.
  ///
  /// In th, this message translates to:
  /// **'สวัสดี'**
  String get homeGreeting;

  /// No description provided for @homeCurrentPlace.
  ///
  /// In th, this message translates to:
  /// **'ตำแหน่งตอนนี้'**
  String get homeCurrentPlace;

  /// No description provided for @homeCurrentPlaceAlt.
  ///
  /// In th, this message translates to:
  /// **'ตำแหน่งปัจจุบัน'**
  String get homeCurrentPlaceAlt;

  /// No description provided for @homeHereSemantics.
  ///
  /// In th, this message translates to:
  /// **'ตำแหน่งตอนนี้ {name} แตะเพื่อปักหมุดตำแหน่งเอง'**
  String homeHereSemantics(String name);

  /// No description provided for @homeSettings.
  ///
  /// In th, this message translates to:
  /// **'ตั้งค่า'**
  String get homeSettings;

  /// No description provided for @homeRouteTo.
  ///
  /// In th, this message translates to:
  /// **'ทางกลับ{place}'**
  String homeRouteTo(String place);

  /// No description provided for @homePreview.
  ///
  /// In th, this message translates to:
  /// **'พรีวิว {time}'**
  String homePreview(String time);

  /// No description provided for @homeDepart.
  ///
  /// In th, this message translates to:
  /// **'ออก {time}'**
  String homeDepart(String time);

  /// No description provided for @homeArriveCaption.
  ///
  /// In th, this message translates to:
  /// **'ถึง'**
  String get homeArriveCaption;

  /// No description provided for @homeModeEta.
  ///
  /// In th, this message translates to:
  /// **'{mode} · {minutes} นาที'**
  String homeModeEta(String mode, int minutes);

  /// No description provided for @homeNextTrips.
  ///
  /// In th, this message translates to:
  /// **'ทริปถัดไป'**
  String get homeNextTrips;

  /// No description provided for @homeUnresolvedSubtitle.
  ///
  /// In th, this message translates to:
  /// **'“{location}” · แตะเพื่อเลือกสถานที่'**
  String homeUnresolvedSubtitle(String location);

  /// No description provided for @homeUnresolvedStatus.
  ///
  /// In th, this message translates to:
  /// **'ไม่รู้ว่าที่ไหน'**
  String get homeUnresolvedStatus;

  /// No description provided for @homeFutureSubtitle.
  ///
  /// In th, this message translates to:
  /// **'{place} · จะเตือนวันเดินทางว่าออกกี่โมงดี'**
  String homeFutureSubtitle(String place);

  /// No description provided for @homeFutureStatus.
  ///
  /// In th, this message translates to:
  /// **'รอวัน'**
  String get homeFutureStatus;

  /// No description provided for @homeTonightTitle.
  ///
  /// In th, this message translates to:
  /// **'ที่บ้านคืนนี้'**
  String get homeTonightTitle;

  /// No description provided for @homeNoCanalStation.
  ///
  /// In th, this message translates to:
  /// **'ไม่มีสถานีวัดระดับคลองใกล้บ้าน'**
  String get homeNoCanalStation;

  /// No description provided for @homeOutOfArea.
  ///
  /// In th, this message translates to:
  /// **'นอกพื้นที่ที่รองรับ · มีเฉพาะข้อมูลฝน'**
  String get homeOutOfArea;

  /// No description provided for @homeCanalLevel.
  ///
  /// In th, this message translates to:
  /// **'{canal} {level} จาก {bank} ม.'**
  String homeCanalLevel(String canal, String level, String bank);

  /// No description provided for @homeQuickAsk.
  ///
  /// In th, this message translates to:
  /// **'ถามเร็ว'**
  String get homeQuickAsk;

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

  /// No description provided for @homeSetPlaceTooltip.
  ///
  /// In th, this message translates to:
  /// **'ตั้ง{label}'**
  String homeSetPlaceTooltip(String label);

  /// No description provided for @homeDefaultPlaceHome.
  ///
  /// In th, this message translates to:
  /// **'บ้าน'**
  String get homeDefaultPlaceHome;

  /// No description provided for @homeDefaultPlaceWork.
  ///
  /// In th, this message translates to:
  /// **'ที่ทำงาน'**
  String get homeDefaultPlaceWork;

  /// No description provided for @homeDefaultPlaceSiam.
  ///
  /// In th, this message translates to:
  /// **'สยาม'**
  String get homeDefaultPlaceSiam;

  /// No description provided for @homeDefaultPlaceThonglor.
  ///
  /// In th, this message translates to:
  /// **'ทองหล่อ'**
  String get homeDefaultPlaceThonglor;

  /// No description provided for @homeDefaultPlaceImpact.
  ///
  /// In th, this message translates to:
  /// **'อิมแพ็ค'**
  String get homeDefaultPlaceImpact;

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

  /// No description provided for @homeTripGoHome.
  ///
  /// In th, this message translates to:
  /// **'กลับบ้าน'**
  String get homeTripGoHome;

  /// No description provided for @homeFromHereSemantics.
  ///
  /// In th, this message translates to:
  /// **'กลับบ้าน จากตำแหน่งตอนนี้'**
  String get homeFromHereSemantics;

  /// No description provided for @homeFromHereTitle.
  ///
  /// In th, this message translates to:
  /// **'กลับบ้าน · จากตำแหน่งตอนนี้'**
  String get homeFromHereTitle;

  /// No description provided for @homeLeaveAround.
  ///
  /// In th, this message translates to:
  /// **'ออกราว {time}'**
  String homeLeaveAround(String time);

  /// No description provided for @homeCheckRainHome.
  ///
  /// In th, this message translates to:
  /// **'เช็กฝนบนทางกลับบ้าน'**
  String get homeCheckRainHome;

  /// No description provided for @homeLocationOnTap.
  ///
  /// In th, this message translates to:
  /// **'แอปใช้ตำแหน่งตอนกดเท่านั้น เพื่อเป็นจุดเริ่มต้นของทาง'**
  String get homeLocationOnTap;

  /// No description provided for @homeCheckWayHome.
  ///
  /// In th, this message translates to:
  /// **'เช็กทางกลับบ้าน'**
  String get homeCheckWayHome;

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
  /// **'เล่นซ้ำพายุ อังคาร 29 ก.ย. 2026 · ส่งเป็น X-Demo-Clock'**
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
  /// **'ยังไม่รู้ว่า{place}อยู่ไหน'**
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

  /// No description provided for @onboardingDemo.
  ///
  /// In th, this message translates to:
  /// **'ใช้โปรไฟล์เดโม (มิว)'**
  String get onboardingDemo;

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
  /// **'ไป{place}'**
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

  /// No description provided for @floodSetHomeTitle.
  ///
  /// In th, this message translates to:
  /// **'ตั้งบ้านเพื่อดูความเสี่ยงน้ำท่วมหน้า⁠บ้าน'**
  String get floodSetHomeTitle;

  /// No description provided for @floodSetHomeMsg.
  ///
  /// In th, this message translates to:
  /// **'แอปจะดูระดับคลองใกล้บ้าน จุดน้ำท่วมของ กทม. และรายงานจากเพื่อนบ้าน แล้วเตือนแม้ไม่ได้เปิดแอป'**
  String get floodSetHomeMsg;

  /// No description provided for @floodUseLocation.
  ///
  /// In th, this message translates to:
  /// **'ใช้ตำแหน่งตอนนี้'**
  String get floodUseLocation;

  /// No description provided for @floodSearch.
  ///
  /// In th, this message translates to:
  /// **'ค้นหา'**
  String get floodSearch;

  /// No description provided for @floodReadError.
  ///
  /// In th, this message translates to:
  /// **'อ่านระดับน้ำไม่ได้'**
  String get floodReadError;

  /// No description provided for @floodReadErrorMsg.
  ///
  /// In th, this message translates to:
  /// **'เชื่อมต่อ ThaiWater ผ่านเซิร์ฟเวอร์ไม่ได้ ถ้าน้ำขึ้นเร็วให้ยกของขึ้นที่สูงไว้ก่อน'**
  String get floodReadErrorMsg;

  /// No description provided for @floodRetry.
  ///
  /// In th, this message translates to:
  /// **'ลองอีกครั้ง'**
  String get floodRetry;

  /// No description provided for @floodModeTitle.
  ///
  /// In th, this message translates to:
  /// **'โหมดน้ำท่วม'**
  String get floodModeTitle;

  /// No description provided for @floodHome.
  ///
  /// In th, this message translates to:
  /// **'บ้าน'**
  String get floodHome;

  /// No description provided for @floodSameQuestion.
  ///
  /// In th, this message translates to:
  /// **'คำถามเดิม ระดับใหม่'**
  String get floodSameQuestion;

  /// No description provided for @floodNoHome.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่ได้ตั้งบ้าน'**
  String get floodNoHome;

  /// No description provided for @floodDoNow.
  ///
  /// In th, this message translates to:
  /// **'ทำตอนนี้ เรียงตามลำดับ'**
  String get floodDoNow;

  /// No description provided for @floodPrepare.
  ///
  /// In th, this message translates to:
  /// **'เตรียมไว้ก่อน'**
  String get floodPrepare;

  /// No description provided for @floodSpotsTitle.
  ///
  /// In th, this message translates to:
  /// **'จุดเสี่ยงน้ำท่วม กทม. ใกล้บ้าน'**
  String get floodSpotsTitle;

  /// No description provided for @floodNoSpots.
  ///
  /// In th, this message translates to:
  /// **'ไม่มีจุดเสี่ยงใน 2 กม.'**
  String get floodNoSpots;

  /// No description provided for @floodNoSpotsMsg.
  ///
  /// In th, this message translates to:
  /// **'บ้านไม่อยู่ใกล้จุดน้ำท่วมซ้ำซากที่ กทม. ประกาศไว้'**
  String get floodNoSpotsMsg;

  /// No description provided for @floodFromHome.
  ///
  /// In th, this message translates to:
  /// **'ห่างบ้าน {meters} ม.'**
  String floodFromHome(int meters);

  /// No description provided for @floodNeighborsTitle.
  ///
  /// In th, this message translates to:
  /// **'เพื่อนบ้านในซอย'**
  String get floodNeighborsTitle;

  /// No description provided for @floodNeighborsDanger.
  ///
  /// In th, this message translates to:
  /// **'11 คนได้รับเตือนเดียวกัน'**
  String get floodNeighborsDanger;

  /// No description provided for @floodNeighborsWatch.
  ///
  /// In th, this message translates to:
  /// **'3 คนรายงานน้ำขังใน 20 นาที'**
  String get floodNeighborsWatch;

  /// No description provided for @floodNeighborsNote.
  ///
  /// In th, this message translates to:
  /// **'คนที่ไม่มีสมาร์ทโฟนได้รับข้อความทาง LINE / SMS หรือโทรอ่านให้ฟัง'**
  String get floodNeighborsNote;

  /// No description provided for @floodStepSemantics.
  ///
  /// In th, this message translates to:
  /// **'ขั้นที่ {order} {text}'**
  String floodStepSemantics(int order, String text);

  /// No description provided for @floodNearbyTitle.
  ///
  /// In th, this message translates to:
  /// **'รายงานน้ำท่วมใกล้ฉัน'**
  String get floodNearbyTitle;

  /// No description provided for @floodNearbyButton.
  ///
  /// In th, this message translates to:
  /// **'ดูรายงานน้ำท่วมใกล้ฉัน'**
  String get floodNearbyButton;

  /// No description provided for @floodHereNow.
  ///
  /// In th, this message translates to:
  /// **'ตำแหน่งตอนนี้'**
  String get floodHereNow;

  /// No description provided for @floodAround.
  ///
  /// In th, this message translates to:
  /// **'รอบ {where}'**
  String floodAround(String where);

  /// No description provided for @floodNoReports.
  ///
  /// In th, this message translates to:
  /// **'ไม่มีรายงานใน 500 ม.'**
  String get floodNoReports;

  /// No description provided for @floodNoReportsMsg.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่มีใครรายงานน้ำขังแถวนี้ใน 24 ชั่วโมง'**
  String get floodNoReportsMsg;

  /// No description provided for @floodWaterDepth.
  ///
  /// In th, this message translates to:
  /// **'น้ำ {min}–{max} ซม.'**
  String floodWaterDepth(int min, int max);

  /// No description provided for @floodCarPassable.
  ///
  /// In th, this message translates to:
  /// **'รถยนต์ {status}'**
  String floodCarPassable(String status);

  /// No description provided for @floodOtherSpot.
  ///
  /// In th, this message translates to:
  /// **'ดูจุดอื่น'**
  String get floodOtherSpot;

  /// No description provided for @reportCameraError.
  ///
  /// In th, this message translates to:
  /// **'เปิดกล้องไม่ได้ ลองเลือกจากคลังภาพแทน'**
  String get reportCameraError;

  /// No description provided for @reportGalleryError.
  ///
  /// In th, this message translates to:
  /// **'เปิดคลังภาพไม่ได้ ตรวจสิทธิ์รูปภาพในตั้งค่าเครื่อง'**
  String get reportGalleryError;

  /// No description provided for @reportTitle.
  ///
  /// In th, this message translates to:
  /// **'แจ้งน้ำท่วม'**
  String get reportTitle;

  /// No description provided for @reportSubtitle.
  ///
  /// In th, this message translates to:
  /// **'ถ่ายรูปน้ำบนถนน บอกคนที่กำลังจะผ่าน'**
  String get reportSubtitle;

  /// No description provided for @reportTakePhoto.
  ///
  /// In th, this message translates to:
  /// **'ถ่ายรูป'**
  String get reportTakePhoto;

  /// No description provided for @reportFromGallery.
  ///
  /// In th, this message translates to:
  /// **'จากคลังภาพ'**
  String get reportFromGallery;

  /// No description provided for @reportFailed.
  ///
  /// In th, this message translates to:
  /// **'ส่งรายงานไม่สำเร็จ'**
  String get reportFailed;

  /// No description provided for @reportFailedMsg.
  ///
  /// In th, this message translates to:
  /// **'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ รูปยังอยู่ในเครื่อง ส่งใหม่ได้เลย'**
  String get reportFailedMsg;

  /// No description provided for @reportResend.
  ///
  /// In th, this message translates to:
  /// **'ส่งอีกครั้ง'**
  String get reportResend;

  /// No description provided for @reportAnalyzing.
  ///
  /// In th, this message translates to:
  /// **'Gemini กำลังดูภาพ ประเมินระดับน้ำเทียบกับล้อรถและขอบทาง…'**
  String get reportAnalyzing;

  /// No description provided for @reportAnalyzeHint.
  ///
  /// In th, this message translates to:
  /// **'Gemini จะประเมินระดับน้ำจากภาพ แล้วเตือนคนที่เส้นทางผ่านจุดนี้ในรัศมี 300 ม.'**
  String get reportAnalyzeHint;

  /// No description provided for @reportSeeHome.
  ///
  /// In th, this message translates to:
  /// **'ดูสถานการณ์ที่บ้าน'**
  String get reportSeeHome;

  /// No description provided for @reportLocating.
  ///
  /// In th, this message translates to:
  /// **'กำลังหาตำแหน่ง…'**
  String get reportLocating;

  /// No description provided for @reportUsingGps.
  ///
  /// In th, this message translates to:
  /// **'ใช้ GPS ของเครื่อง'**
  String get reportUsingGps;

  /// No description provided for @reportGpsDetail.
  ///
  /// In th, this message translates to:
  /// **'GPS · {lat}, {lng} · {time}'**
  String reportGpsDetail(String lat, String lng, String time);

  /// No description provided for @reportFallbackDetail.
  ///
  /// In th, this message translates to:
  /// **'{note} · ใช้ตำแหน่งสำรองของเดโม'**
  String reportFallbackDetail(String note);

  /// No description provided for @reportRetryGps.
  ///
  /// In th, this message translates to:
  /// **'ลองหา GPS'**
  String get reportRetryGps;

  /// No description provided for @reportDepthSemantics.
  ///
  /// In th, this message translates to:
  /// **'น้ำสูงประมาณ {min} ถึง {max} เซนติเมตร'**
  String reportDepthSemantics(int min, int max);

  /// No description provided for @reportSeenByGemini.
  ///
  /// In th, this message translates to:
  /// **'Gemini ดูภาพแล้ว'**
  String get reportSeenByGemini;

  /// No description provided for @reportDepth.
  ///
  /// In th, this message translates to:
  /// **'น้ำสูง {min}–{max} ซม.'**
  String reportDepth(int min, int max);

  /// No description provided for @reportNotified.
  ///
  /// In th, this message translates to:
  /// **'แจ้งคน {count} คนที่กำลังจะผ่านจุดนี้'**
  String reportNotified(int count);

  /// No description provided for @reportCorroborated.
  ///
  /// In th, this message translates to:
  /// **'ยืนยันกับอีก {count} รายงานในรัศมี 300 ม.'**
  String reportCorroborated(int count);

  /// No description provided for @reportDemoNumbers.
  ///
  /// In th, this message translates to:
  /// **'จำนวนคนที่แจ้งเตือนเป็นตัวเลขจำลองสำหรับเดโม'**
  String get reportDemoNumbers;

  /// No description provided for @reportFrameHint.
  ///
  /// In th, this message translates to:
  /// **'ถ่ายให้เห็นล้อรถหรือขอบทาง'**
  String get reportFrameHint;

  /// No description provided for @reportNoPhoto.
  ///
  /// In th, this message translates to:
  /// **'ไม่มีภาพ · ผลตัวอย่าง'**
  String get reportNoPhoto;

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
  /// **'การเดินทาง'**
  String get settingsTravelGroup;

  /// No description provided for @settingsRemindAhead.
  ///
  /// In th, this message translates to:
  /// **'เตือนล่วงหน้า'**
  String get settingsRemindAhead;

  /// No description provided for @settingsRemindAheadHint.
  ///
  /// In th, this message translates to:
  /// **'2 ชั่วโมงก่อนเวลาที่ควรออก'**
  String get settingsRemindAheadHint;

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

  /// No description provided for @settingsRoutine.
  ///
  /// In th, this message translates to:
  /// **'เรียนรู้กิจวัตร'**
  String get settingsRoutine;

  /// No description provided for @settingsRoutineHint.
  ///
  /// In th, this message translates to:
  /// **'รู้เองว่ากลับบ้านราวหกโมงทุกวัน · เร็ว ๆ นี้'**
  String get settingsRoutineHint;

  /// No description provided for @settingsCommunityGroup.
  ///
  /// In th, this message translates to:
  /// **'ชุมชนและน้ำท่วม'**
  String get settingsCommunityGroup;

  /// No description provided for @settingsShareReports.
  ///
  /// In th, this message translates to:
  /// **'แชร์รายงานน้ำท่วมของฉัน'**
  String get settingsShareReports;

  /// No description provided for @settingsShareReportsHint.
  ///
  /// In th, this message translates to:
  /// **'ไม่ระบุตัว เฉพาะตำแหน่งและระดับน้ำ'**
  String get settingsShareReportsHint;

  /// No description provided for @settingsHomeAlerts.
  ///
  /// In th, this message translates to:
  /// **'เตือนน้ำท่วมที่บ้าน'**
  String get settingsHomeAlerts;

  /// No description provided for @settingsHomeAlertsHint.
  ///
  /// In th, this message translates to:
  /// **'แม้ไม่ได้เปิดแอป'**
  String get settingsHomeAlertsHint;

  /// No description provided for @settingsSmsBackup.
  ///
  /// In th, this message translates to:
  /// **'สำรองทาง SMS'**
  String get settingsSmsBackup;

  /// No description provided for @settingsSmsBackupHint.
  ///
  /// In th, this message translates to:
  /// **'เมื่อไม่มีอินเทอร์เน็ต'**
  String get settingsSmsBackupHint;

  /// No description provided for @settingsProfileGroup.
  ///
  /// In th, this message translates to:
  /// **'โปรไฟล์'**
  String get settingsProfileGroup;

  /// No description provided for @settingsExitDemo.
  ///
  /// In th, this message translates to:
  /// **'ออกจากโปรไฟล์เดโม'**
  String get settingsExitDemo;

  /// No description provided for @settingsExitDemoHint.
  ///
  /// In th, this message translates to:
  /// **'ลบสถานที่ของมิวและกลับไปหน้าเริ่มต้น'**
  String get settingsExitDemoHint;

  /// No description provided for @settingsUseDemo.
  ///
  /// In th, this message translates to:
  /// **'ใช้โปรไฟล์เดโม (มิว)'**
  String get settingsUseDemo;

  /// No description provided for @settingsUseDemoHint.
  ///
  /// In th, this message translates to:
  /// **'สถานที่และนัดจำลองของมิว สำหรับสาธิต'**
  String get settingsUseDemoHint;

  /// No description provided for @settingsTeamGroup.
  ///
  /// In th, this message translates to:
  /// **'สำหรับทีม'**
  String get settingsTeamGroup;

  /// No description provided for @settingsDesignSystem.
  ///
  /// In th, this message translates to:
  /// **'ระบบดีไซน์'**
  String get settingsDesignSystem;

  /// No description provided for @settingsDesignSystemHint.
  ///
  /// In th, this message translates to:
  /// **'สี ตัวอักษร ระยะ และคอมโพเนนต์ทุกสถานะท้องฟ้า'**
  String get settingsDesignSystemHint;

  /// No description provided for @settingsDemoClock.
  ///
  /// In th, this message translates to:
  /// **'เวลาสาธิต'**
  String get settingsDemoClock;

  /// No description provided for @settingsRealTime.
  ///
  /// In th, this message translates to:
  /// **'เวลาจริง'**
  String get settingsRealTime;

  /// No description provided for @settingsDemoNote.
  ///
  /// In th, this message translates to:
  /// **'ชื่อ “มิว” ตัวเลขผู้ใช้ และรายงานชุมชนในแอปนี้เป็นข้อมูลจำลองสำหรับเดโม'**
  String get settingsDemoNote;

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

  /// No description provided for @reportSampleResult.
  ///
  /// In th, this message translates to:
  /// **'ผลประเมินตัวอย่าง ยังไม่ได้วิเคราะห์ภาพด้วย AI'**
  String get reportSampleResult;

  /// No description provided for @reportRejectedTitle.
  ///
  /// In th, this message translates to:
  /// **'ใช้ภาพนี้ไม่ได้'**
  String get reportRejectedTitle;
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

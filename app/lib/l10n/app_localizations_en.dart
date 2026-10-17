// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Fon Tok Mai';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageThai => 'ไทย';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get designBack => 'Back';

  @override
  String get designAskTooltip => 'Ask';

  @override
  String get designAskHint => 'Where and when? e.g. “Siam at 5 pm”';

  @override
  String get designDismissBanner => 'Dismiss notification';

  @override
  String get designRetry => 'Try again';

  @override
  String get designLoadingAnswer => 'Loading the answer';

  @override
  String get boardNoteTransitCrowded =>
      'Trains run in the rain, but platforms get crowded. Leave extra time.';

  @override
  String get boardNoteTransitWalk => 'Rain on the walk to the station';

  @override
  String get boardNoteDry => 'No rain on the way';

  @override
  String get boardNoteCarHeavy =>
      'Heavy rain, slow drainage, traffic building up';

  @override
  String get boardNoteCarDrizzle => 'Rain on the way. Drive slower.';

  @override
  String get boardNoteBeatRain => 'You get there before the rain';

  @override
  String get boardNoteMotoHeavy => 'Heavy rain on the way. Skip the motorbike.';

  @override
  String get boardNoteMotoTight =>
      'Just in time. Any later and you get rained on.';

  @override
  String boardHeadlineLeave(String time) {
    return 'Leave at $time';
  }

  @override
  String get boardHeadlineWait => 'Hold off for now';

  @override
  String get boardHeadlineSwitchTransit => 'Take the BTS instead';

  @override
  String homeGpsInaccurate(String distance) {
    return 'Location may be off by $distance';
  }

  @override
  String get homePinMyself => 'Pin it myself';

  @override
  String get homeCurrentPlace => 'Current location';

  @override
  String get homeSettings => 'Settings';

  @override
  String homeModeEta(String mode, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min',
      one: '1 min',
    );
    return '$mode · $_temp0';
  }

  @override
  String get homeQuestionHomeNow => 'Go home now';

  @override
  String homeQuestionToNow(String place) {
    return 'Go to $place now';
  }

  @override
  String homeUsingPinned(String name) {
    return 'Using “$name” as your current location';
  }

  @override
  String get homeBackToGps => 'Use GPS again';

  @override
  String get askSuggestion1 => 'What if I wait until 8 pm?';

  @override
  String get askSuggestion2 => 'Should I take the BTS instead?';

  @override
  String get askOpeningPlain =>
      'Ask me anything about rain and getting around.';

  @override
  String askOpeningWith(String headline) {
    return 'Right now I suggest “$headline”. Anything else you’d like to ask?';
  }

  @override
  String get askFailed =>
      'Couldn’t answer because the server isn’t reachable. Check your connection and ask again.';

  @override
  String get askTitle => 'Ask more';

  @override
  String get askInputHint =>
      'Type a question, e.g. “What about the motorbike?”';

  @override
  String get askRetry => 'Ask again';

  @override
  String get askDisclaimer =>
      'AI analysis and forecasts might not be 100% accurate. Always check actual conditions before traveling.';

  @override
  String partsQuestion(String question) {
    return 'Question: “$question”';
  }

  @override
  String partsArriveBy(String time) {
    return 'Arrive by $time';
  }

  @override
  String get partsChecking => 'Checking this time…';

  @override
  String get partsPreviewEstimate =>
      'Estimated from rain along the route. Release to confirm.';

  @override
  String partsTakesMin(int minutes) {
    return 'Takes $minutes min';
  }

  @override
  String get partsSegLeave => 'Leave';

  @override
  String get partsSegArrive => 'Arrive';

  @override
  String get partsSegMode => 'Mode';

  @override
  String get partsSegConfidence => 'Sure';

  @override
  String get partsNow => 'Now';

  @override
  String get partsDragHint => 'Drag the pin to try a departure time';

  @override
  String get partsLeaveNow => 'Leave now';

  @override
  String get partsOutOfArea => 'Outside coverage area';

  @override
  String get partsRainToday => 'Rain today';

  @override
  String partsMm(int mm) {
    return '$mm mm';
  }

  @override
  String get partsFloodSpots => 'Flood spots, 2 km';

  @override
  String get partsReports => 'Reports, 500 m';

  @override
  String get partsCanalLevel => 'Canal level';

  @override
  String partsCanalLevelValue(String level, String bank) {
    return '$level/$bank m';
  }

  @override
  String get partsCanalRise => 'Rise in 2 h';

  @override
  String partsCm(int cm) {
    return '$cm cm';
  }

  @override
  String get partsToBank => 'To the bank';

  @override
  String get partsAtBank => 'At the bank';

  @override
  String partsCmLeft(int cm) {
    return '$cm cm to go';
  }

  @override
  String get partsNoCanalStation => 'No canal gauge near home';

  @override
  String get partsOutsideBangkok =>
      'Home is outside Bangkok, so canal levels and flood spots are not covered yet. The app can only warn about rain.';

  @override
  String partsDemoClockSemantic(String time) {
    return 'Demo time $time, tap to change';
  }

  @override
  String get partsRealTime => 'Live time';

  @override
  String get partsDemoTime => 'Demo time';

  @override
  String get partsDemoReplay =>
      'Replays the storm day on today\'s date · sent as X-Demo-Clock';

  @override
  String get partsRealTimeNoHeader => 'Live time (no header sent)';

  @override
  String get partsPreset1610 => 'Before leaving work, rain not here yet';

  @override
  String get partsPreset1852 => 'Storm over Ratchada, water waiting to drain';

  @override
  String get partsPreset2140 => 'Flood mode at home';

  @override
  String get partsPresetDevice => 'Use the device clock';

  @override
  String partsKindLabel(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'home': 'home',
      'work': 'work',
      'other': 'place',
    });
    return '$_temp0';
  }

  @override
  String get partsNeedsFirst => 'Need this first';

  @override
  String partsNeedsWhere(String place) {
    return 'Where is your $place?';
  }

  @override
  String get partsNeedsSaveOnce =>
      'Save it once and the app picks this question right back up.';

  @override
  String get partsUseMyLocation => 'Use my location';

  @override
  String get partsSearch => 'Search';

  @override
  String get partsWhichPlace => 'Which place?';

  @override
  String partsNotFound(String query) {
    return 'No match for “$query”. Try another name.';
  }

  @override
  String partsSimilar(String query) {
    return 'Several places look like “$query”';
  }

  @override
  String partsSearchFor(String query) {
    return 'Search “$query”';
  }

  @override
  String get partsNoneOfThese => 'None of these · search myself';

  @override
  String marksSourceSemantic(String text) {
    return 'Source: $text';
  }

  @override
  String get marksSample => 'Sample data';

  @override
  String get marksSampleSemantic => 'Sample data, cannot reach the server';

  @override
  String get marksDemo => 'Demo';

  @override
  String get marksDemoSemantic => 'Demo profile, simulated data';

  @override
  String get marksConfidence => 'Sure';

  @override
  String marksConfidenceSemantic(String percent) {
    return 'Confidence $percent';
  }

  @override
  String get marksGeneratedByAi => 'Analyzed by AI';

  @override
  String get marksGeneratedByFallback =>
      'Using backup calculation · AI did not respond this time';

  @override
  String rainBandLeave(String time) {
    return 'Leave $time';
  }

  @override
  String get rainBandSlider => 'Departure time. Drag to try another.';

  @override
  String get galleryTitle => 'Design system';

  @override
  String get gallerySubtitle => 'Fon Tok Mai · tokens and components';

  @override
  String get galleryClear => 'Clear';

  @override
  String get galleryStorm => 'Storm';

  @override
  String get galleryFlood => 'Flood';

  @override
  String get gallerySkySwatches => 'Sky fields';

  @override
  String get galleryPassPerSky => 'Pass in each sky';

  @override
  String get galleryColors => 'Colors';

  @override
  String get galleryType => 'Type · Chakra Petch';

  @override
  String get gallerySpace => 'Spacing · radius · shadow';

  @override
  String get galleryMotion => 'Motion';

  @override
  String get galleryRainBand => 'RainBand · draggable';

  @override
  String get galleryRerank => 'Re-rank';

  @override
  String get galleryPlaces => 'Places · Notice · ConnectRow';

  @override
  String get galleryNoticeWork => 'Set your workplace for more accurate alerts';

  @override
  String get galleryNoticeOff =>
      'Notifications are off, so the app cannot warn you before you leave';

  @override
  String get galleryOpenSettings => 'Open settings';

  @override
  String get galleryNoticeCalendar =>
      'Connect Calendar so the app can see your plans';

  @override
  String get galleryCalendarDetail => 'Only events with a location';

  @override
  String get galleryCalendarAccount => 'miw.demo@gmail.com · demo account';

  @override
  String get galleryRiskChips => 'RiskChip · ConfidenceMeter · SourceLabel';

  @override
  String get galleryNotifTitle => 'Leave before 16:45 · dinner with family';

  @override
  String get galleryNotifBody =>
      'Rain reaches Rama 4 around 17:30. Leave now and you get home before it.';

  @override
  String get galleryStateLoading => 'State: loading';

  @override
  String get galleryStateError => 'State: error';

  @override
  String get galleryStateEmpty => 'State: empty';

  @override
  String get galleryErrorTitle => 'Could not load trips';

  @override
  String get galleryErrorMessage =>
      'Cannot reach the server. Check your connection and try again.';

  @override
  String get galleryEmptyTitle => 'No trips today';

  @override
  String get galleryEmptyMessage => 'Just ask, for example “Siam at 5 pm”';

  @override
  String get galleryConnectCalendar => 'Connect Calendar';

  @override
  String get galleryRowTransitSub =>
      'Sala Daeng → Lat Phrao, no umbrella needed';

  @override
  String get galleryRowCarSub => 'Arrive before the rain, on time for 18:30';

  @override
  String get galleryRowMotoSub => 'Just in time; any later and you get wet';

  @override
  String galleryRowTitle(String mode, int minutes) {
    return '$mode · $minutes min';
  }

  @override
  String get galleryHeadClear => 'Leave before 16:45';

  @override
  String get galleryHeadStorm => 'Do not leave yet';

  @override
  String get galleryHeadFlood => 'Water reaches your door in 40 min';

  @override
  String get galleryColorPass => 'Pass';

  @override
  String get galleryColorRain => 'Rain (none → heavy)';

  @override
  String get galleryColorRisk => 'Risk';

  @override
  String get galleryTypeVerdict => 'verdict';

  @override
  String get galleryTypeSampleLong =>
      'Rain reaches Rama 4 around 17:30, 25 cm of standing water';

  @override
  String get galleryTypeTabular =>
      'Tabular figures (Petch Tabular) vs. regular figures';

  @override
  String get galleryMotionTap => 'Button and selection states';

  @override
  String get galleryMotionFlap => 'Verdict flips its letters';

  @override
  String get galleryMotionRerank => 'Board re-ranks';

  @override
  String get galleryMotionEnter => 'Notification slides down';

  @override
  String get galleryMotionSky => 'Sky color changes state';

  @override
  String get galleryMotionCurves =>
      'Curves: standard (0.2, 0, 0, 1) · emphasized decelerate (0.05, 0.7, 0.1, 1)';

  @override
  String get galleryMotionReduced => 'Reduce motion is on: every duration is 0';

  @override
  String get galleryFlipDemo => 'OK to leave at 16:45';

  @override
  String get galleryFlip => 'Flip';

  @override
  String galleryModeStatus(int minutes, String status) {
    return '$minutes min · $status';
  }

  @override
  String get placeKindHome => 'Home';

  @override
  String get placeKindWork => 'Work';

  @override
  String get placeKindOther => 'Place';

  @override
  String get placeDemoSiam => 'Siam';

  @override
  String get placeDemoThonglor => 'Thong Lo';

  @override
  String get placeDemoImpact => 'IMPACT';

  @override
  String get locationGpsOff => 'GPS is off';

  @override
  String get locationDenied => 'Location access not allowed';

  @override
  String get locationUnavailable => 'Couldn\'t find your location';

  @override
  String get locationCurrent => 'Current location';

  @override
  String get locationFallbackSpot => 'Ratchadaphisek Rd at Soi Lat Phrao 32';

  @override
  String placesPinLabel(String lat, String lng) {
    return 'Location pin $lat, $lng';
  }

  @override
  String get placesDismiss => 'Dismiss';

  @override
  String get placesNotConnected => 'Not connected';

  @override
  String placesNotConnectedDetail(String detail) {
    return 'Not connected · $detail';
  }

  @override
  String get placesConnecting => 'Connecting…';

  @override
  String get placesConnected => 'Connected';

  @override
  String get placesConnectFailed => 'Couldn\'t connect. Try again';

  @override
  String get placesComingSoon => 'Coming soon';

  @override
  String get placesConnect => 'Connect';

  @override
  String get placesDisconnect => 'Disconnect';

  @override
  String get placesRetry => 'Try again';

  @override
  String get placesSearching => 'Searching';

  @override
  String get onboardingHeadline => 'Get a heads-up before you head home';

  @override
  String get onboardingIntro =>
      'Tell us where home and work are. Every evening we\'ll check rain and flooding on your way back, and the flood risk near your home.';

  @override
  String get onboardingSkipNote => 'You can skip this and just ask anytime';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get onboardingSkip => 'Skip for now';

  @override
  String get onboardingSet => 'Set';

  @override
  String get onboardingHomeHint =>
      'Used for warnings before you head home and flooding near your home';

  @override
  String get onboardingWorkHint =>
      'Optional · makes end-of-work warnings more accurate';

  @override
  String onboardingWorkSummary(String name, String days, String time) {
    return '$name · $days, leaves $time';
  }

  @override
  String get onboardingUseHere => 'Use my location';

  @override
  String get onboardingSearch => 'Search';

  @override
  String get onboardingEdit => 'Edit';

  @override
  String pickerDeleted(String label) {
    return 'Deleted “$label”';
  }

  @override
  String get pickerUndo => 'Undo';

  @override
  String get pickerTitlePoint => 'Choose a spot';

  @override
  String pickerTitleMove(String label) {
    return 'Move $label';
  }

  @override
  String get pickerTitleHome => 'Set home';

  @override
  String get pickerTitleWork => 'Set work';

  @override
  String get pickerTitleOther => 'Add a place';

  @override
  String get pickerSubtitle => 'Search, or use your current location';

  @override
  String pickerHintTyping(int count) {
    return 'Type at least $count characters: a BTS station, mall, soi or district';
  }

  @override
  String get pickerSearchFailedTitle => 'Search failed';

  @override
  String get pickerSearchFailedMessage =>
      'Can\'t reach the server, and there\'s no offline place list on this device';

  @override
  String pickerNoResultsTitle(String query) {
    return 'No results for “$query”';
  }

  @override
  String get pickerNoResultsMessage => 'Try a BTS station or mall name';

  @override
  String get pickerNoResultsMessageOffline =>
      'Try a BTS station or mall name. Right now only the offline list is searchable';

  @override
  String get pickerUseLocation => 'Use my location';

  @override
  String get pickerSearchOnlineAgain => 'Search online again';

  @override
  String get pickerOfflineNotice =>
      'Can\'t search online. Showing offline results';

  @override
  String get pickerOutOfArea => 'Out of area';

  @override
  String get pickerSourceGoogle => 'Results from Google Maps';

  @override
  String get pickerSourceLocal =>
      'BTS/MRT stations, malls and districts in Bangkok';

  @override
  String get pickerSearchHint => 'A place name, e.g. BTS Ari or Central';

  @override
  String get pickerClear => 'Clear';

  @override
  String get pickerNaming => 'Finding the place name…';

  @override
  String get pickerDroppedPin => 'Dropped pin';

  @override
  String get pickerHereNow => 'Current location';

  @override
  String get locateBusy => 'Finding your location…';

  @override
  String get locateBusyHint => 'Using your phone\'s GPS, up to 10 seconds';

  @override
  String get locateSearchInstead => 'Search instead';

  @override
  String get locateIdleHint => 'Uses GPS, and you confirm before saving';

  @override
  String get locateAskTitle => 'Allow location this time';

  @override
  String get locateAskMessage =>
      'We only use your location to work out where you are. We don\'t keep a travel history.';

  @override
  String get locateAllow => 'Allow location';

  @override
  String get locateDeniedTitle => 'Location permission needed';

  @override
  String get locateDeniedForeverMessage =>
      'Turn on location for Fon Tok Mai in your phone\'s settings, or search for a place by name.';

  @override
  String get locateDeniedMessage =>
      'You can allow it in the app\'s settings, or search for a place by name.';

  @override
  String get locateOpenSettings => 'Open settings';

  @override
  String get locateOffTitle => 'Location is off';

  @override
  String get locateOffMessage =>
      'Turn on location services first, or search for a place by name.';

  @override
  String get locateOpenLocationSettings => 'Open location settings';

  @override
  String get locateTimeoutTitle => 'Location timed out';

  @override
  String get locateErrorTitle => 'Couldn\'t find your location';

  @override
  String get locateWeakMessage =>
      'The GPS signal is weak. Try again near a window, or search for a place by name.';

  @override
  String sheetEdit(String label) {
    return 'Edit $label';
  }

  @override
  String sheetConfirm(String label) {
    return 'Confirm $label';
  }

  @override
  String get sheetSourceGps => 'Location from GPS';

  @override
  String get sheetSourceSaved => 'Saved on this device';

  @override
  String get sheetSourceLocal => 'Offline data';

  @override
  String get sheetOutOfArea =>
      'Outside the area we cover. Rain warnings still work, but there\'s no flood spot or canal data.';

  @override
  String sheetLowAccuracy(String distance) {
    return 'Your location may be off by $distance';
  }

  @override
  String get sheetWorkFromHome =>
      'Working from home — we\'ll only warn about other trips';

  @override
  String sheetDuplicate(String label) {
    return 'Close to your saved ‘$label’';
  }

  @override
  String get sheetNameLabel => 'Name';

  @override
  String get sheetIcon => 'Icon';

  @override
  String get sheetWorkDays => 'Work days';

  @override
  String get sheetLeaveTime => 'Usual time you leave work';

  @override
  String get sheetLeaveHint => 'We\'ll check your way home before this time';

  @override
  String get sheetUpdateExisting => 'Update the existing one';

  @override
  String get sheetSaveSeparate => 'Save as a separate place';

  @override
  String get sheetSave => 'Save';

  @override
  String get sheetMove => 'Move';

  @override
  String sheetDelete(String label) {
    return 'Delete $label';
  }

  @override
  String sheetTooMany(int max) {
    return 'You can save up to $max places. Delete one to add another.';
  }

  @override
  String get onboardingAppName => 'Fon Tok Mai';

  @override
  String get pickerPinnedSpot => 'Pinned location';

  @override
  String pickerNearPlace(String name) {
    return 'Near $name';
  }

  @override
  String pickerAboutAway(String address, int meters) {
    return '$address · about $meters m away';
  }

  @override
  String get settingsGoogleTitle => 'Connect Google';

  @override
  String get settingsGoogleSubtitle => 'Calendar and Gmail, one sign-in';

  @override
  String get settingsGoogleUseTitle => 'What the app reads';

  @override
  String get settingsGoogleCalendarUse =>
      'Calendar: events with a time and place, to tell you when to leave.';

  @override
  String get settingsGoogleGmailUse =>
      'Gmail: ticket and booking confirmations only.';

  @override
  String get settingsGooglePrivacy =>
      'Read-only. Events are kept on our server while you use the app.';

  @override
  String get settingsGoogleSignIn => 'Sign in with Google';

  @override
  String get settingsGoogleWaiting => 'Waiting for Google…';

  @override
  String get settingsGoogleWaitingHint =>
      'Finish signing in on Google, then come back here.';

  @override
  String get settingsGoogleFailed =>
      'Google didn\'t confirm the sign-in. Try again.';

  @override
  String settingsGoogleConnected(String email) {
    return 'Connected as $email';
  }

  @override
  String get settingsGoogleCancel => 'Cancel';

  @override
  String get modeCar => 'Car';

  @override
  String get modeTransit => 'BTS / MRT';

  @override
  String get modeMoto => 'Motorbike';

  @override
  String get modeCarShort => 'Car';

  @override
  String get modeTransitShort => 'Transit';

  @override
  String get modeMotoShort => 'Bike';

  @override
  String get riskLow => 'Low risk';

  @override
  String get riskMedium => 'Medium risk';

  @override
  String get riskHigh => 'High risk';

  @override
  String get boardLeaveOk => 'Go';

  @override
  String get boardLeaveWithBuffer => 'Leave early';

  @override
  String get boardWait => 'Wait';

  @override
  String get boardSwitchMode => 'Switch mode';

  @override
  String get boardDontGo => 'Skip it';

  @override
  String get homeLevelNormal => 'Normal';

  @override
  String get homeLevelWatch => 'Watch';

  @override
  String get homeLevelDanger => 'Danger';

  @override
  String get passableYes => 'Passable';

  @override
  String get passableSlow => 'Go slowly';

  @override
  String get passableNo => 'Avoid';

  @override
  String approxMeters(int meters) {
    return '~$meters m';
  }

  @override
  String approxKm(String km) {
    return '~$km km';
  }

  @override
  String weekdayInitial(String day) {
    String _temp0 = intl.Intl.selectLogic(day, {
      '1': 'M',
      '2': 'T',
      '3': 'W',
      '4': 'Th',
      '5': 'F',
      '6': 'Sa',
      '7': 'Su',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String weekdayName(String day) {
    String _temp0 = intl.Intl.selectLogic(day, {
      '1': 'Mon',
      '2': 'Tue',
      '3': 'Wed',
      '4': 'Thu',
      '5': 'Fri',
      '6': 'Sat',
      '7': 'Sun',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String monthShort(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': 'Jan',
      '2': 'Feb',
      '3': 'Mar',
      '4': 'Apr',
      '5': 'May',
      '6': 'Jun',
      '7': 'Jul',
      '8': 'Aug',
      '9': 'Sep',
      '10': 'Oct',
      '11': 'Nov',
      '12': 'Dec',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get workDaysEveryday => 'Every day';

  @override
  String get workDaysWeekdays => 'Mon–Fri';

  @override
  String get navSummary => 'Summary';

  @override
  String get navEvents => 'Events';

  @override
  String get navAsk => 'Ask about a trip';

  @override
  String get summaryTitle => 'Summary';

  @override
  String get summaryNextEvent => 'Next event';

  @override
  String summaryIn(String duration) {
    return 'in $duration';
  }

  @override
  String get summaryStarted => 'Started';

  @override
  String durationHm(String h, String m) {
    return '$h h $m min';
  }

  @override
  String durationH(String h) {
    return '$h h';
  }

  @override
  String durationM(String m) {
    return '$m min';
  }

  @override
  String durationD(String d) {
    return '$d days';
  }

  @override
  String get summaryLeaveBefore => 'Leave before';

  @override
  String get summaryLeaveAt => 'Leave at';

  @override
  String get summaryLeaveNow => 'Leave now';

  @override
  String summaryOverdue(String time) {
    return 'You should have left at $time';
  }

  @override
  String get summaryGoNow => 'Go now';

  @override
  String get summaryAvoid => 'Avoid this trip';

  @override
  String get summaryBy => 'Go by';

  @override
  String get summaryArrive => 'Arrive about';

  @override
  String get summaryRain => 'Rain on the way';

  @override
  String get summaryRainNone => 'no rain';

  @override
  String get summaryRainLight => 'light rain';

  @override
  String get summaryRainModerate => 'moderate rain';

  @override
  String get summaryRainHeavy => 'heavy rain';

  @override
  String get summaryLater => 'Coming up';

  @override
  String get summarySeeAll => 'See all';

  @override
  String get summaryDecideError => 'Couldn\'t work out when to leave';

  @override
  String get summaryRetry => 'Try again';

  @override
  String get summarySetPlace => 'Set place';

  @override
  String get summaryUnresolved =>
      'We don\'t know where this event is yet. Set the place to get a leave time.';

  @override
  String get summaryNoEventsTitle => 'No upcoming events';

  @override
  String get summaryNoEventsBody =>
      'New Google Calendar events show up here. Meanwhile, you can ask about any trip.';

  @override
  String get summaryAskInstead => 'Ask about a trip';

  @override
  String get summaryConnectTitle => 'Connect your calendar';

  @override
  String get summaryConnectBody =>
      'We\'ll look at your next event and tell you when to leave and how to go without getting soaked.';

  @override
  String get summaryConnectCta => 'Connect Google Calendar';

  @override
  String get summaryLoadErrorTitle => 'Couldn\'t load events';

  @override
  String get summaryLoadErrorBody => 'Check your connection and try again.';

  @override
  String summaryHeroSemantics(String title, String time, String leave) {
    return 'Next event $title at $time. $leave. Tap for details.';
  }

  @override
  String get summaryFloodTitle => 'Flooding near home';

  @override
  String get summaryFloodWhatToDo => 'What to do';

  @override
  String get eventsTitle => 'Events';

  @override
  String eventsSource(String account) {
    return 'From Google Calendar · $account';
  }

  @override
  String eventsToday(String date) {
    return 'Today · $date';
  }

  @override
  String eventsTomorrow(String date) {
    return 'Tomorrow · $date';
  }

  @override
  String get eventsNoTime => 'No time set';

  @override
  String eventsLeaveAt(String time, String mode) {
    return 'Leave $time · $mode';
  }

  @override
  String get eventsAvoid => 'Avoid this trip';

  @override
  String get eventsRefresh => 'Refresh';

  @override
  String eventsCount(String count) {
    return '$count events';
  }

  @override
  String get askSheetTitle => 'Where to?';

  @override
  String get askTomorrowMorning => 'Rain tomorrow morning?';

  @override
  String summaryLate(String duration) {
    return 'Arrives $duration after it starts';
  }

  @override
  String get wxRainNow => 'Raining now';

  @override
  String wxRainStops(String time) {
    return 'Raining, easing around $time';
  }

  @override
  String wxRainFrom(String time) {
    return 'Rain from about $time';
  }

  @override
  String wxMaybeRainFrom(String time) {
    return 'Chance of rain from about $time';
  }

  @override
  String get wxMaybeRainNow => 'Chance of rain this hour, then dry';

  @override
  String get wxDryAhead => 'No rain for 12 hours';

  @override
  String get wxSunStrong => 'Strong sun';

  @override
  String get wxHot => 'Very hot';

  @override
  String get wxFeels => 'Feels like';

  @override
  String get wxUv => 'UV';

  @override
  String get wxRainChance => 'Rain chance';

  @override
  String get wxUvLow => 'low';

  @override
  String get wxUvModerate => 'moderate';

  @override
  String get wxUvHigh => 'high';

  @override
  String get wxUvVeryHigh => 'very high';

  @override
  String get wxUvExtreme => 'extreme';

  @override
  String get wxNow => 'Now';

  @override
  String get wxHumidity => 'Humidity';

  @override
  String get wxWind => 'Wind';

  @override
  String wxWindKph(String kph) {
    return '$kph km/h';
  }

  @override
  String get wxSunset => 'Sunset';

  @override
  String get carryTitle => 'Take with you today';

  @override
  String get carryNothing => 'Nothing extra needed';

  @override
  String get carryNothingBody => 'Fine weather for the next 12 hours';

  @override
  String get carryRaincoat => 'Raincoat';

  @override
  String get carryUmbrella => 'Umbrella';

  @override
  String get carrySpareRaincoat => 'Raincoat, just in case';

  @override
  String get carrySpareUmbrella => 'Umbrella, just in case';

  @override
  String carryWhyMaybeRain(String pct, String from, String to) {
    return 'Maybe rain, $pct% · $from–$to';
  }

  @override
  String get carrySunUmbrella => 'Sun umbrella';

  @override
  String get carrySunscreen => 'Sunscreen';

  @override
  String get carryWater => 'Water';

  @override
  String get carryShoes => 'Waterproof shoes';

  @override
  String carryWhyRain(String pct, String from, String to) {
    return '$pct% rain · $from–$to';
  }

  @override
  String carryWhyHeavy(String from, String to) {
    return 'Heavy rain, beyond an umbrella · $from–$to';
  }

  @override
  String carryWhyMoto(String from, String to) {
    return 'Riding through rain · $from–$to';
  }

  @override
  String carryWhyUv(String uv, String from, String to) {
    return 'UV $uv · $from–$to';
  }

  @override
  String carryWhyShade(String from, String to) {
    return 'Fierce sun, walk in shade · $from–$to';
  }

  @override
  String carryWhyHeat(String c) {
    return 'Feels like $c°, sip often';
  }

  @override
  String carryWhyShoes(String from, String to) {
    return 'Water on the roads · $from–$to';
  }

  @override
  String get eventsAllDays => 'All days';

  @override
  String get eventsNoneOn => 'No events this day';

  @override
  String get calPrev => 'Previous month';

  @override
  String get calNext => 'Next month';

  @override
  String calMonth(String month, String year) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': 'January',
      '2': 'February',
      '3': 'March',
      '4': 'April',
      '5': 'May',
      '6': 'June',
      '7': 'July',
      '8': 'August',
      '9': 'September',
      '10': 'October',
      '11': 'November',
      '12': 'December',
      'other': '',
    });
    return '$_temp0 $year';
  }

  @override
  String get dayToday => 'Today';

  @override
  String get dayTomorrow => 'Tomorrow';

  @override
  String get eventsCalendar => 'Calendar';

  @override
  String planTitleToday(String count) {
    return '$count more today';
  }

  @override
  String get planTitleOneToday => '1 trip today';

  @override
  String get planTitleTomorrow => 'Tomorrow\'s plan';

  @override
  String get planTitleNextTripTomorrow => 'Next trip tomorrow';

  @override
  String get planTitleUpcoming => 'Upcoming trip';

  @override
  String get planTitleFree => 'Nothing else today';

  @override
  String get planToday => 'Later today';

  @override
  String get planTomorrow => 'Tomorrow';

  @override
  String get planBring => 'Bring';

  @override
  String get planWeatherNow => 'Weather now';

  @override
  String planRainAt(String pct) {
    return '$pct% rain';
  }

  @override
  String get leaveIn => 'Leave in';

  @override
  String get leaveDue => 'Time to go';

  @override
  String get unitMin => 'min';

  @override
  String get unitHour => 'h';

  @override
  String get alertsTitle => 'Before you go';

  @override
  String alertShort(String to) {
    return 'You can\'t make $to in time';
  }

  @override
  String alertShortBody(String from, String end, String need, String gap) {
    return '$from ends $end; the trip takes about $need but you only have $gap';
  }

  @override
  String alertOverlap(String from, String to) {
    return '$from and $to overlap';
  }

  @override
  String alertTight(String to) {
    return 'Tight hop to $to';
  }

  @override
  String alertTightBody(String need, String gap, String from) {
    return 'About $need on the road with $gap to spare. Leave $from on time';
  }

  @override
  String alertWetLeave(String pct, String to) {
    return '$pct% rain as you leave for $to';
  }

  @override
  String alertWetLeaveBody(String time) {
    return 'Around $time. Pick a way that keeps you out of it';
  }

  @override
  String alertWetLeaveMoto(String time) {
    return 'Around $time, riding through rain. Wear a raincoat or switch to the train';
  }

  @override
  String alertWetReturn(String from, String pct) {
    return '$pct% rain on the way back from $from';
  }

  @override
  String alertWetReturnBody(String time) {
    return 'It ends around $time. Take an umbrella for the ride home';
  }

  @override
  String alertWetReturnMoto(String time) {
    return 'It ends around $time. Pack a raincoat for the ride home';
  }

  @override
  String alertNeedsPlace(String title) {
    return '$title has no place yet';
  }

  @override
  String alertNeedsPlaceBody(String when) {
    return '$when · set the place to plan when to leave';
  }

  @override
  String get upNextTitle => 'Up next';

  @override
  String get online => 'Online · no travel';

  @override
  String get allDay => 'All day';

  @override
  String get allDayNoLeave => 'No leave time';

  @override
  String get allDayNote =>
      'All-day events have no start time, so there is no leave time.';

  @override
  String allDayAskRoute(String place) {
    return 'Ask the way to $place';
  }

  @override
  String get stripTitle => 'Today at a glance';

  @override
  String get stripEvent => 'Event';

  @override
  String get stripTravel => 'Travel';

  @override
  String get stripRain => 'Rain';

  @override
  String get verdictCantDecide => 'Can\'t decide yet';

  @override
  String get verdictServerError =>
      'Couldn\'t reach the server. Check your connection and try again.';

  @override
  String get verdictRetry => 'Try again';

  @override
  String get verdictSavePlace => 'Save this place';

  @override
  String verdictSavedSnack(String label) {
    return 'Saved “$label”';
  }

  @override
  String get verdictQuestionTitle => 'Question';

  @override
  String get verdictReadingQuestion => 'Reading your question…';

  @override
  String verdictGoTo(String place) {
    return 'To $place';
  }

  @override
  String get verdictCompareModes => 'Compare ways to travel';

  @override
  String verdictModeStatus(int eta, String status) {
    return '$eta min · $status';
  }

  @override
  String verdictModeStatusWithProb(int eta, String status, int prob) {
    return '$eta min · $status ($prob%)';
  }

  @override
  String get verdictFloodSpotsTitle => 'Flood spots on your route';

  @override
  String get verdictNoFloodSpots => 'No standing water on this route';

  @override
  String get verdictNoFloodSpotsMsg =>
      'This route avoids the city\'s known flood-prone spots.';

  @override
  String verdictExpectedDepth(int cm) {
    return 'Expected depth $cm cm';
  }

  @override
  String get verdictStillDry => 'Still dry';

  @override
  String get verdictTraceTitle => 'How we got here';

  @override
  String get verdictSources => 'Sources';

  @override
  String get verdictSourceGps => 'GPS · current location';

  @override
  String get verdictAskMore => 'Ask a follow-up';

  @override
  String get verdictWhyTitle => 'Why we suggest this';

  @override
  String get verdictRouteAdvice => 'Getting around the flooding';

  @override
  String verdictAvoid(String spot) {
    return 'Avoid $spot';
  }

  @override
  String get verdictHideFactors => 'Hide factors';

  @override
  String verdictShowFactors(int count) {
    return 'See what we weighed ($count)';
  }

  @override
  String get floodDoNow => 'Do this now, in order';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSubtitle => 'Your data stays on this device';

  @override
  String get settingsNotificationsOff =>
      'Notifications are off, so the app can\'t warn you before you leave.';

  @override
  String get settingsOpenSettings => 'Open settings';

  @override
  String get settingsMyPlaces => 'My places';

  @override
  String get settingsSetHome => 'Set home';

  @override
  String get settingsSetWork => 'Set work';

  @override
  String get settingsSetHomeHint =>
      'So we can warn you before you head home and watch flooding at your door';

  @override
  String get settingsSetWorkHint =>
      'So we can time your end-of-day warning better';

  @override
  String settingsWorkDetail(String days, String time) {
    return ' · $days, leaves $time';
  }

  @override
  String get settingsOutOfArea => 'Outside coverage';

  @override
  String get settingsWfh =>
      'Working from home — we\'ll only warn you about other trips';

  @override
  String get settingsAddPlace => 'Add a place';

  @override
  String settingsAddPlaceHint(int count, int max) {
    return 'Gym, kids\' school, parents\' place · $count of $max';
  }

  @override
  String settingsAddPlaceFull(int max) {
    return 'All $max slots used. Remove one to add another.';
  }

  @override
  String get settingsTravelGroup => 'Travel';

  @override
  String get settingsAutoGroup => 'Let the app find trips';

  @override
  String get settingsCalendarDetail => 'Only events with a location';

  @override
  String settingsCalendarAccount(String account) {
    return '$account · demo account';
  }

  @override
  String get settingsGmailHint =>
      'Only ticket and appointment confirmations. We don\'t store email content.';

  @override
  String get settingsPlaceHome => 'Home';

  @override
  String get settingsPlaceWork => 'Work';

  @override
  String get settingsPlaceSiam => 'Siam';

  @override
  String get settingsPlaceThonglor => 'Thong Lo';

  @override
  String get settingsPlaceImpact => 'IMPACT';

  @override
  String get verdictToolParseQuestion => 'Understood your question';

  @override
  String get verdictToolGetTrip => 'Checked your trip';

  @override
  String get verdictToolGetRoute => 'Found the route';

  @override
  String get verdictToolRain => 'Checked rain on the way';

  @override
  String get verdictToolFloodSpots => 'Checked flood spots';

  @override
  String get verdictToolCanals => 'Checked canal levels';

  @override
  String get verdictToolReports => 'Read community reports';

  @override
  String get verdictToolEvaluate => 'Weighed the risk';

  @override
  String get verdictHotlinesTitle => 'Emergency Assistance Helplines';

  @override
  String verdictHotlineCopied(String number, String purpose) {
    return 'Copied $number ($purpose) to clipboard';
  }

  @override
  String get verdictAccuracyDisclaimer =>
      'AI analysis and forecasts might not be 100% accurate. Always check actual conditions before traveling.';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsEmptyTitle => 'No notifications yet';

  @override
  String get notificationsEmptyBody =>
      'When it\'s almost time to leave or rain is on your route, alerts will show up here.';

  @override
  String get notificationsMarkAllRead => 'Mark all read';
}

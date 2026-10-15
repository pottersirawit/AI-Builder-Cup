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
  String get shellTabTrip => 'Travel';

  @override
  String get shellTabReport => 'Report flood';

  @override
  String get shellTabHome => 'Home';

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
  String get boardNoteDry => 'No rain on the way';

  @override
  String get boardNoteCarHeavy =>
      'Heavy rain, slow drainage, traffic building up';

  @override
  String get boardNoteCarDrizzle => 'Light rain near the end. Drive slower.';

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
  String get homeLoadErrorTitle => 'Couldn’t load your trips';

  @override
  String get homeLoadErrorBody =>
      'Can’t reach the server and there’s no sample data on this device. Check your connection and try again.';

  @override
  String get homeSeeWhatToDo => 'See what to do now';

  @override
  String get homeDecideErrorTitle => 'No verdict yet';

  @override
  String get homeDecideErrorBody =>
      'Can’t reach the server. Check your connection and try again.';

  @override
  String get homeSeeReasons => 'See why and the options';

  @override
  String get homeAskMore => 'Ask more';

  @override
  String get homeNoTripTitle => 'No trips yet';

  @override
  String get homeNoTripBody =>
      'Save your home and the app will warn you before you leave work each day. Or just ask above.';

  @override
  String get homeSetHome => 'Set home';

  @override
  String get homeSetWork => 'Set work';

  @override
  String get homeNoHomeTripTitle => 'No trip home today';

  @override
  String get homeWfhBody =>
      'You’re working from home, so the app only warns about other trips. Ask below, e.g. “Siam at 5 pm”.';

  @override
  String get homeNotWorkdayBody =>
      'Today isn’t a workday. If you’re heading out, ask below.';

  @override
  String get homePastCommuteBody =>
      'It’s past your usual time to head home. Tomorrow the app will check before you leave work.';

  @override
  String homeGpsInaccurate(String distance) {
    return 'Location may be off by $distance';
  }

  @override
  String get homePinMyself => 'Pin it myself';

  @override
  String get homeSetHomeHint =>
      'Set home to get a warning before you head back';

  @override
  String get homeSetWorkHint => 'Set your workplace for more accurate warnings';

  @override
  String get homeWfhNotice =>
      'Working from home — only other trips get warnings';

  @override
  String get homeCalendarHint =>
      'Connect Calendar so the app can see your plans';

  @override
  String get homeConnect => 'Connect';

  @override
  String get homeNoCalendarSoon => 'No events with a location in the next 24 h';

  @override
  String get homeAskHintHero => 'Where to, and when?';

  @override
  String get homeGreetingDemo => 'Hi Miw';

  @override
  String get homeGreeting => 'Hello';

  @override
  String get homeCurrentPlace => 'Current location';

  @override
  String get homeCurrentPlaceAlt => 'Current location';

  @override
  String homeHereSemantics(String name) {
    return 'Current location $name. Tap to pin your location yourself.';
  }

  @override
  String get homeSettings => 'Settings';

  @override
  String homeRouteTo(String place) {
    return 'Route to $place';
  }

  @override
  String homePreview(String time) {
    return 'Preview $time';
  }

  @override
  String homeDepart(String time) {
    return 'Leave $time';
  }

  @override
  String get homeArriveCaption => 'Arrive';

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
  String get homeNextTrips => 'Upcoming trips';

  @override
  String homeUnresolvedSubtitle(String location) {
    return '“$location” · Tap to pick the place';
  }

  @override
  String get homeUnresolvedStatus => 'Unknown place';

  @override
  String homeFutureSubtitle(String place) {
    return '$place · We’ll tell you when to leave on the day';
  }

  @override
  String get homeFutureStatus => 'Upcoming';

  @override
  String get homeTonightTitle => 'Home tonight';

  @override
  String get homeNoCanalStation => 'No canal gauge near home';

  @override
  String get homeOutOfArea => 'Outside the covered area · rain data only';

  @override
  String homeCanalLevel(String canal, String level, String bank) {
    return '$canal $level of $bank m';
  }

  @override
  String get homeQuickAsk => 'Quick ask';

  @override
  String get homeQuestionHomeNow => 'Go home now';

  @override
  String homeQuestionToNow(String place) {
    return 'Go to $place now';
  }

  @override
  String homeSetPlaceTooltip(String label) {
    return 'Set $label';
  }

  @override
  String get homeDefaultPlaceHome => 'Home';

  @override
  String get homeDefaultPlaceWork => 'Work';

  @override
  String get homeDefaultPlaceSiam => 'Siam';

  @override
  String get homeDefaultPlaceThonglor => 'Thonglor';

  @override
  String get homeDefaultPlaceImpact => 'IMPACT';

  @override
  String homeUsingPinned(String name) {
    return 'Using “$name” as your current location';
  }

  @override
  String get homeBackToGps => 'Use GPS again';

  @override
  String get homeTripGoHome => 'Go home';

  @override
  String get homeFromHereSemantics => 'Going home, from your current location';

  @override
  String get homeFromHereTitle => 'Going home · from your current location';

  @override
  String homeLeaveAround(String time) {
    return 'Leave around $time';
  }

  @override
  String get homeCheckRainHome => 'Check the rain on your way home';

  @override
  String get homeLocationOnTap =>
      'The app uses your location only when you tap, as the starting point.';

  @override
  String get homeCheckWayHome => 'Check the way home';

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
      'Replays the storm of Tue 29 Sep 2026 · sent as X-Demo-Clock';

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
  String get onboardingDemo => 'Use the demo profile (Miw)';

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
  String get floodSetHomeTitle =>
      'Set your home to see flood risk at your door';

  @override
  String get floodSetHomeMsg =>
      'We watch nearby canal levels, known flood spots and neighbours\' reports, and warn you even when the app is closed.';

  @override
  String get floodUseLocation => 'Use my location';

  @override
  String get floodSearch => 'Search';

  @override
  String get floodReadError => 'Can\'t read water levels';

  @override
  String get floodReadErrorMsg =>
      'Couldn\'t reach ThaiWater through the server. If water is rising fast, move your things up high first.';

  @override
  String get floodRetry => 'Try again';

  @override
  String get floodModeTitle => 'Flood mode';

  @override
  String get floodHome => 'Home';

  @override
  String get floodSameQuestion => 'Same question, higher stakes';

  @override
  String get floodNoHome => 'No home set yet';

  @override
  String get floodDoNow => 'Do this now, in order';

  @override
  String get floodPrepare => 'Get ready';

  @override
  String get floodSpotsTitle => 'Flood-prone spots near home';

  @override
  String get floodNoSpots => 'No flood spots within 2 km';

  @override
  String get floodNoSpotsMsg =>
      'Home isn\'t near any chronic flood spot the city has listed.';

  @override
  String floodFromHome(int meters) {
    return '$meters m from home';
  }

  @override
  String get floodNeighborsTitle => 'Neighbours on your street';

  @override
  String get floodNeighborsDanger => '11 people got the same alert';

  @override
  String get floodNeighborsWatch =>
      '3 people reported standing water in 20 minutes';

  @override
  String get floodNeighborsNote =>
      'People without smartphones get a LINE / SMS message, or a call that reads it aloud.';

  @override
  String floodStepSemantics(int order, String text) {
    return 'Step $order: $text';
  }

  @override
  String get floodNearbyTitle => 'Flood reports near me';

  @override
  String get floodNearbyButton => 'See flood reports near me';

  @override
  String get floodHereNow => 'Your location';

  @override
  String floodAround(String where) {
    return 'Around $where';
  }

  @override
  String get floodNoReports => 'No reports within 500 m';

  @override
  String get floodNoReportsMsg =>
      'Nobody has reported standing water here in the last 24 hours.';

  @override
  String floodWaterDepth(int min, int max) {
    return 'Water $min–$max cm';
  }

  @override
  String floodCarPassable(String status) {
    return 'Car: $status';
  }

  @override
  String get floodOtherSpot => 'Check another spot';

  @override
  String get reportCameraError =>
      'Couldn\'t open the camera. Try picking from your gallery instead.';

  @override
  String get reportGalleryError =>
      'Couldn\'t open your gallery. Check photo permission in your device settings.';

  @override
  String get reportTitle => 'Report flooding';

  @override
  String get reportSubtitle =>
      'Snap the water on the road and warn people heading there';

  @override
  String get reportTakePhoto => 'Take photo';

  @override
  String get reportFromGallery => 'From gallery';

  @override
  String get reportFailed => 'Couldn\'t send the report';

  @override
  String get reportFailedMsg =>
      'Couldn\'t reach the server. Your photo is still on your phone, so you can send it again.';

  @override
  String get reportResend => 'Send again';

  @override
  String get reportAnalyzing =>
      'Gemini is looking at the photo and judging the water against wheels and the curb…';

  @override
  String get reportAnalyzeHint =>
      'Gemini estimates the water depth from your photo, then warns people whose route passes within 300 m.';

  @override
  String get reportSeeHome => 'See conditions at home';

  @override
  String get reportLocating => 'Finding your location…';

  @override
  String get reportUsingGps => 'Using your phone\'s GPS';

  @override
  String reportGpsDetail(String lat, String lng, String time) {
    return 'GPS · $lat, $lng · $time';
  }

  @override
  String reportFallbackDetail(String note) {
    return '$note · using the demo\'s backup location';
  }

  @override
  String get reportRetryGps => 'Retry GPS';

  @override
  String reportDepthSemantics(int min, int max) {
    return 'Water about $min to $max centimetres deep';
  }

  @override
  String get reportSeenByGemini => 'Gemini has looked at it';

  @override
  String reportDepth(int min, int max) {
    return 'Water $min–$max cm deep';
  }

  @override
  String reportNotified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alerted $count people heading through here',
      one: 'Alerted 1 person heading through here',
    );
    return '$_temp0';
  }

  @override
  String reportCorroborated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Backed up by $count other reports within 300 m',
      one: 'Backed up by 1 other report within 300 m',
    );
    return '$_temp0';
  }

  @override
  String get reportDemoNumbers =>
      'The number of people alerted is a simulated figure for the demo';

  @override
  String get reportFrameHint => 'Include a wheel or the curb in the shot';

  @override
  String get reportNoPhoto => 'No photo · sample result';

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
  String get settingsRemindAhead => 'Remind me ahead';

  @override
  String get settingsRemindAheadHint => '2 hours before you should leave';

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
  String get settingsRoutine => 'Learn my routine';

  @override
  String get settingsRoutineHint =>
      'Notices you head home around 6 pm every day · coming soon';

  @override
  String get settingsCommunityGroup => 'Community and flooding';

  @override
  String get settingsShareReports => 'Share my flood reports';

  @override
  String get settingsShareReportsHint =>
      'Anonymous. Only location and water depth.';

  @override
  String get settingsHomeAlerts => 'Flood alerts for home';

  @override
  String get settingsHomeAlertsHint => 'Even when the app is closed';

  @override
  String get settingsSmsBackup => 'SMS backup';

  @override
  String get settingsSmsBackupHint => 'When there\'s no internet';

  @override
  String get settingsProfileGroup => 'Profile';

  @override
  String get settingsExitDemo => 'Leave the demo profile';

  @override
  String get settingsExitDemoHint =>
      'Removes Mew\'s places and goes back to the start';

  @override
  String get settingsUseDemo => 'Use the demo profile (Mew)';

  @override
  String get settingsUseDemoHint =>
      'Mew\'s sample places and appointments, for demos';

  @override
  String get settingsTeamGroup => 'For the team';

  @override
  String get settingsDesignSystem => 'Design system';

  @override
  String get settingsDesignSystemHint =>
      'Colour, type, spacing and components in every sky state';

  @override
  String get settingsDemoClock => 'Demo clock';

  @override
  String get settingsRealTime => 'Real time';

  @override
  String get settingsDemoNote =>
      'The name “Mew”, user counts and community reports in this app are simulated for the demo.';

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
  String get reportSampleResult =>
      'Sample result. The photo was not analysed by AI';

  @override
  String get reportRejectedTitle => 'We couldn\'t use this photo';
}

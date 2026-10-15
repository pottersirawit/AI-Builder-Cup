import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app_state.dart';
import '../design/design.dart';
import '../l10n/l10n.dart';
import '../location.dart';
import '../models.dart';
import '../places.dart';

/// Opens the picker for [kind] and returns the saved place, or null.
Future<SavedPlace?> pickPlace(
  BuildContext context, {
  required PlaceKind kind,
  String? initialQuery,
  bool locateNow = false,
  SavedPlace? editing,
}) => Navigator.of(context).push<SavedPlace>(
  MaterialPageRoute(
    builder: (_) => PlacePickerScreen(
      kind: kind,
      initialQuery: initialQuery,
      locateNow: locateNow,
      editing: editing,
    ),
  ),
);

/// Picks a point without saving it (e.g. reports near a searched place).
Future<PlaceCandidate?> pickPoint(BuildContext context) =>
    Navigator.of(context).push<PlaceCandidate>(
      MaterialPageRoute(
        builder: (_) =>
            const PlacePickerScreen(kind: PlaceKind.other, save: false),
      ),
    );

/// Edits a saved place from Settings: details in the sheet, "ย้ายตำแหน่ง"
/// through the picker, delete with a snackbar undo.
Future<void> editPlace(BuildContext context, SavedPlace place) async {
  final store = AppScope.readPlaces(context);
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  final r = await showPlaceConfirmSheet(
    context,
    kind: place.kind,
    candidate: candidateOf(place),
    editing: place,
  );
  if (r == null || !context.mounted) return;
  if (r.move) {
    await pickPlace(context, kind: place.kind, editing: place);
  } else if (r.delete) {
    final removed = store.remove(place.id);
    if (removed == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.pickerDeleted(place.labelFor(l))),
          action: SnackBarAction(
            label: l.pickerUndo,
            onPressed: () => store.restore(removed.place, removed.index),
          ),
        ),
      );
  }
}

PlaceCandidate candidateOf(SavedPlace p) => PlaceCandidate(
  nameTh: p.nameTh,
  addressTh: p.addressTh,
  lat: p.lat,
  lng: p.lng,
  source: 'saved',
);

String _pickerTitle(
  AppLocalizations l,
  PlaceKind kind,
  SavedPlace? editing,
  bool save,
) {
  if (!save) return l.pickerTitlePoint;
  if (editing != null) return l.pickerTitleMove(editing.labelFor(l));
  return switch (kind) {
    PlaceKind.home => l.pickerTitleHome,
    PlaceKind.work => l.pickerTitleWork,
    PlaceKind.other => l.pickerTitleOther,
  };
}

/// Search or use the phone's position, then confirm before saving.
class PlacePickerScreen extends StatefulWidget {
  const PlacePickerScreen({
    super.key,
    required this.kind,
    this.initialQuery,
    this.locateNow = false,
    this.editing,
    this.save = true,
  });
  final PlaceKind kind;
  final String? initialQuery;

  /// Starts with "ใช้ตำแหน่งตอนนี้" instead of the keyboard.
  final bool locateNow;
  final SavedPlace? editing;

  /// False: return the chosen point without the confirm sheet.
  final bool save;

  @override
  State<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends State<PlacePickerScreen> {
  static const debounce = Duration(milliseconds: 300);
  static const minChars = 2;

  late final _query = TextEditingController(text: widget.initialQuery ?? '');
  final _focus = FocusNode();
  Timer? _timer;
  int _seq = 0;

  String _searched = '';
  List<PlaceCandidate>? _results;
  bool _searching = false;
  bool _offline = false;
  bool _failed = false;
  bool _naming = false;

  @override
  void initState() {
    super.initState();
    if (_query.text.trim().length >= minChars) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search(_query.text));
    } else if (!widget.locateNow) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _focus.requestFocus(),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _timer?.cancel();
    if (q.trim().length < minChars) {
      _seq++;
      setState(() {
        _results = null;
        _searching = false;
        _failed = false;
      });
      return;
    }
    setState(() => _searching = true);
    _timer = Timer(debounce, () => _search(q));
  }

  Future<void> _search(String q) async {
    final seq = ++_seq;
    final api = AppScope.apiOf(context);
    setState(() {
      _searching = true;
      _failed = false;
    });
    try {
      final r = await api.searchPlaces(q.trim());
      if (!mounted || seq != _seq) return;
      setState(() {
        _searched = q.trim();
        _results = r.data;
        _offline = r.isSample;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _searched = q.trim();
        _results = null;
        _failed = true;
        _searching = false;
      });
    }
  }

  Future<void> _onFix(LocateResult fix) async {
    final api = AppScope.apiOf(context);
    final pinned = context.l10n.pickerDroppedPin;
    setState(() => _naming = true);
    PlaceCandidate c;
    try {
      c = (await api.reversePlace(fix.lat, fix.lng)).data;
    } catch (_) {
      c = PlaceCandidate(
        nameTh: pinned,
        addressTh:
            '${fix.lat.toStringAsFixed(4)}, ${fix.lng.toStringAsFixed(4)}',
        lat: fix.lat,
        lng: fix.lng,
      );
    }
    if (!mounted) return;
    setState(() => _naming = false);
    await _choose(c.withAccuracy(fix.accuracyM ?? 0));
  }

  Future<void> _choose(PlaceCandidate c) async {
    if (!widget.save) {
      Navigator.pop(context, c);
      return;
    }
    final r = await showPlaceConfirmSheet(
      context,
      kind: widget.kind,
      candidate: c,
      editing: widget.editing,
    );
    if (!mounted || r == null) return;
    if (r.saved != null) {
      Navigator.pop(context, r.saved);
    } else if (r.searchInstead) {
      _focus.requestFocus();
    }
  }

  void _searchInstead() => _focus.requestFocus();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.stateOf(context);
    final sky = state.flood ? SkyState.flood : SkyState.clear;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final q = _query.text.trim();
    final l = context.l10n;

    Widget results;
    if (q.length < minChars) {
      results = Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          Space.x4,
          Space.gutter,
          0,
        ),
        child: SourceLabel(
          l.pickerHintTyping(minChars),
          icon: Symbols.info_rounded,
        ),
      );
    } else if (_searching) {
      results = const SkeletonList();
    } else if (_failed) {
      results = ErrorState(
        title: l.pickerSearchFailedTitle,
        message: l.pickerSearchFailedMessage,
        onRetry: () => _search(q),
      );
    } else if (_results != null && _results!.isEmpty) {
      results = EmptyState(
        icon: Symbols.search_off_rounded,
        title: l.pickerNoResultsTitle(_searched),
        message: _offline
            ? l.pickerNoResultsMessageOffline
            : l.pickerNoResultsMessage,
        action: Wrap(
          spacing: Space.x2,
          runSpacing: Space.x2,
          children: [
            if (widget.save)
              OutlinedButton.icon(
                onPressed: () => _locateKey.currentState?.start(),
                icon: const Icon(Symbols.my_location_rounded),
                label: Text(l.pickerUseLocation),
              ),
            if (_offline)
              TextButton(
                onPressed: () => _search(q),
                child: Text(l.pickerSearchOnlineAgain),
              ),
          ],
        ),
      );
    } else if (_results != null) {
      results = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_offline)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.x2,
                Space.gutter,
                Space.x2,
              ),
              child: Notice(
                icon: Symbols.cloud_off_rounded,
                tone: NoticeTone.warning,
                text: l.pickerOfflineNotice,
                action: TextButton(
                  onPressed: () => _search(q),
                  child: Text(l.placesRetry),
                ),
              ),
            ),
          for (final c in _results!)
            ListTile(
              leading: const Icon(Symbols.location_on_rounded),
              title: Text(c.nameTh),
              subtitle: Text(
                c.nameEn == null ? c.addressTh : '${c.addressTh} · ${c.nameEn}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: inServiceArea(c.lat, c.lng)
                  ? null
                  : RiskChip(
                      risk: Risk.medium,
                      label: l.pickerOutOfArea,
                      dense: true,
                    ),
              onTap: () => _choose(c),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.x2,
              Space.gutter,
              0,
            ),
            child: SourceLabel(
              _results!.any((c) => c.source == 'google')
                  ? l.pickerSourceGoogle
                  : l.pickerSourceLocal,
            ),
          ),
        ],
      );
    } else {
      results = const SizedBox.shrink();
    }

    return Scaffold(
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: SkyField(
              state: sky,
              height: double.infinity,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    FieldHeader(
                      state: sky,
                      back: true,
                      title: _pickerTitle(
                        l,
                        widget.kind,
                        widget.editing,
                        widget.save,
                      ),
                      subtitle: l.pickerSubtitle,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.gutter,
                        0,
                        Space.gutter,
                        Space.x4,
                      ),
                      child: TextField(
                        controller: _query,
                        focusNode: _focus,
                        onChanged: _onChanged,
                        onSubmitted: (v) {
                          if (v.trim().length >= minChars) _search(v);
                        },
                        textInputAction: TextInputAction.search,
                        style: t.bodyLarge,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: scheme.surfaceContainerLowest,
                          hintText: l.pickerSearchHint,
                          prefixIcon: const Icon(Symbols.search_rounded),
                          suffixIcon: q.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: l.pickerClear,
                                  onPressed: () {
                                    _query.clear();
                                    _onChanged('');
                                  },
                                  icon: const Icon(Symbols.close_rounded),
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(Radii.pill),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: Space.x2),
              child: LocatePanel(
                key: _locateKey,
                autoStart: widget.locateNow,
                busyLabel: _naming ? l.pickerNaming : null,
                onFix: _onFix,
                onSearchInstead: _searchInstead,
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Divider(indent: Space.gutter, endIndent: Space.gutter),
          ),
          SliverToBoxAdapter(child: results),
          SliverToBoxAdapter(
            child: SizedBox(
              height: Space.x10 + MediaQuery.viewInsetsOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }

  final _locateKey = GlobalKey<LocatePanelState>();
}

/// "ใช้ตำแหน่งตอนนี้" and every state it can land in: the rationale before
/// the first OS prompt, denied, denied forever, location off, timeout. It
/// re-checks when the user comes back from Settings, and never re-prompts.
class LocatePanel extends StatefulWidget {
  const LocatePanel({
    super.key,
    required this.onFix,
    required this.onSearchInstead,
    this.autoStart = false,
    this.busyLabel,
  });
  final ValueChanged<LocateResult> onFix;
  final VoidCallback onSearchInstead;
  final bool autoStart;

  /// Shown while the caller works on the fix (e.g. naming it).
  final String? busyLabel;

  @override
  State<LocatePanel> createState() => LocatePanelState();
}

class LocatePanelState extends State<LocatePanel> with WidgetsBindingObserver {
  LocateStatus? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.autoStart)
      WidgetsBinding.instance.addPostFrameCallback((_) => start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    const blocked = {
      LocateStatus.denied,
      LocateStatus.deniedForever,
      LocateStatus.servicesOff,
    };
    if (state == AppLifecycleState.resumed && blocked.contains(_status))
      _run(prompt: false, quiet: true);
  }

  /// Starts locating; a first-time permission shows the rationale instead.
  void start() => _run(prompt: false);

  Future<void> _run({required bool prompt, bool quiet = false}) async {
    final store = AppScope.readPlaces(context);
    final locator = AppScope.locatorOf(context);
    if (!quiet) setState(() => _busy = true);
    final r = await locator.locate(
      prompt: prompt,
      askedBefore: store.locationAsked,
    );
    if (prompt) store.markLocationAsked();
    if (!mounted) return;
    if (quiet && !r.ok) {
      setState(() => _status = r.status);
      return;
    }
    setState(() {
      _busy = false;
      _status = r.ok ? null : r.status;
    });
    if (r.ok) widget.onFix(r);
  }

  @override
  Widget build(BuildContext context) {
    final locator = AppScope.locatorOf(context);
    final l = context.l10n;
    final busy = _busy || widget.busyLabel != null;
    if (busy) {
      return ListTile(
        leading: const SizedBox.square(
          dimension: 24,
          child: Padding(
            padding: EdgeInsets.all(2),
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
        title: Text(widget.busyLabel ?? l.locateBusy),
        subtitle: Text(l.locateBusyHint),
      );
    }
    final search = TextButton.icon(
      onPressed: widget.onSearchInstead,
      icon: const Icon(Symbols.search_rounded),
      label: Text(l.locateSearchInstead),
    );
    Widget block(
      IconData icon,
      String title,
      String message,
      List<Widget> actions,
    ) => EmptyState(
      icon: icon,
      title: title,
      message: message,
      action: Wrap(spacing: Space.x2, runSpacing: Space.x2, children: actions),
    );
    return switch (_status) {
      null => ListTile(
        leading: const Icon(Symbols.my_location_rounded),
        title: Text(l.pickerUseLocation),
        subtitle: Text(l.locateIdleHint),
        onTap: start,
      ),
      LocateStatus.notAsked => block(
        Symbols.location_on_rounded,
        l.locateAskTitle,
        l.locateAskMessage,
        [
          FilledButton.icon(
            onPressed: () => _run(prompt: true),
            icon: const Icon(Symbols.my_location_rounded),
            label: Text(l.locateAllow),
          ),
          search,
        ],
      ),
      LocateStatus.denied || LocateStatus.deniedForever => block(
        Symbols.location_disabled_rounded,
        l.locateDeniedTitle,
        _status == LocateStatus.deniedForever
            ? l.locateDeniedForeverMessage
            : l.locateDeniedMessage,
        [
          FilledButton.tonalIcon(
            onPressed: locator.openAppSettings,
            icon: const Icon(Symbols.settings_rounded),
            label: Text(l.locateOpenSettings),
          ),
          search,
        ],
      ),
      LocateStatus.servicesOff => block(
        Symbols.location_off_rounded,
        l.locateOffTitle,
        l.locateOffMessage,
        [
          FilledButton.tonalIcon(
            onPressed: locator.openLocationSettings,
            icon: const Icon(Symbols.settings_rounded),
            label: Text(l.locateOpenLocationSettings),
          ),
          search,
        ],
      ),
      LocateStatus.timeout || LocateStatus.error || LocateStatus.ok => block(
        Symbols.location_searching_rounded,
        _status == LocateStatus.timeout
            ? l.locateTimeoutTitle
            : l.locateErrorTitle,
        l.locateWeakMessage,
        [
          FilledButton.tonalIcon(
            onPressed: start,
            icon: const Icon(Symbols.refresh_rounded),
            label: Text(l.placesRetry),
          ),
          search,
        ],
      ),
    };
  }
}

/// The phone's position for a one-off look (nearby reports, the trip home
/// from here), with the same permission states in a sheet. "ค้นหาแทน"
/// switches to picking a point by name.
Future<PlaceCandidate?> locateOrSearch(BuildContext context) async {
  var searchInstead = false;
  final fix = await showModalBottomSheet<LocateResult>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: Space.x4),
        child: LocatePanel(
          autoStart: true,
          onFix: (r) => Navigator.pop(ctx, r),
          onSearchInstead: () {
            searchInstead = true;
            Navigator.pop(ctx);
          },
        ),
      ),
    ),
  );
  if (!context.mounted) return null;
  if (fix != null) {
    return PlaceCandidate(
      nameTh: context.l10n.pickerHereNow,
      lat: fix.lat,
      lng: fix.lng,
      source: 'gps',
      accuracyM: fix.accuracyM,
    );
  }
  return searchInstead ? pickPoint(context) : null;
}

/// How the confirm sheet closed.
class PlaceSheetResult {
  const PlaceSheetResult({
    this.saved,
    this.delete = false,
    this.move = false,
    this.searchInstead = false,
  });
  final SavedPlace? saved;
  final bool delete;
  final bool move;
  final bool searchInstead;
}

/// Confirm before saving: pin preview, name, editable label and icon, work
/// days and leave time for work, and the duplicate, out-of-area, low-accuracy
/// and work-from-home notes. With [editing], also move and delete.
Future<PlaceSheetResult?> showPlaceConfirmSheet(
  BuildContext context, {
  required PlaceKind kind,
  required PlaceCandidate candidate,
  SavedPlace? editing,
}) => showModalBottomSheet<PlaceSheetResult>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) =>
      PlaceConfirmSheet(kind: kind, candidate: candidate, editing: editing),
);

class PlaceConfirmSheet extends StatefulWidget {
  const PlaceConfirmSheet({
    super.key,
    required this.kind,
    required this.candidate,
    this.editing,
  });
  final PlaceKind kind;
  final PlaceCandidate candidate;
  final SavedPlace? editing;

  @override
  State<PlaceConfirmSheet> createState() => _PlaceConfirmSheetState();
}

class _PlaceConfirmSheetState extends State<PlaceConfirmSheet> {
  late final SavedPlace? _e = widget.editing;
  late final _initialLabel =
      _e?.labelFor(context.l10n) ??
      switch (widget.kind) {
        PlaceKind.home => context.l10n.placeKindHome,
        PlaceKind.work => context.l10n.placeKindWork,
        PlaceKind.other => widget.candidate.nameTh.replaceFirst(
          RegExp('^ใกล้'),
          '',
        ),
      };
  late final _label = TextEditingController(text: _initialLabel);
  late String _icon =
      _e?.icon ??
      switch (widget.kind) {
        PlaceKind.home => 'home',
        PlaceKind.work => 'work',
        PlaceKind.other => 'pin',
      };
  late List<int> _days = [...(_e?.days ?? SavedPlace.defaultWorkDays)];
  late String _leave = _e?.leaveTime ?? SavedPlace.defaultLeaveTime;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  SavedPlace _build(String id, PlaceKind kind) => SavedPlace(
    id: id,
    kind: kind,
    labelTh: _storedLabel(kind),
    nameTh: widget.candidate.nameTh,
    addressTh: widget.candidate.addressTh,
    lat: widget.candidate.lat,
    lng: widget.candidate.lng,
    icon: _icon,
    days: _days,
    leaveTime: _leave,
  );

  /// What is stored for the label: the Thai default when the shown default was
  /// left alone, otherwise what the user typed.
  String _storedLabel(PlaceKind kind) {
    final text = _label.text.trim();
    if (text.isEmpty) return kindLabelTh(kind);
    if (text == _initialLabel.trim()) {
      if (_e != null) return _e.labelTh;
      if (kind != PlaceKind.other) return kindLabelTh(kind);
    }
    return text;
  }

  void _save(SavedPlace p) {
    final store = AppScope.readPlaces(context);
    if (store.save(p) == SaveRefusal.tooManyOthers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.sheetTooMany(PlacesStore.maxOthers)),
        ),
      );
      return;
    }
    Navigator.pop(context, PlaceSheetResult(saved: p));
  }

  Future<void> _pickTime() async {
    final hm = _leave.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(hm[0]), minute: int.parse(hm[1])),
      helpText: context.l10n.sheetLeaveTime,
    );
    if (t != null) {
      setState(
        () => _leave =
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.placesOf(context);
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final c = widget.candidate;
    final kind = widget.kind;
    final ofKind = switch (kind) {
      PlaceKind.home => store.home,
      PlaceKind.work => store.work,
      PlaceKind.other => null,
    };
    final dup = store.duplicateOf(
      c.lat,
      c.lng,
      exceptId: _e?.id ?? ofKind?.id,
      forKind: kind,
    );
    final partner = switch (kind) {
      PlaceKind.home => store.work,
      PlaceKind.work => store.home,
      PlaceKind.other => null,
    };
    final wfh =
        partner != null &&
        partner.distanceTo(c.lat, c.lng) <= PlacesStore.duplicateRadiusM;
    final inArea = c.inServiceArea ?? inServiceArea(c.lat, c.lng);
    final acc = c.accuracyM;
    final fromGps = acc != null;
    final source = switch (c.source) {
      'google' => 'Google Maps',
      'saved' => l.sheetSourceSaved,
      _ => l.sheetSourceLocal,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          0,
          Space.gutter,
          Space.x6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _e != null
                  ? l.sheetEdit(_e.labelFor(l))
                  : l.sheetConfirm(kindLabel(l, kind)),
              style: t.titleLarge,
            ),
            const SizedBox(height: Space.x3),
            PinPreview(lat: c.lat, lng: c.lng, accuracyM: acc),
            const SizedBox(height: Space.x3),
            Text(c.nameTh, style: t.titleMedium),
            if (c.addressTh.isNotEmpty)
              Text(
                c.addressTh,
                style: t.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
              ),
            const SizedBox(height: Space.x2),
            SourceLabel(fromGps ? l.sheetSourceGps : source),
            if (!inArea) ...[
              const SizedBox(height: Space.x3),
              Notice(
                icon: Symbols.travel_explore_rounded,
                tone: NoticeTone.warning,
                text: l.sheetOutOfArea,
              ),
            ],
            if (fromGps && acc > 200) ...[
              const SizedBox(height: Space.x3),
              Notice(
                icon: Symbols.location_searching_rounded,
                tone: NoticeTone.warning,
                text: l.sheetLowAccuracy(approxDistance(l, acc)),
                action: TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    const PlaceSheetResult(searchInstead: true),
                  ),
                  child: Text(l.locateSearchInstead),
                ),
              ),
            ],
            if (wfh) ...[
              const SizedBox(height: Space.x3),
              Notice(
                icon: Symbols.home_work_rounded,
                text: l.sheetWorkFromHome,
              ),
            ],
            if (dup != null) ...[
              const SizedBox(height: Space.x3),
              Notice(
                icon: Symbols.join_rounded,
                tone: NoticeTone.warning,
                text: l.sheetDuplicate(dup.labelFor(l)),
              ),
            ],
            const SizedBox(height: Space.x5),
            TextField(
              controller: _label,
              decoration: InputDecoration(
                labelText: l.sheetNameLabel,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: Space.x4),
            Text(
              l.sheetIcon,
              style: t.labelLarge!.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Space.x1),
            Wrap(
              children: [
                for (final k in placeIconKeys)
                  IconButton(
                    tooltip: k,
                    isSelected: k == _icon,
                    onPressed: () => setState(() => _icon = k),
                    style: IconButton.styleFrom(
                      backgroundColor: k == _icon
                          ? scheme.secondaryContainer
                          : null,
                    ),
                    icon: Icon(placeIcon(k), fill: k == _icon ? 1 : 0),
                  ),
              ],
            ),
            if (kind == PlaceKind.work) ...[
              const SizedBox(height: Space.x4),
              Text(
                l.sheetWorkDays,
                style: t.labelLarge!.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: Space.x2),
              Wrap(
                spacing: Space.x1,
                runSpacing: Space.x1,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(weekdayInitial(l, d)),
                      showCheckmark: false,
                      selected: _days.contains(d),
                      onSelected: (on) => setState(
                        () => _days = on
                            ? ([..._days, d]..sort())
                            : (_days.where((x) => x != d).toList()),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Space.x2),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Symbols.schedule_rounded),
                title: Text(l.sheetLeaveTime),
                subtitle: Text(l.sheetLeaveHint),
                trailing: Text(_leave, style: tabular(t.titleMedium!)),
                onTap: _pickTime,
              ),
            ],
            const SizedBox(height: Space.x5),
            if (dup != null) ...[
              FilledButton(
                onPressed: () => _save(
                  _build(dup.id, kind == PlaceKind.other ? dup.kind : kind),
                ),
                child: Text(l.sheetUpdateExisting),
              ),
              const SizedBox(height: Space.x2),
              OutlinedButton(
                onPressed: () =>
                    _save(_build(_e?.id ?? ofKind?.id ?? store.newId(), kind)),
                child: Text(l.sheetSaveSeparate),
              ),
            ] else
              FilledButton(
                onPressed: () =>
                    _save(_build(_e?.id ?? ofKind?.id ?? store.newId(), kind)),
                child: Text(l.sheetSave),
              ),
            if (_e != null) ...[
              const SizedBox(height: Space.x2),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(
                        context,
                        const PlaceSheetResult(move: true),
                      ),
                      icon: const Icon(Symbols.edit_location_alt_rounded),
                      label: Text(l.sheetMove),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.error,
                      ),
                      onPressed: () => Navigator.pop(
                        context,
                        const PlaceSheetResult(delete: true),
                      ),
                      icon: const Icon(Symbols.delete_rounded),
                      label: Text(l.sheetDelete(_e.labelFor(l))),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

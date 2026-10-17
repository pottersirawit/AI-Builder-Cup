import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/design.dart';
import '../l10n/l10n.dart';
import '../location.dart';
import '../models.dart';
import '../places.dart';
import 'place_picker.dart';

/// Shows a bottom sheet allowing the user to select the starting point for a trip
/// (e.g. from a previous event, current GPS, home, work, or another place).
Future<Place?> showOriginPickerSheet({
  required BuildContext context,
  required Place currentOrigin,
  Trip? previousTrip,
  SavedPlace? home,
  SavedPlace? work,
  List<SavedPlace> others = const [],
  LocateResult? currentLocation,
  required ValueChanged<Place> onSelected,
}) {
  final l = context.l10n;
  final t = Theme.of(context).textTheme;
  final scheme = Theme.of(context).colorScheme;

  return showModalBottomSheet<Place>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      bool isSelected(Place p) =>
          (p.lat - currentOrigin.lat).abs() < 0.0001 &&
          (p.lng - currentOrigin.lng).abs() < 0.0001;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.gutter,
            vertical: Space.x2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.isThai ? 'เลือกจุดเริ่มต้นการเดินทาง' : 'Choose starting point',
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: Space.x2),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (previousTrip != null &&
                        previousTrip.destination.resolved) ...[
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: scheme.primaryContainer,
                          child: Icon(
                            Symbols.event_upcoming_rounded,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        title: Text(previousTrip.destination.nameTh),
                        subtitle: Text(
                          l.isThai
                              ? 'งานก่อนหน้า · ${previousTrip.titleTh}'
                              : 'Previous event · ${previousTrip.titleTh}',
                        ),
                        trailing: isSelected(previousTrip.destination)
                            ? Icon(Symbols.check_rounded, color: scheme.primary)
                            : null,
                        onTap: () {
                          Navigator.of(sheetContext).pop(previousTrip.destination);
                          onSelected(previousTrip.destination);
                        },
                      ),
                      const Divider(),
                    ],
                    if (currentLocation != null && currentLocation.ok) ...[
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: scheme.secondaryContainer,
                          child: Icon(
                            Symbols.my_location_rounded,
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                        title: Text(
                          l.isThai
                              ? 'ตำแหน่งปัจจุบัน (GPS)'
                              : 'Current location (GPS)',
                        ),
                        subtitle: Text(
                          '${currentLocation.lat.toStringAsFixed(4)}, ${currentLocation.lng.toStringAsFixed(4)}',
                        ),
                        trailing: (currentOrigin.lat - currentLocation.lat).abs() < 0.0001 &&
                                (currentOrigin.lng - currentLocation.lng).abs() < 0.0001
                            ? Icon(Symbols.check_rounded, color: scheme.primary)
                            : null,
                        onTap: () {
                          final p = Place(
                            nameTh: l.isThai
                                ? 'ตำแหน่งปัจจุบัน'
                                : 'Current location',
                            lat: currentLocation.lat,
                            lng: currentLocation.lng,
                          );
                          Navigator.of(sheetContext).pop(p);
                          onSelected(p);
                        },
                      ),
                    ],
                    if (home != null)
                      ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Symbols.home_rounded),
                        ),
                        title: Text(
                          home.nameTh.isNotEmpty ? home.nameTh : home.labelTh,
                        ),
                        subtitle: Text(l.isThai ? 'บ้าน' : 'Home'),
                        trailing: isSelected(home.asPlace)
                            ? Icon(Symbols.check_rounded, color: scheme.primary)
                            : null,
                        onTap: () {
                          Navigator.of(sheetContext).pop(home.asPlace);
                          onSelected(home.asPlace);
                        },
                      ),
                    if (work != null)
                      ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Symbols.work_rounded),
                        ),
                        title: Text(
                          work.nameTh.isNotEmpty ? work.nameTh : work.labelTh,
                        ),
                        subtitle: Text(l.isThai ? 'ที่ทำงาน' : 'Work'),
                        trailing: isSelected(work.asPlace)
                            ? Icon(Symbols.check_rounded, color: scheme.primary)
                            : null,
                        onTap: () {
                          Navigator.of(sheetContext).pop(work.asPlace);
                          onSelected(work.asPlace);
                        },
                      ),
                    for (final other in others)
                      ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Symbols.place_rounded),
                        ),
                        title: Text(
                          other.nameTh.isNotEmpty ? other.nameTh : other.labelTh,
                        ),
                        trailing: isSelected(other.asPlace)
                            ? Icon(Symbols.check_rounded, color: scheme.primary)
                            : null,
                        onTap: () {
                          Navigator.of(sheetContext).pop(other.asPlace);
                          onSelected(other.asPlace);
                        },
                      ),
                    const Divider(),
                    ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Symbols.search_rounded),
                      ),
                      title: Text(
                        l.isThai
                            ? 'ค้นหาสถานที่อื่น...'
                            : 'Search another place...',
                      ),
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        final picked = await pickPlace(
                          context,
                          kind: PlaceKind.other,
                        );
                        if (picked != null) {
                          onSelected(picked.asPlace);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

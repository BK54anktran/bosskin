import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../core/map/app_tile_layer.dart';
import '../../core/theme/app_theme.dart';

/// Chip nhỏ "📍 Check-in" / "📍 Check-out" ở lịch sử chấm công: bấm mở hộp bản đồ nhỏ đúng điểm chấm.
class AttendanceLocationChip extends StatelessWidget {
  final String label;
  final double latitude;
  final double longitude;
  final Color color;

  const AttendanceLocationChip({
    super.key,
    required this.label,
    required this.latitude,
    required this.longitude,
    this.color = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => showAttendanceLocation(context, label, latitude, longitude, color),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.place_outlined, size: 13, color: color),
                const SizedBox(width: 2),
                Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ),
      );
}

Future<void> showAttendanceLocation(
    BuildContext context, String label, double lat, double lng, Color color) {
  final s = AppLocalizations.of(context);
  final point = LatLng(lat, lng);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${s.attendanceLocationTitle} · $label', style: const TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FlutterMap(
                  options: MapOptions(initialCenter: point, initialZoom: 17),
                  children: [
                    appTileLayer(),
                    MarkerLayer(markers: [
                      Marker(
                        point: point,
                        width: 36,
                        height: 36,
                        child: Icon(Icons.location_on, color: color, size: 36),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.close))],
    ),
  );
}

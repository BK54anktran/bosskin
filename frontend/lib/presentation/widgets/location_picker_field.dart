import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../core/map/app_tile_layer.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/utils/error_utils.dart';
import '../../core/utils/maps_link_utils.dart';
import '../../data/repositories/geo_repository.dart';
import '../../l10n/app_localizations.dart';

typedef LocationChanged = void Function(double? lat, double? lng, int radiusMeters);

/// Widget chọn vị trí check-in: OSM map + GPS button + dán link Google Maps + manual input + radius.
class LocationPickerField extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final int radiusMeters;
  final LocationChanged onChanged;

  const LocationPickerField({
    super.key,
    this.latitude,
    this.longitude,
    this.radiusMeters = 100,
    required this.onChanged,
  });

  @override
  State<LocationPickerField> createState() => _LocationPickerFieldState();
}

class _LocationPickerFieldState extends State<LocationPickerField> {
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late final TextEditingController _radiusCtrl;
  late int _radius;
  late final MapController _mapCtrl;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _latCtrl = TextEditingController(
        text: widget.latitude != null ? widget.latitude!.toStringAsFixed(6) : '');
    _lngCtrl = TextEditingController(
        text: widget.longitude != null ? widget.longitude!.toStringAsFixed(6) : '');
    _radius = widget.radiusMeters;
    _radiusCtrl = TextEditingController(text: _radius.toString());
    _mapCtrl = MapController();
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  LatLng? get _current {
    final lat = double.tryParse(_latCtrl.text);
    final lng = double.tryParse(_lngCtrl.text);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  void _notify() {
    final pos = _current;
    widget.onChanged(pos?.latitude, pos?.longitude, _radius);
  }

  void _onMapTap(TapPosition _, LatLng point) {
    setState(() {
      _latCtrl.text = point.latitude.toStringAsFixed(6);
      _lngCtrl.text = point.longitude.toStringAsFixed(6);
    });
    _notify();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) { setState(() => _locating = false); return; }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        setState(() => _locating = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _latCtrl.text = pos.latitude.toStringAsFixed(6);
        _lngCtrl.text = pos.longitude.toStringAsFixed(6);
        _locating = false;
      });
      _mapCtrl.move(LatLng(pos.latitude, pos.longitude), 16);
      _notify();
    } catch (_) {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Dán link Google Maps (hoặc "vĩ độ, kinh độ") → điền toạ độ và dời bản đồ tới đó.
  Future<void> _pasteMapsLink() async {
    final point = await showInstantDialog<LatLng>(context, (ctx) => const _MapsLinkDialog());
    if (point == null || !mounted) return;
    setState(() {
      _latCtrl.text = point.latitude.toStringAsFixed(6);
      _lngCtrl.text = point.longitude.toStringAsFixed(6);
    });
    _mapCtrl.move(point, 16);
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final pos = _current;
    final initialCenter = pos ?? const LatLng(10.7769, 106.7009); // HCM fallback

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Map ──
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 260,
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: pos != null ? 16 : 12,
                onTap: _onMapTap,
              ),
              children: [
                appTileLayer(),
                if (pos != null)
                  CircleLayer(circles: [
                    CircleMarker(
                      point: pos,
                      radius: _radius.toDouble(),
                      useRadiusInMeter: true,
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderColor: AppTheme.primary,
                      borderStrokeWidth: 1.5,
                    ),
                  ]),
                if (pos != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: pos,
                      width: 36,
                      height: 36,
                      child: const Icon(Icons.location_pin,
                          color: AppTheme.error, size: 36),
                    ),
                  ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // ── GPS button + dán link Google Maps ──
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location, size: 16),
                label: Text(s.useCurrentLocation,
                    style: const TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: s.mapsLinkTitle,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: OutlinedButton.icon(
                  onPressed: _pasteMapsLink,
                  icon: const Icon(Icons.link, size: 16),
                  label: Text(s.pasteMapsLink,
                      style: const TextStyle(fontSize: 13)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // ── Lat / Lng / Radius ──
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _latCtrl,
                decoration: InputDecoration(
                    labelText: s.latitude, isDense: true),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
                onChanged: (_) => _notify(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _lngCtrl,
                decoration: InputDecoration(
                    labelText: s.longitude, isDense: true),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
                onChanged: (_) => _notify(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: TextFormField(
                controller: _radiusCtrl,
                decoration: InputDecoration(
                  labelText: s.radius,
                  isDense: true,
                  suffixText: 'm',
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final val = int.tryParse(v);
                  if (val != null && val > 0) {
                    setState(() => _radius = val);
                    _notify();
                  }
                },
              ),
            ),
          ],
        ),
        if (pos != null) ...[
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () {
              setState(() { _latCtrl.clear(); _lngCtrl.clear(); });
              widget.onChanged(null, null, _radius);
            },
            icon: const Icon(Icons.clear, size: 14),
            label: Text(s.clearLocation,
                style: const TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// Hộp nhập link Google Maps: đọc toạ độ ngay nếu link đầy đủ, link rút gọn thì nhờ backend mở.
class _MapsLinkDialog extends StatefulWidget {
  const _MapsLinkDialog();

  @override
  State<_MapsLinkDialog> createState() => _MapsLinkDialogState();
}

class _MapsLinkDialogState extends State<_MapsLinkDialog> {
  final _ctrl = TextEditingController();
  final _repo = GeoRepository();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || data?.text == null) return;
    setState(() {
      _ctrl.text = data!.text!.trim();
      _error = null;
    });
  }

  Future<void> _apply() async {
    final s = AppLocalizations.of(context);
    final text = _ctrl.text.trim();
    final local = parseMapsCoordinates(text);
    if (local != null) {
      Navigator.pop(context, local);
      return;
    }
    if (!looksLikeUrl(text)) {
      setState(() => _error = s.mapsLinkNotFound);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final point = await _repo.resolveMapsLink(text);
      if (mounted) Navigator.pop(context, point);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = serverMsg(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(s.mapsLinkTitle),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.mapsLinkHint,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: s.mapsLinkField,
                isDense: true,
                errorText: _error,
                errorMaxLines: 3,
                suffixIcon: IconButton(
                  tooltip: s.mapsLinkPaste,
                  icon: const Icon(Icons.content_paste, size: 18),
                  onPressed: _busy ? null : _paste,
                ),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _busy ? null : _apply(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _apply,
          child: _busy
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(s.mapsLinkApply),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/map/app_tile_layer.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/utils/attendance_message_utils.dart';
import '../../../data/models/attendance.dart';
import '../../../data/repositories/attendance_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/notification_service.dart';
import 'package:bosskin/l10n/app_localizations.dart';

class CheckInOutScreen extends StatefulWidget {
  const CheckInOutScreen({super.key});

  @override
  State<CheckInOutScreen> createState() => _CheckInOutScreenState();
}

class _CheckInOutScreenState extends State<CheckInOutScreen> {
  final _repo = AttendanceRepository();

  SelfTodayAttendance? _data;
  List<Attendance> _history = [];
  bool _loading = true;
  bool _loadingHistory = false;
  bool _acting = false;
  String? _error;

  Position? _position;
  bool _locating = false;
  String? _autoAction; // set khi mở từ notification → tự submit sau khi GPS load

  @override
  void initState() {
    super.initState();
    _autoAction = NotificationService.instance.consumePendingAutoAction();
    _load();
    _loadLocation();
  }

  /// Đọc vị trí mới (có xin quyền). Trả null nếu tắt định vị / bị từ chối / quá thời gian.
  Future<Position?> _readPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Vị trí dùng khi bấm check-in/out: luôn đọc lại ngay lúc bấm (vị trí lúc mở màn hình
  /// có thể đã cũ). Không đọc được thì chỉ dùng lại vị trí cũ nếu chưa quá 1 phút.
  Future<Position?> _positionAtTap() async {
    setState(() => _locating = true);
    final fresh = await _readPosition();
    if (!mounted) return fresh;
    setState(() {
      if (fresh != null) _position = fresh;
      _locating = false;
    });
    if (fresh != null) return fresh;
    final cached = _position;
    if (cached != null && DateTime.now().difference(cached.timestamp).inSeconds <= 60) return cached;
    return null;
  }

  Future<void> _loadLocation() async {
    setState(() => _locating = true);
    final pos = await _readPosition();
    if (mounted) setState(() { _position = pos ?? _position; _locating = false; });
    // Mở từ notification → tự submit (dù GPS thành công hay thất bại)
    if (mounted && _autoAction != null) {
      final action = _autoAction!;
      _autoAction = null;
      if (action == 'action_check_in') {
        await _doCheckIn();
      } else if (action == 'action_check_out') {
        await _doCheckOut();
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.getSelfToday();
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
          _loadingHistory = true;
        });
      }
      unawaited(_loadHistory());
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = serverMsg(e);
          _loading = false;
          _loadingHistory = false;
        });
      }
    }
  }

  Future<void> _loadHistory() async {
    final now = DateTime.now();
    try {
      final history = (await _repo.getSelfHistory(
        year: now.year,
        month: now.month,
      ))
          .where((a) => a.checkIn != null || a.checkOut != null)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      if (!mounted) return;
      setState(() {
        _history = history;
        _loadingHistory = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _history = [];
        _loadingHistory = false;
      });
    }
  }

  Future<void> _doCheckIn() async {
    final s = AppLocalizations.of(context);
    await _runAction(
      () async {
        final pos = await _positionAtTap();
        return _repo.selfCheckIn(
            lat: pos?.latitude, lng: pos?.longitude,
            isMocked: pos?.isMocked, accuracy: pos?.accuracy);
      },
      s.checkInSuccess,
    );
  }

  Future<void> _doCheckOut() async {
    final s = AppLocalizations.of(context);
    await _runAction(
      () async {
        final pos = await _positionAtTap();
        return _repo.selfCheckOut(
            lat: pos?.latitude, lng: pos?.longitude,
            isMocked: pos?.isMocked, accuracy: pos?.accuracy);
      },
      s.checkOutSuccess,
    );
  }

  Future<void> _runAction(
    Future<SelfTodayAttendance> Function() action,
    String message,
  ) async {
    setState(() => _acting = true);
    try {
      final data = await action();
      if (!mounted) return;
      setState(() {
        _data = data;
        _acting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _acting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error),
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    if (AuthService.instance.isImpersonating) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.admin_panel_settings_outlined, size: 64, color: AppTheme.primary),
            const SizedBox(height: 16),
            Text(s.impersonatingCompanyNotice,
                style: const TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, style: const TextStyle(color: AppTheme.error)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: Text(s.retry)),
        ]),
      );
    }

    final data = _data;

    // Kiểm tra vị trí có trong phạm vi cho phép không
    final allowedLocs = data?.allowedLocations;
    final isFreeZone = allowedLocs == null;
    final isInsideZone = isFreeZone ||
        _position == null ||
        allowedLocs.any((loc) =>
            _haversineMeters(_position!.latitude, _position!.longitude,
                loc.latitude, loc.longitude) <=
            loc.radiusMeters);

    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final today =
        DateFormat('EEEE, dd/MM/yyyy', localeTag).format(DateTime.now());
    final att = data?.attendance;
    final timeFmt = DateFormat('HH:mm');
    final hasShifts = data?.shifts.isNotEmpty ?? false;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LocationMapPanel(
                    position: _position,
                    locating: _locating,
                    allowedLocations: data?.allowedLocations,
                  ),
                  const SizedBox(height: 16),
                  _TodayCard(today: today),
                  const SizedBox(height: 16),
                  if (data?.employeeName != null)
                    _InfoPanel(
                      title: data!.employeeName!,
                      subtitle: s.loggedInEmployee,
                      icon: Icons.person_outline,
                    ),
                  const SizedBox(height: 12),
                  if (hasShifts) ...[
                    for (final shift in data!.shifts) ...[
                      _ShiftPanel(shift: shift, date: data.date),
                      const SizedBox(height: 12),
                    ],
                  ] else if (data?.shift != null)
                    _ShiftPanel(shift: data!.shift!, date: data.date)
                  else
                    _MessagePanel(message: attendanceMessage(s, data?.message)),
                  if (data?.message != null &&
                      ((data?.shift != null) || hasShifts)) ...[
                    const SizedBox(height: 12),
                    _MessagePanel(message: attendanceMessage(s, data!.message)),
                  ],
                  const SizedBox(height: 16),
                  _StatusPanel(
                    checkIn: att?.checkIn != null
                        ? timeFmt.format(att!.checkIn!)
                        : '',
                    checkOut: att?.checkOut != null
                        ? timeFmt.format(att!.checkOut!)
                        : '',
                    hours: att?.workingHours != null
                        ? _formatHours(att!.workingHours!)
                        : '',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: (data?.canCheckIn ?? false) && !_acting && isInsideZone
                              ? _doCheckIn
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            minimumSize: const Size(0, 48),
                          ),
                          icon: _acting && (data?.canCheckIn ?? false)
                              ? const _ButtonSpinner()
                              : const Icon(Icons.login),
                          label: Text(s.checkInOut.split(' / ').first),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: (data?.canCheckOut ?? false) && !_acting && isInsideZone
                              ? _doCheckOut
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.orange,
                            minimumSize: const Size(0, 48),
                          ),
                          icon: _acting && (data?.canCheckOut ?? false)
                              ? const _ButtonSpinner()
                              : const Icon(Icons.logout),
                          label: Text(s.checkInOut.split(' / ').last),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _HistorySection(
                    loading: _loadingHistory,
                    records: _history,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatHours(double hours) {
    final totalMinutes = (hours * 60).round();
    final hh = totalMinutes ~/ 60;
    final mm = totalMinutes % 60;
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }
}

class _TodayCard extends StatelessWidget {
  final String today;
  const _TodayCard({required this.today});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                color: AppTheme.primary, size: 18),
            const SizedBox(width: 10),
            Text(
              today,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      );
}

class _InfoPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _InfoPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ShiftPanel extends StatelessWidget {
  final SelfShiftInfo shift;
  final DateTime? date;
  const _ShiftPanel({required this.shift, this.date});

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final today = DateTime.now();
    final isYesterday = date != null &&
        date!.year == today.subtract(const Duration(days: 1)).year &&
        date!.month == today.subtract(const Duration(days: 1)).month &&
        date!.day == today.subtract(const Duration(days: 1)).day;
    final dateLabel = isYesterday
        ? '${s.todayShift} (${date!.day}/${date!.month})'
        : s.todayShift;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateLabel,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(
            shift.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text('${shift.startTime} - ${shift.endTime}'),
          const SizedBox(height: 8),
          Text(
            '${s.checkInTime}: ${shift.checkInFrom} - ${shift.checkInTo} | ${s.checkOutTime}: ${shift.checkOutFrom} - ${shift.checkOutTo}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  final String message;
  const _MessagePanel({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.warning.withValues(alpha: 0.25)),
        ),
        child:
            Text(message, style: const TextStyle(color: AppTheme.textPrimary)),
      );
}

class _StatusPanel extends StatelessWidget {
  final String checkIn;
  final String checkOut;
  final String hours;
  const _StatusPanel({
    required this.checkIn,
    required this.checkOut,
    required this.hours,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Row(
      children: [
        _InfoTile(
          label: s.checkInTime,
          value: checkIn,
          icon: Icons.login,
          color: Colors.green,
        ),
        const SizedBox(width: 12),
        _InfoTile(
          label: s.checkOutTime,
          value: checkOut,
          icon: Icons.logout,
          color: Colors.orange,
        ),
        if (hours.isNotEmpty) ...[
          const SizedBox(width: 12),
          _InfoTile(
            label: s.workedHours,
            value: hours,
            icon: Icons.timer_outlined,
            color: AppTheme.primary,
          ),
        ],
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
}

class _HistorySection extends StatelessWidget {
  final bool loading;
  final List<Attendance> records;

  const _HistorySection({
    required this.loading,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final timeFmt = DateFormat('HH:mm');
    final dateFmt = DateFormat('EEE, dd/MM', localeTag);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.historyTitle,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                s.noHistoryThisMonth,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: records.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (_, i) {
                final a = records[i];
                return Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.event_note_outlined,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateFmt.format(a.date),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${s.checkIn}: ${a.checkIn != null ? timeFmt.format(a.checkIn!) : ''}  |  ${s.checkOut}: ${a.checkOut != null ? timeFmt.format(a.checkOut!) : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      a.status.name.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.primary),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.pow(math.sin(dLon / 2), 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

class _LocationMapPanel extends StatefulWidget {
  final Position? position;
  final bool locating;
  final List<AllowedLocation>? allowedLocations;

  const _LocationMapPanel({
    required this.position,
    required this.locating,
    this.allowedLocations,
  });

  @override
  State<_LocationMapPanel> createState() => _LocationMapPanelState();
}

class _LocationMapPanelState extends State<_LocationMapPanel> {
  final _mapCtrl = MapController();

  bool get _isFree => widget.allowedLocations == null;

  bool get _isInside {
    if (_isFree || widget.position == null) return true;
    return widget.allowedLocations!.any((loc) =>
        _haversineMeters(widget.position!.latitude, widget.position!.longitude,
            loc.latitude, loc.longitude) <=
        loc.radiusMeters);
  }

  @override
  void didUpdateWidget(_LocationMapPanel old) {
    super.didUpdateWidget(old);
    // Khi có vị trí + circles, tự fit để thấy tất cả
    if (widget.position != null && !_isFree) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
    }
  }

  void _fitBounds() {
    if (widget.position == null || _isFree) return;
    final pts = <LatLng>[
      LatLng(widget.position!.latitude, widget.position!.longitude),
      ...widget.allowedLocations!.map((l) => LatLng(l.latitude, l.longitude)),
    ];
    double minLat = pts.map((p) => p.latitude).reduce(math.min);
    double maxLat = pts.map((p) => p.latitude).reduce(math.max);
    double minLng = pts.map((p) => p.longitude).reduce(math.min);
    double maxLng = pts.map((p) => p.longitude).reduce(math.max);
    // thêm padding dựa trên radius lớn nhất
    final maxRadius = widget.allowedLocations!
        .map((l) => l.radiusMeters)
        .reduce(math.max);
    final pad = maxRadius / 111320.0 * 1.5; // ~1.5x radius thành độ
    _mapCtrl.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(minLat - pad, minLng - pad),
          LatLng(maxLat + pad, maxLng + pad),
        ),
        padding: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final inside = _isInside;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 200,
            child: widget.locating
                ? Container(
                    color: AppTheme.surface,
                    child: const Center(child: CircularProgressIndicator()),
                  )
                : widget.position == null
                    ? Container(
                        color: AppTheme.surface,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_off_outlined,
                                  size: 32, color: AppTheme.textSecondary),
                              const SizedBox(height: 8),
                              Text(s.locationUnavailable,
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary, fontSize: 13)),
                            ],
                          ),
                        ),
                      )
                    : FlutterMap(
                        mapController: _mapCtrl,
                        options: MapOptions(
                          initialCenter: LatLng(widget.position!.latitude, widget.position!.longitude),
                          initialZoom: 16,
                        ),
                        children: [
                          appTileLayer(),
                          if (!_isFree)
                            CircleLayer(
                              circles: widget.allowedLocations!.map((loc) {
                                final dist = _haversineMeters(
                                    widget.position!.latitude, widget.position!.longitude,
                                    loc.latitude, loc.longitude);
                                final inThis = dist <= loc.radiusMeters;
                                return CircleMarker(
                                  point: LatLng(loc.latitude, loc.longitude),
                                  radius: loc.radiusMeters.toDouble(),
                                  useRadiusInMeter: true,
                                  color: inThis
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : Colors.red.withValues(alpha: 0.15),
                                  borderColor: inThis ? Colors.green : Colors.red,
                                  borderStrokeWidth: 2,
                                );
                              }).toList(),
                            ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(widget.position!.latitude, widget.position!.longitude),
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.location_pin,
                                    color: AppTheme.error, size: 40),
                              ),
                            ],
                          ),
                          // Nút fit bounds
                          if (!_isFree)
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: FloatingActionButton.small(
                                  heroTag: 'fitBounds',
                                  onPressed: _fitBounds,
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppTheme.primary,
                                  child: const Icon(Icons.fit_screen, size: 18),
                                ),
                              ),
                            ),
                        ],
                      ),
          ),
        ),
        // Banner thông báo ngoài phạm vi
        if (!_isFree && widget.position != null && !inside)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: AppTheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(s.outsideAllowedZone,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.error)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

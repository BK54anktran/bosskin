import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/repositories/company_setting_repository.dart';
import 'package:bosskin/l10n/app_localizations.dart';
import '../../widgets/location_picker_field.dart';

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  final _repo = CompanySettingRepository();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool _dayNightMode = false;
  bool _otEnabled = true;
  TimeOfDay _dayStart = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _dayEnd = const TimeOfDay(hour: 22, minute: 0);
  final _hoursPerDayCtrl = TextEditingController(text: '8');
  final _standardWorkDaysCtrl = TextEditingController(text: '22');
  final _cutoffDayCtrl = TextEditingController(text: '1');

  bool _locationCheckEnabled = false;
  double? _checkInLat;
  double? _checkInLng;
  int _checkInRadius = 100;

  final _checkInBeforeCtrl  = TextEditingController(text: '00:30');
  final _checkInAfterCtrl   = TextEditingController(text: '00:30');
  final _checkOutBeforeCtrl = TextEditingController(text: '00:30');
  final _checkOutAfterCtrl  = TextEditingController(text: '00:30');
  final _checkInToleranceCtrl = TextEditingController();
  final _checkOutToleranceCtrl = TextEditingController();
  int? _roundCheckInMinutes;
  int? _roundCheckOutMinutes;
  int? _roundWorkMinutes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hoursPerDayCtrl.dispose();
    _standardWorkDaysCtrl.dispose();
    _cutoffDayCtrl.dispose();
    _checkInBeforeCtrl.dispose();
    _checkInAfterCtrl.dispose();
    _checkOutBeforeCtrl.dispose();
    _checkOutAfterCtrl.dispose();
    _checkInToleranceCtrl.dispose();
    _checkOutToleranceCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.get();
      final attendance = Map<String, dynamic>.from(data['attendance'] as Map);
      final leaves = Map<String, dynamic>.from(data['leaves'] as Map);
      if (!mounted) return;
      setState(() {
        _dayNightMode = attendance['dayNightMode'] == true;
        _otEnabled = attendance['otEnabled'] == true;
        _dayStart = _parseTime(attendance['dayStartTime'] as String?) ?? const TimeOfDay(hour: 6, minute: 0);
        _dayEnd = _parseTime(attendance['dayEndTime'] as String?) ?? const TimeOfDay(hour: 22, minute: 0);
        _hoursPerDayCtrl.text = (leaves['hoursPerDay'] ?? 8).toString();
        final payroll = data['payroll'] as Map<String, dynamic>?;
        _standardWorkDaysCtrl.text = ((payroll?['standardWorkDays'] as num?)?.toInt() ?? 22).toString();
        _cutoffDayCtrl.text = ((payroll?['payrollCutoffDay'] as num?)?.toInt() ?? 1).toString();
        _locationCheckEnabled = attendance['locationCheckEnabled'] == true;
        _checkInLat = (attendance['checkInLatitude'] as num?)?.toDouble();
        _checkInLng = (attendance['checkInLongitude'] as num?)?.toDouble();
        _checkInRadius = (attendance['checkInRadiusMeters'] as num?)?.toInt() ?? 100;
        _checkInBeforeCtrl.text  = _minutesToHhmm((attendance['checkInBeforeMinutes']  as num?)?.toInt() ?? 30);
        _checkInAfterCtrl.text   = _minutesToHhmm((attendance['checkInAfterMinutes']   as num?)?.toInt() ?? 30);
        _checkOutBeforeCtrl.text = _minutesToHhmm((attendance['checkOutBeforeMinutes'] as num?)?.toInt() ?? 30);
        _checkOutAfterCtrl.text  = _minutesToHhmm((attendance['checkOutAfterMinutes']  as num?)?.toInt() ?? 30);
        _checkInToleranceCtrl.text = ((attendance['checkInToleranceMinutes'] as num?)?.toInt() ?? '').toString();
        _checkOutToleranceCtrl.text = ((attendance['checkOutToleranceMinutes'] as num?)?.toInt() ?? '').toString();
        _roundCheckInMinutes = (attendance['roundingCheckInMinutes'] as num?)?.toInt();
        _roundCheckOutMinutes = (attendance['roundingCheckOutMinutes'] as num?)?.toInt();
        _roundWorkMinutes = (attendance['roundingWorkMinutes'] as num?)?.toInt();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = serverMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Chuyển số phút -> "HH:mm"
  String _minutesToHhmm(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  // Chuyển "HH:mm" -> số phút, null nếu không hợp lệ
  int? _hhmmToMinutes(String s) {
    final parts = s.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || m < 0 || m >= 60) return null;
    return h * 60 + m;
  }

  TimeOfDay? _parseTime(String? s) {
    if (s == null) return null;
    final parts = s.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _dayStart : _dayEnd,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _dayStart = picked;
      } else {
        _dayEnd = picked;
      }
    });
  }

  Future<void> _save() async {
    final s = AppLocalizations.of(context);
    final hours = double.tryParse(_hoursPerDayCtrl.text.trim());
    if (hours == null || hours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.leaveAmountGtZero), backgroundColor: AppTheme.error),
      );
      return;
    }
    final ciBefore  = _hhmmToMinutes(_checkInBeforeCtrl.text);
    final ciAfter   = _hhmmToMinutes(_checkInAfterCtrl.text);
    final coBefore  = _hhmmToMinutes(_checkOutBeforeCtrl.text);
    final coAfter   = _hhmmToMinutes(_checkOutAfterCtrl.text);
    if (ciBefore == null || ciAfter == null || coBefore == null || coAfter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.invalidTimeFormat), backgroundColor: AppTheme.error),
      );
      return;
    }
    final ciTolText = _checkInToleranceCtrl.text.trim();
    final coTolText = _checkOutToleranceCtrl.text.trim();
    final ciTol = ciTolText.isEmpty ? null : int.tryParse(ciTolText);
    final coTol = coTolText.isEmpty ? null : int.tryParse(coTolText);
    if ((ciTolText.isNotEmpty && (ciTol == null || ciTol < 0)) ||
        (coTolText.isNotEmpty && (coTol == null || coTol < 0))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dung sai phải là số >= 0'), backgroundColor: AppTheme.error),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _repo.update({
        'attendance': {
          'dayNightMode': _dayNightMode,
          'otEnabled': _otEnabled,
          'dayStartTime': _formatTime(_dayStart),
          'dayEndTime': _formatTime(_dayEnd),
          'locationCheckEnabled': _locationCheckEnabled,
          'checkInLatitude': _checkInLat,
          'checkInLongitude': _checkInLng,
          'checkInRadiusMeters': _checkInRadius,
          'checkInBeforeMinutes': ciBefore,
          'checkInAfterMinutes': ciAfter,
          'checkOutBeforeMinutes': coBefore,
          'checkOutAfterMinutes': coAfter,
          if (ciTol != null) 'checkInToleranceMinutes': ciTol,
          if (coTol != null) 'checkOutToleranceMinutes': coTol,
          if (_roundCheckInMinutes != null) 'roundingCheckInMinutes': _roundCheckInMinutes,
          if (_roundCheckOutMinutes != null) 'roundingCheckOutMinutes': _roundCheckOutMinutes,
          if (_roundWorkMinutes != null) 'roundingWorkMinutes': _roundWorkMinutes,
        },
        'leaves': {
          'hoursPerDay': hours,
        },
        'payroll': {
          'standardWorkDays': int.tryParse(_standardWorkDaysCtrl.text.trim()) ?? 22,
          'payrollCutoffDay': int.tryParse(_cutoffDayCtrl.text.trim()) ?? 1,
        },
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.saveSuccess), backgroundColor: AppTheme.secondary),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: AppTheme.error)),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.companySettingAttendanceTitle,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _dayNightMode,
                            onChanged: (v) => setState(() => _dayNightMode = v),
                            title: Text(s.companySettingDayNightMode),
                          ),
                          if (_dayNightMode) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: _TimePickerTile(
                                    label: s.companySettingDayFrom,
                                    time: _dayStart,
                                    onTap: () => _pickTime(true),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _TimePickerTile(
                                    label: s.companySettingDayTo,
                                    time: _dayEnd,
                                    onTap: () => _pickTime(false),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 6, bottom: 2),
                              child: Text(
                                s.companySettingNightSummary(_formatTime(_dayEnd), _formatTime(_dayStart)),
                                style: const TextStyle(fontSize: 12, color: Color(0xFF607D8B)),
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _otEnabled,
                            onChanged: (v) => setState(() => _otEnabled = v),
                            title: Text(s.companySettingOtMode),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.companySettingLeaveTitle,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _hoursPerDayCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(labelText: s.leaveHoursPerDay),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.payrollSettings, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _standardWorkDaysCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: s.standardWorkDaysLabel,
                              suffixText: s.daysSuffix,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _cutoffDayCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: s.payrollCutoffDayLabel,
                              suffixText: s.daysSuffix,
                              helperText: '1–28. VD: 25 → kỳ tháng 5 = 25/4–24/5',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.checkInRadius,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _locationCheckEnabled,
                            onChanged: (v) => setState(() => _locationCheckEnabled = v),
                            title: Text(s.locationCheckEnabled),
                          ),
                          if (_locationCheckEnabled) ...[
                            const SizedBox(height: 8),
                            LocationPickerField(
                              latitude: _checkInLat,
                              longitude: _checkInLng,
                              radiusMeters: _checkInRadius,
                              onChanged: (lat, lng, r) => setState(() {
                                _checkInLat = lat;
                                _checkInLng = lng;
                                _checkInRadius = r;
                              }),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.companySettingAttendanceWindowTitle,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _checkInBeforeCtrl,
                                  decoration: InputDecoration(labelText: s.companySettingCheckInBefore),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _checkInAfterCtrl,
                                  decoration: InputDecoration(labelText: s.companySettingCheckInAfter),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _checkOutBeforeCtrl,
                                  decoration: InputDecoration(labelText: s.companySettingCheckOutBefore),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _checkOutAfterCtrl,
                                  decoration: InputDecoration(labelText: s.companySettingCheckOutAfter),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _checkInToleranceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Dung sai check-in (phút)'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _checkOutToleranceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Dung sai check-out (phút)'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int?>(
                                  initialValue: _roundCheckInMinutes,
                                  decoration: const InputDecoration(labelText: 'Làm tròn check-in'),
                                  items: const [null, 1, 5, 15, 30, 60]
                                      .map((v) => DropdownMenuItem<int?>(
                                            value: v,
                                            child: Text(v == null ? 'Không áp dụng' : '$v phút'),
                                          ))
                                      .toList(),
                                  onChanged: (v) => setState(() => _roundCheckInMinutes = v),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<int?>(
                                  initialValue: _roundCheckOutMinutes,
                                  decoration: const InputDecoration(labelText: 'Làm tròn check-out'),
                                  items: const [null, 1, 5, 15, 30, 60]
                                      .map((v) => DropdownMenuItem<int?>(
                                            value: v,
                                            child: Text(v == null ? 'Không áp dụng' : '$v phút'),
                                          ))
                                      .toList(),
                                  onChanged: (v) => setState(() => _roundCheckOutMinutes = v),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int?>(
                            initialValue: _roundWorkMinutes,
                            decoration: const InputDecoration(labelText: 'Làm tròn giờ ngày/đêm/OT'),
                            items: const [null, 1, 5, 15, 30, 60]
                                .map((v) => DropdownMenuItem<int?>(
                                      value: v,
                                      child: Text(v == null ? 'Không áp dụng' : '$v phút'),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _roundWorkMinutes = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(s.save),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimePickerTile({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFBDBDBD)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 18, color: Color(0xFF607D8B)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF607D8B))),
                Text('$hh:$mm', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

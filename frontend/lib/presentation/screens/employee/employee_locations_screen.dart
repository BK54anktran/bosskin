import 'package:flutter/material.dart';
import 'package:bosskin/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../data/services/api_service.dart';
import '../../widgets/location_picker_field.dart';

class EmployeeLocationsScreen extends StatefulWidget {
  final int employeeId;
  final String employeeName;

  const EmployeeLocationsScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<EmployeeLocationsScreen> createState() => _EmployeeLocationsScreenState();
}

class _EmployeeLocationsScreenState extends State<EmployeeLocationsScreen> {
  final _api = ApiService.instance;
  List<Map<String, dynamic>> _locations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.get<List<Map<String, dynamic>>>(
        '/employees/${widget.employeeId}/locations',
        (d) => (d as List).map((e) => Map<String, dynamic>.from(e)).toList(),
      );
      if (mounted) setState(() { _locations = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = serverMsg(e); _loading = false; });
    }
  }

  Future<void> _delete(int locationId) async {
    try {
      await _api.delete('/employees/${widget.employeeId}/locations/$locationId');
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _openForm({Map<String, dynamic>? loc}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _LocationFormDialog(
        employeeId: widget.employeeId,
        existing: loc,
      ),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${s.checkInRadius} — ${widget.employeeName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: s.add,
            onPressed: () => _openForm(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.error)))
              : _locations.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.location_off_outlined,
                            size: 48, color: AppTheme.textSecondary),
                        const SizedBox(height: 12),
                        Text(s.noLocations,
                            style: TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => _openForm(),
                          icon: const Icon(Icons.add),
                          label: Text(s.addLocation),
                        ),
                      ]),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _locations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final loc = _locations[i];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.location_pin,
                                color: AppTheme.error),
                            title: Text(loc['name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${(loc['latitude'] as num?)?.toStringAsFixed(5) ?? ''}, '
                              '${(loc['longitude'] as num?)?.toStringAsFixed(5) ?? ''}  '
                              '· ${loc['radiusMeters']}m',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () => _openForm(loc: loc),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18, color: AppTheme.error),
                                  onPressed: () => _confirmDelete(loc),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> loc) async {
    final s = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.delete),
        content: Text('${s.deleteLocationConfirm} "${loc['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok == true) _delete(loc['id'] as int);
  }
}

class _LocationFormDialog extends StatefulWidget {
  final int employeeId;
  final Map<String, dynamic>? existing;

  const _LocationFormDialog({required this.employeeId, this.existing});

  @override
  State<_LocationFormDialog> createState() => _LocationFormDialogState();
}

class _LocationFormDialogState extends State<_LocationFormDialog> {
  final _api = ApiService.instance;
  final _nameCtrl = TextEditingController();
  double? _lat;
  double? _lng;
  int _radius = 100;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e['name'] ?? '';
      _lat = (e['latitude'] as num?)?.toDouble();
      _lng = (e['longitude'] as num?)?.toDouble();
      _radius = (e['radiusMeters'] as num?)?.toInt() ?? 100;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = AppLocalizations.of(context);
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.requiredField), backgroundColor: AppTheme.error),
      );
      return;
    }
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.locationRequired), backgroundColor: AppTheme.error),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'name': _nameCtrl.text.trim(),
        'latitude': _lat,
        'longitude': _lng,
        'radiusMeters': _radius,
      };
      if (widget.existing == null) {
        await _api.post<Map<String, dynamic>>(
            '/employees/${widget.employeeId}/locations',
            (d) => Map<String, dynamic>.from(d as Map),
            body);
      } else {
        await _api.put<Map<String, dynamic>>(
            '/employees/${widget.employeeId}/locations/${widget.existing!['id']}',
            (d) => Map<String, dynamic>.from(d as Map),
            body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? s.editLocation : s.addLocation),
      content: SizedBox(
        width: 480,
        height: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: s.locationName,
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              LocationPickerField(
                latitude: _lat,
                longitude: _lng,
                radiusMeters: _radius,
                onChanged: (lat, lng, r) => setState(() {
                  _lat = lat;
                  _lng = lng;
                  _radius = r;
                }),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(isEdit ? s.save : s.add),
        ),
      ],
    );
  }
}

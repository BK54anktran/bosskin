import 'package:bosskin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../auth/force_change_password_screen.dart' show isStrongPassword;
import '../../../core/utils/error_utils.dart';
import 'package:intl/intl.dart';
import '../../../data/models/department_model.dart';
import '../../../data/models/employee.dart';
import '../../../data/models/salary_grade.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../data/repositories/salary_grade_repository.dart';
import '../../../data/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/date_field.dart';
import '../../widgets/manager_dropdown.dart';
import '../../widgets/department_picker_field.dart';
import 'employee_locations_screen.dart';

class EmployeeFormScreen extends StatefulWidget {
  final Employee? employee;
  final List<DepartmentFlat> departments;
  final List<SalaryGrade> initialGrades;

  const EmployeeFormScreen({
    super.key,
    this.employee,
    required this.departments,
    this.initialGrades = const [],
  });

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _form = GlobalKey<FormState>();
  final _repo = EmployeeRepository();
  final _gradeRepo = SalaryGradeRepository();

  late final TextEditingController _fullName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _password;
  late final TextEditingController _passwordConfirm;
  late final TextEditingController _address;
  late final TextEditingController _idCard;
  late final TextEditingController _bankAccount;
  late final TextEditingController _bankName;
  late final TextEditingController _contractSalary;
  // Bước M — thuế / bảo hiểm
  late final TextEditingController _taxCode;
  late final TextEditingController _socialInsuranceNo;
  late final TextEditingController _healthInsurancePlace;
  DateTime? _insuranceJoinDate;

  Gender _gender = Gender.male;
  DateTime? _dob;
  DateTime _joinDate = DateTime.now();
  int? _deptId;
  int? _positionId;
  int? _gradeId;
  int? _managerId;

  List<Map<String, dynamic>> _positions = [];
  List<SalaryGrade> _grades = [];
  bool _loadingPos = false;
  bool _saving = false;

  bool get _isEdit => widget.employee != null;

  /// Bước M: có trường đang hiển thị dạng che (thiếu quyền EMPLOYEE_SENSITIVE_VIEW).
  bool get _hasMaskedValue {
    final e = widget.employee;
    if (e == null) return false;
    return [e.identityCard, e.bankAccount, e.taxCode, e.socialInsuranceNo].any((v) => (v ?? '').contains('*'));
  }

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _fullName = TextEditingController(text: e?.fullName ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    _password = TextEditingController();
    _passwordConfirm = TextEditingController();
    _phone = TextEditingController(text: e?.phone ?? '');
    _address = TextEditingController(text: e?.address ?? '');
    _idCard = TextEditingController(text: e?.identityCard ?? '');
    _bankAccount = TextEditingController(text: e?.bankAccount ?? '');
    _bankName = TextEditingController(text: e?.bankName ?? '');
    _taxCode = TextEditingController(text: e?.taxCode ?? '');
    _socialInsuranceNo = TextEditingController(text: e?.socialInsuranceNo ?? '');
    _healthInsurancePlace = TextEditingController(text: e?.healthInsurancePlace ?? '');
    _insuranceJoinDate = e?.insuranceJoinDate;
    _contractSalary = TextEditingController(
      text: e?.contractSalary != null ? e!.contractSalary!.toStringAsFixed(0) : '',
    );
    if (widget.initialGrades.isNotEmpty) {
      _grades = widget.initialGrades;
    }
    if (e != null) {
      _gender = e.gender;
      _dob = e.dateOfBirth;
      _joinDate = e.joinDate;
      _deptId = e.departmentId;
      _positionId = e.positionId;
      _gradeId = e.salaryGradeId;
      _managerId = e.managerId;
      _loadPositions(e.departmentId);
    }
    if (widget.initialGrades.isEmpty) _loadGrades();
  }

  bool get _currentGradeMissing {
    final id = widget.employee?.salaryGradeId;
    return id != null && !_grades.any((g) => g.id == id);
  }

  Future<void> _loadGrades() async {
    try {
      final list = await _gradeRepo.getAll();
      if (mounted) setState(() => _grades = list);
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in [
      _fullName,
      _email,
      _password,
      _passwordConfirm,
      _phone,
      _address,
      _idCard,
      _bankAccount,
      _bankName,
      _contractSalary,
      _taxCode,
      _socialInsuranceNo,
      _healthInsurancePlace,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPositions(int deptId, {bool resetPosition = false}) async {
    setState(() {
      _loadingPos = true;
      if (resetPosition) _positionId = null;
    });
    try {
      final res = await ApiService.instance.dio
          .get('/positions', queryParameters: {'departmentId': deptId});
      if (!mounted) return;
      final positions = List<Map<String, dynamic>>.from(res.data);
      setState(() {
        _positions = positions;
        _loadingPos = false;
        // Giữ positionId nếu nó tồn tại trong danh sách mới
        if (_positionId != null &&
            !positions.any((p) => p['id'] == _positionId)) {
          _positionId = null;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPos = false);
    }
  }

  Future<void> _pickDate(bool isDob) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isDob ? (_dob ?? DateTime(1990)) : _joinDate,
      firstDate: isDob ? DateTime(1950) : DateTime(2000),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      isDob ? _dob = picked : _joinDate = picked;
    });
  }

  Future<void> _save() async {
    final s = AppLocalizations.of(context);
    if (!_form.currentState!.validate()) return;
    if (_deptId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.pleaseChooseDepartment)),
      );
      return;
    }
    setState(() => _saving = true);
    final data = {
      'fullName': _fullName.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'gender': _gender.name.toUpperCase(),
      'dateOfBirth':
          _dob != null ? DateFormat('yyyy-MM-dd').format(_dob!) : null,
      'joinDate': DateFormat('yyyy-MM-dd').format(_joinDate),
      'departmentId': _deptId,
      'positionId': _positionId,
      'salaryGradeId': _gradeId,
      'managerId': _managerId,
      'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
      'identityCard': _idCard.text.trim().isEmpty ? null : _idCard.text.trim(),
      'bankAccount':
          _bankAccount.text.trim().isEmpty ? null : _bankAccount.text.trim(),
      'bankName': _bankName.text.trim().isEmpty ? null : _bankName.text.trim(),
      // Bước M: chuỗi rỗng = xoá; bản che (****1234) gửi lại nguyên thì backend giữ giá trị cũ
      'taxCode': _taxCode.text.trim(),
      'socialInsuranceNo': _socialInsuranceNo.text.trim(),
      'healthInsurancePlace': _healthInsurancePlace.text.trim(),
      'insuranceJoinDate':
          _insuranceJoinDate != null ? DateFormat('yyyy-MM-dd').format(_insuranceJoinDate!) : null,
      'contractSalary': _contractSalary.text.trim().isEmpty
          ? null
          : double.tryParse(_contractSalary.text.trim().replaceAll(',', '')),
    };
    if (!_isEdit) {
      data['password'] = _password.text;
    }
    try {
      if (_isEdit) {
        await _repo.update(widget.employee!.id, data);
      } else {
        await _repo.create(data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMsg(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? s.editInfoAdminTitle : s.addEmployee),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_isEdit ? s.save : s.create),
            ),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _section(s.basicInfo, [
              _row([
                _field(TextFormField(
                  controller: _fullName,
                  decoration: InputDecoration(labelText: '${s.fullName} *'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? s.requiredField : null,
                )),
                _field(TextFormField(
                  controller: _email,
                  decoration: InputDecoration(labelText: '${s.workEmail} *'),
                  enabled: !_isEdit,
                  validator: (v) =>
                      v == null || !v.contains('@') ? s.invalidEmail : null,
                )),
              ]),
              if (!_isEdit) ...[
                const SizedBox(height: 12),
                _row([
                  _field(TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: InputDecoration(labelText: s.passwordLabel),
                    validator: (v) {
                      if (_isEdit) return null;
                      if (v == null || !isStrongPassword(v)) return s.passwordPolicyHint;
                      return null;
                    },
                  )),
                  _field(TextFormField(
                    controller: _passwordConfirm,
                    obscureText: true,
                    decoration:
                        InputDecoration(labelText: s.confirmPasswordLabel),
                    validator: (v) {
                      if (_isEdit) return null;
                      if (v == null || v.isEmpty) return s.requiredField;
                      if (v != _password.text) return s.passwordMismatch;
                      return null;
                    },
                  )),
                ]),
              ],
              _row([
                _field(TextFormField(
                  controller: _phone,
                  decoration: InputDecoration(labelText: s.phone),
                  keyboardType: TextInputType.phone,
                )),
                _field(DropdownButtonFormField<Gender>(
                  initialValue: _gender,
                  borderRadius: BorderRadius.circular(12),
                  decoration: InputDecoration(labelText: '${s.gender} *'),
                  items: [
                    DropdownMenuItem(
                        value: Gender.male, child: Text(s.genderMale)),
                    DropdownMenuItem(
                        value: Gender.female, child: Text(s.genderFemale)),
                    DropdownMenuItem(
                        value: Gender.other, child: Text(s.genderOther)),
                  ],
                  onChanged: (v) => setState(() => _gender = v!),
                )),
              ]),
              _row([
                _field(_datePicker(s.dateOfBirth, _dob, () => _pickDate(true))),
                _field(_datePicker(
                    '${s.joinDate} *', _joinDate, () => _pickDate(false))),
              ]),
            ]),
            const SizedBox(height: 28),
            _section(s.departmentAndPosition, [
              _row([
                _field(DepartmentPickerField(
                  departments: widget.departments,
                  value: _deptId,
                  label: '${s.department} *',
                  onChanged: (v) {
                    setState(() => _deptId = v);
                    if (v != null) _loadPositions(v, resetPosition: true);
                  },
                )),
                _field(_loadingPos
                    ? InputDecorator(
                        decoration:
                            InputDecoration(labelText: s.position),
                        child: const LinearProgressIndicator(),
                      )
                    : DropdownButtonFormField<int>(
                        initialValue: _positions.any((p) => p['id'] == _positionId)
                            ? _positionId
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        decoration: InputDecoration(labelText: s.position),
                        items: _positions
                            .map((p) => DropdownMenuItem<int>(
                                  value: p['id'] as int,
                                  child: Text(p['name'] as String),
                                ))
                            .toList(),
                        onChanged: _deptId == null
                            ? null
                            : (v) => setState(() => _positionId = v),
                      )),
              ]),
              _row([
                _field(ManagerDropdown(
                  value: _managerId,
                  excludeEmployeeId: widget.employee?.id,
                  onChanged: (v) => setState(() => _managerId = v),
                )),
              ]),
            ]),
            const SizedBox(height: 28),
            _section(s.salaryGrade, [
              _row([
                _field(DropdownButtonFormField<int>(
                  // initialValue chỉ đọc ở lần dựng đầu: danh sách bậc tải xong sau đó thì phải dựng lại ô,
                  // không thì ô kẹt ở "—" dù NV có bậc (lúc hiện lúc không tuỳ tốc độ mạng)
                  key: ValueKey('grade-${_grades.length}'),
                  initialValue: _grades.any((g) => g.id == _gradeId) ||
                          (_currentGradeMissing && _gradeId == widget.employee!.salaryGradeId)
                      ? _gradeId
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  decoration: InputDecoration(labelText: s.salaryGrade),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('—')),
                    // Bậc hiện tại của NV không có trong danh sách (chưa tải xong / không có quyền xem bậc lương):
                    // vẫn hiện theo mã + tên trả kèm nhân viên
                    if (_currentGradeMissing)
                      DropdownMenuItem<int>(
                        value: widget.employee!.salaryGradeId,
                        child: Text('${widget.employee!.salaryGradeCode ?? ''} · ${widget.employee!.salaryGradeName ?? ''}'),
                      ),
                    ..._grades.map((g) => DropdownMenuItem<int>(
                          value: g.id,
                          child: Text('${g.code} · ${g.name}'),
                        )),
                  ],
                  onChanged: (v) => setState(() => _gradeId = v),
                )),
                _field(TextFormField(
                  controller: _contractSalary,
                  decoration: InputDecoration(
                    labelText: s.empContractSalaryVnd,
                    hintText: s.empContractSalaryHint,
                  ),
                  keyboardType: TextInputType.number,
                )),
              ]),
            ]),
            const SizedBox(height: 28),
            _section(s.additionalInfo, [
              TextFormField(
                controller: _address,
                decoration: InputDecoration(labelText: s.address),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _row([
                _field(TextFormField(
                  controller: _idCard,
                  decoration: InputDecoration(labelText: s.identityCardLabel),
                )),
                _field(const SizedBox()),
              ]),
            ]),
            const SizedBox(height: 28),
            _section(s.taxInsuranceInfo, [
              if (_hasMaskedValue)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(s.sensitiveMaskedHint,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ),
              _row([
                _field(TextFormField(
                  controller: _taxCode,
                  maxLength: 20,
                  decoration: InputDecoration(labelText: s.empTaxCode, counterText: ''),
                )),
                _field(TextFormField(
                  controller: _socialInsuranceNo,
                  maxLength: 20,
                  decoration: InputDecoration(labelText: s.empSocialInsuranceNo, counterText: ''),
                )),
              ]),
              const SizedBox(height: 12),
              _row([
                _field(TextFormField(
                  controller: _healthInsurancePlace,
                  decoration: InputDecoration(labelText: s.empHealthInsurancePlace),
                )),
                _field(DateField(
                  label: s.empInsuranceJoinDate,
                  value: _insuranceJoinDate,
                  clearable: false,
                  onChanged: (d) => setState(() => _insuranceJoinDate = d),
                )),
              ]),
            ]),
            const SizedBox(height: 28),
            _section(s.bankInfo, [
              _row([
                _field(TextFormField(
                  controller: _bankAccount,
                  decoration: InputDecoration(labelText: s.bankAccountLabel),
                )),
                _field(TextFormField(
                  controller: _bankName,
                  decoration: InputDecoration(labelText: s.bankNameLabel),
                )),
              ]),
            ]),
            if (widget.employee != null) ...[
              const SizedBox(height: 28),
              _section(s.checkInRadius, [
                _EmployeeLocationsPreview(
                  employeeId: widget.employee!.id,
                  employeeName: widget.employee!.fullName,
                ),
                const SizedBox(height: 12),
                _DeviceBindingTile(employee: widget.employee!),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(height: 16),
          ...children,
        ],
      );

  Widget _row(List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: children
              .expand((w) => [Expanded(child: w), const SizedBox(width: 16)])
              .toList()
            ..removeLast(),
        ),
      );

  Expanded _field(Widget child) => Expanded(child: child);

  Widget _datePicker(String label, DateTime? value, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
              labelText: label,
              suffixIcon: const Icon(Icons.calendar_today, size: 18)),
          child: Text(
            value != null ? DateFormat('dd/MM/yyyy').format(value) : '—',
            style: TextStyle(color: value != null ? null : AppTheme.textMuted),
          ),
        ),
      );
}

/// Thiết bị chấm công đã gắn + nút gỡ (khi nhân viên đổi máy).
class _DeviceBindingTile extends StatefulWidget {
  final Employee employee;
  const _DeviceBindingTile({required this.employee});

  @override
  State<_DeviceBindingTile> createState() => _DeviceBindingTileState();
}

class _DeviceBindingTileState extends State<_DeviceBindingTile> {
  late bool _bound = widget.employee.deviceBound;
  bool _busy = false;

  Future<void> _unbind() async {
    final s = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ApiService.instance.dio.delete('/employees/${widget.employee.id}/device');
      if (!mounted) return;
      setState(() => _bound = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.deviceUnbound)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(serverMsg(e)), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final at = widget.employee.boundDeviceAt;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(_bound ? Icons.phonelink_lock : Icons.phonelink_off,
          color: _bound ? AppTheme.primary : AppTheme.textSecondary, size: 20),
      title: Text(_bound ? s.deviceBoundLabel : s.deviceNotBoundLabel, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        _bound && at != null ? s.deviceBoundSince(DateFormat('dd/MM/yyyy HH:mm').format(at)) : s.deviceBindingHint,
        style: const TextStyle(fontSize: 11),
      ),
      trailing: _bound
          ? OutlinedButton(onPressed: _busy ? null : _unbind, child: Text(s.deviceUnbind))
          : null,
    );
  }
}

class _EmployeeLocationsPreview extends StatefulWidget {
  final int employeeId;
  final String employeeName;

  const _EmployeeLocationsPreview({
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<_EmployeeLocationsPreview> createState() =>
      _EmployeeLocationsPreviewState();
}

class _EmployeeLocationsPreviewState
    extends State<_EmployeeLocationsPreview> {
  final _api = ApiService.instance;
  List<Map<String, dynamic>> _locations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _api.get<List<Map<String, dynamic>>>(
        '/employees/${widget.employeeId}/locations',
        (d) => (d as List).map((e) => Map<String, dynamic>.from(e)).toList(),
      );
      if (mounted) setState(() => _locations = list);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._locations.map((loc) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_pin,
                  color: AppTheme.error, size: 20),
              title: Text(loc['name'] ?? '',
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                '${(loc['latitude'] as num?)?.toStringAsFixed(5) ?? ''}, '
                '${(loc['longitude'] as num?)?.toStringAsFixed(5) ?? ''}  '
                '· ${loc['radiusMeters']}m',
                style: const TextStyle(fontSize: 11),
              ),
            )),
        OutlinedButton.icon(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EmployeeLocationsScreen(
                  employeeId: widget.employeeId,
                  employeeName: widget.employeeName,
                ),
              ),
            );
            _load();
          },
          icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
          label: Text(_locations.isEmpty ? s.addLocation : s.editLocation),
        ),
      ],
    );
  }
}

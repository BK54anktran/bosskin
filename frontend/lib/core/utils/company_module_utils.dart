import 'package:bosskin/l10n/app_localizations.dart';

/// V24: gói chức năng của công ty (cùng thứ tự với backend core/CompanyModules.ALL).
const List<String> companyModuleKeys = ['ATTENDANCE', 'SHIFT', 'LEAVE', 'PAYROLL', 'CONTRACT', 'DOCUMENT', 'REPORT'];

/// Gói → gói phải bật kèm (chấm công dựa trên phân ca).
const Map<String, String> companyModuleRequires = {'ATTENDANCE': 'SHIFT'};

String companyModuleLabel(AppLocalizations s, String key) => switch (key) {
      'ATTENDANCE' => s.companyModuleAttendance,
      'SHIFT' => s.companyModuleShift,
      'LEAVE' => s.companyModuleLeave,
      'PAYROLL' => s.companyModulePayroll,
      'CONTRACT' => s.companyModuleContract,
      'DOCUMENT' => s.companyModuleDocument,
      'REPORT' => s.companyModuleReport,
      _ => key,
    };

/// Bật / tắt một gói, giữ ràng buộc: bật gói thì bật gói nó cần; tắt gói thì tắt gói cần nó.
void toggleCompanyModule(Set<String> modules, String key, bool on) {
  if (on) {
    modules.add(key);
    final needs = companyModuleRequires[key];
    if (needs != null) modules.add(needs);
  } else {
    modules.remove(key);
    companyModuleRequires.forEach((m, needs) {
      if (needs == key) modules.remove(m);
    });
  }
}

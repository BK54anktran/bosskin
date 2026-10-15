import 'package:bosskin/l10n/app_localizations.dart';

/// V26: tính năng của công ty (khớp backend core/CompanyFeatures.CATALOG — `tools/ci/check_features.py` kiểm hai bên cùng danh sách).
class CompanyFeatureDef {
  final String code;
  final String group;
  final List<String> requires;
  const CompanyFeatureDef(this.code, this.group, [this.requires = const []]);
}

const List<CompanyFeatureDef> companyFeatureCatalog = [
  CompanyFeatureDef('ATT_SHEET', 'ATTENDANCE'),
  CompanyFeatureDef('ATT_SELF', 'ATTENDANCE', ['ATT_SHEET']),
  CompanyFeatureDef('ATT_GEOFENCE', 'ATTENDANCE', ['ATT_SELF']),
  CompanyFeatureDef('ATT_DEVICE', 'ATTENDANCE', ['ATT_SELF']),
  CompanyFeatureDef('ATT_NOSHIFT', 'ATTENDANCE', ['ATT_SELF']),
  CompanyFeatureDef('ATT_REQUEST', 'ATTENDANCE', ['ATT_SHEET']),
  CompanyFeatureDef('SHIFT_BASIC', 'SHIFT'),
  CompanyFeatureDef('SHIFT_ADVANCED', 'SHIFT', ['SHIFT_BASIC']),
  CompanyFeatureDef('SHIFT_ROTATION', 'SHIFT', ['SHIFT_BASIC']),
  CompanyFeatureDef('SHIFT_SWAP', 'SHIFT', ['SHIFT_BASIC']),
  CompanyFeatureDef('SHIFT_REGISTRATION', 'SHIFT', ['SHIFT_BASIC']),
  CompanyFeatureDef('SHIFT_REMINDER', 'SHIFT', ['SHIFT_BASIC']),
  CompanyFeatureDef('CAL_WORKCAL', 'CALENDAR'),
  CompanyFeatureDef('CAL_HOLIDAY', 'CALENDAR'),
  CompanyFeatureDef('LEAVE_BASIC', 'LEAVE'),
  CompanyFeatureDef('LEAVE_BALANCE', 'LEAVE', ['LEAVE_BASIC']),
  CompanyFeatureDef('LEAVE_ACCRUAL', 'LEAVE', ['LEAVE_BALANCE']),
  CompanyFeatureDef('PAY_BASIC', 'PAYROLL'),
  CompanyFeatureDef('PAY_FORMULA', 'PAYROLL', ['PAY_BASIC']),
  CompanyFeatureDef('PAY_TAX_INS', 'PAYROLL', ['PAY_BASIC']),
  CompanyFeatureDef('PAY_DEPENDENT', 'PAYROLL', ['PAY_TAX_INS']),
  CompanyFeatureDef('PAY_EMPLOYER_COST', 'PAYROLL', ['PAY_TAX_INS']),
  CompanyFeatureDef('HR_CONTRACT', 'HR'),
  CompanyFeatureDef('HR_CONTRACT_ALERT', 'HR', ['HR_CONTRACT']),
  CompanyFeatureDef('HR_DOCUMENT', 'HR'),
  CompanyFeatureDef('HR_DOCUMENT_ALERT', 'HR', ['HR_DOCUMENT']),
  CompanyFeatureDef('HR_ORGCHART', 'HR'),
  CompanyFeatureDef('HR_JOBHISTORY', 'HR'),
  CompanyFeatureDef('HR_MANAGER_APPROVAL', 'HR', ['HR_ORGCHART']),
  CompanyFeatureDef('RPT_OVERVIEW', 'REPORT'),
  CompanyFeatureDef('RPT_PAYROLL', 'REPORT', ['PAY_BASIC']),
  CompanyFeatureDef('RPT_INSURANCE', 'REPORT', ['PAY_DEPENDENT']),
  CompanyFeatureDef('DATA_EXCEL', 'REPORT'),
];

/// Nhóm hiển thị, theo thứ tự.
const List<String> companyFeatureGroups = ['ATTENDANCE', 'SHIFT', 'CALENDAR', 'LEAVE', 'PAYROLL', 'HR', 'REPORT'];

final Map<String, CompanyFeatureDef> _byCode = {for (final f in companyFeatureCatalog) f.code: f};

List<CompanyFeatureDef> companyFeaturesOfGroup(String group) =>
    companyFeatureCatalog.where((f) => f.group == group).toList();

List<String> companyFeatureRequires(String code) => _byCode[code]?.requires ?? const [];

String companyFeatureGroupLabel(AppLocalizations s, String group) => switch (group) {
      'ATTENDANCE' => s.featureGroupAttendance,
      'SHIFT' => s.featureGroupShift,
      'CALENDAR' => s.featureGroupCalendar,
      'LEAVE' => s.featureGroupLeave,
      'PAYROLL' => s.featureGroupPayroll,
      'HR' => s.featureGroupHr,
      'REPORT' => s.featureGroupReport,
      _ => group,
    };

String companyFeatureLabel(AppLocalizations s, String code) => switch (code) {
      'ATT_SHEET' => s.featureAttSheet,
      'ATT_SELF' => s.featureAttSelf,
      'ATT_GEOFENCE' => s.featureAttGeofence,
      'ATT_DEVICE' => s.featureAttDevice,
      'ATT_NOSHIFT' => s.featureAttNoshift,
      'ATT_REQUEST' => s.featureAttRequest,
      'SHIFT_BASIC' => s.featureShiftBasic,
      'SHIFT_ADVANCED' => s.featureShiftAdvanced,
      'SHIFT_ROTATION' => s.featureShiftRotation,
      'SHIFT_SWAP' => s.featureShiftSwap,
      'SHIFT_REGISTRATION' => s.featureShiftRegistration,
      'SHIFT_REMINDER' => s.featureShiftReminder,
      'CAL_WORKCAL' => s.featureCalWorkcal,
      'CAL_HOLIDAY' => s.featureCalHoliday,
      'LEAVE_BASIC' => s.featureLeaveBasic,
      'LEAVE_BALANCE' => s.featureLeaveBalance,
      'LEAVE_ACCRUAL' => s.featureLeaveAccrual,
      'PAY_BASIC' => s.featurePayBasic,
      'PAY_FORMULA' => s.featurePayFormula,
      'PAY_TAX_INS' => s.featurePayTaxIns,
      'PAY_DEPENDENT' => s.featurePayDependent,
      'PAY_EMPLOYER_COST' => s.featurePayEmployerCost,
      'HR_CONTRACT' => s.featureHrContract,
      'HR_CONTRACT_ALERT' => s.featureHrContractAlert,
      'HR_DOCUMENT' => s.featureHrDocument,
      'HR_DOCUMENT_ALERT' => s.featureHrDocumentAlert,
      'HR_ORGCHART' => s.featureHrOrgchart,
      'HR_JOBHISTORY' => s.featureHrJobhistory,
      'HR_MANAGER_APPROVAL' => s.featureHrManagerApproval,
      'RPT_OVERVIEW' => s.featureRptOverview,
      'RPT_PAYROLL' => s.featureRptPayroll,
      'RPT_INSURANCE' => s.featureRptInsurance,
      'DATA_EXCEL' => s.featureDataExcel,
      _ => code,
    };

/// Bật / tắt một tính năng, giữ ràng buộc: bật thì bật luôn các tính năng nó cần; tắt thì tắt luôn các tính năng cần nó.
/// Tự chấm công cần Ca làm cơ bản hoặc chấm khi không có ca: tắt cả hai thì tự chấm công tắt theo (backend từ chối nếu không).
void toggleCompanyFeature(Set<String> enabled, String code, bool on) {
  if (on) {
    if (!enabled.add(code)) return;
    for (final need in companyFeatureRequires(code)) {
      toggleCompanyFeature(enabled, need, true);
    }
  } else {
    if (!enabled.remove(code)) return;
    for (final f in companyFeatureCatalog) {
      if (f.requires.contains(code)) toggleCompanyFeature(enabled, f.code, false);
    }
    if (!enabled.contains('SHIFT_BASIC') && !enabled.contains('ATT_NOSHIFT')) {
      toggleCompanyFeature(enabled, 'ATT_SELF', false);
    }
  }
}

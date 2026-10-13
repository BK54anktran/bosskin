<!-- Tự sinh bởi tools/docs/gen_he_thong.py — không sửa tay; sửa code rồi chạy lại. -->

# Danh sách API

40 controller, 308 endpoint. Cột **Quyền** là mã quyền kiểm ở controller (`requirePermission`); "—" nghĩa là chỉ cần đăng nhập, phần kiểm tra (chính chủ, phạm vi phòng ban, vai trò) nằm ở service. `/api/v1/public/**`, `/api/v1/auth/login|refresh|logout|2fa/**`, `/admin/auth/**`, `/actuator/health` không cần đăng nhập; `/admin/**` chỉ nhận token quản trị hệ thống (xem [bảo mật](bao-mat.md)).

| Controller | Gốc | Số endpoint |
|---|---|---|
| [AuditLogController](#auditlogcontroller) | `/` | 2 |
| [AdminStatsController](#adminstatscontroller) | `/admin/stats` | 1 |
| [AttendanceController](#attendancecontroller) | `/api/v1/attendances` | 24 |
| [AttendancePeriodController](#attendanceperiodcontroller) | `/api/v1/attendance-periods` | 3 |
| [AttendanceRequestController](#attendancerequestcontroller) | `/api/v1/attendance-requests` | 8 |
| [AuthController](#authcontroller) | `/` | 10 |
| [CompanyController](#companycontroller) | `/admin/companies` | 6 |
| [CompanySettingController](#companysettingcontroller) | `/api/v1/company-settings` | 2 |
| [ContractController](#contractcontroller) | `/api/v1/contracts` | 14 |
| [DashboardController](#dashboardcontroller) | `/api/v1/dashboard` | 5 |
| [DepartmentController](#departmentcontroller) | `/api/v1/departments` | 10 |
| [DependentController](#dependentcontroller) | `/api/v1/dependents` | 5 |
| [DocumentController](#documentcontroller) | `/` | 18 |
| [EmployeeController](#employeecontroller) | `/api/v1/employees` | 11 |
| [EmployeeLocationController](#employeelocationcontroller) | `/api/v1/employees/{employeeId}/locations` | 4 |
| [FormulaVariableController](#formulavariablecontroller) | `/api/v1/formula-variables` | 9 |
| [HolidayTemplateController](#holidaytemplatecontroller) | `/admin/holidays` | 5 |
| [JobHistoryController](#jobhistorycontroller) | `/` | 4 |
| [LeaveController](#leavecontroller) | `/api/v1/leaves` | 21 |
| [MapTileController](#maptilecontroller) | `/api/v1/map-tiles` | 1 |
| [PayrollController](#payrollcontroller) | `/api/v1/payrolls , /api/v1/payroll` | 10 |
| [PositionController](#positioncontroller) | `/api/v1/positions` | 4 |
| [ProfileController](#profilecontroller) | `/api/v1/profile` | 12 |
| [PublicDocumentFileController](#publicdocumentfilecontroller) | `/` | 1 |
| [ReportController](#reportcontroller) | `/api/v1/reports` | 11 |
| [RoleController](#rolecontroller) | `/api/v1/roles` | 7 |
| [SalaryFormulaController](#salaryformulacontroller) | `/api/v1/salary-formulas` | 5 |
| [SalaryGradeController](#salarygradecontroller) | `/api/v1/salary-grades` | 4 |
| [SalaryHistoryController](#salaryhistorycontroller) | `/api/v1/salary-histories` | 4 |
| [ShiftPlanController](#shiftplancontroller) | `/` | 12 |
| [SystemAdminController](#systemadmincontroller) | `/admin/system-admins` | 5 |
| [TaxPolicyController](#taxpolicycontroller) | `/admin/tax-policies` | 4 |
| [TeamApprovalController](#teamapprovalcontroller) | `/api/v1/team-approvals` | 4 |
| [TrialRequestController](#trialrequestcontroller) | `/` | 5 |
| [TwoFactorController](#twofactorcontroller) | `/` | 6 |
| [UniversalExcelController](#universalexcelcontroller) | `/api/v1/excel` | 7 |
| [UploadController](#uploadcontroller) | `/api/v1/upload` | 2 |
| [UserController](#usercontroller) | `/api/v1/users` | 10 |
| [WorkCalendarController](#workcalendarcontroller) | `/` | 14 |
| [WorkShiftController](#workshiftcontroller) | `/api/v1/shifts` | 18 |

## AuditLogController

`backend/src/main/java/com/bosskin/audit/AuditLogController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/audit-logs` | AUDIT_VIEW | `companyLogs` |
| GET | `/admin/audit-logs` | SYSTEM_ADMIN | `systemLogs` |

## AdminStatsController

`backend/src/main/java/com/bosskin/controller/AdminStatsController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/admin/stats` | SYSTEM_ADMIN | `getStats` |

## AttendanceController

`backend/src/main/java/com/bosskin/controller/AttendanceController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/attendances` | ATTENDANCE_VIEW | `getByMonth` |
| GET | `/api/v1/attendances/timesheet` | ATTENDANCE_VIEW | `getTimesheet` |
| GET | `/api/v1/attendances/timesheet-range` | ATTENDANCE_VIEW | `getTimesheetRange` |
| GET | `/api/v1/attendances/day-view` | ATTENDANCE_VIEW | `getDayView` |
| POST | `/api/v1/attendances/approve` | ATTENDANCE_APPROVE, ATTENDANCE_VIEW | `approve` |
| POST | `/api/v1/attendances/approve-bulk` | ATTENDANCE_APPROVE, ATTENDANCE_VIEW | `approveBulk` |
| PATCH | `/api/v1/attendances/{attendanceId}/override` | ATTENDANCE_MANAGE, ATTENDANCE_VIEW | `override` |
| POST | `/api/v1/attendances/override` | ATTENDANCE_MANAGE, ATTENDANCE_VIEW | `createOverride` |
| POST | `/api/v1/attendances/unapprove` | ATTENDANCE_APPROVE, ATTENDANCE_VIEW | `unapprove` |
| DELETE | `/api/v1/attendances/{id}` | ATTENDANCE_MANAGE | `delete` |
| POST | `/api/v1/attendances/check-in` | ATTENDANCE_MANAGE, ATTENDANCE_VIEW | `checkIn` |
| GET | `/api/v1/attendances/self/today` | ATTENDANCE_SELF | `getSelfToday` |
| GET | `/api/v1/attendances/self/history` | ATTENDANCE_SELF | `getSelfHistory` |
| PATCH | `/api/v1/attendances/self/setting` | ATTENDANCE_MANAGE | `updateSelfAttendanceSetting` |
| POST | `/api/v1/attendances/self/check-in` | ATTENDANCE_SELF | `selfCheckIn` |
| POST | `/api/v1/attendances/self/check-out` | ATTENDANCE_SELF | `selfCheckOut` |
| POST | `/api/v1/attendances/check-out` | ATTENDANCE_MANAGE, ATTENDANCE_VIEW | `checkOut` |
| GET | `/api/v1/attendances/export-timesheet` | ATTENDANCE_VIEW | `exportTimesheetExcel` |
| GET | `/api/v1/attendances/export-day-view` | ATTENDANCE_VIEW | `exportDayView` |
| GET | `/api/v1/attendances/export` | ATTENDANCE_VIEW | `exportExcel` |
| POST | `/api/v1/attendances/preview-import` | ATTENDANCE_VIEW | `previewImport` |
| POST | `/api/v1/attendances/import` | ATTENDANCE_MANAGE | `importExcel` |
| POST | `/api/v1/attendances/preview-import-timesheet` | ATTENDANCE_VIEW | `previewImportTimesheet` |
| POST | `/api/v1/attendances/import-timesheet` | ATTENDANCE_MANAGE, ATTENDANCE_APPROVE | `importTimesheet` |

## AttendancePeriodController

`backend/src/main/java/com/bosskin/controller/AttendancePeriodController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/attendance-periods` | ATTENDANCE_VIEW | `list` |
| POST | `/api/v1/attendance-periods/{year}/{month}/lock` | ATTENDANCE_PERIOD_LOCK | `lock` |
| POST | `/api/v1/attendance-periods/{year}/{month}/unlock` | ATTENDANCE_PERIOD_LOCK | `unlock` |

## AttendanceRequestController

`backend/src/main/java/com/bosskin/controller/AttendanceRequestController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/attendance-requests` | ATTENDANCE_SELF hoặc ATTENDANCE_MANAGE hoặc ATTENDANCE_REQUEST_APPROVE | `getRequests` |
| GET | `/api/v1/attendance-requests/page` | ATTENDANCE_SELF hoặc ATTENDANCE_MANAGE hoặc ATTENDANCE_REQUEST_APPROVE | `searchRequests` |
| GET | `/api/v1/attendance-requests/pending-count` | ATTENDANCE_SELF hoặc ATTENDANCE_MANAGE hoặc ATTENDANCE_REQUEST_APPROVE | `pendingCount` |
| POST | `/api/v1/attendance-requests` | ATTENDANCE_SELF hoặc ATTENDANCE_MANAGE hoặc ATTENDANCE_REQUEST_APPROVE | `create` |
| PUT | `/api/v1/attendance-requests/{id}/approve` | ATTENDANCE_REQUEST_APPROVE | `approve` |
| PUT | `/api/v1/attendance-requests/{id}/reject` | ATTENDANCE_REQUEST_APPROVE | `reject` |
| PUT | `/api/v1/attendance-requests/{id}/cancel` | ATTENDANCE_SELF hoặc ATTENDANCE_MANAGE hoặc ATTENDANCE_REQUEST_APPROVE | `cancel` |
| PUT | `/api/v1/attendance-requests/{id}/applied` | ATTENDANCE_MANAGE hoặc ATTENDANCE_REQUEST_APPROVE | `toggleApplied` |

## AuthController

`backend/src/main/java/com/bosskin/controller/AuthController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| POST | `/api/v1/auth/login` | — | `login` |
| POST | `/api/v1/auth/refresh` | — | `refresh` |
| POST | `/api/v1/auth/logout` | — | `logout` |
| POST | `/admin/auth/login` | — | `systemLogin` |
| POST | `/api/v1/auth/2fa/verify` | — | `verify2fa` |
| POST | `/api/v1/auth/2fa/setup` | — | `setup2fa` |
| POST | `/api/v1/auth/2fa/enable` | — | `enable2fa` |
| POST | `/admin/auth/2fa/verify` | — | `verifySystem2fa` |
| POST | `/admin/auth/2fa/setup` | — | `setupSystem2fa` |
| POST | `/admin/auth/2fa/enable` | — | `enableSystem2fa` |

## CompanyController

`backend/src/main/java/com/bosskin/controller/CompanyController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/admin/companies` | SYSTEM_ADMIN | `getAll` |
| GET | `/admin/companies/{id}` | SYSTEM_ADMIN | `getById` |
| POST | `/admin/companies` | SYSTEM_ADMIN | `create` |
| PUT | `/admin/companies/{id}` | SYSTEM_ADMIN | `update` |
| PATCH | `/admin/companies/{id}/toggle-active` | SYSTEM_ADMIN | `toggleActive` |
| POST | `/admin/companies/{id}/impersonate` | SYSTEM_ADMIN | `impersonate` |

## CompanySettingController

`backend/src/main/java/com/bosskin/controller/CompanySettingController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/company-settings` | — | `get` |
| PUT | `/api/v1/company-settings` | COMPANY_SETTING_MANAGE | `update` |

## ContractController

`backend/src/main/java/com/bosskin/controller/ContractController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/contracts` | CONTRACT_VIEW | `list` |
| GET | `/api/v1/contracts/expiring` | CONTRACT_VIEW | `expiring` |
| GET | `/api/v1/contracts/export` | CONTRACT_VIEW | `export` |
| POST | `/api/v1/contracts/preview-import` | CONTRACT_VIEW, CONTRACT_EDIT | `previewImport` |
| POST | `/api/v1/contracts/import` | CONTRACT_VIEW, CONTRACT_EDIT | `importExcel` |
| GET | `/api/v1/contracts/{id}` | CONTRACT_VIEW | `get` |
| POST | `/api/v1/contracts` | CONTRACT_VIEW, CONTRACT_EDIT | `create` |
| PUT | `/api/v1/contracts/{id}` | CONTRACT_VIEW, CONTRACT_EDIT | `update` |
| POST | `/api/v1/contracts/{id}/activate` | CONTRACT_VIEW, CONTRACT_EDIT | `activate` |
| POST | `/api/v1/contracts/{id}/terminate` | CONTRACT_VIEW, CONTRACT_EDIT | `terminate` |
| DELETE | `/api/v1/contracts/{id}` | CONTRACT_VIEW, CONTRACT_DELETE | `delete` |
| POST | `/api/v1/contracts/{id}/appendices` | CONTRACT_VIEW, CONTRACT_EDIT | `addAppendix` |
| PUT | `/api/v1/contracts/appendices/{appendixId}` | CONTRACT_VIEW, CONTRACT_EDIT | `updateAppendix` |
| DELETE | `/api/v1/contracts/appendices/{appendixId}` | CONTRACT_VIEW, CONTRACT_EDIT | `deleteAppendix` |

## DashboardController

`backend/src/main/java/com/bosskin/controller/DashboardController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/dashboard` | DASHBOARD_VIEW | `getDashboard` |
| GET | `/api/v1/dashboard/analytics` | DASHBOARD_VIEW | `getAnalytics` |
| GET | `/api/v1/dashboard/kpi` | DASHBOARD_VIEW | `getKpi` |
| GET | `/api/v1/dashboard/risks` | DASHBOARD_VIEW | `getRisks` |
| GET | `/api/v1/dashboard/range` | DASHBOARD_VIEW | `getRangeDashboard` |

## DepartmentController

`backend/src/main/java/com/bosskin/controller/DepartmentController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/departments` | DEPARTMENT_VIEW | `getTree` |
| GET | `/api/v1/departments/export` | DEPARTMENT_VIEW | `export` |
| POST | `/api/v1/departments/positions/preview-import` | DEPARTMENT_MANAGE | `previewImportPositions` |
| POST | `/api/v1/departments/positions/import` | DEPARTMENT_MANAGE | `importPositions` |
| POST | `/api/v1/departments/preview-import` | DEPARTMENT_MANAGE | `previewImport` |
| POST | `/api/v1/departments/import` | DEPARTMENT_MANAGE | `importExcel` |
| GET | `/api/v1/departments/flat` | DEPARTMENT_VIEW | `getFlat` |
| POST | `/api/v1/departments` | DEPARTMENT_MANAGE, DEPARTMENT_VIEW | `create` |
| PUT | `/api/v1/departments/{id}` | DEPARTMENT_MANAGE, DEPARTMENT_VIEW | `update` |
| DELETE | `/api/v1/departments/{id}` | DEPARTMENT_MANAGE, DEPARTMENT_VIEW | `delete` |

## DependentController

`backend/src/main/java/com/bosskin/controller/DependentController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/dependents` | EMPLOYEE_VIEW | `list` |
| GET | `/api/v1/dependents/self` | — | `self` |
| POST | `/api/v1/dependents` | EMPLOYEE_VIEW, EMPLOYEE_UPDATE | `create` |
| PUT | `/api/v1/dependents/{id}` | EMPLOYEE_VIEW, EMPLOYEE_UPDATE | `update` |
| DELETE | `/api/v1/dependents/{id}` | EMPLOYEE_VIEW, EMPLOYEE_UPDATE | `delete` |

## DocumentController

`backend/src/main/java/com/bosskin/controller/DocumentController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/document-types` | — | `types` |
| POST | `/api/v1/document-types` | EMPLOYEE_DOCUMENT_VIEW, EMPLOYEE_DOCUMENT_EDIT | `createType` |
| PUT | `/api/v1/document-types/{id}` | EMPLOYEE_DOCUMENT_VIEW, EMPLOYEE_DOCUMENT_EDIT | `updateType` |
| DELETE | `/api/v1/document-types/{id}` | EMPLOYEE_DOCUMENT_VIEW, EMPLOYEE_DOCUMENT_EDIT | `deleteType` |
| GET | `/api/v1/employee-documents` | EMPLOYEE_DOCUMENT_VIEW | `list` |
| POST | `/api/v1/employee-documents` | EMPLOYEE_DOCUMENT_VIEW, EMPLOYEE_DOCUMENT_EDIT | `upload` |
| PUT | `/api/v1/employee-documents/{id}` | EMPLOYEE_DOCUMENT_VIEW, EMPLOYEE_DOCUMENT_EDIT | `update` |
| DELETE | `/api/v1/employee-documents/{id}` | EMPLOYEE_DOCUMENT_VIEW, EMPLOYEE_DOCUMENT_EDIT | `delete` |
| POST | `/api/v1/employee-documents/{id}/approve` | EMPLOYEE_DOCUMENT_VIEW, EMPLOYEE_DOCUMENT_EDIT | `approve` |
| POST | `/api/v1/employee-documents/{id}/reject` | EMPLOYEE_DOCUMENT_VIEW, EMPLOYEE_DOCUMENT_EDIT | `reject` |
| GET | `/api/v1/employee-documents/{id}/link` | EMPLOYEE_DOCUMENT_VIEW | `link` |
| GET | `/api/v1/employee-documents/pending` | EMPLOYEE_DOCUMENT_VIEW | `pending` |
| GET | `/api/v1/employee-documents/expiring` | EMPLOYEE_DOCUMENT_VIEW | `expiring` |
| GET | `/api/v1/employee-documents/missing` | EMPLOYEE_DOCUMENT_VIEW | `missing` |
| GET | `/api/v1/employee-documents/self` | — | `self` |
| POST | `/api/v1/employee-documents/self` | — | `uploadSelf` |
| GET | `/api/v1/employee-documents/self/{id}/link` | — | `selfLink` |
| DELETE | `/api/v1/employee-documents/self/{id}` | — | `deleteSelf` |

## EmployeeController

`backend/src/main/java/com/bosskin/controller/EmployeeController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/employees/export` | EMPLOYEE_VIEW | `export` |
| POST | `/api/v1/employees/preview-import` | EMPLOYEE_CREATE | `previewImport` |
| POST | `/api/v1/employees/import` | EMPLOYEE_CREATE | `importExcel` |
| GET | `/api/v1/employees` | EMPLOYEE_VIEW | `getAll` |
| GET | `/api/v1/employees/{id}` | EMPLOYEE_VIEW | `getById` |
| POST | `/api/v1/employees` | EMPLOYEE_CREATE | `create` |
| PUT | `/api/v1/employees/{id}` | EMPLOYEE_UPDATE | `update` |
| DELETE | `/api/v1/employees/{id}/device` | EMPLOYEE_UPDATE | `unbindDevice` |
| POST | `/api/v1/employees/{id}/resign` | EMPLOYEE_DELETE | `resign` |
| POST | `/api/v1/employees/{id}/reinstate` | EMPLOYEE_DELETE | `reinstate` |
| DELETE | `/api/v1/employees/{id}` | EMPLOYEE_DELETE | `delete` |

## EmployeeLocationController

`backend/src/main/java/com/bosskin/controller/EmployeeLocationController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/employees/{employeeId}/locations` | EMPLOYEE_VIEW | `list` |
| POST | `/api/v1/employees/{employeeId}/locations` | EMPLOYEE_UPDATE | `create` |
| PUT | `/api/v1/employees/{employeeId}/locations/{locationId}` | EMPLOYEE_UPDATE | `update` |
| DELETE | `/api/v1/employees/{employeeId}/locations/{locationId}` | EMPLOYEE_UPDATE | `delete` |

## FormulaVariableController

`backend/src/main/java/com/bosskin/controller/FormulaVariableController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/formula-variables/categories` | PAYROLL_VIEW | `listCategories` |
| GET | `/api/v1/formula-variables` | PAYROLL_VIEW | `list` |
| GET | `/api/v1/formula-variables/all` | PAYROLL_VIEW | `listAll` |
| GET | `/api/v1/formula-variables/{id}/usages` | PAYROLL_VIEW | `usages` |
| POST | `/api/v1/formula-variables/validate` | PAYROLL_VIEW | `validate` |
| POST | `/api/v1/formula-variables` | PAYROLL_CREATE | `create` |
| PUT | `/api/v1/formula-variables/{id}` | PAYROLL_CREATE | `update` |
| PATCH | `/api/v1/formula-variables/{id}/show-in-formula` | PAYROLL_CREATE | `toggleShowInFormula` |
| DELETE | `/api/v1/formula-variables/{id}` | PAYROLL_CREATE | `delete` |

## HolidayTemplateController

`backend/src/main/java/com/bosskin/controller/HolidayTemplateController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/admin/holidays` | SYSTEM_ADMIN | `list` |
| GET | `/admin/holidays/years` | SYSTEM_ADMIN | `years` |
| POST | `/admin/holidays` | SYSTEM_ADMIN | `create` |
| PUT | `/admin/holidays/{id}` | SYSTEM_ADMIN | `update` |
| DELETE | `/admin/holidays/{id}` | SYSTEM_ADMIN | `delete` |

## JobHistoryController

`backend/src/main/java/com/bosskin/controller/JobHistoryController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/employees/{id}/job-histories` | EMPLOYEE_VIEW | `list` |
| POST | `/api/v1/employees/{id}/job-histories` | EMPLOYEE_VIEW, EMPLOYEE_UPDATE | `create` |
| DELETE | `/api/v1/employees/job-histories/{historyId}` | EMPLOYEE_VIEW, EMPLOYEE_UPDATE | `delete` |
| GET | `/api/v1/org-chart` | EMPLOYEE_VIEW | `orgChart` |

## LeaveController

`backend/src/main/java/com/bosskin/controller/LeaveController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/leaves/types` | LEAVE_VIEW | `getTypes` |
| POST | `/api/v1/leaves/types` | LEAVE_TYPE_MANAGE | `createType` |
| PUT | `/api/v1/leaves/types/{id}` | LEAVE_TYPE_MANAGE | `updateType` |
| DELETE | `/api/v1/leaves/types/{id}` | LEAVE_TYPE_MANAGE | `deleteType` |
| GET | `/api/v1/leaves/requests` | LEAVE_VIEW | `getRequests` |
| GET | `/api/v1/leaves/requests/page` | LEAVE_VIEW | `searchRequests` |
| POST | `/api/v1/leaves/requests` | LEAVE_REQUEST_CREATE | `createRequest` |
| PUT | `/api/v1/leaves/requests/{id}/approve` | LEAVE_REQUEST_APPROVE | `approve` |
| PUT | `/api/v1/leaves/requests/{id}/reject` | LEAVE_REQUEST_APPROVE | `reject` |
| POST | `/api/v1/leaves/requests/{id}/cancel` | LEAVE_VIEW | `cancel` |
| PUT | `/api/v1/leaves/requests/{id}/applied` | LEAVE_REQUEST_APPROVE | `updateApplied` |
| GET | `/api/v1/leaves/ledger` | — | `getLedger` |
| GET | `/api/v1/leaves/grants` | LEAVE_VIEW | `getGrants` |
| POST | `/api/v1/leaves/grants/manual` | LEAVE_GRANT_MANUAL | `manualGrant` |
| GET | `/api/v1/leaves/accrual-rules` | LEAVE_VIEW | `getAccrualRules` |
| POST | `/api/v1/leaves/accrual-rules` | LEAVE_ACCRUAL_MANAGE | `createAccrualRule` |
| PUT | `/api/v1/leaves/accrual-rules/{id}` | LEAVE_ACCRUAL_MANAGE | `updateAccrualRule` |
| DELETE | `/api/v1/leaves/accrual-rules/{id}` | LEAVE_ACCRUAL_MANAGE | `deleteAccrualRule` |
| POST | `/api/v1/leaves/accrual-rules/run` | LEAVE_ACCRUAL_MANAGE | `runAccrual` |
| GET | `/api/v1/leaves/settings` | LEAVE_VIEW | `getSetting` |
| PUT | `/api/v1/leaves/settings` | LEAVE_ACCRUAL_MANAGE | `updateSetting` |

## MapTileController

`backend/src/main/java/com/bosskin/controller/MapTileController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/map-tiles/{z}/{x}/{y}.png` | — | `tile` |

## PayrollController

`backend/src/main/java/com/bosskin/controller/PayrollController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/payrolls` | PAYROLL_VIEW | `getByMonth` |
| GET | `/api/v1/payrolls/export-payslips` | PAYROLL_VIEW | `exportPayslips` |
| POST | `/api/v1/payrolls/generate` | PAYROLL_CREATE, PAYROLL_VIEW | `generate` |
| PATCH | `/api/v1/payrolls/{id}` | PAYROLL_CREATE, PAYROLL_VIEW | `patchDraft` |
| POST | `/api/v1/payrolls/{id}/approve` | PAYROLL_APPROVE, PAYROLL_VIEW | `approve` |
| POST | `/api/v1/payrolls/{id}/pay` | PAYROLL_PAY, PAYROLL_VIEW | `markAsPaid` |
| DELETE | `/api/v1/payrolls/{id}` | PAYROLL_CREATE, PAYROLL_VIEW | `delete` |
| POST | `/api/v1/payrolls/{id}/recalculate` | PAYROLL_CREATE, PAYROLL_VIEW | `recalculate` |
| GET | `/api/v1/payrolls/by-employee/{employeeId}` | PAYROLL_VIEW | `getByEmployee` |
| GET | `/api/v1/payrolls/self` | ATTENDANCE_SELF | `getSelf` |

## PositionController

`backend/src/main/java/com/bosskin/controller/PositionController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/positions` | DEPARTMENT_VIEW | `getAll` |
| POST | `/api/v1/positions` | POSITION_MANAGE, DEPARTMENT_VIEW | `create` |
| PUT | `/api/v1/positions/{id}` | POSITION_MANAGE, DEPARTMENT_VIEW | `update` |
| DELETE | `/api/v1/positions/{id}` | POSITION_MANAGE, DEPARTMENT_VIEW | `delete` |

## ProfileController

`backend/src/main/java/com/bosskin/controller/ProfileController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/profile` | — | `getMyProfile` |
| PUT | `/api/v1/profile` | — | `adminUpdate` |
| PATCH | `/api/v1/profile/avatar` | — | `updateAvatar` |
| PATCH | `/api/v1/profile/password` | — | `changePassword` |
| POST | `/api/v1/profile/edit-requests` | — | `submitEditRequest` |
| GET | `/api/v1/profile/edit-requests` | — | `getEditRequests` |
| GET | `/api/v1/profile/edit-requests/pending-count` | — | `getPendingCount` |
| PUT | `/api/v1/profile/edit-requests/{id}/approve` | — | `approveRequest` |
| PUT | `/api/v1/profile/edit-requests/{id}/reject` | — | `rejectRequest` |
| GET | `/api/v1/profile/notification-settings` | — | `getNotificationSettings` |
| PATCH | `/api/v1/profile/notification-settings` | — | `updateNotificationSettings` |
| POST | `/api/v1/profile/notification-settings/test` | — | `sendTestNotification` |

## PublicDocumentFileController

`backend/src/main/java/com/bosskin/controller/PublicDocumentFileController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/public/document-files` | — | `file` |

## ReportController

`backend/src/main/java/com/bosskin/controller/ReportController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/reports/employee-headcount` | EMPLOYEE_VIEW, REPORT_VIEW | `employeeHeadcount` |
| GET | `/api/v1/reports/new-hires` | EMPLOYEE_VIEW, REPORT_VIEW | `newHires` |
| GET | `/api/v1/reports/resigned` | EMPLOYEE_VIEW, REPORT_VIEW | `resigned` |
| GET | `/api/v1/reports/attendance-summary` | ATTENDANCE_VIEW, REPORT_VIEW | `attendanceSummary` |
| GET | `/api/v1/reports/overtime-summary` | ATTENDANCE_VIEW, REPORT_VIEW | `overtimeSummary` |
| GET | `/api/v1/reports/insured-employees` | EMPLOYEE_VIEW, REPORT_VIEW | `insuredEmployees` |
| GET | `/api/v1/reports/dependents` | EMPLOYEE_VIEW, REPORT_VIEW | `dependents` |
| GET | `/api/v1/reports/payroll-summary` | PAYROLL_VIEW, REPORT_VIEW | `payrollSummary` |
| GET | `/api/v1/reports/yearly-overview` | PAYROLL_VIEW, REPORT_VIEW | `yearlyOverview` |
| GET | `/api/v1/reports/leave-balance` | LEAVE_VIEW, REPORT_VIEW | `leaveBalance` |
| GET | `/api/v1/reports/leave-usage` | LEAVE_VIEW, REPORT_VIEW | `leaveUsage` |

## RoleController

`backend/src/main/java/com/bosskin/controller/RoleController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/roles` | ROLE_VIEW | `getAll` |
| GET | `/api/v1/roles/permissions` | DASHBOARD_VIEW, SHIFT_VIEW, SHIFT_MANAGE | `getAllPermissions` |
| GET | `/api/v1/roles/{id}/dept-scopes` | ROLE_MANAGE | `getDeptScopes` |
| POST | `/api/v1/roles` | ROLE_MANAGE | `create` |
| PUT | `/api/v1/roles/{id}` | ROLE_MANAGE | `update` |
| PUT | `/api/v1/roles/{id}/permissions` | ROLE_MANAGE | `updatePermissions` |
| DELETE | `/api/v1/roles/{id}` | ROLE_MANAGE | `delete` |

## SalaryFormulaController

`backend/src/main/java/com/bosskin/controller/SalaryFormulaController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/salary-formulas` | PAYROLL_VIEW | `list` |
| POST | `/api/v1/salary-formulas/validate` | PAYROLL_VIEW | `validate` |
| POST | `/api/v1/salary-formulas` | PAYROLL_CREATE | `create` |
| PUT | `/api/v1/salary-formulas/{id}` | PAYROLL_CREATE | `update` |
| DELETE | `/api/v1/salary-formulas/{id}` | PAYROLL_CREATE | `delete` |

## SalaryGradeController

`backend/src/main/java/com/bosskin/controller/SalaryGradeController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/salary-grades` | PAYROLL_VIEW | `list` |
| POST | `/api/v1/salary-grades` | PAYROLL_CREATE | `create` |
| PUT | `/api/v1/salary-grades/{id}` | PAYROLL_CREATE | `update` |
| DELETE | `/api/v1/salary-grades/{id}` | PAYROLL_CREATE | `delete` |

## SalaryHistoryController

`backend/src/main/java/com/bosskin/controller/SalaryHistoryController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/salary-histories` | PAYROLL_VIEW | `getByEmployee` |
| POST | `/api/v1/salary-histories` | PAYROLL_CREATE | `create` |
| PUT | `/api/v1/salary-histories/{id}` | PAYROLL_CREATE | `update` |
| DELETE | `/api/v1/salary-histories/{id}` | PAYROLL_CREATE | `delete` |

## ShiftPlanController

`backend/src/main/java/com/bosskin/controller/ShiftPlanController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/shift-rotations` | SHIFT_VIEW, SHIFT_MANAGE | `rotations` |
| POST | `/api/v1/shift-rotations` | SHIFT_MANAGE | `createRotation` |
| PUT | `/api/v1/shift-rotations/{id}` | SHIFT_MANAGE | `updateRotation` |
| DELETE | `/api/v1/shift-rotations/{id}` | SHIFT_MANAGE | `deleteRotation` |
| POST | `/api/v1/shift-rotations/{id}/generate` | SHIFT_MANAGE | `generate` |
| GET | `/api/v1/shift-swaps` | ATTENDANCE_SELF, SHIFT_SWAP_APPROVE | `swaps` |
| GET | `/api/v1/shift-swaps/my-shifts` | ATTENDANCE_SELF | `myShifts` |
| GET | `/api/v1/shift-swaps/colleagues` | ATTENDANCE_SELF | `colleagues` |
| POST | `/api/v1/shift-swaps` | ATTENDANCE_SELF | `createSwap` |
| PUT | `/api/v1/shift-swaps/{id}/approve` | — | `approveSwap` |
| PUT | `/api/v1/shift-swaps/{id}/reject` | — | `rejectSwap` |
| PUT | `/api/v1/shift-swaps/{id}/cancel` | — | `cancelSwap` |

## SystemAdminController

`backend/src/main/java/com/bosskin/controller/SystemAdminController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/admin/system-admins` | SYSTEM_ADMIN | `list` |
| POST | `/admin/system-admins` | SYSTEM_ADMIN | `create` |
| PATCH | `/admin/system-admins/{id}/enabled` | SYSTEM_ADMIN | `enabled` |
| POST | `/admin/system-admins/{id}/reset-password` | SYSTEM_ADMIN | `resetPassword` |
| POST | `/admin/system-admins/{id}/reset-2fa` | SYSTEM_ADMIN | `reset2fa` |

## TaxPolicyController

`backend/src/main/java/com/bosskin/controller/TaxPolicyController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/admin/tax-policies` | SYSTEM_ADMIN | `list` |
| POST | `/admin/tax-policies` | SYSTEM_ADMIN | `create` |
| PUT | `/admin/tax-policies/{id}` | SYSTEM_ADMIN | `update` |
| DELETE | `/admin/tax-policies/{id}` | SYSTEM_ADMIN | `delete` |

## TeamApprovalController

`backend/src/main/java/com/bosskin/controller/TeamApprovalController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/team-approvals` | — | `list` |
| GET | `/api/v1/team-approvals/count` | — | `count` |
| POST | `/api/v1/team-approvals/{kind}/{id}/approve` | — | `approve` |
| POST | `/api/v1/team-approvals/{kind}/{id}/reject` | — | `reject` |

## TrialRequestController

`backend/src/main/java/com/bosskin/controller/TrialRequestController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| POST | `/api/v1/public/trial-requests` | — | `submit` |
| GET | `/admin/trial-requests` | SYSTEM_ADMIN | `list` |
| GET | `/admin/trial-requests/count-new` | SYSTEM_ADMIN | `countNew` |
| PATCH | `/admin/trial-requests/{id}` | SYSTEM_ADMIN | `update` |
| GET | `/admin/trial-requests/export` | SYSTEM_ADMIN | `export` |

## TwoFactorController

`backend/src/main/java/com/bosskin/controller/TwoFactorController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/profile/2fa` | ROLE_MANAGE | `status` |
| POST | `/api/v1/profile/2fa/setup` | — | `setup` |
| POST | `/api/v1/profile/2fa/enable` | — | `enable` |
| POST | `/api/v1/profile/2fa/disable` | ROLE_MANAGE | `disable` |
| DELETE | `/api/v1/users/{id}/2fa` | USER_MANAGE | `reset` |
| PUT | `/admin/companies/{id}/require-admin-2fa` | SYSTEM_ADMIN | `requireAdmin2fa` |

## UniversalExcelController

`backend/src/main/java/com/bosskin/controller/UniversalExcelController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/excel/search` | EXCEL_EXPORT, EXCEL_IMPORT | `search` |
| GET | `/api/v1/excel/meta` | EXCEL_EXPORT, EXCEL_IMPORT | `meta` |
| POST | `/api/v1/excel/export` | EXCEL_EXPORT | `export` |
| POST | `/api/v1/excel/preview-import` | EXCEL_IMPORT | `previewImport` |
| POST | `/api/v1/excel/import` | EXCEL_IMPORT | `importAll` |
| GET | `/api/v1/excel/history/{id}/download` | EXCEL_EXPORT, EXCEL_IMPORT | `downloadHistory` |
| GET | `/api/v1/excel/history` | EXCEL_EXPORT, EXCEL_IMPORT | `history` |

## UploadController

`backend/src/main/java/com/bosskin/controller/UploadController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| POST | `/api/v1/upload/image` | — | `uploadImage` |
| POST | `/api/v1/upload/document` | — | `uploadDocument` |

## UserController

`backend/src/main/java/com/bosskin/controller/UserController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/users` | USER_MANAGE | `listUsers` |
| POST | `/api/v1/users/{id}/reset-password` | USER_MANAGE | `resetPassword` |
| POST | `/api/v1/users/initial-passwords` | USER_MANAGE | `issueInitialPasswords` |
| POST | `/api/v1/users` | USER_MANAGE | `createUser` |
| POST | `/api/v1/users/sync-from-employees` | USER_MANAGE | `syncFromEmployees` |
| PUT | `/api/v1/users/{id}/roles` | USER_MANAGE | `updateRoles` |
| PUT | `/api/v1/users/{id}/permissions` | USER_MANAGE | `updateDirectPermissions` |
| GET | `/api/v1/users/{id}/dept-scopes` | USER_MANAGE | `getDeptScopes` |
| PUT | `/api/v1/users/{id}/dept-scopes` | USER_MANAGE | `updateDeptScopes` |
| PATCH | `/api/v1/users/{id}/enabled` | USER_MANAGE | `setEnabled` |

## WorkCalendarController

`backend/src/main/java/com/bosskin/controller/WorkCalendarController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/holidays` | CALENDAR_VIEW | `holidays` |
| POST | `/api/v1/holidays` | CALENDAR_VIEW, CALENDAR_MANAGE | `createHoliday` |
| PUT | `/api/v1/holidays/{id}` | CALENDAR_VIEW, CALENDAR_MANAGE | `updateHoliday` |
| DELETE | `/api/v1/holidays/{id}` | CALENDAR_VIEW, CALENDAR_MANAGE | `deleteHoliday` |
| GET | `/api/v1/holidays/export` | CALENDAR_VIEW | `exportHolidays` |
| POST | `/api/v1/holidays/preview-import` | CALENDAR_VIEW, CALENDAR_MANAGE | `previewImport` |
| POST | `/api/v1/holidays/import` | CALENDAR_VIEW, CALENDAR_MANAGE | `importHolidays` |
| GET | `/api/v1/work-calendars` | CALENDAR_VIEW | `calendars` |
| PUT | `/api/v1/work-calendars/default` | CALENDAR_VIEW, CALENDAR_MANAGE | `saveDefault` |
| POST | `/api/v1/work-calendars` | CALENDAR_VIEW, CALENDAR_MANAGE | `createCalendar` |
| PUT | `/api/v1/work-calendars/{id}` | CALENDAR_VIEW, CALENDAR_MANAGE | `updateCalendar` |
| DELETE | `/api/v1/work-calendars/{id}` | CALENDAR_VIEW, CALENDAR_MANAGE | `deleteCalendar` |
| GET | `/api/v1/work-calendars/departments` | CALENDAR_VIEW | `calendarDepartments` |
| GET | `/api/v1/work-calendars/view` | CALENDAR_VIEW, SHIFT_VIEW, ATTENDANCE_VIEW, ATTENDANCE_SELF | `view` |

## WorkShiftController

`backend/src/main/java/com/bosskin/controller/WorkShiftController.java`

| Method | Đường dẫn | Quyền | Hàm |
|---|---|---|---|
| GET | `/api/v1/shifts/export` | SHIFT_VIEW, SHIFT_MANAGE | `export` |
| GET | `/api/v1/shifts/export-list` | SHIFT_VIEW, SHIFT_MANAGE | `exportList` |
| POST | `/api/v1/shifts/preview-import` | SHIFT_MANAGE | `previewImport` |
| POST | `/api/v1/shifts/import` | SHIFT_MANAGE | `importExcel` |
| POST | `/api/v1/shifts/preview-import-assignments` | SHIFT_MANAGE | `previewImportAssignments` |
| POST | `/api/v1/shifts/import-assignments` | SHIFT_MANAGE | `importAssignments` |
| GET | `/api/v1/shifts` | SHIFT_VIEW, SHIFT_MANAGE | `list` |
| GET | `/api/v1/shifts/department/{deptId}` | SHIFT_VIEW, SHIFT_MANAGE | `listByDept` |
| POST | `/api/v1/shifts` | SHIFT_MANAGE | `create` |
| PUT | `/api/v1/shifts/{id}` | SHIFT_MANAGE | `update` |
| DELETE | `/api/v1/shifts/{id}` | SHIFT_MANAGE | `delete` |
| GET | `/api/v1/shifts/assignments` | SHIFT_VIEW, SHIFT_MANAGE | `assignments` |
| GET | `/api/v1/shifts/assignments/employee/{empId}` | SHIFT_VIEW, SHIFT_MANAGE | `assignmentsByEmployee` |
| GET | `/api/v1/shifts/employees` | SHIFT_VIEW, SHIFT_MANAGE | `employeesInShiftScope` |
| POST | `/api/v1/shifts/assignments` | SHIFT_MANAGE | `assign` |
| POST | `/api/v1/shifts/assignments/bulk` | SHIFT_MANAGE | `bulkAssign` |
| DELETE | `/api/v1/shifts/assignments/{id}` | SHIFT_MANAGE | `deleteAssignmentById` |
| DELETE | `/api/v1/shifts/assignments` | SHIFT_MANAGE | `deleteAssignment` |

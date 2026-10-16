package com.bosskin.service;

import com.bosskin.core.SensitiveData;
import com.bosskin.entity.Employee;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.util.ExcelColumn;
import com.bosskin.util.ExcelI18n;
import com.bosskin.util.ExcelSheet;
import com.bosskin.util.ExcelUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class EmployeeExcelService {

    private final EmployeeRepository employeeRepo;
    private final DeptScopeService   deptScopeService;
    private final ExcelI18n          excelI18n;

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    // ─── Sheet 1: Thông tin cơ bản ───────────────────────────────────────────

    private static final List<ExcelColumn<Employee>> BASIC_COLUMNS = List.of(
        ExcelColumn.readOnlyI18n("excel.col.employee.code",           Employee::getEmployeeCode),
        ExcelColumn.readOnlyI18n("excel.col.employee.fullName",       Employee::getFullName),
        ExcelColumn.readOnlyI18n("excel.col.employee.email",          Employee::getEmail),
        ExcelColumn.readOnlyI18n("excel.col.employee.phone",          Employee::getPhone),
        ExcelColumn.readOnlyI18n("excel.col.employee.gender",         e -> e.getGender() == null ? "" : switch (e.getGender()) {
            case MALE   -> com.bosskin.i18n.AppText.msg("gender.MALE");
            case FEMALE -> com.bosskin.i18n.AppText.msg("gender.FEMALE");
            case OTHER  -> com.bosskin.i18n.AppText.msg("gender.OTHER");
        }),
        ExcelColumn.readOnlyI18n("excel.col.employee.dateOfBirth",    e -> e.getDateOfBirth() == null ? "" : e.getDateOfBirth().format(DATE_FMT)),
        ExcelColumn.readOnlyI18n("excel.col.employee.joinDate",       e -> e.getJoinDate() == null ? "" : e.getJoinDate().format(DATE_FMT)),
        ExcelColumn.readOnlyI18n("excel.col.employee.leaveDate",      e -> e.getLeaveDate() == null ? "" : e.getLeaveDate().format(DATE_FMT)),
        ExcelColumn.readOnlyI18n("excel.col.employee.departmentCode", e -> e.getDepartment() == null ? "" : e.getDepartment().getCode()),
        ExcelColumn.readOnlyI18n("excel.col.employee.departmentName", e -> e.getDepartment() == null ? "" : e.getDepartment().getName()),
        ExcelColumn.readOnlyI18n("excel.col.employee.positionCode",   e -> safePosition(e, false)),
        ExcelColumn.readOnlyI18n("excel.col.employee.positionName",   e -> safePosition(e, true)),
        ExcelColumn.readOnlyI18n("excel.col.employee.salaryGradeCode",e -> e.getSalaryGrade() == null ? "" : e.getSalaryGrade().getCode()),
        ExcelColumn.readOnlyI18n("excel.col.employee.status",         e -> e.getStatus() == null ? "" : switch (e.getStatus()) {
            case ACTIVE   -> "Đang làm";
            case INACTIVE -> "Nghỉ việc";
            case ON_LEAVE -> "Nghỉ phép";
        })
    );

    // ─── Sheet 2: Thông tin cá nhân & ngân hàng ──────────────────────────────

    private static final List<ExcelColumn<Employee>> PERSONAL_COLUMNS = List.of(
        ExcelColumn.readOnlyI18n("excel.col.employee.code",            Employee::getEmployeeCode),
        ExcelColumn.readOnlyI18n("excel.col.employee.fullName",        Employee::getFullName),
        ExcelColumn.readOnlyI18n("excel.col.employee.identityCard",    e -> SensitiveData.forViewer(e.getIdentityCard())),
        ExcelColumn.readOnlyI18n("excel.col.employee.address",         Employee::getAddress),
        ExcelColumn.readOnlyI18n("excel.col.employee.personalEmail",   Employee::getPersonalEmail),
        ExcelColumn.readOnlyI18n("excel.col.employee.bankAccount",     e -> SensitiveData.forViewer(e.getBankAccount())),
        ExcelColumn.readOnlyI18n("excel.col.employee.bankName",        Employee::getBankName),
        ExcelColumn.readOnlyI18n("excel.col.employee.contractSalary",  e -> e.getContractSalary() == null ? "" : e.getContractSalary().stripTrailingZeros().toPlainString()),
        ExcelColumn.readOnlyI18n("excel.col.employee.taxCode",           e -> SensitiveData.forViewer(e.getTaxCode())),
        ExcelColumn.readOnlyI18n("excel.col.employee.socialInsuranceNo", e -> SensitiveData.forViewer(e.getSocialInsuranceNo())),
        ExcelColumn.readOnlyI18n("excel.col.employee.healthInsurancePlace", Employee::getHealthInsurancePlace),
        ExcelColumn.readOnlyI18n("excel.col.employee.insuranceJoinDate", e -> e.getInsuranceJoinDate() == null ? "" : e.getInsuranceJoinDate().format(DATE_FMT))
    );

    @Transactional(readOnly = true)
    public ResponseEntity<byte[]> export(Long companyId, Long userId, Locale locale) {
        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, "EMPLOYEE_VIEW");

        List<Employee> employees = scopeIds.isEmpty()
            ? employeeRepo.findAllByCompanyIdFetchDepartment(companyId)
            : employeeRepo.findAllByCompanyIdAndDepartmentIdInFetchDepartment(companyId, scopeIds);

        return ExcelUtils.exportSheets("excel.file.employee", List.of(
            ExcelSheet.ofI18n("excel.sheet.employee.basic",    BASIC_COLUMNS,    employees),
            ExcelSheet.ofI18n("excel.sheet.employee.personal", PERSONAL_COLUMNS, employees)
        ), excelI18n, locale);
    }

    private static String safePosition(Employee e, boolean getName) {
        try {
            if (e.getPosition() == null) return "";
            return getName ? e.getPosition().getName() : e.getPosition().getCode();
        } catch (Exception ex) {
            return "";
        }
    }
}

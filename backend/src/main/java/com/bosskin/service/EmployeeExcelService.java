package com.bosskin.service;

import com.bosskin.entity.Employee;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.util.ExcelColumn;
import com.bosskin.util.ExcelSheet;
import com.bosskin.util.ExcelUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class EmployeeExcelService {

    private final EmployeeRepository employeeRepo;
    private final DeptScopeService   deptScopeService;

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    // ─── Sheet 1: Thông tin cơ bản ───────────────────────────────────────────

    private static final List<ExcelColumn<Employee>> BASIC_COLUMNS = List.of(
        ExcelColumn.readOnly("Mã NV (*)",       Employee::getEmployeeCode),
        ExcelColumn.readOnly("Họ và tên (*)",   Employee::getFullName),
        ExcelColumn.readOnly("Email (*)",        Employee::getEmail),
        ExcelColumn.readOnly("Số điện thoại",   Employee::getPhone),
        ExcelColumn.readOnly("Giới tính",        e -> e.getGender() == null ? "" : switch (e.getGender()) {
            case MALE   -> "Nam";
            case FEMALE -> "Nữ";
            case OTHER  -> "Khác";
        }),
        ExcelColumn.readOnly("Ngày sinh",        e -> e.getDateOfBirth() == null ? "" : e.getDateOfBirth().format(DATE_FMT)),
        ExcelColumn.readOnly("Ngày vào làm",     e -> e.getJoinDate() == null ? "" : e.getJoinDate().format(DATE_FMT)),
        ExcelColumn.readOnly("Ngày nghỉ",        e -> e.getLeaveDate() == null ? "" : e.getLeaveDate().format(DATE_FMT)),
        ExcelColumn.readOnly("Phòng ban (*)",    e -> e.getDepartment() == null ? "" : e.getDepartment().getCode()),
        ExcelColumn.readOnly("Tên phòng ban",    e -> e.getDepartment() == null ? "" : e.getDepartment().getName()),
        ExcelColumn.readOnly("Chức vụ",          e -> safePosition(e, false)),
        ExcelColumn.readOnly("Tên chức vụ",      e -> safePosition(e, true)),
        ExcelColumn.readOnly("Bậc lương",        e -> e.getSalaryGrade() == null ? "" : e.getSalaryGrade().getCode()),
        ExcelColumn.readOnly("Trạng thái",       e -> e.getStatus() == null ? "" : switch (e.getStatus()) {
            case ACTIVE   -> "Đang làm";
            case INACTIVE -> "Nghỉ việc";
            case ON_LEAVE -> "Nghỉ phép";
        })
    );

    // ─── Sheet 2: Thông tin cá nhân & ngân hàng ──────────────────────────────

    private static final List<ExcelColumn<Employee>> PERSONAL_COLUMNS = List.of(
        ExcelColumn.readOnly("Mã NV",            Employee::getEmployeeCode),
        ExcelColumn.readOnly("Họ và tên",        Employee::getFullName),
        ExcelColumn.readOnly("CCCD/CMND",        Employee::getIdentityCard),
        ExcelColumn.readOnly("Địa chỉ",          Employee::getAddress),
        ExcelColumn.readOnly("Email cá nhân",    Employee::getPersonalEmail),
        ExcelColumn.readOnly("Số tài khoản NH",  Employee::getBankAccount),
        ExcelColumn.readOnly("Ngân hàng",        Employee::getBankName),
        ExcelColumn.readOnly("Lương hợp đồng",   e -> e.getContractSalary() == null ? "" : e.getContractSalary().stripTrailingZeros().toPlainString())
    );

    @Transactional(readOnly = true)
    public ResponseEntity<byte[]> export(Long companyId, Long userId) {
        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, "EMPLOYEE_VIEW");

        List<Employee> employees = scopeIds.isEmpty()
            ? employeeRepo.findAllByCompanyIdFetchDepartment(companyId)
            : employeeRepo.findAllByCompanyIdAndDepartmentIdInFetchDepartment(companyId, scopeIds);

        return ExcelUtils.exportSheets("danh_sach_nhan_vien", List.of(
            ExcelSheet.of("Nhân viên",           BASIC_COLUMNS,    employees),
            ExcelSheet.of("Thông tin cá nhân",   PERSONAL_COLUMNS, employees)
        ));
    }

    /** Trả "" nếu position đã bị soft-delete (lazy proxy throw exception khi access). */
    private static String safePosition(Employee e, boolean getName) {
        try {
            if (e.getPosition() == null) return "";
            return getName ? e.getPosition().getName() : e.getPosition().getCode();
        } catch (Exception ex) {
            return "";
        }
    }
}

package com.bosskin.controller;

import com.bosskin.dto.EmployeeDTO;
import com.bosskin.dto.PageResponse;
import com.bosskin.entity.Employee;
import com.bosskin.entity.User;
import com.bosskin.service.EmployeeExcelService;
import com.bosskin.service.EmployeeImportService;
import com.bosskin.service.EmployeeService;
import com.bosskin.util.ExcelColumn;
import com.bosskin.util.ExcelI18n;
import com.bosskin.util.ExcelUtils;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Locale;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/employees")
@RequiredArgsConstructor
public class EmployeeController {

    private final EmployeeService       employeeService;
    private final EmployeeExcelService  employeeExcelService;
    private final EmployeeImportService employeeImportService;
    private final ExcelI18n             excelI18n;
    private final com.bosskin.audit.AuditService audit;

    // ── Sheet 1: import columns — i18n, map bất kỳ ngôn ngữ nào ──────────────
    private static final List<ExcelColumn<EmployeeDTO.ImportRow>> BASIC_IMPORT = List.of(
        ExcelColumn.ofI18n("excel.col.employee.code",           r -> r.getEmployeeCode(),   (r, v) -> r.setEmployeeCode(v)),
        ExcelColumn.ofI18n("excel.col.employee.fullName",       r -> r.getFullName(),       (r, v) -> r.setFullName(v)),
        ExcelColumn.ofI18n("excel.col.employee.email",          r -> r.getEmail(),          (r, v) -> r.setEmail(v)),
        ExcelColumn.ofI18n("excel.col.employee.phone",          r -> r.getPhone(),          (r, v) -> r.setPhone(v)),
        ExcelColumn.ofI18n("excel.col.employee.gender",         r -> r.getGender(),         (r, v) -> r.setGender(v)),
        ExcelColumn.ofI18n("excel.col.employee.dateOfBirth",    r -> r.getDateOfBirth(),    (r, v) -> r.setDateOfBirth(v)),
        ExcelColumn.ofI18n("excel.col.employee.joinDate",       r -> r.getJoinDate(),       (r, v) -> r.setJoinDate(v)),
        ExcelColumn.ofI18n("excel.col.employee.leaveDate",      r -> r.getLeaveDate(),      (r, v) -> r.setLeaveDate(v)),
        ExcelColumn.ofI18n("excel.col.employee.departmentCode", r -> r.getDepartmentCode(), (r, v) -> r.setDepartmentCode(v)),
        ExcelColumn.readOnlyI18n("excel.col.employee.departmentName", r -> null),
        ExcelColumn.ofI18n("excel.col.employee.positionCode",   r -> r.getPositionCode(),   (r, v) -> r.setPositionCode(v)),
        ExcelColumn.readOnlyI18n("excel.col.employee.positionName", r -> null),
        ExcelColumn.ofI18n("excel.col.employee.salaryGradeCode",r -> r.getSalaryGradeCode(),(r, v) -> r.setSalaryGradeCode(v)),
        ExcelColumn.ofI18n("excel.col.employee.status",         r -> r.getStatus(),         (r, v) -> r.setStatus(v))
    );

    // ── Sheet 2 ───────────────────────────────────────────────────────────────
    private static final List<ExcelColumn<EmployeeDTO.ImportRow>> PERSONAL_IMPORT = List.of(
        ExcelColumn.ofI18n("excel.col.employee.code",          r -> r.getEmployeeCode(),   (r, v) -> r.setEmployeeCode(v)),
        ExcelColumn.readOnlyI18n("excel.col.employee.fullName", r -> null),
        ExcelColumn.ofI18n("excel.col.employee.identityCard",  r -> r.getIdentityCard(),   (r, v) -> r.setIdentityCard(v)),
        ExcelColumn.ofI18n("excel.col.employee.address",       r -> r.getAddress(),        (r, v) -> r.setAddress(v)),
        ExcelColumn.ofI18n("excel.col.employee.personalEmail", r -> r.getPersonalEmail(),  (r, v) -> r.setPersonalEmail(v)),
        ExcelColumn.ofI18n("excel.col.employee.bankAccount",   r -> r.getBankAccount(),    (r, v) -> r.setBankAccount(v)),
        ExcelColumn.ofI18n("excel.col.employee.bankName",      r -> r.getBankName(),       (r, v) -> r.setBankName(v)),
        ExcelColumn.ofI18n("excel.col.employee.contractSalary",r -> r.getContractSalary(), (r, v) -> r.setContractSalary(v))
    );

    @GetMapping("/export")
    public ResponseEntity<byte[]> export(@AuthenticationPrincipal User user) {
        requirePermission(user, "EMPLOYEE_VIEW");
        Locale locale = LocaleContextHolder.getLocale();
        return employeeExcelService.export(user.getCompany().getId(), user.getId(), locale);
    }

    @PostMapping("/preview-import")
    public ResponseEntity<List<EmployeeDTO.ImportDiff>> previewImport(
            @AuthenticationPrincipal User user,
            @RequestParam("file") org.springframework.web.multipart.MultipartFile file) {
        requirePermission(user, "EMPLOYEE_CREATE");
        List<EmployeeDTO.ImportRow> sheet1 = ExcelUtils.importRowsByHeader(file, 0, BASIC_IMPORT,    EmployeeDTO.ImportRow::new, excelI18n);
        List<EmployeeDTO.ImportRow> sheet2 = ExcelUtils.importRowsByHeader(file, 1, PERSONAL_IMPORT, EmployeeDTO.ImportRow::new, excelI18n);
        List<EmployeeDTO.ImportRow> merged = merge(sheet1, sheet2);
        return ResponseEntity.ok(employeeImportService.previewImport(user.getCompany().getId(), user.getId(), merged));
    }

    @PostMapping("/import")
    public ResponseEntity<Void> importExcel(
            @AuthenticationPrincipal User user,
            @RequestParam("file") org.springframework.web.multipart.MultipartFile file) {
        requirePermission(user, "EMPLOYEE_CREATE");
        List<EmployeeDTO.ImportRow> sheet1 = ExcelUtils.importRowsByHeader(file, 0, BASIC_IMPORT,    EmployeeDTO.ImportRow::new, excelI18n);
        List<EmployeeDTO.ImportRow> sheet2 = ExcelUtils.importRowsByHeader(file, 1, PERSONAL_IMPORT, EmployeeDTO.ImportRow::new, excelI18n);
        List<EmployeeDTO.ImportRow> merged = merge(sheet1, sheet2);
        employeeImportService.importFromExcel(user.getCompany().getId(), user.getId(), merged);
        return ResponseEntity.ok().build();
    }

    /** Merge sheet2 vào sheet1 theo employeeCode. */
    private List<EmployeeDTO.ImportRow> merge(List<EmployeeDTO.ImportRow> sheet1,
                                              List<EmployeeDTO.ImportRow> sheet2) {
        Map<String, EmployeeDTO.ImportRow> byCode = new java.util.LinkedHashMap<>();
        for (EmployeeDTO.ImportRow r : sheet1) {
            if (r.getEmployeeCode() != null && !r.getEmployeeCode().isBlank())
                byCode.put(r.getEmployeeCode().trim(), r);
        }
        for (EmployeeDTO.ImportRow r2 : sheet2) {
            if (r2.getEmployeeCode() == null || r2.getEmployeeCode().isBlank()) continue;
            EmployeeDTO.ImportRow r1 = byCode.get(r2.getEmployeeCode().trim());
            if (r1 == null) continue;
            if (notBlank(r2.getIdentityCard()))   r1.setIdentityCard(r2.getIdentityCard());
            if (notBlank(r2.getAddress()))        r1.setAddress(r2.getAddress());
            if (notBlank(r2.getPersonalEmail()))  r1.setPersonalEmail(r2.getPersonalEmail());
            if (notBlank(r2.getBankAccount()))    r1.setBankAccount(r2.getBankAccount());
            if (notBlank(r2.getBankName()))       r1.setBankName(r2.getBankName());
            if (notBlank(r2.getContractSalary())) r1.setContractSalary(r2.getContractSalary());
        }
        return new java.util.ArrayList<>(byCode.values());
    }

    @GetMapping
    public ResponseEntity<PageResponse<EmployeeDTO.Response>> getAll(
        @AuthenticationPrincipal User user,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "20") int size,
        @RequestParam(required = false) String search,
        @RequestParam(required = false) Long departmentId,
        @RequestParam(required = false) Employee.Status status
    ) {
        requirePermission(user, "EMPLOYEE_VIEW");
        return ResponseEntity.ok(employeeService.findAll(user.getCompany().getId(), user.getId(), page, size, search, departmentId, status));
    }

    @GetMapping("/{id}")
    public ResponseEntity<EmployeeDTO.Response> getById(@PathVariable Long id, @AuthenticationPrincipal User user) {
        requirePermission(user, "EMPLOYEE_VIEW");
        return ResponseEntity.ok(employeeService.findById(id, user.getCompany().getId(), user.getId()));
    }

    @PostMapping
    public ResponseEntity<EmployeeDTO.Response> create(
        @Valid @RequestBody EmployeeDTO.CreateRequest request,
        @AuthenticationPrincipal User user
    ) {
        requirePermission(user, "EMPLOYEE_CREATE");
        return ResponseEntity.status(HttpStatus.CREATED).body(employeeService.create(request, user.getCompany().getId(), user.getId()));
    }

    @PutMapping("/{id}")
    public ResponseEntity<EmployeeDTO.Response> update(
        @PathVariable Long id,
        @Valid @RequestBody EmployeeDTO.UpdateRequest request,
        @AuthenticationPrincipal User user
    ) {
        requirePermission(user, "EMPLOYEE_UPDATE");
        return ResponseEntity.ok(employeeService.update(id, request, user.getCompany().getId(), user.getId()));
    }

    /** Gỡ thiết bị chấm công của nhân viên (V6). */
    @DeleteMapping("/{id}/device")
    public ResponseEntity<Void> unbindDevice(@PathVariable Long id, @AuthenticationPrincipal User user) {
        requirePermission(user, "EMPLOYEE_UPDATE");
        employeeService.unbindDevice(id, user.getCompany().getId());
        audit.log("DEVICE_UNBIND").entity("EMPLOYEE", id).save();
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id, @AuthenticationPrincipal User user) {
        requirePermission(user, "EMPLOYEE_DELETE");
        employeeService.delete(id, user.getCompany().getId(), user.getId());
        return ResponseEntity.noContent().build();
    }

    private static boolean notBlank(String v) { return v != null && !v.isBlank(); }

    private void requirePermission(User user, String perm) {
        if (user == null || !user.hasPermission(perm)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
    }
}

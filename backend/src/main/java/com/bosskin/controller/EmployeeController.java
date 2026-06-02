package com.bosskin.controller;

import com.bosskin.dto.EmployeeDTO;
import com.bosskin.dto.PageResponse;
import com.bosskin.entity.Employee;
import com.bosskin.entity.User;
import com.bosskin.service.EmployeeExcelService;
import com.bosskin.service.EmployeeImportService;
import com.bosskin.service.EmployeeService;
import com.bosskin.util.ExcelColumn;
import com.bosskin.util.ExcelUtils;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/employees")
@RequiredArgsConstructor
public class EmployeeController {

    private final EmployeeService      employeeService;
    private final EmployeeExcelService employeeExcelService;
    private final EmployeeImportService employeeImportService;

    // ── Sheet 1: thứ tự cột khớp với BASIC_COLUMNS trong EmployeeExcelService ──
    private static final List<ExcelColumn<EmployeeDTO.ImportRow>> BASIC_IMPORT = List.of(
        ExcelColumn.of("Mã NV (*)",      r -> r.getEmployeeCode(),   (r, v) -> r.setEmployeeCode(v)),
        ExcelColumn.of("Họ và tên (*)",  r -> r.getFullName(),       (r, v) -> r.setFullName(v)),
        ExcelColumn.of("Email (*)",       r -> r.getEmail(),          (r, v) -> r.setEmail(v)),
        ExcelColumn.of("Số điện thoại",  r -> r.getPhone(),          (r, v) -> r.setPhone(v)),
        ExcelColumn.of("Giới tính",      r -> r.getGender(),         (r, v) -> r.setGender(v)),
        ExcelColumn.of("Ngày sinh",      r -> r.getDateOfBirth(),    (r, v) -> r.setDateOfBirth(v)),
        ExcelColumn.of("Ngày vào làm",   r -> r.getJoinDate(),       (r, v) -> r.setJoinDate(v)),
        ExcelColumn.of("Ngày nghỉ",      r -> r.getLeaveDate(),      (r, v) -> r.setLeaveDate(v)),
        ExcelColumn.of("Phòng ban (*)",  r -> r.getDepartmentCode(), (r, v) -> r.setDepartmentCode(v)),
        ExcelColumn.readOnly("Tên phòng ban", r -> null),
        ExcelColumn.of("Chức vụ",        r -> r.getPositionCode(),   (r, v) -> r.setPositionCode(v)),
        ExcelColumn.readOnly("Tên chức vụ", r -> null),
        ExcelColumn.of("Bậc lương",      r -> r.getSalaryGradeCode(),(r, v) -> r.setSalaryGradeCode(v)),
        ExcelColumn.of("Trạng thái",     r -> r.getStatus(),         (r, v) -> r.setStatus(v))
    );

    // ── Sheet 2: thứ tự cột khớp với PERSONAL_COLUMNS ─────────────────────────
    private static final List<ExcelColumn<EmployeeDTO.ImportRow>> PERSONAL_IMPORT = List.of(
        ExcelColumn.of("Mã NV",          r -> r.getEmployeeCode(),   (r, v) -> r.setEmployeeCode(v)),
        ExcelColumn.readOnly("Họ và tên", r -> null),
        ExcelColumn.of("CCCD/CMND",      r -> r.getIdentityCard(),   (r, v) -> r.setIdentityCard(v)),
        ExcelColumn.of("Địa chỉ",        r -> r.getAddress(),        (r, v) -> r.setAddress(v)),
        ExcelColumn.of("Email cá nhân",  r -> r.getPersonalEmail(),  (r, v) -> r.setPersonalEmail(v)),
        ExcelColumn.of("Số tài khoản NH",r -> r.getBankAccount(),    (r, v) -> r.setBankAccount(v)),
        ExcelColumn.of("Ngân hàng",      r -> r.getBankName(),       (r, v) -> r.setBankName(v)),
        ExcelColumn.of("Lương hợp đồng", r -> r.getContractSalary(), (r, v) -> r.setContractSalary(v))
    );

    @GetMapping("/export")
    public ResponseEntity<byte[]> export(@AuthenticationPrincipal User user) {
        requirePermission(user, "EMPLOYEE_VIEW");
        return employeeExcelService.export(user.getCompany().getId(), user.getId());
    }

    @PostMapping("/preview-import")
    public ResponseEntity<List<EmployeeDTO.ImportDiff>> previewImport(
            @AuthenticationPrincipal User user,
            @RequestParam("file") org.springframework.web.multipart.MultipartFile file) {
        requirePermission(user, "EMPLOYEE_CREATE");
        List<EmployeeDTO.ImportRow> sheet1 = ExcelUtils.importRows(file, 0, BASIC_IMPORT,    EmployeeDTO.ImportRow::new);
        List<EmployeeDTO.ImportRow> sheet2 = ExcelUtils.importRows(file, 1, PERSONAL_IMPORT, EmployeeDTO.ImportRow::new);
        List<EmployeeDTO.ImportRow> merged = merge(sheet1, sheet2);
        return ResponseEntity.ok(employeeImportService.previewImport(user.getCompany().getId(), user.getId(), merged));
    }

    @PostMapping("/import")
    public ResponseEntity<Void> importExcel(
            @AuthenticationPrincipal User user,
            @RequestParam("file") org.springframework.web.multipart.MultipartFile file) {
        requirePermission(user, "EMPLOYEE_CREATE");
        List<EmployeeDTO.ImportRow> sheet1 = ExcelUtils.importRows(file, 0, BASIC_IMPORT,    EmployeeDTO.ImportRow::new);
        List<EmployeeDTO.ImportRow> sheet2 = ExcelUtils.importRows(file, 1, PERSONAL_IMPORT, EmployeeDTO.ImportRow::new);
        List<EmployeeDTO.ImportRow> merged = merge(sheet1, sheet2);
        employeeImportService.importFromExcel(user.getCompany().getId(), user.getId(), merged);
        return ResponseEntity.ok().build();
    }

    /** Merge sheet2 vào sheet1 theo employeeCode — giữ sheet1 làm chính. */
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
            if (notBlank(r2.getIdentityCard()))  r1.setIdentityCard(r2.getIdentityCard());
            if (notBlank(r2.getAddress()))       r1.setAddress(r2.getAddress());
            if (notBlank(r2.getPersonalEmail())) r1.setPersonalEmail(r2.getPersonalEmail());
            if (notBlank(r2.getBankAccount()))   r1.setBankAccount(r2.getBankAccount());
            if (notBlank(r2.getBankName()))      r1.setBankName(r2.getBankName());
            if (notBlank(r2.getContractSalary()))r1.setContractSalary(r2.getContractSalary());
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

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id, @AuthenticationPrincipal User user) {
        requirePermission(user, "EMPLOYEE_DELETE");
        employeeService.delete(id, user.getCompany().getId(), user.getId());
        return ResponseEntity.noContent().build();
    }

    private static boolean notBlank(String v) { return v != null && !v.isBlank(); }

    private void requirePermission(User user, String perm) {
        if (!user.hasPermission(perm)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền: " + perm);
        }
    }
}

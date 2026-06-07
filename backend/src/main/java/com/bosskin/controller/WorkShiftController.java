package com.bosskin.controller;

import com.bosskin.dto.ShiftDTO;
import com.bosskin.dto.EmployeeDTO;
import com.bosskin.entity.User;
import com.bosskin.repository.DepartmentRepository;
import com.bosskin.service.DeptScopeService;
import com.bosskin.service.EmployeeService;
import com.bosskin.service.WorkShiftService;
import com.bosskin.service.ShiftExcelService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/v1/shifts")
@RequiredArgsConstructor
public class WorkShiftController {

    private final WorkShiftService shiftService;
    private final DeptScopeService deptScopeService;
    private final EmployeeService employeeService;
    private final ShiftExcelService shiftExcelService;
    private final com.bosskin.service.CompanySettingService companySettingService;
    private final DepartmentRepository departmentRepository;

    // ── Export / Import Excel ────────────────────────────────────────────

    @GetMapping("/export")
    public ResponseEntity<byte[]> export(
            @AuthenticationPrincipal User user,
            @RequestParam(required = false) String from,
            @RequestParam(required = false) String to,
            @RequestParam(required = false) Integer year,
            @RequestParam(required = false) Integer month,
            @RequestParam(required = false) List<Long> departmentIds) {
        requireShiftView(user);
        LocalDate dateFrom, dateTo;
        if (from != null && to != null) {
            dateFrom = LocalDate.parse(from);
            dateTo = LocalDate.parse(to);
        } else {
            LocalDate now = LocalDate.now();
            int y = year != null ? year : now.getYear();
            int m = month != null ? month : now.getMonthValue();
            int cutoffDay = companySettingService.getByCompanyId(user.getCompany().getId())
                .getPayroll().getPayrollCutoffDay();
            com.bosskin.core.PayrollPeriod period = com.bosskin.core.PayrollPeriod.of(y, m, cutoffDay);
            dateFrom = period.from();
            dateTo = period.to();
        }
        // Áp dụng scope của user: nếu user không xem được toàn công ty → lọc theo scope
        Set<Long> userScope = deptScopeService.resolvedScopes(user.getId(), "SHIFT_VIEW");
        List<Long> effectiveDeptIds;
        if (userScope.isEmpty()) {
            // User xem toàn công ty → dùng filter từ frontend (nếu có)
            effectiveDeptIds = (departmentIds != null && !departmentIds.isEmpty()) ? departmentIds : null;
        } else {
            // User chỉ xem scope nhất định → intersect với filter frontend
            Set<Long> scopeSet = userScope.stream().filter(id -> id != null && id > 0).collect(Collectors.toSet());
            if (departmentIds != null && !departmentIds.isEmpty()) {
                scopeSet.retainAll(new java.util.HashSet<>(departmentIds));
            }
            effectiveDeptIds = new ArrayList<>(scopeSet);
        }
        return shiftExcelService.export(user.getCompany().getId(), dateFrom, dateTo, effectiveDeptIds);
    }

    @GetMapping("/export-list")
    public ResponseEntity<byte[]> exportList(@AuthenticationPrincipal User user) {
        requireShiftView(user);
        return shiftExcelService.exportShiftListOnly(user.getCompany().getId());
    }

    @PostMapping("/preview-import")
    public ResponseEntity<List<com.bosskin.service.ShiftExcelService.ShiftDiff>> previewImport(
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal User user) {
        requireShiftManage(user);
        return ResponseEntity.ok(shiftExcelService.previewImport(user.getCompany().getId(), file));
    }

    @PostMapping("/import")
    public ResponseEntity<Map<String, Integer>> importExcel(
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal User user) {
        requireShiftManage(user);
        return ResponseEntity.ok(shiftExcelService.importFromExcel(user.getCompany().getId(), file));
    }

    @PostMapping("/preview-import-assignments")
    public ResponseEntity<com.bosskin.service.ShiftExcelService.ImportPreviewBundle> previewImportAssignments(
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal User user) {
        requireShiftManage(user);
        return ResponseEntity.ok(shiftExcelService.previewAssignments(user.getCompany().getId(), user.getId(), file));
    }

    @PostMapping("/import-assignments")
    public ResponseEntity<Map<String, Integer>> importAssignments(
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal User user) {
        requireShiftManage(user);
        return ResponseEntity.ok(shiftExcelService.importAssignments(user.getCompany().getId(), user.getId(), file));
    }

    // ── Shift templates ─────────────────────────────────────────────────

    @GetMapping
    public List<ShiftDTO.ShiftResponse> list(@AuthenticationPrincipal User user) {
        requireShiftView(user);
        List<ShiftDTO.ShiftResponse> shifts = shiftService.listShifts(user.getCompany().getId());
        Set<Long> scope = deptScopeService.resolvedScopes(user.getId(), "SHIFT_VIEW");
        if (scope.isEmpty()) {
            return shifts;
        }

        boolean selfOnly = scope.contains(DeptScopeService.SCOPE_SELF_ONLY);
        Set<Long> deptScope = scope.stream()
            .filter(id -> id != null && id > 0)
            .collect(java.util.stream.Collectors.toSet());

        java.util.LinkedHashMap<Long, ShiftDTO.ShiftResponse> merged = new java.util.LinkedHashMap<>();

        if (!deptScope.isEmpty()) {
            shifts.stream()
                .filter(s -> s.getDepartments() != null && s.getDepartments().stream().anyMatch(d -> deptScope.contains(d.getId())))
                .forEach(s -> merged.put(s.getId(), s));
        }

        if (selfOnly && user.getEmployee() != null) {
            shiftService.listAssignedShiftsForEmployee(user.getCompany().getId(), user.getEmployee().getId())
                .forEach(s -> merged.put(s.getId(), s));
        }

        return new java.util.ArrayList<>(merged.values());
    }

    @GetMapping("/department/{deptId}")
    public List<ShiftDTO.ShiftResponse> listByDept(
            @PathVariable Long deptId,
            @AuthenticationPrincipal User user) {
        requireShiftView(user);
        departmentRepository.findByIdAndCompanyId(deptId, user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.department.not_found"));
        Set<Long> selectedDeptScope = deptScopeService.expandDepartmentsWithDescendants(Set.of(deptId));
        if (selectedDeptScope.isEmpty()) {
            return List.of();
        }
        Set<Long> scope = deptScopeService.resolvedScopes(user.getId(), "SHIFT_VIEW");
        if (!scope.isEmpty()) {
            Set<Long> deptScope = scope.stream()
                .filter(id -> id != null && id > 0)
                .collect(java.util.stream.Collectors.toSet());
            if (deptScope.isEmpty()) {
                return List.of();
            }
            deptScope.retainAll(selectedDeptScope);
            if (deptScope.isEmpty()) {
                return List.of();
            }
            return shiftService.listByDepartments(deptScope, user.getCompany().getId());
        }
        return shiftService.listByDepartments(selectedDeptScope, user.getCompany().getId());
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ShiftDTO.ShiftResponse create(
            @Valid @RequestBody ShiftDTO.ShiftRequest req,
            @AuthenticationPrincipal User user) {
        requireShiftManage(user);
        return shiftService.createShift(user.getCompany().getId(), req);
    }

    @PutMapping("/{id}")
    public ShiftDTO.ShiftResponse update(
            @PathVariable Long id,
            @Valid @RequestBody ShiftDTO.ShiftRequest req,
            @AuthenticationPrincipal User user) {
        requireShiftManage(user);
        return shiftService.updateShift(id, user.getCompany().getId(), req);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id, @AuthenticationPrincipal User user) {
        requireShiftManage(user);
        shiftService.deleteShift(id, user.getCompany().getId());
    }

    // ── Assignments ─────────────────────────────────────────────────────

    @GetMapping("/assignments")
    public List<ShiftDTO.AssignResponse> assignments(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @AuthenticationPrincipal User user) {
        requireShiftView(user);
        return shiftService.listAssignments(user.getCompany().getId(), from, to);
    }

    @GetMapping("/assignments/employee/{empId}")
    public List<ShiftDTO.AssignResponse> assignmentsByEmployee(
            @PathVariable Long empId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @AuthenticationPrincipal User user) {
        requireShiftView(user);
        return shiftService.listAssignmentsByEmployee(empId, user.getCompany().getId(), from, to);
    }

    @GetMapping("/employees")
    public List<EmployeeDTO.Response> employeesInShiftScope(@AuthenticationPrincipal User user) {
        requireShiftView(user);
        return employeeService.findAllForShiftScope(user.getCompany().getId(), user.getId());
    }

    @PostMapping("/assignments")
    @ResponseStatus(HttpStatus.CREATED)
    public ShiftDTO.AssignResponse assign(
            @Valid @RequestBody ShiftDTO.AssignRequest req,
            @AuthenticationPrincipal User user) {
        requireShiftManage(user);
        return shiftService.assign(user.getCompany().getId(), req, user.getId());
    }

    @PostMapping("/assignments/bulk")
    public ResponseEntity<Map<String, Integer>> bulkAssign(
            @Valid @RequestBody ShiftDTO.BulkAssignRequest req,
            @AuthenticationPrincipal User user) {
        requireShiftManage(user);
        int count = shiftService.bulkAssign(user.getCompany().getId(), req, user.getId());
        return ResponseEntity.ok(Map.of("assigned", count));
    }

    @DeleteMapping("/assignments/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteAssignmentById(@PathVariable Long id, @AuthenticationPrincipal User user) {
        requireShiftManage(user);
        shiftService.deleteAssignmentById(id, user.getCompany().getId());
    }

    @DeleteMapping("/assignments")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteAssignment(
            @RequestParam Long employeeId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate workDate,
            @AuthenticationPrincipal User user) {
        requireShiftManage(user);
        shiftService.deleteAssignment(employeeId, workDate, user.getCompany().getId());
    }

    private void requireShiftView(User user) {
        if (user == null || (!user.hasPermission("SHIFT_VIEW") && !user.hasPermission("SHIFT_MANAGE"))) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
    }

    private void requireShiftManage(User user) {
        if (user == null || !user.hasPermission("SHIFT_MANAGE")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
    }
}

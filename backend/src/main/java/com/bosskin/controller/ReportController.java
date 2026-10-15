package com.bosskin.controller;

import com.bosskin.entity.User;
import com.bosskin.service.ReportService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.util.Locale;

/**
 * REST endpoints for HRM analytics reports.
 * All reports are exported to Excel. Permission required: report.view
 */
@RestController
@RequestMapping("/api/v1/reports")
@RequiredArgsConstructor
public class ReportController {

    private final ReportService reportService;
    private final com.bosskin.service.DeptScopeService deptScopeService;

    private void checkPermission(User user) {
        if (!user.can("REPORT_VIEW")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
    }

    /**
     * Báo cáo xuất dữ liệu của module → cần thêm quyền xem module đó và tôn trọng phạm vi phòng ban
     * (trước đây chỉ kiểm REPORT_VIEW: người có quyền báo cáo tải được lương toàn công ty).
     * Phạm vi giới hạn → bắt buộc chọn một phòng ban trong phạm vi; chỉ-bản-thân → không xuất báo cáo.
     */
    private void checkModule(User user, String modulePerm, Long deptId) {
        checkPermission(user);
        if (user.getCompanyId() == null || !user.can(modulePerm)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        java.util.Set<Long> scope = deptScopeService.resolvedScopes(user.getId(), modulePerm);
        if (scope.isEmpty()) return; // toàn công ty
        if (deptId == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.report.department_required");
        }
        if (!scope.contains(deptId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.department_scope");
        }
    }

    /** Employee headcount — all or filtered by department */
    @GetMapping("/employee-headcount")
    public ResponseEntity<byte[]> employeeHeadcount(
            @RequestParam(required = false) Long deptId,
            @AuthenticationPrincipal User user,
            Locale locale) {
        checkModule(user, "EMPLOYEE_VIEW", deptId);
        return reportService.reportEmployeeHeadcount(user.getCompanyId(), user.getId(), deptId, locale);
    }

    /** New hires in a date range */
    @GetMapping("/new-hires")
    public ResponseEntity<byte[]> newHires(
            @RequestParam String from,
            @RequestParam String to,
            @RequestParam(required = false) Long deptId,
            @AuthenticationPrincipal User user,
            Locale locale) {
        checkModule(user, "EMPLOYEE_VIEW", deptId);
        return reportService.reportNewHires(user.getCompanyId(), user.getId(),
                parseDate(from), parseDate(to), deptId, locale);
    }

    /** Resigned employees in a date range */
    @GetMapping("/resigned")
    public ResponseEntity<byte[]> resigned(
            @RequestParam String from,
            @RequestParam String to,
            @RequestParam(required = false) Long deptId,
            @AuthenticationPrincipal User user,
            Locale locale) {
        checkModule(user, "EMPLOYEE_VIEW", deptId);
        return reportService.reportResigned(user.getCompanyId(), user.getId(),
                parseDate(from), parseDate(to), deptId, locale);
    }

    /** Monthly attendance summary */
    @GetMapping("/attendance-summary")
    public ResponseEntity<byte[]> attendanceSummary(
            @RequestParam int year,
            @RequestParam int month,
            @RequestParam(required = false) Long deptId,
            @AuthenticationPrincipal User user,
            Locale locale) {
        checkModule(user, "ATTENDANCE_VIEW", deptId);
        return reportService.reportAttendanceSummary(user.getCompanyId(), user.getId(),
                year, month, deptId, locale);
    }

    /** Monthly overtime summary */
    @GetMapping("/overtime-summary")
    public ResponseEntity<byte[]> overtimeSummary(
            @RequestParam int year,
            @RequestParam int month,
            @RequestParam(required = false) Long deptId,
            @AuthenticationPrincipal User user,
            Locale locale) {
        checkModule(user, "ATTENDANCE_VIEW", deptId);
        return reportService.reportOvertimeSummary(user.getCompanyId(), user.getId(),
                year, month, deptId, locale);
    }

    /** Bước M: nhân viên tham gia bảo hiểm (MST / CCCD / sổ BHXH che nếu thiếu EMPLOYEE_SENSITIVE_VIEW) */
    @GetMapping("/insured-employees")
    public ResponseEntity<byte[]> insuredEmployees(
            @RequestParam(required = false) Long deptId,
            @AuthenticationPrincipal User user,
            Locale locale) {
        checkModule(user, "EMPLOYEE_VIEW", deptId);
        return reportService.reportInsuredEmployees(user.getCompanyId(), user.getId(), deptId, locale);
    }

    /** Bước M: người phụ thuộc giảm trừ gia cảnh */
    @GetMapping("/dependents")
    public ResponseEntity<byte[]> dependents(
            @RequestParam(required = false) Long deptId,
            @AuthenticationPrincipal User user,
            Locale locale) {
        checkModule(user, "EMPLOYEE_VIEW", deptId);
        return reportService.reportDependents(user.getCompanyId(), user.getId(), deptId, locale);
    }

    /** Monthly payroll cost summary */
    @GetMapping("/payroll-summary")
    public ResponseEntity<byte[]> payrollSummary(
            @RequestParam int year,
            @RequestParam int month,
            @RequestParam(required = false) Long deptId,
            @AuthenticationPrincipal User user,
            Locale locale) {
        checkModule(user, "PAYROLL_VIEW", deptId);
        return reportService.reportPayrollSummary(user.getCompanyId(), user.getId(),
                year, month, deptId, locale);
    }

    /** Yearly overview — all modules, with charts */
    @GetMapping("/yearly-overview")
    public ResponseEntity<byte[]> yearlyOverview(
            @RequestParam int year,
            @RequestParam(required = false) Long deptId,
            @AuthenticationPrincipal User user,
            Locale locale) {
        // File gồm cả số liệu nhân sự và nghỉ phép nên cần đủ quyền xem của cả ba module
        checkModule(user, "PAYROLL_VIEW", deptId);
        checkModule(user, "EMPLOYEE_VIEW", deptId);
        checkModule(user, "LEAVE_VIEW", deptId);
        return reportService.reportYearlyOverview(user.getCompanyId(), user.getId(),
                year, deptId, locale);
    }

    /** Leave balance summary per employee */
    @GetMapping("/leave-balance")
    public ResponseEntity<byte[]> leaveBalance(
            @RequestParam(required = false) Long deptId,
            @AuthenticationPrincipal User user,
            Locale locale) {
        checkModule(user, "LEAVE_VIEW", deptId);
        return reportService.reportLeaveBalance(user.getCompanyId(), user.getId(), deptId, locale);
    }

    /** Leave usage in a date range */
    @GetMapping("/leave-usage")
    public ResponseEntity<byte[]> leaveUsage(
            @RequestParam String from,
            @RequestParam String to,
            @RequestParam(required = false) Long deptId,
            @AuthenticationPrincipal User user,
            Locale locale) {
        checkModule(user, "LEAVE_VIEW", deptId);
        return reportService.reportLeaveUsage(user.getCompanyId(), user.getId(),
                parseDate(from), parseDate(to), deptId, locale);
    }

    private LocalDate parseDate(String s) {
        try {
            return LocalDate.parse(s);
        } catch (Exception e) {
            throw new ResponseStatusException(
                org.springframework.http.HttpStatus.BAD_REQUEST,
                "error.date.invalid_format");
        }
    }
}

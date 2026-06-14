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

    private void checkPermission(User user) {
        if (!user.can("REPORT_VIEW")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
    }

    /** Employee headcount — all or filtered by department */
    @GetMapping("/employee-headcount")
    public ResponseEntity<byte[]> employeeHeadcount(
            @RequestParam(required = false) Long deptId,
            @AuthenticationPrincipal User user) {
        checkPermission(user);
        return reportService.reportEmployeeHeadcount(user.getCompanyId(), user.getId(), deptId);
    }

    /** New hires in a date range */
    @GetMapping("/new-hires")
    public ResponseEntity<byte[]> newHires(
            @RequestParam String from,
            @RequestParam String to,
            @RequestParam(required = false) Long deptId,
            @AuthenticationPrincipal User user) {
        checkPermission(user);
        return reportService.reportNewHires(user.getCompanyId(), user.getId(),
                parseDate(from), parseDate(to), deptId);
    }

    /** Resigned employees in a date range */
    @GetMapping("/resigned")
    public ResponseEntity<byte[]> resigned(
            @RequestParam String from,
            @RequestParam String to,
            @RequestParam(required = false) Long deptId,
            @AuthenticationPrincipal User user) {
        checkPermission(user);
        return reportService.reportResigned(user.getCompanyId(), user.getId(),
                parseDate(from), parseDate(to), deptId);
    }

    /** Monthly attendance summary */
    @GetMapping("/attendance-summary")
    public ResponseEntity<byte[]> attendanceSummary(
            @RequestParam int year,
            @RequestParam int month,
            @RequestParam(required = false) Long deptId,
            @AuthenticationPrincipal User user) {
        checkPermission(user);
        return reportService.reportAttendanceSummary(user.getCompanyId(), user.getId(),
                year, month, deptId);
    }

    /** Monthly overtime summary */
    @GetMapping("/overtime-summary")
    public ResponseEntity<byte[]> overtimeSummary(
            @RequestParam int year,
            @RequestParam int month,
            @RequestParam(required = false) Long deptId,
            @AuthenticationPrincipal User user) {
        checkPermission(user);
        return reportService.reportOvertimeSummary(user.getCompanyId(), user.getId(),
                year, month, deptId);
    }

    /** Monthly payroll cost summary */
    @GetMapping("/payroll-summary")
    public ResponseEntity<byte[]> payrollSummary(
            @RequestParam int year,
            @RequestParam int month,
            @RequestParam(required = false) Long deptId,
            @AuthenticationPrincipal User user,
            Locale locale) {
        checkPermission(user);
        return reportService.reportPayrollSummary(user.getCompanyId(), user.getId(),
                year, month, deptId, locale);
    }

    /** Leave balance summary per employee */
    @GetMapping("/leave-balance")
    public ResponseEntity<byte[]> leaveBalance(
            @RequestParam(required = false) Long deptId,
            @AuthenticationPrincipal User user) {
        checkPermission(user);
        return reportService.reportLeaveBalance(user.getCompanyId(), user.getId(), deptId);
    }

    /** Leave usage in a date range */
    @GetMapping("/leave-usage")
    public ResponseEntity<byte[]> leaveUsage(
            @RequestParam String from,
            @RequestParam String to,
            @RequestParam(required = false) Long deptId,
            @AuthenticationPrincipal User user) {
        checkPermission(user);
        return reportService.reportLeaveUsage(user.getCompanyId(), user.getId(),
                parseDate(from), parseDate(to), deptId);
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

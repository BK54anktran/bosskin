package com.bosskin.controller;

import com.bosskin.dto.DashboardDTO;
import com.bosskin.entity.User;
import com.bosskin.service.DashboardService;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;

@RestController
@RequestMapping("/api/v1/dashboard")
@RequiredArgsConstructor
public class DashboardController {

    private final DashboardService dashboardService;

    @GetMapping
    public ResponseEntity<DashboardDTO.Response> getDashboard(
        @AuthenticationPrincipal User user,
        @RequestParam(required = false) Long departmentId,
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date
    ) {
        if (!user.can("dashboard.view")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        return ResponseEntity.ok(dashboardService.getDashboard(user, departmentId, date));
    }

    @GetMapping("/analytics")
    public ResponseEntity<DashboardDTO.AnalyticsResponse> getAnalytics(
        @AuthenticationPrincipal User user,
        @RequestParam(required = false) Long departmentId,
        @RequestParam(defaultValue = "#{T(java.time.LocalDate).now().getYear()}") int year
    ) {
        if (!user.can("dashboard.view")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        return ResponseEntity.ok(dashboardService.getAnalytics(user, departmentId, year));
    }

    @GetMapping("/kpi")
    public ResponseEntity<DashboardDTO.KpiResponse> getKpi(
        @AuthenticationPrincipal User user,
        @RequestParam(required = false) Long departmentId,
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date
    ) {
        if (!user.can("dashboard.view")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        return ResponseEntity.ok(dashboardService.getKpi(user, departmentId, date));
    }

    @GetMapping("/risks")
    public ResponseEntity<DashboardDTO.RiskResponse> getRisks(
        @AuthenticationPrincipal User user,
        @RequestParam(required = false) Long departmentId,
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date
    ) {
        if (!user.can("dashboard.view")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        return ResponseEntity.ok(dashboardService.getRisks(user, departmentId, date));
    }

    @GetMapping("/range")
    public ResponseEntity<DashboardDTO.RangeResponse> getRangeDashboard(
        @AuthenticationPrincipal User user,
        @RequestParam(required = false) Long departmentId,
        @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
        @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to
    ) {
        if (!user.can("dashboard.view")) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
        if (from.isAfter(to)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.dashboard.invalid_range");
        }
        return ResponseEntity.ok(dashboardService.getRangeDashboard(user, departmentId, from, to));
    }
}

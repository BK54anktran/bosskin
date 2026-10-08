package com.bosskin.controller;

import com.bosskin.dto.PayrollDTO;
import com.bosskin.entity.Payroll;
import com.bosskin.entity.User;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.PayrollRepository;
import com.bosskin.repository.SalaryFormulaRepository;
import com.bosskin.service.DeptScopeService;
import com.bosskin.service.PayrollExcelService;
import com.bosskin.service.PayrollService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@RestController
@RequestMapping({"/api/v1/payrolls", "/api/v1/payroll"})
@RequiredArgsConstructor
public class PayrollController {

    private final PayrollService          payrollService;
    private final PayrollExcelService     payrollExcelService;
    private final PayrollRepository       payrollRepository;
    private final EmployeeRepository      employeeRepository;
    private final DeptScopeService        deptScopeService;
    private final SalaryFormulaRepository salaryFormulaRepository;

    @GetMapping
    public ResponseEntity<Page<PayrollDTO.Response>> getByMonth(
        @AuthenticationPrincipal User user,
        @RequestParam int year,
        @RequestParam int month,
        @RequestParam(required = false) Long departmentId,
        @RequestParam(required = false) Payroll.Status status,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "20") int size
    ) {
        requirePermission(user, "PAYROLL_VIEW");
        var pageable = PageRequest.of(page, size);
        Set<Long> selectedDeptScope = null;
        if (departmentId != null) {
            selectedDeptScope = deptScopeService.expandDepartmentsWithDescendants(Set.of(departmentId));
            if (selectedDeptScope.isEmpty()) {
                return ResponseEntity.ok(Page.empty());
            }
        }
        Set<Long> scopeIds = deptScopeService.resolvedScopes(user.getId(), "PAYROLL_VIEW");
        Page<Payroll> payrolls;
        Long companyId = user.getCompany().getId();
        if (!scopeIds.isEmpty()) {
            Set<Long> deptScope = scopeIds.stream().filter(id -> id != null && id > 0).collect(Collectors.toSet());
            if (deptScope.isEmpty()) return ResponseEntity.ok(Page.empty());
            if (selectedDeptScope != null) {
                Set<Long> intersection = new HashSet<>(deptScope);
                intersection.retainAll(selectedDeptScope);
                if (intersection.isEmpty()) return ResponseEntity.ok(Page.empty());
                deptScope = intersection;
            }
            payrolls = payrollRepository.findByMonthWithDeptScope(year, month, companyId, deptScope, status, pageable);
        } else if (selectedDeptScope != null) {
            payrolls = payrollRepository.findByMonthWithDeptScope(year, month, companyId, selectedDeptScope, status, pageable);
        } else {
            payrolls = payrollRepository.findByMonthWithFilters(year, month, companyId, departmentId, status, pageable);
        }
        return ResponseEntity.ok(payrolls.map(PayrollDTO.Response::from));
    }

    @GetMapping("/export-payslips")
    public ResponseEntity<byte[]> exportPayslips(
        @AuthenticationPrincipal User user,
        @RequestParam int year,
        @RequestParam int month,
        @RequestParam(required = false) List<Long> ids
    ) {
        requirePermission(user, "PAYROLL_VIEW");
        return payrollExcelService.exportPayslips(
            user.getCompany().getId(), user.getId(), year, month, ids
        );
    }

    @PostMapping("/generate")
    public ResponseEntity<PayrollDTO.Response> generate(
        @AuthenticationPrincipal User user,
        @RequestBody Map<String, Object> body
    ) {
        requirePermission(user, "PAYROLL_CREATE");
        Long employeeId = Long.valueOf(body.get("employeeId").toString());
        var employee = employeeRepository.findByIdAndCompanyId(employeeId, user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
        requireViewScope(user, employee.getDepartment().getId());
        int year  = Integer.parseInt(body.get("year").toString());
        int month = Integer.parseInt(body.get("month").toString());
        Long formulaId = body.containsKey("formulaId") && body.get("formulaId") != null
            ? Long.valueOf(body.get("formulaId").toString()) : null;
        requireFormulaCompany(formulaId, user.getCompany().getId());
        Payroll p = payrollService.generatePayroll(employeeId, year, month, formulaId);
        return ResponseEntity.status(HttpStatus.CREATED).body(PayrollDTO.Response.from(p));
    }

    @PatchMapping("/{id}")
    public ResponseEntity<PayrollDTO.Response> patchDraft(
        @PathVariable Long id,
        @AuthenticationPrincipal User user,
        @RequestBody PayrollDTO.PatchRequest body
    ) {
        requirePermission(user, "PAYROLL_CREATE");
        Payroll p = payrollRepository.findByIdAndCompanyId(id, user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.payroll.not_found"));
        requireViewScope(user, p.getEmployee().getDepartment().getId());
        return ResponseEntity.ok(PayrollDTO.Response.from(
            payrollService.patchDraft(id, body.getAllowance(), body.getBonus(), body.getOtherDeductions(), body.getNote(), body.getCustomFormula())
        ));
    }

    @PostMapping("/{id}/approve")
    public ResponseEntity<PayrollDTO.Response> approve(
        @PathVariable Long id,
        @AuthenticationPrincipal User user
    ) {
        requirePermission(user, "PAYROLL_APPROVE");
        Payroll p = payrollRepository.findByIdAndCompanyId(id, user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.payroll.not_found"));
        requireViewScope(user, p.getEmployee().getDepartment().getId());
        return ResponseEntity.ok(PayrollDTO.Response.from(payrollService.approve(id, user.getId())));
    }

    @PostMapping("/{id}/pay")
    public ResponseEntity<PayrollDTO.Response> markAsPaid(
        @PathVariable Long id,
        @AuthenticationPrincipal User user
    ) {
        requirePermission(user, "PAYROLL_PAY");
        Payroll p = payrollRepository.findByIdAndCompanyId(id, user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.payroll.not_found"));
        requireViewScope(user, p.getEmployee().getDepartment().getId());
        return ResponseEntity.ok(PayrollDTO.Response.from(payrollService.markAsPaid(id, user.getId())));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(
        @PathVariable Long id,
        @AuthenticationPrincipal User user
    ) {
        requirePermission(user, "PAYROLL_CREATE");
        Payroll p = payrollRepository.findByIdAndCompanyId(id, user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.payroll.not_found"));
        requireViewScope(user, p.getEmployee().getDepartment().getId());
        if (p.getStatus() != Payroll.Status.DRAFT) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.payroll.delete_non_draft");
        }
        payrollRepository.delete(p);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/recalculate")
    public ResponseEntity<PayrollDTO.Response> recalculate(
        @PathVariable Long id,
        @RequestBody(required = false) Map<String, Object> body,
        @AuthenticationPrincipal User user
    ) {
        requirePermission(user, "PAYROLL_CREATE");
        Payroll p = payrollRepository.findByIdAndCompanyId(id, user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.payroll.not_found"));
        requireViewScope(user, p.getEmployee().getDepartment().getId());
        if (p.getStatus() != Payroll.Status.DRAFT) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.payroll.recalculate_non_draft");
        }
        Long formulaId = (body != null && body.containsKey("formulaId") && body.get("formulaId") != null)
            ? Long.valueOf(body.get("formulaId").toString()) : null;
        requireFormulaCompany(formulaId, user.getCompany().getId());
        Payroll recalculated = payrollService.recalculate(p.getId(), formulaId);
        return ResponseEntity.ok(PayrollDTO.Response.from(recalculated));
    }

    @GetMapping("/by-employee/{employeeId}")
    public ResponseEntity<List<PayrollDTO.Response>> getByEmployee(
        @AuthenticationPrincipal User user,
        @PathVariable Long employeeId,
        @RequestParam(required = false) Integer year
    ) {
        requirePermission(user, "PAYROLL_VIEW");
        var employee = employeeRepository.findByIdAndCompanyId(employeeId, user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
        requireViewScope(user, employee.getDepartment() != null ? employee.getDepartment().getId() : null);
        List<PayrollDTO.Response> result = payrollRepository.findSelfPayrolls(employeeId, year)
            .stream().map(PayrollDTO.Response::from).toList();
        return ResponseEntity.ok(result);
    }

    @GetMapping("/self")
    public ResponseEntity<List<PayrollDTO.Response>> getSelf(
        @AuthenticationPrincipal User user,
        @RequestParam(required = false) Integer year
    ) {
        requirePermission(user, "ATTENDANCE_SELF");
        if (user.getEmployee() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.user.employee_not_linked");
        }
        Long employeeId = user.getEmployee().getId();
        List<PayrollDTO.Response> result = payrollRepository.findSelfPayrolls(employeeId, year)
            .stream()
            .filter(p -> p.getStatus() != Payroll.Status.DRAFT)
            .map(PayrollDTO.Response::from).toList();
        return ResponseEntity.ok(result);
    }

    private void requirePermission(User user, String perm) {
        if (user == null || !user.hasPermission(normalizePermissionCode(perm))) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
    }

    private String normalizePermissionCode(String perm) {
        if (perm == null) return null;
        return perm.trim().toUpperCase().replace('.', '_');
    }

    private void requireViewScope(User user, Long deptId) {
        Set<Long> scope = deptScopeService.resolvedScopes(user.getId(), "PAYROLL_VIEW");
        if (!scope.isEmpty() && !scope.contains(deptId))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.department_scope");
    }

    private void requireFormulaCompany(Long formulaId, Long companyId) {
        if (formulaId == null) return;
        var formula = salaryFormulaRepository.findById(formulaId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.salary_formula.not_found"));
        var grade = formula.getSalaryGrade();
        Long gradeCompanyId = grade.getCompany() != null ? grade.getCompany().getId()
            : (grade.getDepartment() != null ? grade.getDepartment().getCompany().getId() : null);
        if (gradeCompanyId == null || !gradeCompanyId.equals(companyId))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
    }
}

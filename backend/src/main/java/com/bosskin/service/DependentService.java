package com.bosskin.service;

import com.bosskin.audit.AuditService;
import com.bosskin.core.SensitiveData;
import com.bosskin.dto.DependentDTO;
import com.bosskin.entity.Employee;
import com.bosskin.entity.EmployeeDependent;
import com.bosskin.repository.EmployeeDependentRepository;
import com.bosskin.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Clock;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Bước M — người phụ thuộc của nhân viên. Xem theo quyền / phạm vi EMPLOYEE_VIEW, sửa cần EMPLOYEE_UPDATE.
 * MST / CCCD người phụ thuộc che như dữ liệu nhạy cảm của nhân viên ({@link SensitiveData}).
 * Payroll đếm số người được giảm trừ trong tháng của kỳ qua {@link #countDeductible}.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class DependentService {

    private final EmployeeDependentRepository repository;
    private final EmployeeRepository employeeRepository;
    private final DeptScopeService deptScopeService;
    private final AuditService audit;
    private final Clock clock;

    public List<DependentDTO.Response> listByEmployee(Long companyId, Long userId, Long employeeId) {
        Employee e = employee(companyId, employeeId);
        requireScope(userId, e);
        return repository.findByEmployeeIdAndDeletedFalseOrderByDeductionFromAscIdAsc(e.getId()).stream()
            .map(d -> toResponse(d, true)).toList();
    }

    /** Nhân viên xem người phụ thuộc của chính mình (không che). */
    public List<DependentDTO.Response> listSelf(Long userId) {
        Employee e = employeeRepository.findByUserIdFetch(userId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
        return repository.findByEmployeeIdAndDeletedFalseOrderByDeductionFromAscIdAsc(e.getId()).stream()
            .map(d -> toResponse(d, false)).toList();
    }

    @Transactional
    public DependentDTO.Response create(Long companyId, Long userId, DependentDTO.Upsert req) {
        Employee e = employee(companyId, req.getEmployeeId());
        requireScope(userId, e);
        EmployeeDependent d = EmployeeDependent.builder().companyId(companyId).employee(e).build();
        apply(d, req, null);
        d = repository.save(d);
        audit.log("DEPENDENT_CREATE").entity("EMPLOYEE", e.getId())
            .summary(e.getEmployeeCode() + " " + e.getFullName() + " — " + d.getFullName())
            .detail(snapshot(d)).save();
        return toResponse(d, true);
    }

    @Transactional
    public DependentDTO.Response update(Long companyId, Long userId, Long id, DependentDTO.Upsert req) {
        EmployeeDependent d = getOrThrow(companyId, id);
        requireScope(userId, d.getEmployee());
        if (req.getEmployeeId() != null && !req.getEmployeeId().equals(d.getEmployee().getId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.dependent.employee_change");
        }
        Map<String, Object> before = snapshot(d);
        apply(d, req, d);
        d = repository.save(d);
        audit.log("DEPENDENT_UPDATE").entity("EMPLOYEE", d.getEmployee().getId())
            .summary(d.getEmployee().getEmployeeCode() + " " + d.getEmployee().getFullName() + " — " + d.getFullName())
            .detail(AuditService.map("before", before, "after", snapshot(d))).save();
        return toResponse(d, true);
    }

    @Transactional
    public void delete(Long companyId, Long userId, Long id) {
        EmployeeDependent d = getOrThrow(companyId, id);
        requireScope(userId, d.getEmployee());
        d.setDeleted(true);
        repository.save(d);
        audit.log("DEPENDENT_DELETE").entity("EMPLOYEE", d.getEmployee().getId())
            .summary(d.getEmployee().getEmployeeCode() + " " + d.getEmployee().getFullName() + " — " + d.getFullName())
            .detail(snapshot(d)).save();
    }

    /** Số người phụ thuộc được giảm trừ của nhân viên trong tháng {@code ym}. */
    public int countDeductible(Long employeeId, YearMonth ym) {
        return (int) repository.countDeductible(employeeId, ym.atDay(1));
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    private void apply(EmployeeDependent d, DependentDTO.Upsert req, EmployeeDependent current) {
        LocalDate from = req.getDeductionFrom().withDayOfMonth(1);
        LocalDate to = req.getDeductionTo() == null ? null : req.getDeductionTo().withDayOfMonth(1);
        if (to != null && to.isBefore(from)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.dependent.invalid_period");
        }
        d.setFullName(req.getFullName().trim());
        d.setRelationship(req.getRelationship());
        d.setDateOfBirth(req.getDateOfBirth());
        d.setTaxCode(trim(SensitiveData.incoming(current == null ? null : current.getTaxCode(), req.getTaxCode())));
        d.setIdentityNo(trim(SensitiveData.incoming(current == null ? null : current.getIdentityNo(), req.getIdentityNo())));
        d.setDeductionFrom(from);
        d.setDeductionTo(to);
        if (req.getRegistrationStatus() != null) d.setRegistrationStatus(req.getRegistrationStatus());
        d.setNote(trim(req.getNote()));
    }

    private DependentDTO.Response toResponse(EmployeeDependent d, boolean maskForViewer) {
        Employee e = d.getEmployee();
        return DependentDTO.Response.builder()
            .id(d.getId()).employeeId(e.getId()).employeeCode(e.getEmployeeCode()).employeeName(e.getFullName())
            .fullName(d.getFullName()).relationship(d.getRelationship()).dateOfBirth(d.getDateOfBirth())
            .taxCode(maskForViewer ? SensitiveData.forViewer(d.getTaxCode()) : d.getTaxCode())
            .identityNo(maskForViewer ? SensitiveData.forViewer(d.getIdentityNo()) : d.getIdentityNo())
            .deductionFrom(d.getDeductionFrom()).deductionTo(d.getDeductionTo())
            .registrationStatus(d.getRegistrationStatus()).note(d.getNote())
            .activeNow(d.deductibleIn(YearMonth.now(clock)))
            .build();
    }

    private Employee employee(Long companyId, Long employeeId) {
        return employeeRepository.findByIdAndCompanyId(employeeId, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
    }

    private EmployeeDependent getOrThrow(Long companyId, Long id) {
        return repository.findByIdAndCompanyIdAndDeletedFalse(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.dependent.not_found"));
    }

    private void requireScope(Long userId, Employee e) {
        Set<Long> scope = deptScopeService.resolvedScopes(userId, "EMPLOYEE_VIEW");
        if (!scope.isEmpty() && (e.getDepartment() == null || !scope.contains(e.getDepartment().getId()))) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.department_scope");
        }
    }

    private static String trim(String v) {
        return v == null || v.isBlank() ? null : v.trim();
    }

    private static Map<String, Object> snapshot(EmployeeDependent d) {
        return AuditService.map("name", d.getFullName(), "relationship", d.getRelationship().name(),
            "from", d.getDeductionFrom(), "to", d.getDeductionTo(), "status", d.getRegistrationStatus().name());
    }
}

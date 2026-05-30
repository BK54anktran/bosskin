package com.bosskin.controller;

import com.bosskin.entity.Employee;
import com.bosskin.entity.SalaryHistory;
import com.bosskin.entity.User;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.SalaryHistoryRepository;
import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.*;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequestMapping("/api/v1/salary-histories")
@RequiredArgsConstructor
public class SalaryHistoryController {

    private final SalaryHistoryRepository salaryHistoryRepository;
    private final EmployeeRepository      employeeRepository;

    @GetMapping
    public ResponseEntity<List<SalaryHistoryDTO>> getByEmployee(
        @AuthenticationPrincipal User user,
        @RequestParam Long employeeId
    ) {
        requirePermission(user, "PAYROLL_VIEW");
        employeeRepository.findByIdAndCompanyId(employeeId, user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy nhân viên"));
        List<SalaryHistoryDTO> result = salaryHistoryRepository
            .findByEmployeeIdOrderByEffectiveDateDesc(employeeId)
            .stream().map(SalaryHistoryDTO::from).toList();
        return ResponseEntity.ok(result);
    }

    @PostMapping
    public ResponseEntity<SalaryHistoryDTO> create(
        @AuthenticationPrincipal User user,
        @RequestBody SalaryHistoryRequest body
    ) {
        requirePermission(user, "PAYROLL_CREATE");
        Employee employee = employeeRepository.findByIdAndCompanyId(body.getEmployeeId(), user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy nhân viên"));
        SalaryHistory sh = SalaryHistory.builder()
            .employee(employee)
            .baseSalary(body.getBaseSalary())
            .effectiveDate(body.getEffectiveDate())
            .note(body.getNote())
            .build();
        return ResponseEntity.status(HttpStatus.CREATED).body(SalaryHistoryDTO.from(salaryHistoryRepository.save(sh)));
    }

    @PutMapping("/{id}")
    public ResponseEntity<SalaryHistoryDTO> update(
        @PathVariable Long id,
        @AuthenticationPrincipal User user,
        @RequestBody SalaryHistoryRequest body
    ) {
        requirePermission(user, "PAYROLL_CREATE");
        SalaryHistory sh = salaryHistoryRepository.findById(id)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy lịch sử lương"));
        if (!sh.getEmployee().getCompany().getId().equals(user.getCompany().getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền");
        }
        if (body.getBaseSalary() != null) sh.setBaseSalary(body.getBaseSalary());
        if (body.getEffectiveDate() != null) sh.setEffectiveDate(body.getEffectiveDate());
        sh.setNote(body.getNote());
        return ResponseEntity.ok(SalaryHistoryDTO.from(salaryHistoryRepository.save(sh)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(
        @PathVariable Long id,
        @AuthenticationPrincipal User user
    ) {
        requirePermission(user, "PAYROLL_CREATE");
        SalaryHistory sh = salaryHistoryRepository.findById(id)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy lịch sử lương"));
        if (!sh.getEmployee().getCompany().getId().equals(user.getCompany().getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền");
        }
        salaryHistoryRepository.delete(sh);
        return ResponseEntity.noContent().build();
    }

    private void requirePermission(User user, String perm) {
        if (!user.hasPermission(perm)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền: " + perm);
        }
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class SalaryHistoryRequest {
        private Long       employeeId;
        private BigDecimal baseSalary;
        @JsonFormat(pattern = "yyyy-MM-dd")
        private LocalDate  effectiveDate;
        private String     note;
    }

    @Getter @Builder
    public static class SalaryHistoryDTO {
        private Long       id;
        private Long       employeeId;
        private String     employeeName;
        private BigDecimal baseSalary;
        @JsonFormat(pattern = "yyyy-MM-dd")
        private LocalDate  effectiveDate;
        private String     note;
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
        private LocalDateTime createdAt;

        public static SalaryHistoryDTO from(SalaryHistory sh) {
            return SalaryHistoryDTO.builder()
                .id(sh.getId())
                .employeeId(sh.getEmployee().getId())
                .employeeName(sh.getEmployee().getFullName())
                .baseSalary(sh.getBaseSalary())
                .effectiveDate(sh.getEffectiveDate())
                .note(sh.getNote())
                .createdAt(sh.getCreatedAt())
                .build();
        }
    }
}

package com.bosskin.controller;

import com.bosskin.entity.Company;
import com.bosskin.entity.Department;
import com.bosskin.entity.SalaryGrade;
import com.bosskin.entity.User;
import com.bosskin.repository.DepartmentRepository;
import com.bosskin.repository.EmployeeJobHistoryRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.SalaryGradeRepository;
import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.*;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/v1/salary-grades")
@RequiredArgsConstructor
public class SalaryGradeController {

    private final SalaryGradeRepository gradeRepo;
    private final DepartmentRepository departmentRepo;
    private final EmployeeRepository employeeRepo;
    private final EmployeeJobHistoryRepository jobHistoryRepo;

    @GetMapping
    public ResponseEntity<List<SalaryGradeDTO>> list(
            @AuthenticationPrincipal User user,
            @RequestParam(required = false) Long departmentId
    ) {
        requirePermission(user, "PAYROLL_VIEW");
        Long companyId = user.getCompany().getId();
        List<SalaryGrade> grades = departmentId != null
                ? gradeRepo.findByDepartmentIdInOrDepartmentIsNull(collectSubtree(departmentId, companyId), companyId)
                : gradeRepo.findByCompanyId(companyId);
        return ResponseEntity.ok(grades.stream().map(SalaryGradeDTO::from).toList());
    }

    @PostMapping
    public ResponseEntity<SalaryGradeDTO> create(
            @AuthenticationPrincipal User user,
            @RequestBody SalaryGradeRequest body
    ) {
        requirePermission(user, "PAYROLL_CREATE");
        Long companyId = user.getCompany().getId();
        Company company = user.getCompany();

        Department department = null;
        if (body.getDepartmentId() != null) {
            department = departmentRepo.findByIdAndCompanyId(body.getDepartmentId(), companyId)
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.department.not_found"));
        }

        SalaryGrade.PayType payType;
        try {
            payType = SalaryGrade.PayType.valueOf(body.getPayType());
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.salary_grade.invalid_pay_type");
        }

        boolean duplicate = body.getDepartmentId() != null
                ? gradeRepo.findByDepartmentIdAndCode(body.getDepartmentId(), body.getCode()).isPresent()
                : gradeRepo.findByCompanyIdAndDepartmentIsNullAndCode(companyId, body.getCode()).isPresent();
        if (duplicate) throw new ResponseStatusException(HttpStatus.CONFLICT, "error.salary_grade.duplicate_code");

        SalaryGrade grade = SalaryGrade.builder()
                .company(company)
                .department(department)
                .code(body.getCode())
                .name(body.getName())
                .payType(payType)
                .baseRate(body.getBaseRate())
                .build();
        return ResponseEntity.status(HttpStatus.CREATED).body(SalaryGradeDTO.from(gradeRepo.save(grade)));
    }

    @PutMapping("/{id}")
    public ResponseEntity<SalaryGradeDTO> update(
            @PathVariable Long id,
            @AuthenticationPrincipal User user,
            @RequestBody SalaryGradeRequest body
    ) {
        requirePermission(user, "PAYROLL_CREATE");
        SalaryGrade grade = gradeRepo.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.salary_grade.not_found"));
        requireSameCompany(grade, user);
        if (body.getName() != null) grade.setName(body.getName());
        if (body.getBaseRate() != null) grade.setBaseRate(body.getBaseRate());
        if (body.getPayType() != null) {
            try {
                grade.setPayType(SalaryGrade.PayType.valueOf(body.getPayType()));
            } catch (Exception e) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.salary_grade.invalid_pay_type");
            }
        }
        return ResponseEntity.ok(SalaryGradeDTO.from(gradeRepo.save(grade)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(
            @PathVariable Long id,
            @AuthenticationPrincipal User user
    ) {
        requirePermission(user, "PAYROLL_CREATE");
        SalaryGrade grade = gradeRepo.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.salary_grade.not_found"));
        requireSameCompany(grade, user);
        // Bậc còn được NV / quá trình công tác dùng mà xoá mềm thì mọi chỗ nạp NV đó lỗi 500 (EntityNotFound)
        if (employeeRepo.countBySalaryGradeId(id) > 0 || jobHistoryRepo.countUsingSalaryGrade(id) > 0) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.salary_grade.in_use");
        }
        gradeRepo.delete(grade);
        return ResponseEntity.noContent().build();
    }

    /** BFS: collect departmentId + tất cả con cháu, chỉ trong phạm vi company */
    private List<Long> collectSubtree(Long rootId, Long companyId) {
        List<Long> result = new ArrayList<>();
        List<Long> frontier = new ArrayList<>();
        frontier.add(rootId);
        while (!frontier.isEmpty()) {
            result.addAll(frontier);
            List<Department> children = departmentRepo.findByParentIdInAndCompanyId(frontier, companyId);
            frontier = children.stream().map(Department::getId).collect(Collectors.toList());
        }
        return result;
    }

    private void requirePermission(User user, String perm) {
        if (user == null || !user.hasPermission(perm)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
    }

    private void requireSameCompany(SalaryGrade grade, User user) {
        Long gradeCompanyId = grade.getCompany() != null ? grade.getCompany().getId()
                : (grade.getDepartment() != null ? grade.getDepartment().getCompany().getId() : null);
        if (gradeCompanyId != null && !gradeCompanyId.equals(user.getCompany().getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
        }
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class SalaryGradeRequest {
        private Long departmentId;
        private String code;
        private String name;
        private String payType;
        private BigDecimal baseRate;
    }

    @Getter @Builder
    public static class SalaryGradeDTO {
        private Long id;
        private Long companyId;
        private Long departmentId;
        private String departmentName;
        private String code;
        private String name;
        private String payType;
        private BigDecimal baseRate;
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
        private LocalDateTime createdAt;

        public static SalaryGradeDTO from(SalaryGrade g) {
            return SalaryGradeDTO.builder()
                    .id(g.getId())
                    .companyId(g.getCompany() != null ? g.getCompany().getId() : null)
                    .departmentId(g.getDepartment() != null ? g.getDepartment().getId() : null)
                    .departmentName(g.getDepartment() != null ? g.getDepartment().getName() : null)
                    .code(g.getCode())
                    .name(g.getName())
                    .payType(g.getPayType().name())
                    .baseRate(g.getBaseRate())
                    .createdAt(g.getCreatedAt())
                    .build();
        }
    }
}

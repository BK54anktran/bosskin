package com.bosskin.controller;

import com.bosskin.entity.Department;
import com.bosskin.entity.SalaryGrade;
import com.bosskin.entity.User;
import com.bosskin.repository.DepartmentRepository;
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

    @GetMapping
    public ResponseEntity<List<SalaryGradeDTO>> list(
            @AuthenticationPrincipal User user,
            @RequestParam(required = false) Long departmentId
    ) {
        requirePermission(user, "PAYROLL_VIEW");
        Long companyId = user.getCompany().getId();
        List<SalaryGrade> grades = departmentId != null
                ? gradeRepo.findByDepartmentIdInOrDepartmentIsNull(collectSubtree(departmentId, companyId))
                : gradeRepo.findByCompanyId(companyId);
        return ResponseEntity.ok(grades.stream().map(SalaryGradeDTO::from).toList());
    }

    @PostMapping
    public ResponseEntity<SalaryGradeDTO> create(
            @AuthenticationPrincipal User user,
            @RequestBody SalaryGradeRequest body
    ) {
        requirePermission(user, "PAYROLL_CREATE");

        Department department = null;
        if (body.getDepartmentId() != null) {
            department = departmentRepo.findByIdAndCompanyId(body.getDepartmentId(), user.getCompany().getId())
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy phòng ban"));
        }

        SalaryGrade.PayType payType;
        try {
            payType = SalaryGrade.PayType.valueOf(body.getPayType());
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "pay_type không hợp lệ: " + body.getPayType());
        }

        // Check duplicate code trong cùng scope (dept hoặc toàn công ty)
        boolean duplicate = body.getDepartmentId() != null
                ? gradeRepo.findByDepartmentIdAndCode(body.getDepartmentId(), body.getCode()).isPresent()
                : gradeRepo.findByDepartmentIsNullAndCode(body.getCode()).isPresent();
        if (duplicate) throw new ResponseStatusException(HttpStatus.CONFLICT,
                "Mã bậc lương '" + body.getCode() + "' đã tồn tại trong phạm vi này");

        SalaryGrade grade = SalaryGrade.builder()
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
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy bậc lương"));
        requireSameCompany(grade, user);
        if (body.getName() != null) grade.setName(body.getName());
        if (body.getBaseRate() != null) grade.setBaseRate(body.getBaseRate());
        if (body.getPayType() != null) {
            try {
                grade.setPayType(SalaryGrade.PayType.valueOf(body.getPayType()));
            } catch (Exception e) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "pay_type không hợp lệ");
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
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Không tìm thấy bậc lương"));
        requireSameCompany(grade, user);
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
        if (grade.getDepartment() != null &&
                !grade.getDepartment().getCompany().getId().equals(user.getCompany().getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền");
        }
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor
    public static class SalaryGradeRequest {
        private Long departmentId; // null = toàn công ty
        private String code;
        private String name;
        private String payType;
        private BigDecimal baseRate;
    }

    @Getter @Builder
    public static class SalaryGradeDTO {
        private Long id;
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

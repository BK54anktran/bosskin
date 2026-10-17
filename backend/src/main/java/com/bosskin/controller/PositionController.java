package com.bosskin.controller;

import com.bosskin.dto.PositionDTO;
import com.bosskin.entity.Department;
import com.bosskin.entity.Position;
import com.bosskin.entity.User;
import com.bosskin.repository.DepartmentRepository;
import com.bosskin.repository.EmployeeJobHistoryRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.PositionRepository;
import com.bosskin.service.DeptScopeService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Set;

@RestController
@RequestMapping("/api/v1/positions")
@RequiredArgsConstructor
public class PositionController {

    private final PositionRepository positionRepository;
    private final DepartmentRepository departmentRepository;
    private final EmployeeRepository employeeRepository;
    private final EmployeeJobHistoryRepository jobHistoryRepository;
    private final DeptScopeService deptScopeService;

    @GetMapping
    public ResponseEntity<List<PositionDTO.Response>> getAll(
            @RequestParam(required = false) Long departmentId,
            @AuthenticationPrincipal User user) {
        requirePermission(user, "DEPARTMENT_VIEW");
        Long companyId = user.getCompany().getId();
        // Có departmentId: chức vụ của phòng ban đó + chức vụ chung
        var positions = departmentId != null
            ? positionRepository.findUsableInDepartment(departmentId, companyId)
            : positionRepository.findByCompanyId(companyId);
        return ResponseEntity.ok(positions.stream().map(this::toResponse).toList());
    }

    @PostMapping
    public ResponseEntity<PositionDTO.Response> create(
            @Valid @RequestBody PositionDTO.CreateRequest req,
            @AuthenticationPrincipal User user) {
        requirePermission(user, "POSITION_MANAGE");
        requireViewScope(user, req.getDepartmentId());
        Long companyId = user.getCompany().getId();
        if (positionRepository.existsByCodeAndCompanyId(req.getCode(), companyId)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.position.code_duplicate");
        }
        Department dept = resolveDept(req.getDepartmentId(), companyId);

        Position pos = Position.builder()
            .name(req.getName())
            .code(req.getCode().toUpperCase())
            .company(user.getCompany())
            .department(dept)
            .description(req.getDescription())
            .build();
        return ResponseEntity.status(HttpStatus.CREATED).body(toResponse(positionRepository.save(pos)));
    }

    @PutMapping("/{id}")
    public ResponseEntity<PositionDTO.Response> update(
            @PathVariable Long id,
            @Valid @RequestBody PositionDTO.CreateRequest req,
            @AuthenticationPrincipal User user) {
        requirePermission(user, "POSITION_MANAGE");
        requireViewScope(user, req.getDepartmentId());
        Long companyId = user.getCompany().getId();
        Position pos = positionRepository.findByIdAndCompanyId(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.position.not_found"));
        if (positionRepository.existsByCodeAndCompanyIdAndIdNot(req.getCode(), companyId, id)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.position.code_duplicate");
        }
        Department dept = resolveDept(req.getDepartmentId(), companyId);

        pos.setName(req.getName());
        pos.setCode(req.getCode().toUpperCase());
        pos.setDepartment(dept);
        pos.setDescription(req.getDescription());
        return ResponseEntity.ok(toResponse(positionRepository.save(pos)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(
            @PathVariable Long id,
            @AuthenticationPrincipal User user) {
        requirePermission(user, "POSITION_MANAGE");
        Position pos = positionRepository.findByIdAndCompanyId(id, user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.position.not_found"));
        requireViewScope(user, pos.getDepartment() == null ? null : pos.getDepartment().getId());
        if (employeeRepository.countByPositionIdAndCompanyId(pos.getId(), user.getCompany().getId()) > 0) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.position.has_employees");
        }
        if (jobHistoryRepository.countUsingPosition(pos.getId()) > 0) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.position.in_use");
        }
        positionRepository.delete(pos);
        return ResponseEntity.noContent().build();
    }

    private void requirePermission(User user, String perm) {
        if (user == null || !user.hasPermission(perm))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
    }

    private Department resolveDept(Long departmentId, Long companyId) {
        if (departmentId == null) return null;
        return departmentRepository.findByIdAndCompanyId(departmentId, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.department.not_found"));
    }

    /** deptId null = chức vụ chung: chỉ người có phạm vi toàn công ty mới tạo / sửa / xoá. */
    private void requireViewScope(User user, Long deptId) {
        Set<Long> scope = deptScopeService.resolvedScopes(user.getId(), "DEPARTMENT_VIEW");
        if (!scope.isEmpty() && (deptId == null || !scope.contains(deptId)))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.department_scope");
    }

    private PositionDTO.Response toResponse(Position p) {
        return PositionDTO.Response.builder()
            .id(p.getId())
            .name(p.getName())
            .code(p.getCode())
            .departmentId(p.getDepartment() != null ? p.getDepartment().getId() : null)
            .departmentName(p.getDepartment() != null ? p.getDepartment().getName() : null)
            .common(p.getDepartment() == null)
            .description(p.getDescription())
            .build();
    }
}

package com.bosskin.controller;

import com.bosskin.dto.PositionDTO;
import com.bosskin.entity.Department;
import com.bosskin.entity.Position;
import com.bosskin.entity.User;
import com.bosskin.repository.DepartmentRepository;
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
    private final DeptScopeService deptScopeService;

    @GetMapping
    public ResponseEntity<List<PositionDTO.Response>> getAll(
            @RequestParam(required = false) Long departmentId,
            @AuthenticationPrincipal User user) {
        requirePermission(user, "DEPARTMENT_VIEW");
        Long companyId = user.getCompany().getId();
        var positions = departmentId != null
            ? positionRepository.findByDepartmentIdAndDepartmentCompanyId(departmentId, companyId)
            : positionRepository.findByDepartmentCompanyId(companyId);
        return ResponseEntity.ok(positions.stream().map(this::toResponse).toList());
    }

    @PostMapping
    public ResponseEntity<PositionDTO.Response> create(
            @Valid @RequestBody PositionDTO.CreateRequest req,
            @AuthenticationPrincipal User user) {
        requirePermission(user, "POSITION_MANAGE");
        requireViewScope(user, req.getDepartmentId());
        Long companyId = user.getCompany().getId();
        if (positionRepository.existsByCodeAndDepartmentCompanyId(req.getCode(), companyId)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Mã chức vụ đã tồn tại");
        }
        Department dept = departmentRepository.findByIdAndCompanyId(req.getDepartmentId(), companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Phòng ban không tồn tại"));

        Position pos = Position.builder()
            .name(req.getName())
            .code(req.getCode().toUpperCase())
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
        Position pos = positionRepository.findByIdAndDepartmentCompanyId(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Chức vụ không tồn tại"));
        if (positionRepository.existsByCodeAndDepartmentCompanyIdAndIdNot(req.getCode(), companyId, id)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Mã chức vụ đã tồn tại");
        }
        Department dept = departmentRepository.findByIdAndCompanyId(req.getDepartmentId(), companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Phòng ban không tồn tại"));

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
        Position pos = positionRepository.findByIdAndDepartmentCompanyId(id, user.getCompany().getId())
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Chức vụ không tồn tại"));
        requireViewScope(user, pos.getDepartment().getId());
        if (employeeRepository.countByPositionIdAndCompanyId(pos.getId(), user.getCompany().getId()) > 0) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Chức vụ còn nhân viên, không thể xóa");
        }
        positionRepository.delete(pos);
        return ResponseEntity.noContent().build();
    }

    private void requirePermission(User user, String perm) {
        if (!user.hasPermission(perm))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền: " + perm);
    }

    private void requireViewScope(User user, Long deptId) {
        Set<Long> scope = deptScopeService.resolvedScopes(user.getId(), "DEPARTMENT_VIEW");
        if (!scope.isEmpty() && !scope.contains(deptId))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền thao tác phòng ban này");
    }

    private PositionDTO.Response toResponse(Position p) {
        return PositionDTO.Response.builder()
            .id(p.getId())
            .name(p.getName())
            .code(p.getCode())
            .departmentId(p.getDepartment().getId())
            .departmentName(p.getDepartment().getName())
            .description(p.getDescription())
            .build();
    }
}

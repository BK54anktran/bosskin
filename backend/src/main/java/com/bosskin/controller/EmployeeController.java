package com.bosskin.controller;

import com.bosskin.dto.EmployeeDTO;
import com.bosskin.dto.PageResponse;
import com.bosskin.entity.Employee;
import com.bosskin.entity.User;
import com.bosskin.service.EmployeeService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/v1/employees")
@RequiredArgsConstructor
public class EmployeeController {

    private final EmployeeService employeeService;

    @GetMapping
    public ResponseEntity<PageResponse<EmployeeDTO.Response>> getAll(
        @AuthenticationPrincipal User user,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "20") int size,
        @RequestParam(required = false) String search,
        @RequestParam(required = false) Long departmentId,
        @RequestParam(required = false) Employee.Status status
    ) {
        requirePermission(user, "EMPLOYEE_VIEW");
        return ResponseEntity.ok(employeeService.findAll(user.getCompany().getId(), user.getId(), page, size, search, departmentId, status));
    }

    @GetMapping("/{id}")
    public ResponseEntity<EmployeeDTO.Response> getById(@PathVariable Long id, @AuthenticationPrincipal User user) {
        requirePermission(user, "EMPLOYEE_VIEW");
        return ResponseEntity.ok(employeeService.findById(id, user.getCompany().getId(), user.getId()));
    }

    @PostMapping
    public ResponseEntity<EmployeeDTO.Response> create(
        @Valid @RequestBody EmployeeDTO.CreateRequest request,
        @AuthenticationPrincipal User user
    ) {
        requirePermission(user, "EMPLOYEE_CREATE");
        return ResponseEntity.status(HttpStatus.CREATED).body(employeeService.create(request, user.getCompany().getId(), user.getId()));
    }

    @PutMapping("/{id}")
    public ResponseEntity<EmployeeDTO.Response> update(
        @PathVariable Long id,
        @Valid @RequestBody EmployeeDTO.UpdateRequest request,
        @AuthenticationPrincipal User user
    ) {
        requirePermission(user, "EMPLOYEE_UPDATE");
        return ResponseEntity.ok(employeeService.update(id, request, user.getCompany().getId(), user.getId()));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id, @AuthenticationPrincipal User user) {
        requirePermission(user, "EMPLOYEE_DELETE");
        employeeService.delete(id, user.getCompany().getId(), user.getId());
        return ResponseEntity.noContent().build();
    }

    private void requirePermission(User user, String perm) {
        if (!user.hasPermission(perm)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền: " + perm);
        }
    }
}

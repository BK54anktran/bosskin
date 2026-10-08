package com.bosskin.controller;

import com.bosskin.dto.EmployeeLocationDTO;
import com.bosskin.entity.Employee;
import com.bosskin.entity.EmployeeLocation;
import com.bosskin.entity.User;
import com.bosskin.repository.EmployeeLocationRepository;
import com.bosskin.repository.EmployeeRepository;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@RestController
@RequestMapping("/api/v1/employees/{employeeId}/locations")
@RequiredArgsConstructor
public class EmployeeLocationController {

    private final EmployeeLocationRepository locationRepo;
    private final EmployeeRepository employeeRepo;

    @GetMapping
    public ResponseEntity<List<EmployeeLocationDTO.Response>> list(
            @PathVariable Long employeeId,
            @AuthenticationPrincipal User user) {
        requirePermission(user, "EMPLOYEE_VIEW");
        getEmployeeOrThrow(employeeId, user.getCompanyId());
        return ResponseEntity.ok(locationRepo.findByEmployeeId(employeeId)
                .stream().map(this::toResponse).toList());
    }

    @PostMapping
    public ResponseEntity<EmployeeLocationDTO.Response> create(
            @PathVariable Long employeeId,
            @AuthenticationPrincipal User user,
            @Valid @RequestBody EmployeeLocationDTO.Upsert body) {
        requirePermission(user, "EMPLOYEE_UPDATE");
        Employee emp = getEmployeeOrThrow(employeeId, user.getCompanyId());
        EmployeeLocation loc = EmployeeLocation.builder()
                .employee(emp)
                .name(body.getName())
                .latitude(body.getLatitude())
                .longitude(body.getLongitude())
                .radiusMeters(body.getRadiusMeters())
                .build();
        return ResponseEntity.status(HttpStatus.CREATED).body(toResponse(locationRepo.save(loc)));
    }

    @PutMapping("/{locationId}")
    public ResponseEntity<EmployeeLocationDTO.Response> update(
            @PathVariable Long employeeId,
            @PathVariable Long locationId,
            @AuthenticationPrincipal User user,
            @Valid @RequestBody EmployeeLocationDTO.Upsert body) {
        requirePermission(user, "EMPLOYEE_UPDATE");
        getEmployeeOrThrow(employeeId, user.getCompanyId());
        EmployeeLocation loc = locationRepo.findById(locationId)
                .filter(l -> l.getEmployee().getId().equals(employeeId))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.location.not_found"));
        loc.setName(body.getName());
        loc.setLatitude(body.getLatitude());
        loc.setLongitude(body.getLongitude());
        loc.setRadiusMeters(body.getRadiusMeters());
        return ResponseEntity.ok(toResponse(locationRepo.save(loc)));
    }

    @DeleteMapping("/{locationId}")
    public ResponseEntity<Void> delete(
            @PathVariable Long employeeId,
            @PathVariable Long locationId,
            @AuthenticationPrincipal User user) {
        requirePermission(user, "EMPLOYEE_UPDATE");
        getEmployeeOrThrow(employeeId, user.getCompanyId());
        EmployeeLocation loc = locationRepo.findById(locationId)
                .filter(l -> l.getEmployee().getId().equals(employeeId))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.location.not_found"));
        locationRepo.delete(loc);
        return ResponseEntity.noContent().build();
    }

    private Employee getEmployeeOrThrow(Long employeeId, Long companyId) {
        return employeeRepo.findByIdAndCompanyId(employeeId, companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.employee.not_found"));
    }

    private void requirePermission(User user, String perm) {
        if (user == null || !user.hasPermission(perm))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied");
    }

    private EmployeeLocationDTO.Response toResponse(EmployeeLocation loc) {
        return EmployeeLocationDTO.Response.builder()
                .id(loc.getId())
                .name(loc.getName())
                .latitude(loc.getLatitude())
                .longitude(loc.getLongitude())
                .radiusMeters(loc.getRadiusMeters())
                .build();
    }
}

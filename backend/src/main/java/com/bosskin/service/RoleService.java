package com.bosskin.service;

import com.bosskin.entity.Permission;
import com.bosskin.entity.Role;
import com.bosskin.repository.CompanyRepository;
import com.bosskin.repository.DepartmentRepository;
import com.bosskin.repository.PermissionRepository;
import com.bosskin.repository.RoleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RoleService {

    private final RoleRepository roleRepository;
    private final CompanyRepository companyRepository;
    private final DepartmentRepository departmentRepository;
    private final PermissionRepository permissionRepository;
    private final PermissionConsistencyService permissionConsistencyService;

    public List<Role> findByCompany(Long companyId) {
        return roleRepository.findByCompanyId(companyId);
    }

    @Transactional
    public Role create(
        Long companyId,
        String name,
        String description,
        List<String> permissionCodes,
        Boolean roleViewAllCompany,
        Long roleViewDepartmentId
    ) {
        if (roleRepository.existsByCompanyIdAndName(companyId, name)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.role.name_duplicate");
        }
        var company = companyRepository.findById(companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.company.not_found"));

        Set<String> normalizedCodes = permissionConsistencyService.normalizePermissionCodes(permissionCodes);
        Set<Permission> permissions = new HashSet<>(permissionRepository.findAllById(
            normalizedCodes.stream()
                .map(code -> permissionRepository.findByCode(code)
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.permission.invalid_code|" + code))
                    .getId())
                .toList()
        ));

        boolean allCompany = roleViewAllCompany == null || roleViewAllCompany;
        var roleViewDepartment = allCompany
            ? null
            : departmentRepository.findByIdAndCompanyId(roleViewDepartmentId, companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.role.scope_department_invalid"));

        Role role = Role.builder()
            .company(company)
            .name(name)
            .description(description)
            .roleViewAllCompany(allCompany)
            .roleViewDepartment(roleViewDepartment)
            .permissions(permissions)
            .build();
        return roleRepository.save(role);
    }

    @Transactional
    public Role update(
        Long roleId,
        Long companyId,
        String name,
        String description,
        List<String> permissionCodes,
        Boolean roleViewAllCompany,
        Long roleViewDepartmentId
    ) {
        Role role = roleRepository.findById(roleId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.role.not_found"));
        if (!role.getCompany().getId().equals(companyId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.role.edit_forbidden");
        }
        if (name != null && !name.equals(role.getName())) {
            if (roleRepository.existsByCompanyIdAndName(companyId, name)) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "error.role.name_duplicate");
            }
            role.setName(name);
        }
        if (description != null) {
            role.setDescription(description);
        }
        if (roleViewAllCompany != null || roleViewDepartmentId != null) {
            boolean allCompany = roleViewAllCompany == null || roleViewAllCompany;
            role.setRoleViewAllCompany(allCompany);
            if (allCompany) {
                role.setRoleViewDepartment(null);
            } else {
                role.setRoleViewDepartment(
                    departmentRepository.findByIdAndCompanyId(roleViewDepartmentId, companyId)
                        .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.role.scope_department_invalid"))
                );
            }
        }
        if (permissionCodes != null) {
            Set<String> normalizedCodes = permissionConsistencyService.normalizePermissionCodes(permissionCodes);
            Set<Permission> permissions = new HashSet<>();
            for (String code : normalizedCodes) {
                permissionRepository.findByCode(code).ifPresent(permissions::add);
            }
            role.setPermissions(permissions);
        }
        return roleRepository.save(role);
    }

    @Transactional
    public Role updatePermissions(Long roleId, Long companyId, List<String> permissionCodes) {
        Role role = roleRepository.findById(roleId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.role.not_found"));
        if (!role.getCompany().getId().equals(companyId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.role.edit_forbidden");
        }
        Set<String> normalizedCodes = permissionConsistencyService.normalizePermissionCodes(permissionCodes);
        Set<Permission> permissions = new HashSet<>();
        for (String code : normalizedCodes) {
            permissionRepository.findByCode(code).ifPresent(permissions::add);
        }
        role.setPermissions(permissions);
        return roleRepository.save(role);
    }

    @Transactional
    public void delete(Long roleId, Long companyId) {
        Role role = roleRepository.findById(roleId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.role.not_found"));
        if (!role.getCompany().getId().equals(companyId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.role.delete_forbidden");
        }
        roleRepository.delete(role);
    }
}

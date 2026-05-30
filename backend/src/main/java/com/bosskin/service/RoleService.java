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
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Tên vai trò đã tồn tại trong công ty này");
        }
        var company = companyRepository.findById(companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Công ty không tồn tại"));

        Set<String> normalizedCodes = permissionConsistencyService.normalizePermissionCodes(permissionCodes);
        Set<Permission> permissions = new HashSet<>(permissionRepository.findAllById(
            normalizedCodes.stream()
                .map(code -> permissionRepository.findByCode(code)
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Permission không hợp lệ: " + code))
                    .getId())
                .toList()
        ));

        boolean allCompany = roleViewAllCompany == null || roleViewAllCompany;
        var roleViewDepartment = allCompany
            ? null
            : departmentRepository.findByIdAndCompanyId(roleViewDepartmentId, companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Phòng ban scope role không hợp lệ"));

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
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Vai trò không tồn tại"));
        if (!role.getCompany().getId().equals(companyId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền sửa vai trò này");
        }
        if (name != null && !name.equals(role.getName())) {
            if (roleRepository.existsByCompanyIdAndName(companyId, name)) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "Tên vai trò đã tồn tại trong công ty này");
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
                        .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Phòng ban scope role không hợp lệ"))
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
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Vai trò không tồn tại"));
        if (!role.getCompany().getId().equals(companyId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền sửa vai trò này");
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
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Vai trò không tồn tại"));
        if (!role.getCompany().getId().equals(companyId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền xóa vai trò này");
        }
        roleRepository.delete(role);
    }
}

package com.bosskin.service;

import com.bosskin.dto.CompanyResponse;
import com.bosskin.dto.CreateCompanyRequest;
import com.bosskin.entity.Company;
import com.bosskin.entity.Permission;
import com.bosskin.entity.Role;
import com.bosskin.entity.User;
import com.bosskin.repository.CompanyRepository;
import com.bosskin.repository.PermissionRepository;
import com.bosskin.repository.RoleRepository;
import com.bosskin.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CompanyService {

    private final CompanyRepository    companyRepository;
    private final UserRepository       userRepository;
    private final RoleRepository       roleRepository;
    private final PermissionRepository permissionRepository;
    private final PasswordEncoder      passwordEncoder;

    public List<CompanyResponse> findAll() {
        return companyRepository.findAll().stream().map(this::toResponse).toList();
    }

    public CompanyResponse findById(Long id) {
        return toResponse(getOrThrow(id));
    }

    @Transactional
    public CompanyResponse create(CreateCompanyRequest req) {
        if (companyRepository.existsByCode(req.getCode().toUpperCase())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Mã công ty đã tồn tại");
        }
        if (userRepository.existsByEmail(req.getAdminEmail())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Email admin đã được sử dụng");
        }

        // 1. Tạo công ty
        Company company = new Company();
        company.setName(req.getName());
        company.setCode(req.getCode().toUpperCase());
        company.setDomain(req.getDomain());
        company.setAddress(req.getAddress());
        company.setPhone(req.getPhone());
        company.setEmail(req.getCompanyEmail());
        company.setActive(true);
        company = companyRepository.save(company);

        // 2. Tạo role "Admin" cho công ty với toàn quyền
        List<Permission> allPermissions = permissionRepository.findAll();
        Role adminRole = new Role();
        adminRole.setCompany(company);
        adminRole.setName("Admin");
        adminRole.setDescription("Quản trị viên công ty — toàn quyền");
        adminRole.setDefault(true);
        adminRole.setPermissions(new HashSet<>(allPermissions));
        adminRole = roleRepository.save(adminRole);

        // 3. Tạo user admin đầu tiên
        User admin = User.builder()
            .email(req.getAdminEmail())
            .password(passwordEncoder.encode(req.getAdminPassword()))
            .company(company)
            .roles(Set.of(adminRole))
            .enabled(true)
            .build();
        userRepository.save(admin);

        return toResponse(company);
    }

    @Transactional
    public CompanyResponse update(Long id, CreateCompanyRequest req) {
        Company company = getOrThrow(id);
        if (req.getName()         != null) company.setName(req.getName());
        if (req.getDomain()       != null) company.setDomain(req.getDomain());
        if (req.getAddress()      != null) company.setAddress(req.getAddress());
        if (req.getPhone()        != null) company.setPhone(req.getPhone());
        if (req.getCompanyEmail() != null) company.setEmail(req.getCompanyEmail());
        return toResponse(companyRepository.save(company));
    }

    @Transactional
    public void toggleActive(Long id) {
        Company company = getOrThrow(id);
        company.setActive(!company.isActive());
        companyRepository.save(company);
    }

    private Company getOrThrow(Long id) {
        return companyRepository.findById(id)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Công ty không tồn tại"));
    }

    private CompanyResponse toResponse(Company c) {
        String adminEmail = userRepository.findFirstByCompanyId(c.getId())
            .map(User::getEmail).orElse(null);
        return CompanyResponse.builder()
            .id(c.getId()).name(c.getName()).code(c.getCode())
            .domain(c.getDomain()).address(c.getAddress())
            .phone(c.getPhone()).email(c.getEmail())
            .active(c.isActive())
            .selfAttendanceEnabled(c.isSelfAttendanceEnabled())
            .adminEmail(adminEmail)
            .createdAt(c.getCreatedAt())
            .build();
    }
}

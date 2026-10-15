package com.bosskin.service;

import com.bosskin.dto.CompanyResponse;
import com.bosskin.core.CompanyIdentity;
import com.bosskin.dto.CreateCompanyRequest;
import com.bosskin.dto.UpdateCompanyRequest;
import com.bosskin.entity.Company;
import com.bosskin.entity.Permission;
import com.bosskin.entity.Role;
import com.bosskin.entity.User;
import com.bosskin.repository.CompanyRepository;
import com.bosskin.repository.EmployeeRepository;
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
    private final EmployeeRepository   employeeRepository;
    private final RoleRepository       roleRepository;
    private final com.bosskin.repository.RolePermDeptScopeRepository rolePermDeptScopeRepository;
    private final PermissionRepository permissionRepository;
    private final PasswordEncoder      passwordEncoder;
    private final DocumentService      documentService;
    private final com.bosskin.audit.AuditService audit;

    public List<CompanyResponse> findAll() {
        return companyRepository.findAll().stream().map(this::toResponse).toList();
    }

    public CompanyResponse findById(Long id) {
        return toResponse(getOrThrow(id));
    }

    public static final String DEFAULT_EMPLOYEE_ROLE_NAME = "Nhân viên";
    /** ATTENDANCE_VIEW / LEAVE_VIEW là quyền tiên quyết của module, giới hạn phạm vi "chỉ mình tôi". */
    public static final java.util.Set<String> DEFAULT_EMPLOYEE_PERMISSIONS = java.util.Set.of(
        "ATTENDANCE_VIEW", "ATTENDANCE_SELF", "LEAVE_VIEW", "LEAVE_REQUEST_CREATE", "SHIFT_REGISTRATION_SELF");

    @Transactional
    public CompanyResponse create(CreateCompanyRequest req) {
        com.bosskin.core.PasswordPolicy.require(req.getAdminPassword());
        // V22: mã công ty = tiền tố mã NV, đuôi email bắt buộc cho mọi tài khoản của công ty
        String code = CompanyIdentity.normalizeCode(req.getCode());
        requireCodeAvailable(code);
        String domain = CompanyIdentity.normalizeDomain(req.getDomain());
        if (domain == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.company.domain_required");
        }
        if (companyRepository.existsByDomainIgnoreCase(domain)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.company.domain_duplicate|" + domain);
        }
        String adminEmail = req.getAdminEmail().trim();
        if (!CompanyIdentity.emailMatches(domain, adminEmail)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.email.domain_mismatch|" + domain);
        }
        if (userRepository.existsByEmail(adminEmail)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "error.email.in_use");
        }

        // 1. Tạo công ty
        Company company = new Company();
        company.setName(req.getName());
        company.setCode(code);
        company.setDomain(domain);
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
        // Admin KHÔNG phải vai trò mặc định: vai trò mặc định được gán tự động cho nhân viên mới (D1)
        adminRole.setDefault(false);
        adminRole.setPermissions(new HashSet<>(allPermissions));
        adminRole = roleRepository.save(adminRole);

        // 2b. Vai trò mặc định cho nhân viên mới: chỉ tự chấm công và xin nghỉ
        Role employeeRole = new Role();
        employeeRole.setCompany(company);
        employeeRole.setName(DEFAULT_EMPLOYEE_ROLE_NAME);
        employeeRole.setDescription("Vai trò mặc định của nhân viên mới — tự chấm công, xin nghỉ phép");
        employeeRole.setDefault(true);
        employeeRole.setPermissions(new HashSet<>(allPermissions.stream()
            .filter(p -> DEFAULT_EMPLOYEE_PERMISSIONS.contains(p.getCode()))
            .toList()));
        employeeRole = roleRepository.save(employeeRole);
        rolePermDeptScopeRepository.replaceAll(employeeRole.getId(), java.util.Map.of(
            "ATTENDANCE_VIEW", java.util.List.of(DeptScopeService.SCOPE_SELF_ONLY),
            "LEAVE_VIEW", java.util.List.of(DeptScopeService.SCOPE_SELF_ONLY)));

        // 3. Tạo user admin đầu tiên
        User admin = User.builder()
            .email(adminEmail)
            .password(passwordEncoder.encode(req.getAdminPassword()))
            .mustChangePassword(true)
            .company(company)
            .roles(Set.of(adminRole))
            .enabled(true)
            .build();
        userRepository.save(admin);

        // 4. Danh mục loại tài liệu nhân sự mặc định (Bước N)
        documentService.createDefaultTypes(company.getId());

        return toResponse(company);
    }

    @Transactional
    public CompanyResponse update(Long id, UpdateCompanyRequest req) {
        Company company = getOrThrow(id);
        // V22: mã công ty là tiền tố mã NV → không đổi được (kể cả đổi sang mã của công ty khác)
        if (req.getCode() != null && !req.getCode().isBlank()
                && !req.getCode().trim().equalsIgnoreCase(company.getCode())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.company.code_immutable");
        }
        if (req.getName() != null) {
            if (req.getName().isBlank()) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.company.name_required");
            company.setName(req.getName().trim());
        }
        if (req.getDomain() != null) {
            String domain = CompanyIdentity.normalizeDomain(req.getDomain());
            if (domain == null) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "error.company.domain_required");
            }
            if (!domain.equalsIgnoreCase(company.getDomain())) {
                if (companyRepository.existsByDomainIgnoreCaseAndIdNot(domain, id)) {
                    throw new ResponseStatusException(HttpStatus.CONFLICT, "error.company.domain_duplicate|" + domain);
                }
                long outside = userRepository.countEmailOutsideDomain(id, domain);
                if (outside > 0) {
                    throw new ResponseStatusException(HttpStatus.CONFLICT,
                        "error.company.domain_accounts_mismatch|" + domain + "|" + outside);
                }
                company.setDomain(domain);
            }
        }
        if (req.getAddress()      != null) company.setAddress(req.getAddress());
        if (req.getPhone()        != null) company.setPhone(req.getPhone());
        if (req.getCompanyEmail() != null) company.setEmail(req.getCompanyEmail());
        if (req.getModules() != null) {
            java.util.Set<String> before = company.disabledModuleSet();
            java.util.Set<String> disabled = com.bosskin.core.CompanyModules.disabledFromEnabled(req.getModules());
            company.setDisabledModules(com.bosskin.core.CompanyModules.format(disabled));
            if (!disabled.equals(before)) {
                audit.log("COMPANY_MODULES").company(id).entity("COMPANY", id)
                    .summary(company.getCode() + ": " + String.join(", ", com.bosskin.core.CompanyModules.enabledOf(disabled)))
                    .detail(com.bosskin.audit.AuditService.map(
                        "before", com.bosskin.core.CompanyModules.enabledOf(before),
                        "after", com.bosskin.core.CompanyModules.enabledOf(disabled)))
                    .save();
            }
        }
        return toResponse(companyRepository.save(company));
    }

    @Transactional
    public void toggleActive(Long id) {
        Company company = getOrThrow(id);
        company.setActive(!company.isActive());
        companyRepository.save(company);
    }

    /** Mã mới không trùng và không là tiền tố (hoặc nhận mã khác làm tiền tố) của mã công ty đã có. */
    private void requireCodeAvailable(String code) {
        for (String other : companyRepository.findAllCodes()) {
            String o = other.toUpperCase(java.util.Locale.ROOT);
            if (o.equals(code)) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "error.company.code_duplicate");
            }
            if (o.startsWith(code) || code.startsWith(o)) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "error.company.code_prefix_conflict|" + other);
            }
        }
    }

    private Company getOrThrow(Long id) {
        return companyRepository.findById(id)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "error.company.not_found"));
    }

    private CompanyResponse toResponse(Company c) {
        String adminEmail = userRepository.findFirstByCompanyId(c.getId())
            .map(User::getEmail).orElse(null);
        long empCount = employeeRepository.countByCompanyId(c.getId());
        return CompanyResponse.builder()
            .id(c.getId()).name(c.getName()).code(c.getCode())
            .domain(c.getDomain()).address(c.getAddress())
            .phone(c.getPhone()).email(c.getEmail())
            .active(c.isActive())
            .requireAdmin2fa(c.isRequireAdmin2fa())
            .selfAttendanceEnabled(c.isSelfAttendanceEnabled())
            .modules(com.bosskin.core.CompanyModules.enabledOf(c.disabledModuleSet()))
            .employeeCount(empCount)
            .adminEmail(adminEmail)
            .createdAt(c.getCreatedAt())
            .build();
    }
}

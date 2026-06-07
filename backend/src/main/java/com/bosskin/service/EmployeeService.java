package com.bosskin.service;

import com.bosskin.dto.EmployeeDTO;
import com.bosskin.dto.PageResponse;
import com.bosskin.dto.UserDTO;
import com.bosskin.entity.Company;
import com.bosskin.entity.Department;
import com.bosskin.entity.Employee;
import com.bosskin.entity.Position;
import com.bosskin.entity.Role;
import com.bosskin.entity.SalaryGrade;
import com.bosskin.entity.User;
import com.bosskin.repository.CompanyRepository;
import com.bosskin.repository.DepartmentRepository;
import com.bosskin.repository.EmployeeRepository;
import com.bosskin.repository.PositionRepository;
import com.bosskin.repository.RoleRepository;
import com.bosskin.repository.SalaryGradeRepository;
import com.bosskin.repository.UserRepository;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.List;
import java.time.LocalDate;
import java.util.Set;
import java.util.HashSet;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class EmployeeService {

    private final EmployeeRepository employeeRepository;
    private final DepartmentRepository departmentRepository;
    private final PositionRepository positionRepository;
    private final SalaryGradeRepository salaryGradeRepository;
    private final CompanyRepository companyRepository;
    private final RoleRepository roleRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final DeptScopeService deptScopeService;

    public PageResponse<EmployeeDTO.Response> findAll(
        Long companyId, Long userId, int page, int size, String search,
        Long departmentId, Employee.Status status
    ) {
        var pageable = PageRequest.of(page, size, Sort.by("fullName").ascending());
        Set<Long> selectedDeptScope = null;
        if (departmentId != null) {
            selectedDeptScope = deptScopeService.expandDepartmentsWithDescendants(Set.of(departmentId));
            if (selectedDeptScope.isEmpty()) {
                return PageResponse.of(org.springframework.data.domain.Page.empty());
            }
        }

        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, "EMPLOYEE_VIEW");
        if (!scopeIds.isEmpty()) {
            Set<Long> deptScope = scopeIds.stream()
                .filter(id -> id != null && id > 0)
                .collect(Collectors.toSet());
            if (deptScope.isEmpty()) {
                return PageResponse.of(org.springframework.data.domain.Page.empty());
            }
            if (selectedDeptScope != null) {
                Set<Long> intersection = new HashSet<>(deptScope);
                intersection.retainAll(selectedDeptScope);
                if (intersection.isEmpty()) {
                    return PageResponse.of(org.springframework.data.domain.Page.empty());
                }
                deptScope = intersection;
            }
            return PageResponse.of(
                employeeRepository.findAllWithDeptScope(companyId, deptScope, search, status, pageable)
                    .map(this::toResponse)
            );
        }

        if (selectedDeptScope != null) {
            return PageResponse.of(
                employeeRepository.findAllWithDeptScope(companyId, selectedDeptScope, search, status, pageable)
                    .map(this::toResponse)
            );
        }

        return PageResponse.of(
            employeeRepository.findAllWithFilters(companyId, search, departmentId, status, pageable)
                .map(this::toResponse)
        );
    }

    public EmployeeDTO.Response findById(Long id, Long companyId) {
        return toResponse(getOrThrow(id, companyId));
    }

    public EmployeeDTO.Response findById(Long id, Long companyId, Long userId) {
        Employee employee = getOrThrow(id, companyId);
        requireViewScope(userId, employee.getDepartment().getId());
        return toResponse(employee);
    }

    public List<EmployeeDTO.Response> findAllForShiftScope(Long companyId, Long userId) {
        Set<Long> scopeIds = deptScopeService.resolvedScopes(userId, "SHIFT_VIEW");

        if (scopeIds.isEmpty()) {
            return employeeRepository.findAllByCompanyIdFetchDepartment(companyId).stream()
                .map(this::toResponse)
                .toList();
        }

        if (scopeIds.contains(DeptScopeService.SCOPE_SELF_ONLY)) {
            return employeeRepository.findByUserIdFetch(userId)
                .filter(e -> e.getCompany().getId().equals(companyId))
                .map(this::toResponse)
                .stream()
                .toList();
        }

        Set<Long> deptScope = scopeIds.stream()
            .filter(id -> id != null && id > 0)
            .collect(Collectors.toSet());
        if (deptScope.isEmpty()) {
            return List.of();
        }
        return employeeRepository.findAllByCompanyIdAndDepartmentIdInFetchDepartment(companyId, deptScope).stream()
            .map(this::toResponse)
            .toList();
    }

    @Transactional
    public EmployeeDTO.Response create(EmployeeDTO.CreateRequest req, Long companyId, Long userId) {
        requireViewScope(userId, req.getDepartmentId());
        if (employeeRepository.existsByEmailAndCompanyId(req.getEmail(), companyId) ||
            userRepository.existsByEmail(req.getEmail())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Email đã được sử dụng");
        }
        Company company = companyRepository.findById(companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Công ty không tồn tại"));
        Department dept = departmentRepository.findByIdAndCompanyId(req.getDepartmentId(), companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Phòng ban không tồn tại"));
        Position pos = null;
        if (req.getPositionId() != null) {
            pos = positionRepository.findByIdAndDepartmentCompanyId(req.getPositionId(), companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Chức vụ không tồn tại"));
            if (!pos.getDepartment().getId().equals(req.getDepartmentId())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Chức vụ không thuộc phòng ban đã chọn");
            }
        }

        Employee employee = Employee.builder()
            .company(company)
            .employeeCode(generateCode(companyId))
            .fullName(req.getFullName()).email(req.getEmail()).phone(req.getPhone())
            .gender(req.getGender()).dateOfBirth(req.getDateOfBirth()).joinDate(req.getJoinDate())
            .department(dept).position(pos)
            .address(req.getAddress()).identityCard(req.getIdentityCard())
            .bankAccount(req.getBankAccount()).bankName(req.getBankName())
            .build();
        employee = employeeRepository.save(employee);

        var role = resolveEmployeeRole(companyId);

        var user = com.bosskin.entity.User.builder()
            .email(req.getEmail())
            .password(passwordEncoder.encode(req.getPassword()))
            .company(company)
            .employee(employee)
            .enabled(true)
            .build();
        if (role.isPresent()) {
            user.getRoles().add(role.get());
        }
        userRepository.save(user);

        return toResponse(employee);
    }

    @Transactional
    public EmployeeDTO.Response update(Long id, EmployeeDTO.UpdateRequest req, Long companyId, Long userId) {
        Employee e = getOrThrow(id, companyId);
        requireViewScope(userId, e.getDepartment().getId());
        if (req.getFullName()   != null) e.setFullName(req.getFullName());
        if (req.getPhone()      != null) e.setPhone(req.getPhone());
        if (req.getGender()     != null) e.setGender(req.getGender());
        if (req.getDateOfBirth()!= null) e.setDateOfBirth(req.getDateOfBirth());
        if (req.getJoinDate()      != null) e.setJoinDate(req.getJoinDate());
        if (req.getLeaveDate()     != null) e.setLeaveDate(req.getLeaveDate());
        if (req.getStatus()        != null) e.setStatus(req.getStatus());
        if (req.getAddress()       != null) e.setAddress(req.getAddress());
        if (req.getIdentityCard()  != null) e.setIdentityCard(req.getIdentityCard());
        if (req.getPersonalEmail() != null) e.setPersonalEmail(req.getPersonalEmail());
        if (req.getBankAccount()   != null) e.setBankAccount(req.getBankAccount());
        if (req.getBankName()      != null) e.setBankName(req.getBankName());
        if (req.getDepartmentId() != null) {
            e.setDepartment(departmentRepository.findByIdAndCompanyId(req.getDepartmentId(), companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Phòng ban không tồn tại")));
            if (e.getPosition() != null && !e.getPosition().getDepartment().getId().equals(e.getDepartment().getId())) {
                e.setPosition(null);
            }
        }
        if (req.getPositionId() != null) {
            Position pos = positionRepository.findByIdAndDepartmentCompanyId(req.getPositionId(), companyId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Chức vụ không tồn tại"));
            if (!pos.getDepartment().getId().equals(e.getDepartment().getId())) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Chức vụ không thuộc phòng ban đã chọn");
            }
            e.setPosition(pos);
        } else {
            e.setPosition(null);
        }
        if (req.getSalaryGradeId() != null) {
            SalaryGrade grade = salaryGradeRepository.findById(req.getSalaryGradeId())
                .filter(g -> g.getCompany() != null && g.getCompany().getId().equals(companyId))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Bậc lương không tồn tại"));
            e.setSalaryGrade(grade);
        } else {
            e.setSalaryGrade(null);
        }
        if (req.getContractSalary() != null) e.setContractSalary(req.getContractSalary());
        return toResponse(employeeRepository.save(e));
    }

    @Transactional
    public UserDTO.SyncEmployeesResponse syncMissingUserAccounts(Long companyId, String initialPassword) {
        if (initialPassword == null || initialPassword.trim().length() < 6) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Mật khẩu khởi tạo phải có ít nhất 6 ký tự");
        }

        Company company = companyRepository.findById(companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Công ty không tồn tại"));
        List<Employee> employees = employeeRepository.findByCompanyId(companyId);
        Role employeeRole = resolveEmployeeRole(companyId).orElse(null);

        int createdCount = 0;
        int linkedCount = 0;
        int skippedCount = 0;

        for (Employee employee : employees) {
            String email = employee.getEmail();
            if (email == null || email.isBlank()) {
                skippedCount++;
                continue;
            }

            User userByEmployee = userRepository.findByEmployeeId(employee.getId()).orElse(null);
            if (userByEmployee != null) {
                boolean changed = false;
                if (!email.equalsIgnoreCase(userByEmployee.getEmail())) {
                    User sameEmail = userRepository.findByEmail(email).orElse(null);
                    if (sameEmail != null && !sameEmail.getId().equals(userByEmployee.getId())) {
                        skippedCount++;
                        continue;
                    }
                    userByEmployee.setEmail(email);
                    changed = true;
                }
                if (userByEmployee.getEmployee() == null ||
                    !userByEmployee.getEmployee().getId().equals(employee.getId())) {
                    userByEmployee.setEmployee(employee);
                    changed = true;
                }
                if (!userByEmployee.isEnabled()) {
                    userByEmployee.setEnabled(true);
                    changed = true;
                }
                if (employeeRole != null && userByEmployee.getRoles().isEmpty()) {
                    userByEmployee.getRoles().add(employeeRole);
                    changed = true;
                }
                if (changed) {
                    userRepository.save(userByEmployee);
                }
                linkedCount++;
                continue;
            }

            User existing = userRepository.findByEmail(email).orElse(null);
            if (existing != null) {
                if (!existing.getCompany().getId().equals(companyId)) {
                    skippedCount++;
                    continue;
                }
                boolean changed = false;
                if (existing.getEmployee() == null) {
                    existing.setEmployee(employee);
                    changed = true;
                } else if (!existing.getEmployee().getId().equals(employee.getId())) {
                    skippedCount++;
                    continue;
                }
                if (!existing.isEnabled()) {
                    existing.setEnabled(true);
                    changed = true;
                }
                if (employeeRole != null && existing.getRoles().isEmpty()) {
                    existing.getRoles().add(employeeRole);
                    changed = true;
                }
                if (changed) {
                    userRepository.save(existing);
                }
                linkedCount++;
                continue;
            }

            User newUser = User.builder()
                .email(email)
                .password(passwordEncoder.encode(initialPassword))
                .company(company)
                .employee(employee)
                .enabled(true)
                .build();
            if (employeeRole != null) {
                newUser.getRoles().add(employeeRole);
            }
            userRepository.save(newUser);
            createdCount++;
        }

        return UserDTO.SyncEmployeesResponse.builder()
            .createdCount(createdCount)
            .linkedCount(linkedCount)
            .skippedCount(skippedCount)
            .totalEmployees(employees.size())
            .build();
    }

    @Transactional
    public void delete(Long id, Long companyId, Long userId) {
        Employee e = getOrThrow(id, companyId);
        requireViewScope(userId, e.getDepartment().getId());
        e.setStatus(Employee.Status.INACTIVE);
        if (e.getLeaveDate() == null) {
            e.setLeaveDate(LocalDate.now());
        }
        employeeRepository.save(e);
        employeeRepository.delete(e);
    }

    private void requireViewScope(Long userId, Long deptId) {
        Set<Long> scope = deptScopeService.resolvedScopes(userId, "EMPLOYEE_VIEW");
        if (!scope.isEmpty() && !scope.contains(deptId))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Không có quyền thao tác nhân viên phòng ban này");
    }

    private java.util.Optional<Role> resolveEmployeeRole(Long companyId) {
        return roleRepository.findByCompanyIdAndName(companyId, "Employee")
            .or(() -> roleRepository.findFirstByCompanyIdAndIsDefaultTrue(companyId));
    }

    private Employee getOrThrow(Long id, Long companyId) {
        return employeeRepository.findByIdAndCompanyId(id, companyId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Nhân viên không tồn tại"));
    }

    private String generateCode(Long companyId) {
        long count = employeeRepository.countByCompanyId(companyId) + 1;
        return String.format("EMP%05d", count);
    }

    private EmployeeDTO.Response toResponse(Employee e) {
        return EmployeeDTO.Response.builder()
            .id(e.getId()).employeeCode(e.getEmployeeCode())
            .fullName(e.getFullName()).email(e.getEmail()).phone(e.getPhone())
            .personalEmail(e.getPersonalEmail())
            .avatar(e.getAvatar()).gender(e.getGender())
            .dateOfBirth(e.getDateOfBirth()).joinDate(e.getJoinDate()).leaveDate(e.getLeaveDate())
            .status(e.getStatus())
            .departmentId(e.getDepartment().getId()).departmentName(e.getDepartment().getName())
            .positionId(e.getPosition() != null ? e.getPosition().getId() : null)
            .positionName(e.getPosition() != null ? e.getPosition().getName() : null)
            .salaryGradeId(e.getSalaryGrade() != null ? e.getSalaryGrade().getId() : null)
            .salaryGradeCode(e.getSalaryGrade() != null ? e.getSalaryGrade().getCode() : null)
            .salaryGradeName(e.getSalaryGrade() != null ? e.getSalaryGrade().getName() : null)
            .address(e.getAddress()).identityCard(e.getIdentityCard())
            .bankAccount(e.getBankAccount()).bankName(e.getBankName())
            .contractSalary(e.getContractSalary()).createdAt(e.getCreatedAt())
            .build();
    }
}
